# 09 — Clone Customization and Security Audit

This guide identifies the values a copy of this repository may need to change. It distinguishes Terraform inputs from hard-coded values and external GitHub, Azure, or Tailscale settings. Keep the checked-in defaults unchanged unless the change is intended for your copy.

## Audit scope snapshot

- Upstream checked: public template `johnyhdev/hybrid-infra-lab`, branch `main`, commit `5fea4e8` (2026-10-25). Recheck before relying on this comparison because upstream can advance.
- Local branch at audit: `t-vm-v1`, commit `f3e283f`. Compared with upstream `main`, the pre-existing tracked differences were [docs/05-github-environments.md](05-github-environments.md) and [terraform/02-vmresource/main.tf](../terraform/02-vmresource/main.tf); the latter difference is a trigger comment. Preserve local changes when syncing with upstream.
- `docs/999-johnyhdev-verify-note.md` is tracked locally and present in the public upstream tree. It contains author-specific verification output and identifiers, so do not copy those values into a clone. This audit does not edit the note or reproduce its contents. The owner should review whether it should remain public, inspect history, and rotate any actual secret if one is confirmed.
- Local Terraform state, plan, tfvars, provider cache state, and generated Ansible inventory matched ignore rules and were not listed as tracked files in the current index. Their contents were deliberately not opened. This does not establish whether a similar file appeared in earlier Git history.
- GitHub, Azure, and Tailscale live settings and complete historical secret exposure were not verified from this workspace.

## Clone isolation: do this before Terraform initialization

A fork is a separate Git repository, but it is not automatically a separate Azure deployment. A copy can still use the same backend, subscription, resource names, identities, or Tailscale tailnet if you reuse the original configuration.

1. Fork or use **Use this template** to create your own repository. Confirm `git remote -v` points to your copy. Changes in your copy do not change the upstream repository unless you open and merge a pull request there.
2. Choose an Azure subscription or a dedicated resource scope for your copy. Confirm the active context with `az account show` before deployment.
3. Create a dedicated Azure Storage backend for this copy. Update both Terraform backend files before `terraform init`; use the same storage account/container where appropriate, but keep distinct state keys for the identity and VM roots. Never point a copy at another deployment's state.
4. Choose unique lab resource and identity names. Do not apply until the Terraform plan shows only the resources and subscription intended for this copy.
5. Create copy-specific Entra federated credentials, role assignments, GitHub Environments, and Tailscale WIF credentials. Match OIDC issuer, subject, and audience exactly. Do not reuse the upstream repository's credentials or tailnet identity.
6. Update the clone URL and any network values that are specific to your environment. Follow the linked value matrix below and keep coupled values consistent.
7. Configure branch rules, environment approvals, and artifact access in GitHub. These protections are external settings; merely cloning the workflow files does not enable them.
8. Review the first plan independently. Stop if its backend, subscription, resource group, identities, or resources are not exclusively for your copy.

## Values to review or customize

| Value | Current source and behavior | Clone guidance and dependencies |
|---|---|---|
| Azure region | `location` defaults to `Central India` in [terraform/01-identity/variables.tf](../terraform/01-identity/variables.tf#L1-L5). The VM root reads the location of the existing resource group. | Override `location` for the identity root if needed, for example through `TF_VAR_location` or a local ignored `.tfvars`. Check VM SKU, image architecture, zone, quota, cost, and availability in that region. Changing this input does not edit the source default. |
| Lab resource group | `resource_group_name` defaults to `rg-hybrid-infra-lab` in [identity variables](../terraform/01-identity/variables.tf#L7-L11) and [VM variables](../terraform/02-vmresource/variables.tf#L1-L5). | Set the same copy-specific name in both roots and in [ansible/inventory/generate_inventory.sh](../ansible/inventory/generate_inventory.sh#L1-L18). Ensure the VM module points at the identity root's group. |
| Managed identity | `managed_identity_name` defaults to `id-cm` in [identity variables](../terraform/01-identity/variables.tf#L13-L17) and is also read by the VM module in [VM variables](../terraform/02-vmresource/variables.tf#L7-L11). | Keep both module inputs consistent. The identity and its RBAC assignments must be created in the copy's resource group/subscription. |
| Terraform backend | Backend resource group, account, container and state key are hard-coded in [identity backend](../terraform/01-identity/backend.tf#L1-L12) and [VM backend](../terraform/02-vmresource/backend.tf#L1-L12). | Create a new private backend and update both files before init. Keep independent keys (`hybrid-identity.tfstate` and `hybrid-vmresource.tfstate` by default); verify the account name and active subscription. Backend settings are not ordinary Terraform variables. |
| VM names, SKU, zones | `control_vms`, `workload_vms`, and `enable_load_balancer` are inputs in [terraform/02-vmresource/variables.tf](../terraform/02-vmresource/variables.tf#L49-L103). Defaults describe one CM and one workload VM. | Change VM maps only after checking region/zone/architecture/quota. Extra VM entries may require inventory, routing, firewall, and Ansible validation. Load Balancer is disabled by default and is scaffolding, not a finished backend-pool configuration. |
| Network CIDRs and names | VNet/subnet and NSG values are defined in [terraform/02-vmresource/network.tf](../terraform/02-vmresource/network.tf#L1-L105); the Tailscale route is in [tailscale/policy.hujson](../tailscale/policy.hujson#L1-L20); Ansible UFW sources are in [linux baseline](../ansible/roles/linux_baseline/tasks/main.yml#L46-L60). | Avoid overlap with existing networks. If changing an address, update all three layers together and validate the complete Tailscale policy. Review TCP ports and direction before deployment. |
| Administrator username | Terraform defaults `admin_username` to `azureadmin` in [VM variables](../terraform/02-vmresource/variables.tf#L31-L35). The username is also embedded in cloud-init, Ansible, inventory, workflow SSH commands, and Tailscale SSH policy. | Do not change only the Terraform variable. Either keep `azureadmin` or update every dependent reference consistently, then validate cloud-init and CI/Ansible access. |
| Administrator SSH public key | Required `ssh_public_key` is passed as `SSH_PUBLIC_KEY` / `TF_VAR_ssh_public_key`; see [VM variables](../terraform/02-vmresource/variables.tf#L37-L47) and [GitHub Environments](05-github-environments.md#L9-L24). | Supply only the public `.pub` line in the appropriate copy-specific Environments. Never commit a private key. Terraform's `sensitive` flag redacts output but does not encrypt state. The current public-key provisioning is not a verified emergency recovery path. |
| Repository clone URL | CM cloud-init hard-codes the upstream HTTPS URL in [bootstrap/cm-cloud-init.yaml](../bootstrap/cm-cloud-init.yaml#L160-L165). | Change this in your copy to your own HTTPS repository URL. A private repo needs an explicit, secure auth design; do not embed a PAT or token in cloud-init. Existing VMs do not automatically update an already-cloned directory. |
| GitHub Environments and OIDC | Names, secret keys, and variables are described in [docs/05-github-environments.md](05-github-environments.md#L1-L31). OIDC subjects are repository/environment-specific. | Create the documented Environments in your own repository and supply copy-specific Azure/Tailscale identifiers. Recreate Entra/Tailscale federated credentials for the exact owner/repository/environment subject. No client secret is needed for OIDC. Configure reviewers and deployment branch restrictions separately. |
| Azure RBAC | OIDC roles/scopes and setup are in [docs/03-azure-oidc-rbac.md](03-azure-oidc-rbac.md#L86-L115) and [docs/03-azure-oidc-rbac.md](03-azure-oidc-rbac.md#L303-L334). | Review scope and role necessity for each copy. Plan workflows need state access; apply/destroy identities can change resources. Do not grant subscription-wide rights to routine plan/apply identities unless explicitly justified. |
| Tailscale WIF and policy | Client IDs/audiences are inputs or GitHub variables; tags, subnet route, grants and SSH users are in [policy.hujson](../tailscale/policy.hujson#L1-L38). | Create copy-specific credentials and verify the exact subject/audience. Decide whether to use a separate tailnet. Do not reuse tags or routes in a shared tailnet without reviewing their combined effect. Apply and validate the initial policy in the Admin Console; a Git commit alone does not apply it. |
| Ansible inventory and timezone | The inventory generator hard-codes the resource group and username in [generate_inventory.sh](../ansible/inventory/generate_inventory.sh#L1-L30); timezone defaults are in [ansible/group_vars/all.yml](../ansible/group_vars/all.yml#L1-L6). | Keep inventory lookup and Terraform names aligned. The sample static inventory is illustrative; deployment generates private addresses. Change timezone if needed. Workload `*_enabled` flags currently do not conditionally skip roles. |
| Service ports and public access | Nginx proxies HTTP port 80 to loopback 8080; Node Exporter uses 9100; see [Nginx template](../ansible/roles/nginx/templates/lab.conf.j2#L1-L14) and [network rules](../terraform/02-vmresource/network.tf#L66-L105). | No public IP, custom domain, DNS zone, or TLS endpoint is configured. Port or ingress changes require coordinated Terraform, Tailscale, firewall, and Ansible changes. |
| Branch and workflow protections | Workflow triggers are checked in, but branch rules, required reviews, and Environment protection are configured in GitHub. | Use a protected `main`, independent reviewers, and narrowly scoped Environment access. Do not assume the README's approval claims are active until verified in repository settings. Treat Terraform plan files, summaries, state, cloud-init data, and artifacts as sensitive. |

## Security Posture, Design Trade-offs & Audit Findings

This repository is an educational lab, not a production-ready security baseline. It demonstrates infrastructure automation and private access patterns, with important access-control, state-protection, and reproducibility trade-offs that users must review:

- **State and Credential Management:** The CM-to-workload SSH private key and sensitive connection parameters are managed within Terraform state and cloud-init payloads. Adopters must secure backend state storage, version history, execution plans, and cloud-control planes. Note that Terraform `sensitive = true` redacts CLI logs but does not encrypt data at rest within state files.
- **CI/CD Pipeline Security:** Plan workflows triggered by pull requests request `id-token: write` and rely on environment-bound Azure credentials. Fork access and federated credential trust boundaries depend strictly on external GitHub and Entra ID configurations. Strict branch protections and reviews must be enforced to prevent untrusted code execution.
- **Execution Governance:** The destroy workflow creates and saves a plan prior to the protected destroy Environment gate, executing only after verifying artifact identity, commit, and workflow consistency. A reviewer configured on the plan Environment may approve plan generation before the summary exists; that is not destructive approval. Review the published summary before approving `terraform-destroy`. Plan artifacts contain sensitive infrastructure details and require restricted access.
- **Access Control & Privilege Boundaries:** Automation relies on privileged paths: CI reaches the CM, Ansible uses privilege escalation (`become`), and the administrative user operates with passwordless sudo. Tailscale SSH policies restrict access (`azureadmin` on `tag:cm`) and must be audited regularly against organizational least-privilege policies.
- **Automation Trade-offs (Host-Key Checking):** SSH automation uses trust-on-first-use, and generated inventory discards known-host data. This does not independently verify the initial server key. Use trusted, persistent host-key provisioning for stronger verification.
- **Software Lifecycle & Supply Chain:** Virtual machine images default to `latest` and bootstrapping scripts fetch upstream packages dynamically. Adopters requiring strict supply-chain repeatability should pin base image versions, digest hashes, and local package mirrors.
- **Network Boundary & Firewall Alignment:** The CM UFW routed policy permits forwarded traffic broadly and must be evaluated in conjunction with Azure Network Security Groups (NSGs) and Tailscale access grants.
- **Repository Hygiene:** Ensure Git history and tracking indexes are audited. `.gitignore` rules prevent new tracking but do not purge previously committed files or historical artifacts.

---

## Documentation & Operational Corrections

- The backend configuration guide requires explicit verification against local backend definitions.
- Operational runbooks omit unverified emergency paths like serial consoles in favor of standard cloud management.
- Tailscale documentation explicitly references the designated policy SSH user (`azureadmin`).
- The repository documentation accurately details implemented security controls while explicitly defining out-of-scope enterprise features.

---

## Pre-Deployment Verification Checklist

- [ ] Confirm active Git remote, branch status, and clean working tree diff.
- [ ] Verify Azure subscription context, target region, and backend storage account parameters.
- [ ] Run local Terraform formatting/validation checks and review execution plans completely.
- [ ] Validate GitHub Environment secrets, variables, and external federated trust credentials (Entra ID, Tailscale).
- [ ] Confirm branch protection rules, required reviewers, and workflow permissions.
- [ ] Never expose sensitive state, private keys, or unredacted execution plans in public channels. Rotate any compromised secrets immediately.

---

## Disclaimer & Limitation of Liability

> **IMPORTANT:** This repository and its reference architecture are provided **"AS IS"**, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. 
> 
> Adopters, organizations, and system administrators who clone, adapt, modify, or deploy this architecture into production or end-product environments assume **full and sole responsibility** for all associated risks. This includes, but is not limited to, evaluating security posture, meeting regulatory compliance standards (e.g., GDPR, ISO 27001, SOC 2), managing cloud billing, ensuring infrastructure stability, and enforcing data protection. The authors and contributors shall not be held liable for any direct, indirect, incidental, special, exemplary, or consequential damages arising from the implementation or misuse of this codebase.
