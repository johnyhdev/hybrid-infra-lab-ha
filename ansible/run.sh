#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

echo "========================================"
echo "Generating Tailscale inventory"
echo "========================================"

./inventory/generate_inventory.sh inventory/generated/tailscale.yml

echo
echo "========================================"
echo "Checking Workload Nodes Connectivity"
echo "========================================"

# Retry up to 15 times, waiting 10 seconds each time (about 2.5 minutes total)
MAX_RETRIES=15
RETRY_COUNT=0

# Ping workload nodes over Tailscale SSH.
until ansible workload \
  -i inventory/generated/tailscale.yml \
  -u azureadmin \
  -m ping -o >/dev/null 2>&1; do

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: Workload nodes are not reachable after $((MAX_RETRIES * 10)) seconds."
    exit 1
  fi

  echo "Workload nodes are not ready yet. Retrying in 10s ($RETRY_COUNT/$MAX_RETRIES)..."
  sleep 10
done

echo "All Workload nodes are online and ready!"

echo
echo "========================================"
echo "Running Ansible"
echo "========================================"

sudo install -d -o azureadmin -g adm -m 2750 /var/log/ansible
sudo chgrp adm /var/log/ansible/site.log 2>/dev/null || true
sudo chmod 0640 /var/log/ansible/site.log 2>/dev/null || true
umask 027
ansible-playbook \
  -i inventory/generated/tailscale.yml \
  playbooks/site.yml 2>&1 | tee -a /var/log/ansible/site.log