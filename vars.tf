variable "resourceGroupName" {
    type        = string
    description = "Resource Group for this deployment."
}

variable "location" {
    type        = string
    description = "Location for all resources"
}

variable "adminUsername" {
    type        = string
    description = "Username for the Virtual Machine."
}

variable "adminPassword" {
    type        = string
    description = "Password for the Virtual Machine."
}

variable "dnsLabelPrefix" {
    type        = string
    description = "Unique DNS Name for the Public IP used to access the Virtual Machine."
}

variable "windowsOSVersion" {
    type        = list
    default     = ["2016-Datacenter","2008-R2-SP1","2012-Datacenter","2012-R2-Datacenter","2016-Nano-Server","2016-Datacenter-with-Containers","2019-Datacenter"]
    description = "The Windows version for the VM. This will pick a fully patched image of this given Windows version."
}

variable "vmSize" {
    type    = string
    default = "Standard_A1"
    description = "Size of the virtual machine."
}