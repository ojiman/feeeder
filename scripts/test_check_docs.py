#!/usr/bin/env python3
"""Tests for scripts/check_docs.py. Needs only Python 3 (no network: the issue states are given by hand)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_docs  # noqa: E402


def write(root, relative, text):
    path = os.path.join(root, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


class LinkTests(unittest.TestCase):
    def test_a_broken_relative_link_is_reported_with_its_line(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/a.md", "first\nsee [b](b.md) and [gone](gone.md#x)\n")
            write(root, "docs/b.md", "ok\n")
            problems = check_docs.link_problems(root)
            self.assertEqual(len(problems), 1)
            self.assertIn("docs/a.md:2", problems[0])
            self.assertIn("gone.md", problems[0])

    def test_outside_links_anchors_code_blocks_and_inline_code_are_not_checked(self):
        with tempfile.TemporaryDirectory() as root:
            text = "[web](https://example.com/x) [mail](mailto:a@b.c) [here](#top)\n```\n[no](nowhere.md)\n```\n`[no](nowhere.md)`\n"
            write(root, "README.md", text)
            self.assertEqual(check_docs.link_problems(root), [])

    def test_a_link_from_the_repository_root_and_a_parent_folder_resolve(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "AGENTS.md", "x\n")
            write(root, "docs/sub/a.md", "[up](../../AGENTS.md) [abs](/AGENTS.md)\n")
            self.assertEqual(check_docs.link_problems(root), [])


class DecisionTests(unittest.TestCase):
    def test_a_number_used_twice_and_a_record_missing_from_the_index_are_reported(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/decisions/0001-a.md", "# a\n")
            write(root, "docs/decisions/0002-b.md", "# b\n")
            write(root, "docs/decisions/0002-c.md", "# c\n")
            write(root, "docs/decisions/README.md", "| [0001](0001-a.md) | a |\n| [0002](0002-b.md) | b |\n")
            problems = check_docs.decision_problems(root)
            self.assertTrue(any("0002" in p and "twice" in p for p in problems))
            self.assertTrue(any("0002-c.md" in p and "index" in p for p in problems))

    def test_a_consistent_set_has_no_problem(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/decisions/0001-a.md", "# a\n")
            write(root, "docs/decisions/README.md", "| [0001](0001-a.md) | a |\n")
            self.assertEqual(check_docs.decision_problems(root), [])


class IssueReferenceTests(unittest.TestCase):
    def test_the_issues_named_in_status_marks_are_found(self):
        text = "a `[未実装 #139（×）、#140（Esc）]` b `[実装済み。いまは「一覧」。#139]` c `[not built #7]` d `[built]` e [link](#3)\n"
        found = check_docs.status_mark_issues(text)
        self.assertEqual(sorted(n for n, _ in found), [7, 139, 139, 140])

    def test_roadmap_issues_count_except_in_the_history(self):
        base = "https://github.com/o/r/issues/"
        text = (f"## Now\n[#1]({base}1) and [#2]({base}2)\n## Done (history)\n[#3]({base}3)\n## Candidates\n[#4]({base}4)\n")
        self.assertEqual(sorted(n for n, _ in check_docs.roadmap_issues(text)), [1, 2, 4])

    def test_a_closed_issue_in_a_mark_or_the_active_roadmap_is_reported_and_an_open_one_is_not(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/specification.md", "rule `[未実装 #10]` and `[not built #11]`\n")
            base = "https://github.com/o/r/issues/"
            write(root, "docs/roadmap.md", f"## Now\n[#12]({base}12)\n## Done (history)\n[#13]({base}13)\n")
            states = {10: "OPEN", 11: "CLOSED", 12: "CLOSED", 13: "CLOSED"}
            problems = check_docs.issue_problems(root, lambda n: states[n])
            joined = "\n".join(problems)
            self.assertIn("#11", joined)
            self.assertIn("#12", joined)
            self.assertNotIn("#10", joined)
            self.assertNotIn("#13", joined)

    def test_an_issue_that_cannot_be_found_is_reported(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/specification.md", "`[未実装 #99]`\n")

            def lookup(number):
                raise LookupError("no such issue")

            problems = check_docs.issue_problems(root, lookup)
            self.assertTrue(any("#99" in p for p in problems))


if __name__ == "__main__":
    unittest.main(verbosity=2)
