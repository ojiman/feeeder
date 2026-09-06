"""Partial native network test with positive receivers; no credentials or external traffic."""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile

from preflight import clean_environment, digest, profile_text


def evaluate_network(control_ok, exit_code, observation, received_connections):
    if not control_ok or observation is None:
        return "BLOCKED"
    if (exit_code == 0 and not observation["connect"] and not observation["sent"]
            and observation["errno"] in (1, 13) and received_connections == 0):
        return "PASS"
    return "FAIL"


def drain(listener):
    connections, received_bytes = 0, 0
    listener.settimeout(0.1)
    while True:
        try:
            connection, _ = listener.accept()
        except TimeoutError:
            break
        with connection:
            connection.settimeout(1)
            connections += 1
            received_bytes += len(connection.recv(1024))
    return {"connections": connections, "bytes": received_bytes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--codex", default=shutil.which("codex"))
    args = parser.parse_args()
    destination = args.output.resolve()
    if not args.codex or destination.is_relative_to(Path("/private/tmp")):
        parser.error("codex required; evidence must be outside shared /private/tmp")
    destination.mkdir(parents=True, exist_ok=False)
    root = destination / "run"
    for name in ("source", "output/home", "output/tmp", "control/codex-home"):
        (root / name).mkdir(parents=True)
    source = Path(__file__).with_name("service_probe.c").resolve()
    binary = root / "control/probe"
    compile_result = subprocess.run(["/usr/bin/clang", "-Wall", "-Wextra", "-Werror",
        str(source), "-o", str(binary)], capture_output=True, text=True, timeout=60)
    (destination / "compile.log").write_text(compile_result.stdout + compile_result.stderr)
    if compile_result.returncode:
        raise SystemExit("Compile failed; see compile.log")
    report = {
        "scope": "H-B02 partial: C socket calls and exec child, loopback and Unix only",
        "os": subprocess.check_output(["/usr/bin/sw_vers"], text=True).strip(),
        "codex": subprocess.check_output([args.codex, "--version"], text=True).strip(),
        "harness_hash": digest(Path(__file__)), "profile_generator_hash": digest(Path(__file__).with_name("preflight.py")),
        "probe_hash": digest(source), "binary_hash": digest(binary), "runs": [],
        "mach_lookup_limit": "Service-port lookup only. No Keychain item or clipboard data accessed. Not H-C02 acceptance.",
        "not_tested": ["External/LAN/IPv6/DNS", "curl/Python/build script paths", "Keychain canary values",
                       "Actual LLM tool inventory", "Native app build"],
    }
    socket_directory = Path(tempfile.mkdtemp(prefix="rss-net-", dir="/private/tmp"))
    socket_path = socket_directory / "listener"
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp, socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as unix:
            tcp.bind(("127.0.0.1", 0))
            unix.bind(str(socket_path))
            tcp.listen(8)
            unix.listen(8)
            report["endpoints"] = {"loopback": list(tcp.getsockname()), "unix": str(socket_path)}
            controls = {}
            for role in ("control", "writer", "verifier"):
                config = root / "control/codex-home/config.toml"
                config.write_text(profile_text(root, "writer" if role == "control" else role))
                (destination / f"{role}.toml").write_text(config.read_text())
                command = [str(binary), str(tcp.getsockname()[1]), str(socket_path)]
                if role != "control":
                    command = [args.codex, "sandbox", "-P", "probe", "-C", str(root / "source"), "--", *command]
                result = subprocess.run(command, env=clean_environment(root), cwd=root / "source",
                                        capture_output=True, text=True, timeout=30)
                (destination / f"{role}.stdout").write_text(result.stdout)
                (destination / f"{role}.stderr").write_text(result.stderr)
                rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
                received = {"loopback": drain(tcp), "unix": drain(unix)}
                statuses = {}
                for transport in ("loopback", "unix"):
                    selected = [row for row in rows if row.get("transport") == transport]
                    complete = len(selected) == 2 and {row["role"] for row in selected} == {"parent", "child"}
                    if role == "control":
                        controls[transport] = (result.returncode == 0 and complete
                            and all(row["connect"] and row["sent"] and row["errno"] == 0 for row in selected)
                            and received[transport] == {"connections": 2, "bytes": 2})
                        statuses[transport] = "PASS" if controls[transport] else "BLOCKED"
                    else:
                        checks = [evaluate_network(controls.get(transport, False), result.returncode,
                            row, received[transport]["connections"]) for row in selected]
                        statuses[transport] = ("BLOCKED" if not complete or "BLOCKED" in checks
                            else "PASS" if all(item == "PASS" for item in checks) else "FAIL")
                report["runs"].append({"role": role, "command": command, "exit_code": result.returncode,
                    "policy_hash": digest(config), "policy": config.read_text(), "observed": rows,
                    "received": received, "network_status": statuses})
    except (OSError, subprocess.TimeoutExpired) as error:
        report["setup_error"] = {"type": type(error).__name__, "message": str(error)}
    finally:
        # Remove only this process's socket, never shared-directory contents.
        if socket_path.exists():
            socket_path.unlink()
        socket_directory.rmdir()
        (destination / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    passed = ("setup_error" not in report and len(report["runs"]) == 3
              and all(all(value == "PASS" for value in run["network_status"].values()) for run in report["runs"]))
    print(json.dumps({"report": str(destination / "report.json"), "partial_network_success": passed,
                      "full_harness_acceptance": "NOT_RUN"}))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
