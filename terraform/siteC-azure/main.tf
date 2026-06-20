# ============================================================================
# Site C — Azure (extension hybride cloud du projet CIA)
# ----------------------------------------------------------------------------
# Provisionne Resource Group + VNet + Subnet + NSG + Public IP + Linux VM
# Ubuntu 22.04 (Standard_B2s) avec cloud-init pré-installant Docker.
# Cette VM hébergera NetBox + Elastic stack + bastion + OpenVPN server
# (config Ansible appliquée après ce `terraform apply`).
# ============================================================================

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-siteC-rg"
  location = var.location

  tags = {
    project = "CIA"
    site    = "C-azure"
    group   = "GR46"
    managed = "terraform"
  }
}

# --- Réseau ----------------------------------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-siteC-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_public" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# --- Network Security Group (firewall as code) -----------------------------

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-siteC-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    description                = "SSH bastion management (clé cia_gr46 uniquement)"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-openvpn"
    description                = "OpenVPN server pour tunnel inter-sites (Site B client → Site C)"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    description                = "HTTPS pour NetBox UI (via Caddy reverse proxy)"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-kibana"
    description                = "Kibana UI pour démo observabilité jury"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5601"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- IP publique statique --------------------------------------------------

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-siteC-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- Interface réseau ------------------------------------------------------

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-siteC-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# --- Linux VM Ubuntu 22.04 -------------------------------------------------

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.prefix}-siteC-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "${var.prefix}-siteC-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init.yaml"))

  tags = {
    project = "CIA"
    site    = "C-azure"
    group   = "GR46"
    role    = "netbox+elastic+bastion+vpn-server"
  }
}
