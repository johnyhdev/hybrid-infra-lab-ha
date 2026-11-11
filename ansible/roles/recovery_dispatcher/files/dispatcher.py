#!/usr/bin/env python3
"""Loopback-only, fixed-action recovery dispatcher with Key Vault-free ephemeral auth."""

from __future__ import annotations

import email.utils
import hmac
import json
import os
import pathlib
import re
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONFIG_PATH = pathlib.Path("/etc/phase8-dispatcher/config.json")
TOKEN_PATH = pathlib.Path("/run/phase8-dispatcher/alertmanager.token")
STATE_PATH = pathlib.Path("/var/lib/phase8-dispatcher/state.json")
AUDIT_PATH = pathlib.Path("/var/log/phase8-dispatcher/audit.jsonl")
LOCK = threading.Lock()
MAX_BODY = 1_000_000
RUN_TIMEOUT_SECONDS = 300

ACTIONS = {
    "NginxUnavailable": ("restart_nginx", "/usr/local/sbin/phase8-recovery-restart-nginx", "workload"),
    "CloudflaredUnavailable": ("restart_cloudflared", "/usr/local/sbin/phase8-recovery-restart-cloudflared", "workload"),
    "NodeExporterDown": ("restart_node_exporter", "/usr/local/sbin/phase8-recovery-restart-node-exporter", "control:workload"),
    "PostgreSQLUnavailable": ("restart_postgresql", "/usr/local/sbin/phase8-recovery-restart-postgresql", "database"),
    "WorkloadCPUTestCritical": ("stop_cpu_test_service", "/usr/local/sbin/phase8-recovery-stop-cpu-test", "workload"),
}
INSTANCE_RE = re.compile(r"^vm-(?:cm|workload)-[a-z0-9-]{1,48}$")


def config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def azure_token(cfg: dict) -> str:
    query = urllib.parse.urlencode({
        "api-version": "2019-08-01",
        "resource": "https://storage.azure.com/",
        "client_id": cfg["managed_identity_client_id"],
    })
    request = urllib.request.Request(
        f"http://169.254.169.254/metadata/identity/oauth2/token?{query}",
        headers={"Metadata": "true"},
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)["access_token"]


def blob_request(method: str, url: str, token: str, headers: dict | None = None, body: bytes | None = None):
    request_headers = {
        "Authorization": f"Bearer {token}",
        "x-ms-date": email.utils.formatdate(usegmt=True),
        "x-ms-version": "2023-11-03",
    }
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)
    return urllib.request.urlopen(request, timeout=8)


def blob_url(cfg: dict) -> str:
    account = cfg["storage_account_name"]
    container = urllib.parse.quote(cfg["state_container"], safe="")
    blob = urllib.parse.quote(cfg["state_blob"], safe="")
    return f"https://{account}.blob.core.windows.net/{container}/{blob}"


def ensure_state_blob(url: str, token: str) -> None:
    try:
        with blob_request("HEAD", url, token):
            return
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    try:
        with blob_request(
            "PUT", url, token,
            {"x-ms-blob-type": "BlockBlob", "Content-Type": "application/json"},
            b"{}",
        ):
            return
    except urllib.error.HTTPError as error:
        if error.code != 409:
            raise


def acquire_lease(url: str, token: str) -> str:
    lease_id = str(uuid.uuid4())
    with blob_request(
        "PUT", url + "?comp=lease", token,
        {
            "x-ms-lease-action": "acquire",
            "x-ms-lease-duration": "60",
            "x-ms-proposed-lease-id": lease_id,
            "Content-Length": "0",
        },
        b"",
    ) as response:
        return response.headers["x-ms-lease-id"]


def read_state(url: str, token: str, lease: str) -> dict:
    with blob_request("GET", url, token, {"x-ms-lease-id": lease}) as response:
        value = json.loads(response.read().decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("state root must be object")
    return value


def write_state(url: str, token: str, lease: str, state: dict) -> None:
    payload = json.dumps(state, sort_keys=True, separators=(",", ":")).encode("utf-8")
    with blob_request(
        "PUT", url, token,
        {
            "x-ms-lease-id": lease,
            "x-ms-blob-type": "BlockBlob",
            "Content-Type": "application/json",
        },
        payload,
    ):
        pass


def release_lease(url: str, token: str, lease: str) -> None:
    with blob_request(
        "PUT", url + "?comp=lease", token,
        {"x-ms-lease-action": "release", "x-ms-lease-id": lease, "Content-Length": "0"},
        b"",
    ):
        pass


def audit(event: dict) -> None:
    AUDIT_PATH.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n"
    fd = os.open(AUDIT_PATH, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o640)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(encoded)
        stream.flush()
        os.fsync(stream.fileno())


def alert_action(alert: dict) -> tuple[str, str, str, str] | None:
    if not isinstance(alert, dict) or alert.get("status") != "firing":
        return None
    labels = alert.get("labels")
    if not isinstance(labels, dict):
        return None
    alert_name = labels.get("alertname")
    if alert_name == "WorkloadCPUTestCritical" and labels.get("component") != "phase8-cpu-test":
        return None
    action = ACTIONS.get(alert_name)
    if not action:
        return None
    instance = labels.get("instance")
    if not isinstance(instance, str) or not INSTANCE_RE.fullmatch(instance):
        return None
    return action[0], action[1], action[2], instance


def process_alert(alert: dict) -> tuple[bool, str]:
    selected = alert_action(alert)
    if selected is None:
        labels = alert.get("labels", {}) if isinstance(alert, dict) else {}
        alert_name = labels.get("alertname", "unknown") if isinstance(labels, dict) else "unknown"
        audit({"time": int(time.time()), "alert": str(alert_name)[:160], "result": "unmapped_or_nonfiring"})
        return False, "unmapped_or_nonfiring"
    action_id, wrapper, _allowed_group, instance = selected
    labels = alert.get("labels", {})
    alert_name = str(labels.get("alertname", "unknown"))[:160]
    instance = str(labels.get("instance", "unknown"))[:128]
    state_key = f"{action_id}:{alert_name}:{instance}"
    cfg = config()
    token = azure_token(cfg)
    url = blob_url(cfg)
    ensure_state_blob(url, token)
    lease = acquire_lease(url, token)
    try:
        state = read_state(url, token, lease)
        now = time.time()
        previous = float(state.get(state_key, 0))
        cooldown = int(cfg.get("cooldown_seconds", 300))
        if now - previous < cooldown:
            audit({"time": int(now), "action_id": action_id, "alert": alert_name, "instance": instance, "result": "cooldown"})
            return False, "cooldown"

        state[state_key] = now
        write_state(url, token, lease, state)
        audit({"time": int(now), "action_id": action_id, "alert": alert_name, "instance": instance, "result": "accepted"})
        try:
            result = subprocess.run(
                ["/usr/bin/sudo", "-n", wrapper, instance],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=RUN_TIMEOUT_SECONDS,
                check=False,
            )
            success = result.returncode == 0
            audit({"time": int(time.time()), "action_id": action_id, "alert": alert_name, "instance": instance, "result": "success" if success else "failed", "returncode": result.returncode})
            return success, "executed" if success else "recovery_failed"
        except subprocess.TimeoutExpired:
            audit({"time": int(time.time()), "action_id": action_id, "alert": alert_name, "instance": instance, "result": "timeout"})
            return False, "timeout"
    finally:
        release_lease(url, token, lease)


class Handler(BaseHTTPRequestHandler):
    server_version = "Phase8Dispatcher"

    def log_message(self, _format: str, *_args) -> None:
        return

    def respond(self, status: int, message: str) -> None:
        body = json.dumps({"status": message}).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path != "/healthz" or self.client_address[0] not in {"127.0.0.1", "::1"}:
            self.respond(404, "not_found")
            return
        try:
            config()
            TOKEN_PATH.stat()
            self.respond(200, "ok")
        except (OSError, ValueError, KeyError):
            self.respond(503, "not_ready")

    def do_POST(self) -> None:
        if self.path != "/alert" or self.client_address[0] not in {"127.0.0.1", "::1"}:
            self.respond(404, "not_found")
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
            audit({"time": int(time.time()), "result": "rejected_content_type"})
            self.respond(415, "content_type")
            return
        try:
            token = TOKEN_PATH.read_text(encoding="utf-8").strip()
        except OSError:
            audit({"time": int(time.time()), "result": "rejected_auth_unavailable"})
            self.respond(503, "auth_unavailable")
            return
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {token}"
        if not hmac.compare_digest(supplied, expected):
            audit({"time": int(time.time()), "result": "rejected_auth"})
            self.respond(401, "unauthorized")
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > MAX_BODY:
                raise ValueError("invalid size")
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("payload root must be an object")
            alerts = payload.get("alerts")
            if not isinstance(alerts, list) or len(alerts) > 5:
                raise ValueError("alerts must be a bounded list")
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
            audit({"time": int(time.time()), "result": "rejected_payload"})
            self.respond(400, "invalid_payload")
            return

        try:
            with LOCK:
                results = [process_alert(alert) for alert in alerts]
        except Exception as error:  # Fail closed; do not reveal token/response details.
            audit({"time": int(time.time()), "result": "dispatcher_error", "error_type": type(error).__name__})
            self.respond(503, "recovery_unavailable")
            return
        if any(not ok and reason not in {"unmapped_or_nonfiring", "cooldown"} for ok, reason in results):
            self.respond(500, "recovery_failed")
            return
        self.respond(202, "accepted")


def main() -> None:
    config()
    server = ThreadingHTTPServer(("127.0.0.1", 9088), Handler)
    server.daemon_threads = True
    server.serve_forever()


if __name__ == "__main__":
    main()
