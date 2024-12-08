terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  
  features {}
  #resource_provider_registrations = true
  skip_provider_registration = true
  subscription_id = "7df4a5e8-ff7d-4c10-91e7-78a62c0dc549"
  client_id       = "18957ccb-d73a-446b-a63c-ff0210e6dbeb"
  client_secret   = "q.EzQFoI64LlAZBgQz2JhUr1O.k0G10G5y"
  tenant_id       = "d1ab8a17-ac40-4620-ad1b-d81b08e2ffb6"
}

resource "azurerm_resource_group" "dev-MyApp-we-rg" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_virtual_network" "dev-MyApp-we-vn" {
  name                = var.vn_name
  resource_group_name = azurerm_resource_group.dev-MyApp-we-rg.name
  location            = azurerm_resource_group.dev-MyApp-we-rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "dev-MyApp-we-sn" {
  name                 = var.sn_name
  resource_group_name  = azurerm_resource_group.dev-MyApp-we-rg.name
  virtual_network_name = azurerm_virtual_network.dev-MyApp-we-vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "dev-MyApp-we-ip" {
  name                = var.ip_name
  resource_group_name = azurerm_resource_group.dev-MyApp-we-rg.name
  location            = azurerm_resource_group.dev-MyApp-we-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "dev-MyApp-we-nic" {
  name                = var.nic_name
  location            = azurerm_resource_group.dev-MyApp-we-rg.location
  resource_group_name = azurerm_resource_group.dev-MyApp-we-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev-MyApp-we-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev-MyApp-we-ip.id
  }
}

resource "azurerm_network_security_group" "dev-MyApp-we-nsg" {
  name                = var.nsg_name
  location            = azurerm_resource_group.dev-MyApp-we-rg.location
  resource_group_name = azurerm_resource_group.dev-MyApp-we-rg.name

  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev-MyApp-we-nsga" {
  subnet_id                 = azurerm_subnet.dev-MyApp-we-sn.id
  network_security_group_id = azurerm_network_security_group.dev-MyApp-we-nsg.id
}

resource "azurerm_linux_virtual_machine" "dev-MyApp-we-vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.dev-MyApp-we-rg.name
  location            = azurerm_resource_group.dev-MyApp-we-rg.location
  size                = "Standard_A1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.dev-MyApp-we-nic.id,
  ]

  custom_data = filebase64("nginx.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "vm_public_ip" {
  value = azurerm_public_ip.dev-MyApp-we-ip.ip_address
}
