# Phase 8 — One-time external setup

Complete the external identity/policy prerequisites before apply. Enroll the Cloudflare secret after the VM root creates the private Key Vault endpoint and before approving the protected Ansible deployment. Never put credential values in Git, Terraform variables/state, cloud-init, workflow artifacts, or logs. Keep the Azure administrator **public** key input: Azure Linux VM creation requires an SSH public key; routine management uses Tailscale SSH and does not use its matching private key.

## 1. Azure and GitHub

1. Use the existing Azure OIDC/Entra federation and protected apply Environments. Verify the apply identity is scoped only to the lab resource group and required state storage.
2. Create/retain the existing `id-cm-ha` identity and create `id-workload-ha` through Terraform identity apply. Do not copy one identity's federated trust to the other.
3. Set protected GitHub Environment variables: `AZURE_KEY_VAULT_NAME`, `LOKI_STORAGE_ACCOUNT_NAME`, `WORKLOAD_MANAGED_IDENTITY_NAME`, `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE`, `TAILSCALE_WORKLOAD_CLIENT_ID`, `TAILSCALE_WORKLOAD_AUDIENCE`, `TAILSCALE_PACKAGE_VERSION`, `AZURE_CLI_VERSION`, `TAILSCALE_CI_CLIENT_ID`, `TAILSCALE_CI_AUDIENCE`, and `UBUNTU_IMAGE_VERSION`. Add the VM-root values to every Terraform plan/apply/destroy Environment.
4. Keep required `SSH_PUBLIC_KEY` as the public provisioning key. Do not add an SSH private key for Ansible or CI.
5. Protect `main`, require independent review, enable the existing Terraform apply and `tailscale-ci-ha` Environment approvals, and restrict deployment branches. PR jobs must not receive apply credentials.

## 2. Tailscale WIF and access policy

1. Apply the full repository policy in the Tailscale Admin Console before provisioning. Verify tag owners and least-privilege SSH grants for `tag:cm`, `tag:workload`, and `tag:ci`.
2. Create separate Azure WIF credentials in Tailscale for `id-cm-ha` → `tag:cm` and `id-workload-ha` → `tag:workload`. Use each identity's principal ID as the subject and the exact Azure issuer/audience shown for your tenant. Never store a JWT or auth key.
3. Keep GitHub CI WIF separate; it may join as `tag:ci` only. Do not allow CI to enroll as CM/workload or write the Tailscale policy unless its separate policy workflow requires that permission.
4. Enable MagicDNS and Tailscale HTTPS certificates for the tailnet. Confirm each node has a stable `*.ts.net` DNS name; Ansible uses that name for certificates and the dynamic Tailscale address for management.
5. Validate positive and negative policy cases: admin/CI/CM to allowed nodes and ports; unauthorized role pairs denied. No broad `*` grant.

## 3. Cloudflare Tunnel Pool and WAF bootstrap

Cloudflare connectors are on workload VMs. Tunnel replicas do not replace the per-node Nginx proxy/backend health design.

1. Create a Cloudflare API Token restricted to the required account and the least-privilege read permission accepted by the Tunnel Token endpoint (prefer Cloudflare Tunnel Read / cloudflared Connector Read; do not grant write or zone-wide DNS/WAF unless a separately reviewed automation needs it). Confirm current API permission names and rate limits in the Cloudflare dashboard.
2. After the VM apply creates the Key Vault private endpoint, enroll the API Token as the secret named by `cloudflare_api_token_secret_name` (default `cloudflare-api-token`) before approving the protected Ansible deployment job. Use a separately approved, temporary `Key Vault Secrets Officer` assignment scoped to this vault. A designated operator can transfer the secret file over Tailscale SSH to an online CM, use Azure CLI with `AZURE_CONFIG_DIR` under `/run` to authenticate interactively and run `az keyvault secret set --file` (never `--value`), then remove both the temporary file and CLI cache and revoke the temporary role. The control subnet is allowed to reach only the private endpoint; public network access stays disabled. Terraform grants only the workload Managed Identity secret-read access and never creates/writes the secret value. Never put the token in command arguments, Terraform variables, cloud-init, CI logs, or shell history.

	Example on the authorized workstation and then the CM (replace placeholders; the secret file must already be protected locally):

	```bash
	ssh azureadmin@<CM_TAILSCALE_DNS> 'sudo install -d -o azureadmin -g azureadmin -m 0700 /run/secret-enrollment'
	scp <SECURE_LOCAL_TOKEN_FILE> azureadmin@<CM_TAILSCALE_DNS>:/run/secret-enrollment/cloudflare-api-token
	# On the CM:
	chmod 600 /run/secret-enrollment/cloudflare-api-token
	export AZURE_CONFIG_DIR="$(mktemp -d /run/az-secret.XXXXXX)"
	az login --use-device-code
	az keyvault secret set --vault-name "<VAULT_NAME>" --name cloudflare-api-token --file /run/secret-enrollment/cloudflare-api-token --output none
	az logout
	rm -f /run/secret-enrollment/cloudflare-api-token
	rmdir /run/secret-enrollment
	rm -rf "$AZURE_CONFIG_DIR"
	unset AZURE_CONFIG_DIR
	```
3. Record token expiry and owner. Rotate by creating a replacement, updating the Key Vault secret version, verifying runtime refresh, then revoking the old token. The API Token and returned Tunnel Token are persistent credentials—not short-lived—and must never be logged or copied to GitHub variables/secrets.
4. Create one remotely managed Tunnel per configured Tunnel Pool and record its distinct Tunnel UUID. Configure its origin service to the local workload proxy `http://localhost:8081`. Add each pool's non-secret IDs, member VM names, region, service group, desired replicas and maximum in `ansible/group_vars/workload/cloudflare.yml`. Set `cloudflared_package_version` to the exact approved Cloudflare repository version; do not use an uncontrolled latest upgrade.
5. Do not exceed the verified Cloudflare connector limit for one Tunnel (design target: 25). Add a new Tunnel Pool with a distinct ID for additional capacity. If multiple Tunnel IDs serve one hostname, configure and test explicit traffic steering; health-aware multi-pool steering may require the optional paid Cloudflare Load Balancing product.
6. Configure Cloudflare DNS hostname(s) to the Tunnel, enable the account/zone WAF protections and HTTPS/redirect policy. Do not create public VM IPs or direct-origin firewall rules. Test that the origin cannot be reached directly.

## 4. Key Vault and storage outputs

- After identity apply, verify the Key Vault exists with RBAC authorization, public access denied by its firewall, and private endpoint DNS resolving from the VNet.
- Confirm `id-workload-ha` has only Key Vault Secrets User on the designated vault; it must not write or list unrelated secrets.
- After VM/network apply, verify the private Loki Storage account/container and private endpoint exist; `id-cm-ha` has only Blob Data Contributor at that account scope.
- Copy the resulting storage account name and CM/workload identity client IDs into the protected GitHub variables and Ansible non-secret group variables. Never copy secret values.

## 5. Version and capacity values

- Query Azure for an exact Ubuntu 24.04 ARM64 image version available in the selected region and set `UBUNTU_IMAGE_VERSION`; the VM module rejects `latest`.
- Choose an exact stable Tailscale `x.y.z` release supported by Ubuntu 24.04 ARM64 for `TAILSCALE_PACKAGE_VERSION`. The pinned release's official installer configures the signed package repository and installs that exact version.
- Find the exact Azure CLI APT package version on Microsoft's signed Noble repository (`apt-cache madison azure-cli`) and set `AZURE_CLI_VERSION`; the CM bootstrap installs only that version.
- Confirm the exact approved APT package versions are available for Ubuntu 24.04 ARM64 (use the signed Ubuntu/Grafana/Cloudflare repositories), then replace `REPLACE_` values in `ansible/group_vars/all.yml` and `ansible/group_vars/workload/cloudflare.yml`. The required pins are Nginx, Python 3, PostgreSQL 16, Prometheus, Alertmanager, Grafana, Alloy, and cloudflared. Loki is pinned to 3.5.0 with the official ARM64 checksum. Keep changes reviewed with compatibility/rollback planning.
- Obtain the Node Exporter ARM64 release SHA-256 from the official release checksum list and set `node_exporter_sha256.arm64` in Ansible variables. Do not copy a checksum from an unverified mirror.
- Set `monitoring_loki_sha256_arm64` in `ansible/group_vars/control.yml` from the official Loki `SHA256SUMS` for the pinned version. The monitoring playbook verifies it before installing.
- `WORKLOAD_MANAGED_IDENTITY_NAME` and `AZURE_KEY_VAULT_NAME` must match the Terraform identity root. The private Loki storage name must satisfy Azure's global account-name rules.
- Loki Blob storage uses ZRS. Confirm the selected Azure region supports zone-redundant standard Storage before planning; use another approved zone-redundant option only through a reviewed Terraform change.

## 6. Notifications

The repository includes local Alertmanager routing to the fixed recovery dispatcher. It does not configure a chat provider because no vendor/credential flow has been selected. Choose and approve a provider before enabling external chat notifications; store provider secrets only in an approved external secret store with scoped access/rotation. A successful webhook response is not proof of human acknowledgement.

## 7. Values to customize for a clone

Set VM maps/zones/SKUs/disks, subnet CIDRs, region, Key Vault name, storage account name, Tailscale WIF identifiers, Tunnel IDs/pools, Cloudflare zone/hostnames, approved package versions, and Ubuntu ARM64 image version for the selected region. Verify Azure SKU/zone/VM/disk quotas, subnet capacity, Cloudflare account limits/rates, DNS ownership, and expected cost before apply. One-node maps require `ha_mode=false` and are explicitly non-HA. A map/count change is Terraform provisioning, not autoscaling.
