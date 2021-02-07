# Create security group to secure network connections
resource "azurerm_network_security_group" "security_group" {
  name                = "UdacityCourseSecurityGroup"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.main.name

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
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    main_tag = "Terraform Udacity"
  }
}