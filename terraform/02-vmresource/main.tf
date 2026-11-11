data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
# trigger VM build v3
data "azurerm_user_assigned_identity" "cm" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.main.name
}

data "azurerm_user_assigned_identity" "workload" {
  name                = var.workload_managed_identity_name
  resource_group_name = data.azurerm_resource_group.main.name
}

data "azurerm_key_vault" "workload_secrets" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_storage_account" "loki" {
  name                            = var.loki_storage_account_name
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  tags = {
    managed_by = "terraform"
    role       = "loki-storage"
  }
}

resource "azurerm_storage_management_policy" "loki_cleanup" {
  storage_account_id = azurerm_storage_account.loki.id

  rule {
    name    = "delete-logs-older-than-7-days"
    enabled = true

    filters {
      prefix_match = ["loki/"] # Áp dụng cho các file nằm trong container loki
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}

resource "azurerm_storage_container" "loki" {
  name                  = "loki"
  storage_account_id    = azurerm_storage_account.loki.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "recovery" {
  name                  = "recovery-state"
  storage_account_id    = azurerm_storage_account.loki.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "cm_loki_blob" {
  scope                = azurerm_storage_container.loki.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.cm.principal_id
}

resource "azurerm_role_assignment" "cm_recovery_blob" {
  scope                = azurerm_storage_container.recovery.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.cm.principal_id
}

resource "terraform_data" "topology_guard" {
  input = {
    control_count  = length(var.control_vms)
    workload_count = length(var.workload_vms)
    ha_mode        = var.ha_mode
  }

  lifecycle {
    precondition {
      condition = !var.ha_mode || (
        length(var.control_vms) >= 2 &&
        length(var.workload_vms) >= 2 &&
        length(distinct([for vm in values(var.control_vms) : vm.zone])) >= 2 &&
        length(distinct([for vm in values(var.workload_vms) : vm.zone])) >= 2
      )
      error_message = "HA mode requires at least two CM and two workload VMs distributed across at least two distinct zones per plane. Set ha_mode=false only for an explicitly non-HA lab."
    }

    precondition {
      condition     = length(var.workload_vms) <= 250
      error_message = "The workload design limit is 250 nodes; confirm Azure quotas, subnet capacity, Tunnel Pool limits, and cost before increasing this limit."
    }

    precondition {
      condition     = length([for vm in values(var.workload_vms) : vm if vm.database]) == 1
      error_message = "Exactly one workload VM must be designated as the single PostgreSQL host."
    }
  }
}
