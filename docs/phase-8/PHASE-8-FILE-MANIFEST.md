# Phase 8 File Manifest

This is the Phase 8 change inventory. The M1–M5 code batch is present but static validation and all runtime acceptance tests remain pending. The tables retain the original intended paths; reconcile `CREATE`/`UPDATE` entries below with actual working-tree state before merge. Cloudflare may use the approved Key Vault + workload Managed Identity API Token exception; never expose tokens in Terraform state, cloud-init, logs, or artifacts. SMTP/chat remain subject to separate approval.

**Status key:** `PLANNED` = no implementation yet; `IN PROGRESS`; `IMPLEMENTED` = code/docs changed; `VERIFIED` = documented checks passed; `DEFERRED` = intentionally outside current scope.

## Baseline files to preserve

| Path | Action | Reason / constraint |
|---|---|---|
| `ansible/run.sh` | UPDATE in 8.2/8.12 or KEEP as local wrapper | Reconcile with tailnet-based management and exact-SHA deploy; remove stale Azure-private SSH assumptions without creating a competing entrypoint. |
| `ansible/inventory/generate_inventory.sh` | UPDATE in 8.1–8.2 | Replace VM subnet SSH discovery with Tailscale role-tag/hostname discovery. |
| `ansible/inventory/hosts.yml` | KEEP | Static syntax-check/sample inventory; do not treat hard-coded sample addresses as runtime discovery. |
| `ansible/playbooks/site.yml` | UPDATE in 8.3/8.5 | Orchestrate control/workload cluster roles while preserving explicit groups and a staged non-destructive rollout. |
| `ansible/playbooks/remediation.yml` | KEEP / REVIEW in 8.9 | Existing broad start-services playbook; do not use as an unreviewed dispatcher target. |
| `terraform/**`, `bootstrap/**`, `tailscale/policy.hujson` | UPDATE in 8.1–8.2 | Explicitly in scope for adjustable HA topology, separate workload identity, tailnet enrollment/ACL, internal load balancing and dynamic discovery. |
| `.github/workflows/ansible-deploy-ha.yml` | UPDATE in 8.12 | Reuse current workflow; exact-SHA deploy and smoke checks, preserve approval and OIDC boundaries. |

## Phase-by-phase paths

### M0 — Baseline audit and scope freeze — `READ-ONLY GATE`

| Path / evidence | Action | Purpose |
|---|---|---|
| Existing Terraform, Ansible, cloud-init, Tailscale policy, workflows and docs | READ ONLY | Record implemented code versus verified operation, role/dependency map, current VM/network/identity/software/cost assumptions, and limitations. Preserve working baseline and existing names/IDs. |
| `docs/phase-8/PHASE-8-BLUEPRINT.md`, `PHASE-8-FILE-MANIFEST.md`, `PHASE-8-TEST-MATRIX.md` | UPDATE docs only after M0 plan approval | Record audit evidence and exact scoped file plan; no infrastructure code or live environment changes during M0. |
| `.github/agents/phase8-coordinator.agent.md` and specialist agents | UPDATE docs only after M0 plan approval | Require audit → patch plan → explicit user approval before milestone implementation; code and live operation have separate approvals. |

### 8.0 — Contract and planning documents — `IMPLEMENTED`; architecture validation pending

| Path | Action | Consumer / dependency |
|---|---|---|
| `docs/phase-8/PHASE-8-BLUEPRINT.md` | CREATE | All later phases; locked architecture and security decisions. |
| `docs/phase-8/PHASE-8-FILE-MANIFEST.md` | CREATE | All implementers; approved file scope. |
| `docs/phase-8/PHASE-8-TEST-MATRIX.md` | CREATE | Implementers and acceptance owner; pass criteria before implementation. |
| `docs/phase-8/PHASE-8-CHANGELOG.md` | CREATE | Records baseline decisions and approved changes. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | CREATE | Operator-facing deployment, access, secrets, troubleshooting, rollback and rebuild guide; update as code lands. |
| `.github/agents/phase8-coordinator.agent.md` | CREATE | Orders work and enforces docs-first phase gates. |
| `.github/agents/phase8-platform.agent.md` | CREATE | Phases 8.1–8.4 Azure topology, Tailscale, distributed workload ingress, Tunnel Pools, and edge operations. |
| `.github/agents/phase8-observability.agent.md` | CREATE | Phases 8.5–8.8 specialist. |
| `.github/agents/phase8-recovery.agent.md` | CREATE | Phases 8.9–8.11 specialist. |
| `.github/agents/phase8-cicd-acceptance.agent.md` | CREATE | Phases 8.12–8.13 specialist. |
| `.github/agents/phase8-security-reviewer.agent.md` | CREATE | Independent, read-only security review. |
| `README.md` | UPDATE | Link Phase 8 docs and state actual implementation status/limitations. |

### 8.1 — Terraform HA topology, identities, network, discovery — `IMPLEMENTED; VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `terraform/01-identity/main.tf`, `variables.tf`, `outputs.tf` | UPDATE | Add separate least-privilege `id-workload` identity and required WIF/RBAC outputs; preserve CM role scope. |
| `terraform/01-identity/key-vault.tf` or dedicated vault module | CREATE after scope review | Provision Key Vault and narrowly scoped workload-MI read permission only; never manage the Cloudflare API Token secret value in Terraform/state. |
| `terraform/02-vmresource/variables.tf` | UPDATE | Count/map validation, HA mode, zone constraints, identity inputs and tunable VM sizing. Existing maps are the preferred scaling interface. |
| `terraform/02-vmresource/control.tf`, `workload.tf` | UPDATE | Attach identities per role and expose dynamic node maps; remove per-node static SSH key assumptions after Tailscale SSH tests. |
| `terraform/02-vmresource/network.tf` | UPDATE | Restrictive NSGs for Tailscale bootstrap/egress, private TLS service paths, LB probes and no public management ingress. |
| `terraform/02-vmresource/load-balancer.tf` | UPDATE only if required/cost-approved | Private frontend/backend wiring and probes if needed; default ingress must work without Cloudflare Load Balancing or a central gateway. |
| `terraform/02-vmresource/main.tf`, `outputs.tf` | UPDATE | Private DNS/service-discovery outputs and complete endpoint maps. |
| `bootstrap/cm-cloud-init-ha.yaml`, `workload-cloud-init-ha.yaml` | UPDATE | Per-role WIF/Tailscale enrollment, no persistent CM→workload private key, no unpinned clone of `main`; minimal bootstrap only. |
| `tailscale/policy.hujson` | UPDATE | `tag:workload` ownership, least-privilege grants/SSH, role-to-role and CI/admin access. |
| `ansible/inventory/generate_inventory.sh`, `ansible/ansible.cfg` | UPDATE | Dynamic Tailscale inventory for CM/workload groups; no hard-coded IPs or plaintext VNet SSH. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Scale parameters, supported zones, cost notes, identity setup and HA/non-HA mode. |

### 8.2 — Tailscale management and zero-trust ACL — `IMPLEMENTED; VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `tailscale/policy.hujson` | UPDATE | Identity-based access for operators/CI to CM and workload; deny by default; no broad `*` grant. |
| `bootstrap/cm-cloud-init-ha.yaml`, `workload-cloud-init-ha.yaml` | UPDATE | Exchange short-lived Azure MI OIDC assertions for Tailscale enrollment; role tags and auto-renewal. |
| `.github/workflows/ansible-deploy-ha.yml` | UPDATE (implemented in 8.12) | CI joins tailnet via OIDC and runs management over tailnet; phase 8.2 must define interface. |
| `ansible/inventory/generate_inventory.sh` | UPDATE | Use Tailscale DNS/IP for Ansible target selection. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Tailscale SSH/admin access and recovery path. |

### 8.3 — Distributed workload proxy and application HA — `IMPLEMENTED; VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `ansible/roles/workload_resilience/**` | CREATE/UPDATE after recheck | Nginx/app health, restart policy and load-balancer readiness on all workload members. |
| `ansible/roles/nginx/**`, `ansible/roles/sample_app/**` | UPDATE after proxy/backend design | Dedicated proxy listener, local app/web listener, private backend proxying, health checks and stateless multi-node behavior; preserve existing interfaces where possible. |
| `ansible/roles/postgresql/**` | KEEP / bounded UPDATE | Preserve single-instance PostgreSQL baseline; document service availability, backups, restore and recovery. No Patroni in required baseline. |
| `ansible/playbooks/application.yml`, `ansible/group_vars/all.yml`, `control.yml`, `workload.yml` | UPDATE after review | Apply workload proxy/app configuration to every member, dynamic service-group inventory and health checks; centralize approved package versions. |
| `ansible/group_vars/package_versions.yml` or existing central variables | CREATE/UPDATE after path review | Pin critical package/runtime versions by default and separate install, security patch, and major/minor upgrade policy. |
| `ansible/roles/*/tasks/**` for baseline, Nginx, PostgreSQL, Node Exporter, app | UPDATE after version policy review | Replace uncontrolled runtime upgrades with centralized approved versions; report actual installed versions and verify health after controlled updates. |
| `ansible/roles/postgresql_patroni/**` or equivalent | DEFER optional module | Only add after a concrete application requirement, separate cost/architecture review and approval. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Single-database limitations, backup/restore, maintenance and recovery; Patroni future option only. |

### 8.4 — Cloudflare Tunnel Pools/WAF and distributed ingress — `IMPLEMENTED; EXTERNAL VALUES/AUTH VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `cloudflare/tunnel-pools.yml` or approved canonical pool data source | CREATE after path/layout review | Logical pools with pool name, distinct Tunnel ID, region, service group, desired/max replicas, workload membership/status; validation rejects >25 connectors per tunnel (verify current limit). |
| `ansible/group_vars/all.yml` or `ansible/group_vars/cloudflare.yml` | UPDATE/CREATE after recheck | Non-secret pool metadata, connector limits and service-group config; no API/Tunnel token. |
| `ansible/roles/cloudflared/**` | CREATE after auth review | One least-privilege connector on each workload VM; retrieve authorized Cloudflare API Token from Key Vault via workload MI at runtime, obtain/refresh Tunnel Token; no token in custom_data/state/logs. |
| `ansible/roles/cloudflared/files/**` or `templates/**` | CREATE after runtime flow review | Token retrieval/refresh helper must avoid argv/env/file/log persistence, validate TLS and fail closed; use OS/runtime credential facilities appropriate to cloudflared. |
| `ansible/roles/nginx_proxy/**` or existing `ansible/roles/nginx/**` | UPDATE/CREATE after recheck | Dedicated proxy listener/port, private dynamic upstream inventory, passive health/failure settings, bounded retries/timeouts, loop prevention, config validation/reload. |
| `ansible/roles/nginx_proxy/templates/**` or existing Nginx templates | UPDATE/CREATE after recheck | Consistent service-group upstream config rendered from controlled inventory; avoid retrying non-idempotent methods unless explicitly safe. |
| `terraform/02-vmresource/network.tf`, `load-balancer.tf` | UPDATE only where needed | Private proxy/backend paths and health probes; no public origin ingress. Native private LB is optional and cost-reviewed; no mandatory Cloudflare LB or central gateway. |
| `.github/workflows/cloudflare-*.yml` or existing protected workflow | UPDATE/CREATE after credential/data-flow review | Provision/manage Cloudflare resources without exposing token in Terraform state or workflow logs; use workload MI→Key Vault at runtime. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Tunnel Pools, quotas/API rates/pricing, connector recovery, secret enrollment outside Terraform, runtime retrieval, expiry, rotation/revocation, and Key Vault outage behavior. |

### 8.5–8.8 — HA Observability, TLS, alerts, Grafana — `IMPLEMENTED; VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `ansible/roles/monitoring_stack/tasks/main.yml` | CREATE after recheck | Redundant Prometheus, Alertmanager, Grafana and Loki on the CM pool. |
| `ansible/roles/log_collector/**` | CREATE after collector selection | Grafana Alloy or another approved lightweight collector on CM/workload nodes; send logs to private Loki endpoints using verified TLS. |
| `ansible/roles/node_exporter/**` | UPDATE after transport design | Node Exporter private listener with TLS/peer validation; add mTLS only if justified and certificate lifecycle is approved. |
| `ansible/roles/internal_pki/**` | CREATE only for justified mTLS flows | Certificate issuance/renewal and recovery for selected flows; not a mandatory global dependency. |
| `ansible/roles/monitoring_stack/tasks/provisioning.yml` | CREATE after recheck | Idempotent Grafana provisioning tasks (8.8). |
| `ansible/roles/monitoring_stack/handlers/main.yml` | CREATE after recheck | Safe service reload/restart handlers. |
| `ansible/roles/monitoring_stack/templates/prometheus.yml.j2` | CREATE after recheck | Private workload target discovery from inventory and rule file configuration. |
| `ansible/roles/monitoring_stack/templates/workload-alerts.yml.j2` | CREATE after recheck | 8.7 rules; escape Prometheus templates from Jinja. |
| `ansible/roles/monitoring_stack/templates/alertmanager.yml.j2` | CREATE after recheck | 8.7 routing; no secret values in template. |
| `ansible/roles/monitoring_stack/templates/*systemd*` | CREATE after recheck | Pinned ARM64-compatible service units, tailnet-only operator listeners, private TLS telemetry listeners, filesystem boundaries. |
| `ansible/roles/monitoring_stack/templates/loki-config.yml.j2` | CREATE after source/version review | 8.5 replicated Loki with durable object storage. |
| `ansible/roles/log_collector/templates/**` | CREATE after selection | 8.6 private-IP log forwarding with TLS and server identity validation; use mTLS only if approved for this flow. |
| `ansible/roles/monitoring_stack/templates/grafana-datasource.yml.j2` | CREATE after recheck | Git-provisioned Prometheus/Loki data sources. |
| `ansible/roles/monitoring_stack/templates/grafana-dashboard-provider.yml.j2` | CREATE after recheck | Dashboard provider definition. |
| `ansible/roles/monitoring_stack/templates/hybrid-infrastructure-dashboard.json.j2` | CREATE after recheck | Availability, services, resources, network, alerts. |
| `ansible/playbooks/monitoring.yml` | CREATE after recheck | Explicit control-only entrypoint; do not silently make site deployment install stack until validated. |
| `ansible/roles/workload_resilience/**` and/or a dedicated probe role | CREATE/UPDATE after 8.3 design review | HTTP/LB readiness and service health across all workload nodes; avoid duplicate exporters. |
| `ansible/group_vars/all.yml` | UPDATE | Shared pinned versions, ports, paths, retention and probe settings after actual values chosen. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Install, tailnet UI access, TLS/query/rule validation, eligible notification setup and troubleshooting. |

### 8.9–8.11 — Dispatcher, fixed recovery and controlled test — `IMPLEMENTED; VALIDATION/TEST AUTHORIZATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `ansible/roles/recovery_dispatcher/tasks/main.yml` | CREATE after threat review | Unprivileged dispatcher service, short-lived/federated caller identity, tailnet/private TLS listener; mTLS only if justified. |
| `ansible/roles/recovery_dispatcher/files/dispatcher.py` | CREATE after interface review | Canonical static source; fixed schema/action mapping, no dynamic shell execution. |
| `ansible/roles/recovery_dispatcher/templates/dispatcher.service.j2` | CREATE after recheck | Unprivileged service identity, hardening, resource/timeout limits. |
| `ansible/roles/recovery_dispatcher/templates/sudoers-recovery.j2` | CREATE after security review | Exact wrapper allowlist only; validate with `visudo`. |
| `ansible/roles/recovery_dispatcher/templates/recovery-*` | CREATE after recheck | Root-owned no-argument wrappers for fixed actions. |
| `ansible/playbooks/remediation/restart-*.yml` and `stop-cpu-test.yml` | CREATE after recheck | One fixed, bounded action per playbook and target group. |
| `ansible/playbooks/drift-check.yml` | CREATE after recheck | Deterministic scoped desired-state check; no broad self-modification. |
| `ansible/roles/cpu_test/**` | CREATE after recheck | Separate cgroup/resource-limited test service and textfile marker. |
| `ansible/playbooks/cpu-test-setup.yml`, `cpu-test-start.yml` | CREATE after recheck | Explicit setup/start controls for the isolated test workload. |
| `ansible/group_vars/all.yml` | UPDATE | Allowlisted action IDs and fixed safe limits only, no secrets. |
| `ansible/playbooks/remediation.yml` | UPDATE only if necessary | Retain compatibility; dispatcher must not target an ambiguous broad playbook. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | Short-lived identity/certificate rotation, observe-only enablement, recovery runbook, audit and rollback. |

### 8.12–8.13 — CI/CD and acceptance — `IMPLEMENTED; STATIC VALIDATION PENDING`

| Path | Action | Consumer / dependency |
|---|---|---|
| `.github/workflows/ansible-check.yml` | UPDATE | YAML, syntax/lint, Python compile/unit tests, monitoring-config validation, secret scan; no deployment credentials. |
| `.github/workflows/terraform-identity-apply-ha.yml`, `terraform-vmresource-apply-ha.yml` | UPDATE | Protected apply dependencies, secure map inputs, outputs/artifacts and successful provisioning handoff. |
| `.github/workflows/ansible-deploy-ha.yml` | UPDATE | Trigger after reviewed apply or approved config merge, protected Environment, exact-SHA Tailscale deployment, concurrency control, smoke tests and commit evidence. |
| `ansible/scripts/validate-repo.sh` | CREATE after checking for equivalent | Local parity with non-privileged CI validation. |
| `ansible/scripts/smoke-test.sh` | CREATE after checking for equivalent | Run bounded loopback smoke tests on the CM after approved deployment. |
| `ansible/tests/**` or `tests/phase8/**` | CREATE after test layout selection | Dispatcher unit/security tests and config tests; no real recovery by default. |
| `docs/phase-8/PHASE-8-TEST-MATRIX.md` | UPDATE | Commands, actual results, evidence link and commit for each test. |
| `docs/phase-8/PHASE-8-CHANGELOG.md` | UPDATE | Accepted design/code decisions, deviations and validation outcomes. |
| `docs/phase-8/PHASE-8-OPERATIONS.md` | UPDATE | End-to-end deploy/rebuild/rollback instructions. |
| `README.md` | UPDATE | Reflect actual implemented status; no unsupported “100%/HA” claims. |

## Deferred / out of scope unless blueprint is amended

| Path / capability | Action | Reason |
|---|---|---|
| `terraform/**`, `bootstrap/**`, `tailscale/policy.hujson` | UPDATE as listed in 8.1–8.2 | HA topology, Tailscale identities/ACLs and dynamic management are explicitly in scope, including workload Tailscale enrollment. |
| Cloudflare Tunnel/WAF, workload log forwarding | PLANNED with credential/TLS gates | Cloudflare API Token exception is approved only through Key Vault + workload MI and safe runtime retrieval; TLS required, mTLS only when justified. |
| AWX, Keepalived/ARP VIP, workload public IP, public monitoring endpoint | REJECT / DEFER | AWX excluded for resource cost; Azure-native load balancing is preferred; public origin/admin access violates the boundary. |
| Any public monitoring port or public VM address | REJECT | Violates locked private-network boundary. |
| Terraform apply/destroy from recovery dispatcher | REJECT | Recovery has no infrastructure lifecycle privilege. |

## Change procedure

Before a phase starts, the owner updates the phase status and confirms each affected path/action against the working tree. After implementation, replace planned actions with actual outcomes, list added/removed paths, record tests and evidence, and update this manifest in the same change. A path not listed here is not implicitly approved for modification.
