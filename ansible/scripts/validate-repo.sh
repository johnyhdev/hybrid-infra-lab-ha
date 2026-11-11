#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANSIBLE_DIR="$ROOT/ansible"
export ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles:$ANSIBLE_DIR/playbooks/roles"

for command in terraform ansible-playbook ansible-lint python3; do
  command -v "$command" >/dev/null 2>&1 || { echo "Missing required command: $command" >&2; exit 2; }
done

terraform -chdir="$ROOT/terraform/01-identity" fmt -check -recursive
terraform -chdir="$ROOT/terraform/01-identity" init -backend=false -input=false
terraform -chdir="$ROOT/terraform/01-identity" validate
terraform -chdir="$ROOT/terraform/02-vmresource" fmt -check -recursive
terraform -chdir="$ROOT/terraform/02-vmresource" init -backend=false -input=false
terraform -chdir="$ROOT/terraform/02-vmresource" validate

ansible-lint "$ANSIBLE_DIR"
for playbook in \
  site.yml baseline.yml application.yml monitoring.yml monitoring-health.yml \
  cpu-test-setup.yml cpu-test-start.yml drift-check.yml \
  remediation/restart-nginx.yml remediation/restart-cloudflared.yml \
  remediation/restart-node-exporter.yml remediation/restart-postgresql.yml \
  remediation/stop-cpu-test.yml; do
  if [[ -f "$ANSIBLE_DIR/playbooks/$playbook" ]]; then
    ansible-playbook -i "$ANSIBLE_DIR/inventory/hosts.yml" \
      "$ANSIBLE_DIR/playbooks/$playbook" --syntax-check
  fi
done

while IFS= read -r -d '' yaml_file; do
  python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8"))' "$yaml_file"
done < <(find "$ROOT" -type f \( -name '*.yml' -o -name '*.yaml' \) \
  -not -path '*/.terraform/*' -not -path '*/.git/*' -print0)

while IFS= read -r -d '' shell_file; do
  bash -n "$shell_file"
done < <(find "$ROOT/ansible" "$ROOT/bootstrap" -type f -name '*.sh' -print0)

python3 -m compileall -q \
  "$ANSIBLE_DIR/roles/cloudflared/files" \
  "$ANSIBLE_DIR/roles/recovery_dispatcher/files" \
  "$ANSIBLE_DIR/tests"
python3 -m unittest discover -s "$ANSIBLE_DIR/tests" -v

git -C "$ROOT" diff --check
printf 'PASS: Phase 8 static validation completed. No deployment was performed.\n'
