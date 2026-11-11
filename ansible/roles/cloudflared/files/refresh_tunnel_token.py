#!/usr/bin/python3
"""Fetch a short-lived access token and Tunnel Token without logging secrets."""

import json
import grp
import os
import pathlib
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request

IMDS_URL = (
    "http://169.254.169.254/metadata/identity/oauth2/token"
    "?api-version=2019-08-01&resource="
)
VAULT_SCOPE = urllib.parse.quote("https://vault.azure.net", safe="")
TOKEN_DIRECTORY = pathlib.Path("/run/cloudflared")
TOKEN_PATH = TOKEN_DIRECTORY / "token"
CONFIG_PATH = pathlib.Path("/etc/cloudflared/runtime.json")


def get_json(url: str, headers: dict[str, str]) -> dict:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


def main() -> int:
    temporary: pathlib.Path | None = None
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        vault_uri = config["key_vault_uri"].rstrip("/")
        secret_name = urllib.parse.quote(config["secret_name"], safe="")
        account_id = config["account_id"]
        tunnel_id = config["tunnel_id"]

        identity_url = (
            IMDS_URL + VAULT_SCOPE + "&client_id="
            + urllib.parse.quote(config["managed_identity_client_id"], safe="")
        )
        identity = get_json(identity_url, {"Metadata": "true"})
        vault_token = identity["access_token"]
        secret_url = (
            f"{vault_uri}/secrets/{secret_name}?api-version=7.4"
        )
        secret = get_json(secret_url, {"Authorization": f"Bearer {vault_token}"})
        api_token = secret["value"]

        tunnel_url = (
            "https://api.cloudflare.com/client/v4/accounts/"
            f"{account_id}/cfd_tunnel/{tunnel_id}/token"
        )
        tunnel = get_json(tunnel_url, {"Authorization": f"Bearer {api_token}"})
        token = tunnel.get("result")
        if (
            tunnel.get("success") is not True
            or not isinstance(token, str)
            or not token
            or len(token) > 8192
            or "\n" in token
        ):
            raise RuntimeError("Cloudflare did not return a Tunnel Token")

        TOKEN_DIRECTORY.mkdir(mode=0o750, parents=True, exist_ok=True)
        cloudflared_gid = grp.getgrnam("cloudflared").gr_gid
        os.chown(TOKEN_DIRECTORY, 0, cloudflared_gid)
        os.chmod(TOKEN_DIRECTORY, 0o750)
        temporary = TOKEN_DIRECTORY / f".token-{secrets.token_hex(8)}"
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o440)
        with os.fdopen(fd, "w", encoding="utf-8") as token_file:
            token_file.write(token)
            token_file.flush()
            os.fsync(token_file.fileno())
        os.chown(temporary, 0, cloudflared_gid)
        os.chmod(temporary, 0o440)
        os.replace(temporary, TOKEN_PATH)
        temporary = None
        return 0
    except (KeyError, OSError, ValueError, urllib.error.URLError, RuntimeError) as error:
        print(f"Tunnel credential refresh failed: {type(error).__name__}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
