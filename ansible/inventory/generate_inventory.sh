#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-inventory/generated/tailscale.yml}"
mkdir -p "$(dirname "$OUTPUT")"

python3 - "$OUTPUT" <<'PY'
import json
import atexit
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile

output = pathlib.Path(sys.argv[1])
azure_config_dir = pathlib.Path(tempfile.mkdtemp(prefix="phase8-azure-", dir="/run"))
os.chmod(azure_config_dir, 0o700)
os.environ["AZURE_CONFIG_DIR"] = str(azure_config_dir)


def cleanup_azure_cli() -> None:
    subprocess.run(["az", "logout"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    shutil.rmtree(azure_config_dir, ignore_errors=True)


atexit.register(cleanup_azure_cli)
status = json.loads(subprocess.check_output(["tailscale", "status", "--json"], text=True))
resource_group = os.environ.get("AZURE_RESOURCE_GROUP", "rg-hybrid-infra-lab-ha")
cm_identity_name = os.environ.get("CM_MANAGED_IDENTITY_NAME", "id-cm-ha")
workload_identity_name = os.environ.get("WORKLOAD_MANAGED_IDENTITY_NAME", "id-workload-ha")
cm_identity_client_id = os.environ.get("CM_MANAGED_IDENTITY_CLIENT_ID")
identity_client_file = pathlib.Path("/etc/phase8/cm-identity-client-id")
if not cm_identity_client_id and identity_client_file.is_file():
    cm_identity_client_id = identity_client_file.read_text(encoding="utf-8").strip()
login_command = ["az", "login", "--identity", "--output", "none"]
if cm_identity_client_id:
    login_command.extend(["--client-id", cm_identity_client_id])
subprocess.run(login_command, check=True)
if not cm_identity_client_id:
    cm_identity_client_id = subprocess.check_output(
        ["az", "identity", "show", "--resource-group", resource_group, "--name", cm_identity_name, "--query", "clientId", "--output", "tsv"],
        text=True,
    ).strip()
workload_identity_client_id = subprocess.check_output(
    ["az", "identity", "show", "--resource-group", resource_group, "--name", workload_identity_name, "--query", "clientId", "--output", "tsv"],
    text=True,
).strip()
azure_vms = json.loads(
    subprocess.check_output(
        [
            "az", "vm", "list", "--show-details", "--resource-group", resource_group,
            "--query", "[].{name:name, privateIps:privateIps, database:tags.database, dataDiskSizeGb:tags.data_disk_size_gb}", "--output", "json",
        ],
        text=True,
    )
)
private_ips = {
    vm["name"].lower(): (vm.get("privateIps") or "").split(",")[0]
    for vm in azure_vms
}
database_nodes = {
    vm["name"].lower()
    for vm in azure_vms
    if vm.get("database") == "primary"
}
data_disk_sizes = {
    vm["name"].lower(): int(vm.get("dataDiskSizeGb") or 0)
    for vm in azure_vms
}
local_name = socket.gethostname().split(".", 1)[0].lower()
nodes = [status.get("Self", {})]
peers = status.get("Peer", {})
nodes.extend(peers.values() if isinstance(peers, dict) else peers)

control = []
workload = []
database = []
for node in nodes:
    if node.get("Online") is False:
        continue
    tags = node.get("Tags") or []
    host = (node.get("HostName") or node.get("DNSName") or "").rstrip(".")
    alias = host.split(".", 1)[0].lower()
    ips = node.get("TailscaleIPs") or []
    address = next((ip for ip in ips if ":" not in ip), None) or (ips[0] if ips else None)
    if not alias or not address:
        continue
    group = "control" if "tag:cm" in tags else "workload" if "tag:workload" in tags else None
    if not group:
        continue
    is_database = alias in database_nodes
    item = (alias, address, alias == local_name, is_database)
    (control if group == "control" else workload).append(item)
    if group == "workload" and alias in database_nodes:
        database.append(item)

if not control or not workload or len(database) != 1:
    raise SystemExit("Tailscale inventory must contain online tag:cm and tag:workload nodes")

lines = [
    "all:",
    "  vars:",
    "    ansible_user: azureadmin",
    "    ansible_connection: ssh",
    "    ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'",
    f"    monitoring_loki_uai_client_id: {cm_identity_client_id}",
    f"    workload_managed_identity_client_id: {workload_identity_client_id}",
    "  children:",
]
for group, hosts in (("control", control), ("workload", workload), ("database", database)):
    lines.extend((f"    {group}:", "      hosts:"))
    for alias, address, is_local, is_database in sorted(hosts):
        lines.append(f"        {alias}:")
        lines.append(f"          ansible_host: {address}")
        if is_database:
            lines.append("          is_database: true")
        private_ip = private_ips.get(alias)
        if private_ip:
            lines.append(f"          azure_private_ip: {private_ip}")
        lines.append(f"          data_disk_size_gb: {data_disk_sizes.get(alias, 0)}")
        dns_name = next(
            (node.get("DNSName", "").rstrip(".") for node in nodes
             if (node.get("HostName") or node.get("DNSName", "").rstrip(".").split(".", 1)[0]).lower() == alias),
            None,
        )
        if dns_name:
            lines.append(f"          tailscale_dns_name: {dns_name}")
        if group == "workload":
            private_ip = private_ips.get(alias)
            if not private_ip:
                raise SystemExit(f"No Azure private IP found for workload VM {alias}")
            lines.append(f"          workload_private_ip: {private_ip}")
        if is_local:
            lines.append("          ansible_connection: local")
output.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Generated Tailscale inventory: {output}")
PY
