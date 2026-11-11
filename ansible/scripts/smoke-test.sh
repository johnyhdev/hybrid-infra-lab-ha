#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
INVENTORY="inventory/generated/tailscale.yml"
[[ -s "$INVENTORY" ]] || { echo "Missing generated Tailscale inventory" >&2; exit 2; }

TAILSCALE_IP="$(tailscale ip -4 | head -n 1)"
for endpoint in \
  "http://${TAILSCALE_IP}:9090/-/ready" \
  "http://${TAILSCALE_IP}:9093/-/ready" \
  "http://${TAILSCALE_IP}:3000/api/health" \
  "http://127.0.0.1:9088/healthz"; do
  curl --fail --silent --show-error --max-time 5 "$endpoint" >/dev/null
  printf 'PASS %s\n' "$endpoint"
done

ansible-playbook -i "$INVENTORY" playbooks/monitoring-health.yml
ansible all -i "$INVENTORY" -m ping -o
ansible workload -i "$INVENTORY" -m command -a 'curl -fsS http://127.0.0.1:8081/healthz' -o
ansible database -i "$INVENTORY" -m command -a 'pg_isready' -o
printf 'PASS: Phase 8 local smoke checks completed\n'
