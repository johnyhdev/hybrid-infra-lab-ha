output "resource_group_name" {
  description = "Persistent resource group name"
  value       = azurerm_resource_group.main.name
}

output "tenant_id" {
  description = "Microsoft Entra tenant ID"
  value       = azurerm_user_assigned_identity.cm.tenant_id
}

output "cm_principal_id" {
  description = "Principal ID of id-cm"
  value       = azurerm_user_assigned_identity.cm.principal_id
}

output "cm_client_id" {
  description = "Client ID of id-cm"
  value       = azurerm_user_assigned_identity.cm.client_id
}

output "cm_identity_id" {
  description = "Resource ID of id-cm"
  value       = azurerm_user_assigned_identity.cm.id
}

output "workload_principal_id" {
  description = "Principal ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.principal_id
}

output "workload_client_id" {
  description = "Client ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "workload_identity_id" {
  description = "Resource ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.id
}

output "key_vault_name" {
  description = "Key Vault name; secret values are enrolled outside Terraform"
  value       = azurerm_key_vault.workload_secrets.name
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.workload_secrets.id
}
