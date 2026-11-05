---
name: hybrid-infrastructure-documentation
description: 'Review and improve infrastructure-lab documentation for portfolio use. Use when updating README narratives, verifying architecture and security claims against Terraform, Ansible, CI workflows, Tailscale policy, or revising limitations and cleanup guidance. Keep English clear at B1 level and translate remaining Vietnamese text into English.'
argument-hint: 'Describe the documentation to review and the project goal'
---

# Hybrid Infrastructure Documentation

## Goal

Make repository documentation easy to present to HR and technical leads while keeping every technical claim supported by the checked-in implementation. Explain the infrastructure mindset through automation, identity-based access, private networking, and security trade-offs without presenting a learning lab as production-ready or claiming security outcomes that have not been verified.

## Procedure

1. **Identify the requested outcome and scope.** Find the primary README, numbered guides, workflows, infrastructure code, and policies. Treat examples or draft documents only as style references; do not copy unverified code, stale links, or unsupported promises.
2. **Build a fact map from the repository.** Verify Terraform roots, state/backend setup, Azure resources, network exposure, identities and permissions, VM authentication, cloud-init, Ansible roles, GitHub Actions triggers and environments, and Tailscale routes/grants/SSH rules. Separate checked-in behavior from settings the user must configure in Azure, GitHub, or Tailscale.
3. **Choose the reader-facing story.** For a portfolio README, explain the problem and goal, what the lab builds, how automation and access flow work, the deployment order, what services are configured, and how to verify or clean up. Use short headings and a simple architecture diagram when useful.
4. **Write in clear B1 English.** Prefer short sentences, familiar terms, consistent names, and concrete explanations that the project owner can repeat in an interview. Explain technical terms once. Do not use marketing claims such as “highly secure,” “zero risk,” or “production-ready” unless independently demonstrated.
5. **Review limitations and cleanup as safety-critical content.** Preserve warnings about public exposure, key and state handling, disabled host-key verification, incomplete services, external approval settings, and destructive workflow behavior. Check cleanup commands, resource scopes, state dependencies, and manual steps against current configuration; do not imply that an approval reviewed a different plan or that Terraform manages manually created resources.
6. **Translate repository Vietnamese text.** Search source, workflow, configuration, and documentation files for Vietnamese comments or prose. Translate only human-readable text, preserving code, identifiers, command behavior, and file formats.
7. **Validate the result.** Check every README link and architecture statement against current files. Confirm setup-guide links use real filenames, no unsupported features or fictional commands were introduced, important caveats remain visible, and Vietnamese prose is removed from the requested scope. Review the diff for unintended code changes.

## Quality checks

- Documentation distinguishes implemented controls from desired security goals and external configuration.
- Portfolio language is positive but factual, readable aloud, and useful to both non-technical and technical readers.
- Numbered guides remain the source of detailed setup steps; the README is a trustworthy overview.
- Limitations and cleanup steps are precise, ordered, and explicit about destructive actions and state retention.
- Translations do not alter executable behavior.
