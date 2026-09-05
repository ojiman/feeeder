"""Small native boundary experiment. Never starts an LLM or changes user settings."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def clean_environment(root):
    return {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "HOME": str(root / "output/home"),
        "TMPDIR": str(root / "output/tmp"),
        "LANG": "en_US.UTF-8",
        "CODEX_HOME": str(root / "control/codex-home"),
    }


def profile_text(root, role):
    if role not in {"writer", "verifier"}:
        raise ValueError("unknown role")
    # JSON strings are valid TOML basic strings for these POSIX paths.
    entries = {
        ":root": "deny",
        ":slash_tmp": "deny",
        "/private/tmp": "deny",
        ":minimal": "read",
        str(root / "source"): "write" if role == "writer" else "read",
        str(root / "output"): "write",
        str(root / "control/probe"): "read",
    }
    lines = ['default_permissions = "probe"', '[permissions.probe.filesystem]']
    lines += [f"{json.dumps(key)} = {json.dumps(value)}" for key, value in entries.items()]
    return "\n".join(lines + ['[permissions.probe.network]', 'enabled = false', ''])


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default=shutil.which("codex"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--temporary-location", action="store_true",
                        help="Reproduce the observed /private/tmp boundary failure with fake files")
    args = parser.parse_args()
    if not args.codex:
        parser.error("codex executable required")
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    root = Path(tempfile.mkdtemp(prefix="rss-harness-", dir="/private/tmp" if args.temporary_location else destination)).resolve()
    for name in ("source", "output/home", "output/tmp", "control/codex-home", "protected"):
        (root / name).mkdir(parents=True, exist_ok=True)
    probe_source = Path(__file__).with_name("probe.c").resolve()
    binary = root / "control/probe"
    compile_result = subprocess.run(
        ["/usr/bin/clang", "-Wall", "-Wextra", "-Werror", str(probe_source), "-o", str(binary)],
        capture_output=True, text=True, timeout=60,
    )
    (destination / "compile.log").write_text(compile_result.stdout + compile_result.stderr)
    if compile_result.returncode:
        raise SystemExit("Probe compilation failed; see compile.log")
    protected = root / "protected/canary"
    (root / "source/link").symlink_to(protected)
    (root / "source/input").write_text("synthetic source\n")
    source_hash = digest(probe_source)
    os.environ["RSS_FAKE_TOKEN"] = "not-a-secret-harness-parent-only"
    report = {
        "scope": "H-B01/H-B03/H-C01 partial native command probes, not full H acceptance",
        "root": str(root), "probe_source_hash": source_hash, "probe_binary_hash": digest(binary),
        "os": subprocess.check_output(["/usr/bin/sw_vers"], text=True).strip(),
        "codex": subprocess.check_output([args.codex, "--version"], text=True).strip(),
        "runs": [],
        "not_tested": ["Keychain IPC", "network positive controls", "tool surface", "LLM worker",
                       "authoritative oracle adoption", "approval matching", "prompt injection", "native app build"],
    }
    try:
        for role in ("control", "writer", "verifier"):
            protected.write_text("synthetic protected canary\n")
            before = digest(protected)
            config = profile_text(root, "writer" if role == "control" else role)
            (root / "control/codex-home/config.toml").write_text(config)
            (destination / f"{role}.toml").write_text(config)
            command = [str(binary), str(root)]
            if role != "control":
                command = [args.codex, "sandbox", "-P", "probe", "-C", str(root / "source"), "--", *command]
            result = subprocess.run(command, env=clean_environment(root), cwd=root / "source",
                                    capture_output=True, text=True, timeout=30)
            (destination / f"{role}.stdout").write_text(result.stdout)
            (destination / f"{role}.stderr").write_text(result.stderr)
            observations = {}
            for line in result.stdout.splitlines():
                parts = line.split()
                if len(parts) == 3:
                    observations[parts[0]] = {"success": parts[1] == "1", "errno": int(parts[2])}
            expected = {}
            for prefix in ("parent", "child"):
                expected.update({f"{prefix}.{name}": value for name, value in {
                    "source_read": True, "source_write": role != "verifier",
                    "output_write": True, "output_delete": True,
                    "protected_read": role == "control", "protected_write": role == "control",
                    "relative_read": role == "control", "symlink_read": role == "control",
                    "fake_token": False,
                }.items()})
            matches = set(observations) == set(expected) and all(
                observations[key]["success"] == value and (
                    value or key.endswith("fake_token") or observations[key]["errno"] in (1, 13)
                ) for key, value in expected.items()
            )
            unchanged = digest(protected) == before
            status = "PASS" if result.returncode == 0 and matches and (role == "control" or unchanged) else "FAIL"
            if not observations:
                status = "BLOCKED"
            report["runs"].append({"role": role, "status": status, "exit_code": result.returncode,
                "command": command, "policy_hash": hashlib.sha256(config.encode()).hexdigest(),
                "expected": expected, "observed": observations, "protected_unchanged": unchanged})
    finally:
        (destination / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    # A failed positive control invalidates conclusions from negative tests.
    success = len(report["runs"]) == 3 and all(run["status"] == "PASS" for run in report["runs"])
    print(json.dumps({"report": str(destination / "report.json"), "partial_probe_success": success,
                      "full_harness_acceptance": "NOT_RUN", "runs": [
                          {"role": run["role"], "status": run["status"]} for run in report["runs"]]}))
    raise SystemExit(0 if success else 1)


if __name__ == "__main__":
    main()
