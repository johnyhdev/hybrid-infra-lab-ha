variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

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

variable "workload_managed_identity_name" {
  description = "Managed identity used by workload VMs for Tailscale WIF and approved Key Vault access"
  type        = string
  default     = "id-workload-ha"
}

variable "key_vault_name" {
  description = "Globally unique Azure Key Vault name for the Cloudflare API Token secret"
  type        = string
  default     = "kvhybridinfra26111010"

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9-]{1,22}[A-Za-z0-9]$", var.key_vault_name)) &&
      !strcontains(var.key_vault_name, "--")
    )
    error_message = "key_vault_name must be 3-24 characters, start with a letter, end with a letter or digit, and contain no consecutive hyphens."
  }
}
