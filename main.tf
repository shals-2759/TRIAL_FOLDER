resource "azurerm_resource_group" "rg"{
  name = "storage_resource_group"
  location = "Central India"
}

resource "azurerm_virtual_network" "vn"{
  location =azurerm_resource_group.rg.location
  name = "storage_vnet"
  resource_group_name =azurerm_resource_group.rg.name
  address_space=["10.0.0.0/16"]
}

resource "azurerm_subnet" "sn"{
  name = "subnet1"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip"{
  name = "storage-public-ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
}

resource "azurerm_network_security_group" "nsg"{
  location = azurerm_resource_group.rg.location
  name = "storage-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  
  security_rule{
    name ="AllowSSH"
    priority = 100
    direction ="Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range ="*"
    destination_port_range="22"
    source_address_prefix="*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc"{
    subnet_id=azurerm_subnet.sn.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface" "nic"{
  //NIC is a component that allows a device to communicate on a network
  //The NIC owns the IP address of the VM, if a request comes from internet or a response goes to the internet it happens with the help of NIC
  name = "storage_nic"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.sn.id
    public_ip_address_id = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_linux_virtual_machine" "vm"{
  name = "storage-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_D2_v4"
  admin_username = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  admin_ssh_key {
    username="adminuser"
    public_key = file("/home/shalinir/.ssh/id_rsa.pub")
  }
  os_disk {
    //Without caching every Read/write goes to disk storage but using cache, frequently accessed data can be served from the cache, improving performance
    caching = "ReadWrite" 
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku ="server"
    version ="latest"
  }

}


resource "azurerm_storage_account" "sa"{
  name = "str2759acc2760"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false
#   network_rules {
#     default_action = "Deny"
#     ip_rules = [ "1.6.141.77" ]
#   }
}

resource "azurerm_private_endpoint" "pe" {
  name = "storage-private-endpoint"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = azurerm_subnet.sn.id

private_service_connection {
  name = "storage-connection"
  private_connection_resource_id = azurerm_storage_account.sa.id
  subresource_names = ["blob"]
  is_manual_connection = false
}
 private_dns_zone_group {
    name = "blob-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.pdns.id
    ]
  }
}

resource "azurerm_private_dns_zone" "pdns"{
    name="privatelink.blob.core.windows.net"
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link"{
    name = "blob-link"
    resource_group_name = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.pdns.name
    virtual_network_id = azurerm_virtual_network.vn.id
}



resource "azurerm_storage_container" "sc"{
  name = "storagecontainer01"
  container_access_type = "blob"
  storage_account_name = azurerm_storage_account.sa.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}