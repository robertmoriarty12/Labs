# ==============================================
# Event Grid -> Azure Monitor Alert (PowerShell)
# ==============================================
# This script:
#   1. Gets an ARM OAuth2 token via client credentials
#   2. Creates (PUT) an Event Grid subscription for a Key Vault
#   3. Verifies (GET) the created resource

# ======= Parameters to Fill In =======
$tenantId       = "<TENANT_ID>"
$subscriptionId = "<SUBSCRIPTION_ID>"
$clientId       = "<APP_REG_CLIENT_ID>"
$clientSecret   = "<APP_REG_CLIENT_SECRET>"   # Rotate after use
$resourceGroup  = "<RESOURCE_GROUP_NAME>"
$keyVaultName   = "<KEY_VAULT_NAME>"
$eventSubName   = "<EVENT_SUBSCRIPTION_NAME>"
$actionGroupId  = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME>/providers/microsoft.insights/actionGroups/<ACTION_GROUP_NAME>"

# ======= API Version =======
# Supports MonitorAlert destination (use stable if preview is unavailable)
$apiVersion = "2025-04-01-preview"   # fallback: "2024-06-01"

# ======= Acquire OAuth2 Token (ARM Audience) =======
$tokenUri = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$tokenBody = @{
  grant_type    = "client_credentials"
  client_id     = $clientId
  client_secret = $clientSecret
  resource      = "https://management.azure.com/"
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$accessToken   = $tokenResponse.access_token
if (-not $accessToken) { throw "Failed to get ARM access token. Check credentials." }

$headers = @{
  Authorization = "Bearer $accessToken"
  "Content-Type" = "application/json"
}

# ======= Build URI Safely =======
$path = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.KeyVault/vaults/{2}/providers/Microsoft.EventGrid/eventSubscriptions/{3}" `
        -f $subscriptionId,$resourceGroup,$keyVaultName,$eventSubName
$uri  = "https://management.azure.com{0}?api-version={1}" -f $path,$apiVersion

Write-Host "PUT -> $uri" -ForegroundColor Cyan

# ======= Body (MonitorAlert Destination) =======
$body = @{
  properties = @{
    eventDeliverySchema = "CloudEventSchemaV1_0"
    destination = @{
      endpointType = "MonitorAlert"
      properties = @{
        severity     = "Sev1"
        description  = "Key Vault lifecycle alert"
        actionGroups = @($actionGroupId)
      }
    }
    filter = @{
      includedEventTypes = @(
        "Microsoft.KeyVault.CertificateNearExpiry",
        "Microsoft.KeyVault.CertificateNewVersionCreated",
        "Microsoft.KeyVault.KeyNearExpiry",
        "Microsoft.KeyVault.SecretNearExpiry"
      )
    }
  }
} | ConvertTo-Json -Depth 8

# ======= Create / Update Subscription =======
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body | Out-Null

# ======= Verify =======
$verify = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
$verify | ConvertTo-Json -Depth 8
