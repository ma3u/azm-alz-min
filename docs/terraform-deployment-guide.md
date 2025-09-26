# Terraform Deployment Guide - Azure Landing Zone Sandbox

This guide provides instructions for deploying the Azure Landing Zone sandbox environment using Terraform with Azure Verified Modules (AVM).

## 🚨 CRITICAL RULE - ALWAYS CHECK AVM MODULE AVAILABILITY

Before deploying ANY Azure resource, ALWAYS verify the latest AVM Terraform module version:

```bash
# Quick AVM Terraform module version check
curl -s "https://registry.terraform.io/v1/modules/Azure/{module-name}/azurerm" | jq -r '.version'

# Example for Container Registry:
curl -s "https://registry.terraform.io/v1/modules/Azure/avm-res-containerregistry-registry/azurerm" | jq -r '.version'

# Example for Virtual Network:
curl -s "https://registry.terraform.io/v1/modules/Azure/avm-res-network-virtualnetwork/azurerm" | jq -r '.version'
```

**Never assume module availability - always verify first!**

## Prerequisites

### Software Requirements

1. **Terraform** >= 1.3.0

   ```bash
   # Install or update Terraform
   brew install terraform

   # Verify version
   terraform version
   ```

2. **Azure CLI** >= 2.50.0

   ```bash
   # Install Azure CLI
   brew install azure-cli

   # Verify version
   az version
   ```

3. **jq** (for JSON parsing)
   ```bash
   brew install jq
   ```

### Azure Authentication

```bash
# Login to Azure
az login

# Set subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"

# Verify current context
az account show --output table
```

## Infrastructure Overview

The Terraform configuration deploys the following Azure resources using AVM modules:

### Core Architecture

- **Resource Groups**: Hub and Spoke separation
- **Virtual Networks**: Hub-Spoke architecture with VNet peering
- **Azure Container Registry**: Premium SKU with vulnerability scanning
- **Private DNS Zone**: For ACR private endpoint resolution
- **Log Analytics Workspace**: Centralized monitoring and diagnostics

### Optional Services (Configurable)

- **Azure Bastion**: Secure RDP/SSH access
- **App Service Plan & Web App**: Sample application workload
- **Storage Account**: General-purpose storage for applications

### Network Design

```
Hub VNet (10.0.0.0/16)
├── AzureBastionSubnet (10.0.1.0/24)
├── snet-shared-services (10.0.3.0/24)
├── snet-acr-private-endpoints (10.0.4.0/24)
└── GatewaySubnet (10.0.100.0/24)

Spoke VNet (10.1.0.0/16)
├── snet-web-apps (10.1.2.0/24) - with App Service delegation
└── snet-private-endpoints (10.1.11.0/24)
```

## AVM Terraform Modules Used

| Service            | Module                                                | Version | Purpose                                 |
| ------------------ | ----------------------------------------------------- | ------- | --------------------------------------- |
| Virtual Network    | `Azure/avm-res-network-virtualnetwork/azurerm`        | 0.8.0   | Hub and Spoke networking                |
| Container Registry | `Azure/avm-res-containerregistry-registry/azurerm`    | 0.3.0   | Private ACR with vulnerability scanning |
| App Service Plan   | `Azure/avm-res-web-serverfarm/azurerm`                | 0.7.0   | App hosting infrastructure              |
| Web App            | `Azure/avm-res-web-site/azurerm`                      | 0.8.0   | Web application with VNet integration   |
| Storage Account    | `Azure/avm-res-storage-storageaccount/azurerm`        | 0.1.4   | Application storage                     |
| Azure Bastion      | `Azure/avm-res-network-bastionhost/azurerm`           | 0.2.1   | Secure remote access                    |
| Public IP          | `Azure/avm-res-network-publicipaddress/azurerm`       | 0.2.0   | Public IP for Bastion                   |
| Log Analytics      | `Azure/avm-res-operationalinsights-workspace/azurerm` | 0.1.4   | Monitoring and diagnostics              |

## Configuration

### Default Configuration (`terraform.tfvars`)

```hcl
# Primary configuration
location            = "westeurope"
environment         = "sandbox"
organization_prefix = "alz"

# Network configuration
hub_vnet_address_space   = "10.0.0.0/16"
spoke_vnet_address_space = "10.1.0.0/16"

# Feature flags
enable_bastion            = false # Set to true to enable Azure Bastion
enable_app_workloads      = true  # Enable web app and storage deployment
enable_container_registry = true  # Enable ACR with vulnerability scanning
```

### Customization Options

| Variable                    | Description            | Default       | Validation                  |
| --------------------------- | ---------------------- | ------------- | --------------------------- |
| `location`                  | Azure region           | `westeurope`  | Must be valid Azure region  |
| `environment`               | Environment tag        | `sandbox`     | `sandbox`, `dev`, or `test` |
| `organization_prefix`       | Resource naming prefix | `alz`         | 2-10 lowercase alphanumeric |
| `hub_vnet_address_space`    | Hub network CIDR       | `10.0.0.0/16` | Valid CIDR block            |
| `spoke_vnet_address_space`  | Spoke network CIDR     | `10.1.0.0/16` | Valid CIDR block            |
| `enable_bastion`            | Deploy Azure Bastion   | `false`       | Boolean                     |
| `enable_app_workloads`      | Deploy app services    | `true`        | Boolean                     |
| `enable_container_registry` | Deploy ACR             | `true`        | Boolean                     |

## Deployment Commands

### Directory Setup

```bash
# Navigate to Terraform directory
cd infra/terraform/simple-sandbox

# Verify files are present
ls -la
# Expected files: main.tf, variables.tf, terraform.tfvars, outputs.tf
```

### Standard Deployment Workflow

#### 1. Initialize Terraform

```bash
# Download providers and modules
terraform init

# Verify initialization
ls .terraform/
```

#### 2. Plan Deployment

```bash
# Generate execution plan
terraform plan -var-file="terraform.tfvars" -out="tfplan"

# Review the plan output carefully
```

#### 3. Apply Configuration

```bash
# Apply the planned changes
terraform apply tfplan

# Or apply directly (with confirmation prompt)
terraform apply -var-file="terraform.tfvars"
```

#### 4. Verify Deployment

```bash
# Check deployment outputs
terraform output

# Get connection information
terraform output connection_info

# Get AVM modules information
terraform output avm_modules_used
```

### Advanced Deployment Options

#### Custom Variable Override

```bash
# Override specific variables
terraform apply \
  -var="environment=dev" \
  -var="enable_bastion=true" \
  -var="location=eastus"
```

#### Partial Deployment (Disable Features)

```bash
# Deploy without Container Registry
terraform apply -var="enable_container_registry=false"

# Deploy without Application Workloads
terraform apply -var="enable_app_workloads=false"

# Minimal deployment (networking only)
terraform apply \
  -var="enable_bastion=false" \
  -var="enable_app_workloads=false" \
  -var="enable_container_registry=false"
```

### Deployment Validation Commands

#### Network Validation

```bash
# List deployed resource groups
az group list --query "[?contains(name, 'alz')].{Name:name,Location:location}" --output table

# Check VNet peering status
az network vnet peering list \
  --resource-group rg-alz-hub-sandbox \
  --vnet-name vnet-alz-hub-sandbox \
  --query "[].{Name:name,State:peeringState,RemoteVNet:remoteVirtualNetwork.id}" \
  --output table
```

#### Container Registry Validation

```bash
# Get ACR details
ACR_NAME=$(terraform output -raw container_registry_name)
az acr show --name $ACR_NAME --query "{Name:name,Sku:sku.name,LoginServer:loginServer}" --output table

# Check private endpoint
az network private-endpoint list \
  --resource-group rg-alz-hub-sandbox \
  --query "[?contains(name, 'acr')].{Name:name,State:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  --output table
```

#### Application Validation

```bash
# Test web app connectivity
WEB_APP_URL="https://$(terraform output -raw web_app_default_hostname)"
curl -I "$WEB_APP_URL"

# Check storage account
STORAGE_NAME=$(terraform output -raw storage_account_name)
az storage account show --name $STORAGE_NAME --query "{Name:name,Kind:kind,Tier:accessTier}" --output table
```

## Cost Estimation

### Sandbox Configuration (~$18/month)

- **Resource Groups**: Free
- **Virtual Networks & Peering**: Free (within region)
- **Container Registry Premium**: ~$5/month
- **App Service Plan (B1)**: ~$13/month
- **Storage Account (LRS)**: ~$1/month
- **Log Analytics**: ~$2/month (30-day retention)

### With Azure Bastion (+$140/month)

- **Azure Bastion Standard**: ~$140/month
- **Public IP Standard**: ~$3/month

> **💡 Cost Optimization Tip**: Disable Bastion (`enable_bastion = false`) for cost-effective sandbox testing.

## Troubleshooting

### Common Issues

#### 1. Module Version Conflicts

**Error**: "Unsupported Terraform Core version"

**Solution**:

```bash
# Check Terraform version
terraform version

# Update Terraform if needed
brew upgrade terraform

# Or use compatible module versions (see AVM version matrix)
```

#### 2. Resource Name Conflicts

**Error**: "already exists" or "name not available"

**Solution**:

```bash
# Check current deployment
terraform show

# Generate new unique suffix
terraform apply -replace="random_string.unique"
```

#### 3. Network Configuration Issues

**Error**: "subnet conflicts" or "address space overlap"

**Solution**:

```bash
# Verify network ranges don't conflict
terraform plan -var="hub_vnet_address_space=10.10.0.0/16"
```

#### 4. Permission Issues

**Error**: "insufficient privileges"

**Solution**:

```bash
# Check current permissions
az role assignment list --assignee $(az account show --query user.name -o tsv) --all

# Ensure you have Contributor role on subscription
az role assignment create \
  --assignee $(az account show --query user.name -o tsv) \
  --role "Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)"
```

### Resource State Management

#### View Current State

```bash
# List all managed resources
terraform state list

# Show specific resource details
terraform state show azurerm_resource_group.hub

# Show current state summary
terraform show
```

#### State Recovery

```bash
# Import existing resource (if state drift occurs)
terraform import azurerm_resource_group.hub /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}

# Refresh state from Azure
terraform refresh
```

## Environment Management

### Development Workflow

```bash
# 1. Create feature branch configuration
cp terraform.tfvars terraform.dev.tfvars

# 2. Customize for development
# Edit terraform.dev.tfvars with dev-specific settings

# 3. Deploy development environment
terraform apply -var-file="terraform.dev.tfvars"
```

### Clean Up

```bash
# Destroy specific resources
terraform destroy -target="module.azure_bastion[0]"

# Destroy entire environment
terraform destroy -var-file="terraform.tfvars"

# Clean up Terraform state
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

### State Backend (Recommended for Production)

For production deployments, configure remote state backend:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "alz-sandbox.tfstate"
  }
}
```

## Security Considerations

### Container Registry Security

- **Premium SKU**: Required for vulnerability scanning and private endpoints
- **Admin User Disabled**: Uses managed identity authentication
- **Network Access**: Deny public access, private endpoint only
- **Vulnerability Scanning**: Microsoft Defender for Containers enabled
- **Private DNS**: Custom DNS resolution for private endpoint

### Network Security

- **Hub-Spoke Architecture**: Segmented network design
- **Private Endpoints**: Secure access to PaaS services
- **VNet Integration**: Web app deployed with VNet integration
- **No Public IPs**: Except for Bastion (optional)

### Access Control

- **Managed Identities**: System-assigned identities for resources
- **Azure RBAC**: Role-based access control
- **Private Connectivity**: All inter-service communication via private network

## Monitoring and Diagnostics

### Log Analytics Integration

All resources send diagnostic data to centralized Log Analytics workspace:

```bash
# Query ACR logs
az monitor log-analytics query \
  --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "ContainerRegistryRepositoryEvents | limit 10"

# Query VNet flow logs
az monitor log-analytics query \
  --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "AzureNetworkAnalytics_CL | limit 10"
```

### Cost Monitoring

```bash
# Check current month costs
az consumption usage list \
  --start-date "$(date -v1d +%Y-%m-%d)" \
  --end-date "$(date +%Y-%m-%d)" \
  --query "[?contains(instanceName, 'alz')].{Service:instanceName,Cost:pretaxCost}" \
  --output table
```

## Migration from Bicep

If migrating from the existing Bicep deployment:

```bash
# 1. Export existing resources
az group export --name "rg-alz-hub-sandbox" --output-template exported.json

# 2. Remove existing deployment
az group delete --name "rg-alz-hub-sandbox" --yes
az group delete --name "rg-alz-spoke-sandbox" --yes

# 3. Deploy with Terraform
terraform apply -var-file="terraform.tfvars"
```

## Support and Maintenance

### AVM Module Updates

```bash
# Check for module updates
terraform init -upgrade

# Review changes
terraform plan -var-file="terraform.tfvars"

# Apply updates
terraform apply -var-file="terraform.tfvars"
```

### Version Compatibility Matrix

| Terraform Version | AVM Module Version | Azure Provider Version |
| ----------------- | ------------------ | ---------------------- |
| >= 1.3.0          | 0.8.x - 0.9.x      | ~> 3.70                |
| >= 1.5.0          | 0.9.x - 0.10.x     | ~> 3.80                |
| >= 1.6.0          | 0.10.x - 0.11.x    | ~> 3.90                |

### Getting Help

- **Terraform Documentation**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **AVM Documentation**: https://azure.github.io/Azure-Verified-Modules/
- **Azure CLI Reference**: https://docs.microsoft.com/en-us/cli/azure/reference-index
- **Issues**: Create issues in the project repository with Terraform configuration and error details

---

## Quick Reference Commands

```bash
# Essential deployment workflow
terraform init
terraform plan -var-file="terraform.tfvars" -out="tfplan"
terraform apply tfplan

# Validation
terraform output connection_info
curl -I "https://$(terraform output -raw web_app_default_hostname)"

# Cleanup
terraform destroy -var-file="terraform.tfvars"
```
