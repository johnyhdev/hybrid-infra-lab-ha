resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  address_space = [
    "10.20.0.0/16"
  ]

  tags = {
    managed_by = "terraform"
  }
}

resource "azurerm_subnet" "automation" {
  name                 = var.automation_subnet_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    var.control_plane_subnet_cidr
  ]
}

resource "azurerm_subnet" "workload" {
  name                 = var.workload_subnet_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    var.workload_plane_subnet_cidr
  ]
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "link-${var.vnet_name}-keyvault"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "link-${var.vnet_name}-blob"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "loki_storage" {
  name                = "pep-${var.loki_storage_account_name}-blob"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.automation.id

  private_service_connection {
    name                           = "psc-${var.loki_storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.loki.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-zone"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob.id]
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pep-${var.key_vault_name}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.workload.id

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = data.azurerm_key_vault.workload_secrets.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "key-vault-zone"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "azurerm_network_security_group" "cm" {
  name                = "nsg-vm-cm-ha"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    managed_by = "terraform"
    role       = "control-manager"
  }
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-vm-workload-ha"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    managed_by = "terraform"
    role       = "workload"
  }
}

resource "azurerm_subnet_network_security_group_association" "cm" {
  subnet_id                 = azurerm_subnet.automation.id
  network_security_group_id = azurerm_network_security_group.cm.id
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_network_security_rule" "cm_deny_vnet_ssh" {
  name                        = "deny-direct-vnet-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_tailscale_udp" {
  name                        = "allow-tailscale-udp-from-vnet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "41641"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_node_exporter_from_control" {
  name                        = "allow-node-exporter-from-control"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9100"
  source_address_prefix       = var.control_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_storage_https_from_control" {
  name                        = "allow-private-storage-https-from-control"
  priority                    = 125
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.control_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_loki_from_vnet" {
  name                        = "allow-loki-from-vnet"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3100"
  source_address_prefix       = var.control_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_loki_from_workload" {
  name                        = "allow-loki-from-workload"
  priority                    = 141
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3100"
  source_address_prefix       = var.workload_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "cm_deny_other_vnet" {
  name                        = "deny-other-vnet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.cm.name
}

resource "azurerm_network_security_rule" "workload_deny_vnet_ssh" {
  name                        = "deny-direct-vnet-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_tailscale_udp" {
  name                        = "allow-tailscale-udp-from-vnet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "41641"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_proxy_from_workload" {
  name                        = "allow-proxy-backend-from-workload"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = var.workload_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_lb_probe" {
  count = var.enable_load_balancer ? 1 : 0

  name                        = "allow-azure-lb-probe"
  priority                    = 125
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8081"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_node_exporter_from_automation" {
  name                        = "allow-node-exporter-from-automation"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9100"
  source_address_prefix       = var.control_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_keyvault_https" {
  name                        = "allow-keyvault-private-https"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.workload_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_keyvault_https_from_control" {
  name                        = "allow-keyvault-private-https-from-control"
  priority                    = 141
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.control_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_postgresql_private" {
  name                        = "allow-postgresql-from-workload"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = var.workload_plane_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_security_rule" "workload_deny_other_vnet" {
  name                        = "deny-other-vnet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}
