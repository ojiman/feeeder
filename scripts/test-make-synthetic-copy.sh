#!/usr/bin/env bash
# Uses real temporary files, ditto and plutil; codesign and open are stubbed.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/make-synthetic-copy.sh
python3 - "$script" <<'PY'
import json
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile

script = sys.argv[1]
with tempfile.TemporaryDirectory(prefix="unagi-synthetic-test-") as root:
    root = Path(root).resolve()
    tools = root / "bin"
    tools.mkdir()
    (tools / "codesign").write_text('#!/bin/bash\nif [ "$1" = --verify ]; then exit "${TEST_VERIFY_STATUS:-0}"; fi\nexit "${TEST_SIGN_STATUS:-0}"\n')
    (tools / "open").write_text('#!/bin/bash\necho unexpected-launch >&2\nexit 99\n')
    # Resolve the reserved library to a fixture, without changing HOME or touching the person's files.
    (tools / "python3").write_text(f'''#!{sys.executable}
import os
import sys
original = os.path.expanduser
os.path.expanduser = lambda path: os.environ["TEST_LIBRARY"] if path == "~/Library/Application Support/UnagiReader" else original(path)
sys.argv.pop(1)
exec(compile(sys.stdin.read(), "<path-check>", "exec"))
''')
    for tool in tools.iterdir():
        tool.chmod(0o755)
    real_library = root / "owner/Library/Application Support/UnagiReader"
    real_library.mkdir(parents=True)
    library_marker = real_library / "keep.txt"
    library_marker.write_text("keep")
    env = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}", TMPDIR=str(root), TEST_LIBRARY=str(real_library))
    source = root / "Source ' app.app"
    contents = source / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    executable = contents / "MacOS/UnagiReader"
    executable.write_text("#!/bin/bash\nexit 0\n")
    executable.chmod(0o755)
    info = contents / "Info.plist"
    original = plistlib.dumps({"CFBundleIdentifier": "xyz.ojima.UnagiReader", "CFBundleExecutable": "UnagiReader"})
    info.write_bytes(original)

    def run(data=None, *, app=source, status=0, sign_status="0", verify_status="0"):
        args = ["bash", script, str(app)]
        if data is not None:
            args.append(str(data))
        result = subprocess.run(args, env=dict(env, TEST_SIGN_STATUS=sign_status, TEST_VERIFY_STATUS=verify_status), text=True, capture_output=True)
        assert result.returncode == status, (args, result.returncode, result.stdout, result.stderr)
        assert "unexpected-launch" not in result.stderr
        if status:
            assert "Ready:" not in result.stdout and "open -n" not in result.stdout, result.stdout
        assert info.read_bytes() == original, "the source app changed"
        return result

    def launch_args(result):
        command = next(line.strip() for line in result.stdout.splitlines() if line.strip().startswith("open -n "))
        args = shlex.split(command)
        assert args[:2] == ["open", "-n"] and args[3:5] == ["--args", "--data-directory"]
        assert args[6:] == ["--seed-demo"]
        app, data = Path(args[2]), Path(args[5])
        assert app.is_absolute() and app.is_relative_to(root) and not app.is_relative_to(source)
        assert plistlib.loads((app / "Contents/Info.plist").read_bytes())["CFBundleIdentifier"] == "xyz.ojima.UnagiReader.Synthetic"
        assert (app / "Contents/MacOS/UnagiReader").read_bytes() == executable.read_bytes()
        assert data.is_dir() and not list(data.iterdir())
        return app, data

    first_app, first_data = launch_args(run())
    assert first_data.is_relative_to(first_app.parent)
    second_app, _ = launch_args(run())
    assert second_app != first_app, "each copy must have its own folder"
    print("ok   fresh copy, separate identifier and data, source unchanged, no launch")

    named_data = root / "data ' $(touch unwanted)"
    _, data = launch_args(run(named_data))
    assert data == named_data and not (root / "unwanted").exists()
    print("ok   spaces and shell characters in the launch command")

    alias = root / "library-alias"
    alias.symlink_to(real_library, target_is_directory=True)
    for forbidden in [real_library, real_library / "child", real_library / "../UnagiReader", alias, alias / "child", Path(str(real_library).lower()) / "child"]:
        result = run(forbidden, status=1)
        assert "real library" in result.stderr, result.stderr
    assert list(real_library.iterdir()) == [library_marker] and library_marker.read_text() == "keep"
    print("ok   real library, descendants, normalized paths, case variants and symlink aliases refused")

    marker = named_data / "keep.txt"
    marker.write_text("keep")
    run(named_data, status=1)
    assert marker.read_text() == "keep"
    run(source / "new-data", status=1)
    assert not (source / "new-data").exists()
    print("ok   existing data directory and paths inside the source app refused")

    before = set(root.iterdir())
    run(status=1, sign_status="1")
    assert set(root.iterdir()) == before, "a failed signing left a copy behind"
    run(status=1, verify_status="1")
    assert set(root.iterdir()) == before, "a failed verification left a copy behind"
    print("ok   signing and verification failures produce no launch command and remove their copy")

    run(app=root / "missing.app", status=1)
    info.unlink()
    external_info = root / "external.plist"
    external_info.write_bytes(original)
    info.symlink_to(external_info)
    run(status=1)
    assert external_info.read_bytes() == original
    print("ok   missing app and linked Info.plist refused")

    for args in [[""], [str(source), ""], ["--unknown"], ["a", "b", "c"]]:
        result = subprocess.run(["bash", script, *args], env=env, text=True, capture_output=True)
        assert result.returncode == 2 and "Usage:" in result.stderr, result
    print("ok   invalid arguments refused")

print("all passed")
PY
