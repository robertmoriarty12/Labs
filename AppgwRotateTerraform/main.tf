data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  lower   = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg-${random_string.suffix.result}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "uami" {
  name                = "${var.prefix}-uami"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "agw" {
  name                 = "agw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.prefix}kv${random_string.suffix.result}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  enabled_for_deployment      = false
  enabled_for_disk_encryption = false
  enabled_for_template_deployment = false

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Allow the UAMI to read Key Vault secrets (for App Gateway cert loading)
resource "azurerm_key_vault_access_policy" "uami" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.uami.principal_id

  secret_permissions = ["Get", "List"]
}

# Optional: allow the current caller to manage the KV and cert
resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions       = ["Get", "List", "Set", "Delete", "Purge"]
  certificate_permissions  = ["Get", "Create", "Delete", "List", "Update", "Import", "Purge"]
}

# Self-signed certificate for appgw.test
resource "azurerm_key_vault_certificate" "appgw_cert" {
  name         = "appgw-cert"
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=appgw.test"
      validity_in_months = 12
      key_usage          = ["digitalSignature", "keyEncipherment"]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server Authentication
      subject_alternative_names {
        dns_names = ["appgw.test"]
      }
    }

    lifetime_action {
      trigger {
        lifetime_percentage = 80
      }
      action {
        action_type = "AutoRenew"
      }
    }
  }

  depends_on = [
    azurerm_key_vault_access_policy.uami,
    azurerm_key_vault_access_policy.me
  ]
}

# Build a versionless secret ID so App Gateway always uses the latest cert version
locals {
  kv_secret_id_parts       = split("/", azurerm_key_vault_certificate.appgw_cert.secret_id)
  kv_secret_id_versionless = join("/", slice(local.kv_secret_id_parts, 0, length(local.kv_secret_id_parts) - 1))
}

resource "azurerm_application_gateway" "agw" {
  name                = "${var.prefix}-agw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.agw.id
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  backend_address_pool {
    name         = "appGatewayBackendPool"
    ip_addresses = ["10.2.2.4"]
  }

  backend_http_settings {
    name                                = "appGatewayBackendHttpSettings"
    protocol                            = "Http"
    port                                = 80
    cookie_based_affinity               = "Disabled"
    request_timeout                     = 30
    pick_host_name_from_backend_address = false

    connection_draining {
      enabled           = false
      drain_timeout_sec = 1
    }
  }

  ssl_certificate {
    name                = "kv-cert"
    key_vault_secret_id = local.kv_secret_id_versionless
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "port-443"
    protocol                       = "Https"
    host_name                      = "appgw.test"
    ssl_certificate_name           = "kv-cert"
    require_sni                    = true
  }

  request_routing_rule {
    name                       = "rule-https"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "appGatewayBackendPool"
    backend_http_settings_name = "appGatewayBackendHttpSettings"
    priority                   = 100
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uami.id]
  }

  tags = var.tags

  depends_on = [
    azurerm_key_vault_certificate.appgw_cert
  ]
}
