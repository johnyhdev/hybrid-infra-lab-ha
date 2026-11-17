mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "rg-test"
      location = "centralindia"
    }
  }
  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test"
    }
  }
  mock_data "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-vault"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/backup"
    }
  }
}

variables {
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEbOI6JFAgZvfzqLXOSApETAMZ23ldPhwUv7xYkG/ZXc"
  workload_vms = {
    db1 = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = true }
    db2 = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = true }
    db3 = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = true }
  }
}

run "three_members_in_one_zone" {
  command = plan

  assert {
    condition     = length(azurerm_linux_virtual_machine.workload) == 3
    error_message = "Three DB workload VMs must be planned even in one zone."
  }

  assert {
    condition     = can(yamldecode(base64decode(local.control_cloud_init_encoded["vm-cm-01"])).runcmd[0])
    error_message = "Control cloud-init runcmd must be a command list."
  }

  assert {
    condition     = azurerm_storage_account.loki.shared_access_key_enabled == false && azurerm_storage_account.loki.network_rules[0].default_action == "Deny"
    error_message = "Storage must disable Shared Key and deny unmatched network traffic."
  }

  assert {
    condition     = contains(azurerm_subnet.automation.service_endpoints, "Microsoft.Storage") && contains(azurerm_subnet.workload.service_endpoints, "Microsoft.Storage") && !contains(azurerm_subnet.workload.service_endpoints, "Microsoft.KeyVault")
    error_message = "Both subnets need Storage service endpoints; Key Vault uses Private Link."
  }

  assert {
    condition     = azurerm_private_endpoint.key_vault.private_service_connection[0].private_connection_resource_id == data.azurerm_key_vault.workload_secrets.id && contains(azurerm_private_endpoint.key_vault.private_service_connection[0].subresource_names, "vault")
    error_message = "The private endpoint must target the existing Key Vault."
  }
}

run "reject_two_database_members" {
  command = plan

  variables {
    workload_vms = {
      db1 = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = true }
      db2 = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = true }
      app = { size = "Standard_D2ps_v6", zone = "1", os_disk_size_gb = 64, database_cluster_member = false }
    }
  }

  expect_failures = [var.workload_vms]
}