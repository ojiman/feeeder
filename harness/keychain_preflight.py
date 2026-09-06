"""User-approved disposable Keychain experiment. Never enumerates existing items."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess

from preflight import clean_environment, digest, profile_text


def read_row(raw):
    rows = [json.loads(line) for line in raw.splitlines() if line.startswith("{")]
    return rows[0] if len(rows) == 1 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--codex", default=shutil.which("codex"))
    args = parser.parse_args()
    destination = args.output.resolve()
    if not args.codex or destination.is_relative_to(Path("/private/tmp")):
        parser.error("codex required; Keychain fixture/evidence must be outside shared /private/tmp")
    destination.mkdir(parents=True, exist_ok=False)
    root = destination / "run"
    for name in ("source", "output/home", "output/tmp", "control/codex-home", "protected"):
        (root / name).mkdir(parents=True)
    source = Path(__file__).with_name("keychain_probe.c").resolve()
    binary = root / "control/probe"
    result = subprocess.run(["/usr/bin/clang", "-Wall", "-Wextra", "-Werror", "-Wno-deprecated-declarations",
        str(source), "-framework", "Security", "-framework", "CoreFoundation", "-o", str(binary)],
        capture_output=True, text=True, timeout=60)
    (destination / "compile.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise SystemExit("Compile failed; see compile.log")
    canary = secrets.token_hex(24)
    keychain = root / "protected/fixture.keychain"
    report = {"scope": "H-C02 partial: explicit disposable legacy Keychain, framework and CLI",
        "harness_hash": digest(Path(__file__)), "probe_hash": digest(source), "binary_hash": digest(binary),
        "profile_generator_hash": digest(Path(__file__).with_name("preflight.py")),
        "os": subprocess.check_output(["/usr/bin/sw_vers"], text=True).strip(),
        "codex": subprocess.check_output([args.codex, "--version"], text=True).strip(),
        "fixture_path": str(keychain), "runs": [],
        "limitations": ["Legacy Keychain only; modern data-protection Keychain not tested", "No LLM worker tested",
                        "Creating/deleting an explicit disposable Keychain may register/remove it in the OS search list; no default Keychain switch requested"]}
    setup_env = clean_environment(root) | {"RSS_KEYCHAIN_CANARY": canary}
    created = False
    stage = "setup"
    try:
        setup = subprocess.run([str(binary), "create", str(keychain)], env=setup_env,
                               capture_output=True, text=True, timeout=30)
        report["setup"] = read_row(setup.stdout)
        report["setup_stages"] = setup.stderr.replace(canary, "[REDACTED]")
        created = setup.returncode == 0 and report["setup"] is not None and report["setup"]["status"] == 0
        if not created:
            report["status"] = "BLOCKED"
        else:
            for role in ("control", "writer", "verifier"):
                config = root / "control/codex-home/config.toml"
                config.write_text(profile_text(root, "writer" if role == "control" else role))
                commands = {
                    "framework": [str(binary), "read", str(keychain)],
                    "cli": ["/usr/bin/security", "find-generic-password", "-s", "rss-harness-fixture",
                            "-a", "canary", "-w", str(keychain)],
                }
                observations = {}
                for name, command in commands.items():
                    stage = role + "." + name
                    if role != "control":
                        command = [args.codex, "sandbox", "-P", "probe", "-C", str(root / "source"), "--", *command]
                    result = subprocess.run(command, env=clean_environment(root), cwd=root / "source",
                                            capture_output=True, text=True, timeout=30)
                    # Raw CLI stdout is never persisted or sent to a model.
                    row = read_row(result.stdout) if name == "framework" else None
                    observations[name] = {
                        "command": command, "exit_code": result.returncode, "framework_result": row,
                        "value_obtained": bool(row and row["value_obtained"]) if name == "framework"
                                          else result.returncode == 0 and result.stdout.strip() == canary,
                        "canary_in_stderr": canary in result.stderr,
                        "stderr": result.stderr.replace(canary, "[REDACTED]"),
                    }
                report["runs"].append({"role": role, "observations": observations,
                                       "policy_hash": digest(config), "policy": config.read_text()})
            control = report["runs"][0]["observations"]
            control_ok = all(item["value_obtained"] for item in control.values())
            worker_ok = all(
                not obs["value_obtained"] and not obs["canary_in_stderr"] and (
                    obs["exit_code"] != 0 if name == "cli" else
                    obs["exit_code"] == 0 and obs["framework_result"] is not None
                    and obs["framework_result"]["status"] != 0
                ) for run in report["runs"][1:] for name, obs in run["observations"].items()
            )
            report["status"] = "BLOCKED" if not control_ok else "PASS" if worker_ok else "FAIL"
    except (OSError, subprocess.TimeoutExpired) as error:
        report["status"] = "BLOCKED"
        report["error"] = type(error).__name__
        report["error_stage"] = stage
        if isinstance(error, subprocess.TimeoutExpired) and error.stderr:
            stderr = error.stderr.decode(errors="replace") if isinstance(error.stderr, bytes) else error.stderr
            report["timeout_stages"] = stderr.replace(canary, "[REDACTED]")
    finally:
        if created or keychain.exists() or Path(str(keychain) + "-db").exists():
            try:
                cleanup = subprocess.run([str(binary), "delete", str(keychain)], env=clean_environment(root),
                                         capture_output=True, text=True, timeout=15)
                report["cleanup"] = read_row(cleanup.stdout)
                if cleanup.returncode != 0 or not report["cleanup"] or report["cleanup"]["status"] != 0:
                    report["status"] = "FAIL"
            except (OSError, subprocess.TimeoutExpired):
                report["cleanup"] = {"status": "BLOCKED", "action": "User must delete this exact fixture path"}
                report["status"] = "FAIL"
        payload = json.dumps(report, indent=2)
        if canary in payload:
            payload = payload.replace(canary, "[REDACTED]")
            report["status"] = "FAIL"
            payload = json.dumps(report, indent=2).replace(canary, "[REDACTED]")
        (destination / "report.json").write_text(payload + "\n")
    print(json.dumps({"report": str(destination / "report.json"), "partial_keychain_status": report["status"],
                      "full_harness_acceptance": "NOT_RUN"}))
    raise SystemExit(0 if report["status"] == "PASS" else 1)


if __name__ == "__main__":
    raise SystemExit(
        "DISABLED: this experiment triggered an unexpected login Keychain prompt. "
        "Do not run on the user's normal account; see docs/harness-service-results.md."
    )
