# 01 — Prerequisites and clone setup

Start here and follow documents 01–08 in order. The current repository implements two Terraform roots: `terraform/01-identity` and `terraform/02-vmresource`.

## Accounts and cost

Prepare:

- An active Azure subscription with billing, permissions, and VM quota for Central India, zone 1, and the default Ubuntu ARM64 size.
- A GitHub account/repository with Actions enabled and permission to configure Environments, secrets, variables, and branch protections.
- An administrator account in a Tailscale tailnet that supports OIDC/workload identity federation, Tailscale SSH, and policy GitOps.

Use a dedicated test subscription/repository/tailnet where possible. Azure VMs and other resources incur costs while provisioned. Review prices and quota before deployment; this is a learning lab, not a production design.

## Windows workstation

The author's tested workstation was Windows 10, Ryzen 7 4800H, 16 GB RAM, and 512 GB SSD. This is a reference setup, not a minimum requirement.

Install Git for Windows, VS Code, Azure CLI, Terraform CLI (Windows x64), and a browser. Recommended VS Code extensions: Azure Resources, HashiCorp Terraform, and GitHub Actions. GitHub CLI (`gh`) is useful but optional. WSL 2/Bash is useful for local shell scripts; Python is not required locally for Terraform workflows. The Ansible control-manager and GitHub runners install/use their own dependencies.

Verify in PowerShell:

```powershell
git --version
terraform version
az version
code --version
# Optional
gh --version
```

If GitHub CLI is not installed, run `winget install --id GitHub.cli --source winget` in PowerShell, then close and reopen the terminal before checking `gh --version`. Do not type the installation note after the command as if it were part of the command.

Log in and select the intended subscription:

```powershell
az login
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show --output table
```

## Check region, SKU, quota, and networks

The default VM maps define one control-manager and one workload VM, both `Standard_D2ps_v6`, zone `1`, using Ubuntu 24.04 ARM64. Verify SKU/zone support and vCPU quota for your subscription; availability and pricing can change.

```powershell
az vm list-skus --location centralindia --size Standard_D2ps_v6 --all --output table
az vm list-usage --location centralindia --output table
```

If needed, update `control_vms` and `workload_vms` in `terraform/02-vmresource/variables.tf` and ensure the selected SKU supports the configured ARM64 image. Default networking is VNet `10.20.0.0/16`, automation subnet `10.20.1.0/24`, and workload subnet `10.20.2.0/24`. Avoid overlap; if changed, update Terraform and Tailscale route/policy values together.

## Fork, clone, and customize

1. Fork the repository to your GitHub account or organization.
2. Clone your fork and open the repository root in VS Code. Check `git remote -v`, `git branch --show-current`, and `git status`.
3. Use `main` as the default branch and configure Git author name/email if needed.
4. Review and customize these repository-specific settings before running Terraform:
   - `terraform/01-identity/backend.tf` and `terraform/02-vmresource/backend.tf`: state resource group, globally unique storage account, container, and distinct state keys.
   - `terraform/01-identity/variables.tf`: lab resource-group name, managed-identity name, and location.
   - `terraform/02-vmresource/variables.tf` and `network.tf`: resource names, VM maps, and CIDRs as needed.
   - `bootstrap/cm-cloud-init.yaml`: change the hard-coded HTTPS clone URL to your fork. Private repositories require a deliberate authentication method; never embed a PAT/token in cloud-init.
   - `ansible/inventory/generate_inventory.sh`: match the Terraform resource-group name.
   - `tailscale/policy.hujson`: keep route CIDRs synchronized with Terraform.

Azure Storage account names must be globally unique, 3–24 characters, lowercase letters and digits only. Ensure state keys remain distinct between Terraform roots.

## Administrator SSH key

Azure Linux VM provisioning requires an authentication mechanism. This project uses SSH public-key authentication and disables password authentication. Create or select a dedicated SSH key pair for the lab. For example, in PowerShell:

```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\hybrid-infra-lab"
Get-Content "$env:USERPROFILE\.ssh\hybrid-infra-lab.pub"
```

Supply **only the public key** (the `.pub` file contents) to GitHub as `SSH_PUBLIC_KEY`; never commit the private key or place it in Terraform files. Keep the private key protected on an administrator workstation. The repository provisions the public key for Azure VM authentication, but the lab's normal CM access uses Tailscale SSH identity/policy and does not use that private key. No alternate private-key or Azure Serial Console recovery path is configured and verified here; do not assume the private key alone provides emergency access. For local Terraform runs, provide the public key through `TF_VAR_ssh_public_key` or an ignored local `terraform.tfvars` file; verify it is not staged before committing.

### Copy the public key into the GitHub value and local Terraform input

1. In PowerShell, print the public half and copy the **entire single line** beginning with `ssh-rsa` (or the key type created by your `ssh-keygen` version):

```powershell
Get-Content "$env:USERPROFILE\.ssh\hybrid-infra-lab.pub"
```

The private half is the file without `.pub`; never run `Get-Content` on it, paste it into GitHub, or place it in the repository. The public key is not a private credential, but the repo supplies it to Azure at VM creation.

2. For the GitHub workflows, add that public-key line as the `SSH_PUBLIC_KEY` **secret** in each of these exact repository Environments: `terraform-vmresource-plan`, `terraform-vmresource-apply`, and `terraform-destroy`. The UI clicks and remaining Environment values are listed in document 05. The plan and apply workflows pass it as `TF_VAR_ssh_public_key`; the destroy workflow also needs it because Terraform loads the same required input configuration.

3. Only run Terraform locally if you have already verified that your local Azure identity can authenticate to this repository's OIDC-configured AzureRM backend. Otherwise, use the GitHub plan workflow described in document 06. If local authentication is supported/configured, open a PowerShell terminal at the repository root and set the environment variable from the `.pub` file. Do this in the same terminal session in which Terraform is run:

```powershell
$env:TF_VAR_ssh_public_key = (Get-Content "$env:USERPROFILE\.ssh\hybrid-infra-lab.pub" -Raw).Trim()
```

Run commands separately in each module directory; these are independent Terraform roots with different remote state keys:

```powershell
Set-Location .\terraform\01-identity
terraform init
terraform fmt -check
terraform validate
terraform plan
```

The identity root does not consume this variable; it is needed by `terraform/02-vmresource`. Change to that directory to plan VM resources only after the backend and Azure/Tailscale inputs are configured:

```powershell
Set-Location ..\02-vmresource
$env:TF_VAR_tailscale_cm_client_id = "<TAILSCALE_CM_CLIENT_ID_FROM_DOCUMENT_04>"
$env:TF_VAR_tailscale_cm_audience = "<TAILSCALE_CM_AUDIENCE_FROM_DOCUMENT_04>"
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Replace the two placeholders with the non-secret Client ID and Audience for the **Azure control-manager** Tailscale credential. These variables are required by `terraform/02-vmresource`; do not use the GitHub CI or policy-GitOps values.

Local Terraform authentication with the repository's OIDC backend settings must be validated for your chosen local identity before running these commands; `az login` alone may not provide the GitHub OIDC token expected by CI. If local `terraform init` fails authentication, stop and use the documented GitHub workflow rather than adding a client secret or storage key to backend configuration.

4. Clear the public-key value from the current PowerShell process when finished and verify it is empty:

```powershell
Remove-Item Env:TF_VAR_ssh_public_key -ErrorAction SilentlyContinue
Remove-Item Env:TF_VAR_tailscale_cm_client_id -ErrorAction SilentlyContinue
Remove-Item Env:TF_VAR_tailscale_cm_audience -ErrorAction SilentlyContinue
Test-Path Env:TF_VAR_ssh_public_key
```

The last command should return `False`. If you instead create a local `terraform.tfvars`, create it only inside `terraform/02-vmresource`, ensure it contains only `ssh_public_key = "<PUBLIC_KEY_LINE>"`, confirm `git check-ignore .\terraform.tfvars` from that module directory, and delete it after use. Do not create one in the identity root and do not put the private key in either file. Deleting a file does not guarantee forensic erasure on SSD or OneDrive-synced storage.

The VM-resource module also creates a separate Terraform-generated key for Ansible connections from the control-manager to workload VMs. Its private material is stored in Terraform state/custom data; see document 08 for the security implications.

Continue with [02 — Bootstrap the Azure Blob backend](02-azure-state-backend.md).