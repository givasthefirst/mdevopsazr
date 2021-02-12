provider "azurerm" {
  features {}
}

# Create resource group to deploy all resources
resource "azurerm_resource_group" "main" {
  name     = "udacity-resources"
  location = var.location
  tags = {
    main_tag = var.project_name
  }

}

# Create virtual network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/24"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

# Create subnet 
resource "azurerm_subnet" "main" {
  name                 = "main"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Create network interface(s) basedon the amount of machine_count 
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-${count.index}-nic"
  count               = var.machine_count
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location


  ip_configuration {
    name                          = "udacity"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    main_tag = var.project_name
  }
}

# Create availability set to best allocate vms in differents domains 
resource "azurerm_availability_set" "main" {
  name                = "udacity-aset"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    main_tag = var.project_name
  }
}

# Connect the security group to the network interface(s)
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main[count.index].id
  count                     = var.machine_count
  network_security_group_id = azurerm_network_security_group.security_group.id
}

# Get image previously built by packer
data "azurerm_image" "main" {
  name                = "PackerUdacityImage"
  resource_group_name = "packer-rg"
}

# Create virtual machine(s) using vm created previously by packer
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm-${count.index}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  count                           = var.machine_count
  size                            = "Standard_B1s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.main[count.index].id]
  availability_set_id             = azurerm_availability_set.main.id
  source_image_id                 = data.azurerm_image.main.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    main_tag = var.project_name
  }

}

# Create managed disk(s) to have a place to persist data
resource "azurerm_managed_disk" "main" {
  name                 = "${azurerm_linux_virtual_machine.main[count.index].name}-disk"
  count                = var.machine_count
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10

  tags = {
    main_tag = var.project_name
  }
}

# Attach disk to machine_count
resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  managed_disk_id    = azurerm_managed_disk.main[count.index].id
  count              = var.machine_count
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

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

# Create security group to secure network connections
resource "azurerm_network_security_group" "security_group" {
  name                = "UdacityCourseSecurityGroup"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.main.name

  # Deny traffic to/from the internet
  security_rule {
    name                       = "DenyAccessFromTheInternet"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow traffic within the network
  security_rule {
    name                       = "AllowAccessFromTheSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow access to the port 80, load balancer and machines are sharing same public ip
  # makint this rule necessary to access the web page
  security_rule {
    name                       = "AllowAccessFromTheInternetInPort80"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    main_tag = var.project_name
  }
}