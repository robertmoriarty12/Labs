resource "azurerm_resource_group" "rg" {
  name     = "rg-kv-eg-demo"
  location = var.location
}

data "azurerm_client_config" "current" {}

resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${random_integer.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
}

resource "azurerm_eventgrid_event_subscription" "kv_expiry_sub" {
  name  = "sub-kv-expiry"
  scope = azurerm_key_vault.kv.id

  included_event_types = [
    "Microsoft.KeyVault.SecretNearExpiry",
    "Microsoft.KeyVault.SecretExpired",
    "Microsoft.KeyVault.CertificateNearExpiry",
    "Microsoft.KeyVault.CertificateExpired"
  ]

  eventhub_endpoint_id = azurerm_eventhub.kv_events.id
}

resource "azurerm_eventhub_namespace" "demo" {
  name                = "evhns${random_integer.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1
  auto_inflate_enabled = false
}

resource "azurerm_eventhub" "kv_events" {
  name              = "kvevents"
  namespace_id      = azurerm_eventhub_namespace.demo.id
  partition_count   = 2
  message_retention = 1
}