resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    managed_by = "terraform"
    role       = "lab-foundation"
  }
}

resource "azurerm_user_assigned_identity" "cm" {
  name                = var.managed_identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    managed_by = "terraform"
    role       = "control-manager"
  }
}

resource "azurerm_role_assignment" "cm_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.cm.principal_id
}