# Key Vault Expiry Events Demo (Terraform)

This Terraform project deploys a minimal Azure environment that:

1. Creates a Resource Group
2. Creates an Azure Key Vault (with purge protection and soft delete retention)
3. Subscribes to Key Vault lifecycle events (secret & certificate expiry / near-expiry) via Event Grid
4. Routes those events to an Azure Event Hub (demo sink) for inspection

> Originally this demo attempted to send emails via an Azure Monitor Action Group directly from an Event Grid subscription. That is **not supported**: Event Grid does not invoke Azure Monitor Action Groups directly. Instead, Action Groups are triggered by Azure Monitor alerts. For a pure email notification scenario you would add an ingestion + alerting pipeline (Log Analytics + Scheduled Query Alert) or use a Logic App / Function. This repo keeps the scope intentionally small and just lands events in an Event Hub.

## Deployed Resources

| Resource | Terraform Address | Notes |
|----------|-------------------|-------|
| Resource Group | `azurerm_resource_group.rg` | Deployment scope |
| Key Vault | `azurerm_key_vault.kv` | Randomized name using `random_integer` suffix |
| Event Grid Subscription | `azurerm_eventgrid_event_subscription.kv_expiry_sub` | Filters to near-expiry / expiry events for secrets & certs |
| Event Hub Namespace | `azurerm_eventhub_namespace.demo` | Standard SKU (capacity 1) |
| Event Hub | `azurerm_eventhub.kv_events` | Receives the Key Vault events |
| Random Integer | `random_integer.suffix` | Provides uniqueness for names |

## Event Types Captured
- Microsoft.KeyVault.SecretNearExpiry
- Microsoft.KeyVault.SecretExpired
- Microsoft.KeyVault.CertificateNearExpiry
- Microsoft.KeyVault.CertificateExpired

## Files
- `main.tf` – core resources
- `providers.tf` – provider & version pinning
- `variables.tf` – input variables (currently `location` and optional `webhook_url` if reintroduced)
- `terraform.tfvars` – variable values (webhook placeholder no longer used after Event Hub switch)
- `terraform.tfstate` (and backups) – state (do **not** commit to public repos)

## Usage

### Prerequisites
- Terraform >= 1.5
- Azure CLI authenticated (or environment variables / managed identity)
- Sufficient permissions to create RG, Key Vault, Event Hub, Event Grid subscription

### Steps
```powershell
# Initialize provider plugins
terraform init

# Review planned changes
terraform plan

# Apply (creates RG, KV, Event Hub namespace+hub, and Event Grid subscription)
terraform apply -auto-approve
```

### Inspecting Events
1. Generate a secret or certificate in the Key Vault with a near-term expiry to trigger events (secrets: set an `exp` attribute via CLI or REST; certificates: use a short validity test cert).
2. Use Azure Portal or CLI to read Event Hub messages (you may need to add an authorization rule & consumer group – not created by default in this simplified demo).

Example (after adding a listen authorization rule):
```powershell
# Add (optional) authorization rule via Terraform or Azure CLI if needed
# az eventhubs eventhub authorization-rule create ...
```

## Extending the Demo
| Goal | Addition |
|------|----------|
| Send email notifications | Add ingestion to Log Analytics + Scheduled Query Alert referencing Action Group OR Logic App/Function endpoint |
| Persist events for analysis | Enable Capture on Event Hub or forward to Storage / Data Explorer |
| Filter different Key Vault events | Adjust `included_event_types` list |
| Multiple vaults | Add more vault resources and duplicate / parameterize subscription blocks |

## Limitations / Notes
- No direct Action Group integration: must use Azure Monitor alerting pipeline if required.
- No access policies are configured on Key Vault (RBAC assumed or add `access_policy` blocks if needed).
- Event Hub authorization rule & consumer group not created (keep minimal footprint).
- `webhook_url` variable retained only if you want to revert to a webhook; otherwise safe to remove.

## Potential Next Steps
- Remove `webhook_url` variable & tfvars entry (cleanup)
- Add an output for Key Vault name (`vault_name`) & Event Hub name for quick reference
- Add an authorization rule for the Event Hub and output connection string for local consumers
- Implement a sample Azure Function that reads the Event Hub events

## Troubleshooting
| Issue | Cause | Fix |
|-------|-------|-----|
| Event Grid subscription stuck validating | Webhook endpoint invalid | Use Event Hub endpoint (as implemented) or a real webhook handler |
| Key Vault events not appearing | Event may not have fired yet | Create/modify secrets/certs with near expiry to trigger events |
| Terraform apply slow on Key Vault | Normal provisioning time | Wait; typical 2–4 minutes for new KV with purge protection |

## Destroy
```powershell
terraform destroy -auto-approve
```

## License
Internal demo – add a license if publishing externally.
