# Phase 8 Acceptance Test Matrix

**Status:** Implementation code is present. Final local checks recorded below; Ansible lint/syntax, Python unit tests, and all runtime/safety results remain `NOT RUN`. Do not infer operational success from code or partial static checks.
**Evidence rule:** Record result, UTC timestamp, tested commit SHA, environment/target, command or procedure, concise output/log reference, and operator for every run. Remove secrets and bearer tokens from evidence.

### Final implementation-batch static checks

| Check | Result | Evidence |
|---|---|---|
| Terraform fmt (identity + VM roots) | PASS | `terraform -chdir=terraform/01-identity fmt -check -recursive`; same for `terraform/02-vmresource`; 2026-11-10 11:47 +07, source revision `6855e5a38f62e753513ebbc2eabed76c0089a85a`. |
| Terraform validate (backend disabled) | PASS | Both roots initialized with `-backend=false` and validated; no Azure plan/apply; same revision/time above. |
| `git diff --check` | PASS | No whitespace errors; Git emitted only LF-to-CRLF working-copy warnings; same revision/time above. |
| Ansible lint/syntax, YAML parse, Python unit tests | NOT RUN | Python unit-test run was explicitly skipped; local Ansible/Bash tooling unavailable. The CI/local validation script remains the full check entry point. |
| T01–T10 and A01–A12 | NOT RUN | No deployment or runtime/fault-injection tests performed. |

## Mandatory design gates before any deployment

- **Provider authentication:** Prefer federation. If Cloudflare lacks suitable federation, use only the approved narrowly scoped, expiring API Token in Azure Key Vault, retrieved by workload Managed Identity at runtime to obtain/refresh Tunnel Tokens. Never pass tokens via Terraform state, cloud-init, logs or artifacts. SMTP/chat need a separate approved credential flow.
- **TLS/mTLS:** HTTPS/TLS is required for designated private data-plane flows. For each flow, document whether mTLS is justified. If enabled, approve issuer, identity binding, key custody, issuance/renewal/distribution/revocation/recovery and CA outage behavior first.
- **Database/HA targets:** baseline PostgreSQL is a single instance; approve backup/restore expectations and numeric RPO/RTO before coding or fault injection. Patroni is optional future work and is not required for Phase 8 acceptance.
- **Tunnel Pools:** verify current Cloudflare connector-per-Tunnel limit, account quotas, API rate limits and pricing; pool validation must enforce the verified limit (target maximum 25 per tunnel) and never assume replicas provide backend load balancing.
- **Cloud account preconditions:** Azure subscription quotas, at least two supported availability zones, DNS ownership, Cloudflare account/WAF capability, protected GitHub Environment and OIDC federation must be prepared. These are bootstrapped prerequisites, not values committed to Git.

## End-to-end tests (T01–T10)

### M0 baseline audit evidence (not a new acceptance ID)

Before implementation, record current Terraform/Ansible/workflow/Tailscale roles and dependencies; distinguish code present from runtime-verified behavior; capture VM/SKU/zone/network/identity/software assumptions; note current monitoring/logging/recovery gaps and cost/quotas where observable. Preserve the existing working foundation. Runtime deployment evidence must not be inferred from repository source alone.

| ID | Test | PASS criteria | Validation / evidence | Result |
|---|---|---|---|---|
| T01 | Provisioning and configurable topology | Protected merge provisions requested map-defined VM counts; HA mode creates at least 2 CM + 2 workload nodes across distinct zones, dynamic addresses, identities, private DNS and healthy pools. Vertical SKU/OS/data-disk inputs are configurable. Horizontal design target up to 250 is documented, not claimed deployed; scale-to-one is visibly non-HA. Quota, subnet capacity and cost assumptions are reviewed. | Terraform plan/resource inventory, generated inventories, SKU/disk configuration, quota/cost review; no secrets in logs. | NOT RUN |
| T02 | Tailnet and zero-trust management | All CM/workload nodes enroll with short-lived WIF and correct role tags; only authorized operators/CI can use Tailscale SSH; Ansible reaches all intended nodes over tailnet; no management path uses public/VNet SSH. | Tailscale status/ACL tests, Ansible reachability, NSG audit and redacted identity evidence. | NOT RUN |
| T03 | Workload and Cloudflare edge HA | Each workload node has an outbound connector and dedicated-port Nginx proxy. Connector failure, proxy failure, local app failure, unhealthy remote backend exclusion, backend recovery, and total workload-node loss are tested separately. Public 80/443 reaches only Cloudflare WAF/Tunnel; no origin public IP/port exists. Tunnel replicas are not counted as backend balancing. Each pool uses distinct IDs/service-group assignment and rejects over-capacity membership at the verified per-Tunnel maximum (design target 25). | Test-domain WAF/Tunnel status, connector/proxy/app/backend health, external origin-bypass test, failover/recovery, pool validation and current provider quota/rate-limit evidence. Cloudflare LB is not required. | NOT RUN |
| T04 | Database baseline backup/restore | The configured single PostgreSQL instance's availability limitation is documented; backup completes and restore is verified within approved RPO/RTO. Application/infrastructure HA tests do not depend on Patroni. | PostgreSQL health, backup artifact integrity, isolated restore and application-independent evidence. Patroni is out of scope unless separately approved. | NOT RUN |
| T05 | TLS and private telemetry | Designated private metrics/log/service flows use HTTPS/TLS with peer verification; mTLS is tested only for flows explicitly selected and documented. Wrong CA/identity and plaintext downgrade are rejected where applicable; metrics/log queries return data. | TLS verification/expiry/renewal, optional mTLS negative tests, Prometheus target status, selected log collector status and sanitized Loki queries. | NOT RUN |
| T06 | Monitoring HA and notifications | One monitoring-node failure preserves service within approved targets; the remaining CM can execute essential Ansible operations. Metrics cover VM CPU/RAM/disk/network, cloudflared/Tailscale, Nginx proxy/app/backend health, HTTP errors/latency, PostgreSQL, Ansible/cloud-init/deployment failures, capacity and cost; searchable logs include the corresponding services; alert grouping/inhibition works. Chat notification is accepted only with an approved credential flow and verified receipt. | Controlled CM/monitoring-node failure tests, Ansible operation from surviving CM, HA peer status, data continuity, target coverage, searchable logs, sanitized alert receipt and resource-overhead evidence. | NOT RUN |
| T07 | Recovery and fail-closed behavior | Fixed recovery works only for allowlisted alert/action/target; injected failure is audited and bounded; bad identity/state/audit/cooldown fails closed. | Unit/integration negative tests with fake runner, then explicitly authorized lab test; redacted audit. | NOT RUN |
| T08 | Configuration drift, package policy and self-healing | Drift on a selected CM/workload is detected and deterministically restored from Git desired state; critical package/runtime versions are pinned by default, reported, and do not change during ordinary runs; controlled updates are tested on a designated node with health checks and a documented verified rollback source. No unrelated host/service changes; idempotent rerun is clean. | Drift injection and before/after hashes, package version report, controlled update/rollback evidence, Ansible output, post-health checks. | NOT RUN |
| T09 | GitHub zero-touch pipeline | PR checks have no deployment secrets; reviewed merge + protected approval provisions Terraform and configures all nodes using exact SHA and OIDC/Tailscale; smoke tests pass and workflow records provenance. | PR/Actions URLs, SHA equality, Environment approval, federated claims and smoke output. | NOT RUN |
| T10 | HA rebuild, scale and recovery | Rebuild/replace a CM or workload from Git without VM hand edits; replacement joins tailnet and registers connector/proxy/backend inventory automatically. Services/data restore, edge/monitoring recover; scale changes update inventories/proxies safely and enforce pool capacity; measured RPO/RTO met. | Exact SHA, replacement/scale logs, backend registration/removal, data restore, connector/pool capacity and failure-domain evidence. | NOT RUN |

## Security and safety tests (A01–A12)

| ID | Test | PASS criteria | Validation / evidence | Result |
|---|---|---|---|---|
| A01 | Public edge isolation | No VM public IP or direct origin ingress; only Cloudflare WAF routes public 80/443 through outbound Tunnel; monitoring/admin endpoints are not published. | Terraform/NSG audit, Cloudflare config review and external origin-bypass test. | NOT RUN |
| A02 | Tailnet role ACL | `tag:cm` and `tag:workload` are owner-restricted; CI/operator grants are least-privilege; workload is manageable only over tailnet and no broad `*` grant remains. | HuJSON validation and positive/negative Tailscale connectivity tests. | NOT RUN |
| A03 | Credential protection and rotation | Azure/Tailscale use OIDC/managed identity. Cloudflare exception, if needed, is narrowly scoped and expiring in Key Vault; only authorized workload MI can retrieve it at runtime, it is not short-lived, and rotation/revocation work without rebuilding VMs. No API/Tunnel Token appears in Terraform state, variables, cloud-init, GitHub logs, Ansible logs or application logs. SMTP/chat follow separately approved policy. | Credential permission/scope/expiry review, Key Vault access audit, runtime retrieval and rotation/revocation test, state/log/artifact scan; never print token content. | NOT RUN |
| A04 | TLS identity by flow | Every TLS-required private flow verifies peer identity and rejects plaintext/downgrade. Any mTLS flow has documented justification and working certificate issue/renew/distribute/revoke/recovery; non-mTLS flows are not falsely reported as mutual-authenticated. | Automated TLS negative tests; mTLS checks only for approved flows; cert rotation/recovery evidence where applicable. | NOT RUN |
| A05 | Malformed payload | Invalid JSON/schema, oversized input, wrong content type, unexpected alert status, and malformed fields are rejected safely. | Unit/fuzz-style bounded input tests; no shell or playbook launched. | NOT RUN |
| A06 | Unknown action/alert | Unknown alert name, action ID, or alert/action/target combination is rejected; payload cannot select an arbitrary service, host, command, file, or playbook. | Negative tests and fixed mapping review. | NOT RUN |
| A07 | Cooldown fail-closed | Duplicate action within cooldown is rejected; corrupt/missing/unwritable state follows explicit fail-closed policy and cannot trigger recovery. | Unit tests for valid, corrupt, missing and I/O-error state. | NOT RUN |
| A08 | Concurrency and bounds | Concurrent duplicates are serialized/rejected; execution timeout and retry count are enforced; request cannot hold unbounded workers/resources. | Dispatcher unit/integration tests with controlled fake runner. | NOT RUN |
| A09 | Fixed target and verification | Each allowed action targets only its fixed Ansible group/service and has a post-action health check; no payload-controlled target. | Playbook `--syntax-check`, unit tests of mapping, code review. | NOT RUN |
| A10 | No dynamic command execution | No shell command from webhook data; wrappers take no user-controlled arguments; sudoers grants only exact root-owned wrappers. | Static source review, tests with shell metacharacter payloads, `visudo -c`. | NOT RUN |
| A11 | Audit and recovery failure | Every accept/reject/timeout/failure is auditable without secrets; audit write failure prevents execution; recovery failure is bounded and not misreported as success. | Unit tests and controlled integration evidence. | NOT RUN |
| A12 | CI identity boundary | Pull request checks have no Azure/Tailscale/Cloudflare secrets; only protected deployment uses restricted OIDC roles, exact SHA is deployed, no long-lived SSH key is used, and resource lifecycle permissions are scoped. | Workflow permissions, federated subject/audience, Actions evidence and role assignment review. | NOT RUN |

## Static validation (run before any runtime or fault-injection test)

The repository-level script is `ansible/scripts/validate-repo.sh`; run it after environment setup but before any deployment approval. It performs non-destructive local checks only:

- Terraform fmt/validate/plan review and security policy scan for changed HCL; never apply from PR checks.
- Tailscale HuJSON policy validation and positive/negative ACL tests in a non-production tailnet.
- YAML parse for changed YAML files.
- `ansible-playbook --syntax-check` for each changed playbook using the documented inventory and role path.
- `ansible-lint` on `ansible/`.
- Python compile and dispatcher unit tests using the repository-selected Python environment.
- Prometheus rule/config validation and Alertmanager config validation using pinned compatible tools/containers.
- Grafana provisioning JSON/YAML validation.
- Nginx proxy configuration validation, upstream generation consistency, retry/timeout constraints, and proxy-loop checks.
- Cloudflare Tunnel Pool schema/capacity validation and current provider quota/limit documentation.
- TLS configuration validation for designated flows; certificate lifecycle checks only for flows that use certificates (especially mTLS).
- Ansible package-version policy checks: no uncontrolled `latest` for critical packages; report installed versions and verify controlled-update/rollback paths.
- Secret scanning (Gitleaks) over the relevant repository state.
- `git diff --check`, review of changed paths against the manifest, and check that no credentials entered the diff.

Static checks do not replace T01–T10 or A01–A12 runtime/safety evidence.

## Runtime test safety

Fault injection, alert delivery, service stop/restart, and recovery tests require a designated lab maintenance window and explicit operator approval. Do not execute against production or shared services. Capture pre-test state, define a recovery/abort procedure, and restore/verify state even when a test fails. Never run Terraform destroy or destructive cloud actions as an acceptance test without a separate explicit request and approved plan.
