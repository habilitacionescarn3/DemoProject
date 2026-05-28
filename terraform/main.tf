# Ressource groupe
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    devopslab = "true"
  }
}

# 2. VNET
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-devops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Front/Back subnet (Public-facing)
resource "azurerm_subnet" "web_subnet" {
  name                 = "sub-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet DB 
resource "azurerm_subnet" "db_subnet" {
  name                 = "sub-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3.NSG 
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-bootcamp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # En prod, on mettrait ton IP publique uniquement
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AppPort"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 4. Publique IP creation and NIC interface
resource "azurerm_public_ip" "web_pip" {
  count               = 2
  name                = "pip-web-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "web_nic" {
  count               = 2
  name                = "nic-web-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_pip[count.index].id
  }
}

# DB network interface 
resource "azurerm_network_interface" "db_nic" {
  name                = "nic-db"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
  }
}

# NSG and NIC 
resource "azurerm_network_interface_security_group_association" "web_assoc" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.web_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 5. VM (AlmaLinux 9)
resource "azurerm_linux_virtual_machine" "web_vm" {
  count               = 2
  name                = "vm-web-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2_v4" # Économique, parfait pour le bootcamp
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.web_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(file("${path.module}/labopenssh.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-base"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "db_vm" {
  name                = "vm-db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2_v4"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.db_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(file("${path.module}/labopenssh.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

   source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-base"
    version   = "latest"
  }
}