locals {
  workload_cloud_init_encoded = {
    for name, vm in var.workload_vms : name => base64encode(
      templatefile("${path.module}/../../bootstrap/workload-cloud-init-ha.yaml", {
        hostname                     = name
        tailscale_workload_client_id = var.tailscale_workload_client_id
        tailscale_workload_audience  = var.tailscale_workload_audience
        tailscale_package_version    = var.tailscale_package_version
      })
    )
  }
}

resource "azurerm_network_interface" "workload" {
  for_each = var.workload_vms

  depends_on = [terraform_data.topology_guard]

  name                           = "nic-${each.key}"
  location                       = data.azurerm_resource_group.main.location
  resource_group_name            = data.azurerm_resource_group.main.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Track cloud-init changes using SHA256 hash so plan output remains clean
resource "terraform_data" "workload_cloud_init" {
  for_each = var.workload_vms

  input = sha256(local.workload_cloud_init_encoded[each.key])
}

resource "azurerm_linux_virtual_machine" "workload" {
  for_each = var.workload_vms

  name                = each.key
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  size = each.value.size
  zone = each.value.zone

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.workload[each.key].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Read the Base64 cloud-init data directly from locals
  custom_data = local.workload_cloud_init_encoded[each.key]

  # Recreate the VM when cloud-init hash changes
  lifecycle {
    replace_triggered_by = [
      terraform_data.workload_cloud_init[each.key]
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = each.value.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server-arm64"
    version   = var.ubuntu_image_version
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      data.azurerm_user_assigned_identity.workload.id
    ]
  }

  tags = {
    role              = "workload"
    database          = each.value.database ? "primary" : "none"
    data_disk_size_gb = tostring(each.value.data_disk_size_gb)
    environment       = "lab"
    managed_by        = "terraform"
  }
}

resource "azurerm_managed_disk" "workload_data" {
  for_each = {
    for name, vm in var.workload_vms : name => vm
    if vm.data_disk_size_gb > 0
  }

  name                 = "disk-${each.key}-data"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = each.value.data_disk_size_gb
  zone                 = each.value.zone
}

resource "azurerm_virtual_machine_data_disk_attachment" "workload_data" {
  for_each = azurerm_managed_disk.workload_data

  managed_disk_id    = each.value.id
  virtual_machine_id = azurerm_linux_virtual_machine.workload[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}