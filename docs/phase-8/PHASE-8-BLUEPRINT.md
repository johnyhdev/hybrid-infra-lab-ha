# Phase 8 — Zero-Touch Observability & Recovery Blueprint

**Status:** Broad M1–M5 code is present but not runtime-validated. Environment-specific package/image/provider values remain prerequisites; T01–T10 and A01–A12 are `NOT RUN`. Do not claim production readiness, full HA, or zero-touch rebuild.
**Source of truth:** This blueprint, the file manifest, the acceptance matrix, and the repository's reviewed code on `main`.
**Scope:** Phases 8.0–8.13, applied in order. A phase is not complete until its implementation, documented checks, and evidence are recorded.

## 1. Goal and definition of zero-touch

Extend the repository into a configurable, multi-zone Azure deployment with redundant control and workload nodes, private management over Tailscale, a Cloudflare-protected public edge, encrypted internal service traffic, workload/application HA, observability, and bounded self-recovery. PostgreSQL remains single-instance baseline; database HA is optional future work. GitHub is the source of truth for non-secret desired state and exact deployment revisions. A reviewed PR is validated and, after merge plus protected-environment approval, provisions/applies the infrastructure and configuration without manual VM setup.

“Zero-touch” means no ad-hoc VM edits or manual service configuration are part of a normal provision/rebuild. It does **not** mean zero prerequisites or automatic approval: cloud accounts, billing, DNS/domain ownership, initial federated identities, policy, and protected GitHub Environment reviewers must be bootstrapped. PRs may provision only after the configured protected approval gate; no unreviewed PR receives deployment credentials. A notification is not proof of human acknowledgement.

**Credential requirement:** prefer short-lived OIDC/managed-identity tokens and short-lived certificates; do not use long-lived personal access tokens, SSH private keys in CI, or shared static passwords. If Cloudflare lacks suitable federation for a required operation, the approved exception is a narrowly scoped, expiring Cloudflare API Token stored in Azure Key Vault and retrieved at runtime by the authorized workload Managed Identity. The API Token is used only to obtain/refresh the Tunnel Token required by `cloudflared`; verify the current Cloudflare API supports the chosen operation and permissions before implementing this flow. Provision the vault and least-privilege identity access through IaC, but do not provision the secret value through Terraform or place it in state. Define a protected out-of-band secret enrollment/rotation procedure and a runtime retrieval mechanism that does not log or persist the API/Tunnel Token in cloud-init, environment files, shell history, ordinary Ansible output, GitHub Secrets, or logs. Do not describe either persistent provider credential as short-lived. Document expiry, scope, rotation, revocation, and failure behavior. SMTP/chat integrations remain disabled unless they support the approved short-lived/federated flow or receive a separately approved credential decision.

Short-lived bootstrap tokens do not eliminate every form of machine identity state: Tailscale nodes retain device identity keys on disk, subject to the configured key-expiry/rotation policy. The policy prohibits persistent bearer/API tokens, not the cryptographic device identity needed to reconnect. Document and test device-key rotation and node revocation.

## 2. Current code state (not proof of operation)

- Terraform maps default to two control managers and two workloads across zones 1 and 2, with a design cap of 250 workloads. Exact Ubuntu ARM64 image version and Azure quotas must be supplied/verified.
- CM and workload VMs attach distinct managed identities, enroll individually in Tailscale as `tag:cm` / `tag:workload`, and use Tailscale SSH for administration and Ansible. Azure's SSH **public** key remains a VM provisioning input; no private SSH key is distributed to CI or workloads.
- Workload code configures a local app, private TLS Nginx backend/proxy, per-workload Cloudflare Tunnel connector, and private dynamic peer inventory. The Cloudflare API Token exception is runtime-read from a private Key Vault by workload MI; external secret enrollment is gated before protected Ansible approval.
- Control-manager roles configure Prometheus, Alertmanager, Grafana, Loki with Azure Blob, Alloy, TLS, local Loki failover proxy, and fixed recovery dispatch. PostgreSQL remains one designated workload instance. Two nodes do not prove every monitoring/data service remains available through every failure.
- Protected GitHub workflows, validation, exact-SHA deployment, and smoke-test code exist. Cloudflare/Ubuntu/monitoring package pins and names are environment-specific prerequisites; static and runtime validation must be recorded before apply.
- Detailed live configuration and acceptance status are in the [external setup checklist](EXTERNAL-SETUP.md), [file manifest](PHASE-8-FILE-MANIFEST.md), and [test matrix](PHASE-8-TEST-MATRIX.md). Reinspect current code before modifying any phase.

## 3. Locked security and network boundaries

1. HA mode provisions at least two control and two workload VMs across distinct supported availability zones. Counts and per-VM size/zone are map-driven; scale-down to one node is allowed only as an explicit non-HA lab mode and must surface an HA warning. Dynamic private IPs are discovered, never hard-coded.
2. No VM has a public IP. Public application traffic is only Cloudflare-proxied HTTP/HTTPS (ports 80/443 at the edge), protected by Cloudflare WAF and carried through outbound Tunnel connectors running on workload VMs. Each workload VM runs one connector, one lightweight Nginx reverse proxy on a dedicated local port, and its local Nginx web server/application. Connectors are not application load balancers; backend health and distribution are handled by each workload proxy. No dedicated centralized ingress gateway VM is required by default. Scope connector egress narrowly; the tunnel has no inbound VM listener.
3. Every CM and workload VM joins Tailscale using per-role Azure managed identities and WIF/OIDC with `tag:cm` / `tag:workload`; tag ownership and ACL grants are least-privilege. Human administration and Ansible management use Tailscale addresses/SSH, not direct VNet SSH. Disable/remove the persistent CM-to-workload SSH key path after the replacement is tested.
4. Operator access to Grafana, Prometheus, Ansible/control surfaces and VM login is through the tailnet. Bind operator-facing listeners to tailnet interfaces or a tailnet-only proxy; do not bind them publicly or expose them through Cloudflare.
5. East-west metrics, logs, database and service traffic use private Azure addresses and HTTPS/TLS. Use mTLS selectively where the flow's threat model justifies mutual authentication and automated certificate issuance, renewal, distribution, revocation, and recovery are documented. Prometheus scrape and the approved log collector use TLS; dashboards/admin UIs use tailnet interfaces. No plaintext fallback for flows designated TLS-required. Tailscale is not a substitute for private-IP TLS.
6. PR validation is unprivileged and receives no cloud secrets. Protected deployment uses GitHub OIDC for Azure and Tailscale WIF, exact commit SHA, explicit environment approval, concurrency protection, and least-privilege roles. Never use long-lived SSH keys in CI.
7. Dispatcher input is data, never a command. Map only known alert names to fixed action IDs, fixed playbooks, fixed inventory groups, and fixed service names. Never interpolate payload values into shell, Ansible arguments, paths, or service names.
8. Recovery is fail-closed: reject unauthenticated, malformed, unknown, stale, concurrent, or cooldown-blocked requests; reject state read/write errors; bound execution by timeout/retry limits; record an audit event for every decision. Recovery starts disabled/observe-only until relevant independent security and acceptance tests pass.
9. No monitoring/recovery action may invoke Terraform apply/destroy, change Azure resources, or broaden network policy.
10. Never commit credentials to Git, Ansible vars, Terraform state, workflow artifacts, or logs. Prefer federation/short-lived credentials. The Cloudflare Key Vault API Token exception is allowed only as scoped in the credential requirement above; it is a controlled persistent credential, not a short-lived token. Other provider integrations without supported federation remain disabled until separately approved.
11. For any mTLS flow, select an internal PKI that issues short-lived role-bound certificates and supports automated renewal. PKI product, trust-root custody, rotation and recovery must be approved and validated for those flows; mTLS is not imposed globally.
12. Do not claim HA until multi-zone failover, quorum, RPO/RTO, failure recovery, and rebuild have been exercised and evidenced. Set measurable RPO/RTO targets before coding; no zero data-loss guarantee is implied.

## 4. Architecture and implementation decisions

| Concern | Phase 8 contract |
|---|---|
| Topology | Existing `control_vms`/`workload_vms` maps become adjustable HA counts, default 2 each, spread across zones. Add private DNS/service discovery. Azure private Load Balancer is optional and cost-reviewed; if enabled, wire backend NICs, probes and rules correctly. No Keepalived/ARP VIP on Azure; use Azure-native load balancing where a shared private endpoint is needed. |
| Tailscale identities | Separate `id-cm` and `id-workload` managed identities with minimal Azure RBAC and WIF audience/subject restrictions. All nodes join the tailnet with role tags; dynamic Tailscale IP/hostname inventory replaces VNet SSH management. |
| Edge and Tunnel Pools | Cloudflare DNS/WAF proxies app hostnames to Tunnel Pools. Each pool records `pool_name`, distinct `tunnel_id`, `region`, `service_group`, `desired_replicas`, `max_replicas`, workload membership and connector status. Default maximum is 25 connectors per Tunnel subject to current Cloudflare documentation/account limits. Additional pools use incrementing identifiers and distinct Tunnel IDs/service-group assignments. The pool model must reject over-capacity assignment. Include API quotas/rate limits/pricing. Do not assume Tunnel replicas distribute or health-check application traffic. If one hostname spans multiple Tunnel IDs/pools, explicitly define and test traffic steering; do not imply health-aware cross-pool failover without optional Cloudflare Load Balancing or another approved mechanism. |
| Distributed workload ingress | One `cloudflared` and one lightweight Nginx reverse proxy per workload VM. Connectors target the local proxy on a dedicated port; proxy upstream inventory contains private IPs for that service group and is rendered consistently across peers. Each proxy can route eligible requests to healthy remote workload backends; backend health, proxy health, connector availability, and local app health are separate. No central gateway or Cloudflare Load Balancing is required by default. |
| Nginx upstream behavior | Nginx Open Source passive failure detection/retry is acceptable initially. Use least-connections or another justified policy, bounded timeouts/retries, safe config validation/reload, and avoid retrying non-idempotent requests unless application semantics permit. Passive checks detect failures through requests; active health checks are an optional extension if required. Prevent proxy loops. |
| PostgreSQL baseline | PostgreSQL remains a single database instance in the baseline; document availability limitations, backup/restore expectations and recovery. Patroni/DCS/database clustering is an optional future module only when a workload requirement justifies its complexity/cost. Infrastructure and app HA must not depend on database HA. |
| App HA | Two or more workload nodes run proxy and app/web services; service-group backend inventory is dynamic. Local unhealthy app/backend is excluded according to tested proxy behavior; complete VM loss removes that connector while other workload connectors continue. Replacement registration/configuration is automated. No zero downtime claim without evidence. |
| Monitoring HA | Redundant Prometheus instances, Alertmanager HA peers, reproducible Grafana instances behind tailnet-only access, and a Loki deployment with replicated storage/object-store design. No local SQLite or one-node data store may be called HA. Specify component replication and storage before implementation. |
| Private data plane | Relevant metrics, logs, database and service channels use Azure private IPs with HTTPS/TLS and verified identity. Use mTLS only for justified flows with fully documented issuance/renewal/distribution/revocation/recovery. Tailscale is reserved for administration/Ansible. |
| Internal PKI | A certificate issuer is required only for selected mTLS flows; product, root custody, rotation, CA outage and recovery are explicit gates before enabling those flows. |
| ARM64 | The default VMs are ARM64. Every downloaded binary/package must support the selected architecture, use a pinned version, and verify a checksum/signature. |
| Alert routing | Normalize severity to `info`, `warning`, and `critical`; group and inhibit repeats. Select a lightweight chatbot/notification provider only after cost, privacy, and credential review; verify delivery. SMTP/chat are enabled only with approved credential handling; email/chat receipt is not human acknowledgement/escalation. |
| HA targets | Agree and measure RPO/RTO per service before code. Include node, zone, CM, workload, database, tunnel, and monitoring failures. A 2+2 configuration does not by itself prove HA. |
| GitHub deployment | Replace manual Terraform→Ansible gaps with protected, exact-SHA OIDC pipeline that provisions infra, bootstraps trust, configures over Tailscale, smoke-tests and records evidence. No later `git pull main`. |
| AWX | Explicitly excluded due resource cost. Use GitHub Actions + Ansible on the HA CM pool; do not introduce AWX. |

## 5. Fixed order and phase exit gates

| Phase | Deliverable | Exit gate / dependency |
|---|---|---|
| 8.0 | Blueprint, manifest, HA/credential decisions | Architecture, Cloudflare Key Vault/runtime token flow, RPO/RTO and actual paths reviewed before code changes. |
| 8.1 | HA Terraform topology and identity | Configurable counts, zone placement, `id-workload`, private DNS, safe dynamic discovery, and any approved optional private LB validated. |
| 8.2 | Tailscale zero-trust enrollment and ACL | CM/workload join through short-lived WIF; tag-based least privilege; management and Ansible paths tested; SSH-key path removed only after replacement. |
| 8.3 | Distributed workload proxy and application HA | Each workload has connector + dedicated-port proxy + local app; dynamic private backend inventory, health exclusion, safe reload and replacement validated. PostgreSQL remains single-instance baseline with backup/restore documented; Patroni optional. |
| 8.4 | Cloudflare Tunnel Pools and WAF | Workload-hosted connectors, distinct pool/Tunnel IDs, connector cap enforcement, WAF, private origin TLS, credential retrieval from Key Vault via workload MI, rotation and quota/cost documented; no paid Cloudflare LB dependency. |
| 8.5 | HA observability and logs | Lightweight, cost-reviewed metrics/log stack (Prometheus, Grafana, Loki and approved collector); no single-node claim for components designated HA; ARM64, TLS, retention, restore, and resource overhead checks. |
| 8.6 | Metrics/log targets and TLS | Dynamic private-IP targets and approved lightweight log collector (Grafana Alloy or reviewed equivalent); TLS peer validation and metrics/log query verified; mTLS only for approved flows. |
| 8.7 | Alert rules and notification providers | Rules/routing/grouping/inhibition; short-lived OAuth/federated mail/chat only, otherwise explicitly disabled. |
| 8.8 | Grafana HA provisioning | Datasources/dashboards from Git; multi-node access through tailnet, no public UI. |
| 8.9 | Dispatcher security guardrails | Fixed schema/action map, cooldown, concurrency, audit, fail-closed, observe-only and unit tests. |
| 8.10 | Remediation and deterministic drift detection | Fixed playbooks, target validation, service recovery, configuration reconciliation and post-checks. |
| 8.11 | Controlled failure tests | Resource-limited CPU test; node/zone/CM/DB/tunnel failover and recovery safely demonstrated. |
| 8.12 | Zero-touch GitHub CI/CD | PR checks unprivileged; approved merge provisions Terraform and configures via Tailscale using exact SHA and OIDC. |
| 8.13 | HA acceptance and rebuild | T01–T10/A01–A12, measured RPO/RTO, failure/rebuild/scale tests and operational evidence complete. |

## 6. Milestone execution roadmap (M0–M5)

The M0–M5 roadmap is a delivery grouping over the detailed 8.0–8.13 phase gates above; it does not renumber or replace those phases or the existing T01–T10/A01–A12 acceptance IDs.

| Milestone | Detailed Phase 8 mapping | Exit evidence |
|---|---|---|
| M0 — Baseline audit and scope freeze | Phase 8.0 plus a read-only audit before each implementation milestone | Current-state topology/dependencies, what code exists versus what is operationally verified, baseline costs/limits where available, and a reviewed file-by-file patch plan. Do not mark the existing Terraform/Ansible/WIF/Tailscale foundation “operational” without runtime evidence. No code change or deployment during audit. |
| M1 — Workload stack and public ingress | 8.1–8.4 | Workload-hosted Tunnel Pool connectors, Nginx proxies, dynamic private backend inventory, WAF/TLS, backend health/replacement and secure Key Vault retrieval verified. PostgreSQL remains single-instance baseline. |
| M2 — Observability and alerting | 8.5–8.8 | Metrics, logs via Grafana Alloy or an approved lightweight collector, dashboards and alerts for CM/workload, cloudflared, Tailscale, proxy/app/backend, PostgreSQL, Ansible/cloud-init/deploy failures, capacity and cost; notification receipt tested only for approved providers. |
| M3 — Infrastructure/application HA | Cross-cutting gates in 8.1–8.8 and HA tests in 8.11/8.13 | Separate CM/workload operations, zone placement, remaining-CM management operation, workload/proxy/backend failover, monitoring continuity/recovery, measured interruption and RTO/RPO. A node count is not evidence by itself. |
| M4 — Self-healing and automated recovery | 8.9–8.11 | Bounded service recovery, backend inventory reconciliation, workload replacement/configuration, actionable failed-recovery alert, and documented manual intervention/data-restore boundaries. |
| M5 — Scaling and final validation | 8.12–8.13 | Vertical SKU/disk and horizontal workload map changes, inventory/proxy/Tunnel Pool updates, quota/cost checks, safe add/remove and rebuild. 250 workloads is a design/automation target only; Terraform map changes are provisioning, not autoscaling. |

### Milestone execution protocol

1. Audit repository state and documentation read-only; report current implementation, actual evidence, dependencies, conflicts, and unverified assumptions.
2. Provide an architecture and file-by-file patch plan with exact files/sections, preservation notes, risks/cost, tests, and rollback.
3. Wait for explicit approval of that milestone's plan before changing files. A separate approval is required for code/infrastructure work and another for apply/destroy, live Cloudflare/Tailscale changes, or fault injection.
4. Implement only the approved milestone scope. Preserve established workflows, identities, names, acceptance IDs and unrelated history; stop and request approval if a new conflict or scope expansion appears.
5. Validate documentation, frontmatter, acceptance IDs, references and diffs. Record `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN` honestly. Do not claim production readiness, zero downtime, autoscaling, or capability completion without evidence.

## 7. Change-control contract for agents and contributors

- Read this blueprint, `PHASE-8-FILE-MANIFEST.md`, `PHASE-8-TEST-MATRIX.md`, and current target files before editing.
- Work on one phase at a time by default. This repository's M1–M5 batch was explicitly approved for continuous code implementation; live cloud operations and fault injection still require separate approval.
- The manifest is the allowlist of planned file changes. Mark each path `CREATE`, `UPDATE`, `KEEP`, or `DEFER` after comparing it with the repository. Do not duplicate existing functionality.
- Deliver complete files, not snippets or placeholders. Preserve unrelated user edits. Never overwrite an existing file without inspecting it first.
- Run one final non-destructive static validation after the approved implementation batch; do not pause for repeated intermediate checks. Static checks do not prove deployment, security, or recovery behavior.
- If a change would alter architecture, interfaces, products, network paths, identities, or secrets handling, stop and propose a blueprint update before coding.
- Update the manifest, test matrix, and changelog with every accepted implementation/decision. Record test evidence as `PASS`, `FAIL`, or `NOT RUN`; never infer a pass.

## 8. Definition of completion

Phase 8 is complete only when all implementation entries in the manifest are reconciled with the repository, all applicable T01–T10/A01–A12 checks have recorded results, rebuild and rollback instructions have been exercised or explicitly marked not run, and the README/operator guide match the code. Until then this blueprint documents a target, not a claim that the repository already provides full zero-touch observability or recovery.
