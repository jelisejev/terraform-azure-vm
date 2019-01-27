resource "azurerm_resource_group" "vm" {
  location = "westeurope"
  name = "${var-name}"
}

resource "azurerm_public_ip" "vm" {
  name                         = "${var.name}-pip"
  location                     = "${azurerm_resource_group.vm.location}"
  resource_group_name          = "${azurerm_resource_group.vm.name}"
  public_ip_address_allocation = "Dynamic"
}

resource "azurerm_virtual_network" "vm" {
  name                = "${var.name}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.vm.location}"
  resource_group_name = "${azurerm_resource_group.vm.name}"
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.name}-subnet"
  resource_group_name  = "${azurerm_resource_group.vm.name}"
  virtual_network_name = "${azurerm_virtual_network.vm.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "http" {
  name                = "HTTP"
  resource_group_name = "${azurerm_resource_group.vm.name}"
  location = "${azurerm_resource_group.vm.location}"

  security_rule {
    name = "HTTPS"
    protocol = "TCP"
    source_port_range = "*"
    source_address_prefix = "*"
    destination_port_range = "443"
    destination_address_prefix = "*"
    access = "Allow"
    direction = "Inbound"
    priority = 1000
  }

  # reuired to perform SSL certificate verification
  security_rule {
    name = "HTTP"
    protocol = "TCP"
    source_port_range = "*"
    source_address_prefix = "*"
    destination_port_range = "80"
    destination_address_prefix = "*"
    access = "Allow"
    direction = "Inbound"
    priority = 1100
  }

  security_rule {
    name = "SSH"
    protocol = "*"
    source_port_range = "*"
    source_address_prefix = "*"
    destination_port_range = "22"
    destination_address_prefix = "*"
    access = "Allow"
    direction = "Inbound"
    priority = 500
  }

  // allow all outbound connections
  security_rule {
    name = "Outbound"
    protocol = "*"
    source_port_range = "*"
    source_address_prefix = "*"
    destination_port_range = "*"
    destination_address_prefix = "*"
    access = "Allow"
    direction = "Outbound"
    priority = 500
  }
}

resource "azurerm_network_interface" "main" {
  name                = "${var.name}-nic"
  location            = "${azurerm_resource_group.vm.location}"
  resource_group_name = "${azurerm_resource_group.vm.name}"

  network_security_group_id = "${azurerm_network_security_group.http.id}"

  ip_configuration {
    name                          = "network"
    subnet_id                     = "${azurerm_subnet.vm_subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.vm.id}"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.name}"
  location              = "${azurerm_resource_group.vm.location}"
  resource_group_name   = "${azurerm_resource_group.vm.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  delete_data_disks_on_termination = true
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "${var.name}-disk"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "${var.name}"
    admin_username = "testadmin"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = "${file(var.public_key_file)}"
      path = "/home/testadmin/.ssh/authorized_keys"
    }
  }
}

output "public_ip" {
  value = "${azurerm_public_ip.vm.ip_address}"
}
