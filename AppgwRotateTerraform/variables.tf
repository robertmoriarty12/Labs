variable "prefix" {
  type        = string
  default     = "agwrenewal"
  description = "Prefix for resource names"
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Azure location"
}

variable "tags" {
  type        = map(string)
  default     = {
    env      = "dev"
    workload = "appgw-demo"
  }
  description = "Tags to apply to all resources"
}
