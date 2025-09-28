# Azure Application Gateway + Key Vault TLS (Cert Rotation) — Lab

A minimal, reproducible lab to front a simple HTTP backend with **Azure Application Gateway (Standard_v2)**, terminate TLS with a certificate stored in **Azure Key Vault**, and test **certificate rotation** (new Key Vault secret version) with **zero downtime**.

> This guide includes only **working, battle‑tested commands** from the session. Any false starts have been removed so it’s copy/paste‑friendly.

---

## Topology & Resource Map (example values)

> Rename freely — these are sane defaults used across commands.

| Resource | Name | Notes |
|---|---|---|
| Subscription | `<your-subscription-id>` | Set with `az account set` |
| Resource Group | `rg-appgw-kv-lab` | Region `centralus` (example) |
| Virtual Network | `vnet-lab` | Address space `10.2.0.0/16` |
| Subnet (AppGW) | `snet-appgw` | `10.2.0.0/24` (dedicated) |
| Subnet (Server) | `snet-server` | `10.2.2.0/24` |
| **Ubuntu VM** | `vm-backend` | Private IP e.g. `10.2.2.4` |
| **App Gateway** | `agw-lab` | SKU **Standard_v2**, 1 instance |
| Public IP | `agw-lab-pip` | Standard SKU |
| **Key Vault** | `kv-agw-lab-<unique>` | **RBAC authorization enabled** |
| **UAMI** | `uami-agw` | User Assigned Managed Identity for AGW |
| KV Cert object | `appgw-cert` | Holds your TLS cert versions |
| Hostname (CN/SAN) | `appgw.test` | Matches listener + client hosts entry |

---

## Prerequisites

- Azure CLI logged in: `az login`
- Sufficient rights to create/assign **User Assigned Managed Identity (UAMI)** and **Key Vault RBAC** (“Key Vault Secrets User”)
- A **Windows client VM** to generate certs and test HTTPS
- An **Ubuntu server VM** as backend target
- On the Windows client, you’ll import a **lab Root CA** into **Trusted Root Certification Authorities** so the client trusts your leaf certs

> Notes: This lab uses Key Vault **RBAC** (not access policies). App Gateway is configured with **User Assigned** identity.
>
> Networking: Ensure the backend NSG allows **TCP 80** from the **AppGW subnet** (10.2.0.0/24 in example).

---

## 1) Backend: Hello Flask on Ubuntu (HTTP :80)

```bash
sudo apt-get update
sudo apt-get install -y python3-pip gunicorn
sudo mkdir -p /opt/hello

sudo tee /opt/hello/app.py >/dev/null <<'PY'
from flask import Flask
app = Flask(__name__)
@app.route("/")
def index():
    return "Hello, you've made it to the server."
PY

sudo tee /etc/systemd/system/hello.service >/dev/null <<'UNIT'
[Unit]
Description=Hello Flask
After=network.target

[Service]
User=www-data
WorkingDirectory=/opt/hello
ExecStart=/usr/bin/gunicorn -b 0.0.0.0:80 app:app
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

sudo useradd -r -s /usr/sbin/nologin www-data || true
sudo chown -R www-data:www-data /opt/hello
sudo systemctl daemon-reload
sudo systemctl enable --now hello

# Local smoke test
curl -f http://127.0.0.1:80
```

**NSG**: allow **TCP 80** from the **AppGW subnet** to this VM.

---

## 2) Windows Client: Create a Root CA + Leaf (CN=appgw.test), export PFX & Root CER

Open **PowerShell** on the Windows client:

```powershell
# Output folder
New-Item -Path "C:\test" -ItemType Directory -Force | Out-Null

# 2.1 Root CA (5 years)
$root = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable `
  -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 `
  -Subject "CN=Lab Root CA" -KeyUsage CertSign, CRLSign `
  -NotAfter (Get-Date).AddYears(5) `
  -CertStoreLocation "Cert:\CurrentUser\My"

# 2.2 Leaf cert for appgw.test (signed by Root CA)
$leaf = New-SelfSignedCertificate -Type Custom `
  -DnsName "appgw.test" -Subject "CN=appgw.test" `
  -Signer $root -CertStoreLocation "Cert:\CurrentUser\My" `
  -KeyExportPolicy Exportable -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
  -NotAfter (Get-Date).AddYears(2) `
  -KeyUsage DigitalSignature, KeyEncipherment `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")   # EKU: Server Authentication

# 2.3 Export artifacts
$pwd = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
Export-PfxCertificate -Cert $leaf -FilePath "C:\test\appgw.test.pfx" -Password $pwd -ChainOption BuildChain -CryptoAlgorithmOption AES256_SHA256
Export-Certificate    -Cert $root -FilePath "C:\test\lab-root-ca.cer"

Write-Host "Wrote C:\test\appgw.test.pfx and C:\test\lab-root-ca.cer"
```

**Trust on the client**: Open **MMC** → Certificates (Local Computer) → **Trusted Root Certification Authorities** → **Certificates** → **Import** `C:\test\lab-root-ca.cer`.

---

## 3) Key Vault (RBAC), Import PFX as Certificate Object

> Run CLI from a machine that can access the PFX file (or import via Portal: Key Vault → Certificates → Import).

```bash
# Vars
SUB="<your-subscription-id>"
RG="rg-appgw-kv-lab"
LOC="centralus"
KV="kv-agw-lab-$(printf '%04d' $RANDOM)"

az account set --subscription "$SUB"
az group create -n "$RG" -l "$LOC"

# Create Key Vault with RBAC authorization
az keyvault create -g "$RG" -n "$KV" -l "$LOC" --sku standard --enable-rbac-authorization true
```

**Import the PFX** as a certificate object named `appgw-cert`:

```bash
# If running on the Windows client where the file exists:
az keyvault certificate import \
  --vault-name "$KV" \
  --name appgw-cert \
  --file "C:\test\appgw.test.pfx" \
  --password "P@ssw0rd!"
```

Grab the **Secret Identifier** (what AppGW will use):

```bash
KV_SECRET_ID=$(az keyvault certificate show -n appgw-cert --vault-name "$KV" --query sid -o tsv)
echo "$KV_SECRET_ID"
```

---

## 4) App Gateway (Std_v2) + UAMI + RBAC → Key Vault

### 4.1 Network (if you need to create it)

```bash
VNET="vnet-lab"
SNET_APPGW="snet-appgw"
SNET_SERVER="snet-server"

az network vnet create -g "$RG" -n "$VNET" -l "$LOC" --address-prefixes 10.2.0.0/16 \
  --subnet-name "$SNET_APPGW" --subnet-prefix 10.2.0.0/24
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n "$SNET_SERVER" --address-prefix 10.2.2.0/24
```

### 4.2 Public IP + App Gateway (with rule priority)

```bash
APPGW="agw-lab"
BACKEND_IP="10.2.2.4"      # your Ubuntu VM IP
FQDN="appgw.test"

az network public-ip create -g "$RG" -n "${APPGW}-pip" --sku Standard -l "$LOC"

# Create AGW; set a priority on the default rule (required by newer APIs)
az network application-gateway create -g "$RG" -n "$APPGW" -l "$LOC" \
  --sku Standard_v2 \
  --public-ip-address "${APPGW}-pip" \
  --vnet-name "$VNET" --subnet "$SNET_APPGW" \
  --capacity 1 \
  --servers "$BACKEND_IP" \
  --http-settings-port 80 \
  --frontend-port 80 \
  --routing-rule-type Basic \
  --priority 100
```

### 4.3 User Assigned Managed Identity (UAMI) + RBAC on KV

```bash
UAMI="uami-agw"

# Create UAMI
az identity create -g "$RG" -n "$UAMI" -l "$LOC"

# IDs
MI_ID=$(az identity show -g "$RG" -n "$UAMI" --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show -g "$RG" -n "$UAMI" --query principalId -o tsv)

# Attach UAMI to App Gateway
az network application-gateway identity assign \
  -g "$RG" --gateway-name "$APPGW" \
  --identity "$MI_ID"

# Give UAMI data-plane rights on the vault
VAULT_ID=$(az keyvault show -n "$KV" --query id -o tsv)
az role assignment create \
  --assignee "$MI_PRINCIPAL_ID" \
  --role "Key Vault Secrets User" \
  --scope "$VAULT_ID"
```

---

## 5) Bind KV Cert to AGW and add HTTPS (443)

Create the AGW SSL cert object that references the **Key Vault Secret Identifier**:

```bash
az network application-gateway ssl-cert create \
  -g "$RG" --gateway-name "$APPGW" \
  -n kv-cert \
  --key-vault-secret-id "$KV_SECRET_ID"
```

Create **frontend-port 443**, **HTTPS listener** (omit `--protocol`), and **HTTPS rule** (with priority):

```bash
az network application-gateway frontend-port create \
  -g "$RG" --gateway-name "$APPGW" -n port-443 --port 443

az network application-gateway http-listener create \
  -g "$RG" --gateway-name "$APPGW" \
  -n listener-https \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port port-443 \
  --ssl-cert kv-cert \
  --host-name "$FQDN"

az network application-gateway rule create \
  -g "$RG" --gateway-name "$APPGW" \
  -n rule-https \
  --http-listener listener-https \
  --rule-type Basic \
  --address-pool appGatewayBackendPool \
  --http-settings appGatewayBackendHttpSettings \
  --priority 200
```

(Optional) Health probe and attach it:

```bash
az network application-gateway probe create \
  -g "$RG" --gateway-name "$APPGW" \
  -n probe-http --protocol Http --path / --port 80 --timeout 30 --interval 30 --threshold 3

az network application-gateway http-settings update \
  -g "$RG" --gateway-name "$APPGW" \
  -n appGatewayBackendHttpSettings \
  --probe probe-http
```

---

## 6) Test from the Windows Client

Map the hostname to the AGW public IP (for testing):

```powershell
# Get the AGW public IP (example)
# az network public-ip show -g rg-appgw-kv-lab -n agw-lab-pip --query ipAddress -o tsv

# Edit as Administrator: C:\Windows\System32\drivers\etc\hosts
# Add a line:
# <AGW_PUBLIC_IP>   appgw.test

Invoke-WebRequest https://appgw.test
# Expect output:  Hello, you've made it to the server.
```

Your client trusts the cert because the **Lab Root CA** was imported into **Trusted Root Certification Authorities**.

---

## 7) Certificate Rotation (No Downtime)

Create a new leaf (signed by your **Lab Root CA**) and import as a **new version** of the same Key Vault certificate object.

```powershell
# Find Root CA
$root = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*CN=Lab Root CA*" -and $_.HasPrivateKey } | Select-Object -First 1
if (-not $root) { throw "Root CA not found in CurrentUser\My." }

# New leaf for appgw.test (1 year)
$leafNew = New-SelfSignedCertificate -Type Custom `
  -DnsName "appgw.test" -Subject "CN=appgw.test" `
  -Signer $root -CertStoreLocation "Cert:\CurrentUser\My" `
  -KeyExportPolicy Exportable -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
  -NotAfter (Get-Date).AddYears(1) `
  -KeyUsage DigitalSignature, KeyEncipherment `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")

$pwd = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
Export-PfxCertificate -Cert $leafNew -FilePath "C:\test\appgw-rotated.pfx" -Password $pwd -ChainOption BuildChain -CryptoAlgorithmOption AES256_SHA256
```

Import as **new version** (same name `appgw-cert`) in Key Vault:

```bash
az keyvault certificate import \
  --vault-name "$KV" \
  --name appgw-cert \
  --file "C:\test\appgw-rotated.pfx" \
  --password "P@ssw0rd!"
```

**How AGW picks it up**

- App Gateway (Std_v2) polls Key Vault about every **4 hours** and automatically uses the **latest enabled secret version**.
- **No downtime**: existing TLS sessions complete on the old cert; new sessions use the new one.

**Force immediate refresh (optional)**

```bash
# Nudge a refresh
az network application-gateway update -g "$RG" -n "$APPGW"

# Or explicitly rebind to the newest version’s Secret ID
NEW_SID=$(az keyvault certificate show -n appgw-cert --vault-name "$KV" --query sid -o tsv)
az network application-gateway ssl-cert update \
  -g "$RG" --gateway-name "$APPGW" -n kv-cert \
  --key-vault-secret-id "$NEW_SID"

# If your CLI lacks 'ssl-cert update', use:
# az network application-gateway ssl-cert delete  -g "$RG" --gateway-name "$APPGW" -n kv-cert
# az network application-gateway ssl-cert create  -g "$RG" --gateway-name "$APPGW" -n kv-cert --key-vault-secret-id "$NEW_SID"
# az network application-gateway http-listener update -g "$RG" --gateway-name "$APPGW" -n listener-https --ssl-cert kv-cert
```

**Rollback (if needed)**

- Point AGW back to a previous version’s **Secret Identifier**, or
- Disable the newest version in Key Vault so the prior version becomes **latest enabled**, then `az network application-gateway update`.

---

## 8) Useful Checks & Troubleshooting

**Which cert is AGW currently using?** ✅

```bash
az network application-gateway ssl-cert show \
  -g "$RG" --gateway-name "$APPGW" -n kv-cert \
  --query keyVaultSecretId -o tsv
```
This prints the **exact Key Vault secret version** AGW is bound to.

**Identity & role assignments**

```bash
# Show AGW identity block
az network application-gateway show -g "$RG" -n "$APPGW" --query identity -o jsonc

# List UAMI role assignments
az role assignment list --assignee "$MI_PRINCIPAL_ID" -o table
```

**Key Vault basics**

```bash
az keyvault show -n "$KV" --query properties.enableRbacAuthorization
az keyvault certificate list-versions -n appgw-cert --vault-name "$KV" -o table
```

**AGW bindings**

```bash
az network application-gateway ssl-cert list     -g "$RG" --gateway-name "$APPGW" -o table
az network application-gateway http-listener list -g "$RG" --gateway-name "$APPGW" -o table
az network application-gateway rule list         -g "$RG" --gateway-name "$APPGW" -o table
```

**Backend health**

- Portal → App Gateway → **Backend health** should be **Healthy**.
- Ensure backend NSG allows **TCP 80** from the **AppGW subnet**.

**Client name resolution / reachability**

```powershell
nslookup appgw.test
ping appgw.test   # optional, just to confirm hosts mapping
Invoke-WebRequest https://appgw.test
```

---

## 9) Security Notes

- Protect the **PFX password**; never commit PFX files to source control.
- Limit Key Vault network access and data‑plane rights (grant UAMI only **Key Vault Secrets User**).
- Prefer HTTPS‑only: after 443 is confirmed, remove the default HTTP rule if desired:
  ```bash
  az network application-gateway rule delete -g "$RG" --gateway-name "$APPGW" -n rule1
  ```

---

## 10) Restart / Refresh / Cleanup

```bash
# Restart (or stop/start) App Gateway
az network application-gateway restart --resource-group "$RG" --name "$APPGW"
# or
az network application-gateway stop  --resource-group "$RG" --name "$APPGW"
az network application-gateway start --resource-group "$RG" --name "$APPGW"

# Cleanup
az group delete -n "$RG" --yes --no-wait
```

---

### Appendix: Variables quick block

```bash
# Edit and reuse
SUB="<your-subscription-id>"
RG="rg-appgw-kv-lab"
LOC="centralus"
VNET="vnet-lab"
SNET_APPGW="snet-appgw"
SNET_SERVER="snet-server"
APPGW="agw-lab"
KV="kv-agw-lab-1234"
UAMI="uami-agw"
BACKEND_IP="10.2.2.4"
FQDN="appgw.test"
```

---

**End of guide — happy testing!**
