# Declaring the local variables
locals  {
    storageAccountName          = lower(join("", ["sawinvm", random_string.asaname-01.result]))
    nicName                     = "myVMNic"
    addressPrefix               = "10.0.0.0/16"
    subnetName                  = "Subnet"
    subnetPrefix                = "10.0.0.0/24"
    publicIPAddressName         = "myPublicIP"
    vmName                      = "SimpleWinVM"
    virtualNetworkName          = "MyVNET"
    networkSecurityGroupName    = "default-NSG"
    osDiskName                  = join("",[local.vmName, "_OsDisk_1_", lower(random_string.avmosd-01.result)])
}

# Generating the random string to create a unique storage account
resource "random_string" "asaname-01" {
    length  = 16
    special = "false"
}

# Generating the random string to create a unique os disk 
resource "random_string" "avmosd-01" {
    length  = 32
    special = "false"
}

# Resource Group
resource "azurerm_resource_group" "arg-01" {
    name        = var.resourceGroupName
    location    = var.location
}

# Storage Account
resource "azurerm_storage_account" "asa-01" {
    name                        = local.storageAccountName
    resource_group_name         = azurerm_resource_group.arg-01.name
    location                    = azurerm_resource_group.arg-01.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"
}

# Public IP
resource "azurerm_public_ip" "apip-01" {
    name                = local.publicIPAddressName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    allocation_method   = "Dynamic"
    domain_name_label   = var.dnsLabelPrefix
}

# Network Security Group with allow RDP rule 
resource "azurerm_network_security_group" "ansg-01" {
    name                = local.networkSecurityGroupName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    security_rule {
        name                        = "default-allow-3389"
        priority                    = 1000
        access                      = "Allow"
        direction                   = "Inbound"
        destination_port_range      = 3389
        protocol                    = "Tcp"
        source_port_range           = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }
}

# Virtual Network
resource "azurerm_virtual_network" "avn-01" {
    name                = local.virtualNetworkName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    address_space       = [local.addressPrefix]
}

# Subnet
resource "azurerm_subnet" "as-01" {
    name                  = local.subnetName
    resource_group_name   = azurerm_resource_group.arg-01.name
    virtual_network_name  = azurerm_virtual_network.avn-01.name
    address_prefix        = local.subnetPrefix
}

# Associate the subnet with NSG
resource "azurerm_subnet_network_security_group_association" "asnsga-01" {
    subnet_id                   = azurerm_subnet.as-01.id
    network_security_group_id   = azurerm_network_security_group.ansg-01.id
}

# Network Interface Card
resource "azurerm_network_interface" "anic-01" {
    name                = local.nicName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    ip_configuration {
        name                            = "ipconfig1"
        private_ip_address_allocation   = "Dynamic"
        public_ip_address_id            = azurerm_public_ip.apip-01.id
        subnet_id                       = azurerm_subnet.as-01.id
    }
}

# Virtual Machine
resource "azurerm_virtual_machine" "avm-01" {
    name                    = local.vmName
    resource_group_name     = azurerm_resource_group.arg-01.name
    location                = azurerm_resource_group.arg-01.location
    vm_size                 = var.vmSize
    network_interface_ids   = [azurerm_network_interface.anic-01.id]
    os_profile {
        computer_name   = local.vmName
        admin_username  = var.adminUsername
        admin_password  = var.adminPassword
    }
    storage_image_reference {
        publisher   = "MicrosoftWindowsDesktop"
        offer       = "Windows-10"
        sku         = var.windowsOSVersion
        version     = "latest"
    }
    storage_os_disk {
        name            = local.osDiskName
        create_option   = "FromImage"
    }
    storage_data_disk {
        name            = "Data"
        disk_size_gb    = 1023
        lun             = 0
        create_option   = "Empty"
    }
    os_profile_windows_config {
        provision_vm_agent  = true
    }
    boot_diagnostics {
        enabled     = true
        storage_uri = azurerm_storage_account.asa-01.primary_blob_endpoint
    }
	provisioner "local-exec" {
    command = <<EOH
	$credentials = Get-Credential 
    Invoke-WebRequest -Uri data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAOsAAAB5CAMAAADveiavAAAA+VBMVEX///8hqdQPLD8Ao9EAoNAirNgAIDYAACMVp9MAns8AJjoAHjUAJDkAGjIAGDEPKj3w+PsAAB8AACYAEy68vMDi8fih1OkAABz4/P4ADSsAABkAAAC+4O8OIzbx8vPo6uuPzOXM5/LKzM5futwgo8pCsdgAABPX2tyu2esdlLMZepPX7PUbhKNzwN8UV2Yem74RP1EXboMUU2kSSFZ5gYmaoKZYWWSnrLGHj5YQNkoSS1INEScVXnIYdYZAQlBlbngpPEwNHCkyNkVWY25FU2AMMDoQOjobiJ8VZnMkuukJEhcNESAAISsfpcIdj7UQPUQNJyQmKDtgjp2mkHJaAAAWiklEQVR4nO1cZ2OizNoWcBQr9mAiVoyCCGJ3w6qJ5miefZKcff//j3ln6GUwlt3zKfeH3cQIw8Xdy0wk8k3f9E3f9E3f9E3f9L+mer3R6PXaOvV6jUad/ftrsrlc2aZc7n+wYqTeKy2Wm/02lb+/0+kxn9zulotS768tyZZb/Upz2Ol2CQoRTXQ7nWGzXxvk/tqakUhjsZmvk9ViKp1mSJuYZCpbTa7ny78Bt9yHIAFCCInQidaJoiDkYaX8F9aEDJ3G7ouxZJLEUzKZyReWvfqfW5Et14ZU1AXSTzRBU1F6+KfZ257t74thMB0OV+O7RePPrFiuDOloCEgPUdFOZfBn1kS0mDPVNA5b8KNYcb/8A3ajNuxSYewM8pcihn8GbWN2X01jUEEaYYU5k1/exttcn8YA5b2/Ag9aOtq5HW1jSRZCBJZbCRMGx1uyysyu19tyhcDILg00AQIEAKFE/wg+7DTVvNFOzdbVoJZyT08MyU3U0WHC/Xr9hUGbLO5L1y3INrsURkwhSFEChCgLgBcUAf6qKQFJ7tZuQNrO+uwRwyElVQVhzMnKUVBGK0FQxhyGten7zRWszfXxWgqET/mHCjSJl5WP/2jqD4LXeKBz2U3R4bWsbUwDPGU0UVyp0qsmrITxEyOMRPFZFvDKXFxfzNpaN4HHysv8myTT8uEwFj808KYelCPBi6riA0t1r9Pa9roYEN7xYTzmoOQ+H8aQtcxhJYiidFhhsZKxzPLCJWF8BCMHKpGI6m7VwQCRAf4HIQsKT0gilGfxQwUTUYAi7UVLg6vkeJMJKqoEAT6JIjeSRpowUZWRqDIrrHnSqTq/LpQqD2ooKHTz9YMQn4GoCkde/BQ+JvxPSdDeAOTxJ+8xyXS0fw3WoEflRPH+WR0Jh4PKcKqkTUakKB4moVjJzEv73OUG/VprUPaEQF2bs0DRVOkA1VZUgCqpmgCOiiC/AQlyFwDJY5ITF3K2BO3KPIiVGQmScOBW4xE0R9wzxzEMM1rhTBNj4o+RZyptrotiej2or/RbOmbWwQpZp7MPWaOfCjB+lVXxUwGTN1H2ijFxic6yu109Up9jQkLmWZ5wDhL9I8y3Xl5eSCaWLRazqezd7DyoNIoICDOsp6hEK1ImsIGTraGQy1CLJ6LmU9lL7FNjdzetRxp7bPjLhQusTS8oty0tZrPZdLrZvZzBWbbjd6rRcmSAQ+pFzfPv/4g+W0x3z3c89X0qM2XDsJ5ByRfXzVBW/zXUZiB+SOQira+wQvssT6TAh1146XkhOZtJkUXoLHrrq7Guz36vJgWhElQuUvsaK/DFxTp12EhzeM6yjX0KhgFQx3rbM6QVj3UP77OYlUqldq/ROOMNV6KB56WJXKR/bp7ju7QTiQwTla+XrW8gVB1r+xTWZDJWrBbihWoWk7zHdkgR8lUYX273881mM13OTskxDhMNBbHi+twyWUYN5mS2h7B2aKr1JdapntToWMNChGQmw6zXm+UCMm6x3K1fmEzK89XMFGLdolfAJJPpdCwWy2SL4QaqhntyGgmiU3MhUL2l2e/3a6jy1O0SJ+DSQ8Mzf2WNS4/G0y7gj3h1zcS301nbnZ82SrMNU3B9uwrfVJ30Xp6OhXG2hX1qemhhpaPdYbNW9qgCW641IetCsDYjEVSeGZ7Wnt7WeMIYwprCsLT6sCn1gveo9xbkvR16FODVdX/SG1vj8/dBF8sgCytE2i9jHzo3aFJBPUeXQlVFf6BOqmx9Z4bADJS4RYHxCXEstV6G52mledp8O3kYF9YfzTvZV6fmOLAhUAmqGWGHUHhPVhvYCk6UKRgQJ9AP0VN+dha3HhA+7YJJVuN5aH5g8BNLMyRT3S1OZ6SlXVWH9gjFtWFg5UYrG21xHrw8FwIVMSU3jHa+Cm3LzSBYqmZiRTofRnUTKslsEWf0wj6MfpbTzX4be4h/XSCsL+4Qax/hF9v3OtSVID/ZYKubwBWBcMnFnFy3coa/GgTUFlrgXMKQ5vBXtUm5sV5FUAsY8hH+0L4zoEqStLJrUkVfPssOw6Ai5uTOC/VyHZow42iDUHRpYu2GVY7bjn5uZ2af5mKw7KKYjMP/S3EE9V389SSqHGPVG4vePAATLll0giUBsDXkiJrNIaROp9uFEVcramsC/imnWduOMDFmu13v5zAQmE6Xi8UlbC4VmAiybDABVH5qGU5UnzTBum914fpm5QRU4utQAAMB9bcG0JrVLANN4b/Yy7ttLqOHATAOSKVSBawFDaU2DJsiyyLJjOWVMFGFV00ZWRLDZJ2Y4gRU6HIu6VuwqHEHiWVNBe9bt0a+FkM7jD81nMX6QlFGbwYJCcNxY0mvwznpfNouVJyKdsMVDU8tIkEZif6wCVP92tC+N/ZGppMIUvr8MoqLzDfHPf9SBeZeFZ+t28VeGubjhWO9rLKAqExZBsqMmE/q/TIbhvWqovbeiqJWwqsqrlSRc8AiMSmHM/UKqND1hLw6uhNkbD0sW42fVUIJEGPf7pcmjA8TgbTBZnb1SNkVQ/gf8pwUJUj9EO2PBm9WCklqUhfn3QbtbTFhJsLDRNGeZdseZDdOhRDw/nI2Eb2uUxHiq+lg1r4M1L2NB01f2Suvb21onCzw2vPHu11aZf7lbV4efsiytwlFXVPfRRSS5SX832vsY3i2Xlq5d+64tfMebqy9CuJE0AwxZlaCzUr6CARR8EA9o6CAJ7dhB8CukAfEpBHHQk2+XN9I7TkpLfMsqNyTZtonTrKhAlqWVHB0MTbavHpB1vE0QBj/mJhvNCDECyvD8apt4TrDZFDb6Xwxnxw3UcaMjtuucQL+AMRXRRTd2nVDT96pxSmvAlBkwxIEfLXZu2FGzylXFZ+p3gAV2junlsxw43ejdcmpji3SJEKRxm6oGA9xAXVMxgIZ8hR8HE3G+oQ4ZbCAOQii/Pxkwa1era0GzZziBKeaUDUHGHzzsqfRhoqHt5AVBoPPd/gv/wPgLAD7YL3/iaDwthHJ3jqwtKw6MqLzmJNdHgYcj4Tk5iq4dXjHdDtAlQAAksVXr1707q3Xr4n3rwfVwJq6pjPupak3GuPGDlBJE8GbdHTcKw1unsuykkR+In2IE9Pk+RS2ZAlb5jDmnn6ODT3zZZvllk4XPVB95wbLTXgbGRTgT42XXJEEJsLpLWaz0gWuwMpbAS8enZ475XnkmRVJcJowGgkGVr3q5KIKZSb+Fw0l7J2ONbdyoAJRURXp0+lQ0FQgXOrts6lYLPZ7ejZaO/TUjYAVsXhf4jRlWkuOUwVLXZO+Kqedb9JU83ys9XXKhupiogKUn+BwcHSVDoRLswK8Mglfe/XsTCtnuFigSKp8/O9PczmvcTJb6CtVG/3z/OvJeLbk3HsjhJVKRNHskQ2W/dqa9NbGzZlXJ1zi5aMGbbDq2CWq6XespThDZu+3sXzSzgMRucZ3MSUiQ2FhLCaLvGB5N8oTTZgt9JUoKbwiaIa6xnxlP4S1xuZaei1LF4taF94JWTm0BBLBJk1QgXys91tvdzAOVCArvAyjfhfUQITeeEmSmU2DZdsvab1rUvr1+6W9+P3bFOnGBv649Q/I2S0glQZvk3fLOHmwmu418/Tw8O/IrJj4q34Iqw4RCgpiLNtM6MkxPUCpMqp25Dq0974GlbgkDJfMyBAo0PxOBJX4Kbgcaydw0SxFpnbGu8oyqLBZypPbfRHeqfqC6s+FYrpaTN/tvby1QydV4oVPe4EgVmasagdJUk2sVV+AaGMt03o9CGaMVFevzedYCLJTjrSgHcBlKYsMwzndb1UDh9eD4EpvcOHSNEPem+4d5mDVEqpMMrG7PBTp7Bx57uR2MWUeF96rWpbkKBoKU8zfPKmOiXU1+hzLmmomX1XffWysuS56ulxX52WLoKGdq9GoBA0tNb5/P3tyVBMAVSYkWXNBxRSF6psYkzZ5BlEWFujfJNmGIp0k473ILpbeR1i25FPZlrOKaxQIgxWaytfRZDw22xKFcKyIl+UEQVRarVoHCTQ09tC6GOhx9H8OVOUDSBP+zRFg8IF5PxArWfRj1YuQUJYzi8iyQMYKm0Arwi7FAOnHp2ahTbjsHmtj1Q6Hw/vnF3wtUyjuQn6biqIBM2RYkLEvR8NK2E6HCghHFYYQLgEGxHiDSW6gDN+ZrgYGX0Ukw2Y74oHMzKDpikPbFfePAToyLMO82DLECbfcuMd7ONX0r6H6Cg0xdFkDiLUz1An6rwHEj7dMXqjEEfqCd/csMNC44jR4zSJFprf6T708dPU9xFe9zAfj2Qxq8C7WXJqMpbyctbFKB0oCP7BYrRoC9/wvI5rhcNb3BAgrFNo+oPXQNUcbEls2nIwOB19UcAppQOG1g/rmrroAFbrzQjChQsW+2L7U6y0ySd0lQKypeY9t7NJkFfK3xEYaM5J89IYZlh0GvMxrtnHyYLXG8Tj5QxCEUbh/pY1xBTQGhxpP9LDS7FJ6O60f9d/UItfsEnSs0n8PqiuGAEaxwi9DkNqPEGx1u6oyZHFbNzpE2f1mHyOTKWjtHjez0myr9z9d1HfeKpAcO+zWEatDx7yORiuruomLm4zJMj1ugN7UCJAp3WPk0IvATdq4SyM//wOAoLomkoBkpY+LwIUlLpNkkkkmXdwjQUVYmWwqzcTy7UjvpZjNpNPJ4s5riK1YAiiqJPA8DqtdRWRI9XAY4+PhPtHVqVMxucc2ofWlu03j1yYNaFxh11XLBPxY9Aw4A+nZLF0kfwdL7o3pnixmtvOZ/qjINi2mZDU2R2LbQ3/Lbv1pgTVOAnhJnPzXlmH3VxZWTsep0lgzhdjfhc0NjP1drpdUbtXsHC/Xag0w9tTTd4RqpLp/FZwZg/QLpjDQa5fabcfzwMQLfmDCa6C/+RbMdWwZfgPgh8XXqPs7emcY0ZMw4Z5FM39NBeXqYvI14wAhOlEwcPp3OtjTqZuB9TQ5OZ0CM2PJXIr2xIh1qwaTUlVudDCxZqc3b7TpBwrUwA3VM42b2p8sg5Qe4sWvsFq5OsFr4sTuKPiibbP3yoxURREOsoE1ub91CxV2TMuC+j7xDR5ng/MULmqUSl+WKGyFUQ5vR8WqbfnS7X3KgKocjiNnpj1+7diESWHNMx0qH9z+UTwJ9gyym5HCkT9+WGGTr/I/Mwt+T0/u+eDU/qaVw2aXDNKe/VBRkfYmrbFFmFC0iSxblsE359S+Dy5MGtM7V1Po7JLOVhU7OZ+6pdEQGboiCWB7V399srHFtl9TtwjVSagiDirqNFy5XQuRPUcOhNdPTbBaYv6+CTsNblBB9PtqjQ1OtXuhhg3s5q+3EU2brSIPhNHnwayF+4P0BX6E4Ppy+PAEV2npXw/U+8e7eKEI4z/4c3p7bbPBGViFKQZ4O9rxsD+aC5sCxwTlZ9GJMS2CGnrNw30PxkeL5XS3Z56eMtXUlUbC0Rl1PFGdukSw6oHZeaTTw1Urn5xdgrlCyS3DeZfssI1e+zoptt8uzC7ejprd5MWUSkohu1zvrln5VAxhlKRmTlcrSf6JPe5OVx0cJFH4sGt5CUyF5x4vxNe4nRZ1AiphrD21320axoaDSq1VvqVLV3MvqUw+bOeKLZXM8GMED3VjEO0CGmDHtb1QXS281IaFjxqNJhJRCk31Q9itC48WYPsJzyqSZufpwTZRBBXasRr7AP+0vkiOWxR86LCTEpzZJbuFh2o9pgSag2dRirhsHtFvCZ0cOaRT71IhF93DvzxeNLuWG5jHfNDGCRjuh/CEpuZYEDL1Fd97oS+aSCyHhy3BlphODdzoWjINOZAnH647WYCFuJtuBJ6VzRZeoYRzUZgeZThWEIo1bAx+gdHY9N4YCKqet9ee7QX2WbVcAuxrxhktPB0r5uABunkOa8sVNjIIhZoIHffbBge6UP+oh0xmLDX92jX01i/r9Xq/mS4XpbZ5XErNZlmw9NbmoCjF2vgoC8rxl6xlK0TnhDGkgj0x+1F/B6QYGY62ocjZwuykILPt3V2STEKKZYqF+P3jw8PD0oUVMxkYKWWSDAwKWXxESUe7tVO8zdUICt21FYL15LDJIpABoLGfklllZOLbZahFri822cDVWRdW/A6SRSa977lqYv6npTqhJ/mUKx1Uq26Gz5iGGCaTpv4RTGQkZ3ZekM6QO39rTKfedJ3GzJWjgwjMBwmbXVqiCftThpQmsLt0+h2gm3iUxYQE3yckWKe970iJODQcSxcKJh1/2M3avUZdh1yvw/h1MY0/ZrD5b2xmYQ0f01rO0ThxGFQdbTTRbdYGA3Qal757odXsRKOmM0NjqfhxWm/5EEP1DVnMP97lC9ViBu22Qunk1GeyYtU7co82eCynaJtSvpAJS0bRvjw9DTi1L6MEDWm40zCfG8UX+jx/B/rtqCsgRMEJXgO+3vbCNiAZ261221T8AWaTm6B5ZtKxTCabzaRS6RO7n5n0whCwr5xly/eYCma3sr3dyPspGl7CasBpZcVCj2APXziTOCNMoL+af655hBAon6KIQ4ujaM5VPnS/g6vmkOvXY2VK+m7HL9eteZwGUEVeUyX+LLSof5HAfHzWhnVkVGcoFLDGh3AHEpy5lZ1pI6xfj3557TA/4YEqi2M+cI4PhqiItVPQ8+nZc8il+3j87hHGAgVyv5tOg+UZzt2I4fAlQf2NwDChc84rdpeSwU8J8BMCHCXwcQjsfPARDeCbCmC9ZLBuwZlim0zHstkgE/9RftmbHzkZe36TjvU3xNo9sQsVD5aHOEVATHhR08+mQuzlNcD7EelYoQ9tJdDYhiulugQqDAt/n9JRRgLiihu9ciSX4jJHcRQm0i+NSO7MTNTTJADQNIkqPwGQwW/aTzQMwOvbAhBsAFywUYjIlsuDWh9mkYBGmKlLLXBjjt/EYrBSO0xWgqRonPgurN556QTWyLmKk3MXlCG2yRs6yIcf8aTw/sofROFTVQhJVXlePTonwPhZmCu3ahfv2qpPsam7ThlJy4vC6yv/qny+khMpbCse+XJJ1YxtenwHFF1ZFGRJkd/eoDiLiiyhg7jECTFxnQBDD2utVvnm001Lj/g9OyT5rLw+CaJ4+HgdC2jeOKyIn/p92YoVv6MUVQGIENnrmybwGk3IPHibKLL7VDl0Rdc8C+mG+lxjg49yyWfpMNKk1eiTHD2L4krQVjiwTHZ3aTEU+h4PWjRcIQoACvOYV46AQCWzT0ITvG9EH1dBhapoonP1GD1bIrGCzJDa6Fk9SJOVKELDpB5wxildveKMRJ8cm3gVAfzkeVnjFRn63TdRwDsiCtRukeXGNB7DHUbFMQy3Qmc5oTMVGP9BFJCS8Sv7MmXM8YhGSMEraKeh/1REh7c3nwUZ6e2YExY5JIBKVtfXz5X0sYdBfkEUccuOLZva03zYPuAQKmxPV2u+oHIFXIaWpujmNXtmMcT2NvliyOmtQUanC/GbkCLKNaMn2iQB4aX+6InL9dmcrIa5IBelitv5DZ1xF/U7xBlw0dzc8A+x1CG2PdtV4/juuwU0X91cdBTFaUKVllOyDBka7Tb7f+UQ7Ui9sdjl7wvZdDLpsryMfhRFpnr/uCv9yRO0I6hbUukmorQ58GkhpA2YiWin/1cPR0cjVcvNfL3dJrPFYrVaLWZj5HY9n08v2Qp2EQ3QEadd5HbMAoweJFVafxemTah4WFqYVGq3/zA7g4RqhzWDWoPB/+Rs/2/6pm/6pm/6phvo/wG5nZMNTvF89QAAAABJRU5ErkJggg== -OutFile "C:\" -Credential $Credentials
    EOH
    }
	
}

# Print virtual machine dns name
output "hostname" {
    value   = azurerm_public_ip.apip-01.fqdn
}
