# 06 — Deploy and verify

Use this guide only after completing the one-time values and provider setup in [Phase 8 external setup](phase-8/EXTERNAL-SETUP.md). The repo is not runtime-accepted yet: run the static validation job and review its result before approving any apply. No command in this guide is a substitute for reviewing the exact Terraform plan.

## Deployment order

1. Open a PR and check the unprivileged repository validation, Terraform plan artifacts, and Tailscale policy test when applicable. Reject unexpected resources, replacement, public IPs, stale plans, or wrong subscriptions.
2. Merge only the reviewed commit. Approve the protected identity apply first. It creates the resource group, CM/workload identities, and private Key Vault configuration.
3. Review the VM-resource plan and approve its protected apply. The defaults are two CM VMs and two workload VMs in separate zones, no VM public IPs, exact Ubuntu image version, private endpoints, Loki storage, and NSGs.
4. After the private Key Vault endpoint exists, enroll the Cloudflare API Token out-of-band using a trusted private-network operator process. Do this before approving the `tailscale-ci-ha` deployment environment. Do not pass the token through Terraform, cloud-init, CI, or logs.
5. Approve the protected Ansible deployment. It joins Tailscale as `tag:ci`, selects an online CM, checks out the exact triggering commit SHA, regenerates Tailscale inventory, runs Ansible, and executes bounded smoke checks. Verify SHA equality and workflow output before considering the rollout complete.
6. Record results in the Phase 8 test matrix. Runtime/failover tests are still `NOT RUN` until performed in an authorized lab window.

The Azure SSH public key remains a required VM provisioning input (`SSH_PUBLIC_KEY`); routine operator and Ansible access use Tailscale SSH. CI has no SSH private key. No CM-to-workload key is generated or distributed.

## Verify topology and access

From an authorized Azure CLI session:

```powershell
az account show --output table
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --show-details --query "[].{name:name,power:powerState,privateIp:privateIps,zones:zones}" --output table
az network vnet subnet list --resource-group "<LAB_RESOURCE_GROUP>" --vnet-name "<VNET_NAME>" --output table
```

Confirm two CM and two workload nodes in separate supported zones, private IPs only, correct identities and no public IPs. In Tailscale Admin Console confirm the expected tags and no advertised subnet routes. Check generated inventory has `control`, `workload`, and exactly one `database` host. Normal login is `ssh azureadmin@<TAILSCALE_DNS_OR_IP>` from an authorized tailnet node.

## Verify services

On an online CM over Tailscale SSH:

```bash
cd /home/azureadmin/hybrid-infra-lab-ha/ansible
./inventory/generate_inventory.sh
ansible-inventory -i inventory/generated/tailscale.yml --graph
bash ./scripts/smoke-test.sh
```

The smoke script checks each control manager's monitoring endpoints, TLS-verified Loki access and local recovery dispatcher, all-host Ansible reachability, workload proxy health, and PostgreSQL readiness. It is an operational smoke check, not a zone-failure or RPO/RTO acceptance test. For a service issue, use `systemctl status <service>` and `journalctl -u <service> -n 100 --no-pager` on the affected host; do not open public SSH or use a direct VNet SSH fallback.

## Destroy and cleanup

The protected VM-resource destroy workflow applies a saved, reviewed destroy plan for module 02 only. It leaves the identity root, Key Vault, and state backend. Verify the plan and resource group before approval. Do not delete the identity foundation or state backend until all dependent VMs, secrets, identities, and audit requirements have been handled. See [08 — limitations and cleanup](08-limitations-and-cleanup.md).

## Acceptance status

A green Terraform apply, Ansible run, syntax check, or smoke test alone does not establish HA or production readiness. T01–T10 and A01–A12 remain unaccepted until their evidence, tested commit, timestamp, and operator are recorded in [the Phase 8 test matrix](phase-8/PHASE-8-TEST-MATRIX.md).
