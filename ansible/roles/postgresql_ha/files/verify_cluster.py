#!/usr/bin/python3
"""Fail closed unless exactly one authenticated Patroni primary and two replicas exist."""

from __future__ import annotations

import base64
import json
import pathlib
import ssl
import sys
import urllib.error
import urllib.request

CONFIG_PATH = pathlib.Path("/etc/phase8-postgresql/runtime.json")
PATRONI_PATH = pathlib.Path("/etc/patroni/patroni.yml")


def main() -> int:
    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    patroni = json.loads(PATRONI_PATH.read_text(encoding="utf-8"))
    auth = patroni["restapi"]["authentication"]
    credential = base64.b64encode(f"{auth['username']}:{auth['password']}".encode()).decode("ascii")
    context = ssl.create_default_context(cafile="/etc/ssl/certs/ca-certificates.crt")
    primary = []
    replicas = []
    for member in cfg["members"]:
        for endpoint, collection in (("primary", primary), ("replica", replicas)):
            request = urllib.request.Request(
                f"https://{member['dns_name']}:{cfg['patroni_api_port']}/{endpoint}",
                headers={"Authorization": f"Basic {credential}"},
            )
            try:
                with urllib.request.urlopen(request, timeout=4, context=context) as response:
                    if response.status == 200 and endpoint == "primary":
                        collection.append(member["name"])
                    elif response.status == 200 and endpoint == "replica":
                        collection.append(member["name"])
            except (urllib.error.URLError, urllib.error.HTTPError):
                pass
    if len(primary) != 1 or len(replicas) != 2:
        raise RuntimeError(f"expected 1 primary and 2 replicas, observed {len(primary)} primary and {len(replicas)} replicas")
    print(f"PostgreSQL HA healthy: primary={primary[0]}, replicas={','.join(replicas)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"PostgreSQL HA verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
