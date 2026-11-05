# 03 — Microsoft Entra OIDC, federated credentials, and Azure RBAC

GitHub Actions authenticates to Azure through GitHub OIDC; do not create a client secret. Use a separate Entra application/service principal for each GitHub Environment so plan and apply permissions remain distinct. The current workflows use five Azure environments.

## Identify the repository and Azure tenant

Authenticate GitHub CLI (`gh auth login`) if required, then run in PowerShell:

```powershell
$repo = "<OWNER>/<REPOSITORY>"
$repoInfo = gh api "repos/$repo" | ConvertFrom-Json
$owner = $repoInfo.owner.login
$ownerId = $repoInfo.owner.id
$repoName = $repoInfo.name
$repoId = $repoInfo.id
$tenantId = az account show --query tenantId -o tsv
$subscriptionId = az account show --query id -o tsv
```

Verify every value from your own GitHub repository and Azure tenant. GitHub may issue immutable repository subjects containing owner and repository IDs. Confirm the actual OIDC `sub` format for your repository before creating credentials. For immutable subjects, the format is:

`repo:<OWNER>@<OWNER_ID>/<REPOSITORY>@<REPOSITORY_ID>:environment:<ENVIRONMENT>`

If GitHub issues a different subject format, use the exact claim GitHub issues. Subject matching is exact.

## Create five Entra applications and service principals

Create a separate app for each environment:

- `terraform-identity-plan`
- `terraform-identity-apply`
- `terraform-vmresource-plan`
- `terraform-vmresource-apply`
- `terraform-destroy`

Run this **once** in PowerShell while signed in to the intended Entra tenant. First check whether any of these names already exist:

```powershell
$displayNames = @(
  "terraform-identity-plan",
  "terraform-identity-apply",
  "terraform-vmresource-plan",
  "terraform-vmresource-apply",
  "terraform-destroy"
)

foreach ($displayName in $displayNames) {
  Write-Host "--- $displayName ---"
  az ad app list --display-name $displayName --query "[].{displayName:displayName,clientId:appId,applicationObjectId:id}" --output table
}
```

If **any** app is listed, stop before running the creation loop; recover and verify the existing application, service-principal, and FIC IDs first. Run the creation block only when all five names return no results. It creates each App Registration and Service Principal, then prints the three different IDs that must be recorded.

```powershell
$displayNames = @(
  "terraform-identity-plan",
  "terraform-identity-apply",
  "terraform-vmresource-plan",
  "terraform-vmresource-apply",
  "terraform-destroy"
)

$appRecords = foreach ($displayName in $displayNames) {
  $app = az ad app create --display-name $displayName | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0) { throw "App creation failed for $displayName." }
  az ad sp create --id $app.appId | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Service Principal creation failed for $displayName." }
  $spObjectId = az ad sp show --id $app.appId --query id -o tsv
  if ($LASTEXITCODE -ne 0) { throw "Could not read Service Principal Object ID for $displayName." }
  [pscustomobject]@{
    DisplayName               = $displayName
    ApplicationClientId       = $app.appId
    ApplicationObjectId       = $app.id
    ServicePrincipalObjectId  = $spObjectId
  }
}

$appRecords | Format-Table -AutoSize
```

Save the output in a secure administrator record (not in the repository). The Application/Client ID (`appId`) goes into the GitHub Environment's `AZURE_CLIENT_ID`; the Application Object ID (`id`) owns the FIC; the Service Principal Object ID receives Azure RBAC assignments. Never substitute one ID type for another. Continue with all five records available; the FIC and RBAC steps below use them.

## Create and verify the five federated credentials

A federated credential (FIC) is an exact trust rule: the issuer, audience, and subject must match the OIDC token from the GitHub job. The workflows use these **case-sensitive** environment names and the Azure App Registration belonging to each row:

| GitHub Environment | FIC name | App Registration |
|---|---|---|
| `terraform-identity-plan` | `github-terraform-identity-plan` | Identity plan app |
| `terraform-identity-apply` | `github-terraform-identity-apply` | Identity apply app |
| `terraform-vmresource-plan` | `github-terraform-vmresource-plan` | VM resource plan app |
| `terraform-vmresource-apply` | `github-terraform-vmresource-apply` | VM resource apply app |
| `terraform-destroy` | `github-terraform-destroy` | Destroy app |

Use the Application **Object ID** (not Client ID and not Service Principal Object ID) in the Azure `--id` argument. First obtain repository information using the same repository that contains these workflows. In PowerShell, run from any directory after `gh auth login`:

```powershell
$repo = "<OWNER>/<REPOSITORY>"
$repoInfo = gh api "repos/$repo" | ConvertFrom-Json
$owner = $repoInfo.owner.login
$ownerId = $repoInfo.owner.id
$repoName = $repoInfo.name
$repoId = $repoInfo.id
"Repository: $owner/$repoName (ID $repoId); owner ID $ownerId"
```

Replace `<OWNER>/<REPOSITORY>` with your actual GitHub slug. Do not use an example repository or IDs copied from another account. The workflow's environment names can be checked in `.github/workflows/terraform-identity-plan.yml`, `.github/workflows/terraform-identity-apply.yml`, `.github/workflows/terraform-vmresource-plan.yml`, `.github/workflows/terraform-vmresource-apply.yml`, and `.github/workflows/terraform-vmresource-destroy.yml`.

For repositories using GitHub's immutable subject format, construct the subject as follows. Confirm that this is the format GitHub issues for your repository; if the actual claim format differs, stop and use the exact `sub` claim GitHub issues rather than trying alternate subjects:

```powershell
$environment = "terraform-vmresource-plan"
$subject = "repo:$($owner)@$($ownerId)/$($repoName)@$($repoId):environment:$environment"
$subject
```

To inspect the claim without printing or storing the bearer token, temporarily add this step **inside the relevant plan job's `steps:` list, before Azure Login** in its workflow file. The job already has `permissions: id-token: write` and names its GitHub Environment. Push a temporary branch/PR to run it:

```yaml
- name: Print OIDC claims only (temporary diagnostic)
  uses: actions/github-script@v7
  with:
    script: |
      const token = await core.getIDToken('api://AzureADTokenExchange');
      const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
      core.info(JSON.stringify({ iss: payload.iss, sub: payload.sub, aud: payload.aud }, null, 2));
```

Read only the printed `iss`, `sub`, and `aud` values in the Actions log. The log must not contain the token itself. Copy the exact `sub` and confirm the issuer/audience match the values configured below. Repeat with a job that uses each environment if needed, then immediately remove the diagnostic step and merge that removal; do not leave token-inspection code in a production workflow. The VM plan subject must end in `:environment:terraform-vmresource-plan`; substitute each environment for its matching app. Do not configure `ref:refs/heads/main` (or another broad branch subject) for a job that uses a GitHub Environment.

If the observed subject does **not** match the immutable format, do not generate/create credentials with the default subject expression below. Instead, create an explicit subject map from the exact `sub` claims observed for these five jobs, for example `$subjects = @{ "terraform-vmresource-plan" = "<EXACT_SUB_CLAIM_FROM_PLAN_JOB>"; ... }`, and change the JSON-generation line to `subject = $subjects[$environment]`. Fill all five map entries from actual job claims before running the generator. Never guess a pattern or copy another repository's claims.

### Generate the five JSON files outside the repository

1. In the PowerShell window, create a temporary folder under the Windows temp directory. This is deliberately not a folder inside your clone:

```powershell
$ficDir = Join-Path $env:TEMP "hybrid-lab-federated-credentials"
New-Item -ItemType Directory -Path $ficDir -Force | Out-Null
Set-Location $ficDir
```

2. Make a map from each environment to its matching **Application Object ID**. Copy each Object ID from the output of `az ad app list --display-name <APP_DISPLAY_NAME> --output table` or the app-creation results. Do not put Client IDs or Service Principal Object IDs in this map.

```powershell
$appObjectIds = @{
  "terraform-identity-plan"    = "<IDENTITY_PLAN_APP_OBJECT_ID>"
  "terraform-identity-apply"   = "<IDENTITY_APPLY_APP_OBJECT_ID>"
  "terraform-vmresource-plan"  = "<VMRESOURCE_PLAN_APP_OBJECT_ID>"
  "terraform-vmresource-apply" = "<VMRESOURCE_APPLY_APP_OBJECT_ID>"
  "terraform-destroy"          = "<DESTROY_APP_OBJECT_ID>"
}
```

Replace all five placeholders with the actual Application Object IDs before continuing. The following block writes one complete JSON document per environment. The generated files contain no passwords or tokens, but are kept outside the clone and removed after verification:

```powershell
$environments = @(
  "terraform-identity-plan",
  "terraform-identity-apply",
  "terraform-vmresource-plan",
  "terraform-vmresource-apply",
  "terraform-destroy"
)

foreach ($environment in $environments) {
  $credential = @{
    name        = "github-$environment"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:$($owner)@$($ownerId)/$($repoName)@$($repoId):environment:$environment"
    description = "GitHub Actions federated credential for $environment"
    audiences   = @("api://AzureADTokenExchange")
  }
  $jsonPath = Join-Path $ficDir "$environment.json"
  $credential | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding ascii
}

Get-ChildItem $ficDir -Filter *.json | Select-Object Name, Length
```

Before creating any credentials, open one generated file to verify the complete values and shape:

```powershell
Get-Content (Join-Path $ficDir "terraform-vmresource-plan.json")
```

It should contain the five JSON properties `name`, `issuer`, `subject`, `description`, and `audiences`. Its subject must end with `:environment:terraform-vmresource-plan`; the other files must end with their respective environment names.

### Create each FIC on its matching app

Run the following. It pairs each JSON with the app object ID from the map, checks each Azure CLI result, and stops on the first failure:

```powershell
foreach ($environment in $environments) {
  $appObjectId = $appObjectIds[$environment]
  $jsonPath = Join-Path $ficDir "$environment.json"
  az ad app federated-credential create --id $appObjectId --parameters $jsonPath --output none
  if ($LASTEXITCODE -ne 0) { throw "FIC creation failed for $environment; stop and correct the reported error." }
  Write-Host "Created FIC for $environment on Application Object ID $appObjectId"
}
```

If a command reports that the credential already exists, do not create a differently named duplicate to bypass the error. List that app's credentials, compare the issuer/subject/audience with the values above, and either keep the exact match or deliberately remove the incorrect credential before retrying.

### Verify every app before deleting the files

List the FICs on each app and inspect all three trust fields. The credential name, subject's environment suffix, issuer, and audience must match the corresponding row and the JSON just created:

```powershell
foreach ($environment in $environments) {
  Write-Host "--- $environment ---"
  az ad app federated-credential list `
    --id $appObjectIds[$environment] `
    --query "[?name=='github-$environment'].{name:name,issuer:issuer,subject:subject,audiences:audiences}" `
    --output json
  if ($LASTEXITCODE -ne 0) { throw "FIC verification failed for $environment." }
}
```

Expect exactly one result for each environment, with issuer `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`, and the exact repository subject ending in that environment. An empty result means the FIC was created on the wrong app, has a different name, or was not created. Correct this before configuring/running the workflow.

After verifying all five, make sure you Set-Location back to Gihub Repo hybrid-infra-lab:

```powershell
Set-Location "<your path github repo hybrid-infra-lab>"
```

 Remove the temporary JSON files and confirm the directory is gone:

```powershell
Remove-Item -LiteralPath $ficDir -Recurse -Force
Test-Path -LiteralPath $ficDir
```

The last command must return `False`. These JSON files are configuration, not bearer credentials; deletion keeps setup artifacts out of the repository. File deletion is not guaranteed secure erasure on SSDs or synced storage, which is why the procedure creates them under the local temp directory in the first place.

To intentionally **revoke** a FIC later, first list the app and copy the exact `name` returned by Azure, then delete that named credential from the same Application Object ID:

```powershell
az ad app federated-credential list --id "<APP_OBJECT_ID>" --output table
az ad app federated-credential delete --id "<APP_OBJECT_ID>" --federated-credential-id "<EXACT_FIC_NAME_FROM_LIST>"
az ad app federated-credential list --id "<APP_OBJECT_ID>" --output table
```

The final list should no longer contain the revoked name. Do not revoke a credential still used by an active workflow.

## Deploy 01-Identity to create main resource

Before assigning workload-level RBAC roles, you must deploy the `01-identity` module to create the lab Resource Group and foundational identities.

Now move to 01-identity folder (you are at root hybrid-infra-lab now):
```powershell
cd terraform/01-identity
```

Run these codes:
```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Make sure the Plan adds 3 new resources. Then
```powershell
terraform apply -auto-approve
```

## Assign Azure RBAC roles

Get the relevant scopes:

```powershell
$subscriptionScope = az account show --query id -o tsv
$labRgScope = az group show --name "<LAB_RESOURCE_GROUP>" --query id -o tsv
$storageScope = az storage account show --name "<STATE_STORAGE_ACCOUNT>" --resource-group "<STATE_RESOURCE_GROUP>" --query id -o tsv
```

Replace the placeholders with the values from document 02 and run the commands in PowerShell. Confirm that the subscription and resource-group names shown by these commands are the ones used by the workflows before creating role assignments.

Every Terraform identity needs Blob data access to read/write/lease state. Assign `Storage Blob Data Contributor` to each service principal on the state Storage Account or container. This includes plan jobs because the AzureRM backend uses blob leases:

```powershell
az role assignment create --assignee-object-id <SP_OBJECT_ID> --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope $storageScope
```

For all five identities, this PowerShell loop assigns the state role at the Storage Account scope. Fill the five placeholders with the corresponding **Service Principal Object IDs** from the app-creation output, then run the block once:

```powershell
$spObjectIds = @{
  "terraform-identity-plan"    = "<IDENTITY_PLAN_SP_OBJECT_ID>"
  "terraform-identity-apply"   = "<IDENTITY_APPLY_SP_OBJECT_ID>"
  "terraform-vmresource-plan"  = "<VMRESOURCE_PLAN_SP_OBJECT_ID>"
  "terraform-vmresource-apply" = "<VMRESOURCE_APPLY_SP_OBJECT_ID>"
  "terraform-destroy"          = "<DESTROY_SP_OBJECT_ID>"
}

foreach ($environment in $spObjectIds.Keys) {
  az role assignment create `
    --assignee-object-id $spObjectIds[$environment] `
    --assignee-principal-type ServicePrincipal `
    --role "Storage Blob Data Contributor" `
    --scope $storageScope `
    --output none
  if ($LASTEXITCODE -ne 0) { throw "Could not assign state access for $environment." }
}

foreach ($environment in $spObjectIds.Keys) {
  Write-Host "--- $environment state access ---"
  az role assignment list `
    --assignee-object-id $spObjectIds[$environment] `
    --scope $storageScope `
    --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{role:roleDefinitionName,scope:scope}" `
    --output table
}
```

Check that each query shows `Storage Blob Data Contributor` at the intended state account scope. Azure RBAC propagation may delay successful backend access even after the assignment exists.

Suggested management-plane permissions:

| GitHub environment | Azure resource scope and role | Purpose |
|---|---|---|
| `terraform-identity-plan` | `Reader` at subscription scope | Initial plan may inspect whether the lab resource group and identity exist. |
| `terraform-identity-apply` | `Contributor` plus `User Access Administrator` (or suitably conditioned `Role Based Access Control Administrator`) at subscription scope for first bootstrap | Creates the resource group, managed identity, and `Reader` role assignment for `id-cm`. Contributor alone cannot create role assignments; the target group does not exist yet. |
| `terraform-vmresource-plan` | `Reader` on the lab resource group | Reads the resource group and identity and creates plans. |
| `terraform-vmresource-apply` | `Contributor` on the lab resource group | Creates networking, NSGs, NICs, and VMs. |
| `terraform-destroy` | `Contributor` on the lab resource group | Deletes resources managed by module 02 only. |

Use a dedicated lab subscription for initial identity bootstrap. After successful setup, remove or reduce subscription-scoped bootstrap privileges if they are no longer needed. Production designs should use narrower custom roles/scopes and separate identity and workload resource groups. Do not grant subscription-wide Owner for convenience.

Example assignment (repeat with the appropriate app and scope):

```powershell
az role assignment create `
  --assignee-object-id <SP_OBJECT_ID> `
  --assignee-principal-type ServicePrincipal `
  --role "Reader" `
  --scope $labRgScope
```

For each assignment below, use the SP Object ID from the matching environment row above. These commands implement the preceding role table; first bootstrap uses subscription-scoped roles because `terraform/01-identity` creates the lab Resource Group and then assigns `Reader` to `id-cm`:

```powershell
$subscriptionScope = "/subscriptions/$(az account show --query id -o tsv)"

# Identity plan: subscription Reader, because the Resource Group may not exist yet.
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-plan"] --assignee-principal-type ServicePrincipal --role "Reader" --scope $subscriptionScope

# Identity apply: temporary bootstrap permissions. Contributor does not grant roleAssignments/write.
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-apply"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $subscriptionScope
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-apply"] --assignee-principal-type ServicePrincipal --role "User Access Administrator" --scope $subscriptionScope
```

The identity-apply `User Access Administrator` grant at subscription scope is powerful and is required by this initial bootstrap design. Use a dedicated lab subscription; once the identity foundation has been created, **remove or narrow that grant only after verifying no planned identity operation needs it**. 

The `terraform-destroy` app is for module 02 only; it does not remove the module 01 Resource Group or identity. For a fresh setup, apply the three bootstrap role assignments (identity-plan Reader plus identity-apply Contributor and User Access Administrator) before the first identity apply. 

Now that the lab Resource Group has been created, obtain its scope and grant the three workload roles:

```powershell
$labRgScope = az group show --name "<LAB_RESOURCE_GROUP>" --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $labRgScope) { throw "Lab Resource Group not found; do not continue." }

az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-plan"] --assignee-principal-type ServicePrincipal --role "Reader" --scope $labRgScope
az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-apply"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope
az role assignment create --assignee-object-id $spObjectIds["terraform-destroy"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope
```

If the Resource Group already exists, run all appropriate assignments and verify scopes before starting CI.

To verify management-plane assignments, query each SP at its target scope and confirm the expected role names. Example for the VM apply principal:

```powershell
az role assignment list `
  --assignee-object-id $spObjectIds["terraform-vmresource-apply"] `
  --scope $labRgScope `
  --query "[].{role:roleDefinitionName,scope:scope,principal:principalId}" `
  --output table
```

The `terraform/01-identity` module also creates `azurerm_role_assignment.cm_reader`: it assigns Azure `Reader` on the lab resource group to the **managed identity principal ID** of `id-cm`. This runtime permission lets the control-manager inventory process read Azure VM metadata; it is not a GitHub workflow permission. The identity apply principal must be allowed to create this role assignment.

Azure RBAC propagation can take several minutes. Blob data roles are distinct from management-plane `Reader`/`Contributor` roles.

## Checkpoint

- Five apps/service principals and five FICs exist with correct issuer, audience, and environment-specific subjects.
- Each GitHub environment uses the client ID of its corresponding app.
- Each app has Blob data access for the backend.
- Resource roles/scopes match the table; identity apply can create the bootstrap Resource Group and `cm_reader` assignment.

Continue with [04 — Tailscale WIF and policy](04-tailscale-wif-policy.md).