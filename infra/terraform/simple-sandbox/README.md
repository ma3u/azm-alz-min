# Azure Landing Zone - Terraform Simple Sandbox

This directory contains the Terraform configuration for deploying a simplified Azure Landing Zone using Azure Verified Modules (AVM).

## 🚨 CRITICAL - AVM Module Version Check

Before deployment, **ALWAYS** verify AVM module versions:

```bash
# Check Container Registry module version
curl -s "https://registry.terraform.io/v1/modules/Azure/avm-res-containerregistry-registry/azurerm" | jq -r '.version'

# Check Virtual Network module version
curl -s "https://registry.terraform.io/v1/modules/Azure/avm-res-network-virtualnetwork/azurerm" | jq -r '.version'
```

## Quick Start

```bash
# 1. Initialize Terraform (requires Terraform 1.9+)
terraform1.9 init

# 2. Review the deployment plan
terraform1.9 plan -var-file="terraform.tfvars" -out="tfplan"

# 3. Deploy the infrastructure
terraform1.9 apply tfplan

# 4. View deployed resources
terraform1.9 state list
```

## ✅ Live Deployment Results (Sep 26, 2025 21:45 UTC)

**Successfully Deployed:**

- ✅ Hub Resource Group: `rg-alz-hub-sandbox`
- ✅ Spoke Resource Group: `rg-alz-spoke-sandbox`
- ✅ Hub VNet: `vnet-alz-hub-sandbox` (10.0.0.0/16)
- ✅ Spoke VNet: `vnet-alz-spoke-sandbox` (10.1.0.0/16)
- ✅ VNet Peering: Hub ↔ Spoke (Connected)
- ✅ Container Registry: `acralzsandboxrzvc8h8b` (Premium SKU)
- ✅ Private Endpoint: ACR with private DNS zone
- ✅ Storage Account: `stalzsandboxrzvc8h8b`
- ✅ Log Analytics: `log-alz-hub-sandbox`
- ✅ App Service Plan: `asp-alz-sandbox`

**Blocked by Policy:**

- ⚠️ Web App: Blocked by company governance policy (expected behavior)
- ⚠️ Azure Bastion: Not deployed (disabled in config)

**Total Deployment Time:** ~3 minutes
**Estimated Monthly Cost:** ~$8-10 (without web app)

## Files Structure

- **`main.tf`** - Main Terraform configuration with all resources
- **`variables.tf`** - Variable definitions with validation rules
- **`terraform.tfvars`** - Default values for variables
- **`outputs.tf`** - Resource outputs and connection information

## Deployed Resources

### Core Infrastructure (Always Deployed)

- 2 Resource Groups (Hub + Spoke)
- 2 Virtual Networks with Hub-Spoke peering
- Log Analytics Workspace for monitoring

### Optional Services (Configurable)

- **Azure Container Registry** (`enable_container_registry = true`)
  - Premium SKU with vulnerability scanning
  - Private endpoint in hub subnet
  - Microsoft Defender for Containers enabled
- **Application Workloads** (`enable_app_workloads = true`)
  - App Service Plan (B1 SKU)
  - Web App with VNet integration
  - Storage Account (LRS)
- **Azure Bastion** (`enable_bastion = true`)
  - Bastion Host in hub subnet
  - Static Public IP address

## Cost Estimation

| Configuration                | Monthly Cost (USD) |
| ---------------------------- | ------------------ |
| Minimal (networking only)    | ~$2                |
| Default (with ACR + Web App) | ~$18               |
| With Azure Bastion           | ~$161              |

## AVM Modules Used

| Resource           | Module Version | Purpose                 |
| ------------------ | -------------- | ----------------------- |
| Virtual Network    | `0.8.0`        | Hub-Spoke networking    |
| Container Registry | `0.3.0`        | Secure container images |
| Web Apps           | `0.8.0`        | Application hosting     |
| Storage Account    | `0.1.4`        | Application data        |
| Bastion Host       | `0.2.1`        | Secure remote access    |
| Log Analytics      | `0.1.4`        | Monitoring              |

## Configuration Options

Edit `terraform.tfvars` to customize your deployment:

```hcl
# Feature flags
enable_bastion            = false # Cost optimization
enable_app_workloads      = true  # Deploy sample app
enable_container_registry = true  # Deploy ACR with scanning

# Network configuration
hub_vnet_address_space   = "10.0.0.0/16"
spoke_vnet_address_space = "10.1.0.0/16"

# Environment settings
location            = "westeurope"
environment         = "sandbox"
organization_prefix = "alz"
```

## Validation Commands

```bash
# Check deployed resources
az group list --query "[?contains(name, 'alz')]" --output table

# Test web app (if enabled)
curl -I "https://$(terraform output -raw web_app_default_hostname)"

# Verify ACR private endpoint (if enabled)
az network private-endpoint list --resource-group rg-alz-hub-sandbox --output table
```

## Clean Up

```bash
# Destroy all resources
terraform destroy -var-file="terraform.tfvars"

# Clean local state
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Documentation

For detailed deployment instructions, troubleshooting, and advanced configurations, see:

- [Terraform Deployment Guide](../../../docs/terraform-deployment-guide.md)
- [AVM Modules Guide](../../../docs/avm-modules-guide.md)

## Requirements

- Terraform >= 1.3.0
- Azure CLI >= 2.50.0
- Azure subscription with Contributor access
- jq (for module version checks)
