#!/usr/bin/python3
"""Small production-pattern demo: DB-backed readiness, inventory and idempotent purchases."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import psycopg2
from psycopg2.extras import RealDictCursor

CONFIG_PATH = Path(os.environ.get("PHASE8_DB_CONFIG", "/etc/phase8-postgresql/app.json"))
CONFIG = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def connect():
    return psycopg2.connect(
        host=CONFIG["host"],
        port=CONFIG["port"],
        dbname=CONFIG["database"],
        user=CONFIG["user"],
        password=CONFIG["password"],
        sslmode=CONFIG.get("sslmode", "require"),
        connect_timeout=3,
        application_name="phase8-sample-app",
    )


class Handler(BaseHTTPRequestHandler):
    def respond(self, status: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in ("/healthz", "/readyz"):
            try:
                with connect() as connection, connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
                    cursor.fetchone()
                self.respond(200, b"ok\n", "text/plain")
            except Exception:
                self.respond(503, b"database unavailable\n", "text/plain")
            return

        if self.path == "/api/inventory":
            try:
                with connect() as connection, connection.cursor(cursor_factory=RealDictCursor) as cursor:
                    cursor.execute("SELECT sku, quantity, updated_at FROM inventory ORDER BY sku")
                    rows = cursor.fetchall()
                body = json.dumps(rows, default=str).encode("utf-8")
                self.respond(200, body)
            except Exception:
                self.respond(503, b'{"error":"database unavailable"}')
            return

        if self.path == "/":
            try:
                with connect() as connection, connection.cursor() as cursor:
                    cursor.execute("SELECT count(*) FROM inventory")
                    count = cursor.fetchone()[0]
                body = (
                    "<!doctype html><html><head><title>Phase 8 HA Lab</title></head>"
                    "<body><h1>Hybrid Infrastructure Lab</h1>"
                    f"<p>Application connected to PostgreSQL. Inventory SKUs: {count}</p>"
                    "<p><a href='/api/inventory'>View inventory API</a></p></body></html>"
                ).encode("utf-8")
                self.respond(200, body, "text/html; charset=utf-8")
            except Exception:
                self.respond(503, b"database unavailable\n", "text/plain")
            return

        self.respond(404, b'{"error":"not found"}')

    def do_POST(self) -> None:
        if self.path != "/api/purchase":
            self.respond(404, b'{"error":"not found"}')
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 16_384:
                self.respond(400, b'{"error":"invalid request size"}')
                return
            payload = json.loads(self.rfile.read(length))
            sku = str(payload["sku"])
            quantity = int(payload["quantity"])
            key = self.headers.get("Idempotency-Key", str(payload.get("idempotency_key", "")))
            if not key or len(key) > 160 or not sku or len(sku) > 128 or quantity < 1 or quantity > 1000:
                self.respond(400, b'{"error":"sku, quantity and Idempotency-Key are required"}')
                return

            with connect() as connection, connection.cursor(cursor_factory=RealDictCursor) as cursor:
                # Claim the idempotency key before touching stock. Concurrent retries
                # wait on the unique key and cannot decrement inventory twice.
                cursor.execute(
                    """INSERT INTO purchase_requests
                       (idempotency_key, sku, quantity, success, resulting_quantity)
                       VALUES (%s, %s, %s, false, NULL)
                       ON CONFLICT (idempotency_key) DO NOTHING
                       RETURNING idempotency_key""",
                    (key, sku, quantity),
                )
                claimed = cursor.fetchone()
                if claimed is None:
                    cursor.execute(
                        "SELECT sku, quantity, success, resulting_quantity FROM purchase_requests WHERE idempotency_key=%s",
                        (key,),
                    )
                    previous = cursor.fetchone()
                    if previous is None:
                        raise RuntimeError("idempotency row vanished")
                    if previous["sku"] != sku or previous["quantity"] != quantity:
                        self.respond(409, b'{"error":"Idempotency-Key was already used for a different request"}')
                        return
                    status = 200 if previous["success"] else 409
                    body = json.dumps({"replayed": True, **previous}).encode("utf-8")
                    self.respond(status, body)
                    return

                cursor.execute("SELECT 1 FROM inventory WHERE sku=%s", (sku,))
                if cursor.fetchone() is None:
                    self.respond(404, b'{"error":"unknown SKU"}')
                    return
                cursor.execute(
                    """UPDATE inventory SET quantity=quantity-%s, updated_at=now()
                       WHERE sku=%s AND quantity >= %s
                       RETURNING quantity""",
                    (quantity, sku, quantity),
                )
                updated = cursor.fetchone()
                if updated is None:
                    cursor.execute(
                        "UPDATE purchase_requests SET success=false WHERE idempotency_key=%s",
                        (key,),
                    )
                    self.respond(409, b'{"error":"unknown SKU or insufficient inventory"}')
                    return
                cursor.execute(
                    """UPDATE purchase_requests SET success=true, resulting_quantity=%s
                       WHERE idempotency_key=%s""",
                    (updated["quantity"], key),
                )
            body = json.dumps({"ok": True, "sku": sku, "quantity": quantity, "remaining": updated["quantity"]}).encode("utf-8")
            self.respond(201, body)
        except (ValueError, KeyError, json.JSONDecodeError):
            self.respond(400, b'{"error":"invalid JSON request"}')
        except Exception:
            self.respond(503, b'{"error":"database operation failed; retry with the same Idempotency-Key"}')

    def log_message(self, _format: str, *_args: object) -> None:
        # Avoid writing request headers or submitted values, which may contain secrets.
        super().log_message("request completed")


server = ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("PHASE8_APP_PORT", "8082"))), Handler)
server.serve_forever()
