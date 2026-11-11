# Phase 8 Changelog

This log records approved design and implementation changes. Keep entries chronological; do not rewrite history to make an unimplemented item appear complete.

## Current status — M1–M5 implementation batch

The user approved continuous repository code/documentation work from M1 through M5, followed by one final non-destructive static validation. Code has been added across Terraform identity/VM roots, Tailscale WIF/policy, cloud-init, dynamic inventory, workload proxy/Tunnel roles, TLS, monitoring/logging, bounded recovery, GitHub validation/deploy, smoke tests, and concise external setup. Azure `SSH_PUBLIC_KEY` remains a required VM provisioning input; no private SSH key is distributed to CI or workloads.

The selected current design supersedes older entries below where they conflict: PostgreSQL is single-instance (Patroni optional); Cloudflare API Token in Key Vault via workload MI is an approved persistent-credential exception if federation is unavailable; Cloudflare LB is optional; workload nodes join Tailscale; default maps are two CM/two workloads; no subnet route is advertised. Exact package/image/provider inputs remain environment-specific. Terraform fmt/validate and `git diff --check` passed at 2026-11-10 11:47 +07 on source revision `6855e5a38f62e753513ebbc2eabed76c0089a85a`. Ansible lint/syntax and Python unit tests were not run; T01–T10/A01–A12 remain `NOT RUN`. No cloud apply, provider change, or fault injection was authorized or performed.

## 2026-11-07 — Phase 8.0 initial baseline (superseded)

Status: Initial single-node/private-only design was superseded by the revised HA target below before implementation. No infrastructure code was deployed under this baseline.

### Baseline decisions

- Reviewed the repository's actual Ansible, Terraform, cloud-init, Tailscale, and GitHub workflow structure before proposing files.
- The existing repository is one `vm-cm-01` and one `vm-workload-01`; the earlier instruction to preserve single-node topology is superseded.
- The earlier decision to keep workloads off Tailscale and defer Cloudflare was superseded.
- Reuse the current `ansible-deploy-ha.yml`, `tailscale-ci-ha` environment, Tailscale OIDC, inventory generator, and CM Ansible entrypoint; do not add a competing AWX or deployment workflow by default.
- Require ARM64-compatible pinned artifacts because the current Terraform default is ARM64. Validate hashes/signatures before installing downloaded binaries.
- Require a tested HTTP-health signal before claiming Nginx/sample-app alert coverage. Do not silently add an exporter/product.
- Treat runtime secrets as external protected inputs; document secure setup, rotation, permissions, and rebuild requirements without committing secret values.
- Dispatcher and recovery must be fixed-action, fixed-target, fail-closed, auditable, bounded, and initially observe-only. No payload-driven shell, Terraform, or infrastructure lifecycle access.
- AWX remains excluded due to resource cost. The previous single-node observability target was not approved for implementation.
- Deployment remains protected by a manual Environment approval. “Zero-touch” excludes routine manual VM configuration, not prerequisites, secret management, or approval.

### Documents and agent definitions

Created initial Phase 8 blueprint, file manifest, T01–T10/A01–A12 test matrix, operations guide, and repository-scoped specialist agent definitions. These are planning/documentation artifacts, not proof of implementation or acceptance.

### Validation

- Repository baseline inspected; no infrastructure deployment or fault injection performed.
- Tests T01–T10 and A01–A12: `NOT RUN`.
- Code implementation phases 8.1–8.13: pending.

## 2026-11-07 — Phase 8 target revised for HA and zero trust

Status: Target architecture recorded; Terraform, Tailscale, Cloudflare, HA services, and runtime validation pending.

### User-selected architecture

- Expand scope beyond observability to adjustable multi-zone Azure VM pools: HA defaults at least two CM and two workload nodes; one-node mode is explicitly non-HA.
- Join both VM roles to Tailscale through separate managed identities and WIF/OIDC (`tag:cm`, `tag:workload`). Management, VM login, Grafana access, and Ansible use the tailnet; remove the persistent CM-to-workload SSH key only after keyless management is proven.
- Keep VMs private/no public IP. Public application access is Cloudflare WAF → outbound Cloudflare Tunnel → private Azure internal load balancer; public ports are 80/443 at the Cloudflare edge only.
- Internal metrics, logs, database and service communication use private Azure addresses with HTTPS/mTLS and short-lived certificates.
- User selected self-managed Patroni. Two database members need a third DCS voter; proposed voters are CM-01, workload-01 and workload-02. This is a single-node failure design with control-plane coupling, not multi-failure tolerance.
- AWX explicitly excluded. GitHub Actions + Ansible remain the deployment orchestration path.
- User selected strict short-lived-only credentials. No Cloudflare Tunnel, SMTP, or chat integration may silently use a persistent provider token. If provider federation/ephemeral connector credentials cannot be verified, keep that integration blocked and do not claim full zero-touch completion. A one-way hash cannot authenticate to an external provider.
- Internal PKI must provide short-lived role-bound certificates, automated renewal and HA recovery; product/trust-root design is a pre-deployment gate.
- Require measurable RPO/RTO objectives before implementation and acceptance; do not imply zero data loss or HA from node count alone.

### Validation and gates

- No Terraform plan/apply, credential setup, DNS/WAF change, VM deployment, or fault injection performed.
- Cloudflare connector and notification-provider short-lived credential capability: `UNVERIFIED / BLOCKED`.
- RPO/RTO targets: `NOT SET`.
- Tests T01–T10 and A01–A12: `NOT RUN`.
- Phase implementation remains pending.

## 2026-11-07 — Phase 8 target revised: distributed workload ingress

Status: Architecture decision approved; documentation/agent alignment recorded. No infrastructure code changed and no runtime capability is implemented or verified by this entry.

### Approved decisions

- Place one `cloudflared` connector and one lightweight Nginx reverse proxy on each workload VM; no dedicated central ingress gateway is required by default. Each proxy uses consistent, dynamically generated private upstream inventory for its service group and may route eligible traffic to healthy peer workloads.
- Keep connector availability, proxy availability, local application health, and backend-pool health as separate test signals. Cloudflare Tunnel replicas do not imply application balancing or health checks. Nginx Open Source passive upstream checks are acceptable initially; active checking remains optional.
- Define logical Tunnel Pools with pool name, distinct Tunnel ID, region, service group, desired/max replicas, workload membership and connector status. Enforce the verified Cloudflare connector limit (target maximum 25 per Tunnel), support additional distinct pools, and document provider quotas, API rate limits and cost.
- Cloudflare API Token exception is approved only if federation is unavailable: narrowly scope and expire it, store in Azure Key Vault, and allow only authorized workload Managed Identity to retrieve it at runtime and obtain/refresh the Tunnel Token. Never pass token material through Terraform state/vars, cloud-init/custom data, GitHub Secrets by default, logs or artifacts. Do not call this credential short-lived.
- PostgreSQL remains single-instance baseline with documented availability, backup and restore limitations. Patroni/DCS is optional future work and not a Phase 8 acceptance dependency.
- Require HTTPS/TLS on designated internal data-plane flows. Use mTLS selectively after documenting threat-model justification and complete certificate lifecycle/recovery; do not mandate global mTLS.
- Preserve existing phase acceptance IDs T01–T10 and A01–A12 without changing their identities; add subcriteria for connector/proxy/app/backend failures, pool limits, credential rotation and cost/quota.
- Keep Cloudflare Load Balancing, paid NGINX Plus, and centralized ingress gateway optional/non-mandatory. No zero downtime, 250-node deployment, or autoscaling claim without corresponding implementation and evidence.

### Validation and implementation status

- Repository/code audit completed for Terraform VM maps/LB scaffolding, Nginx role/template, Azure-IP inventory, and existing docs/agents.
- Documentation and agent updates only; no HCL, Ansible, workflow, Tailscale policy, or live Cloudflare/Tailscale changes authorized by this decision.
- Tunnel replica limit and account/API quotas: must be verified against current Cloudflare account/product documentation before implementing pool validation.
- Tests T01–T10 and A01–A12 remain `NOT RUN`.

## 2026-11-07 — Phase 8 M0–M5 execution roadmap integrated

Status: Documentation and agent workflow aligned; implementation remains pending.

### Approved additions

- Added M0 read-only baseline audit and scope-freeze gate; distinguish checked-in implementation from runtime evidence and record cost/limits only where available.
- Mapped M1 to workload ingress (per-workload connector/proxy, Tunnel Pools, dynamic private backends, WAF/TLS, replacement); M2 to metrics/logging/dashboards/alerts; M3 to independent management/workload/monitoring failure tests; M4 to bounded recovery/replacement; M5 to vertical/horizontal provisioning, capacity and cost validation.
- Preserved detailed Phase 8.0–8.13 sequencing and T01–T10/A01–A12 IDs. M0–M5 is a delivery grouping, not a renumbering.
- Added explicit audit → exact patch plan → user approval → implementation → evidence protocol to the coordinator and specialist agents. Live apply/destroy, provider changes and destructive tests require separate approvals.
- Added lightweight collector selection (Grafana Alloy or approved equivalent), CM survivor Ansible continuity, package version/update/rollback checks, and cost/quota evidence to the corresponding existing acceptance IDs.

### Validation and status

- Documentation and agent instructions only; no HCL, Ansible, workflow, Tailscale policy, or live infrastructure/provider changes.
- All runtime acceptance results remain `NOT RUN`.
- Cloudflare connector limit/API token-to-Tunnel-token operation and account quotas still require verification before implementation.

## Entry template

### YYYY-MM-DD — Phase 8.N — Short decision/change title

- Status: Proposed / Approved / Implemented / Verified / Deferred.
- Decision and rationale:
- Paths changed:
- Architecture/interface impact:
- Validation and evidence (commit SHA, commands, results):
- Rollback or follow-up:
