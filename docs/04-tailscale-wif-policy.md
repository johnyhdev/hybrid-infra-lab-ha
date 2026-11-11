# 04 — Tailscale WIF and policy

The repository uses three distinct Tailscale identity flows: the Azure managed identity on the control-manager, the GitHub CI runner, and policy GitOps. Do not interchange their client IDs or audiences. Do not create long-lived Tailscale auth keys for these flows.

## Prepare and apply the initial policy

Apply and validate the complete repository policy before provisioning VMs. Do not retype a shortened example: the source of truth is `tailscale/policy.hujson`.

1. Open the repository root in VS Code. In PowerShell at that root, copy the complete policy text to the clipboard and check that the file is not empty:

```powershell
Get-Content .\tailscale\policy.hujson -Raw | Set-Clipboard
(Get-Item .\tailscale\policy.hujson).Length
```

2. Open Tailscale Admin Console → **Access controls** → policy **JSON editor**. Select all of the current policy text, paste the clipboard contents, and run the editor's **Preview/Validate** action before saving. Resolve any syntax or validation errors; do not save a partial policy.
3. Review the effective policy before applying. The repository version defines `tag:cm`, `tag:workload`, and `tag:ci`; it does not advertise a subnet route. Admins can SSH to both roles, CI can SSH to control managers only, and control managers can SSH to workloads. Monitoring access and peer gossip are restricted to the listed control-manager grants. Confirm the whole policy matches your access model.
4. Save/apply the policy in the Admin Console. Confirm successful validation/save and that the saved policy includes all three tags and SSH grants. A Git commit alone does not apply the initial tailnet policy.
5. If host roles or monitoring ports change later, update the policy and Terraform NSGs together, validate the complete policy again, and only then merge. The policy GitOps workflow tests/applies later changes; it does not provision devices.

The `tailscale-policy-ha` GitHub Environment is used by both PR tests and main-branch apply. Required reviewers on this environment may block PR tests as well; configure protection deliberately.

## GitHub policy GitOps credential

Create a GitHub Actions OpenID Connect trust credential in Tailscale. In the Admin Console's OAuth clients/workload identity federation area, create a credential for GitHub Actions and enter these values in the matching issuer, subject, audience, and permission fields. UI labels can change; choose fields by their meaning, not a static OAuth client-secret option:

- Description: **github-tailscale-policy-ha**
- Issuer: `https://token.actions.githubusercontent.com`
- Subject: exact subject for this repository's `tailscale-policy-ha` environment. Use the repository/owner-ID format verified in document 03, ending in `:environment:tailscale-policy-ha`.
- Permissions SCOPES (Policy Write): policy-file read/test on PRs and policy update after merge (`policy_file` scopes presented by the current Tailscale UI). Do not grant unrelated device-enrollment or administrator scopes to this identity.

Save the credential and record the generated **Client ID**, exact **Audience**, and **Tailnet ID/unique ID** shown by Tailscale. Do not copy a client secret or bearer token. Confirm that the credential is listed in the Admin Console and that its issuer, subject, audience, and permissions are correct. These identifiers are not bearer secrets; store them as GitHub Environment Variables in document 05. A successful PR policy test is the end-to-end check; creation alone does not prove the subject/audience match.

## GitHub CI credential

Create a **separate** GitHub OIDC credential for the `tailscale-ci-ha` environment in the same Tailscale workload identity federation area. Do not reuse the policy GitOps credential:

- Description: **github-tailscale-ci-ha**
- Issuer: `https://token.actions.githubusercontent.com`.
- Subject: exact repository/owner-ID subject for this repository, ending `:environment:tailscale-ci-ha`.
- Permissions SCOPES (Key Auth Keys): allow the GitHub runner to enroll/authenticate a machine as `tag:ci` only; do not grant policy-file write or `tag:cm` enrollment to CI.

Save the credential, record its Client ID and exact Audience separately from the policy and CM values, and verify the saved subject and `tag:ci` scope in the Admin Console. A successful `Ansible CD Deploy` run in document 06 is the end-to-end check that GitHub can join as `tag:ci`.

## Azure managed identity credential

After the identity module creates `id-cm-ha` and `id-workload-ha`, retrieve each identity's identifiers:

```powershell
az identity show --resource-group "<LAB_RESOURCE_GROUP>" --name "<CM_IDENTITY_NAME>" --query "{tenantId:tenantId,principalId:principalId,clientId:clientId}" --output table
```

Create separate Tailscale trust credentials for Microsoft Entra/Azure in the Tailscale workload identity federation area. Select the Entra/Azure identity-provider option offered by the current console; do not choose GitHub for these credentials:

- Description: azure-vm-cm-ha
- Issuer: the exact Microsoft Entra issuer URL required/displayed by the current Tailscale UI for your tenant. Copy it from the UI; do not guess the tenant/version URL.
- Subject: the **principal ID** of the User Assigned Managed Identity `id-cm-ha`, not its client ID.
- Audience: the exact audience required for Azure token exchange by the Tailscale credential (default: **fb60f99c-7a34-4190-8149-302f77469936**). Cloud-init requests a Managed Identity token for resource `api://AzureADTokenExchange` and passes it to Tailscale. Never paste a bearer JWT/access token into configuration, GitHub, or logs.
- Permissions SCOPES (KEY AUTH_KEYS): allow the required machine enrollment for `tag:cm` only. Do not allow GitHub policy updates or `tag:ci` enrollment through this identity.

Create the corresponding workload trust credential using the **principal ID** of `id-workload-ha` as its subject and restrict machine enrollment to `tag:workload`. It uses a separate Client ID/Audience pair from the CM credential. Neither identity should advertise a subnet route.

Save and verify both credentials' issuer, subject, audience, and tag scope. Record the Tailscale CM and workload credential Client IDs/Audiences. Set them as GitHub Variables available to the VM plan/apply/destroy environments. Terraform passes them to cloud-init; each VM uses its attached Azure Managed Identity to join with its own tag. End-to-end verification is that both `vm-cm-*` nodes are online with `tag:cm`, and all `vm-workload-*` nodes are online with `tag:workload`, without advertised routes. If the live console differs from these expectations, reconcile before deploying.

## Keep the identities distinct

| Value | Purpose | GitHub storage |
|---|---|---|
| `TAILSCALE_POLICY_CLIENT_ID`, `TAILSCALE_POLICY_AUDIENCE`, `TAILSCALE_TAILNET` | Policy test and apply | Variables in `tailscale-policy-ha` |
| `TAILSCALE_CI_CLIENT_ID`, `TAILSCALE_CI_AUDIENCE` | CI runner joins the tailnet | Secrets in `tailscale-ci-ha` |
| `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` | Control-manager VM WIF | Variables in VM plan/apply/destroy environments |
| `TAILSCALE_WORKLOAD_CLIENT_ID`, `TAILSCALE_WORKLOAD_AUDIENCE` | Workload VM WIF | Variables in VM plan/apply/destroy environments |
| `id-cm-ha` principal ID | Subject in Azure-to-Tailscale trust | Not a Tailscale client ID; not a GitHub secret |

Verify the policy test succeeds and both CM and workload nodes enroll with the expected tags. Continue with [05 — GitHub Environments](05-github-environments.md).

## Phase 8 workload identity and management

The VM Terraform root attaches a dedicated workload Managed Identity and cloud-init enrolls workloads with `tag:workload`. Tailscale SSH is the normal operator/Ansible access path. Azure SSH public keys remain only as required VM creation inputs; no SSH private key is deployed to workloads or CI.

For Cloudflare Tunnel, the workload Managed Identity has read access only to the Key Vault secret containing the Cloudflare API Token. This is a persistent credential exception, not part of the Tailscale WIF flow. Never put its value in this policy, Git, Terraform state, cloud-init, or logs. See the [external setup checklist](phase-8/EXTERNAL-SETUP.md) and [Phase 8 blueprint](phase-8/PHASE-8-BLUEPRINT.md).