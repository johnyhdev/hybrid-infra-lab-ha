resource "azurerm_lb" "workload" {
  count = var.enable_load_balancer ? 1 : 0

  name                = "lb-workload"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    role       = "workload"
    managed_by = "terraform"
  }
}

resource "azurerm_lb_backend_address_pool" "workload" {
  count = var.enable_load_balancer ? 1 : 0

  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.workload[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "workload" {
  for_each = var.enable_load_balancer ? var.workload_vms : {}

  network_interface_id    = azurerm_network_interface.workload[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.workload[0].id
}

resource "azurerm_lb_probe" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name            = "proxy-health-probe"
  loadbalancer_id = azurerm_lb.workload[0].id

  protocol     = "Http"
  port         = 8081
  request_path = "/healthz"
}

resource "azurerm_lb_rule" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "proxy-http"
  loadbalancer_id                = azurerm_lb.workload[0].id
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.workload[0].id
  ]
  probe_id = azurerm_lb_probe.http[0].id

  protocol                = "Tcp"
  frontend_port           = 8081
  backend_port            = 8081
  idle_timeout_in_minutes = 4
  load_distribution       = "Default"
}
