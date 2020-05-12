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
    type        = string
    default     = "19h1-evd"
    description = "The Windows version for the VM. This will pick a fully patched image of this given Windows version."
}

variable "vmSize" {
    type    = string
    default = "Standard_D2s_v3"
    description = "Size of the virtual machine."
}
