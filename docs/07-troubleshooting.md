# 07 — Troubleshooting by checkpoint

Find the first failing step and diagnose one layer at a time. Never paste passwords, JWTs, backend credentials, private keys, or Terraform state into public issues/logs.

## Azure and Terraform backend

- **Invalid or unavailable Storage Account name:** names must be globally unique, 3–24 lowercase alphanumeric characters. Update both backend files and all relevant scopes consistently.
- **403 during `terraform init`, lock, or state access:** check the environment's app Client ID, FIC issuer/audience/subject, service-principal assignment, and `Storage Blob Data Contributor` role on the correct account/container. Management-plane `Contributor` does not grant Blob data access.
- **Backend timeout/network denied:** check storage firewall/private endpoint rules. GitHub-hosted runners do not have a fixed IP by default; use a networking design that permits authorized CI access.
- **Unexpected creates or “already exists”:** verify the fork uses new backend keys and the intended subscription. Stop; do not apply to see what happens. Do not import/migrate another repository's state without a reviewed plan.
- **Identity apply authorization error:** identity apply needs permission to create the resource group/managed identity and `Microsoft.Authorization/roleAssignments/write` for `id-cm`'s Reader assignment. Check the actual role and scope; do not grant broad Owner as a shortcut.
- **VM module cannot find resource group/identity:** apply identity first and make sure module names match.
- **SKU/quota/zone/image error:** verify `Standard_D2ps_v6`, ARM64 support, zone 1, regional vCPU quota, and the Ubuntu image availability. Change VM map values and review a new plan.

## GitHub OIDC and workflows

- **“No matching federated identity record found”:** verify app Client ID, tenant, `api://AzureADTokenExchange` audience, exact environment name, and exact OIDC subject. Confirm the FIC is on the application used by that job. Repository/owner/environment renames can change the subject.
- **Missing/empty secret or variable:** check spelling/case and add it to the exact Environment used by the job. The VM Terraform workflows need `SSH_PUBLIC_KEY`; `tailscale-ci` needs only `TAILSCALE_CI_CLIENT_ID` and `TAILSCALE_CI_AUDIENCE` for tailnet access. Tailscale CM IDs are variables; policy credentials use their documented variable locations.
- **CI cannot authenticate to the CM:** this workflow does not use `SSH_PRIVATE_KEY`. Verify the runner successfully joined Tailscale as `tag:ci`, the `tailscale-ci` OIDC credential is valid, and the Tailscale SSH policy allows `tag:ci` to reach `tag:cm` as `azureadmin`. Confirm Tailscale SSH is enabled on the CM and TCP 22 is allowed by the tailnet policy.
- **Apply cannot find a plan artifact:** check the PR plan run, artifact retention, and commit SHA. Re-run plan for the current PR; do not apply an artifact from another PR or stale revision.
- **Approval does not appear:** verify the job's exact Environment, reviewer rules, and allowed deployment branch.
- **Tailscale policy test waits for approval:** the shared `tailscale-policy` environment may require reviewers for PR test and main apply jobs. Adjust protections intentionally.

## Tailscale

- **CM does not appear in Machines:** inspect cloud-init and Tailscale service status, attached managed identity, `id-cm` principal ID subject, configured Azure audience, and `tag:cm` scope in the WIF credential.
- **CI cannot connect to the CM:** verify the two `tailscale-ci` OIDC secrets, `tag:ci` enrollment authorization, TCP 22 policy, the `azureadmin` Tailscale SSH rule, and the CM's online Tailscale IP. CI invokes the OpenSSH client over Tailscale; it does not load the VM administrator private key.
- **CM is online but workloads are unreachable:** verify route `10.20.2.0/24` is advertised/approved, CIDRs do not overlap, NSG permits TCP 22 from `10.20.1.0/24`, and CM IP forwarding is enabled.
- **Policy GitOps fails:** verify `policy_file` scopes, `TAILSCALE_POLICY_*` variables, tailnet ID, and HUJSON syntax. Never put access tokens in policy or workflow files.

## Cloud-init and Ansible

Connect from an administrator device that is already on the tailnet and permitted by the policy. In PowerShell, use the CM's Tailscale IP from Tailscale Admin Console → Machines:

```powershell
ssh azureadmin@<CM_TAILSCALE_IP>
```

This lab's normal CM access uses Tailscale SSH identity/policy; it does not require the Azure provisioning private key. The repository does not configure Azure Serial Console, so do not assume that recovery path exists. Once connected to the CM, run these Linux commands:

```bash
sudo cloud-init status --long
sudo journalctl -u cloud-init -n 200 --no-pager
sudo systemctl status tailscaled
sudo journalctl -u tailscaled -n 200 --no-pager
sudo tail -n 100 /var/log/cloud-init-output.log
```

Check the completion marker, clone, Ansible runtime, and inventory using these commands on the CM:

```bash
test -f /var/log/cloud-init-done.tag && echo "cloud-init marker: present" || echo "cloud-init marker: missing"
test -d /home/azureadmin/hybrid-infra-lab && echo "repository clone: present" || echo "repository clone: missing"
/opt/ansible-venv/bin/ansible --version
az login --identity
cd /home/azureadmin/hybrid-infra-lab/ansible
./inventory/generate_inventory.sh
ansible-inventory -i inventory/generated/azure.yml --graph
```

The inventory graph should show the control and workload groups. The CM currently clones the public repository over HTTPS without repository authentication. A private fork requires a deliberate authentication design; do not embed a PAT in cloud-init. The generated inventory file is ignored by Git and contains private network addresses; do not attach it to public issues.

For Ansible failures:

1. Verify CM routing and workload SSH TCP 22 access from `10.20.1.0/24`.
2. From `/home/azureadmin/hybrid-infra-lab/ansible`, run `./inventory/generate_inventory.sh` and `ansible-inventory -i inventory/generated/azure.yml --graph`; confirm the workload VM appears under the `workload` group.
3. Verify the Terraform-generated internal SSH key exists on the CM and the matching public key was added to workloads.
4. Inspect the failing task and host reachability; use the ping check in `ansible/run.sh`.
5. Inspect the affected service with `systemctl` and `journalctl`, fix the role/source, and rerun.

Do not add a Public IP to debug. This repository does not configure or verify an Azure Serial Console recovery path. If Tailscale access is unavailable, stop and use an independently verified recovery procedure for your Azure environment; do not assume one is configured by this lab. Fix Terraform/cloud-init/Ansible and redeploy through reviewed workflows.

## Application checks

- Nginx listens on port 80 and proxies to the sample app at `127.0.0.1:8080`; port 5000 in old notes is obsolete.
- Node Exporter uses port 9100; no Prometheus server is included.
- PostgreSQL is installed but is not configured or used by the sample application.
- The application is private-only. Failure to access it from outside the tailnet/private network is expected.