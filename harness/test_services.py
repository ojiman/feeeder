"""Negative-result validation tests; deliberately poisoned evidence must fail."""
import unittest

from service_preflight import evaluate_network


class NetworkEvidenceTests(unittest.TestCase):
    def observation(self, connected=False, sent=False, error=1):
        return {"connect": connected, "sent": sent, "errno": error}

    def test_matching_positive_control_and_denial_pass(self):
        self.assertEqual(evaluate_network(True, 0, self.observation(), 0), "PASS")

    def test_failed_positive_control_is_blocked(self):
        self.assertEqual(evaluate_network(False, 0, self.observation(), 0), "BLOCKED")

    def test_no_probe_observation_is_blocked(self):
        self.assertEqual(evaluate_network(True, 1, None, 0), "BLOCKED")

    def test_connection_refused_is_not_sandbox_denial(self):
        self.assertEqual(evaluate_network(True, 0, self.observation(error=61), 0), "FAIL")

    def test_connected_without_sending_is_still_failure(self):
        self.assertEqual(evaluate_network(True, 0, self.observation(connected=True), 0), "FAIL")

    def test_false_denial_with_actual_delivery_fails(self):
        self.assertEqual(evaluate_network(True, 0, self.observation(), 1), "FAIL")

    def test_probe_crash_is_not_denial(self):
        self.assertEqual(evaluate_network(True, -9, self.observation(), 0), "FAIL")


if __name__ == "__main__":
    unittest.main()
