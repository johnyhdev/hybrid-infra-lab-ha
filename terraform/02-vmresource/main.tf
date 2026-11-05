data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
# trigger VM build v3
data "azurerm_user_assigned_identity" "cm" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.main.name
}
