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
  default     = "24.04.202509120" # Example: "24.04.202509120"

  validation {
    condition     = can(regex("^24[.]04[.][0-9]+$", var.ubuntu_image_version))
    error_message = "Provide an exact Ubuntu ARM64 image version; latest is not accepted."
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
      os_disk_size_gb   = 64
      data_disk_size_gb = 0
    }
    "vm-cm-02" = {
      size              = "Standard_D2ps_v6"
      zone              = "2"
      os_disk_size_gb   = 64
      data_disk_size_gb = 0
    }
  }

  validation {
    condition     = length(var.control_vms) >= 1
    error_message = "At least one control-manager VM is required; set ha_mode=false for a single-node non-HA lab."
  }
}

variable "ha_mode" {
  description = "When true, require at least two control and two workload VMs in distinct zones"
  type        = bool
  default     = true
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
  description = "Workload VM definitions; scalable by map, with a design target up to 250 nodes"

  type = map(object({
    size              = string
    zone              = string
    os_disk_size_gb   = number
    data_disk_size_gb = number
    database          = bool
  }))

  default = {
    "vm-workload-01" = {
      size              = "Standard_D2ps_v6"
      zone              = "1"
      os_disk_size_gb   = 64
      data_disk_size_gb = 0
      database          = true
    }
    "vm-workload-02" = {
      size              = "Standard_D2ps_v6"
      zone              = "2"
      os_disk_size_gb   = 64
      data_disk_size_gb = 0
      database          = false
    }
  }

  validation {
    condition     = length(var.workload_vms) >= 1 && length(var.workload_vms) <= 250
    error_message = "workload_vms must contain between 1 and 250 nodes; this is a provisioning limit, not autoscaling."
  }

  validation {
    condition     = length([for vm in values(var.workload_vms) : vm if vm.database]) == 1
    error_message = "Exactly one workload VM must be designated as the single PostgreSQL host."
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