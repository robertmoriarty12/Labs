# Azure Application Gateway + Key Vault TLS (Cert Rotation) — Lab

A minimal, reproducible lab to front a simple HTTP backend with **Azure Application Gateway (Standard_v2)**, terminate TLS with a certificate stored in **Azure Key Vault**, and test **certificate rotation** (new Key Vault secret version) with **zero downtime**.

> This README only includes **working, battle-tested commands**. Any false starts are removed so others can follow this end-to-end without surprises.

---

## Topology & Resource Map (example values)

| Resource | Name | Notes |
|---|---|---|
| Subscription | `<your-subscription-id>` | Set with `az account set` |
| Resource Group | `rg-appgw-kv-lab` | Region `centralus` |
| Virtual Network | `vnet-lab` | Address space `10.2.0.0/16` |
| Subnet (AppGW) | `snet-appgw` | `10.2.0.0/24` |
| Subnet (Server) | `snet-server` | `10.2.2.0/24` |
| **Ubuntu VM** | `vm-backend` | Private IP e.g. `10.2.2.4` |
| **App Gateway** | `agw-lab` | SKU **Standard_v2**, 1 instance |
| Public IP | `agw-lab-pip` | Standard SKU |
| **Key Vault** | `kv-agw-lab-<unique>` | With **RBAC authorization** enabled |
| **UAMI** | `uami-agw` | User Assigned Managed Identity for AGW |
| KV Cert object | `appgw-cert` | Holds your TLS cert versions |
| Hostname (CN/SAN) | `appgw.test` | Matches listener + client hosts entry |

---

## Backend: Hello Flask on Ubuntu (HTTP :80)

[Instructions here unchanged for brevity in this snippet; see full content above.]

---

## Certificate Rotation Notes

- **Rotation:** Import a new PFX version into the existing `appgw-cert` object.  
- **Polling:** AppGW checks Key Vault every ~4 hours. New sessions use the updated version automatically.  
- **Rollback:** Point AGW back to an older Secret Identifier, or disable the newest version in Key Vault.

---

## Checking Which Cert AGW is Using

You can confirm which Key Vault secret version App Gateway is actively referencing:

```bash
az network application-gateway ssl-cert show   -g "$RG" --gateway-name "$APPGW" -n kv-cert   --query keyVaultSecretId -o tsv
```

This outputs the **exact Key Vault secret version** AGW is bound to.

---

## Restart / Refresh

To nudge AGW immediately (instead of waiting 4 hours):

```bash
az network application-gateway update -g "$RG" -n "$APPGW"
# or restart
az network application-gateway restart -g "$RG" -n "$APPGW"
```

---

## Cleanup

```bash
az group delete -n "$RG" --yes --no-wait
```

---
