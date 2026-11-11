# 08 — Limitations, Security Considerations, and Cleanup

## Architecture Scope and Scaling Considerations

- **Design Scope:** This is an educational, single-region HA reference implementation under development, not a production-certified platform. Multi-zone defaults, observability and bounded recovery code are present, but live deployment, failover, RPO/RTO, secret enrollment, and acceptance evidence remain external gates. There is no autoscaling.
- **Default Resource Footprint:** Terraform defaults to two control managers and two workloads across zones 1 and 2, using Ubuntu 24.04 ARM64 (`Standard_D2ps_v6`). Exact regional image/package versions, quota, SKU/zone support, cost, DNS and Cloudflare limits must be set or verified before apply. One-node configurations require explicit `ha_mode=false` and are non-HA.
- **Network Access & Emergency Recovery:** No Public IP addresses are provisioned on virtual machines. Administrative access is strictly routed through Tailscale private mesh networking. While the administrator SSH public key is provisioned during Azure VM bootstrapping, this reference setup does not configure a separate private-key or Serial Console emergency recovery path; administrative access should never involve opening public SSH ports to the internet.
- **Identity & Credential Management:** 
  - Azure VM provisioning requires an authentication mechanism. This architecture installs the administrator SSH public key and disables password authentication. The public key is passed to workflows via `SSH_PUBLIC_KEY`; private-key material must remain strictly protected. Note that marking variables as `sensitive` in Terraform redacts output in CLI logs but does not encrypt plain text in state files.
  - The Ansible deployment workflow uses Tailscale OIDC and Tailscale SSH policy controls to reach CM peers and workloads. It does not store an administrator private key in GitHub CI secrets or generate a CM-to-workload key.
- **Pipeline Security Trade-offs:** Automation uses `StrictHostKeyChecking=accept-new` to accept a host key on first connection and reject a changed key on later connections. This does not authenticate the first connection against an independently verified fingerprint; stricter deployments should provision known host keys through a trusted channel.
- **Software Lifecycle & Scaling:** Critical package/image versions are exact-input pins and intentionally fail until required values are populated. Validate packages from their signed repositories. Workload map changes provision/replace VMs; they are not autoscaling. The 250-node limit is a design ceiling, not a tested capacity claim.
  - PostgreSQL remains a single TLS-enabled workload instance and is not clustered; backup/restore and measured RPO/RTO still require operational verification. The sample app does not use it.
  - Prometheus, Alertmanager, Grafana, Loki, Alloy, and recovery roles are implemented but not runtime-validated. Two control managers do not establish full monitoring HA or Loki data durability by themselves.
  - The optional private Azure Load Balancer is disabled by default; review its backend/network requirements and plan before enabling it.
- **Zero-Trust Scope & Repository Access:** 
  - Tailscale tags `tag:cm`, `tag:workload`, and `tag:ci` have role-scoped grants. CI access is intended for CM deployment only; audit the effective policy and WIF credentials before use.
  - The CM clones this repository using a hardcoded HTTPS URL. For private repository adoption, implement explicit authentication mechanisms (e.g., GitHub Apps or deploy keys); never embed Personal Access Tokens (PATs) in cloud-init scripts.
  - Generated Terraform plan summaries and pipeline artifacts may expose internal network topology or resource parameters. Access and retention periods must be strictly governed.
- **Deprovisioning Pipeline Behavior:** The destroy workflow creates and displays a saved destroy plan in the `terraform-vmresource-plan` Environment. The apply job then waits for approval in the protected `terraform-destroy` Environment, verifies that the plan artifact belongs to the same repository, commit, and workflow run, and applies that exact plan. Plan artifacts and summaries can contain sensitive infrastructure details; restrict access and keep retention short. A stale or failed plan must be regenerated and reviewed.

## Phase 8 implementation status

The Phase 8 code and acceptance criteria are maintained in [the Phase 8 blueprint](phase-8/PHASE-8-BLUEPRINT.md), [external setup checklist](phase-8/EXTERNAL-SETUP.md), and [test matrix](phase-8/PHASE-8-TEST-MATRIX.md). Terraform, cloud-init, Tailscale, Ansible, monitoring, Cloudflare runtime credential retrieval, bounded recovery, CI, and smoke-test code have been added. External values still contain explicit placeholders, and runtime acceptance tests remain `NOT RUN`; do not describe the platform as deployed, fully HA, or production-ready until required inputs are completed and evidence is recorded.

PostgreSQL remains a single-instance baseline; Patroni is optional future work. Cloudflare Load Balancing and NGINX Plus are not required. Cloudflare Tunnel replicas do not by themselves provide application health-aware balancing. The target Cloudflare credential exception uses Azure Key Vault plus workload Managed Identity when provider federation is unavailable; it is a persistent credential requiring scope, expiry, rotation and revocation controls. See the Phase 8 guide for current-versus-target details.

---

## Cleanup and Deprovisioning Procedures

Infrastructure cleanup spans both compute resources and core identity/state layers. **Never delete the state storage backend first**, as Terraform requires active state files to cleanly deprovision managed Azure resources.

Before executing cleanup, verify your active Azure subscription and cross-check backend configurations in both `terraform/01-identity/backend.tf` and `terraform/02-vmresource/backend.tf`. Confirm the active resource group, storage account, blob container, and state keys from the configuration for the deployment you intend to remove. Do not copy backend names from another clone or rely on names in old logs.

### A. Remove the Compute and Network Module (Module 02)

1. In the Azure Portal or via CLI, inspect the target subscription and Resource Group. Verify active context and running instances before dispatching cleanup jobs:

```powershell
az account show --output table
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --show-details --output table
az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
```

2. In GitHub Actions, navigate to **Actions → Terraform VM Resource Destroy → Run workflow** on `main`. Confirm the destructive input, inspect the generated plan summary, and approve the protected `terraform-destroy` Environment only after reviewing that plan. The workflow applies the same saved destroy plan; if the run fails or the state changes, generate and review a new plan.

3. Verify Azure has successfully deprovisioned all module-02 resources (VMs, NICs, VNets, NSGs, and optional Load Balancers):

```powershell
az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --output table
```

The foundational `terraform/01-identity` Resource Group and `id-cm` managed identity will remain intact. Do not delete the Resource Group manually while Terraform state continues to manage it.

### B. Deprovision the Identity Foundation (Module 01)

There is no dedicated automated identity destroy workflow. Deprovisioning Module 01 requires applying changes through the identity pipeline. Because `terraform/01-identity/main.tf` enforces `prevent_destroy = true` lifecycle guards on core identity resources and the Resource Group, deprovisioning requires a controlled two-step Pull Request process:

1. **First PR (Lift Protection Guard):** 
   - Remove the two `lifecycle { prevent_destroy = true }` blocks from the Resource Group and managed identity blocks in `terraform/01-identity/main.tf`. Retain all resource declarations.
   - Confirm the generated plan reports **0 to add, 0 to change, 0 to destroy**. 
   - Merge the PR and approve the `terraform-identity-apply` workflow run. This updates the state to lift destruction guards while keeping all Azure resources operational.

2. **Second PR (Remove Resources):** 
   - Remove the managed identity, its `cm_reader` role assignment, and the Resource Group resource blocks from `terraform/01-identity/main.tf` (along with any dependent outputs). Do not alter backend settings.
   - Review the generated `Terraform Identity Plan` artifact. Confirm it proposes the deletion of **only** the lab foundation resources. Stop immediately if the plan targets state storage accounts, shared subscription infrastructure, or unexpected resources.

3. **Execution & Verification:** 
   - Merge the second PR and approve `Terraform Identity Apply` in the protected environment.
   - Confirm successful apply execution and check the Azure Resource Group status:

```powershell
$groupExists = az group exists --name "<LAB_RESOURCE_GROUP>"
if ($groupExists -eq "true") {
	az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
	az identity list --resource-group "<LAB_RESOURCE_GROUP>" --output table
} else {
	"Lab Resource Group is absent."
}
```

Expect output confirming `Lab Resource Group is absent.`. If the group persists, inspect remaining resources manually. Retain both Terraform state blobs until deprovisioning is fully verified and administrative audit compliance is satisfied.

### C. Revoke External Access and Clean Artifacts

Execute these steps only after pipeline workflows no longer require access credentials:

1. **Azure RBAC Cleanup:** List and remove temporary service principal role assignments scoped to the subscription, state storage account, or resource group. Delete assignments explicitly using their Azure assignment IDs:

```powershell
az role assignment list --assignee-object-id "<SP_OBJECT_ID>" --all --query "[].{id:id,role:roleDefinitionName,scope:scope}" --output table
az role assignment delete --ids "<EXACT_LAB_ROLE_ASSIGNMENT_RESOURCE_ID>"
```

Repeat for all Service Principals associated with the environment. Verify principal ID, role name, and scope before deletion. Remove any temporary Blob Data roles granted to bootstrap administrative accounts during initial setup.

2. **Entra ID (Azure AD):** For each App Registration, remove the specific Federated Identity Credentials (`github-<environment>`) using the process outlined in Document 03. Once federated credentials are removed, safely delete the dedicated Service Principals and App Registrations, ensuring they are not shared with other active systems.

3. **GitHub Environment & Artifact Clean Hygiene:** Under **Settings → Environments**, remove secrets, variables, and deployment protection rules; delete the environments if no longer needed. Under **Actions**, purge old plan artifacts and workflow summaries. Ensure artifact retention policies are configured to minimize credential exposure risks in historical logs.

4. **Tailscale Node & Auth Revocation:** In the Tailscale Admin Console, revoke the policy GitOps credentials, `tailscale-ci` keys, and CM workload identity keys. Delete offline or ephemeral CI nodes and remove tag assignments or advertised route approvals if they are no longer required by other operational nodes.

5. **Local Repository & Workstation Hygiene:** Inspect local clones for untracked `.tfstate` files, variable files (`.tfvars`), generated inventories, or private keys:

```bash
git ls-files --others --exclude-standard
```

Delete local plan artifacts and temporary files. If sensitive material was ever inadvertently committed to Git history, rotate the compromised credentials immediately and execute a controlled repository history purge.

### D. Retire the State Backend Last

The `rg-terraform-state` Resource Group and Storage Account are bootstrapped independently and are not managed by Terraform. Keep this backend operational until all managed infrastructure components are completely deprovisioned and audit retention periods expire.

To retire the backend:
1. Export required state history to an encrypted, access-controlled archive for compliance.
2. Confirm no active pipelines or team members rely on the backend.
3. Manually delete the Storage Account and Resource Group via Azure Portal or Azure CLI after double-checking subscription contexts.

Never delete a `.tfstate` blob directly from storage to reset a environment. Orphaned resources left in Azure without state tracking can cause billing drift and security vulnerabilities. Perform a final verification using `az resource list` and inspect Azure Cost Management to ensure all associated resources have been removed.

---

## Existing VM Migration and Key Rotation

- **Administrator Key Changes:** The Terraform configuration disables password authentication and installs the initial administrator public key. Modifying this public key in code for an active deployment may trigger VM replacement in Terraform. Always review the plan prior to applying key updates.
- **Key Removal vs. Revocation:** Removing a public key from source code does not remove it from running VMs, nor does it purge historical key material from Azure state backups, GitHub artifacts, or Git history. To rotate an exposed key, issue revocation updates directly to active hosts or redeploy via Terraform, followed by key rotation in GitHub Environment Variables.
- **Tailscale Management:** Routine access uses Tailscale SSH and role policy. The Azure public key is retained only for VM creation/recovery; no private SSH key is distributed to CI or workloads.

---

## Final Verification Checklist

- [ ] Compute and network resources (Module 02) successfully destroyed via pipeline workflow.
- [ ] Identity foundation lifecycle guards removed, PR approved, and Module 01 deprovisioned.
- [ ] Temporary subscription-level RBAC role assignments and bootstrap access revoked.
- [ ] GitHub OIDC federated credentials, environment secrets, and Tailscale `tag:ci` keys revoked.
- [ ] Local clones, Git history, workflow artifacts, and state storage verified clear of unencrypted secrets.