variable "resource_group_name" {
  description = "Persistent lab resource group"
  type        = string
  default     = "rg-hybrid-infra-lab-ha"
}

variable "managed_identity_name" {
  description = "Control Manager managed identity"
  type        = string
  default     = "id-cm-ha"
}

variable "vnet_name" {
  description = "Main virtual network"
  type        = string
  default     = "vnet-hybrid-infra-ha"
}

variable "automation_subnet_name" {
  description = "Control Manager subnet"
  type        = string
  default     = "snet-automation-ha"
}

variable "workload_subnet_name" {
  description = "Workload subnet"
  type        = string
  default     = "snet-workload-ha"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "ubuntu_image_version" {
  description = "Exact Ubuntu 24.04 ARM64 marketplace image version available in the selected region"
  type        = string
  default     = "latest" # Example: "24.04.202509120"

  validation {
    # Cho phép nhận giá trị "latest" hoặc đúng định dạng 24.04.[số]
    condition     = var.ubuntu_image_version == "latest" || can(regex("^24[.]04[.][0-9]+$", var.ubuntu_image_version))
    error_message = "Provide either 'latest' or an exact Ubuntu ARM64 image version matching 24.04.xxxxx."
  }
}

variable "ssh_public_key" {
  description = "Administrator public SSH key required for secure VM provisioning and emergency access."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.ssh_public_key)) > 0
    error_message = "Set ssh_public_key to the administrator's SSH public key."
  }
}

variable "control_vms" {
  description = "Control Manager VM definitions; HA mode requires two nodes across distinct zones"

  type = map(object({
    size              = string
    zone              = string
    os_disk_size_gb   = number
    data_disk_size_gb = number
  }))

  default = {
    "vm-cm-01" = {
      size              = "Standard_D2ps_v6"
      zone              = "1"
      os_disk_size_gb   = 30
      data_disk_size_gb = 0
    }
    "vm-cm-02" = {
      size              = "Standard_D2ps_v6"
      zone              = "3"
      os_disk_size_gb   = 30
      data_disk_size_gb = 0
    }
  }

  validation {
    condition     = length(var.control_vms) >= 1
    error_message = "At least one control-manager VM is required; set ha_mode=false for a single-node non-HA lab."
  }
}

variable "ha_mode" {
  description = "When true, require at least two control VMs in distinct zones and two workload VMs"
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "ID of the Disk Encryption Set to use for managed disks"
  type        = string
  default     = ""
}

variable "tailscale_cm_client_id" {
  description = "Tailscale WIF client ID for CM VMs"
  type        = string
  default     = "TNyex2DCUG11CNTRL-krrc39yEGY11CNTRL"

  validation {
    condition     = length(trimspace(var.tailscale_cm_client_id)) > 0
    error_message = "Set tailscale_cm_client_id to the client ID created for the Azure control-manager WIF credential."
  }
}

variable "tailscale_cm_audience" {
  description = "Tailscale WIF audience for CM VMs"
  type        = string
  default     = "fb60f99c-7a34-4190-8149-302f77469936"

  validation {
    condition     = length(trimspace(var.tailscale_cm_audience)) > 0
    error_message = "Set tailscale_cm_audience to the audience configured for the Azure control-manager WIF credential."
  }
}

variable "workload_vms" {
  description = "Workload VM definitions; exactly three PostgreSQL members may share zones when capacity is limited"

  type = map(object({
    size                    = string
    zone                    = string
    os_disk_size_gb         = number
    data_disk_size_gb       = optional(number, 0)
    database_cluster_member = optional(bool, false)
    cloudflare_ingress      = optional(bool, false)
  }))

  default = {
    "vm-workload-01" = {
      size                    = "Standard_D2ps_v6"
      zone                    = "1"
      os_disk_size_gb         = 30
      database_cluster_member = true
      cloudflare_ingress      = true
    }
    "vm-workload-02" = {
      size                    = "Standard_D2ps_v6"
      zone                    = "1"
      os_disk_size_gb         = 30
      database_cluster_member = true
      cloudflare_ingress      = true
    }
    "vm-workload-03" = {
      size                    = "Standard_D2ps_v6"
      zone                    = "3"
      os_disk_size_gb         = 30
      database_cluster_member = true
      cloudflare_ingress      = true
    }
  }

  validation {
    condition     = length(var.workload_vms) >= 3 && length(var.workload_vms) <= 250
    error_message = "workload_vms must contain the three HA database/app nodes and no more than 250 total nodes."
  }

  validation {
    condition     = length([for vm in values(var.workload_vms) : vm if vm.database_cluster_member]) == 3
    error_message = "Exactly three workload VMs must be designated as PostgreSQL HA cluster members."
  }

}

variable "tailscale_workload_client_id" {
  description = "Tailscale WIF client ID for workload VMs"
  type        = string
  default     = "TNyex2DCUG11CNTRL-kgjfSznGt221CNTRL"

  validation {
    condition     = length(trimspace(var.tailscale_workload_client_id)) > 0
    error_message = "Set tailscale_workload_client_id to the workload Azure WIF credential client ID."
  }
}

variable "tailscale_workload_audience" {
  description = "Tailscale WIF audience for workload VMs"
  type        = string
  default     = "fb60f99c-7a34-4190-8149-302f77469936"

  validation {
    condition     = length(trimspace(var.tailscale_workload_audience)) > 0
    error_message = "Set tailscale_workload_audience to the workload Azure WIF credential audience."
  }
}

variable "enable_load_balancer" {
  description = "Enable the optional private Azure Load Balancer for workload VMs"
  type        = bool
  default     = false
}

variable "control_plane_subnet_cidr" {
  description = "Control-manager subnet CIDR"
  type        = string
  default     = "10.20.1.0/24"
}

variable "workload_plane_subnet_cidr" {
  description = "Workload subnet CIDR"
  type        = string
  default     = "10.20.2.0/23"
}

variable "workload_managed_identity_name" {
  description = "Workload identity created by the identity root"
  type        = string
  default     = "id-workload-ha"
}

variable "key_vault_name" {
  description = "Key Vault created by the identity root for workload runtime secrets"
  type        = string
  default     = "kvhybridinfra26111010"
}

variable "loki_storage_account_name" {
  description = "Globally unique private Azure Storage account for durable Loki chunks/index and recovery state"
  type        = string
  default     = "lokistorage26111010"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.loki_storage_account_name))
    error_message = "loki_storage_account_name must be 3-24 lowercase letters and digits."
  }
}

variable "storage_encryption_key_name" {
  description = "Name of the RSA key stored in the Azure Key Vault when customer-managed storage encryption is enabled"
  type        = string
  default     = "loki-encryption-key"
}

variable "enable_storage_cmk" {
  description = "Opt in to customer-managed Blob encryption; enabling it requires the matching Key Vault key and may incur extra Key Vault operation charges"
  type        = bool
  default     = false
}

variable "tailscale_package_version" {
  description = "Exact Tailscale client release version installed by bootstrap"
  type        = string
  default     = "1.78.3"

  validation {
    condition     = can(regex("^[0-9]+[.][0-9]+[.][0-9]+$", var.tailscale_package_version))
    error_message = "Provide an exact Tailscale x.y.z release version."
  }
}

variable "azure_cli_version" {
  description = "Exact Azure CLI APT package version installed on control managers"
  type        = string
  default     = "2.65.0-1~noble"

  validation {
    condition     = length(trimspace(var.azure_cli_version)) > 0 && !strcontains(var.azure_cli_version, "latest")
    error_message = "Provide the exact Azure CLI package version available in the Microsoft Ubuntu repository."
  }
}

variable "postgres_backup_blob_retention_days" {
  description = "Blob lifecycle retention for PostgreSQL base backups and WAL; longer than the 7-day PITR target for safety"
  type        = number
  default     = 9

  validation {
    condition     = var.postgres_backup_blob_retention_days >= 8 && var.postgres_backup_blob_retention_days <= 365
    error_message = "PostgreSQL backup storage retention must exceed the PITR recovery window (minimum 8 days)."
  }
}