variable "location" {
  default = "eastus2"
}

variable "webhook_url" {
  description = "HTTPS endpoint for Event Grid validation"
  type        = string
}
