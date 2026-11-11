# Phase 8 Operator Guide

**Status:** Code paths and operator workflow are documented; environment placeholders remain and runtime acceptance is `NOT RUN`. Follow [external setup](EXTERNAL-SETUP.md) before the protected deployment.

## 1. What is and is not deployed

Phase 8 code defaults to two CM and two workload VMs in separate zones. Terraform/image/package/provider values must be completed for the target environment. Code presence is not deployment evidence: Cloudflare, monitoring, recovery, failover, backup/restore and rebuild remain unverified until documented tests pass.

Both roles join Tailscale with role tags; routine management uses Tailscale SSH. Each workload runs one outbound-only Cloudflare Tunnel connector, a dedicated Nginx proxy and local application. Proxy/backend, connector, application and database health are separate. Internal telemetry/service flows use private TLS; mTLS is selective. PostgreSQL remains a single instance. HA claims require measured failover and RPO/RTO evidence.

Cloudflare federation is preferred. If unavailable, the approved exception is a narrowly scoped, expiring Cloudflare API Token in Azure Key Vault, readable only by the authorized workload Managed Identity, used at runtime to obtain/refresh the Tunnel Token. This is a persistent credential, not short-lived: never put it in GitHub Secrets by default, Terraform state/variables, cloud-init/custom data, Ansible output, or logs. SMTP/chat remain disabled until a separate credential policy is approved. A one-way hash cannot authenticate to a provider.

## 2. Routine GitOps lifecycle

1. Make one scoped change on a feature branch. Read the blueprint and update the manifest before modifying code.
2. Run repository validation, inspect the diff, and confirm only manifest-approved paths changed. Never include secret values.
3. Open a PR. Static checks and security scans run without deployment credentials. PR checks do not apply infrastructure.
4. After review and merge, approve the protected production Environment. The deployment workflow uses the exact reviewed SHA, obtains short-lived Azure/Tailscale identities, applies the Terraform plan, then configures all nodes over Tailscale.
5. Review Terraform plan approval, deployed resource inventory, exact commit SHA, Ansible results, TLS/HA smoke tests and public-edge checks. Confirm no step selected a later `main` revision.
6. Update the acceptance matrix and changelog with factual results. Syntax success does not prove HA, security, provider authentication, or zero-touch rebuild.

The current deployment workflow uses `.github/workflows/ansible-deploy-ha.yml`, the `tailscale-ci-ha` GitHub Environment, Tailscale OIDC, and SSH to the CM. The target workflow must replace key-based SSH with tailnet-based short-lived identity after the path is tested. Do not bypass these protections with direct VNet SSH, public SSH, or ad-hoc VM edits.

## 3. Operator access

Operators access Grafana, Prometheus, Alertmanager, Ansible, and VM login through the tailnet and role-specific ACLs. Monitoring/admin services are not exposed through Cloudflare or public DNS. Exact Tailscale SSH/proxy commands and service URLs must be added and tested during implementation. Never add a public NSG rule or public IP to make an admin interface reachable.

Ansible inventory resolves all nodes dynamically using the approved Tailscale identity/hostname or private discovery for data-plane checks. Ansible management must travel over Tailscale; metrics/logs/database use private Azure IPs with TLS/mTLS and verified certificate identities. No plaintext fallback is allowed.

## 4. Secrets and access control

- Use short-lived Azure/Tailscale OIDC tokens, short-lived service certificates, and workload identity. Do not use CI SSH private keys or static bearer tokens.
- Cloudflare may use only the approved Key Vault + workload Managed Identity exception if federation is unavailable. Use runtime retrieval and token refresh; document API Token versus Tunnel Token and rotation/revocation. This is not a short-lived credential.
- Never put credentials in Git, Terraform state/vars, cloud-init/custom data, Ansible vars, logs, Actions artifacts, or screenshots. Hashing provider credentials is not a solution because external authentication needs the original credential/token.
- Runtime credential retrieval must be authenticated, non-logging, least-privilege, and automated. Missing/expired/unreadable inputs fail closed. SMTP/chat require a separate approved credential decision.
- PR validation must never receive secrets. Deployment and secret injection must stay behind the protected Environment approval and minimum required permissions.

Exact federated claims, certificate paths, rotation steps and recovery procedures remain pending until implementation and security review. Do not create credential files on a VM by hand as a substitute for the GitOps path.

## 5. Alerting and recovery operations

Recovery starts observe-only and may be enabled only after security tests and an approved change. A webhook can request only a fixed mapped action; it cannot choose a host, service, command, playbook, or file path. Each action needs an explicit target, cooldown, concurrency/timeout/retry bound, audit record, and post-action health check.

For every recovery event, operators should be able to determine: alert name/fingerprint, accepted or rejected decision, fixed action ID, fixed target, start/end time, result, and verification state—without exposing bearer tokens or SMTP credentials. If dispatcher state/audit writes fail, no action may run. If remediation fails, retries stop at the documented bound and a Critical failure notification is attempted.

Do not use the dispatcher for Terraform apply/destroy, network policy edits, arbitrary shell, or manual operator commands. For an incident outside the allowlist, follow the normal reviewed/manual incident procedure.

## 6. Troubleshooting checkpoints

Use the least invasive check first and preserve sanitized output:

1. GitHub: confirm PR checks, Terraform plan approval, Environment approval, exact SHA, workflow permissions, and Azure/Tailscale OIDC claims.
2. Tailnet: verify expected CM/workload tags, ACL reachability, node expiry/renewal, and absence of direct VNet management fallback.
3. Azure: verify VM count/zones, managed identities, private IPs, LB backend health, DNS records, NSG isolation and no public IPs.
4. Workloads/database: verify Tailscale management, connector/proxy/local-app/backend health separately, TLS identities on designated flows, PostgreSQL service health, backup freshness and restore procedure. Patroni is not part of the baseline.
5. Cloudflare: verify WAF policy, workload connector count/status, Tunnel Pool capacity, credential scope/expiry, tunnel health, TLS origin, and that origin is not directly reachable. Confirm the current provider API supports the selected API Token→Tunnel Token operation; then test Key Vault→workload MI retrieval and rotation without exposing token content.
6. Observability: verify Prometheus target TLS/`UP`, selected log collector TLS delivery, Loki queries, HA peer status, rule evaluation and data continuity.
7. Recovery: verify federated caller identity, allowlist mapping, cooldown/state, concurrency, timeout and audit writes. Verify mTLS only where the flow is explicitly configured to require it. Never manually invoke a privileged wrapper outside an approved test.

Add concrete commands, expected outputs, and remediation steps as each phase is implemented. Do not guess service names or paths; use the manifest and deployed role definitions.

## 7. Tunnel Pools, workload proxies and scaling (planned; verify before use)

- A logical Tunnel Pool records pool name, unique Tunnel ID, region, service group, desired/max replicas, workload membership and connector health. Do not assign more than the verified Cloudflare connector limit to one Tunnel; the current design target is 25, subject to current account/product documentation. Create another pool with a distinct Tunnel ID and explicit service-group membership when capacity requires it. Confirm API limits and supported token retrieval/refresh operations before enabling automation.
- Track Cloudflare account quotas, API rate limits, plan/pricing and egress costs before expanding pools. Cloudflare Load Balancing is optional and not required for the default deployment.
- Each workload connector points to its local Nginx proxy on the dedicated proxy port. Proxy upstreams come from dynamic inventory/private IPs and must be consistent across peers. Validate `nginx -t` before reload. Prevent loops and use bounded timeouts/retries; do not retry non-idempotent methods without application-level safety.
- Nginx Open Source passive health detection is request-driven, not active health checking. Test connector, proxy, local app and remote backend failures independently. Register/remove/replace backends through Git/Ansible inventory updates; do not make manual VM edits the normal path.
- Scaling workload maps through Terraform is provisioning, not autoscaling. Horizontal target maximum 250 is a design/automation target only; confirm Azure quota, subnet capacity, Tunnel Pool limits, Nginx capacity and cost. Vertical SKU/disk changes require reviewed Terraform plans and replacement/maintenance assessment.
- Critical package/runtime versions should be centralized and pinned. Separate normal idempotent install from security patching and major/minor upgrades; test on a designated node first, record installed versions, run health checks, and use only a verified rollback source. Do not assume package downgrade is available.

## 8. Database availability (planned baseline)

PostgreSQL is a single instance unless a future workload requirement approves a database HA module. Document its failure impact, backup cadence/retention, restore test and achieved RPO/RTO. Do not claim application HA implies database HA. Patroni and its quorum/cost design are deferred and are not required Phase 8 acceptance.

## 9. Rollback and rebuild

Every phase that changes a service must document an idempotent rollback to the last reviewed Git revision and any required verification. Restore through Ansible/GitOps, not undocumented edits. If automation is unavailable, use the separately documented break-glass procedure and create a follow-up PR capturing the resulting desired state.

A rebuild requires the approved repository revision, Azure/Tailscale federated identities, DNS/domain prerequisites, protected GitHub Environment, Key Vault and the separately enrolled Cloudflare API Token if that exception is used, plus approved RPO/RTO. T10 is not passed until replacement of CM/workload nodes and scale changes reconstruct the cluster, database baseline, TLS, observability and public edge without VM hand edits and meet measured recovery targets. Never treat a green syntax check as rebuild evidence.

## 10. Change and acceptance records

For each accepted change, update:

- the file/action/status and dependencies in `PHASE-8-FILE-MANIFEST.md`;
- decisions and deviations in `PHASE-8-CHANGELOG.md`;
- test outcome, evidence, commit SHA and operator in `PHASE-8-TEST-MATRIX.md`;
- these runbook procedures with commands verified against the actual code.

Current runtime tests T01–T10 and security tests A01–A12 are `NOT RUN`; consult the matrix for criteria and fault-injection safety rules.
