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
    "10.20.1.0/24"
  ]
}

resource "azurerm_subnet" "workload" {
  name                 = var.workload_subnet_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    "10.20.2.0/24"
  ]
}

resource "azurerm_network_security_group" "cm" {
  name                = "nsg-vm-cm"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    managed_by = "terraform"
    role       = "control-manager"
  }
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-vm-workload"
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

resource "azurerm_network_security_rule" "workload_ssh_from_automation" {
  name                        = "allow-ssh-from-automation"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

# Allow HTTP (Port 80) from Automation Subnet to Workload Subnet
resource "azurerm_network_security_rule" "workload_http_from_automation" {
  name                        = "allow-http-from-automation"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

# Allow Node Exporter Metrics (Port 9100) from Automation Subnet (Prometheus/Vault)
resource "azurerm_network_security_rule" "workload_node_exporter_from_automation" {
  name                        = "allow-node-exporter-from-automation"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9100"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

