#!/usr/bin/python3
"""Upload/download PostgreSQL base-backup and WAL objects using VM managed identity."""

from __future__ import annotations

import base64
import email.utils
import hashlib
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CONFIG_PATH = pathlib.Path("/etc/phase8-postgresql/backup.json")
IMDS_URL = "http://169.254.169.254/metadata/identity/oauth2/token"
API_VERSION = "2023-11-03"
BLOCK_SIZE = 8 * 1024 * 1024
SAFE_NAME = re.compile(r"^[A-Za-z0-9._-]{1,128}$")


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(BLOCK_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def remote_sha256(cfg: dict, token: str, key: str) -> str:
    digest = hashlib.sha256()
    with request("GET", blob_url(cfg, key), token) as response:
        while chunk := response.read(BLOCK_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def load_config() -> dict:
    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    for key in ("storage_account", "container", "cluster_name", "managed_identity_client_id"):
        if not cfg.get(key):
            raise ValueError(f"backup config missing {key}")
    return cfg


def access_token(cfg: dict) -> str:
    query = urllib.parse.urlencode({
        "api-version": "2019-08-01",
        "resource": "https://storage.azure.com/",
        "client_id": cfg["managed_identity_client_id"],
    })
    request = urllib.request.Request(
        f"{IMDS_URL}?{query}",
        headers={"Metadata": "true"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)["access_token"]


def blob_url(cfg: dict, key: str, query: str = "") -> str:
    quoted_key = "/".join(urllib.parse.quote(part, safe="") for part in key.split("/"))
    path = f"/{cfg['container']}" + (f"/{quoted_key}" if key else "")
    url = f"https://{cfg['storage_account']}.blob.core.windows.net{path}"
    return f"{url}?{query}" if query else url


def headers(token: str, extra: dict[str, str] | None = None) -> dict[str, str]:
    result = {
        "Authorization": f"Bearer {token}",
        "x-ms-date": email.utils.formatdate(usegmt=True),
        "x-ms-version": API_VERSION,
    }
    if extra:
        result.update(extra)
    return result


def request(method: str, url: str, token: str, extra: dict[str, str] | None = None, body: bytes | None = None):
    req = urllib.request.Request(url, data=body, headers=headers(token, extra), method=method)
    return urllib.request.urlopen(req, timeout=120)


def upload_file(cfg: dict, token: str, local_path: pathlib.Path, key: str, immutable: bool) -> None:
    size = local_path.stat().st_size
    if size <= BLOCK_SIZE:
        data = local_path.read_bytes()
        digest = base64.b64encode(hashlib.md5(data).digest()).decode("ascii")
        try:
            with request("PUT", blob_url(cfg, key), token, {
                "x-ms-blob-type": "BlockBlob",
                "Content-Type": "application/octet-stream",
                "Content-MD5": digest,
                **({"If-None-Match": "*"} if immutable else {}),
            }, data):
                return
        except urllib.error.HTTPError as error:
            if error.code != 412 or not immutable:
                raise
            if remote_sha256(cfg, token, key) != hashlib.sha256(data).hexdigest():
                raise RuntimeError(f"Existing immutable Blob differs from local file: {key}")
            return

    block_ids: list[str] = []
    with local_path.open("rb") as source:
        index = 0
        while chunk := source.read(BLOCK_SIZE):
            raw_id = f"{index:08d}".encode("ascii")
            block_id = base64.b64encode(raw_id).decode("ascii")
            query = urllib.parse.urlencode({"comp": "block", "blockid": block_id})
            with request("PUT", blob_url(cfg, key, query), token, {
                "Content-Length": str(len(chunk)),
                "Content-Type": "application/octet-stream",
            }, chunk):
                pass
            block_ids.append(block_id)
            index += 1
    block_list = ET.Element("BlockList")
    for block_id in block_ids:
        ET.SubElement(block_list, "Latest").text = block_id
    payload = ET.tostring(block_list, encoding="utf-8", xml_declaration=True)
    query = urllib.parse.urlencode({"comp": "blocklist"})
    try:
        with request("PUT", blob_url(cfg, key, query), token, {
            "Content-Type": "application/xml",
            "Content-Length": str(len(payload)),
            **({"If-None-Match": "*"} if immutable else {}),
        }, payload):
            pass
    except urllib.error.HTTPError as error:
        if error.code != 412 or not immutable:
            raise
        if remote_sha256(cfg, token, key) != sha256_file(local_path):
            raise RuntimeError(f"Existing immutable Blob differs from local file: {key}")


def archive_wal(cfg: dict, token: str, source: pathlib.Path, filename: str) -> None:
    if not SAFE_NAME.fullmatch(filename):
        raise ValueError("unsafe WAL filename")
    key = f"{cfg['cluster_name']}/wal/{filename}"
    upload_file(cfg, token, source, key, immutable=True)


def restore_wal(cfg: dict, token: str, filename: str, destination: pathlib.Path) -> None:
    if not SAFE_NAME.fullmatch(filename):
        raise ValueError("unsafe WAL filename")
    key = f"{cfg['cluster_name']}/wal/{filename}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.restore-tmp")
    try:
        with request("GET", blob_url(cfg, key), token) as response, temporary.open("wb") as output:
            while chunk := response.read(BLOCK_SIZE):
                output.write(chunk)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, destination)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            temporary.unlink(missing_ok=True)
            raise FileNotFoundError(filename) from error
        raise
    finally:
        temporary.unlink(missing_ok=True)


def upload_backup_directory(cfg: dict, token: str, directory: pathlib.Path, timestamp: str) -> None:
    if not SAFE_NAME.fullmatch(timestamp):
        raise ValueError("unsafe backup identifier")
    prefix = f"{cfg['cluster_name']}/base/{timestamp}"
    manifest: dict[str, object] = {"cluster": cfg["cluster_name"], "backup_id": timestamp, "files": {}}
    for path in sorted(directory.iterdir()):
        if not path.is_file():
            continue
        if path.name == "manifest.json":
            continue
        digest = sha256_file(path)
        manifest["files"][path.name] = {"size": path.stat().st_size, "sha256": digest}
        upload_file(cfg, token, path, f"{prefix}/{path.name}", immutable=True)
    manifest_path = directory / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    upload_file(cfg, token, manifest_path, f"{prefix}/manifest.json", immutable=True)
    marker = directory / ".last-success.json"
    marker.write_text(json.dumps({
        "cluster": cfg["cluster_name"],
        "backup_id": timestamp,
        "success_timestamp": int(__import__("datetime").datetime.now(__import__("datetime").timezone.utc).timestamp()),
    }, sort_keys=True) + "\n", encoding="utf-8")
    upload_file(cfg, token, marker, f"{cfg['cluster_name']}/metadata/last-success.json", immutable=False)


def get_latest_backup_success(cfg: dict, token: str) -> int:
    key = f"{cfg['cluster_name']}/metadata/last-success.json"
    try:
        with request("GET", blob_url(cfg, key), token) as response:
            value = json.loads(response.read().decode("utf-8"))
        return int(value["success_timestamp"])
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return 0
        raise


def download_backup_directory(cfg: dict, token: str, backup_id: str, destination: pathlib.Path) -> None:
    if not SAFE_NAME.fullmatch(backup_id):
        raise ValueError("unsafe backup identifier")
    prefix = f"{cfg['cluster_name']}/base/{backup_id}/"
    query = urllib.parse.urlencode({"restype": "container", "comp": "list", "prefix": prefix})
    with request("GET", blob_url(cfg, "", query), token) as response:
        xml_payload = response.read()
    root = ET.fromstring(xml_payload)
    names = [entry.text for entry in root.findall(".//Blob/Name") if entry.text]
    if not names or not any(name == prefix + "manifest.json" for name in names):
        raise FileNotFoundError("complete backup manifest not found")
    destination.mkdir(parents=True, exist_ok=True)
    for blob_name in names:
        relative = blob_name[len(prefix):]
        if not relative or "/" in relative or relative in {".", ".."}:
            raise ValueError("unexpected path in backup manifest listing")
        target = destination / relative
        with request("GET", blob_url(cfg, blob_name), token) as response, target.open("wb") as output:
            while chunk := response.read(BLOCK_SIZE):
                output.write(chunk)
            output.flush()
            os.fsync(output.fileno())
    manifest_path = destination / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("cluster") != cfg["cluster_name"] or manifest.get("backup_id") != backup_id:
        raise RuntimeError("backup manifest identity does not match the requested cluster/backup")
    for filename, details in manifest.get("files", {}).items():
        if not SAFE_NAME.fullmatch(filename):
            raise RuntimeError("backup manifest contains an unsafe filename")
        file_path = destination / filename
        if not file_path.is_file() or file_path.stat().st_size != int(details["size"]) or sha256_file(file_path) != details["sha256"]:
            raise RuntimeError(f"backup integrity verification failed for {filename}")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        raise SystemExit("usage: postgres_blob.py archive <path> <wal-name> | restore <wal-name> <path> | upload-backup <dir> <backup-id> | download-backup <backup-id> <dir>")
    cfg = load_config()
    token = access_token(cfg)
    operation = argv[1]
    if operation == "archive" and len(argv) == 4:
        archive_wal(cfg, token, pathlib.Path(argv[2]), argv[3])
    elif operation == "restore" and len(argv) == 4:
        restore_wal(cfg, token, argv[2], pathlib.Path(argv[3]))
    elif operation == "upload-backup" and len(argv) == 4:
        upload_backup_directory(cfg, token, pathlib.Path(argv[2]), argv[3])
    elif operation == "latest-success" and len(argv) == 2:
        print(get_latest_backup_success(cfg, token))
    elif operation == "download-backup" and len(argv) == 4:
        download_backup_directory(cfg, token, argv[2], pathlib.Path(argv[3]))
    else:
        raise SystemExit("invalid PostgreSQL backup command")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as error:  # Do not log tokens or SAS URLs.
        print(f"PostgreSQL Blob backup operation failed: {type(error).__name__}", file=sys.stderr)
        raise SystemExit(1)
