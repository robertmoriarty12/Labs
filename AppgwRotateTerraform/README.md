<div align="center">

# Azure Application Gateway (Dummy) with User-Assigned Managed Identity

Minimal Terraform deployment that creates an isolated Resource Group with an Application Gateway (Standard_v2) and a User-Assigned Managed Identity (UAMI), wired to a dummy backend. Intended for deployment testing only; not production-ready.

</div>

---

## What this deploys

All resources are created in a brand-new resource group so nothing in your existing environment is modified.

- Resource Group (isolated; random suffix to avoid collisions)
- User-Assigned Managed Identity (UAMI)
- Virtual Network and a dedicated subnet for Application Gateway
- Public IP (Standard, static)
- Application Gateway Standard_v2
	- Frontend public IP
	- HTTP listener on port 80
	- Backend pool with a dummy target `8.8.8.8`
	- Basic routing rule to the dummy backend
	- Supported TLS policy set to avoid deprecated TLS versions

High-level flow

```
Internet ──▶ Public IP ──▶ Application Gateway (Std_v2) ──▶ Backend Pool [8.8.8.8]
																					│
																					└── UAMI attached (no roles assigned)
```

> Note: The backend will be unhealthy and 502s are expected. This is intentional since `8.8.8.8` is a placeholder.

## Prerequisites

- Terraform >= 1.13
- Azure CLI authenticated to the correct tenant/subscription
- Permissions to create the resources above

Optional but recommended, set your subscription before running Terraform:

```powershell
az account set --subscription "<your-subscription-id-or-name>"
```

## Quick start

From the repo folder containing the Terraform files:

```powershell
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Outputs include the resource group name, Application Gateway ID, public IP, and the UAMI resource ID.

To destroy everything when done:

```powershell
terraform destroy -auto-approve
```

## Configuration

These variables can be overridden via `-var` flags or a `*.tfvars` file.

- `location` (string, default: `eastus`) — Azure region for all resources
- `name_prefix` (string, default: `demo-appgw`) — Prefix for resource names
- `address_space` (list(string), default: `["10.90.0.0/16"]`) — VNet address space
- `subnet_prefix` (string, default: `"10.90.0.0/24"`) — App Gateway subnet CIDR
- `tags` (map(string)) — Tags applied to all resources

Example using a tfvars file:

```hcl
# local.auto.tfvars (example)
location      = "eastus2"
name_prefix   = "demo-appgw"
address_space = ["10.91.0.0/16"]
subnet_prefix = "10.91.0.0/24"
tags = {
	environment = "sandbox"
	purpose     = "ephemeral-appgw-test"
	managedBy   = "terraform"
}
```

Apply with:

```powershell
terraform apply -var-file="local.auto.tfvars"
```

## Outputs

- `resource_group_name` — Name of the created resource group
- `application_gateway_id` — Resource ID of the Application Gateway
- `application_gateway_public_ip` — Public IPv4 address
- `user_assigned_identity_id` — Resource ID of the UAMI

## Verify deployment

- Azure Portal: Navigate to the new resource group and open the Application Gateway
- CLI: Inspect identity on the gateway

```powershell
az network application-gateway show `
	-g <rg-name> `
	-n <agw-name> `
	--query identity -o jsonc
```

List UAMI IDs attached to the gateway:

```powershell
az network application-gateway show `
	-g <rg-name> `
	-n <agw-name> `
	--query "identity.userAssignedIdentities | keys(@)" -o tsv
```

## Notes and constraints

- App Gateway requires a dedicated subnet (the template creates one specifically for AGW)
- The backend target `8.8.8.8` is a placeholder; health probes will fail and 502s are expected
- A supported TLS policy is set to avoid deprecated TLS versions
- The UAMI has no role assignments by default; add any RBAC as required for your scenario

## Troubleshooting

1) Azure auth/expired token

If you see errors like “invalid_grant” or sign-in frequency issues during `plan/apply`:

```powershell
az logout
az login --tenant "<tenant-id>"
# optional
az account set --subscription "<subscription-id-or-name>"
```

2) Deprecated TLS policy

If the gateway creation fails with an error about deprecated TLS versions, ensure the `ssl_policy` block in `main.tf` sets a supported predefined policy (this template uses `AppGwSslPolicy20220101S`).

3) Address space overlaps

If your environment uses overlapping address spaces, adjust `address_space` and `subnet_prefix` to avoid conflicts.

4) AGW subnet must be dedicated

If you accidentally reuse an existing subnet that hosts other services, the deployment can fail. This template creates a dedicated subnet for AGW.

## Cost considerations

Standard_v2 Application Gateway incurs cost even when idle. Use this template for short-lived tests and run `terraform destroy` when finished.

## Repository structure

```
.
├── main.tf           # RG, UAMI, VNet/Subnet, Public IP, App Gateway
├── provider.tf       # Terraform + provider configuration
├── variables.tf      # Input variables and defaults
├── outputs.tf        # Outputs
└── README.md         # This file
```

Recommended `.gitignore` snippet for Terraform:

```
# Local .terraform directories
.terraform/

# Terraform state
*.tfstate
*.tfstate.*

# Crash logs
crash.log
crash.*.log

# Sensitive variable files
*.tfvars
*.tfvars.json

# Plan files
*.plan
tfplan
```

## License

MIT or your preferred license.
