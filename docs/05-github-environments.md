# 05 — GitHub Environments, secrets, variables, and protection

Create the environments below under Repository → Settings → Environments. Names are case-sensitive and form part of OIDC subjects; do not rename them without updating federated credentials.

In the GitHub repository, open **Settings → Environments → New environment**, enter one exact name from the tables below, and select **Configure environment**. Repeat for every listed environment. Inside each environment, use **Add environment secret** for secret values and **Add environment variable** for non-secret values; enter the exact uppercase key, paste its matching value, and save. Do not create repository-wide copies as a substitute: each workflow references an environment-scoped value. After setup, revisit each Environment and confirm the key names appear in the correct Secrets or Variables section (GitHub does not reveal saved secret values).

## Azure environments

Use the Entra app for the matching environment from document 03. Add these **secrets** to each environment:

| Environment | `AZURE_CLIENT_ID` | `AZURE_TENANT_ID` | `AZURE_SUBSCRIPTION_ID` | Additional secret | Variables |
|---|---|---|---|---|---|
| `terraform-identity-plan` | Identity plan app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-identity-apply` | Identity apply app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-vmresource-plan` | VM plan app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-vmresource-apply` | VM apply app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-destroy` | Destroy app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |

`SSH_PUBLIC_KEY` must contain the public half of the key pair, e.g. the complete single-line content of the `.pub` file. Never put the private key in these Terraform environments or in the repository. This is the key Azure installs during VM provisioning; the documented normal CM access path is Tailscale SSH, and this lab does not configure/verify a separate private-key recovery path.

The destroy workflow uses `terraform-vmresource-plan` to create a destroy plan, then pauses at the protected `terraform-destroy` Environment before applying that exact saved plan. The plan Environment must have the Azure plan app and the VM-resource variables/secrets listed above. If `terraform-vmresource-plan` has required reviewers, that first approval permits plan generation only; it does not approve destruction. Review the published plan summary, then approve the protected `terraform-destroy` Environment to authorize applying that exact artifact. Restrict both Environments to `main`. The plan identity needs the documented state access and read permissions, while the destroy identity is authorized to delete module-02 resources.

## Tailscale environments

- `tailscale-ci`: create secrets `TAILSCALE_CI_CLIENT_ID` and `TAILSCALE_CI_AUDIENCE` only. No `SSH_PRIVATE_KEY` secret is required for the current CI-to-CM connection.
- `tailscale-policy`: create variables `TAILSCALE_POLICY_CLIENT_ID`, `TAILSCALE_POLICY_AUDIENCE`, and `TAILSCALE_TAILNET`.

The CI workflow joins the tailnet using the Tailscale OIDC credential, then uses its existing OpenSSH commands to connect to the CM's Tailscale IP. The VM's Tailscale SSH server and tailnet policy authorize that connection; the workflow does not need the administrator SSH private key. The `SSH_PUBLIC_KEY` remains configured on the VMs for Azure VM provisioning, but is not the CI authentication mechanism.

The deployment workflow currently uses `StrictHostKeyChecking=accept-new`. This accepts an unknown key on first connection and rejects a changed key only when the key is subsequently remembered. The generated workload inventory also sets `UserKnownHostsFile=/dev/null`, so that host key is not retained across connections. Tailscale identity/policy authorizes access but does not replace host-key verification. Sensitive deployments should provision and verify host keys through a trusted channel.

## Protect environments and `main`

Configure protection while viewing each Environment's settings:

### Part 1: Configuring Environment Protection

To access the Environment settings: 
👉 Go to your **Repository** $\rightarrow$ Click the **Settings** tab $\rightarrow$ In the left sidebar, click **Environments**.

#### 1. For Apply and Destroy Environments: `terraform-identity-apply`, `terraform-vmresource-apply`, `terraform-destroy`
*Note: The destroy environment is exceptionally sensitive; configure with extreme care.*

1. Click on the environment name (e.g., `terraform-identity-apply`).
2. Enable **Required reviewers**:
   * Check the box to enable required reviewers.
   * Add trusted accounts or maintainers who are authorized to approve deployments.
3. Under **Deployment branches and tags**:
   * Click the dropdown and change it from *No restriction* to **Selected branches and tags**.
   * Type **`main`** and click **Add rule**.
4. Click **Save protection rules** (or save environment) at the bottom of the page.
5. Repeat these exact steps for `terraform-vmresource-apply` and `terraform-destroy`.

---

#### 2. Security Considerations for Plan Environments
* **Warning:** Jobs running plan operations receive the Environment's secrets and request Azure OIDC access. Pull-request workflows execute repository code, so untrusted contributors must not be able to obtain privileged Azure credentials or state access.
* **Fork protection:** The checked-in Terraform plan jobs skip pull requests from forks. This does not make same-repository PR code inherently safe.
* **Required review:** Configure trusted reviewers for `terraform-identity-plan` and `terraform-vmresource-plan`, restrict who can approve, and verify effective GitHub Environment and Entra federated-credential settings. Do not rely on Environment secrets alone as a boundary for untrusted pull-request code.
* **Best practice:** Keep the repository private if that matches your collaboration needs, but still protect the plan Environments. Repository visibility alone does not replace OIDC subject, Environment, permissions, and reviewer checks.

---

#### 3. Configuring the `tailscale-policy` Environment
- This environment is shared by both PR validation tests and main apply jobs.
- **Important Caveat:** Because GitHub Environments apply protection rules globally to any job referencing them, enabling *Required reviewers* for this environment will also cause automated Pull Request tests to be **gated (paused)** in a yellow "Waiting / Pending review" state.
- **How to Configure & Handle:**
  1. Under **Deployment branches and tags**, select **No restriction** (allowing PR branches to run validation tests without being blocked).
  2. Keep **Required reviewers** enabled below so that actual deployments when code merges to `main` remain safely protected and require manual approval.
  3. *Note:* If you ever see a PR check paused in a yellow review state, simply navigate to your repository's *Settings $\rightarrow$ Environments $\rightarrow$ tailscale-policy* and click **Approve and deploy** to let the workflow proceed.

---

#### 4. Configuring the `tailscale-ci` Environment
1. Click on the **`tailscale-ci`** environment.
2. Under **Deployment branches and tags**, restrict deployments exclusively to **`main`**.
3. **Decision on Reviewers:**
   * *For maximum safety:* Add Required reviewers so that every time Terraform provisions a new VM on `main`, the automated Ansible configuration pauses until you manually approve it.
   * *For 100% automation:* Leave reviewers empty if you want CI/CD pipelines to run continuously without manual interruption.

---

### Part 2: Branch Protection for `main`

#### Step 1: Enable GitHub Actions (if not already enabled)
👉 Go to **Settings** $\rightarrow$ Left sidebar **Actions** $\rightarrow$ **General** $\rightarrow$ Ensure **Allow all actions and reusable workflows** is selected $\rightarrow$ Click **Save**.

#### Step 2: Create a Branch Ruleset for `main`
👉 Go to **Settings** $\rightarrow$ Left sidebar **Rulesets** $\rightarrow$ **Rulesets** $\rightarrow$ Click **New ruleset** $\rightarrow$ Select **New branch ruleset** (or *Add branch protection rule*).

1. **Target branches:** 
   * Name your ruleset (e.g., `Protect Main before PR`).
   * Enforcement status: Set to **Active**.
   * Target branches $\rightarrow$ Add target $\rightarrow$ Select **Include by pattern** (then type `main` and add).
2. **Required Settings to Check:**
   * [x] **Require a pull request before merging**: 
     * Set minimum required approvals to at least `1`.
     * [x] **Dismiss stale approvals when new commits are pushed** (Invalidates old approvals when new code is pushed).
     * [x] **Require review from Code Owners** (Enforces reviews based on the `.github/CODEOWNERS` file).
   * [x] **Require status checks to pass before merging** (Blocks merging until required status checks succeed).
     * [x] **Require branches to be up to date before merging** (Invalidates old branches).
     * [x] **Required status checks** $\rightarrow$ **Add checks** $\rightarrow$ Find **plan** $\rightarrow$ and check **Terrform Identity Plan** and **Terraform VM Resource Plan**  (Required Plan Completed before Merge to Main).

---

### Part 3: Selecting Required Status Checks - Use for Verify Steps only (Avoiding Merge Deadlocks)

*Do not rush to type check names prematurely; the repository needs to register their exact names first.*

1. **Create a Documentation PR (Test PR):**
   * Create a new branch, make a harmless modification (e.g., update `README.md`), push it to GitHub, and open a Pull Request targeting `main`.
2. **Inspect the Check Names:**
   * Scroll down to the automated checks section at the bottom of the Pull Request. 
   * Note the exact names reported for the Terraform checks: **Terraform Identity Plan** and **Terraform VM Resource Plan**, alongside relevant Ansible/Tailscale tests.
3. **Update Your Ruleset:**
   * Return to the Ruleset created in *Part 2*, locate **Require status checks to pass**, type or select the exact check names you just identified.
   * *Caution:* Never require checks that cannot run for specific paths or conditional jobs that might get skipped; otherwise, GitHub will permanently block merging.
   * Click **Save changes**.

---

### Part 4: Code Owners & Final Verification Checklist

#### 1. Code Owners Compliance
* Although the repository includes a `.github/CODEOWNERS` file, the file itself does **not** enforce approvals by default unless *Require review from Code Owners* is explicitly enabled in your branch rules.
* Ensure all listed owners and teams have proper repository access.
* **Golden Rule:** Even as repository owner, **never approve your own production-grade changes** as a substitute for an independent reviewer.

#### 2. Final Verification Checklist
1. [ ] Re-open each **Environment** under *Settings* $\rightarrow$ Verify deployment branches (`main`) and reviewers are correctly set.
2. [ ] Re-open the **Rulesets** page $\rightarrow$ Confirm the active rule correctly targets `main`.
3. [ ] Open a **Test PR** $\rightarrow$ Confirm expected status checks appear and successfully block merging when they fail *(Do not test this by approving a real infrastructure apply)*.
4. [ ] Final sanity check: GitHub Environments do **not** automatically inherit secrets from one another. Confirm every workflow's required secrets and variables are explicitly defined in their respective environments.

👉 Once completed, you are ready to proceed with **06 — Deploy and verify**.

 Continue with [06 — Deploy and verify](06-deploy-and-verify.md).