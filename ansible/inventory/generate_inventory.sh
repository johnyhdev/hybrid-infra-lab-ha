#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP="rg-hybrid-infra-lab"
OUTPUT="inventory/generated/azure.yml"

mkdir -p "$(dirname "$OUTPUT")"

CURRENT_HOSTNAME=$(hostname)

# Query Azure CLI for VM names and private IP addresses
CM_VMS=$(az vm list \
  --resource-group "$RESOURCE_GROUP" \
  --show-details \
  --query "[?tags.role=='control-manager'].{name:name, ip:privateIps}" \
  -o json)

WORKLOAD_VMS=$(az vm list \
  --resource-group "$RESOURCE_GROUP" \
  --show-details \
  --query "[?tags.role=='workload'].{name:name, ip:privateIps}" \
  -o json)

cat > "$OUTPUT" <<EOF
all:
  vars:
    ansible_user: azureadmin
    ansible_ssh_private_key_file: ~/.ssh/vm-cm-workload
    ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'
  children:
    control:
      hosts:
EOF

# Parse JSON for the control group
echo "$CM_VMS" | jq -c '.[]' | while read -r vm; do
  NAME=$(echo "$vm" | jq -r '.name')
  # Select the first IP if Azure returns a comma-separated list
  IP=$(echo "$vm" | jq -r '.ip | split(",")[0] // .ip')
  
  if [ "$NAME" = "$CURRENT_HOSTNAME" ]; then
    cat >> "$OUTPUT" <<EOF
        ${NAME}:
          ansible_host: ${IP}
          ansible_connection: local
EOF
  else
    cat >> "$OUTPUT" <<EOF
        ${NAME}:
          ansible_host: ${IP}
EOF
  fi
done

cat >> "$OUTPUT" <<EOF
    workload:
      hosts:
EOF

# Parse JSON for the workload group
echo "$WORKLOAD_VMS" | jq -c '.[]' | while read -r vm; do
  NAME=$(echo "$vm" | jq -r '.name')
  IP=$(echo "$vm" | jq -r '.ip | split(",")[0] // .ip')
  cat >> "$OUTPUT" <<EOF
        ${NAME}:
          ansible_host: ${IP}
EOF
done

echo "Inventory generated:"
cat "$OUTPUT"