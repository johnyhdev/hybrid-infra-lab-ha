#!/usr/bin/env bash
set -Eeuo pipefail

readonly RELEASE_SHA="${1:-}"
readonly ARCHIVE="${2:-}"
readonly SHA_FILE="${3:-}"
# Deployment layout defaults. Override through PHASE8_* environment variables
# only when matching cloud-init/Alloy paths and permissions are updated too.
readonly DEPLOY_USER="${PHASE8_DEPLOY_USER:-${SUDO_USER:-$(id -un)}}"
readonly DEPLOY_PRIMARY_GROUP="${PHASE8_DEPLOY_PRIMARY_GROUP:-$(id -gn "$DEPLOY_USER")}"
# Alloy is added to adm by the Ansible log-collector role so it can read this log.
readonly DEPLOY_LOG_GROUP="${PHASE8_DEPLOY_LOG_GROUP:-adm}"
readonly STATE_ROOT="${PHASE8_STATE_ROOT:-/var/lib/phase8}"
readonly RELEASE_ROOT="$STATE_ROOT/releases"
readonly LAST_GOOD="${PHASE8_LAST_GOOD_LINK:-$STATE_ROOT/last-good}"
readonly CURRENT="${PHASE8_CURRENT_LINK:-$STATE_ROOT/current}"
readonly DEPLOY_LOCK="${PHASE8_DEPLOY_LOCK:-$STATE_ROOT/deploy.lock}"
readonly LOG_DIR="${PHASE8_DEPLOY_LOG_DIR:-/var/log/ansible}"
readonly LOG_FILE="${PHASE8_DEPLOY_LOG_FILE:-$LOG_DIR/site.log}"
readonly ALLOY_TEXTFILE_DIR="${PHASE8_ALLOY_TEXTFILE_DIR:-/var/lib/alloy/textfile}"
readonly CONTROLLER_LINK="${PHASE8_CONTROLLER_LINK:-/home/$DEPLOY_USER/hybrid-infra-lab-ha}"
readonly INVENTORY_NAME=inventory/generated/tailscale.yml

if [[ ! "$RELEASE_SHA" =~ ^[0-9a-f]{40,64}$ || -z "$ARCHIVE" || -z "$SHA_FILE" ]]; then
  echo "Usage: $0 <approved-commit-sha> <release.tar.gz> <release.tar.gz.sha256>" >&2
  exit 2
fi

mkdir -p "$RELEASE_ROOT"
exec 9>"$DEPLOY_LOCK"
flock -n 9 || { echo "another approved release deployment is already running" >&2; exit 3; }
sudo install -d -o "$DEPLOY_USER" -g "$DEPLOY_LOG_GROUP" -m 2750 "$LOG_DIR"
sudo touch "$LOG_FILE"
sudo chown "$DEPLOY_USER:$DEPLOY_LOG_GROUP" "$LOG_FILE"
sudo chmod 0640 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { printf '[release %s] %s\n' "$RELEASE_SHA" "$*"; }

write_deploy_metric() {
  local failed="$1"
  local rollback_failed="${2:-0}"
  local temporary
  temporary="$(mktemp)"
  printf 'phase8_ansible_release_deploy_failed{release_sha="%s"} %s\nphase8_ansible_release_rollback_failed %s\nphase8_ansible_release_deploy_info{release_sha="%s"} 1\n' \
    "$RELEASE_SHA" "$failed" "$rollback_failed" "$RELEASE_SHA" > "$temporary"
  if [[ -d "$ALLOY_TEXTFILE_DIR" ]]; then
    sudo install -o root -g alloy -m 0640 "$temporary" "$ALLOY_TEXTFILE_DIR/phase8_deployment.prom" || true
  fi
  rm -f "$temporary"
}

atomic_link() {
  local target="$1" link="$2" tmp="${2}.next"
  ln -sfn "$target" "$tmp"
  mv -Tf "$tmp" "$link"
}

on_unhandled_error() {
  local status="$1"
  log "unhandled controller error (exit=$status); no further rollout will be attempted"
  write_deploy_metric 1
  exit "$status"
}

activate_controller_path() {
  local controller="$CONTROLLER_LINK"
  if [[ -d "$controller" && ! -L "$controller" ]]; then
    local legacy="$RELEASE_ROOT/legacy-checkout-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$controller" "$legacy"
  fi
  atomic_link "$CURRENT" "$controller"
}

trap 'on_unhandled_error "$?"' ERR

release_dir="$RELEASE_ROOT/$RELEASE_SHA"
previous_dir=""
if [[ -L "$LAST_GOOD" ]]; then
  previous_dir="$(readlink -f "$LAST_GOOD")"
fi

if [[ ! -d "$release_dir" ]]; then
  [[ -f "$ARCHIVE" && -f "$SHA_FILE" ]] || { log "release archive/checksum is missing"; exit 2; }
  (cd "$(dirname "$ARCHIVE")" && sha256sum --check "$(basename "$SHA_FILE")")
  if tar -tzf "$ARCHIVE" | awk 'BEGIN{bad=0} /^\// || /(^|\/)\.\.(\/|$)/ {bad=1} END{exit bad}'; then
    :
  else
    log "release archive contains unsafe paths"
    exit 2
  fi
  staging="$RELEASE_ROOT/.staging-$RELEASE_SHA-$$"
  rm -rf "$staging"
  install -d -o "$DEPLOY_USER" -g "$DEPLOY_PRIMARY_GROUP" -m 0750 "$staging"
  tar --no-same-owner --no-same-permissions -xzf "$ARCHIVE" -C "$staging"
  [[ -f "$staging/.phase8-release-sha" ]] || { rm -rf "$staging"; log "release commit marker missing"; exit 2; }
  [[ "$(cat "$staging/.phase8-release-sha")" == "$RELEASE_SHA" ]] || { rm -rf "$staging"; log "release commit marker mismatch"; exit 2; }
  printf '%s\n' "$RELEASE_SHA" > "$staging/.approved-release"
  chmod 0440 "$staging/.phase8-release-sha" "$staging/.approved-release"
  mv "$staging" "$release_dir"
fi

[[ "$(cat "$release_dir/.phase8-release-sha" 2>/dev/null || true)" == "$RELEASE_SHA" ]] || { log "stored release SHA mismatch"; exit 2; }
[[ "$(cat "$release_dir/.approved-release" 2>/dev/null || true)" == "$RELEASE_SHA" ]] || { log "release is not marked approved by the deployment workflow"; exit 2; }
[[ -f "$release_dir/ansible/playbooks/site.yml" ]] || { log "release does not contain Ansible playbooks"; exit 2; }

if [[ "${PHASE8_STAGE_ONLY:-0}" == "1" ]]; then
  log "approved release staged and checksum-verified; deployment not started"
  exit 0
fi

ansible_dir="$release_dir/ansible"
inventory="$ansible_dir/$INVENTORY_NAME"
log "generating live Tailscale/Azure inventory"
"$ansible_dir/inventory/generate_inventory.sh" "$inventory"

mapfile -t workload_hosts < <(
  /opt/ansible-venv/bin/ansible-inventory -i "$inventory" --list | /usr/bin/python3 -c '
import json, sys
inv=json.load(sys.stdin)
workload=inv.get("workload", {}).get("hosts", [])
hostvars=inv.get("_meta", {}).get("hostvars", {})
if isinstance(workload, dict): workload=list(workload)
items=sorted((name for name in workload if name in hostvars), key=str.casefold)
if not items: raise SystemExit("inventory has no workload hosts")
canary=next((name for name in items if not hostvars[name].get("is_database", False)), items[0])
print(canary)
for name in items:
    if name != canary: print(name)
'
)
canary="${workload_hosts[0]}"
rest_hosts=("${workload_hosts[@]:1}")
mapfile -t database_hosts < <(/opt/ansible-venv/bin/ansible-inventory -i "$inventory" --list | /usr/bin/python3 -c 'import json,sys; v=json.load(sys.stdin).get("database",{}).get("hosts",[]); print("\n".join(sorted(v if isinstance(v,list) else v.keys())))')
[[ "${#database_hosts[@]}" -eq 3 ]] || { log "requires exactly three database cluster members; refusing deploy"; exit 2; }
mapfile -t control_hosts < <(/opt/ansible-venv/bin/ansible-inventory -i "$inventory" --list | /usr/bin/python3 -c 'import json,sys; v=json.load(sys.stdin).get("control",{}).get("hosts",[]); print("\n".join(sorted(v if isinstance(v,list) else v.keys())))')
canary_observation_seconds="${PHASE8_CANARY_OBSERVATION_SECONDS:-$(/opt/ansible-venv/bin/ansible-inventory -i "$inventory" --host "$canary" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("workload_rollout_canary_observation_seconds", 30))')}"
[[ "$canary_observation_seconds" =~ ^[0-9]+$ ]] || { log "invalid canary observation duration"; exit 2; }

run_playbook() {
  local release="$1" playbook="$2" limit="$3" stage="$4"
  [[ -n "$limit" ]] || return 0
  log "stage=$stage limit=$limit"
  (cd "$release/ansible" && ANSIBLE_ROLES_PATH="$release/ansible/roles:$release/ansible/playbooks/roles" \
    /opt/ansible-venv/bin/ansible-playbook -i "$inventory" "playbooks/$playbook" --limit "$limit")
}

rollback_limit="$canary"
rollback() {
  local cause="$1"
  log "deployment failed: $cause"
  write_deploy_metric 1
  if [[ -n "$previous_dir" && -f "$previous_dir/ansible/playbooks/application-services.yml" && -f "$previous_dir/ansible/playbooks/workload-prepare.yml" ]]; then
    log "rolling back application/configuration only to last good release $(basename "$previous_dir") on $rollback_limit; database transactions and data will not be restored"
    if (cd "$previous_dir/ansible" && ANSIBLE_ROLES_PATH="$previous_dir/ansible/roles:$previous_dir/ansible/playbooks/roles" \
      /opt/ansible-venv/bin/ansible-playbook -i "$inventory" playbooks/workload-prepare.yml --limit "$rollback_limit" && \
      /opt/ansible-venv/bin/ansible-playbook -i "$inventory" playbooks/application-services.yml --limit "$rollback_limit"); then
      log "rollback completed"
      atomic_link "$previous_dir" "$CURRENT"
      activate_controller_path
    else
      log "CRITICAL: rollback failed; manual recovery is required"
      write_deploy_metric 1 1
    fi
  else
    log "CRITICAL: no previously approved successful release exists; automatic rollback is unavailable on this first rollout"
    write_deploy_metric 1 1
  fi
  exit 1
}

rollback_control() {
  local cause="$1"
  log "control-manager stage failed: $cause"
  write_deploy_metric 1
  if [[ -n "$previous_dir" && -f "$previous_dir/ansible/playbooks/baseline.yml" && -f "$previous_dir/ansible/playbooks/monitoring.yml" ]]; then
    if (cd "$previous_dir/ansible" && ANSIBLE_ROLES_PATH="$previous_dir/ansible/roles:$previous_dir/ansible/playbooks/roles" \
      /opt/ansible-venv/bin/ansible-playbook -i "$inventory" playbooks/baseline.yml --limit "$control_limit" && \
      /opt/ansible-venv/bin/ansible-playbook -i "$inventory" playbooks/monitoring.yml --limit "$control_limit"); then
      log "control-manager rollback completed"
    else
      log "CRITICAL: control-manager rollback failed; manual recovery is required"
      write_deploy_metric 1 1
    fi
  else
    log "CRITICAL: no previous control-manager release exists for rollback"
    write_deploy_metric 1 1
  fi
  exit 1
}

database_stage_failed() {
  log "CRITICAL: PostgreSQL HA configuration failed; no automatic database restore or config rollback will run"
  log "Database data is preserved. Stop application rollout and require operator review of Patroni/etcd state before any restore or failover action."
  write_deploy_metric 1 1
  exit 1
}

all_workload_limit="$(IFS=,; echo "${workload_hosts[*]}")"
if run_playbook "$release_dir" workload-prepare.yml "$all_workload_limit" prepare-workload-nodes; then :; else rollback workload-preparation; fi

control_limit="$(IFS=,; echo "${control_hosts[*]}")"
if run_playbook "$release_dir" baseline.yml "$control_limit" control-baseline; then :; else rollback_control control-baseline; fi
if run_playbook "$release_dir" monitoring.yml "$control_limit" control-monitoring; then :; else rollback_control control-monitoring; fi

database_limit="$(IFS=,; echo "${database_hosts[*]}")"
if run_playbook "$release_dir" postgresql-ha.yml "$database_limit" database-ha; then :; else database_stage_failed; fi

if run_playbook "$release_dir" application-services.yml "$canary" canary-application; then :; else rollback canary-application; fi
sleep "$canary_observation_seconds"
if /opt/ansible-venv/bin/ansible workload -i "$inventory" --limit "$canary" \
  -m ansible.builtin.uri -a "url=http://127.0.0.1:8081/readyz status_code=200" -o; then
  log "canary readiness remained healthy during observation"
else
  rollback canary-observation-health
fi
if run_playbook "$release_dir" monitoring-health.yml "$control_limit" canary-control-health; then :; else rollback canary-health; fi

if (( ${#rest_hosts[@]} > 0 )); then
  rest_limit="$(IFS=,; echo "${rest_hosts[*]}")"
  rollback_limit="$all_workload_limit"
  if run_playbook "$release_dir" application-services.yml "$rest_limit" workload-batch-application; then :; else rollback workload-batch-application; fi
fi

if (( ${#control_hosts[@]} > 0 )); then
  rollback_limit="$all_workload_limit,$control_limit"
fi

if bash "$release_dir/ansible/scripts/smoke-test.sh"; then
  log "post-deployment smoke checks passed"
else
  rollback smoke-test
fi

all_hosts=("${workload_hosts[@]}" "${control_hosts[@]}")
rollback_limit="$(IFS=,; echo "${all_hosts[*]}")"
atomic_link "$release_dir" "$CURRENT"
activate_controller_path
atomic_link "$release_dir" "$LAST_GOOD"
write_deploy_metric 0
log "release deployment succeeded; last-good is $RELEASE_SHA"
