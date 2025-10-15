variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "name_prefix" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "demo-appgw"
}

variable "address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.90.0.0/16"]
}

variable "subnet_prefix" {
  description = "Subnet prefix for the Application Gateway subnet"
  type        = string
  default     = "10.90.0.0/24"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    environment = "sandbox"
    purpose     = "ephemeral-appgw-test"
    managedBy   = "terraform"
  }
}
