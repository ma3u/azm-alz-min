# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## 🚨 CRITICAL RULE - ALWAYS CHECK AVM MODULE AVAILABILITY

Before implementing ANY Azure resource, ALWAYS verify the latest AVM module version:

```bash
# Quick AVM module version check
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/{service}/{resource}/tags/list" | jq -r '.tags[]' | sort -V | tail -5
```

**Example for Container Registry:**

```bash
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/container-registry/registry/tags/list" | jq -r '.tags[]' | sort -V | tail -5
```

**Never assume module availability - always verify first!**

## Repository Overview

This is a **successfully implemented** Azure Landing Zone project using Azure Verified Modules (AVM) with SSH key-based authentication. The project demonstrates modern AI-assisted infrastructure development with two deployment strategies: a cost-effective sandbox for testing (~$18/month) and an enterprise-grade production template with subscription vending (~$4,140/month).

## ✅ Current Implementation Status (Updated Sep 26, 2025)

### Successfully Deployed and Tested

- **Simplified Sandbox ALZ**: Deployed and verified working
- **Hub-Spoke Networking**: VNet peering functional between 10.0.0.0/16 and 10.1.0.0/16
- **SSH Key Authentication**: RSA 4096-bit keys generated and secured in `.secrets/`
- **Web Application**: `app-alz-web-sandbox.azurewebsites.net` (HTTP 200 confirmed)
- **AVM Resource Modules**: Using Microsoft-validated modules for all components
- **Documentation**: Comprehensive deployment guides for both sandbox and enterprise options

### Ready for Deployment

- **Enterprise ALZ Template**: Management Group scoped with subscription vending
- **Additional Services**: PostgreSQL, Container Apps, Application Gateway, Azure Firewall
- **Production Features**: DDoS Standard, WAF v2, Private Endpoints, Zone Redundancy

## AI-Assisted Development Context & Recent Learnings (Sep 26, 2025)

This project demonstrates successful AI-powered infrastructure development. When working with this repository, leverage Warp's capabilities for:

- **AVM Template Management**: AI assistance with Azure Verified Module selection and configuration
- **Deployment Orchestration**: Context-aware help with both sandbox and enterprise deployment strategies
- **Security Configuration**: SSH key management, network security, and compliance best practices
- **Cost Optimization**: Balance between sandbox testing (~$18/month) and enterprise features (~$4,140/month)
- **Troubleshooting**: Quick resolution of common AVM deployment issues

### ⚠️ CRITICAL LESSONS LEARNED (Sep 26, 2025)

#### 1. Repository Structure Organization Issues
- **Problem**: README.md had incorrect file paths pointing to `sandbox/main.bicep` instead of `infra/bicep/sandbox/main.bicep`
- **Solution**: Reorganized repository with proper directory structure and updated all references
- **Impact**: Broken deployment commands in documentation, confused users about file locations
- **AI Context**: Always verify actual file paths in repository before updating documentation

#### 2. Version Conflicts & Tool Management
- **Problem**: User has `terraform1.9` executable but documentation referenced standard `terraform` command
- **Solution**: Updated all Terraform commands to use `terraform1.9` consistently
- **Impact**: Deployment failures due to version mismatches
- **AI Context**: Check actual installed tools and versions before providing commands

#### 3. Workflow Automation Discrepancies
- **Problem**: GitHub Actions workflows target correct paths (`infra/bicep/sandbox/`, `infra/terraform/simple-sandbox/`) but README was outdated
- **Solution**: Synchronized documentation with actual CI/CD pipeline configurations
- **Impact**: Manual deployment instructions didn't match automated workflows
- **AI Context**: Always cross-reference CI/CD workflows when updating deployment documentation

### Proven Warp Benefits for ALZ Development

- **Persistent Context**: Maintains deployment state across sessions (critical for long ALZ deployments)
- **Multi-Template Orchestration**: Handles complex relationships between hub, spoke, and application templates
- **Command Generation**: Quickly generates Azure CLI commands for validation, deployment, and troubleshooting
- **Documentation Sync**: Keeps deployment guides current with template changes

## Architecture

### Core Components

- **Azure Verified Modules (AVM)**: Microsoft-validated resource and pattern modules for enterprise-grade infrastructure
- **Dual Deployment Strategy**: Sandbox testing ($18/month) and enterprise production ($4,140/month)
- **SSH Key Authentication**: Secure, password-free access using RSA 4096-bit keys
- **Hub-Spoke Networking**: Scalable network architecture with VNet peering and security segmentation

### Project Structure

```
azure-landingzone/
├── infra/
│   ├── accelerator/                   # Original AVM-based deployment templates
│   │   ├── simple-sandbox.bicep       # ✅ Original working sandbox ALZ
│   │   ├── simple-sandbox.parameters.json # Original sandbox configuration
│   │   ├── alz-avm-patterns.bicep     # Enterprise ALZ with subscription vending
│   │   └── alz-avm-patterns.parameters.json # Enterprise configuration
│   ├── bicep/                         # ✅ ORGANIZED Bicep structure
│   │   ├── main.bicep                 # Key Vault deployment
│   │   ├── main.parameters.json       # Key Vault parameters
│   │   └── sandbox/                   # ✅ Sandbox-specific templates (ACTIVE)
│   │       ├── main.bicep             # ✅ Working sandbox ALZ (copied & tested)
│   │       └── main.parameters.json   # ✅ Sandbox ALZ parameters (copied)
│   └── terraform/                     # ✅ ORGANIZED Terraform structure
│       ├── main.tf                    # Key Vault with AzureRM provider
│       ├── variables.tf               # Variable definitions
│       ├── outputs.tf                 # Output values
│       ├── terraform.tfvars.example   # Example variables
│       └── simple-sandbox/            # ✅ ALZ sandbox implementation (ACTIVE)
│           ├── main.tf                # ✅ Working ALZ infrastructure (tested)
│           ├── variables.tf           # Input variables with validation
│           ├── terraform.tfvars       # Default configuration values
│           ├── outputs.tf             # Resource outputs and connection info
│           └── cleanup.sh             # Automated cleanup script
├── .secrets/                          # SSH keys (excluded from git)
│   ├── azure-alz-key                 # Private SSH key
│   ├── azure-alz-key.pub             # Public SSH key
│   └── README.md                     # Security documentation
├── .github/workflows/                 # ✅ AUTOMATED CI/CD
│   ├── bicep-alz-sandbox.yml         # ✅ Bicep sandbox deployment (working)
│   └── terraform-alz-deployment.yml  # ✅ Terraform sandbox deployment (working)
├── docs/                             # Comprehensive documentation
│   ├── avm-deployment-guide.md       # Complete deployment guide for both options
│   ├── avm-modules-guide.md          # AVM modules reference
│   └── deployment-guide.md           # Original Key Vault guide
└── DEPLOYMENT-SUCCESS.md             # Success summary with live environment details
```

### Key Technologies

- **Azure Verified Modules (AVM)**: Pattern modules (`avm/ptn/*`) for enterprise orchestration, Resource modules (`avm/res/*`) for components
- **Bicep**: Infrastructure as Code with AVM integration and type safety
- **SSH Authentication**: RSA 4096-bit keys for secure, password-free access
- **Hub-Spoke Networking**: Scalable architecture with VNet peering and network segmentation

## Current Deployment Commands (Tested & Working)

### Quick Start - Sandbox Deployment ✅

```bash
# Ensure SSH keys exist (run once)
mkdir -p .secrets
ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N "" -C "azure-alz-sandbox-key"

# Login to Azure
az login
az account set --subscription "your-subscription-id"

# Deploy sandbox ALZ (TESTED WORKING - 3 minutes, ~$18/month)
# UPDATED PATH: Now using organized structure
az deployment sub create \
  --location "westeurope" \
  --template-file infra/bicep/sandbox/main.bicep \
  --parameters infra/bicep/sandbox/main.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)" \
  --verbose
```

### Enterprise Production Deployment 🏢

```bash
# Deploy enterprise ALZ (requires Management Group permissions)
az deployment mg create \
  --management-group-id "YOUR_MANAGEMENT_GROUP_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-avm-patterns.bicep \
  --parameters infra/accelerator/alz-avm-patterns.parameters.json \
  --name "alz-enterprise-$(date +%Y%m%d-%H%M%S)" \
  --verbose
```

### AI-Assisted Development Commands

```bash
# Current working environment (AI context)
# Deployed: app-alz-web-sandbox.azurewebsites.net (HTTP 200 ✅)
# Hub VNet: vnet-alz-hub-sandbox (10.0.0.0/16)
# Spoke VNet: vnet-alz-spoke-sandbox (10.1.0.0/16)
# SSH Keys: Available in .secrets/ directory

# AI prompts for extending current deployment:
# "Add Azure Bastion to enable SSH access using our generated keys"
# "Enable PostgreSQL with private networking in the spoke"
# "Add Application Gateway with WAF for web app protection"
# "Implement Container Apps for microservices workloads"

# AI troubleshooting context:
# "Check VNet peering status between hub and spoke"
# "Validate AVM module versions and compatibility"
# "Analyze deployment outputs for connection information"
```

### Current Template Operations

```bash
# Validate working sandbox template
az bicep build --file infra/accelerator/simple-sandbox.bicep

# Validate enterprise template
az bicep build --file infra/accelerator/alz-avm-patterns.bicep

# Test template with What-If analysis
az deployment sub what-if \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json
```

### Current Environment Management

```bash
# Verify current deployment (WORKING SANDBOX)
az resource list --resource-group rg-alz-hub-sandbox --output table
az resource list --resource-group rg-alz-spoke-sandbox --output table

# Test web app connectivity
curl -I https://app-alz-web-sandbox.azurewebsites.net  # Should return HTTP 200

# Check deployment outputs for connection info
az deployment sub show --name "$(az deployment sub list --query '[0].name' -o tsv)" \
  --query 'properties.outputs.connectionInfo.value' --output yaml

# Monitor costs
az consumption usage list --start-date 2025-09-26 --end-date 2025-09-27 \
  --query '[].{service:instanceName,cost:pretaxCost}' --output table

# Clean up when done testing
az group delete --name rg-alz-hub-sandbox --yes --no-wait
az group delete --name rg-alz-spoke-sandbox --yes --no-wait

# TERRAFORM COMMANDS (Updated with correct version)
# Use terraform1.9 specifically (user's installed version)
cd infra/terraform/simple-sandbox
terraform1.9 state list
terraform1.9 output connection_info
terraform1.9 destroy -var-file="terraform.tfvars" -auto-approve
```

### Extension and Customization Operations

```bash
# Enable additional services in sandbox
# UPDATED PATH: Edit organized structure parameters
# Edit infra/bicep/sandbox/main.parameters.json:
# Set enableBastion: true, enableAppWorkloads: false, etc.

# Redeploy with changes (UPDATED PATHS)
az deployment sub create \
  --location "westeurope" \
  --template-file infra/bicep/sandbox/main.bicep \
  --parameters infra/bicep/sandbox/main.parameters.json \
  --name "alz-sandbox-update-$(date +%Y%m%d-%H%M%S)"

# Check AVM module versions (UPDATED PATH)
grep -r "br/public:avm" infra/bicep/sandbox/main.bicep
```

### Key Configuration Files

### infra/bicep/sandbox/main.bicep ✅ (ORGANIZED & WORKING)

- **NEW LOCATION**: Moved from `infra/accelerator/` to organized structure
- Uses AVM resource modules: VNet (0.1.6), Web Apps (0.3.7), Storage (0.9.1), Log Analytics (0.3.4)
- Implements hub-spoke architecture with automatic VNet peering
- SSH key integration for secure VM access (keys in `.secrets/`)
- Configures Basic tier services for cost-effective testing (~$18/month)
- Generates unique resource names with `uniqueString()` function
- Comprehensive outputs including connection information

### infra/accelerator/alz-avm-patterns.bicep 🏢 (ENTERPRISE READY)

- Uses AVM pattern modules: subscription vending (0.2.0), hub networking (0.1.0)
- Management Group scoped deployment with automated subscription creation
- Enterprise features: Azure Firewall, DDoS Standard, Application Gateway WAF v2
- Private endpoints and DNS zones for secure connectivity
- Zone redundancy and high availability configurations

### .secrets/ (SECURITY)

- `azure-alz-key` / `azure-alz-key.pub`: RSA 4096-bit SSH keys
- Automatically excluded from git via `.gitignore`
- Used by Bicep templates for secure authentication
- README.md with security guidelines

## Security Considerations

### Key Vault Security Features

- **RBAC Authorization**: Fine-grained access control using Azure AD
- **Soft Delete & Purge Protection**: 90-day retention, prevents accidental deletion
- **Premium SKU**: HSM-backed keys and enhanced security
- **Network Access**: Configurable (default allows Azure services)

### Deployment Security

- PSRule for Azure compliance scanning in CI pipeline
- What-If analysis before all deployments
- Manual approval gates for production deployments
- Service principal with least-privilege access

## Environment Strategy

### Development

- Resource Group: `rg-avm-alz-min-dev`
- Key Vault Prefix: `kv-dev`
- Auto-deployment from `main` and `develop` branches

### Production

- Resource Group: `rg-avm-alz-min-prod`
- Key Vault Prefix: `kv-prod`
- Manual approval required, deploys only from `main` branch

## Troubleshooting

### Common Issues

**Key Vault Name Already Exists**

```bash
# Check if name is globally unique or soft-deleted
az keyvault list --query "[?name=='kv-name']"
az keyvault list-deleted --query "[?name=='kv-name']"

# Purge soft-deleted vault if needed
az keyvault purge --name kv-name --location westeurope
```

**Resource Provider Not Registered**

```bash
az provider register --namespace Microsoft.KeyVault
az provider show --namespace Microsoft.KeyVault --query "registrationState"
```

**Template Validation Errors**

```bash
# Check template syntax
az bicep build --file infra/main.bicep

# Validate with detailed output
az deployment group validate \
  --resource-group your-rg \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --debug
```

## Testing

### Post-Deployment Validation

```bash
# Test Key Vault accessibility and operations
KV_NAME="your-keyvault-name"

# Verify Key Vault exists and is accessible
az keyvault show --name $KV_NAME

# Test secret operations (validates RBAC permissions)
az keyvault secret set --vault-name $KV_NAME --name "test-secret" --value "test-value"
az keyvault secret show --vault-name $KV_NAME --name "test-secret" --query "value"
az keyvault secret delete --vault-name $KV_NAME --name "test-secret"
```

## Azure DevOps Integration

### Pipeline Triggers

- **CI**: Triggers on commits to `main`, `develop`, `feature/*` branches affecting `infra/` or `pipelines/`
- **PR**: Validation pipeline for PRs to `main` and `develop`

### Pipeline Stages

1. **CI**: Bicep linting, ARM template building, PSRule security scanning
2. **Deploy Dev**: Automatic deployment to development environment
3. **Deploy Prod**: Manual approval required, production deployment

### Required Azure DevOps Setup

- Service connection: Update `azureServiceConnection` in `pipelines/variables/common.yml`
- Environments: `avm-alz-min-dev` and `avm-alz-min-prod` with appropriate approvals
- Variable groups: Update subscription IDs and resource group names

## Best Practices

### AI-Assisted Development

- Use Warp's persistent context to maintain deployment state awareness across sessions
- Leverage AI for generating secure Bicep templates with AVM patterns
- Let AI assist with troubleshooting deployment failures and security configurations
- Use AI-powered What-If analysis interpretation for change impact assessment
- **ALWAYS check AVM module availability**: Before implementing any Azure resource, verify the latest AVM module version and parameters

### AVM Module Verification (MANDATORY)

**CRITICAL RULE**: Before implementing any Azure resource, ALWAYS verify AVM module availability and versions.

#### Check AVM Module Availability

```bash
# Check available versions for a specific resource type
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/{service}/{resource}/tags/list" | jq -r '.tags[]' | sort -V

# Example: Check Container Registry module versions
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/container-registry/registry/tags/list" | jq -r '.tags[]' | sort -V

# Example: Check Storage Account module versions
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/storage/storage-account/tags/list" | jq -r '.tags[]' | sort -V

# Search for available AVM modules
curl -s "https://mcr.microsoft.com/v2/_catalog" | jq -r '.repositories[]' | grep "bicep/avm/res" | sort
```

#### AVM Module Template

Always use this format for AVM modules:

```bicep
module resourceName 'br/public:avm/res/{service}/{resource}:{latest-version}' = {
  name: 'deploymentName'
  scope: resourceGroup
  params: {
    // Use AVM-validated parameters only
    // Check module documentation for correct parameter names
  }
}
```

#### Verification Checklist

- [ ] Confirmed AVM module exists for the Azure resource
- [ ] Identified latest stable version (avoid preview versions in production)
- [ ] Reviewed module documentation for parameter requirements
- [ ] Tested module parameters match AVM schema (not ARM template parameters)
- [ ] Validated template compiles with `az bicep build`

### Bicep Development

- **MANDATORY**: Always check AVM module availability before implementing any Azure resource
- Always use What-If analysis before deployment
- Leverage Azure Verified Modules for proven, secure configurations
- Use consistent naming conventions with environment indicators
- Apply comprehensive resource tagging
- Understand AVM parameters rather than recreating custom configurations
- Validate AVM module versions and parameter schemas before coding

### Security

- Enable all Key Vault security features from day one
- Use RBAC instead of access policies for modern security model
- Implement network restrictions for production workloads
- Monitor and alert on Key Vault access patterns
- Let AI suggest security hardening based on Azure security baselines

### Operations

- Test in development environment first
- Use incremental deployment mode
- Maintain deployment documentation
- Implement proper change management for production
- Use AI assistance for deployment troubleshooting and optimization
