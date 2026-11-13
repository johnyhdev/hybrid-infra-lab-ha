#!/usr/bin/python3
"""Take one consistent PostgreSQL base backup from the current Patroni primary."""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

RUNTIME = pathlib.Path("/etc/phase8-postgresql/backup.json")
PATRONI_CONFIG = pathlib.Path("/etc/patroni/patroni.yml")
BLOB_TOOL = "/usr/local/lib/phase8-postgresql/postgres_blob.py"


def current_node_is_primary() -> bool:
    patroni = json.loads(PATRONI_CONFIG.read_text(encoding="utf-8"))
    auth = patroni["restapi"]["authentication"]
    cfg = json.loads(pathlib.Path("/etc/phase8-postgresql/runtime.json").read_text(encoding="utf-8"))
    request = urllib.request.Request(f"https://{cfg['dns_name']}:{cfg['patroni_api_port']}/primary")
    request.add_header("Authorization", "Basic " + __import__("base64").b64encode(
        f"{auth['username']}:{auth['password']}".encode("utf-8")
    ).decode("ascii"))
    try:
        context = ssl.create_default_context(cafile="/etc/ssl/certs/ca-certificates.crt")
        with urllib.request.urlopen(request, timeout=4, context=context) as response:
            return response.status == 200
    except (urllib.error.URLError, urllib.error.HTTPError):
        return False


def main() -> int:
    if not current_node_is_primary():
        return 0
    cfg = json.loads(pathlib.Path("/etc/phase8-postgresql/runtime.json").read_text(encoding="utf-8"))
    now = dt.datetime.now(dt.timezone.utc)
    timestamp = now.strftime("%Y%m%dT%H%M%SZ")
    backup_root = pathlib.Path(cfg["backup_temp_dir"])
    backup_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"base-{timestamp}-", dir=backup_root) as tmp:
        target = pathlib.Path(tmp)
        command = [
            f"{cfg['postgres_bin_dir']}/pg_basebackup",
            f"--dbname=host=127.0.0.1 port={cfg['haproxy_port']} user={cfg['backup_user']} dbname=replication replication=true sslmode=require",
            f"--pgdata={target}",
            "--format=tar",
            "--gzip",
            "--wal-method=stream",
            "--progress",
            "--manifest-checksums=SHA256",
            "--no-password",
        ]
        subprocess.run(command, check=True, env={**os.environ, "PGPASSFILE": "/var/lib/postgresql/.pgpass"})
        archives = sorted(target.glob("*.tar.gz"))
        if not archives or not (target / "base.tar.gz").is_file():
            raise RuntimeError("pg_basebackup did not produce the expected base archive")
        for archive in archives:
            subprocess.run(["tar", "-tzf", str(archive)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["/usr/bin/python3", BLOB_TOOL, "upload-backup", str(target), timestamp], check=True)
    success_path = backup_root / "last-success"
    temporary = backup_root / ".last-success.tmp"
    temporary.write_text(str(int(now.timestamp())) + "\n", encoding="ascii")
    os.chmod(temporary, 0o640)
    os.replace(temporary, success_path)
    print(f"PostgreSQL base backup uploaded: {timestamp}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"PostgreSQL base backup failed: {type(error).__name__}", file=sys.stderr)
        raise SystemExit(1)
