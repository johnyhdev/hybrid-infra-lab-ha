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

resource "azurerm_lb_probe" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name            = "http-health-probe"
  loadbalancer_id = azurerm_lb.workload[0].id

  protocol     = "Http"
  port         = 80
  request_path = "/"
}

resource "azurerm_lb_probe" "https" {
  count = var.enable_load_balancer ? 1 : 0

  name            = "https-health-probe"
  loadbalancer_id = azurerm_lb.workload[0].id

  protocol     = "Https"
  port         = 443
  request_path = "/"
}

resource "azurerm_lb_rule" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "http"
  loadbalancer_id                = azurerm_lb.workload[0].id
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.workload[0].id
  ]
  probe_id = azurerm_lb_probe.http[0].id

  protocol                = "Tcp"
  frontend_port           = 80
  backend_port            = 80
  idle_timeout_in_minutes = 4
  load_distribution       = "Default"
}

resource "azurerm_lb_rule" "https" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "https"
  loadbalancer_id                = azurerm_lb.workload[0].id
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.workload[0].id
  ]
  probe_id = azurerm_lb_probe.https[0].id

  protocol                = "Tcp"
  frontend_port           = 443
  backend_port            = 443
  idle_timeout_in_minutes = 4
  load_distribution       = "Default"
}
