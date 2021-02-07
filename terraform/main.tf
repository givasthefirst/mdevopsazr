# Create resource group to deploy all resources
resource "azurerm_resource_group" "main" {
  name     = "udacity-resources"
  location = var.location
  tags = {
    main_tag = "terraformed-udacity-nic"
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
    main_tag = "terraformed-udacity-nic"
  }
}

# Create availability set to best allocate vms in differents domains 
resource "azurerm_availability_set" "main" {
  name                = "udacity-aset"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    main_tag = "udacity"
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
  size                            = "Standard_B1s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  count                           = var.machine_count
  network_interface_ids           = [azurerm_network_interface.main[count.index].id]
  availability_set_id             = azurerm_availability_set.main.id
  source_image_id                 = data.azurerm_image.main.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    main_tag = "terraformed-udacity-vm"
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
    main_tag = "terraformed-udacity-disk"
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