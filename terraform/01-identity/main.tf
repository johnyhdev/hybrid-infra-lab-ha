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

resource "azurerm_user_assigned_identity" "workload" {
  name                = var.workload_managed_identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    managed_by = "terraform"
    role       = "workload"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "workload_secrets" {
  name                          = var.key_vault_name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30

  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }

  tags = {
    managed_by = "terraform"
    role       = "workload-secrets"
  }
}

resource "azurerm_role_assignment" "workload_keyvault_secret_reader" {
  scope                = azurerm_key_vault.workload_secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}