# One-time bootstrap and PostgreSQL secrets

This note covers prerequisites that are **not** automated by this repository. It does not authorize applying infrastructure. The normal CI pipeline still requires protected-environment approval when configured and does not yet order identity and VM Terraform roots automatically.

## Prerequisites

1. Set up the pre-existing Terraform remote-state resource group, Storage Account, container and Azure RBAC for the OIDC principal used by GitHub; the two roots use separate blobs. Configure GitHub OIDC/Azure credentials, Tailscale WIF/policy, required GitHub variables, SSH public key and Cloudflare Tunnel configuration. Verify regional and VM-family quota and available SKU/zone capacity.
2. Apply the reviewed identity root first, then generate a fresh VM-resource plan and apply it only after review/approval. This order is not yet automated by the current independent workflows. For an existing installation, coordinate migration and verify the plans: the Key Vault private endpoint and DNS must work before turning off the existing route. Do not remove working network access first.
3. Key Vault secret administration requires a host with network reachability and DNS resolving the vault hostname to the private endpoint, such as a trusted control manager on the VNet. An Internet-connected workstation or GitHub-hosted runner alone cannot reach a private-only vault. An authorized administrator needs the appropriate Key Vault secret data-plane write role (for example, **Key Vault Secrets Officer**, scoped to the vault), separately from the workload's read-only identity. Allow for RBAC propagation. Review and remove temporary administrative access after enrollment according to policy.

## Set five PostgreSQL secrets once

Perform the following interactively on the trusted host as the authorized administrator. Do **not** paste passwords into shell commands, chat, source control, Terraform variables/state, workflow logs or process arguments. `read -s` hides typing and the CLI receives a root-readable temporary file path, not the password argument. Use a protected host and run as a user trusted to handle these credentials. The temporary files and Azure CLI session are placed in `/dev/shm` and deleted on exit; other privileged users on the host may still access them. Shell variables are not a hardware security boundary.

```bash
# Run in a new interactive Bash session on the trusted VNet-connected host.
set -euo pipefail
umask 077
workdir=$(mktemp -d /dev/shm/phase8-bootstrap.XXXXXXXX)
trap 'rm -rf -- "$workdir"' EXIT
export AZURE_CONFIG_DIR="$workdir/azure"
mkdir -m 700 "$AZURE_CONFIG_DIR"
az login --use-device-code --output none

vault_name="kvhybridinfra26111010"  # Set your vault name, not a secret.
for name in \
  postgresql-superuser-password \
  postgresql-replication-password \
  postgresql-app-password \
  postgresql-backup-password \
  postgresql-patroni-api-password; do
  read -r -s -p "Value for $name (at least 24 characters): " value
  printf '\n'
  if (( ${#value} < 24 )); then
    unset value
    echo "Value is too short; aborting." >&2
    exit 1
  fi
  printf '%s' "$value" > "$workdir/value"
  unset value
  az keyvault secret set --vault-name "$vault_name" --name "$name" \
    --file "$workdir/value" --encoding utf-8 --only-show-errors --output none
  rm -f -- "$workdir/value"
done
printf 'PostgreSQL secrets enrolled.\n'
```

This creates a **new version** if a name already exists; run it only for first enrollment, not as a deployment step or a credential-rotation procedure. If interrupted, some names may already exist; do not blindly rerun it against a live cluster. Updating vault values alone does not rotate PostgreSQL credentials: active Patroni configuration changes are intentionally refused until a coordinated, tested rotation is performed. Values must be at least 24 characters and must not contain newlines. Keep copies according to your credential-recovery policy; do not send them to an assistant.

## Key Vault call frequency and costs

The PostgreSQL Ansible role runs `prepare_runtime.py` once **per database member per execution of the role**. Each successful execution obtains one identity token from Azure IMDS and performs **five Key Vault secret GETs**. With three members that is normally 15 secret reads per role run. It is not executed for each application query, WAL archive, database failover or Patroni process restart in the current code. Failed/partial runs and operator/API calls add requests; no global rate cap is implemented. Three-member examples: 10 role runs/day ≈ 4,500 reads/month (30 days); 1,000 runs/day ≈ 450,000 reads/month. These are estimates, not quotas, bills, or guarantees.

The Cloudflare token refresher is separate: each connector reads its Key Vault secret on service start and on a 12-hour timer, plus retries or restarts. Azure Storage operations for Loki, dispatcher state, PostgreSQL WAL and backups are separate from Key Vault operations. Consult current Azure pricing and monitor actual operation counts before setting budgets/alerts; this repository does not establish a spending cap.
