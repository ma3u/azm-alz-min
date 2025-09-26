# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is an Azure Landing Zone project that deploys secure Azure Key Vault infrastructure using Bicep templates, with a dual-repository strategy (public GitHub for collaboration, private Azure DevOps for enterprise CI/CD). This repository represents a modern approach to AI-assisted infrastructure development, leveraging Azure Verified Modules and GitOps principles.

## AI-Assisted Development Context

This project is designed for AI-powered development workflows. When working with this repository, leverage Warp's pre-indexing capabilities and persistent context awareness for:

- **Bicep Template Generation**: AI can suggest secure configurations using Azure Verified Modules
- **Deployment Troubleshooting**: Context-aware assistance for Azure CLI operations and pipeline failures  
- **Security Optimization**: AI-powered suggestions for Key Vault hardening and compliance
- **Template Optimization**: Intelligent recommendations for performance and cost improvements

### Warp Advantages for Infrastructure Work
- **Persistent Context**: No token-consuming rescanning between sessions
- **Infrastructure Pattern Recognition**: Understands Bicep, Azure CLI, and deployment workflows
- **Generous Request Limits**: 25,500 AI requests at $18/month enables continuous infrastructure assistance

## Architecture

### Core Components
- **Bicep Infrastructure**: Modern ARM template alternative using Azure Verified Modules (AVM)
- **Dual Repository Strategy**: Public GitHub repo mirrors to private Azure DevOps for enterprise deployment
- **CI/CD Pipeline**: Azure DevOps with security scanning, What-If analysis, and environment promotion
- **Key Vault Security**: Premium tier with RBAC, soft delete, purge protection

### Project Structure
```
azure-landingzone/
├── infra/                     # Bicep infrastructure templates
│   ├── main.bicep            # Main Key Vault deployment using AVM module
│   └── main.parameters.json  # Default parameters
├── pipelines/                 # Azure DevOps CI/CD configuration  
│   ├── azure-pipelines.yml   # Main pipeline with CI/CD stages
│   ├── templates/            # Reusable pipeline templates
│   └── variables/            # Pipeline variable configurations
└── docs/                     # Comprehensive documentation
    ├── deployment-guide.md   # Complete deployment instructions
    └── linkedin-article.md   # Architecture deep-dive
```

### Key Technologies
- **Bicep**: Infrastructure as Code with type safety and module reusability
- **Azure Verified Modules (AVM)**: Using `br/public:avm/res/key-vault/vault:0.4.0`
- **Azure DevOps**: Enterprise CI/CD with security scanning and approval gates
- **PSRule for Azure**: Security and compliance validation

## Common Development Commands

### Local Development Setup
```bash
# Clone and setup
git clone <repo-url>
cd azure-landingzone

# Install Azure CLI and Bicep
az bicep install
az bicep upgrade

# Login to Azure
az login
az account set --subscription "your-subscription-id"
```

### Bicep Template Operations
```bash
# Lint and build Bicep templates
az bicep build --file infra/main.bicep

# Validate template syntax
az bicep build --file infra/main.bicep --stdout > /dev/null

# Generate ARM JSON (for review)
az bicep build --file infra/main.bicep
```

### Azure Deployment Commands
```bash
# Create resource group
az group create --name "rg-avm-alz-min-dev" --location "westeurope"

# Validate deployment
az deployment group validate \
  --resource-group "rg-avm-alz-min-dev" \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Preview changes (What-If)
az deployment group what-if \
  --resource-group "rg-avm-alz-min-dev" \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-avm-alz-min-dev" \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --name "keyvault-deployment-$(date +%Y%m%d-%H%M%S)"
```

### Pipeline Operations
```bash
# Install PSRule for security scanning (local testing)
Install-Module -Name PSRule.Rules.Azure -Force

# Run security validation locally
Invoke-PSRule -Path infra/ -Module PSRule.Rules.Azure
```

## Key Configuration Files

### infra/main.bicep
- Uses Azure Verified Module for Key Vault deployment
- Generates unique names within 24-character limit
- Configures security features (RBAC, soft delete, purge protection)
- Environment and purpose tagging applied

### infra/main.parameters.json
- Default parameters for local deployments
- Pipeline creates environment-specific parameters dynamically
- Customize `namePrefix` for different environments

### pipelines/variables/common.yml
- Contains pipeline configuration variables
- Service connection names and subscription IDs
- Update for your Azure DevOps environment

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

### Bicep Development
- Always use What-If analysis before deployment
- Leverage Azure Verified Modules for proven, secure configurations  
- Use consistent naming conventions with environment indicators
- Apply comprehensive resource tagging

### Security
- Enable all Key Vault security features from day one
- Use RBAC instead of access policies for modern security model
- Implement network restrictions for production workloads
- Monitor and alert on Key Vault access patterns

### Operations
- Test in development environment first
- Use incremental deployment mode
- Maintain deployment documentation
- Implement proper change management for production