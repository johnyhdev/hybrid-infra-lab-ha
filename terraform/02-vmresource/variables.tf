variable "resource_group_name" {
  description = "Persistent lab resource group"
  type        = string
  default     = "rg-hybrid-infra-lab"
}

variable "managed_identity_name" {
  description = "Control Manager managed identity"
  type        = string
  default     = "id-cm"
}

variable "vnet_name" {
  description = "Main virtual network"
  type        = string
  default     = "vnet-hybrid-infra"
}

variable "automation_subnet_name" {
  description = "Control Manager subnet"
  type        = string
  default     = "snet-automation"
}

variable "workload_subnet_name" {
  description = "Workload subnet"
  type        = string
  default     = "snet-workload"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
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
  description = "Control Manager VM definitions"

  type = map(object({
    size = string
    zone = string
  }))

  default = {
    "vm-cm-01" = {
      size = "Standard_D2ps_v6"
      zone = "1"
    }
  }
}

variable "tailscale_cm_client_id" {
  description = "Tailscale WIF client ID for CM VMs"
  type        = string

  validation {
    condition     = length(trimspace(var.tailscale_cm_client_id)) > 0
    error_message = "Set tailscale_cm_client_id to the client ID created for the Azure control-manager WIF credential."
  }
}

variable "tailscale_cm_audience" {
  description = "Tailscale WIF audience for CM VMs"
  type        = string

  validation {
    condition     = length(trimspace(var.tailscale_cm_audience)) > 0
    error_message = "Set tailscale_cm_audience to the audience configured for the Azure control-manager WIF credential."
  }
}

variable "workload_vms" {
  description = "Workload VM definitions"

  type = map(object({
    size = string
    zone = string
  }))

  default = {
    "vm-workload-01" = {
      size = "Standard_D2ps_v6"
      zone = "1"
    }
  }
}

variable "enable_load_balancer" {
  description = "Enable Azure Load Balancer for workload VMs"
  type        = bool
  default     = false
}