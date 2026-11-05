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
