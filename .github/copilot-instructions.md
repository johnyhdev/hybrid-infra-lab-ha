# Workspace Agent Instructions

- Start every repository task by reading `PROJECT-STATUS.md`. Treat it as the concise repository map and implementation-status index.
- Read only the source files named by that map and directly related files required for the requested change. Do not scan the repository broadly or re-read unrelated files.
- Do not read or use `docs/**` or `.github/agents/**` as implementation context unless the user explicitly requests those sources. Those materials are retired from the agent workflow; do not rely on cached/copied content from them.
- The status file describes current code separately from planned direction. Verify the actual target file before editing; never report planned work as implemented or tested.
- Preserve the agreed direction: low added cost; no unnecessary paid services, VM, data disk, or HSM; CM/workload HA; least privilege, OIDC/managed identity, private-by-default access, TLS, and no committed/runtime secret exposure. Explain cost-impacting proposals and do not deploy/apply infrastructure without explicit user authorization.
- Make the smallest relevant change, run the focused validation available for it, and report any untested runtime or Azure behavior.
- When implementation status, source locations, or an architecture decision changes, update `PROJECT-STATUS.md` and/or `IMPLEMENTATION-DECISIONS.md` in the same change. Record unresolved tradeoffs as open decisions rather than silently choosing a paid or availability-impacting design.
