#!/usr/bin/python3
"""Render secret-bearing Patroni/app configs using runtime Key Vault retrieval."""

from __future__ import annotations

import base64
import grp
import json
import os
import pathlib
import subprocess
import tempfile
import urllib.parse
import urllib.request

CONFIG_PATH = pathlib.Path("/etc/phase8-postgresql/runtime.json")
IMDS_URL = "http://169.254.169.254/metadata/identity/oauth2/token"


def get_json(url: str, headers: dict[str, str]) -> dict:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


def atomic_write(path: pathlib.Path, contents: str, mode: int, owner: int, group: int) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and path.read_text(encoding="utf-8") == contents:
        if (path.stat().st_mode & 0o7777) != mode or path.stat().st_uid != owner or path.stat().st_gid != group:
            os.chown(path, owner, group)
            os.chmod(path, mode)
            return True
        return False
    if path.is_file():
        active = subprocess.run(["systemctl", "is-active", "--quiet", "patroni.service"], check=False).returncode == 0
        if active:
            raise RuntimeError("PostgreSQL HA credentials/config changed while Patroni is active; use a coordinated maintenance rotation")
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = pathlib.Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(contents)
            output.flush()
            os.fsync(output.fileno())
        os.chown(temporary, owner, group)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
        return True
    finally:
        temporary.unlink(missing_ok=True)


def secret(vault_uri: str, name: str, token: str) -> str:
    url = f"{vault_uri.rstrip('/')}/secrets/{urllib.parse.quote(name, safe='')}?api-version=7.4"
    value = get_json(url, {"Authorization": f"Bearer {token}"}).get("value")
    if not isinstance(value, str) or len(value) < 24 or "\n" in value:
        raise ValueError(f"Key Vault secret {name!r} is missing, too short, or malformed")
    return value


def main() -> int:
    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    token_query = urllib.parse.urlencode({
        "api-version": "2019-08-01",
        "resource": "https://vault.azure.net",
        "client_id": cfg["managed_identity_client_id"],
    })
    token = get_json(f"{IMDS_URL}?{token_query}", {"Metadata": "true"})["access_token"]
    credentials = {
        key: secret(cfg["key_vault_uri"], value, token)
        for key, value in cfg["secret_names"].items()
    }

    tls_ca = "/etc/ssl/certs/ca-certificates.crt"
    pg_parameters = {
        "listen_addresses": cfg["listen_address"],
        "port": cfg["postgresql_port"],
        "ssl": "on",
        "ssl_cert_file": "/etc/phase8/tls/tls.crt",
        "ssl_key_file": "/etc/phase8/tls/tls.key",
        "password_encryption": "scram-sha-256",
        "wal_level": "replica",
        "wal_log_hints": "on",
        "max_wal_senders": 10,
        "max_replication_slots": 10,
        "wal_keep_size": "256MB",
        "max_connections": 100,
        "unix_socket_directories": "/var/run/postgresql",
        "synchronous_commit": "on",
        "archive_mode": "on",
        "archive_timeout": cfg["archive_timeout"],
        "archive_command": "/usr/local/sbin/phase8-postgresql-archive-wal %p %f",
        "restore_command": "/usr/local/sbin/phase8-postgresql-restore-wal %f %p",
        "logging_collector": "on",
        "log_directory": "/var/log/postgresql/phase8",
        "log_filename": "postgresql-%Y-%m-%d_%H%M%S.log",
        "log_rotation_age": "1d",
        "log_rotation_size": "100MB",
    }

    patroni = {
        "scope": cfg["cluster_name"],
        "namespace": "/service/",
        "name": cfg["node_name"],
        "restapi": {
            "listen": f"{cfg['listen_address']}:{cfg['patroni_api_port']}",
            "connect_address": f"{cfg['dns_name']}:{cfg['patroni_api_port']}",
            "authentication": {"username": "patroni_api", "password": credentials["patroni_api"]},
            "certfile": "/etc/phase8/tls/tls.crt",
            "keyfile": "/etc/phase8/tls/tls.key",
            # "cafile": tls_ca,
        },
        "etcd3": {
            "hosts": [f"https://{member['dns_name']}:{cfg['etcd_client_port']}" for member in cfg["members"]],
            "protocol": "https",
            "cacert": tls_ca,
            "cert": "/etc/phase8/tls/tls.crt",
            "key": "/etc/phase8/tls/tls.key",
            "use_proxies": False,  # This line remains unchanged
        },
        "bootstrap": {
            "dcs": {
                "ttl": 30,
                "loop_wait": 10,
                "retry_timeout": 10,
                "maximum_lag_on_failover": 1048576,
                "synchronous_mode": True,
                "synchronous_mode_strict": True,
                "synchronous_node_count": 1,
                "postgresql": {
                    "use_pg_rewind": True,
                    "use_slots": True,
                    "parameters": pg_parameters,
                },
            },
            "initdb": ["--data-checksums", "--encoding=UTF8"],
            "users": {
                cfg["app_user"]: {"password": credentials["app"], "options": ["LOGIN"]},
                "replicator": {"password": credentials["replication"], "options": ["LOGIN", "REPLICATION"]},
                cfg["backup_user"]: {"password": credentials["backup"], "options": ["LOGIN", "REPLICATION"]},
            },
        },
        "postgresql": {
            "listen": f"{cfg['listen_address']}:{cfg['postgresql_port']}",
            "connect_address": f"{cfg['dns_name']}:{cfg['postgresql_port']}",
            "data_dir": cfg["data_directory"],
            "bin_dir": cfg["postgres_bin_dir"],
            "authentication": {
                "superuser": {"username": "postgres", "password": credentials["superuser"]},
                "replication": {"username": "replicator", "password": credentials["replication"]},
            },
            "use_unix_socket": True,
            "use_pg_rewind": True,
            "create_replica_methods": ["basebackup"],
            "basebackup": [{"checkpoint": "fast"}],
            "parameters": pg_parameters,
            "pg_hba": [
                "local all all peer",
                "hostssl replication replicator 100.64.0.0/10 scram-sha-256",
                f"hostssl replication {cfg['backup_user']} 100.64.0.0/10 scram-sha-256",
                f"hostssl all {cfg['app_user']} 100.64.0.0/10 scram-sha-256",
                f"hostssl replication {cfg['backup_user']} 127.0.0.1/32 scram-sha-256",
                f"hostssl all {cfg['app_user']} 127.0.0.1/32 scram-sha-256",
                "hostssl all postgres 127.0.0.1/32 scram-sha-256",
                f"hostssl all postgres {cfg['database_subnet_cidr']} scram-sha-256",
            ],
        },
        "watchdog": ({"mode": "required", "device": "/dev/watchdog", "safety_margin": 5}
                     if cfg.get("require_watchdog", False) else {"mode": "off"}),
        "tags": {"nofailover": False, "noloadbalance": False, "clonefrom": False, "nosync": False},
    }

    haproxy = [
        "global", "    log /dev/log local0", "    maxconn 1024", "    user haproxy", "    group haproxy", "    daemon", "",
        "defaults", "    log global", "    mode tcp", "    timeout connect 3s", "    timeout client 1m", "    timeout server 1m", "",
        "frontend postgresql_write", f"    bind 127.0.0.1:{cfg['haproxy_port']}", "    default_backend patroni_primary", "",
        "backend patroni_primary", "    http-check expect status 200",
    ]
    auth = base64.b64encode(f"patroni_api:{credentials['patroni_api']}".encode()).decode("ascii")
    haproxy.append(f'    http-check send meth GET uri /primary ver HTTP/1.1 hdr Host "{cfg["dns_name"]}" hdr Authorization "Basic {auth}"')
    for member in cfg["members"]:
        haproxy.append(
            f"    server {member['name']} {member['dns_name']}:{cfg['postgresql_port']} "
            f"check port {cfg['patroni_api_port']} check-ssl verify required "
            f"ca-file {tls_ca} verifyhost {member['dns_name']} inter 2s fall 3 rise 2"
        )

    pgpass_rows = [
        ("127.0.0.1", cfg["haproxy_port"], cfg["database"], cfg["app_user"], credentials["app"]),
        ("127.0.0.1", cfg["haproxy_port"], "replication", cfg["backup_user"], credentials["backup"]),
        ("127.0.0.1", cfg["haproxy_port"], "*", "postgres", credentials["superuser"]),
        ("127.0.0.1", cfg["postgresql_port"], "*", "postgres", credentials["superuser"]),
    ]
    def pgpass_escape(value: str) -> str:
        return value.replace("\\", "\\\\").replace(":", "\\:")

    pgpass = "\n".join(":".join((*row[:4], pgpass_escape(row[4]))) for row in pgpass_rows) + "\n"

    postgres_gid = grp.getgrnam("postgres").gr_gid
    sample_gid = grp.getgrnam("sample-app").gr_gid
    changed = False
    changed |= atomic_write(pathlib.Path("/etc/patroni/patroni.yml"), json.dumps(patroni, separators=(",", ":")) + "\n", 0o640, 0, postgres_gid)
    changed |= atomic_write(pathlib.Path("/etc/phase8-postgresql/app.json"), json.dumps({
        "host": "127.0.0.1", "port": cfg["haproxy_port"], "database": cfg["database"],
        "user": cfg["app_user"], "password": credentials["app"], "sslmode": "require",
    }, separators=(",", ":")) + "\n", 0o640, 0, sample_gid)
    changed |= atomic_write(pathlib.Path("/etc/phase8-postgresql/backup.json"), json.dumps({
        "storage_account": cfg["storage_account"], "container": cfg["backup_container"],
        "cluster_name": cfg["cluster_name"], "managed_identity_client_id": cfg["backup_managed_identity_client_id"],
        "retention_days": cfg["backup_retention_days"],
    }, separators=(",", ":")) + "\n", 0o640, 0, postgres_gid)
    changed |= atomic_write(pathlib.Path("/var/lib/postgresql/.pgpass"), pgpass, 0o600, postgres_gid, postgres_gid)
    haproxy_gid = grp.getgrnam("haproxy").gr_gid
    changed |= atomic_write(pathlib.Path("/etc/haproxy/haproxy.cfg"), "\n".join(haproxy) + "\n", 0o640, 0, haproxy_gid)
    print("updated" if changed else "unchanged")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # Never log credentials, access tokens, or Key Vault response bodies.
        import sys
        print(f"PostgreSQL runtime secret/config preparation failed: {type(error).__name__}", file=sys.stderr)
        raise SystemExit(1)
