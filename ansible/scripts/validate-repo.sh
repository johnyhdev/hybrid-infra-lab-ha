#!/usr/bin/env bash
set -euo pipefail

# Focused profiles avoid repeating unrelated Terraform/Ansible/Python checks.
# Usage: validate-repo.sh [all|terraform-identity|terraform-vmresource|ansible|ansible-security|python|shell]
PROFILE="${1:-all}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANSIBLE_DIR="$ROOT/ansible"
export ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles:$ANSIBLE_DIR/playbooks/roles"
export ANSIBLE_INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

require_commands() {
  local command
  for command in "$@"; do
    command -v "$command" >/dev/null 2>&1 || { echo "Missing required command: $command" >&2; exit 2; }
  done
}

validate_terraform_root() {
  local root="$1"
  require_commands terraform
  terraform -chdir="$root" fmt -check -recursive
  terraform -chdir="$root" init -backend=false -input=false
  terraform -chdir="$root" validate
}

validate_ansible() {
  require_commands ansible-playbook ansible-lint python3
  ansible-lint "$ANSIBLE_DIR"
  local playbook
  for playbook in \
    site.yml baseline.yml application.yml monitoring.yml monitoring-health.yml \
    workload-prepare.yml postgresql-ha.yml application-services.yml \
    cpu-test-setup.yml cpu-test-start.yml drift-check.yml \
    remediation/restart-nginx.yml remediation/restart-cloudflared.yml \
    remediation/restart-alloy.yml remediation/restart-postgresql.yml \
    remediation/stop-cpu-test.yml; do
    if [[ -f "$ANSIBLE_DIR/playbooks/$playbook" ]]; then
      ansible-playbook -i "$ANSIBLE_INVENTORY" \
        "$ANSIBLE_DIR/playbooks/$playbook" --syntax-check
    fi
  done
  while IFS= read -r -d '' yaml_file; do
    python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8"))' "$yaml_file"
  done < <(find "$ANSIBLE_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) \
    -not -path '*/.terraform/*' -print0)
}

validate_ansible_security() {
  require_commands checkov
  checkov -d "$ANSIBLE_DIR" --framework ansible --config-file "$ROOT/.checkov.yaml" --quiet
}

validate_python() {
  require_commands python3
  python3 -m compileall -q \
    "$ANSIBLE_DIR/roles/cloudflared/files" \
    "$ANSIBLE_DIR/roles/recovery_dispatcher/files" \
    "$ANSIBLE_DIR/roles/postgresql_ha/files" \
    "$ANSIBLE_DIR/roles/sample_app/files" \
    "$ANSIBLE_DIR/tests"
  python3 -m unittest discover -s "$ANSIBLE_DIR/tests" -v
}

validate_shell() {
  require_commands bash
  while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file"
  done < <(find "$ANSIBLE_DIR" "$ROOT/bootstrap" -type f -name '*.sh' -print0)
  bash "$ANSIBLE_DIR/tests/test_inventory_retry.sh"
}

case "$PROFILE" in
  terraform-identity)
    validate_terraform_root "$ROOT/terraform/01-identity"
    ;;
  terraform-vmresource)
    validate_terraform_root "$ROOT/terraform/02-vmresource"
    ;;
  ansible)
    validate_ansible
    ;;
  ansible-security)
    validate_ansible_security
    ;;
  python)
    validate_python
    ;;
  shell)
    validate_shell
    ;;
  all)
    require_commands terraform ansible-playbook ansible-lint python3 bash
    validate_terraform_root "$ROOT/terraform/01-identity"
    validate_terraform_root "$ROOT/terraform/02-vmresource"
    validate_ansible
    while IFS= read -r -d '' yaml_file; do
      python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8"))' "$yaml_file"
    done < <(find "$ROOT" -type f \( -name '*.yml' -o -name '*.yaml' \) \
      -not -path '*/.terraform/*' -not -path '*/.git/*' -print0)
    validate_shell
    validate_python
    git -C "$ROOT" diff --check
    ;;
  *)
    echo "Unknown validation profile: $PROFILE" >&2
    echo "Usage: $0 [all|terraform-identity|terraform-vmresource|ansible|ansible-security|python|shell]" >&2
    exit 2
    ;;
esac

printf 'PASS: Phase 8 %s validation completed. No deployment was performed.\n' "$PROFILE"
