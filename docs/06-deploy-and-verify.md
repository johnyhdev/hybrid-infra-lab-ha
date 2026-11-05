# 06 — Run workflows, deploy, and verify

Follow this sequence. Do not approve an apply until state, Azure OIDC/RBAC, and Tailscale credentials are configured.

## Push and review checks

1. Check `git status`; ensure state, `.terraform/`, tfvars, passwords, private keys, and plan files are not committed.
2. Push a branch to your GitHub fork and open a pull request against `main`.
3. Review Ansible checks, Tailscale policy tests (if changed), Terraform plan summaries, TFLint, and Checkov results. Stop if the plan targets the wrong subscription/resource group or contains unexpected changes/replacements.
4. Confirm each workflow is using the intended GitHub Environment and succeeds in OIDC/backend authentication.
5. Merge only after review. The apply workflow finds the plan artifact and waits at the apply environment for approval. Review the plan summary, run, and target before approving.

Run these checks from the repository root in PowerShell before staging or pushing. The output of `git ls-files` must not list state, tfvars, generated inventory, or plans; ignored files may still be tracked if they were added before ignore rules were written:

```powershell
git status --short
git ls-files | Select-String -Pattern '(^|/)(\.terraform/|.*\.tfstate(\..*)?|.*\.tfvars(\.json)?|.*\.tfplan|tfplan(\.txt)?|destroy-plan\.txt|ansible/inventory/generated/)'
git check-ignore -v terraform/02-vmresource/tfplan terraform/02-vmresource/tfplan.txt ansible/inventory/generated/azure.yml
```

The `git ls-files` search should return no sensitive/generated files; `git check-ignore` should identify ignore rules for the sample paths (it can report a path does not exist yet). If any sensitive value was committed previously, merely deleting it or adding `.gitignore` is insufficient: revoke/rotate the affected key or credential first, then remove it from Git history using a reviewed history-rewrite procedure and invalidate retained artifacts/backups where possible. Do not publish the affected clone until reviewed.

Apply the initial Tailscale policy manually before creating VMs so the required tags and route rules are present. Later policy changes should pass the PR test and be reviewed before merge.

## Apply the identity root first

The first infrastructure PR must change `terraform/01-identity/**` so the plan workflow runs. Review, merge, and approve `terraform-identity-apply`. It should create:

- The persistent lab Resource Group.
- User Assigned Managed Identity `id-cm`.
- Azure `Reader` role assignment for the managed identity principal on the lab Resource Group.

The identity module uses a separate Blob state key, `hybrid-identity.tfstate`. It should not create VMs or network resources. If the apply fails with `roleAssignments/write`, fix the identity apply RBAC described in document 03; do not grant Owner broadly.

## Apply the VM/network root

Open a PR changing `terraform/02-vmresource/**` (or another path included in the workflow filter) and inspect the plan. After merge, approve `terraform-vmresource-apply`. The default plan creates:

- VNet `10.20.0.0/16`, automation subnet `10.20.1.0/24`, workload subnet `10.20.2.0/24`, and NSGs.
- One Ubuntu 24.04 ARM64 control-manager and one workload VM according to the VM maps.
- No Public IP.
- No Load Balancer by default (`enable_load_balancer = false`).

Terraform apply finishing does not mean cloud-init/Tailscale is ready. The Ansible deploy workflow joins Tailscale as `tag:ci`, then uses its existing OpenSSH commands to connect to the CM's Tailscale IP. Tailscale SSH and tailnet policy authorize the CI identity; no `SSH_PRIVATE_KEY` secret or `ssh-agent` step is needed. The CM runs Ansible to configure workloads over the private Azure network.

The deployment is a separate workflow run: after `Terraform VM Resource Apply` completes on `main`, GitHub starts `Ansible CD Deploy` because `.github/workflows/ansible-deploy.yml` listens for that workflow's completion. Open **Actions → Ansible CD Deploy**, select the run associated with the VM apply, and check the `Ansible Continuous Deployment` job. Success means it joined Tailscale, found an online `tag:cm`, waited for cloud-init, pulled `main` on the CM, generated inventory, and completed `ansible/run.sh`. If no VM-resource paths changed, the apply workflow can finish successfully with its apply job skipped; its successful completion can still trigger Ansible. Review the run's skipped/successful steps rather than assuming each workflow run changed Azure resources.

The deployment uses `StrictHostKeyChecking=accept-new`. The generated workload inventory also sets `UserKnownHostsFile=/dev/null`, so it does not retain host keys for later comparison. Tailscale identity/policy authorizes access but does not independently verify the server's SSH host key. For sensitive deployments, provision host keys through a trusted channel and keep the known-hosts file persistent and protected.

If migrating from existing VMs provisioned with `SSH_PUBLIC_KEY`, review the plan because changing VM authentication can force replacement. Recreating a VM removes its old authorized key; deleting the public key from source does not revoke it from an existing VM or erase it from state versions, old workflow artifacts, or Git history. Do not edit Terraform state by hand.

## Verify Azure and Tailscale

```powershell
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --show-details --query "[].{name:name,power:powerState,privateIp:privateIps}" --output table
az network vnet subnet list --resource-group "<LAB_RESOURCE_GROUP>" --vnet-name "<VNET_NAME>" --output table
az vm identity show --resource-group "<LAB_RESOURCE_GROUP>" --name "vm-cm-01" --output json
```

Replace `<LAB_RESOURCE_GROUP>` and `<VNET_NAME>` with the names in the Terraform variables and run the commands in PowerShell. Confirm both VMs are running and private-only, the CM has `id-cm`, and no Public IP is associated. In Tailscale Admin Console → Machines, verify `vm-cm-01` is online with `tag:cm` and that route `10.20.2.0/24` is advertised and approved. Confirm the Ansible deploy workflow succeeds and inventory discovers the workload.

An administrator whose Tailscale identity is permitted by the policy can connect over the private tailnet, for example `ssh azureadmin@<CM_TAILSCALE_IP>`. This uses Tailscale SSH authorization and does not require the VM administrator private key. Keep the private key corresponding to `SSH_PUBLIC_KEY` protected, but note that this repository does not configure or verify a separate key-based/Serial Console recovery path. Do not use a public IP or open SSH to the Internet. Password authentication is disabled.

## Verify Ansible services

Run these checks **on the control-manager VM**, not on the Windows laptop. Connect using an administrator device that is already on the tailnet and permitted by the policy:

```powershell
ssh azureadmin@<CM_TAILSCALE_IP>
```

Replace `<CM_TAILSCALE_IP>` with the address shown for `vm-cm-01` in Tailscale Admin Console → Machines. After connecting, run the following Bash commands on the CM to refresh Azure inventory. `az login --identity` uses the CM's attached managed identity; do not paste a user password or token:

```bash
cd /home/azureadmin/hybrid-infra-lab/ansible
az login --identity
./inventory/generate_inventory.sh
ansible-inventory -i inventory/generated/azure.yml --graph
```

The graph should contain `control` and `workload` groups and `vm-workload-01` under workload. Then check services and both application ports on every workload VM through Ansible:

```bash
ansible workload \
	-i inventory/generated/azure.yml \
	--private-key ~/.ssh/vm-cm-workload \
	-u azureadmin \
	--ssh-common-args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null' \
	-m shell \
	-a 'set -e; for service in nginx sample-app postgresql node_exporter; do state=$(systemctl is-active "$service"); printf "%s: %s\n" "$service" "$state"; test "$state" = active; done; printf "nginx response: "; curl --fail --silent --show-error http://127.0.0.1/; printf "app response: "; curl --fail --silent --show-error http://127.0.0.1:8080/; printf "Node Exporter metrics:\n"; curl --fail --silent --show-error http://127.0.0.1:9100/metrics | head -n 3'
```

Expected: each `systemctl is-active` result is `active`; both port 80 and port 8080 return `Hybrid Infrastructure Lab - Application OK`; the Node Exporter request returns Prometheus text beginning with metric names. A failed command exits nonzero. PostgreSQL being active means the package/service is installed; this lab does not configure a database or connect the sample application to it. The app and metrics remain private; they are not expected to respond from the public Internet.

To re-run full configuration after correcting a role or template, stay on the CM in `/home/azureadmin/hybrid-infra-lab/ansible` and run `./run.sh`. This logs in with managed identity, regenerates inventory, waits for SSH reachability, and applies `playbooks/site.yml`. The separate `playbooks/remediation.yml` only starts the listed services; it does not perform full configuration. For diagnosis, use `ansible workload ... -m shell -a 'systemctl status <SERVICE> --no-pager; journalctl -u <SERVICE> -n 100 --no-pager'` with the same inventory/private-key/SSH arguments above. Do not add a Public IP to troubleshoot.

## Destroy the temporary VM environment

The `Terraform VM Resource Destroy` workflow manages module 02 only. Run it from `main`, set the confirmation input to `yes`, and review the complete destroy plan in the workflow summary. The plan job uses the `terraform-vmresource-plan` Environment; the apply job then waits for approval in the protected `terraform-destroy` Environment and applies the same saved plan after checking its repository, commit, module, run, and artifact metadata. If the state changes or the plan expires, apply fails and a new plan must be generated and reviewed. This workflow does not remove the identity foundation or state backend. See [08 — Limitations and cleanup](08-limitations-and-cleanup.md).