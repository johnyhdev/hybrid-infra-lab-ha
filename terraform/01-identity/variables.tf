variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

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
