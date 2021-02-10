# Create public ip
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "lb-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    main_tag = var.project_name
  }
}

# Create Standard load balancer
resource "azurerm_lb" "main" {
  name                = "udacity-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  tags = {
    main_tag = var.project_name
  }
}

# Create load balancer address pool
resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "BackEndAddressPool"
}

# Associate network interface to backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "main" {
  network_interface_id    = azurerm_network_interface.main[count.index].id
  count                   = var.machine_count
  ip_configuration_name   = "udacity"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# Create load balancer rule
# Map the requests received from the internet to the vms, from port to port
resource "azurerm_lb_rule" "main" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.main.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.main.id
  disable_outbound_snat          = true
}

# Create Outbound rule for load balancer 
resource "azurerm_lb_outbound_rule" "main" {
  resource_group_name     = azurerm_resource_group.main.name
  loadbalancer_id         = azurerm_lb.main.id
  name                    = "OutboundRule"
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id

  frontend_ip_configuration {
    name = "PublicIPAddress"
  }
}

# Create health probe to check if the app is healthy
resource "azurerm_lb_probe" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "http-check"
  port                = 80
  protocol            = "Http"
  request_path        = "/index.html"
  interval_in_seconds = 5
  number_of_probes    = 2
}