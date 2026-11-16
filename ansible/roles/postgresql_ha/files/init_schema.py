#!/usr/bin/python3
"""Idempotently create the small transactional inventory demo schema."""

from __future__ import annotations

import json
import pathlib
import sys
import time

import psycopg2
from psycopg2 import sql

APP_CONFIG = pathlib.Path("/etc/phase8-postgresql/app.json")
PATRONI_CONFIG = pathlib.Path("/etc/patroni/patroni.yml")
def main() -> int:
    app = json.loads(APP_CONFIG.read_text(encoding="utf-8"))
    patroni = json.loads(PATRONI_CONFIG.read_text(encoding="utf-8"))
    database = app["database"]
    admin_password = patroni["postgresql"]["authentication"]["superuser"]["password"]
    deadline = time.monotonic() + 180
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with psycopg2.connect(
                host=app["host"], port=app["port"], dbname="postgres",
                user="postgres", password=admin_password, sslmode=app["sslmode"],
                connect_timeout=3,
            ) as connection:
                connection.autocommit = True
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (database,))
                    if cursor.fetchone() is None:
                        cursor.execute(sql.SQL("CREATE DATABASE {} OWNER {}").format(
                            sql.Identifier(database), sql.Identifier(app["user"])
                        ))
            with psycopg2.connect(
                host=app["host"], port=app["port"], dbname=database,
                user="postgres", password=admin_password, sslmode=app["sslmode"],
                connect_timeout=3,
            ) as connection:
                with connection.cursor() as cursor:
                    cursor.execute("""
                        CREATE TABLE IF NOT EXISTS inventory (
                            sku text PRIMARY KEY,
                            quantity integer NOT NULL CHECK (quantity >= 0),
                            updated_at timestamptz NOT NULL DEFAULT now()
                        )
                    """)
                    cursor.execute("""
                        CREATE TABLE IF NOT EXISTS purchase_requests (
                            idempotency_key text PRIMARY KEY,
                            sku text NOT NULL,
                            quantity integer NOT NULL CHECK (quantity > 0),
                            success boolean NOT NULL,
                            resulting_quantity integer,
                            created_at timestamptz NOT NULL DEFAULT now()
                        )
                    """)
                    cursor.execute("""
                        INSERT INTO inventory (sku, quantity)
                        VALUES ('demo-widget', 100)
                        ON CONFLICT (sku) DO NOTHING
                    """)
            return 0
        except Exception as error:
            last_error = error
            time.sleep(3)
    raise RuntimeError(f"database schema initialization timed out ({type(last_error).__name__})")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"PostgreSQL schema initialization failed: {type(error).__name__}", file=sys.stderr)
        raise SystemExit(1)
