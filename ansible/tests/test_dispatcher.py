import importlib.util
import pathlib
import unittest

SOURCE = pathlib.Path(__file__).parents[1] / "roles" / "recovery_dispatcher" / "files" / "dispatcher.py"
SPEC = importlib.util.spec_from_file_location("phase8_dispatcher", SOURCE)
DISPATCHER = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(DISPATCHER)


class DispatcherAllowlistTests(unittest.TestCase):
    def test_known_service_alert_maps_to_fixed_wrapper(self):
        alert = {
            "status": "firing",
            "fingerprint": "abc123",
            "labels": {"alertname": "NginxUnavailable", "instance": "vm-workload-01"},
        }
        self.assertEqual(
            DISPATCHER.alert_action(alert),
            ("restart_nginx", "/usr/local/sbin/phase8-recovery-restart-nginx", "workload", "vm-workload-01"),
        )

    def test_missing_or_noncanonical_instance_does_not_map(self):
        missing = {"status": "firing", "labels": {"alertname": "NginxUnavailable"}}
        malformed = {"status": "firing", "labels": {"alertname": "NginxUnavailable", "instance": "../../etc"}}
        self.assertIsNone(DISPATCHER.alert_action(missing))
        self.assertIsNone(DISPATCHER.alert_action(malformed))

    def test_unknown_alert_does_not_map_to_a_command(self):
        alert = {"status": "firing", "labels": {"alertname": "UnexpectedCommand"}}
        self.assertIsNone(DISPATCHER.alert_action(alert))

    def test_cpu_test_requires_fixed_component_label(self):
        bad = {"status": "firing", "labels": {"alertname": "WorkloadCPUTestCritical", "component": "production"}}
        good = {"status": "firing", "labels": {"alertname": "WorkloadCPUTestCritical", "component": "phase8-cpu-test", "instance": "vm-workload-02"}}
        self.assertIsNone(DISPATCHER.alert_action(bad))
        self.assertEqual(DISPATCHER.alert_action(good)[0], "stop_cpu_test_service")

    def test_resolved_alert_never_triggers_recovery(self):
        alert = {"status": "resolved", "labels": {"alertname": "NginxUnavailable"}}
        self.assertIsNone(DISPATCHER.alert_action(alert))


if __name__ == "__main__":
    unittest.main()
