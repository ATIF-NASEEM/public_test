# 1. Provider Configuration
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

# 2. Resource Group
resource "azurerm_resource_group" "poc-rg" {
  name     = "kv-vm-test-rg"
  location = "East US"
}

# 3. Networking
resource "azurerm_virtual_network" "poc-vn" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.poc-rg.location
  resource_group_name = azurerm_resource_group.poc-rg.name
}

resource "azurerm_subnet" "pov-vm-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.poc-rg.name
  virtual_network_name = azurerm_virtual_network.poc-vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.poc-rg.location
  resource_group_name = azurerm_resource_group.poc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pov-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 4. Key Vault
resource "azurerm_key_vault" "poc-kv" {
  name                        = "test-kv-${random_id.id.hex}" # Must be unique
  location                    = azurerm_resource_group.poc-rg.location
  resource_group_name         = azurerm_resource_group.poc-rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  # Grant current user (you) access to manage the KV
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }
}

resource "random_id" "id" { byte_length = 4 }

# 5. Create a test secret to retrieve later
resource "azurerm_key_vault_secret" "kv-secret" {
  name         = "TestSecret"
  value        = "ConnectivitySuccessful!"
  key_vault_id = azurerm_key_vault.poc-kv.id
}

# 6. Virtual Machine with Managed Identity
resource "azurerm_linux_virtual_machine" "pov-mv" {
  name                = "example-vm"
  resource_group_name = azurerm_resource_group.poc-rg.name
  location            = azurerm_resource_group.poc-rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.example.id]

  # SSH Key (ensure you have one locally or use a password)
  admin_ssh_key {
    username   = "azureuser"
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

  # IMPORTANT: Enable Managed Identity
  identity {
    type = "SystemAssigned"
  }
}
