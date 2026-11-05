# 02 — Bootstrap the Azure Blob state backend

The backend must exist before running `terraform init` in either module. Terraform should not create the storage account that stores its own state. Both backends use Azure AD/OIDC authentication; do not configure a Storage Account access key.

## Create the state resources

In PowerShell, after selecting the intended subscription:

```powershell
$location = "Central India"
$stateResourceGroup = "rg-terraform-state"
$storageAccount = "sthybridlab<unique-lowercase-suffix>"
$container = "tfstate"
```

Choose a globally unique suffix. Keep the same names in both backend files. Storage account names must be 3–24 lowercase alphanumeric characters.

```powershell
az group create --name $stateResourceGroup --location $location
az storage account create `
  --name $storageAccount `
  --resource-group $stateResourceGroup `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --https-only true `
  --allow-shared-key-access false

az storage container create `
  --name $container `
  --account-name $storageAccount `
  --auth-mode login
```

If the selected Azure CLI/API does not support disabling shared-key access, stop and verify the current backend authentication design; never put an account key into Terraform configuration. Enable Blob versioning and soft-delete/data-protection safeguards in the Storage Account. Storage firewall restrictions must still allow your administrators and GitHub runners to reach the backend.

Enable Blob versioning and deletion recovery immediately after creation. Run this PowerShell command with the same `$storageAccount` and `$stateResourceGroup` values set above:

```powershell
az storage account blob-service-properties update `
  --account-name $storageAccount `
  --resource-group $stateResourceGroup `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 14 `
  --enable-container-delete-retention true `
  --container-delete-retention-days 14
```

Verify the account-level security settings and Blob data-protection properties:

```powershell
az storage account show `
  --name $storageAccount `
  --resource-group $stateResourceGroup `
  --query "{name:name,httpsOnly:enableHttpsTrafficOnly,minTlsVersion:minimumTlsVersion,publicBlobAccess:allowBlobPublicAccess,sharedKeyAccess:allowSharedKeyAccess,defaultNetworkAction:networkRuleSet.defaultAction}" `
  --output table

az storage account blob-service-properties show `
  --account-name $storageAccount `
  --resource-group $stateResourceGroup `
  --query "{versioning:isVersioningEnabled,blobDeleteRetention:deleteRetentionPolicy,containerDeleteRetention:containerDeleteRetentionPolicy}" `
  --output json
```

Confirm `httpsOnly` is `True`, `minTlsVersion` is `TLS1_2`, public blob access and shared-key access are disabled, and versioning plus both retention policies are enabled. If an option is unsupported by the installed CLI/API, do not skip protection silently: inspect the current Azure Portal Storage Account → Data protection settings, configure the equivalent options, then rerun the verification command. Choose a firewall/private-endpoint design that permits both your administrator workstation and the GitHub runner; do not enable a network rule that makes state inaccessible to CI.

## Grant the bootstrap user Blob access

Azure management-plane `Reader` or `Contributor` does not grant Blob data access. The user who initializes/applies Terraform locally needs `Storage Blob Data Contributor` on the state account (or a narrower container scope), including permission to lease the state blob:

```powershell
$storageScope = az storage account show `
  --name $storageAccount `
  --resource-group $stateResourceGroup `
  --query id -o tsv
$userObjectId = az ad signed-in-user show --query id -o tsv
az role assignment create `
  --assignee-object-id $userObjectId `
  --assignee-principal-type User `
  --role "Storage Blob Data Contributor" `
  --scope $storageScope
```

RBAC propagation may take several minutes. Verify access with `az storage container list --account-name $storageAccount --auth-mode login --output table`.

## Configure both Terraform backends

Edit `terraform/01-identity/backend.tf` and `terraform/02-vmresource/backend.tf`. Set the correct resource group, storage account, and container. Preserve different keys, for example `hybrid-identity.tfstate` and `hybrid-vmresource.tfstate`:

```hcl
terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    resource_group_name  = "rg-terraform-state"
    storage_account_name = "<YOUR_UNIQUE_STORAGE_ACCOUNT>"
    container_name       = "tfstate"
    key                  = "<UNIQUE_MODULE_STATE_KEY>.tfstate"
  }
}
```

Do not copy a backend name/key from another repository. Terraform creates the state blob on first apply.

These backend files use `use_oidc = true` and `use_azuread_auth = true`, matching the GitHub Actions workflows. A local `az login` does not automatically provide the GitHub-issued OIDC token. The local Terraform CLI flow is therefore not assumed to work just because Azure CLI login succeeds. Test it only with an explicitly configured, supported local authentication method; never solve a local auth error by inserting an account key, client secret, or password into a backend file. CI authentication is verified by the workflow checks in document 06.

## Checkpoint

- The state resource group, Storage Account, and `tfstate` container exist.
- Anonymous blob access is disabled; HTTPS/TLS 1.2 is required; shared-key access is disabled where supported.
- Data protection/versioning is enabled or deliberately configured.
- Both backends point to the new account and use distinct state keys.
- No account keys/passwords are present in `.tf` files.

Continue with [03 — Entra OIDC, federated credentials, and RBAC](03-azure-oidc-rbac.md).