output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource Group name"
}

output "app_gateway_name" {
  value       = azurerm_application_gateway.agw.name
  description = "Application Gateway name"
}

output "app_gateway_public_ip" {
  value       = azurerm_public_ip.pip.ip_address
  description = "Public IP address of the Application Gateway"
}

output "key_vault_name" {
  value       = azurerm_key_vault.kv.name
  description = "Key Vault name"
}
