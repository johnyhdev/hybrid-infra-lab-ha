resource "azurerm_network_interface" "cm" {
  for_each = var.control_vms

  name                = "nic-${each.key}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.automation.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "internal_lab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Mark rendered cloud-init data as sensitive and encode it for Azure custom data.
resource "terraform_data" "cm_cloud_init" {
  for_each = var.control_vms

  input = sensitive(base64encode(
    templatefile("${path.module}/../../bootstrap/cm-cloud-init.yaml", {
      internal_private_key_b64 = base64encode(tls_private_key.internal_lab_key.private_key_pem)
      internal_public_key      = tls_private_key.internal_lab_key.public_key_openssh
      tailscale_cm_client_id   = var.tailscale_cm_client_id
      tailscale_cm_audience    = var.tailscale_cm_audience
      hostname                 = each.key
      workload_subnet_cidr     = azurerm_subnet.workload.address_prefixes[0]
    })
  ))
}

resource "azurerm_linux_virtual_machine" "cm" {
  for_each = var.control_vms

  name                = each.key
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  size = each.value.size
  zone = each.value.zone

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.cm[each.key].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Read the pre-encoded cloud-init data from terraform_data.
  custom_data = terraform_data.cm_cloud_init[each.key].output

  lifecycle {
    replace_triggered_by = [
      terraform_data.cm_cloud_init[each.key]
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server-arm64"
    version   = "latest"
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      data.azurerm_user_assigned_identity.cm.id
    ]
  }

  tags = {
    role        = "control-manager"
    environment = "lab"
    managed_by  = "terraform"
  }
}