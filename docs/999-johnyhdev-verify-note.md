#Johnyhdev Verification Checks
**Attention**: These steps on this file only demonstrate to you after the  project complete, some code need to be finished the step No before it can work. 
Example: az account list --output table (Only works after az login succeed).
This file is not recommended in live production repo because can make your repo leak to security issue.

##01-prerequisites-and-clone.md

At this step, I just run verification code to make sure the repo works at attended. It doesn't guarantee you will get the same results like me. The version checks may be the same, but the terraform init or etc... may be failed. Don't worry, just keep reading and action.

git --version
```
git version 2.54.0.windows.1
```

terraform version
```
Terraform v1.16.6

Your version of Terraform is out of date! The latest version
is 1.17.0. You can update by downloading from https://developer.hashicorp.com/terraform/install
```

az version
```
hybrid-infrastru
{
  "azure-cli": "2.91.0",
  "azure-cli-core": "2.91.0",
  "extensions": {}
}
```

code --version
```
1.135.0
08d4889f9ec4a1685d257b9b95de036c8e1ce1e5
x64
```

```
gh version 2.102.0 (2026-09-30)
https://github.com/cli/cli/releases/tag/v2.102.0
```

az account list --output table
```
A few accounts are skipped as they don't have 'Enabled' state. Use '--all' to display them.
Name    CloudName    SubscriptionId                        TenantId                         e    IsDefault
------  -----------  ------------------------------------  ------------------------------------  -----------
subJHD  AzureCloud   adee883c-f49b-4d4a-a5e1-8eedf0d4454c  25249825-52b8-4478-bd14-bc39033c8led  True
```

az account set --subscription "adee883c-f49b-4d4a-a5e1-8eedf0d4454c"

az account show --output table
```
hybrid-infrastructure-lab> az account show --output table
EnvironmentName    HomeTenantId                          IsDefault    Name    State    TenantDefaultDomain    TenantDisplayName TenantId
-----------------  ------------------------------------  -----------  ------  -------  ---------------------  ------------------- ------------------------------------
AzureCloud         25249825-52b8-4478-bd14-bc39033c86d0  True         subJHD  Enabled  abtev.onmicrosoft.com  ABTEV 25249825-52b8-4478-bd14-bc39033c86d0
```

az vm list-skus --location centralindia --size Standard_D2ps_v6 --all --output table

```
ResourceType     Locations     Name              Zones    Restrictions
---------------  ------------  ----------------  -------  --------------------------------------------------------------------------
virtualMachines  CentralIndia  Standard_D2ps_v6  1,2      NotAvailableForSubscription, type: Zone, locations: CentralIndia, zones: 3

#Note: Available Zone 1, 2 only.
```

az vm list-usage --location centralindia --output table
```
Name                                      CurrentValue    Limit
----------------------------------------  --------------  -------
Total Regional Low-priority vCPUs         0               3
Total Regional vCPUs                      0               10
Virtual Machines                          0               25000
Availability Sets                         0               2500
Virtual Machine Scale Sets                0               2500
Dedicated vCPUs                           0               3000
Cloud Services                            0               2500
Basic A Family vCPUs                      0               10
Standard A0-A7 Family vCPUs               0               10
Standard A8-A11 Family vCPUs              0               10
Standard Av2 Family vCPUs                 0               10
Standard BS Family vCPUs                  0               10
Standard Basv2 Family vCPUs               0               0
Standard Bsv2 Family vCPUs                0               0
Standard Bpsv2 Family vCPUs               0               0
Standard D Family vCPUs                   0               10
Standard Dv2 Family vCPUs                 0               10
Standard Dv2 Promo Family vCPUs           0               10
Standard Dadsv7 Family vCPUs              0               10
Standard Daldsv7 Family vCPUs             0               10
Standard Dalsv7 Family vCPUs              0               10
Standard Dasv7 Family vCPUs               0               10
Standard Ddsv6 Family vCPUs               0               10
Standard Ddsv7 Family vCPUs               0               10
Standard Dldsv6 Family vCPUs              0               10
Standard Dldsv7 Family vCPUs              0               10
Standard Dlsv6 Family vCPUs               0               10
Standard Dlsv7 Family vCPUs               0               10
Standard Dndv6 Family vCPUs               0               10
Standard Dnldv6 Family vCPUs              0               10
Standard Dnlv6 Family vCPUs               0               10
Standard Dnv6 Family vCPUs                0               10
Standard Dsv6 Family vCPUs                0               10
Standard Dsv7 Family vCPUs                0               10
Standard DADSv5 Family vCPUs              0               0
standard Dadv6 Family vCPUs               0               10
standard Daldv6 Family vCPUs              0               10
standard Dalv6 Family vCPUs               0               10
Standard DASv4 Family vCPUs               0               10
Standard DASv5 Family vCPUs               0               0
standard Dav6 Family vCPUs                0               10
Standard DAv4 Family vCPUs                0               0
Standard DDSv4 Family vCPUs               0               10
Standard DDSv5 Family vCPUs               0               0
Standard DDv4 Family vCPUs                0               10
Standard DDv5 Family vCPUs                0               0
Standard DLDSv5 Family vCPUs              0               0
Standard DLSv5 Family vCPUs               0               0
Standard DPDSv5 Family vCPUs              0               0
Standard Dpdsv6 Family vCPUs              0               10
Standard DPLDSv5 Family vCPUs             0               0
Standard Dpldsv6 Family vCPUs             0               10
Standard DPLSv5 Family vCPUs              0               0
Standard Dplsv6 Family vCPUs              0               10
Standard DPSv5 Family vCPUs               0               0
Standard Dpsv6 Family vCPUs               0               10
Standard DSv3 Family vCPUs                0               10
Standard DSv4 Family vCPUs                0               10
Standard DSv5 Family vCPUs                0               0
Standard Dv3 Family vCPUs                 0               10
Standard Dv4 Family vCPUs                 0               10
Standard Dv5 Family vCPUs                 0               0
standard DCADCCV5 Family vCPUs            0               0
Standard DCADSv5 Family vCPUs             0               0
Standard DCadsv6 Family vCPUs             0               0
standard DCACCV5 Family vCPUs             0               0
Standard DCASv5 Family vCPUs              0               0
Standard DCasv6 Family vCPUs              0               0
Standard DDCSv3 Family vCPUs              0               0
Standard DCEDV5 Family vCPUs              0               0
Standard DCEV5 Family vCPUs               0               0
Standard DCSv3 Family vCPUs               0               0
Standard DCSv2 Family vCPUs               0               8
Standard DCS Family vCPUs                 0               8
Standard DS Family vCPUs                  0               10
Standard DSv2 Family vCPUs                0               10
Standard DSv2 Promo Family vCPUs          0               10
Standard EIDSv5 Family vCPUs              0               0
Standard EIDv5 Family vCPUs               0               0
Standard EISv5 Family vCPUs               0               0
Standard EIv5 Family vCPUs                0               0
Standard EIADSv5 Family vCPUs             0               0
Standard EIASv5 Family vCPUs              0               0
Standard EIBDSv5 Family vCPUs             0               0
Standard EIBSv5 Family vCPUs              0               0
Standard Eadsv7 Family vCPUs              0               10
Standard Easv7 Family vCPUs               0               10
Standard Edsv6 Family vCPUs               0               10
Standard Esv6 Family vCPUs                0               10
Standard Edsv7 Family vCPUs               0               10
Standard Endv6 Family vCPUs               0               10
Standard Env6 Family vCPUs                0               10
Standard Esv7 Family vCPUs                0               10
Standard EADSv5 Family vCPUs              0               0
Standard EASv4 Family vCPUs               0               10
Standard EASv5 Family vCPUs               0               0
Standard EDSv4 Family vCPUs               0               10
Standard EDSv5 Family vCPUs               0               0
Standard ESv3 Family vCPUs                0               10
Standard ESv4 Family vCPUs                0               0
Standard ESv5 Family vCPUs                0               0
standard Eadv6 Family vCPUs               0               10
standard Eav6 Family vCPUs                0               10
Standard EAv4 Family vCPUs                0               0
Standard EBDSv5 Family vCPUs              0               10
Standard EBSv5 Family vCPUs               0               10
Standard EDv4 Family vCPUs                0               0
Standard EDv5 Family vCPUs                0               0
Standard EPDSv5 Family vCPUs              0               0
Standard Epdsv6 Family vCPUs              0               10
Standard EPSv5 Family vCPUs               0               0
Standard Epsv6 Family vCPUs               0               10
Standard Ev3 Family vCPUs                 0               10
Standard Ev4 Family vCPUs                 0               10
Standard Ev5 Family vCPUs                 0               0
Standard EISv3 Family vCPUs               0               10
Standard EIv3 Family vCPUs                0               10
Standard EIDSv4 Family vCPUs              0               0
Standard XEISv4 Family vCPUs              0               0
Standard EIASv4 Family vCPUs              0               0
Standard ECEDV5 Family vCPUs              0               0
Standard ECEV5 Family vCPUs               0               0
standard ECADCCV5 Family vCPUs            0               0
Standard ECADSv5 Family vCPUs             0               0
Standard ECadsv6 Family vCPUs             0               0
standard ECACCV5 Family vCPUs             0               0
Standard ECASv5 Family vCPUs              0               0
Standard ECasv6 Family vCPUs              0               0
Standard ECIADSv5 Family vCPUs            0               0
Standard ECIASv5 Family vCPUs             0               0
Standard F Family vCPUs                   0               10
Standard Famdsv7 Family vCPUs             0               10
Standard Famsv7 Family vCPUs              0               10
Standard Fadsv7 Family vCPUs              0               10
Standard Faldsv7 Family vCPUs             0               10
Standard Falsv6 Family vCPUs              0               10
Standard Falsv7 Family vCPUs              0               10
Standard Famsv6 Family vCPUs              0               10
Standard Fasv6 Family vCPUs               0               10
Standard Fasv7 Family vCPUs               0               10
Standard FS Family vCPUs                  0               10
Standard FSv2 Family vCPUs                0               10
Standard FXmdsv2 Family vCPUs             0               10
Standard FXmsv2 Family vCPUs              0               10
Standard FXMDVS Family vCPUs              0               0
Standard G Family vCPUs                   0               10
Standard GS Family vCPUs                  0               10
Standard H Family vCPUs                   0               8
Standard H Promo Family vCPUs             0               8
Standard HBrsv2 Family vCPUs              0               0
Standard HBv3 Family vCPUs                0               0
Standard HBv4 Family vCPUs                0               0
Standard Hbv5 Family vCPUs                0               0
Standard HBS Family vCPUs                 0               0
Standard HCS Family vCPUs                 0               0
Standard HX Family vCPUs                  0               0
InternalNDM Sv 1 Family vCPUs             0               10
Standard Laosv4 Family vCPUs              0               10
Standard LASv3 Family vCPUs               0               0
Standard Lasv 4 Family vCPUs              0               10
Standard LS Family vCPUs                  0               10
Standard LSv2 Family vCPUs                0               10
Standard LSv3 Family vCPUs                0               0
Standard Lsv 4 Family vCPUs               0               10
Standard MS Family vCPUs                  0               0
Standard MBDSMediumMemoryv3 Family vCPUs  0               10
Standard MBSMediumMemoryv3 Family vCPUs   0               10
Standard MDSMediumMemoryv2 Family vCPUs   0               0
Standard MSMediumMemoryv2 Family vCPUs    0               0
StandardMDS Medium Memoryv3 Family vCPUs  0               0
StandardMS Medium Memoryv3 Family vCPUs   0               0
Standard MIDSMediumMemoryv2 Family vCPUs  0               0
Standard MISMediumMemoryv2 Family vCPUs   0               0
Standard MSv2 Family vCPUs                0               0
StandardMDS High Memoryv3 Family vCPUs    0               0
StandardMS High Memoryv3 Family vCPUs     0               0
StandardMIDS High Memoryv3 Family vCPUs   0               0
StandardMIS High Memoryv3 Family vCPUs    0               0
Standard NC Family vCPUs                  0               12
Standard NCSv2 Family vCPUs               0               0
Standard NCSv3 Family vCPUs               0               0
Standard NC Promo Family vCPUs            0               12
Standard NCADSA10v4 Family vCPUs          0               0
Standard NCASv3_T4 Family vCPUs           0               0
Standard NCADS_A100_v4 Family vCPUs       0               0
Standard NCadsH100v5 Family vCPUs         0               0
Standard NCCads2023 Family vCPUs          0               0
Standardndisrgb300g5v6family vCPUs        0               0
Standard NDISR GB300V6 Family vCPUs       0               0
StandardNDISRGB200V6NDRFamily vCPUs       0               0
Standard NDS Family vCPUs                 0               0
Standard NDSv2 Family vCPUs               0               0
Standard NDSv3 Family vCPUs               0               0
Standard NDAMSv4_A100Family vCPUs         0               0
Standard NDASv4_A100 Family vCPUs         0               0
Standard NDSH100v5 Family vCPUs           0               0
StandardNDISRH200V5Family vCPUs           0               0
StandardNDI Sv 5MI300X Family vCPUs       0               0
Standard NGADSV620v1 Family vCPUs         0               0
Standard NPS Family vCPUs                 0               0
Standard NVADSA10v5 Family vCPUs          0               0
Standard NV Family vCPUs                  0               12
Standard NVadsV710v5 Family vCPUs         0               0
Standard NVSv2 Family vCPUs               0               0
Standard NVSv3 Family vCPUs               0               0
Standard NV Promo Family vCPUs            0               12
Standard NVSv4 Family vCPUs               0               8
Standard PBS Family vCPUs                 0               6
Standard Storage Managed Disks            0               50000
Premium Storage Managed Disks             0               50000
StandardSSDStorageDisks                   0               50000
StandardSSDZRSStorageDisks                0               50000
PremiumZRSStorageDisks                    0               50000
UltraSSDStorageDisks                      0               1000
PremiumV2StorageDisks                     0               5000
StandardStorageSnapshots                  0               75000
StandardSSDStorageSnapshots               0               75000
PremiumStorageSnapshots                   0               75000
ZrsStorageSnapshots                       0               75000
UltraSSDTotalSizeInGB                     0               102400
PremiumV2TotalDiskSizeInGB                0               1048576
DiskEncryptionSets                        0               5000
DiskAccesses                              0               1000
BackgroundCopyInProgressUltraSSDDisks     0               50
BackgroundCopyInProgressPremiumV2Disks    0               50
PremiumV2StorageSnapshots                 0               1000
PremiumV2TotalSnapshotSizeInGB            0               102400
Gallery                                   0               100
Gallery Image                             0               1000
Gallery Image Version                     0               10000
Gallery Application Version               0               300
Gallery Script Version                    0               300
```

git remote -v
```
origin  https://github.com/johnyhdev/hybrid-infrastructure-lab.git (fetch)
origin  https://github.com/johnyhdev/hybrid-infrastructure-lab.git (push)
```

git branch --show-current
```
u-p67-v8
```

git status
```
On branch u-p67-v8
Your branch is up to date with 'origin/u-p67-v8'.

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        docs/999-johnyhdev-note.md

nothing added to commit but untracked files present (use "git add" to track)
```

ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\hybrid-infra-lab"
```
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in C:\Users\johnyhdev\.ssh\hybrid-infra-lab.
Your public key has been saved in C:\Users\johnyhdev\.ssh\hybrid-infra-lab.pub.
The key fingerprint is:
SHA256:JyV1BnTsdJxZjbw3APolcMEQO737XUfAKktejN4Otp0 johnyhdev@d-JHD
The key's randomart image is:
+---[RSA 4096]----+
|         =B**o =o|
|         .*=ooB .|
|        .+.= o+. |
|         ooo=..o.|
|        S =o+  .o|
|         * =.  . |
|          *..   o|
|         . =... o|
|          . E. . |
+----[SHA256]-----+
```

Get-Content "$env:USERPROFILE\.ssh\hybrid-infra-lab.pub"
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQaERLiMHcapHKmgeGiHspCGhUNuRA/U7DJ2mbrplA0LYLgDxEvKDJ70OZH7WcPtjMWtkpIor6GI0RIzQBqxR2Ei2VxabCHsxSRxiMSOSp4L7i5jQ7HQhEGhrD8lQTPm4cl6XQAiYqF1M6acXNKKf1NLPOP230kodZAl9cGu2eEJKlgX6jeb2N1jI7R5sYKe4j8GtyIS51KZZAhJS8s3xZgzk/JyAc9jW0t1m6jR8duEYsKuODwaiOvFY/YUTePo1bF2Erh3xkldbL6N+mJcwLqDiqY9WqSKWFh022BzVmeC+SPz76r1lYOVLGpPgsz+L97fBQUcoQHPXlFZo5I8qxXYDzXR3LdoDSAc/TCkCaKnXp8/dOK4u7rmL6Qrx9KMSvlHuKPGHqQo8mIRimoWCQGZVucpALiRtgC4Sxt4KII6RUrsmLjl0J5GVql91WLy/mhcq1Rcmmx80LMBSUA1JTON5b6azCAcxYy944KW/cTrPt/ofv6D2d88T7AuupmX4D9Ovtn38MqGtZHgqcjIGF0dni+TFE+mGON3IdFMuB7sxuKhKgFqsBGKZaDBmfnBzLXcHUzN+jGaAV2EfqL579YJLRQPyfpKpnF8i1pfkMt1EKcPqefck4V0l1kRO2nXb9B8IwHO5uD6OU6Sm83rwWKGQjWuO68YtF3QV5zxmxDQ== johnyhdev@d-JHD
```

$env:TF_VAR_ssh_public_key = (Get-Content "$env:USERPROFILE\.ssh\hybrid-infra-lab.pub" -Raw).Trim()
```
Return nothing
```

Set-Location .\terraform\01-identity
terraform init
```
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/azurerm from the dependency lock file


You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

terraform fmt -check
```
#Will fix all format error
```

terraform validate
```
Success! The configuration is valid.
```

terraform plan
```
Acquiring state lock. This may take a few moments...
azurerm_resource_group.main: Refreshing state... [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab]
azurerm_user_assigned_identity.cm: Refreshing state... [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-cm]
azurerm_role_assignment.cm_reader: Refreshing state... [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.Authorization/roleAssignments/a45a89d9-883a-9486-053f-42acc6d91791]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
Releasing state lock. This may take a few moments...
```

Set-Location ..\02-vmresource
$env:TF_VAR_tailscale_cm_client_id = "<TAILSCALE_CM_CLIENT_ID_FROM_DOCUMENT_04>"
$env:TF_VAR_tailscale_cm_audience = "<TAILSCALE_CM_AUDIENCE_FROM_DOCUMENT_04>"
terraform init
terraform fmt -check
terraform validate
terraform plan

```
Initializing the backend...

Initializing provider plugins...
- terraform.io/builtin/terraform is built in to Terraform
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Reusing previous version of hashicorp/tls from the dependency lock file
- Using previously-installed hashicorp/azurerm v4.81.0

Terraform has been successfully initialized!
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

terraform.tfvars

Success! The configuration is valid.

Acquiring state lock. This may take a few moments...
data.azurerm_resource_group.main: Reading...
data.azurerm_resource_group.main: Read complete after 1s [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab]
data.azurerm_user_assigned_identity.cm: Reading...
data.azurerm_user_assigned_identity.cm: Read complete after 1s [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-cm]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following
symbols:
  + create

Terraform will perform the following actions:

  # azurerm_linux_virtual_machine.cm["vm-cm-01"] will be created
  + resource "azurerm_linux_virtual_machine" "cm" {
      + admin_username                                         = "azureadmin"
      + allow_extension_operations                             = (known after apply)
      + bypass_platform_safety_checks_on_user_schedule_enabled = false
      + computer_name                                          = (known after apply)
      + custom_data                                            = (sensitive value)
      + disable_password_authentication                        = true
      + disk_controller_type                                   = (known after apply)
      + extensions_time_budget                                 = "PT1H30M"
      + id                                                     = (known after apply)
      + location                                               = "centralindia"
      + max_bid_price                                          = -1
      + name                                                   = "vm-cm-01"
      + network_interface_ids                                  = (known after apply)
      + os_managed_disk_id                                     = (known after apply)
      + patch_assessment_mode                                  = (known after apply)
      + patch_mode                                             = (known after apply)
      + platform_fault_domain                                  = -1
      + priority                                               = "Regular"
      + private_ip_address                                     = (known after apply)
      + private_ip_addresses                                   = (known after apply)
      + provision_vm_agent                                     = (known after apply)
      + public_ip_address                                      = (known after apply)
      + public_ip_addresses                                    = (known after apply)
      + resource_group_name                                    = "rg-hybrid-infra-lab"
      + size                                                   = "Standard_D2ps_v6"
      + tags                                                   = {
          + "environment" = "lab"
          + "managed_by"  = "terraform"
          + "role"        = "control-manager"
        }
      + virtual_machine_id                                     = (known after apply)
      + vm_agent_platform_updates_enabled                      = (known after apply)
      + zone                                                   = "1"

      + admin_ssh_key {
          # At least one attribute in this block is (or was) sensitive,
          # so its contents will not be displayed.
        }

      + identity {
          + identity_ids = [
              + "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-cm",
            ]
          + principal_id = (known after apply)
          + tenant_id    = (known after apply)
          + type         = "UserAssigned"
        }

      + os_disk {
          + caching                   = "ReadWrite"
          + disk_size_gb              = (known after apply)
          + id                        = (known after apply)
          + name                      = (known after apply)
          + storage_account_type      = "Standard_LRS"
          + write_accelerator_enabled = false
        }

      + source_image_reference {
          + offer     = "ubuntu-24_04-lts"
          + publisher = "Canonical"
          + sku       = "server-arm64"
          + version   = "latest"
        }

      + termination_notification (known after apply)
    }

  # azurerm_linux_virtual_machine.workload["vm-workload-01"] will be created
  + resource "azurerm_linux_virtual_machine" "workload" {
      + admin_username                                         = "azureadmin"
      + allow_extension_operations                             = (known after apply)
      + bypass_platform_safety_checks_on_user_schedule_enabled = false
      + computer_name                                          = (known after apply)
      + custom_data                                            = (sensitive value)
      + disable_password_authentication                        = true
      + disk_controller_type                                   = (known after apply)
      + extensions_time_budget                                 = "PT1H30M"
      + id                                                     = (known after apply)
      + location                                               = "centralindia"
      + max_bid_price                                          = -1
      + name                                                   = "vm-workload-01"
      + network_interface_ids                                  = (known after apply)
      + os_managed_disk_id                                     = (known after apply)
      + patch_assessment_mode                                  = (known after apply)
      + patch_mode                                             = (known after apply)
      + platform_fault_domain                                  = -1
      + priority                                               = "Regular"
      + private_ip_address                                     = (known after apply)
      + private_ip_addresses                                   = (known after apply)
      + provision_vm_agent                                     = (known after apply)
      + public_ip_address                                      = (known after apply)
      + public_ip_addresses                                    = (known after apply)
      + resource_group_name                                    = "rg-hybrid-infra-lab"
      + size                                                   = "Standard_D2ps_v6"
      + tags                                                   = {
          + "environment" = "lab"
          + "managed_by"  = "terraform"
          + "role"        = "workload"
        }
      + virtual_machine_id                                     = (known after apply)
      + vm_agent_platform_updates_enabled                      = (known after apply)
      + zone                                                   = "1"

      + admin_ssh_key {
          # At least one attribute in this block is (or was) sensitive,
          # so its contents will not be displayed.
        }

      + os_disk {
          + caching                   = "ReadWrite"
          + disk_size_gb              = (known after apply)
          + id                        = (known after apply)
          + name                      = (known after apply)
          + storage_account_type      = "Standard_LRS"
          + write_accelerator_enabled = false
        }

      + source_image_reference {
          + offer     = "ubuntu-24_04-lts"
          + publisher = "Canonical"
          + sku       = "server-arm64"
          + version   = "latest"
        }

      + termination_notification (known after apply)
    }

  # azurerm_network_interface.cm["vm-cm-01"] will be created
  + resource "azurerm_network_interface" "cm" {
      + accelerated_networking_enabled = false
      + applied_dns_servers            = (known after apply)
      + id                             = (known after apply)
      + internal_domain_name_suffix    = (known after apply)
      + ip_forwarding_enabled          = false
      + location                       = "centralindia"
      + mac_address                    = (known after apply)
      + name                           = "nic-vm-cm-01"
      + private_ip_address             = (known after apply)
      + private_ip_addresses           = (known after apply)
      + resource_group_name            = "rg-hybrid-infra-lab"
      + virtual_machine_id             = (known after apply)

      + ip_configuration {
          + gateway_load_balancer_frontend_ip_configuration_id = (known after apply)
          + name                                               = "internal"
          + primary                                            = (known after apply)
          + private_ip_address                                 = (known after apply)
          + private_ip_address_allocation                      = "Dynamic"
          + private_ip_address_version                         = "IPv4"
          + subnet_id                                          = (known after apply)
        }
    }

  # azurerm_network_interface.workload["vm-workload-01"] will be created
  + resource "azurerm_network_interface" "workload" {
      + accelerated_networking_enabled = false
      + applied_dns_servers            = (known after apply)
      + id                             = (known after apply)
      + internal_domain_name_suffix    = (known after apply)
      + ip_forwarding_enabled          = false
      + location                       = "centralindia"
      + mac_address                    = (known after apply)
      + name                           = "nic-vm-workload-01"
      + private_ip_address             = (known after apply)
      + private_ip_addresses           = (known after apply)
      + resource_group_name            = "rg-hybrid-infra-lab"
      + virtual_machine_id             = (known after apply)

      + ip_configuration {
          + gateway_load_balancer_frontend_ip_configuration_id = (known after apply)
          + name                                               = "internal"
          + primary                                            = (known after apply)
          + private_ip_address                                 = (known after apply)
          + private_ip_address_allocation                      = "Dynamic"
          + private_ip_address_version                         = "IPv4"
          + subnet_id                                          = (known after apply)
        }
    }

  # azurerm_network_security_group.cm will be created
  + resource "azurerm_network_security_group" "cm" {
      + id                  = (known after apply)
      + location            = "centralindia"
      + name                = "nsg-vm-cm"
      + resource_group_name = "rg-hybrid-infra-lab"
      + security_rule       = (known after apply)
      + tags                = {
          + "managed_by" = "terraform"
          + "role"       = "control-manager"
        }
    }

  # azurerm_network_security_group.workload will be created
  + resource "azurerm_network_security_group" "workload" {
      + id                  = (known after apply)
      + location            = "centralindia"
      + name                = "nsg-vm-workload"
      + resource_group_name = "rg-hybrid-infra-lab"
      + security_rule       = (known after apply)
      + tags                = {
          + "managed_by" = "terraform"
          + "role"       = "workload"
        }
    }

  # azurerm_network_security_rule.workload_http_from_automation will be created
  + resource "azurerm_network_security_rule" "workload_http_from_automation" {
      + access                      = "Allow"
      + destination_address_prefix  = "*"
      + destination_port_range      = "80"
      + direction                   = "Inbound"
      + id                          = (known after apply)
      + name                        = "allow-http-from-automation"
      + network_security_group_name = "nsg-vm-workload"
      + priority                    = 110
      + protocol                    = "Tcp"
      + resource_group_name         = "rg-hybrid-infra-lab"
      + source_address_prefix       = "10.20.1.0/24"
      + source_port_range           = "*"
    }

  # azurerm_network_security_rule.workload_node_exporter_from_automation will be created
  + resource "azurerm_network_security_rule" "workload_node_exporter_from_automation" {
      + access                      = "Allow"
      + destination_address_prefix  = "*"
      + destination_port_range      = "9100"
      + direction                   = "Inbound"
      + id                          = (known after apply)
      + name                        = "allow-node-exporter-from-automation"
      + network_security_group_name = "nsg-vm-workload"
      + priority                    = 120
      + protocol                    = "Tcp"
      + resource_group_name         = "rg-hybrid-infra-lab"
      + source_address_prefix       = "10.20.1.0/24"
      + source_port_range           = "*"
    }

  # azurerm_network_security_rule.workload_ssh_from_automation will be created
  + resource "azurerm_network_security_rule" "workload_ssh_from_automation" {
      + access                      = "Allow"
      + destination_address_prefix  = "*"
      + destination_port_range      = "22"
      + direction                   = "Inbound"
      + id                          = (known after apply)
      + name                        = "allow-ssh-from-automation"
      + network_security_group_name = "nsg-vm-workload"
      + priority                    = 100
      + protocol                    = "Tcp"
      + resource_group_name         = "rg-hybrid-infra-lab"
      + source_address_prefix       = "10.20.1.0/24"
      + source_port_range           = "*"
    }

  # azurerm_subnet.automation will be created
  + resource "azurerm_subnet" "automation" {
      + address_prefixes                              = [
          + "10.20.1.0/24",
        ]
      + default_outbound_access_enabled               = true
      + id                                            = (known after apply)
      + name                                          = "snet-automation"
      + private_endpoint_network_policies             = "Disabled"
      + private_link_service_network_policies_enabled = true
      + resource_group_name                           = "rg-hybrid-infra-lab"
      + virtual_network_name                          = "vnet-hybrid-infra"
    }

  # azurerm_subnet.workload will be created
  + resource "azurerm_subnet" "workload" {
      + address_prefixes                              = [
          + "10.20.2.0/24",
        ]
      + default_outbound_access_enabled               = true
      + id                                            = (known after apply)
      + name                                          = "snet-workload"
      + private_endpoint_network_policies             = "Disabled"
      + private_link_service_network_policies_enabled = true
      + resource_group_name                           = "rg-hybrid-infra-lab"
      + virtual_network_name                          = "vnet-hybrid-infra"
    }

  # azurerm_subnet_network_security_group_association.cm will be created
  + resource "azurerm_subnet_network_security_group_association" "cm" {
      + id                        = (known after apply)
      + network_security_group_id = (known after apply)
      + subnet_id                 = (known after apply)
    }

  # azurerm_subnet_network_security_group_association.workload will be created
  + resource "azurerm_subnet_network_security_group_association" "workload" {
      + id                        = (known after apply)
      + network_security_group_id = (known after apply)
      + subnet_id                 = (known after apply)
    }

  # azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space                  = [
          + "10.20.0.0/16",
        ]
      + dns_servers                    = (known after apply)
      + guid                           = (known after apply)
      + id                             = (known after apply)
      + location                       = "centralindia"
      + name                           = "vnet-hybrid-infra"
      + private_endpoint_vnet_policies = "Disabled"
      + resource_group_name            = "rg-hybrid-infra-lab"
      + subnet                         = (known after apply)
      + tags                           = {
          + "managed_by" = "terraform"
        }
    }

  # terraform_data.cm_cloud_init["vm-cm-01"] will be created
  + resource "terraform_data" "cm_cloud_init" {
      + id     = (known after apply)
      + input  = (sensitive value)
      + output = (known after apply)
    }

  # terraform_data.workload_cloud_init["vm-workload-01"] will be created
  + resource "terraform_data" "workload_cloud_init" {
      + id     = (known after apply)
      + input  = (known after apply)
      + output = (known after apply)
    }

  # tls_private_key.internal_lab_key will be created
  + resource "tls_private_key" "internal_lab_key" {
      + algorithm                     = "RSA"
      + ecdsa_curve                   = "P224"
      + id                            = (known after apply)
      + private_key_openssh           = (sensitive value)
      + private_key_pem               = (sensitive value)
      + private_key_pem_pkcs8         = (sensitive value)
      + public_key_fingerprint_md5    = (known after apply)
      + public_key_fingerprint_sha256 = (known after apply)
      + public_key_openssh            = (known after apply)
      + public_key_pem                = (known after apply)
      + rsa_bits                      = 4096
    }

Plan: 17 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + admin_username          = "azureadmin"
  + automation_subnet_id    = (known after apply)
  + control_vm_ids          = {
      + vm-cm-01 = (known after apply)
    }
  + control_vm_names        = [
      + "vm-cm-01",
    ]
  + control_vm_private_ips  = {
      + vm-cm-01 = (known after apply)
    }
  + resource_group_name     = "rg-hybrid-infra-lab"
  + vnet_name               = "vnet-hybrid-infra"
  + workload_subnet_id      = (known after apply)
  + workload_vm_ids         = {
      + vm-workload-01 = (known after apply)
    }
  + workload_vm_names       = [
      + "vm-workload-01",
    ]
  + workload_vm_private_ips = {
      + vm-workload-01 = (known after apply)
    }

─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run
"terraform apply" now.
Releasing state lock. This may take a few moments...
```

Remove-Item Env:TF_VAR_ssh_public_key -ErrorAction SilentlyContinue
Remove-Item Env:TF_VAR_tailscale_cm_client_id -ErrorAction SilentlyContinue
Remove-Item Env:TF_VAR_tailscale_cm_audience -ErrorAction SilentlyContinue
```
Return nothing
```

Test-Path Env:TF_VAR_ssh_public_key
```
False
```

## 02 — Bootstrap the Azure Blob state backend

### Create the state resources
$location = "Central India"
$stateResourceGroup = "rg-terraform-state"
$storageAccount = "sthybridlab202610230913"
$container = "tfstate"

**202610230913** is <unique-lowercase-suffix> (Make sure $storageAccount is unique because it is Globally)
```
Return nothing
```
Now make sure storageAccount in 2 files Backend are same: *sthybridlab202610230913*
\hybrid-infrastructure-lab\terraform\01-identity\backend.tf
\hybrid-infrastructure-lab\terraform\02-vmresource\backend.tf

az group create --name $stateResourceGroup --location $location
```
{
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state",
  "location": "centralindia",
  "managedBy": null,
  "name": "rg-terraform-state",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

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
```
{
  "accessTier": "Hot",
  "accountMigrationInProgress": null,
  "allowBlobPublicAccess": false,
  "allowCrossTenantReplication": false,
  "allowSharedKeyAccess": false,
  "allowSharedKeyAccessForServices": null,
  "allowedCopyScope": null,
  "azureFilesIdentityBasedAuthentication": null,
  "blobRestoreStatus": null,
  "creationTime": "2026-10-23T14:27:50.939598+00:00",
  "customDomain": null,
  "dataCollaborationPolicyProperties": null,
  "defaultToOAuthAuthentication": null,
  "dnsEndpointType": null,
  "dualStackEndpointPreference": null,
  "enableExtendedGroups": null,
  "enableHttpsTrafficOnly": true,
  "enableNfsV3": null,
  "encryption": {
    "encryptionIdentity": null,
    "keySource": "Microsoft.Storage",
    "keyVaultProperties": null,
    "requireInfrastructureEncryption": null,
    "services": {
      "blob": {
        "enabled": true,
        "keyType": "Account",
        "lastEnabledTime": "2026-10-23T14:27:51.092763+00:00"
      },
      "file": {
        "enabled": true,
        "keyType": "Account",
        "lastEnabledTime": "2026-10-23T14:27:51.092763+00:00"
      },
      "queue": null,
      "table": null
    }
  },
  "extendedLocation": null,
  "failoverInProgress": null,
  "geoPriorityReplicationStatus": null,
  "geoReplicationStats": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913",
  "identity": null,
  "immutableStorageWithVersioning": null,
  "isHnsEnabled": null,
  "isLocalUserEnabled": null,
  "isSftpEnabled": null,
  "isSkuConversionBlocked": null,
  "keyCreationTime": {
    "key1": "2026-10-23T14:27:51.082659+00:00",
    "key2": "2026-10-23T14:27:51.082659+00:00"
  },
  "keyPolicy": null,
  "kind": "StorageV2",
  "largeFileSharesState": null,
  "lastGeoFailoverTime": null,
  "location": "centralindia",
  "minimumTlsVersion": "TLS1_2",
  "name": "sthybridlab202610230913",
  "networkRuleSet": {
    "bypass": "None",
    "defaultAction": "Allow",
    "ipRules": [],
    "ipv6Rules": [],
    "resourceAccessRules": null,
    "virtualNetworkRules": []
  },
  "placement": null,
  "primaryEndpoints": {
    "blob": "https://sthybridlab202610230913.blob.core.windows.net/",
    "dfs": "https://sthybridlab202610230913.dfs.core.windows.net/",
    "file": "https://sthybridlab202610230913.file.core.windows.net/",
    "internetEndpoints": null,
    "ipv6Endpoints": null,
    "microsoftEndpoints": null,
    "queue": "https://sthybridlab202610230913.queue.core.windows.net/",
    "table": "https://sthybridlab202610230913.table.core.windows.net/",
    "web": "https://sthybridlab202610230913.z29.web.core.windows.net/"
  },
  "primaryLocation": "centralindia",
  "privateEndpointConnections": [],
  "provisioningState": "Succeeded",
  "publicNetworkAccess": null,
  "resourceGroup": "rg-terraform-state",
  "routingPreference": null,
  "sasPolicy": null,
  "secondaryEndpoints": null,
  "secondaryLocation": null,
  "sku": {
    "name": "Standard_LRS",
    "tier": "Standard"
  },
  "statusOfPrimary": "available",
  "statusOfSecondary": null,
  "storageAccountSkuConversionStatus": null,
  "systemData": null,
  "tags": {},
  "type": "Microsoft.Storage/storageAccounts",
  "zones": null
}
```

az storage container create `
  --name $container `
  --account-name $storageAccount `
  --auth-mode login
```
{
  "created": true
}
```

az storage account blob-service-properties update `
  --account-name $storageAccount `
  --resource-group $stateResourceGroup `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 14 `
  --enable-container-delete-retention true `
  --container-delete-retention-days 14
```
{
  "automaticSnapshotPolicyEnabled": null,
  "changeFeed": null,
  "containerDeleteRetentionPolicy": {
    "allowPermanentDelete": null,
    "days": 14,
    "enabled": true
  },
  "cors": {
    "corsRules": []
  },
  "defaultServiceVersion": null,
  "deleteRetentionPolicy": {
    "allowPermanentDelete": null,
    "days": 14,
    "enabled": true
  },
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913/blobServices/default",
  "isVersioningEnabled": true,
  "lastAccessTimeTrackingPolicy": null,
  "name": "default",
  "resourceGroup": "rg-terraform-state",
  "restorePolicy": null,
  "sku": null,
  "staticWebsite": {
    "defaultIndexDocumentPath": null,
    "enabled": false,
    "errorDocument404Path": null,
    "indexDocument": null
  },
  "systemData": null,
  "type": "Microsoft.Storage/storageAccounts/blobServices"
}
```


az storage account show `
  --name $storageAccount `
  --resource-group $stateResourceGroup `
  --query "{name:name,httpsOnly:enableHttpsTrafficOnly,minTlsVersion:minimumTlsVersion,publicBlobAccess:allowBlobPublicAccess,sharedKeyAccess:allowSharedKeyAccess,defaultNetworkAction:networkRuleSet.defaultAction}" `
  --output table
```
Name                     HttpsOnly    MinTlsVersion    PublicBlobAccess    SharedKeyAccess    DefaultNetworkAction
-----------------------  -----------  ---------------  ------------------  -----------------  ----------------------
sthybridlab202610230913  True         TLS1_2           False               False              Allow
```

az storage account blob-service-properties show `
  --account-name $storageAccount `
  --resource-group $stateResourceGroup `
  --query "{versioning:isVersioningEnabled,blobDeleteRetention:deleteRetentionPolicy,containerDeleteRetention:containerDeleteRetentionPolicy}" `
  --output json
```
{
  "blobDeleteRetention": {
    "allowPermanentDelete": false,
    "days": 14,
    "enabled": true
  },
  "containerDeleteRetention": {
    "allowPermanentDelete": null,
    "days": 14,
    "enabled": true
  },
  "versioning": true
}
```

### Grant the bootstrap user Blob access

$storageScope = az storage account show `
  --name $storageAccount `
  --resource-group $stateResourceGroup `
  --query id -o tsv
$userObjectId = az ad signed-in-user show --query id -o tsv
$storageScope
$userObjectId
```
/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913

a6aa0fb-1ea8-42cd-80af-ae33be142ad0
```

az role assignment create `
  --assignee-object-id $userObjectId `
  --assignee-principal-type User `
  --role "Storage Blob Data Contributor" `
  --scope $storageScope
```
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-23T14:41:59.308307+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913/providers/Microsoft.Authorization/roleAssignments/bbbb0d98-2420-46fa-8f60-b08216c33597",
  "name": "bbbb0d98-2420-46fa-8f60-b08216c33597",
  "principalId": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "principalType": "User",
  "resourceGroup": "rg-terraform-state",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-23T14:41:59.714314+00:00"
}
```
Wait until the account is grant access to blob storage
Verify again with commands:

az storage container list --account-name $storageAccount --auth-mode login --output table
(if success will shows)
```
Name     Lease Status    Last Modified
-------  --------------  -------------------------
tfstate                  2026-10-23T14:32:27+00:00
```

### Configure both Terraform backends

terraform/01-identity/backend.tf
```
terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sthybridlab202610230913"
    container_name       = "tfstate"
    key                  = "hybrid-identity.tfstate"
  }
}
```


terraform/02-vmresource/backend.tf
```
terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sthybridlab202610230913"
    container_name       = "tfstate"
    key                  = "hybrid-vmresource.tfstate"
  }
}

```
### Check point completed

## 03 — Microsoft Entra OIDC, federated credentials, and Azure RBAC

### Identify the repository and Azure tenant

gh auth login
```
Now process login steps to github with gh cli

? Where do you use GitHub? **GitHub.com**
? What is your preferred protocol for Git operations on this host? **HTTPS**
? Authenticate Git with your GitHub credentials? **Yes**
? How would you like to authenticate GitHub CLI? **Login with a web browser**

! One-time code (**6B92-CBA3** use this code at login page with your Github account enabled and grant access) copied to clipboard 
Press Enter to open https://github.com/login/device in your browser...

✓ Authentication complete.
- gh config set -h github.com git_protocol https
✓ Configured git protocol
✓ Logged in as johnyhdev
```

Make sure to replace:
$repo = "<OWNER>/<REPOSITORY>"
<OWNER> = your account access. Here is johnyhdev (my account)
<REPOSITORY> = your cloned repo. Here is **hybrid-infrastructure-lab**.

$repo = "johnyhdev/hybrid-infrastructure-lab"
$repoInfo = gh api "repos/$repo" | ConvertFrom-Json
$owner = $repoInfo.owner.login
$ownerId = $repoInfo.owner.id
$repoName = $repoInfo.name
$repoId = $repoInfo.id
$tenantId = az account show --query tenantId -o tsv
$subscriptionId = az account show --query id -o tsv

check values
$repo
$repoInfo
$owner
$ownerId
$repoName
$repoId
$tenantId
$subscriptionId
```
johnyhdev/hybrid-infrastructure-lab
```

$repoInfo
```
id                             : 1348065848
node_id                        : R_kgDOUFnaOA
name                           : hybrid-infrastructure-lab
full_name                      : johnyhdev/hybrid-infrastructure-lab
private                        : False
owner                          : @{login=johnyhdev; id=269844224; node_id=U_kgDOEBV_AA; 
                                 avatar_url=https://avatars.githubusercontent.com/u/269844224?v=4; gravatar_id=; 
                                 url=https://api.github.com/users/johnyhdev; html_url=https://github.com/johnyhdev; 
                                 followers_url=https://api.github.com/users/johnyhdev/followers; 
                                 following_url=https://api.github.com/users/johnyhdev/following{/other_user}; 
                                 gists_url=https://api.github.com/users/johnyhdev/gists{/gist_id}; 
                                 starred_url=https://api.github.com/users/johnyhdev/starred{/owner}{/repo}; 
                                 subscriptions_url=https://api.github.com/users/johnyhdev/subscriptions; 
                                 organizations_url=https://api.github.com/users/johnyhdev/orgs; 
                                 repos_url=https://api.github.com/users/johnyhdev/repos; 
                                 events_url=https://api.github.com/users/johnyhdev/events{/privacy}; 
                                 received_events_url=https://api.github.com/users/johnyhdev/received_events; type=User; 
                                 user_view_type=public; site_admin=False}
html_url                       : https://github.com/johnyhdev/hybrid-infrastructure-lab
description                    : Steps guide: Lab test automation Terraform and ansible without SSH, Secret, etc,
fork                           : False
url                            : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab
forks_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/forks
keys_url                       : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/keys{/key_id}
collaborators_url              : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/collaborators{/collaborator}
teams_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/teams
hooks_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/hooks
issue_events_url               : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/issues/events{/number}
events_url                     : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/events
assignees_url                  : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/assignees{/user}
branches_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/branches{/branch}
tags_url                       : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/tags
blobs_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/git/blobs{/sha}
git_tags_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/git/tags{/sha}
git_refs_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/git/refs{/sha}
trees_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/git/trees{/sha}
statuses_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/statuses/{sha}
languages_url                  : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/languages
stargazers_url                 : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/stargazers
contributors_url               : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/contributors
subscribers_url                : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/subscribers
subscription_url               : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/subscription
commits_url                    : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/commits{/sha}
git_commits_url                : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/git/commits{/sha}
comments_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/comments{/number}
issue_comment_url              : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/issues/comments{/number}
contents_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/contents/{+path}
compare_url                    : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/compare/{base}...{head}
merges_url                     : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/merges
archive_url                    : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/{archive_format}{/ref}
downloads_url                  : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/downloads
issues_url                     : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/issues{/number}
pulls_url                      : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/pulls{/number}
milestones_url                 : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/milestones{/number}
notifications_url              : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/notifications{?since,all,partici
                                 pating}
labels_url                     : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/labels{/name}
releases_url                   : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/releases{/id}
deployments_url                : https://api.github.com/repos/johnyhdev/hybrid-infrastructure-lab/deployments
created_at                     : 2026-08-27T04:27:54Z
updated_at                     : 2026-10-22T09:11:35Z
pushed_at                      : 2026-10-22T09:11:29Z
git_url                        : git://github.com/johnyhdev/hybrid-infrastructure-lab.git
ssh_url                        : git@github.com:johnyhdev/hybrid-infrastructure-lab.git
clone_url                      : https://github.com/johnyhdev/hybrid-infrastructure-lab.git
svn_url                        : https://github.com/johnyhdev/hybrid-infrastructure-lab
homepage                       : 
size                           : 2241
stargazers_count               : 0
watchers_count                 : 0
language                       : HCL
has_issues                     : True
has_projects                   : True
has_downloads                  : False
has_wiki                       : True
has_pages                      : False
has_discussions                : False
forks_count                    : 0
mirror_url                     : 
archived                       : False
disabled                       : False
open_issues_count              : 0
license                        : @{key=mit; name=MIT License; spdx_id=MIT; url=https://api.github.com/licenses/mit; 
                                 node_id=MDc6TGljZW5zZTEz}
allow_forking                  : True
is_template                    : True
web_commit_signoff_required    : False
has_pull_requests              : True
pull_request_creation_policy   : collaborators_only
topics                         : {}
visibility                     : public
forks                          : 0
open_issues                    : 0
watchers                       : 0
default_branch                 : main
permissions                    : @{admin=True; maintain=True; push=True; triage=True; pull=True}
temp_clone_token               : 
allow_squash_merge             : True
allow_merge_commit             : True
allow_rebase_merge             : True
allow_auto_merge               : False
delete_branch_on_merge         : False
allow_update_branch            : False
use_squash_pr_title_as_default : False
squash_merge_commit_title      : COMMIT_OR_PR_TITLE
merge_commit_message           : PR_TITLE
security_and_analysis          : @{secret_scanning=; secret_scanning_push_protection=; dependabot_security_updates=; 
                                 secret_scanning_non_provider_patterns=; secret_scanning_validity_checks=}
subscribers_count              : 0
```

$ownerId
```
269844224
```

$repoName
```
hybrid-infrastructure-lab
```

$repoId
```
1348065848
```

$tenantId
```
25249825-52b8-4478-bd14-bc39033c86d0
```

$subscriptionId
```
adee883c-f49b-4d4a-a5e1-8eedf0d4454c
```

Now craft your immutable subjects follow this:
repo:<OWNER>@<OWNER_ID>/<REPOSITORY>@<REPOSITORY_ID>:environment:<ENVIRONMENT>

```
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:<ENVIRONMENT>

**<ENVIRONMENT>** later you could change this to correct value.
```

### Create five Entra applications and service principals

$displayNames = @(
  "terraform-identity-plan",
  "terraform-identity-apply",
  "terraform-vmresource-plan",
  "terraform-vmresource-apply",
  "terraform-destroy"
)
```
Return nothing
```

foreach ($displayName in $displayNames) {
  Write-Host "--- $displayName ---"
  az ad app list --display-name $displayName --query "[].{displayName:displayName,clientId:appId,applicationObjectId:id}" --output table
}
```
--- terraform-identity-plan ---

--- terraform-identity-apply ---

--- terraform-vmresource-plan ---

--- terraform-vmresource-apply ---

--- terraform-destroy ---

It's safe to create 5 Entra app. Return nothing.
```


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
DisplayName                ApplicationClientId                  ApplicationObjectId                  ServicePrincipalObjectId            
-----------                -------------------                  -------------------                  ------------------------            
terraform-identity-plan    42997876-5fbf-4bf3-a205-22fe57dd2a7e 4016df0d-78f4-4f50-84ae-b721e5d75350 45bbd344-62c6-468a-b095-2c7b6cbec76e
terraform-identity-apply   45a1f2db-9414-4ae0-a673-3bd26a151b06 f6f084d3-db93-479a-923d-e8d484dd7553 9a2f99b9-3fb8-4984-b2af-2fc2604f4f71
terraform-vmresource-plan  1bb529c8-b19c-4072-b203-16bf8ea4cf73 4eda0cb5-c61d-4009-b740-06bdfb3a56a7 a2e7349f-38bf-4b71-9228-b85fec9eaf65
terraform-vmresource-apply 90ab1ff5-6a07-4218-a559-cda0233030b0 5e9a8dd7-e82b-4a4a-8da9-9baeeb1f941a 2b461c5f-6b6f-43dc-9eaf-7d3c41521346
terraform-destroy          171e640a-d1e5-4b5f-a1bc-f12c43f456ad 76d93c47-3e33-437f-86ad-7cd58b899af2 07c80f58-0969-4a00-be7c-4be147f485ff
```

### Create and verify the five federated credentials

$repo = "johnyhdev/hybrid-infrastructure-lab"
$repoInfo = gh api "repos/$repo" | ConvertFrom-Json
$owner = $repoInfo.owner.login
$ownerId = $repoInfo.owner.id
$repoName = $repoInfo.name
$repoId = $repoInfo.id
"Repository: $owner/$repoName (ID $repoId); owner ID $ownerId"
```
Repository: johnyhdev/hybrid-infrastructure-lab (ID 1348065848); owner ID 269844224
```

$environment = "terraform-vmresource-plan"
$subject = "repo:$($owner)@$($ownerId)/$($repoName)@$($repoId):environment:$environment"
$subject
```
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-vmresource-plan
```

Now create 4 mores:
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-identity-plan
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-identity-apply
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-vmresource-apply
repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-destroy

### Generate the five JSON files outside the repository


$ficDir = Join-Path $env:TEMP "hybrid-lab-federated-credentials"
New-Item -ItemType Directory -Path $ficDir -Force | Out-Null
Set-Location $ficDir
```
Return nothing
```

Now copy ApplicationObjectId of you and replace

$appObjectIds = @{
  "terraform-identity-plan"    = "4016df0d-78f4-4f50-84ae-b721e5d75350"
  "terraform-identity-apply"   = "f6f084d3-db93-479a-923d-e8d484dd7553"
  "terraform-vmresource-plan"  = "4eda0cb5-c61d-4009-b740-06bdfb3a56a7"
  "terraform-vmresource-apply" = "5e9a8dd7-e82b-4a4a-8da9-9baeeb1f941a"
  "terraform-destroy"          = "76d93c47-3e33-437f-86ad-7cd58b899af2"
}
```
Return nothing
```


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
Name                            Length
----                            ------
terraform-destroy.json             399
terraform-identity-apply.json      420
terraform-identity-plan.json       417
terraform-vmresource-apply.json    426
terraform-vmresource-plan.json     423
```
Make sure 5 files are created and can be used for the next step

Get-Content (Join-Path $ficDir "terraform-vmresource-plan.json")
```
{
    "subject":  "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-vmresource-plan",
    "audiences":  [
                      "api://AzureADTokenExchange"
                  ],
    "issuer":  "https://token.actions.githubusercontent.com",
    "name":  "github-terraform-vmresource-plan",
    "description":  "GitHub Actions federated credential for terraform-vmresource-plan"
}
```

### Create each FIC on its matching app


foreach ($environment in $environments) {
  $appObjectId = $appObjectIds[$environment]
  $jsonPath = Join-Path $ficDir "$environment.json"
  az ad app federated-credential create --id $appObjectId --parameters $jsonPath --output none
  if ($LASTEXITCODE -ne 0) { throw "FIC creation failed for $environment; stop and correct the reported error." }
  Write-Host "Created FIC for $environment on Application Object ID $appObjectId"
}
```
Created FIC for terraform-identity-plan on Application Object ID 4016df0d-78f4-4f50-84ae-b721e5d75350
Created FIC for terraform-identity-apply on Application Object ID f6f084d3-db93-479a-923d-e8d484dd7553
Created FIC for terraform-vmresource-plan on Application Object ID 4eda0cb5-c61d-4009-b740-06bdfb3a56a7
Created FIC for terraform-vmresource-apply on Application Object ID 5e9a8dd7-e82b-4a4a-8da9-9baeeb1f941a
Created FIC for terraform-destroy on Application Object ID 76d93c47-3e33-437f-86ad-7cd58b899af2
```

### Verify every app before deleting the files

foreach ($environment in $environments) {
  Write-Host "--- $environment ---"
  az ad app federated-credential list `
    --id $appObjectIds[$environment] `
    --query "[?name=='github-$environment'].{name:name,issuer:issuer,subject:subject,audiences:audiences}" `
    --output json
  if ($LASTEXITCODE -ne 0) { throw "FIC verification failed for $environment." }
}
```
--- terraform-identity-plan ---
[
  {
    "audiences": [
      "api://AzureADTokenExchange"
    ],
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-terraform-identity-plan",
    "subject": "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-identity-plan"
  }
]
--- terraform-identity-apply ---
[
  {
    "audiences": [
      "api://AzureADTokenExchange"
    ],
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-terraform-identity-apply",
    "subject": "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-identity-apply"
  }
]
--- terraform-vmresource-plan ---
[
  {
    "audiences": [
      "api://AzureADTokenExchange"
    ],
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-terraform-vmresource-plan",
    "subject": "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-vmresource-plan"
  }
]
--- terraform-vmresource-apply ---
[
  {
    "audiences": [
      "api://AzureADTokenExchange"
    ],
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-terraform-vmresource-apply",
    "subject": "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-vmresource-apply"
  }
]
--- terraform-destroy ---
[
  {
    "audiences": [
      "api://AzureADTokenExchange"
    ],
    "issuer": "https://token.actions.githubusercontent.com",
    "name": "github-terraform-destroy",
    "subject": "repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:terraform-destroy"
  }
]
```


Make sure you Set-Location back to your github repo hybrid-infrastructure-lab

Set-Location "d:\hybrid-infrastructure-lab"
Remove-Item -LiteralPath $ficDir -Recurse -Force
Test-Path -LiteralPath $ficDir
```
False
```

Do not run these codes, it will delete FIC. Only use it when you want to revoke FIC.

```
az ad app federated-credential list --id "<APP_OBJECT_ID>" --output table
az ad app federated-credential delete --id "<APP_OBJECT_ID>" --federated-credential-id "<EXACT_FIC_NAME_FROM_LIST>"
az ad app federated-credential list --id "<APP_OBJECT_ID>" --output table
```

### Assign Azure RBAC roles

$subscriptionScope = az account show --query id -o tsv
$labRgScope = az group show --name "rg-hybrid-infra-lab" --query id -o tsv
```
$subscriptionScope
adee883c-f49b-4d4a-a5e1-8eedf0d4454c

$labRgScope
/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab
```

$storageScope = az storage account show --name "sthybridlab202610230913" --resource-group "rg-terraform-state" --query id -o tsv
$storageScope
```
$storageScope
/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
```

Template code:
az role assignment create --assignee-object-id <SP_OBJECT_ID> --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope $storageScope


$spObjectIds = @{
  "terraform-identity-plan"    = "45bbd344-62c6-468a-b095-2c7b6cbec76e"
  "terraform-identity-apply"   = "9a2f99b9-3fb8-4984-b2af-2fc2604f4f71"
  "terraform-vmresource-plan"  = "a2e7349f-38bf-4b71-9228-b85fec9eaf65"
  "terraform-vmresource-apply" = "2b461c5f-6b6f-43dc-9eaf-7d3c41521346"
  "terraform-destroy"          = "07c80f58-0969-4a00-be7c-4be147f485ff"
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
results:
```
--- terraform-identity-apply state access ---
Role                           Scope
-----------------------------  ---------------------------------------------------------------------------------------------------------------------------------------------------------
Storage Blob Data Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
--- terraform-vmresource-apply state access ---
Role                           Scope
-----------------------------  ---------------------------------------------------------------------------------------------------------------------------------------------------------
Storage Blob Data Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
--- terraform-identity-plan state access ---
Role                           Scope
-----------------------------  ---------------------------------------------------------------------------------------------------------------------------------------------------------
Storage Blob Data Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
--- terraform-destroy state access ---
Role                           Scope
-----------------------------  ---------------------------------------------------------------------------------------------------------------------------------------------------------
Storage Blob Data Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
--- terraform-vmresource-plan state access ---
Role                           Scope
-----------------------------  ---------------------------------------------------------------------------------------------------------------------------------------------------------
Storage Blob Data Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sthybridlab202610230913
```


Now grant priviledge to create Azure Resource

$subscriptionScope = "/subscriptions/$(az account show --query id -o tsv)"

# Identity plan: subscription Reader, because the Resource Group may not exist yet.
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-plan"] --assignee-principal-type ServicePrincipal --role "Reader" --scope $subscriptionScope

# Identity apply: temporary bootstrap permissions. Contributor does not grant roleAssignments/write.
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-apply"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $subscriptionScope
az role assignment create --assignee-object-id $spObjectIds["terraform-identity-apply"] --assignee-principal-type ServicePrincipal --role "User Access Administrator" --scope $subscriptionScope
Results
```
terraform-identity-plan
{
  "condition": null,
  "conditionVersion": null,
  "createdOn": "2026-10-24T00:45:48.219763+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleAssignments/3fb9e28f-b41b-4e10-ba9b-e13c72503889",
  "name": "3fb9e28f-b41b-4e10-ba9b-e13c72503889",
  "principalId": "45bbd344-62c6-468a-b095-2c7b6cbec76e",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T00:45:48.464768+00:00"
}

Terraform-identity-apply contributor
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-24T00:45:53.247382+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleAssignments/b0b583f6-2d2f-4dfc-8603-f8301e682472",
  "name": "b0b583f6-2d2f-4dfc-8603-f8301e682472",
  "principalId": "9a2f99b9-3fb8-4984-b2af-2fc2604f4f71",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T00:45:53.472380+00:00"
}

Terraform-identity-apply User Access Administrator
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-24T00:47:07.807210+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleAssignments/c21b8f8c-97aa-4f7e-a473-99b08e481c43",
  "name": "c21b8f8c-97aa-4f7e-a473-99b08e481c43",
  "principalId": "9a2f99b9-3fb8-4984-b2af-2fc2604f4f71",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T00:47:08.152634+00:00"
}
```

Now go to hybrid-infrastructure-lab/terraform/01-identity and process terraform

cd terraform/01-identity
terraform init (or **terraform init -reconfigure**, if your terraform run successful with the old backend.tf last time)
results
```
Initializing the backend...

Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v4.81.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

terraform fmt
result
```
return nothing
```

terraform validate
result
```
Success! The configuration is valid.
```


terraform plan
result
```
Acquiring state lock. This may take a few moments...

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following
symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "centralindia"
      + name     = "rg-hybrid-infra-lab"
      + tags     = {
          + "managed_by" = "terraform"
          + "role"       = "lab-foundation"
        }
    }

  # azurerm_role_assignment.cm_reader will be created
  + resource "azurerm_role_assignment" "cm_reader" {
      + condition_version                = (known after apply)
      + id                               = (known after apply)
      + name                             = (known after apply)
      + principal_id                     = (known after apply)
      + principal_type                   = (known after apply)
      + role_definition_id               = (known after apply)
      + role_definition_name             = "Reader"
      + scope                            = (known after apply)
      + skip_service_principal_aad_check = (known after apply)
    }

  # azurerm_user_assigned_identity.cm will be created
  + resource "azurerm_user_assigned_identity" "cm" {
      + client_id           = (known after apply)
      + id                  = (known after apply)
      + location            = "centralindia"
      + name                = "id-cm"
      + principal_id        = (known after apply)
      + resource_group_name = "rg-hybrid-infra-lab"
      + tags                = {
          + "managed_by" = "terraform"
          + "role"       = "control-manager"
        }
      + tenant_id           = (known after apply)
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cm_client_id        = (known after apply)
  + cm_identity_id      = (known after apply)
  + cm_principal_id     = (known after apply)
  + resource_group_name = "rg-hybrid-infra-lab"
  + tenant_id           = (known after apply)

─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform
apply" now.
Releasing state lock. This may take a few moments...
```

terraform apply -auto-approve
```
azurerm_user_assigned_identity.cm: Creation complete after 7s [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-cm]
azurerm_role_assignment.cm_reader: Creating...
azurerm_role_assignment.cm_reader: Still creating... [00m10s elapsed]
azurerm_role_assignment.cm_reader: Still creating... [00m20s elapsed]
azurerm_role_assignment.cm_reader: Still creating... [00m30s elapsed]
azurerm_role_assignment.cm_reader: Creation complete after 32s [id=/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.Authorization/roleAssignments/404096df-9771-fc19-f347-7e669db1120f]
Releasing state lock. This may take a few moments...

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

cm_client_id = "62fe8c7e-d841-4f01-a8fe-cfd9ff18fd9e"
cm_identity_id = "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-cm"
cm_principal_id = "351683d1-df30-4f81-83f9-72704b25988e"
resource_group_name = "rg-hybrid-infra-lab"
tenant_id = "25249825-52b8-4478-bd14-bc39033c86d0"
```

After 01-identity resource available, continue

$labRgScope = az group show --name "rg-hybrid-infra-lab" --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $labRgScope) { throw "Lab Resource Group not found; do not continue." }

az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-plan"] --assignee-principal-type ServicePrincipal --role "Reader" --scope $labRgScope
az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-apply"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope
az role assignment create --assignee-object-id $spObjectIds["terraform-destroy"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope

results
```
az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-plan"] --assignee-principal-type ServicePrincipal --role "Reader" --scope $labRgScope
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-24T01:11:52.972037+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.Authorization/roleAssignments/284518b3-91e7-44b7-98a0-e0895b2d9d75",
  "name": "284518b3-91e7-44b7-98a0-e0895b2d9d75",
  "principalId": "a2e7349f-38bf-4b71-9228-b85fec9eaf65",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T01:11:53.392049+00:00"
}


az role assignment create --assignee-object-id $spObjectIds["terraform-vmresource-apply"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-24T01:11:58.178103+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.Authorization/roleAssignments/a9995f11-c35f-4d2f-bab0-b04817a2689f",
  "name": "a9995f11-c35f-4d2f-bab0-b04817a2689f",
  "principalId": "2b461c5f-6b6f-43dc-9eaf-7d3c41521346",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T01:11:58.579110+00:00"
}


az role assignment create --assignee-object-id $spObjectIds["terraform-destroy"] --assignee-principal-type ServicePrincipal --role "Contributor" --scope $labRgScope
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2026-10-24T01:12:05.708612+00:00",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab/providers/Microsoft.Authorization/roleAssignments/77ba9448-7dea-427a-a7fd-644f0b2e2aeb",
  "name": "77ba9448-7dea-427a-a7fd-644f0b2e2aeb",
  "principalId": "07c80f58-0969-4a00-be7c-4be147f485ff",
  "principalType": "ServicePrincipal",
  "resourceGroup": "rg-hybrid-infra-lab",
  "roleDefinitionId": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
  "scope": "/subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab",
  "systemData": null,
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "4a6aa0fb-1ea8-42cd-80af-ae33be142ad0",
  "updatedOn": "2026-10-24T01:12:06.149620+00:00"
}

```


Verify code

az role assignment list `
  --assignee-object-id $spObjectIds["terraform-vmresource-apply"] `
  --scope $labRgScope `
  --query "[].{role:roleDefinitionName,scope:scope,principal:principalId}" `
  --output table
result
```
Role         Scope                                                                                   Principal
-----------  --------------------------------------------------------------------------------------  ------------------------------------
Contributor  /subscriptions/adee883c-f49b-4d4a-a5e1-8eedf0d4454c/resourceGroups/rg-hybrid-infra-lab  2b461c5f-6b6f-43dc-9eaf-7d3c41521346
```

## 04 — Tailscale WIF and policy

### Prepare and apply the initial policy

Get-Content .\tailscale\policy.hujson -Raw | Set-Clipboard
(Get-Item .\tailscale\policy.hujson).Length
result
```
Return nothing (because data is compied to the clipboard)
```

Now go to Tailscale admin -> Access -> JSON Editor and paste code, verify status then **Save**.

### GitHub policy GitOps credential

Follow: Admin Console -> Settings -> Trust Credentials -> + Credential -> Choose OPEN ID Connect -> 

```
Description: github-tailscale-policy
Issuer: https://token.actions.githubusercontent.com (or choose Github)
Subject: repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:tailscale-policy (make sure to enter correct your repo and surfix: environment:tailscale-policy)

Next -> SCOPES
Find General -> Policy File (Check Write) -> Generate Credential.

Make sure to save:
github-tailscale-policy: CLIENT ID: TNyex2DCUG11CNTRL-k2hNUvoipW11CNTRL (TAILSCALE_POLICY_CLIENT_ID)
github-tailscale-policy: Audience (aud Claim): api.tailscale.com/TNyex2DCUG11CNTRL-k2hNUvoipW11CNTRL (TAILSCALE_POLICY_AUDIENCE)

Get **Tailnet ID/unique ID** at Tailscale Admin Console -> Settings -> General -> Tailnet ID: TNyex2DCUG11CNTRL

github-tailscale-policy: Tailnet ID: TAILSCALE_TAILNET: TNyex2DCUG11CNTRL

Using 3 as **Variables** in Github Environment **tailscale-policy**
```
After that, repeat to create github-tailscale-ci

+ Credential -> Choose OPEN ID Connect -> 
```
Description: github-tailscale-ci
Issuer: https://token.actions.githubusercontent.com (or choose Github)
Subject: repo:johnyhdev@269844224/hybrid-infrastructure-lab@1348065848:environment:tailscale-ci (make sure to enter correct your repo and surfix: environment:tailscale-ci)

Next -> SCOPES
Find Keys -> AUTH KEYS (Check Write) -> Look at Tags: choose **tag:ci** -> Generate Credential.

Make sure to save:
github-tailscale-ci: CLIENT ID: TNyex2DCUG11CNTRL-k1mATHLGmh11CNTRL
github-tailscale-ci: Audience (aud Claim): api.tailscale.com/TNyex2DCUG11CNTRL-k1mATHLGmh11CNTRL

Using as **Secrets values** in Github Environment **tailscale-ci**
```

### Azure managed identity credential
Go to VS Code root:

az identity show --resource-group "<LAB_RESOURCE_GROUP>" --name "<CM_IDENTITY_NAME>" --query "{tenantId:tenantId,principalId:principalId,clientId:clientId}" --output table

Edit values:
az identity show --resource-group "rg-hybrid-infra-lab" --name "id-cm" --query "{tenantId:tenantId,principalId:principalId,clientId:clientId}" --output table
result
```
TenantId                              PrincipalId                           ClientId
------------------------------------  ------------------------------------  ------------------------------------
25249825-52b8-4478-bd14-bc39033c86d0  351683d1-df30-4f81-83f9-72704b25988e  62fe8c7e-d841-4f01-a8fe-cfd9ff18fd9e
```

Back to tailscale admin console:

+ Credential -> Choose OPEN ID Connect -> 
```
Description: azure-vm-cm
Issuer: 25249825-52b8-4478-bd14-bc39033c86d0 (Copied Your TenantId from the code above, this ID from my Tenant)
Subject: 351683d1-df30-4f81-83f9-72704b25988e (paste Your PrincipalID from the code above, this is my ID)
Audience: fb60f99c-7a34-4190-8149-302f77469936 (Default Azure audience)

Continue -> SCOPES
Find Keys -> AUTH KEYS (Check Write) -> Look at Tags: choose **tag:cm** -> Generate Credential.

Make sure to save:
azure-vm-cm CLIENT_ID: TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL
azure-vm-cm Audience: fb60f99c-7a34-4190-8149-302f77469936

2 values will be used as **secrets values* in Github Environment:
terraform-vmresource-plan
terraform-vmresource-apply
terraform-destroy

Github Secrets:
TAILSCALE_CM_AUDIENCE: fb60f99c-7a34-4190-8149-302f77469936
TAILSCALE_CM_CLIENT_ID: TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL
```

Done next

## 05 — GitHub Environments, secrets, variables, and protection

Goto Github -> Repo hybrid-infrastructure-lab -> Settings -> Environments -> New Environment

```
Follow tables and create:
terraform-identity-plan
terraform-identity-apply
terraform-vmresource-plan
terraform-vmresource-apply
terraform-destroy

table with Var:
| Environment | `AZURE_CLIENT_ID` | `AZURE_TENANT_ID` | `AZURE_SUBSCRIPTION_ID` | Additional secret | Variables |
|---|---|---|---|---|---|
| `terraform-identity-plan` | Identity plan app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-identity-apply` | Identity apply app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-vmresource-plan` | VM plan app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-vmresource-apply` | VM apply app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-destroy` | Destroy app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |

table with Secrets values:
| Environment | `AZURE_CLIENT_ID` | `AZURE_TENANT_ID` | `AZURE_SUBSCRIPTION_ID` | Additional secret | Variables |
|---|---|---|---|---|---|
| `terraform-identity-plan` | 42997876-5fbf-4bf3-a205-22fe57dd2a7e | 25249825-52b8-4478-bd14-bc39033c86d0 | adee883c-f49b-4d4a-a5e1-8eedf0d4454c | — | — |
| `terraform-identity-apply` | 45a1f2db-9414-4ae0-a673-3bd26a151b06 | 25249825-52b8-4478-bd14-bc39033c86d0 | adee883c-f49b-4d4a-a5e1-8eedf0d4454c | — | — |
| `terraform-vmresource-plan` | 1bb529c8-b19c-4072-b203-16bf8ea4cf73 | 25249825-52b8-4478-bd14-bc39033c86d0 | adee883c-f49b-4d4a-a5e1-8eedf0d4454c | `SSH_PUBLIC_KEY (get values from your terraform.tfvars)` | `TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL`, `fb60f99c-7a34-4190-8149-302f77469936` |
| `terraform-vmresource-apply` | 90ab1ff5-6a07-4218-a559-cda0233030b0 | 25249825-52b8-4478-bd14-bc39033c86d0 | adee883c-f49b-4d4a-a5e1-8eedf0d4454c | `SSH_PUBLIC_KEY(get values from your terraform.tfvars)` | `TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL`, `fb60f99c-7a34-4190-8149-302f77469936` |
| `terraform-destroy` | 171e640a-d1e5-4b5f-a1bc-f12c43f456ad | 25249825-52b8-4478-bd14-bc39033c86d0 | adee883c-f49b-4d4a-a5e1-8eedf0d4454c | `SSH_PUBLIC_KEY(get values from your terraform.tfvars)` | `TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL`, `fb60f99c-7a34-4190-8149-302f77469936` |

Values summary for repo johnyhdev (**do not use for your repo, it wont work**):
# ==========================================
# HYBRID INFRASTRUCTURE LAB - VALUES SUMMARY
# ==========================================

# --- COMMON VALUES ---
AZURE_TENANT_ID=25249825-52b8-4478-bd14-bc39033c86d0
AZURE_SUBSCRIPTION_ID=adee883c-f49b-4d4a-a5e1-8eedf0d4454c

# --- 1. terraform-identity-plan ---
[terraform-identity-plan]
AZURE_CLIENT_ID=42997876-5fbf-4bf3-a205-22fe57dd2a7e

# --- 2. terraform-identity-apply ---
[terraform-identity-apply]
AZURE_CLIENT_ID=45a1f2db-9414-4ae0-a673-3bd26a151b06

# --- 3. terraform-vmresource-plan ---
[terraform-vmresource-plan]
AZURE_CLIENT_ID=1bb529c8-b19c-4072-b203-16bf8ea4cf73
TAILSCALE_CM_CLIENT_ID=TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL
TAILSCALE_CM_AUDIENCE=fb60f99c-7a34-4190-8149-302f77469936

# --- 4. terraform-vmresource-apply ---
[terraform-vmresource-apply]
AZURE_CLIENT_ID=90ab1ff5-6a07-4218-a559-cda0233030b0
TAILSCALE_CM_CLIENT_ID=TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL
TAILSCALE_CM_AUDIENCE=fb60f99c-7a34-4190-8149-302f77469936

# --- 5. terraform-destroy ---
[terraform-destroy]
AZURE_CLIENT_ID=171e640a-d1e5-4b5f-a1bc-f12c43f456ad
TAILSCALE_CM_CLIENT_ID=TNyex2DCUG11CNTRL-knAo6LQRwo11CNTRL
TAILSCALE_CM_AUDIENCE=fb60f99c-7a34-4190-8149-302f77469936
```

### Tailscale environments

Now create tailscale environment:

```
tailscale-ci: create secrets TAILSCALE_CI_CLIENT_ID and TAILSCALE_CI_AUDIENCE only. No SSH_PRIVATE_KEY secret is required for the current CI-to-CM connection.
github-tailscale-ci: CLIENT ID: **TNyex2DCUG11CNTRL-k1mATHLGmh11CNTRL**
github-tailscale-ci: Audience (aud Claim): **api.tailscale.com/TNyex2DCUG11CNTRL-k1mATHLGmh11CNTRL**


tailscale-policy: create variables TAILSCALE_POLICY_CLIENT_ID, TAILSCALE_POLICY_AUDIENCE, and TAILSCALE_TAILNET.
github-tailscale-policy: CLIENT ID: **TNyex2DCUG11CNTRL-k2hNUvoipW11CNTRL** (TAILSCALE_POLICY_CLIENT_ID)
github-tailscale-policy: Audience (aud Claim): **api.tailscale.com/TNyex2DCUG11CNTRL-k2hNUvoipW11CNTRL** (TAILSCALE_POLICY_AUDIENCE)
github-tailscale-policy: Tailnet ID: TAILSCALE_TAILNET: **TNyex2DCUG11CNTRL**
```

### Protect environments and main

Each environment: terraform-identity-apply, terraform-vmresource-apply, terraform-destroy, tailscale-policy, tailscale-ci
```
-> Enable Required reviewers (add Approver account: here is wiflyoteam)
-> Deployment branches and tag -> Choose "Selected Branches and tags" -> Choose Ref type: branch -> Enter Name Pattern "main" -> Add rule

```

Now protect Main:
```
Follow the guide
```

## 06 — Run workflows, deploy, and verify

### Push and review checks

