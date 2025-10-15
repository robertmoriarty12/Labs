output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Name of the created resource group"
}

output "application_gateway_id" {
  value       = azurerm_application_gateway.appgw.id
  description = "Resource ID of the Application Gateway"
}

output "application_gateway_public_ip" {
  value       = azurerm_public_ip.appgw_pip.ip_address
  description = "Public IP address of the Application Gateway"
}

output "user_assigned_identity_id" {
  value       = azurerm_user_assigned_identity.uami.id
  description = "Resource ID of the User Assigned Managed Identity"
}
