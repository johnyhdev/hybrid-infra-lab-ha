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

resource "azurerm_user_assigned_identity" "postgres_backup" {
  name                = "id-postgres-backup-ha"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    managed_by = "terraform"
    role       = "postgres-backup-writer"
  }
}

data "azurerm_key_vault" "workload_secrets" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# 1. Truy vấn thông tin Key bên trong Key Vault hiện có
data "azurerm_key_vault_key" "loki_encryption_key" {
  count        = var.enable_storage_cmk ? 1 : 0
  name         = var.storage_encryption_key_name # Tên Key trong Key Vault (ví dụ: "loki-storage-key")
  key_vault_id = data.azurerm_key_vault.workload_secrets.id
}

resource "azurerm_storage_account" "loki" {
  # checkov:skip=CKV_AZURE_206: "ZRS replication is sufficient for lab telemetry storage"
  # checkov:skip=CKV2_AZURE_21: "Blob logging managed at storage account diagnostic setting level"

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

  # 1. Bật System Assigned Identity cho Storage Account
  identity {
    type = "SystemAssigned"
  }

  tags = {
    managed_by = "terraform"
    role       = "loki-storage"
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

}

resource "azurerm_storage_account_queue_properties" "loki" {
  storage_account_id = azurerm_storage_account.loki.id

  logging {
    delete                = true
    read                  = true
    write                 = true
    version               = "1.0"
    retention_policy_days = 7
  }
}

# Đảm bảo phân quyền RBAC được áp dụng xong trước khi gán Customer Managed Key vào Storage Account
resource "azurerm_storage_account_customer_managed_key" "loki_cmk" {
  count              = var.enable_storage_cmk ? 1 : 0
  storage_account_id = azurerm_storage_account.loki.id
  key_vault_key_id   = data.azurerm_key_vault_key.loki_encryption_key[0].id

  depends_on = [
    azurerm_role_assignment.storage_cmk_encryption
  ]
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

  rule {
    name    = "delete-postgres-backups-after-retention-window"
    enabled = true

    filters {
      prefix_match = ["postgres-backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.postgres_backup_blob_retention_days
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

resource "azurerm_storage_container" "postgres_backups" {
  name                  = "postgres-backups"
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

resource "azurerm_role_assignment" "workload_postgres_backup_blob" {
  scope                = azurerm_storage_container.postgres_backups.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.postgres_backup.principal_id
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
      condition = length([for vm in values(var.workload_vms) : vm if vm.database_cluster_member]) == 3 && length(distinct([
        for vm in values(var.workload_vms) : vm.zone if vm.database_cluster_member
      ])) == 3
      error_message = "PostgreSQL HA requires exactly three cluster-member VMs distributed across three distinct zones."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "loki_blob_logging" {
  name               = "diag-loki-blob-service-critical"
  target_resource_id = "${azurerm_storage_account.loki.id}/blobServices/default"
  storage_account_id = azurerm_storage_account.loki.id

  # Chỉ ghi nhận các sự kiện ghi/xóa dữ liệu quan trọng, lược bỏ Read request để tiết kiệm dung lượng
  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  # Tắt hoàn toàn các metric không cần thiết để giảm thiểu chi phí transaction
}

# Cấp quyền cho Storage Account System-Assigned Identity được phép dùng Key trong Key Vault (do KV bật Azure RBAC)
resource "azurerm_role_assignment" "storage_cmk_encryption" {
  count                = var.enable_storage_cmk ? 1 : 0
  scope                = data.azurerm_key_vault.workload_secrets.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_storage_account.loki.identity[0].principal_id
}

