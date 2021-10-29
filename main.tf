provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "user10-rg" {
    name     = "user10-rg"
    location = "koreacentral"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "user10-vnet" {
    name = "user10-vnet"
    address_space = ["40.0.0.0/16"]
    location = azurerm_resource_group.user10-rg.location
    resource_group_name = azurerm_resource_group.user10-rg.name
}

resource "azurerm_subnet" "user10-subnet1" {
    name = "user10-mysubnet1"
    resource_group_name = azurerm_resource_group.user10-rg.name
    virtual_network_name = azurerm_virtual_network.user10-vnet.name
    address_prefixes = ["40.0.1.0/24"]
}

resource "azurerm_public_ip" "user10-publicip" {  
name                = "user10publicip"  
location            = azurerm_resource_group.user10-rg.location  
resource_group_name = azurerm_resource_group.user10-rg.name  
allocation_method   = "Static"  
domain_name_label   = azurerm_resource_group.user10-rg.name  
	
	tags = {    
		environment = "staging"  
	}

}


resource "azurerm_lb" "user10-lb" {
  name = "user10lb"
  location = azurerm_resource_group.user10-rg.location
  resource_group_name = azurerm_resource_group.user10-rg.name
  frontend_ip_configuration {
  name = "user10PublicIPAddress"
  public_ip_address_id = azurerm_public_ip.user10-publicip.id
 }
}


resource "azurerm_lb_backend_address_pool" "user10-bepool" {
    loadbalancer_id = azurerm_lb.user10-lb.id
    name = "user10-BackEndAddressPool"
}


resource "azurerm_lb_probe" "user10-lb-probe" {
    resource_group_name = azurerm_resource_group.user10-rg.name
    loadbalancer_id = azurerm_lb.user10-lb.id
    name = "http-probe"
    protocol = "Http"
    request_path = "/"
    port = 80
}


resource "azurerm_lb_rule" "user10-lbrule" {
    resource_group_name = azurerm_resource_group.user10-rg.name
    loadbalancer_id = azurerm_lb.user10-lb.id
    name = "http"
    protocol = "Tcp"
    frontend_port = 80
    backend_port = 80
    backend_address_pool_id = azurerm_lb_backend_address_pool.user10-bepool.id
    frontend_ip_configuration_name = "user10PublicIPAddress"
    probe_id = azurerm_lb_probe.user10-lb-probe.id
}


resource "azurerm_network_security_group" "user10-nsg" {
    name                = "user10-nsg"
    location            = azurerm_resource_group.user10-rg.location
    resource_group_name = azurerm_resource_group.user10-rg.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "59.9.143.82/32"   ## Admin 서버 IP 주소 혹은 접속하는 서버(or PC) IP주소
        destination_address_prefix = "*"
    }
 security_rule {
        name                       = "HTTP"
        priority                   = 2001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}


resource "azurerm_lb_nat_rule" "user10-natrule1" {
  resource_group_name            = azurerm_resource_group.user10-rg.name
  loadbalancer_id                = azurerm_lb.user10-lb.id
  name                           = "web1SSH"
  protocol                       = "Tcp"
  frontend_port                  = 50001
  backend_port                   = 22
  frontend_ip_configuration_name = "user10PublicIPAddress"
}

resource "azurerm_lb_nat_rule" "user10-natrule2" {
  resource_group_name            = azurerm_resource_group.user10-rg.name
  loadbalancer_id                = azurerm_lb.user10-lb.id
  name                           = "web2SSH"
  protocol                       = "Tcp"
  frontend_port                  = 50002
  backend_port                   = 22
  frontend_ip_configuration_name = "user10PublicIPAddress"
}



resource "azurerm_network_interface" "user10-vm1-nic1" {
    name                = "user10-vm1-nic1"
    location = azurerm_resource_group.user10-rg.location
    resource_group_name = azurerm_resource_group.user10-rg.name

    ip_configuration {
        name                          = "myNicConfiguration1"
        subnet_id                     = azurerm_subnet.user10-subnet1.id
        private_ip_address_allocation = "Dynamic"
#        public_ip_address_id          = azurerm_public_ip.user10-publicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-association" {
  network_interface_id      = azurerm_network_interface.user10-vm1-nic1.id
  network_security_group_id = azurerm_network_security_group.user10-nsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backendPool" {
  network_interface_id    = azurerm_network_interface.user10-vm1-nic1.id
  ip_configuration_name   = "myNicConfiguration1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.user10-bepool.id 
}
resource "azurerm_network_interface_nat_rule_association" "natrule1" {
  network_interface_id  = azurerm_network_interface.user10-vm1-nic1.id
  ip_configuration_name = "myNicConfiguration1"
  nat_rule_id           = azurerm_lb_nat_rule.user10-natrule1.id
}




resource "azurerm_network_interface" "user10-vm2-nic1" {
    name                = "myNIC2"
    location = azurerm_resource_group.user10-rg.location
    resource_group_name = azurerm_resource_group.user10-rg.name

    ip_configuration {
        name                          = "myNicConfiguration2"
        subnet_id                     = azurerm_subnet.user10-subnet1.id
        private_ip_address_allocation = "Dynamic"
#        public_ip_address_id          = azurerm_public_ip.user10-publicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-association2" {
  network_interface_id      = azurerm_network_interface.user10-vm2-nic1.id
  network_security_group_id = azurerm_network_security_group.user10-nsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backendPool2" {
  network_interface_id    = azurerm_network_interface.user10-vm2-nic1.id
  ip_configuration_name   = "myNicConfiguration2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.user10-bepool.id 
}

resource "azurerm_network_interface_nat_rule_association" "natrule2" {
  network_interface_id  = azurerm_network_interface.user10-vm2-nic1.id
  ip_configuration_name = "myNicConfiguration2"
  nat_rule_id           = azurerm_lb_nat_rule.user10-natrule2.id
}


resource "azurerm_availability_set" "avset" {
 name                         = "avset"
 location                     = azurerm_resource_group.user10-rg.location
 resource_group_name          = azurerm_resource_group.user10-rg.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}


resource "azurerm_storage_account" "user10-diag-storage" {
    name                = "user10diagstorage"
    resource_group_name = azurerm_resource_group.user10-rg.name
    location = azurerm_resource_group.user10-rg.location
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags = {
        environment = "Terraform Demo"
    }
}




resource "azurerm_virtual_machine" "user10-web1" {
    name                  = "user10-web1"
    location              = azurerm_resource_group.user10-rg.location
    resource_group_name   = azurerm_resource_group.user10-rg.name
    availability_set_id   = azurerm_availability_set.avset.id
    delete_os_disk_on_termination    = true
    network_interface_ids = [azurerm_network_interface.user10-vm1-nic1.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }
    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

 os_profile {
        computer_name  = "user10-web1"
        admin_username = "azureuser"    ## 아래 34번 라인의 계정이름과 동일해야 함
        admin_password = "Pass****"     ## 12자리이상, 특수문자, 숫자, 대문자 조합으로 생성 필요
	custom_data= file("web.sh")     ## Terraform 실행하는 서버에 존재해야 함, 실행은 만들어지는 VM에서
    }

 os_profile_linux_config {
        disable_password_authentication = false
        ssh_keys {
	    ## ssh-keygen -t rsa -b 4096 -m PEM   명령어를 통해 Private Key(id_rsa)와 Public Key(id_rsa.pub)파일 생성
            ## 서버 접근을 위해 관리 서버에서 생성한 id_rsa.pub 파일을 가상서버로 복사
            path     = "/home/azureuser/.ssh/authorized_keys"   ## 가상 서버에 복사되는 위치
	    ## id_rsa.pub 파일 내용을 아래 key_data에 넣어줌 (무조건 한줄로!!!)
            key_data = file("~/.ssh/id_rsa.pub")
        }
    }
    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.user10-diag-storage.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}


resource "azurerm_virtual_machine" "user10-web2" {
    name                  = "user10-web2"
    location              = azurerm_resource_group.user10-rg.location
    resource_group_name   = azurerm_resource_group.user10-rg.name
    availability_set_id   = azurerm_availability_set.avset.id
    delete_os_disk_on_termination    = true
    network_interface_ids = [azurerm_network_interface.user10-vm2-nic1.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk2"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }
    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

 os_profile {
        computer_name  = "user10-web2"
        admin_username = "azureuser"
        admin_password = "Pass****"
	custom_data= file("web.sh")
    }

os_profile_linux_config {
        disable_password_authentication = false
        ssh_keys {
	    ## ssh-keygen -t rsa -b 4096 -m PEM   명령어를 통해 Private Key(id_rsa)와 Public Key(id_rsa.pub)파일 생성
            ## 서버 접근을 위해 관리 서버에서 생성한 id_rsa.pub 파일을 가상서버로 복사
            path     = "/home/azureuser/.ssh/authorized_keys"   ## 가상 서버에 복사되는 위치
	    ## id_rsa.pub 파일 내용을 아래 key_data에 넣어줌 (무조건 한줄로!!!)
            key_data = file("~/.ssh/id_rsa.pub")
        }
    }
    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.user10-diag-storage.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}
