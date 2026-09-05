"""Tests for probe preparation; these are not H acceptance evidence."""
import tempfile
import unittest
from pathlib import Path

from preflight import clean_environment, profile_text


class PreparationTests(unittest.TestCase):
    def test_environment_is_allowlist_not_blacklist(self):
        with tempfile.TemporaryDirectory() as directory:
            result = clean_environment(Path(directory))
        self.assertEqual(set(result), {"PATH", "HOME", "TMPDIR", "LANG", "CODEX_HOME"})
        self.assertEqual(result["PATH"], "/usr/bin:/bin:/usr/sbin:/sbin")

    def test_verifier_has_no_source_write_and_no_network(self):
        import tomllib
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            config = tomllib.loads(profile_text(root, "verifier"))
        policy = config["permissions"]["probe"]
        self.assertEqual(policy["filesystem"][str(root / "source")], "read")
        self.assertEqual(policy["filesystem"][str(root / "output")], "write")
        self.assertFalse(policy["network"]["enabled"])
        self.assertEqual(policy["filesystem"][":root"], "deny")
        self.assertEqual(policy["filesystem"][":slash_tmp"], "write")
        self.assertEqual(policy["filesystem"]["/private/tmp"], "write")
        self.assertNotIn("extends", policy)

    def test_writer_can_write_source_output_and_shared_temporary_area(self):
        import tomllib
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            policy = tomllib.loads(profile_text(root, "writer"))["permissions"]["probe"]
        writable = {key for key, value in policy["filesystem"].items() if value == "write"}
        self.assertEqual(writable, {str(root / "source"), str(root / "output"), ":slash_tmp", "/private/tmp"})

    def test_protected_role_roots_cannot_live_in_shared_temporary_area(self):
        for root in (Path("/private/tmp/worker"), Path("/tmp/worker")):
            with self.subTest(root=root), self.assertRaises(ValueError):
                profile_text(root, "writer")

    def test_unknown_role_is_rejected(self):
        with self.assertRaises(ValueError):
            profile_text(Path("/tmp/example"), "owner")


if __name__ == "__main__":
    unittest.main()
