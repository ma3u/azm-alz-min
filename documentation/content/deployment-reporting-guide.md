# Deployment Reporting Guide

This guide covers the comprehensive deployment reporting system that provides detailed insights into your Azure Landing Zone deployments, including cost analysis, security assessments, and resource inventories.

## 🎯 Overview

The deployment reporting system (`deploy-with-report.sh`) automatically:

1. **Validates prerequisites** and runs pre-commit checks
2. **Deploys infrastructure** with full error handling
3. **Inventories resources** across all resource groups
4. **Analyzes costs** with service-level breakdown
5. **Assesses security** with scoring and recommendations
6. **Generates reports** in HTML and JSON formats
7. **Manages history** by keeping the last 5 deployment reports

## 🚀 Quick Start

### Basic Deployment with Reporting

```bash
# Use default foundation template
./automation/scripts/deploy-with-report.sh

# Use hub-spoke architecture
./automation/scripts/deploy-with-report.sh \
  blueprints/bicep/hub-spoke/main.bicep \
  blueprints/bicep/hub-spoke/main.parameters.json
```

### View Reports

```bash
# Open latest HTML report
open deployment-reports/$(ls deployment-reports/ | grep '^20' | sort -r | head -1)/deployment-report.html

# List all deployment reports
deployment-reports/scripts/report-manager.sh list

# View reports index
open deployment-reports/index.html
```

## 📊 Report Components

### 1. Deployment Status Dashboard

**Metrics displayed:**

- ✅ **Deployment Status** - succeeded/failed
- 📦 **Resources Deployed** - total count across resource groups
- 💰 **Estimated Monthly Cost** - calculated from resource types
- 🔒 **Security Score** - 0-100 based on security findings

![Deployment Dashboard](../images/deployment-dashboard.png)

### 2. Pre-deployment Checks

**Prerequisites validation:**

- Azure CLI version and authentication
- Bicep CLI availability
- jq tool for JSON processing
- Subscription permissions

**Pre-commit validation:**

- YAML/JSON syntax checks
- Bicep linting and compilation
- Terraform formatting
- Security policy compliance

### 3. Resource Inventory

**Complete resource catalog:**

- **Hub resources** (networking, shared services)
- **Spoke resources** (applications, storage)
- **Resource types** with counts and locations
- **Networking features** (peering, DNS, endpoints)

**Example output:**

```
Total Resources: 13 across 2 resource groups

🏢 Hub Resources (rg-alz-hub-sandbox)
• vnet-alz-hub-sandbox - Virtual Network (10.0.0.0/16)
• log-alz-hub-sandbox - Log Analytics Workspace
• acralzsandboxhqilxdzf - Container Registry (Standard)
• privatelink.azurecr.io - Private DNS Zone (Premium only)

💻 Spoke Resources (rg-alz-spoke-sandbox)
• vnet-alz-spoke-sandbox - Virtual Network (10.1.0.0/16)
• app-alz-web-sandbox - Web App (Live URL)
• asp-alz-sandbox - App Service Plan (Basic B1)
• stalzsandboxhqilxdzf - Storage Account (Standard LRS)
```

### 4. Cost Analysis

**Detailed cost breakdown by service:**

- Container Registry: $0-150/month (Standard vs Premium)
- App Service Plan: ~$13/month (Basic B1)
- Log Analytics: ~$15/month
- Storage Account: ~$5/month
- Networking: ~$10/month

**Cost optimization notes:**

- ⚠️ Premium Container Registry adds ~$150/month
- 💡 Standard SKU sufficient for development/testing
- 📊 Costs scale with data ingestion and storage

### 5. Security Assessment

**Security scoring (0-100):**

- **90-100**: Excellent security posture
- **80-89**: Good with minor improvements
- **70-79**: Adequate with recommendations
- **<70**: Needs security attention

**Security findings:**

- Public IP exposure count
- Storage account security settings
- Private endpoint usage
- Network isolation implementation

**Example recommendations:**

- ✅ Container Registry secured with private endpoints
- ✅ No public IP addresses exposed
- ✅ Storage accounts use secure defaults
- ✅ Hub-spoke architecture provides isolation

### 6. Testing Commands

**Ready-to-run validation commands:**

```bash
# Test web application
curl -I https://app-alz-web-sandbox.azurewebsites.net

# Check VNet peering
az network vnet peering list \
  --resource-group rg-alz-hub-sandbox \
  --vnet-name vnet-alz-hub-sandbox

# Test container registry (requires login)
az acr login --name acralzsandboxhqilxdzf

# Cleanup when ready
az group delete --name rg-alz-hub-sandbox --yes --no-wait
az group delete --name rg-alz-spoke-sandbox --yes --no-wait
```

## 🗂️ Report Management

### Automatic History Management

The system automatically:

- **Keeps last 5 reports** active
- **Archives older reports** as compressed files
- **Updates index** with latest deployment data
- **Commits reports** to git (if in git repository)

### Manual Report Management

```bash
# List current and archived reports
deployment-reports/scripts/report-manager.sh list

# Generate new index
deployment-reports/scripts/report-manager.sh index

# Restore archived report
deployment-reports/scripts/report-manager.sh restore deployment-report-20250928-143022.tar.gz

# Manual cleanup (remove reports older than last 5)
deployment-reports/scripts/report-manager.sh cleanup
```

### Report Directory Structure

```
deployment-reports/
├── 20250929-093957/          # Latest deployment
│   ├── deployment-report.html
│   ├── deployment-summary.json
│   ├── pre-deployment/       # Prerequisites & validation
│   ├── deployment/          # Deployment logs & output
│   ├── resources/           # Resource inventory
│   ├── costs/              # Cost analysis
│   └── security/           # Security assessment
├── 20250928-143022/         # Previous deployment
├── archive/                # Compressed old reports
│   └── deployment-report-20250927-*.tar.gz
├── scripts/               # Report management tools
└── index.html            # Reports overview page
```

## 💡 Cost Optimization

### Container Registry SKU Selection

**Standard SKU (Default - Recommended for Sandbox):**

- **Cost**: ~$0.50/day (~$15/month)
- **Features**: Basic registry, standard storage
- **Limitations**: No private endpoints, no geo-replication
- **Best for**: Development, testing, sandbox environments

**Premium SKU (Production):**

- **Cost**: ~$5/day (~$150/month)
- **Features**: Private endpoints, geo-replication, vulnerability scanning
- **Benefits**: Enhanced security, performance, compliance
- **Best for**: Production workloads, enterprise environments

### Toggle Container Registry SKU

**In parameters file:**

```json
{
  "containerRegistrySku": {
    "value": "Standard" // or "Premium"
  }
}
```

**Cost impact:**

- Standard: Total monthly cost ~$25-50
- Premium: Total monthly cost ~$175-200

## 🔧 Customization

### Environment Variables

```bash
# Override default resource group naming
export RESOURCE_GROUP_NAME="rg-custom-alz-$(date +%Y%m%d)"

# Change default location
export LOCATION="eastus2"

# Customize deployment name
export DEPLOYMENT_NAME="custom-alz-deployment-$(date +%Y%m%d-%H%M%S)"
```

### Template Customization

**For different architectures:**

```bash
# Foundation template (basic ALZ)
./automation/scripts/deploy-with-report.sh \
  blueprints/bicep/foundation/main.bicep \
  blueprints/bicep/foundation/main.parameters.json

# Hub-spoke template (enterprise ALZ)
./automation/scripts/deploy-with-report.sh \
  blueprints/bicep/hub-spoke/main.bicep \
  blueprints/bicep/hub-spoke/main.parameters.json
```

## 🚨 Troubleshooting

### Common Issues

**1. Empty Resource Group Created**

- **Cause**: Script creates placeholder RG for resource group-scoped deployments
- **Fix**: Template uses `targetScope = 'subscription'` - no action needed
- **Note**: Script now auto-detects subscription scope and skips placeholder RG

**2. Container Registry Premium Cost**

- **Issue**: Premium SKU costs ~$150/month
- **Fix**: Use Standard SKU for development (`"containerRegistrySku": "Standard"`)
- **Trade-off**: Standard SKU doesn't support private endpoints

**3. Pre-commit Hooks Failing**

- **Cause**: Code quality issues, missing dependencies
- **Fix**: Run `pre-commit run --all-files` to see specific errors
- **Reference**: [Pre-commit Errors Analysis](pre-commit-errors-analysis.md)

**4. Authentication Errors**

- **Cause**: Azure CLI session expired
- **Fix**: `az login` and ensure correct subscription selected
- **Check**: `az account show` to verify current context

### Report Generation Issues

**Missing data in reports:**

```bash
# Regenerate resource inventory manually
(az resource list --resource-group "rg-alz-hub-sandbox" --output json; \
 az resource list --resource-group "rg-alz-spoke-sandbox" --output json) | \
 jq -s 'add' > deployment-reports/latest/resources/resource-inventory.json

# Update cost analysis
./automation/scripts/update-cost-analysis.sh deployment-reports/latest
```

## 📚 Integration with CI/CD

### GitHub Actions

```yaml
name: Deploy with Reporting
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy with Report
        run: |
          ./automation/scripts/deploy-with-report.sh \
            blueprints/bicep/hub-spoke/main.bicep \
            blueprints/bicep/hub-spoke/main.parameters.json

      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: deployment-reports
          path: deployment-reports/
          retention-days: 30
```

### Azure DevOps

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    displayName: 'Deploy with Reporting'
    inputs:
      azureSubscription: '$(azureServiceConnection)'
      scriptType: 'bash'
      scriptLocation: 'scriptPath'
      scriptPath: './automation/scripts/deploy-with-report.sh'
      arguments: 'blueprints/bicep/hub-spoke/main.bicep blueprints/bicep/hub-spoke/main.parameters.json'

  - task: PublishBuildArtifacts@1
    displayName: 'Publish Deployment Reports'
    inputs:
      pathToPublish: 'deployment-reports'
      artifactName: 'deployment-reports'
```

## 🎯 Best Practices

### Report Security

1. **Avoid sensitive data** in reports (credentials, keys)
2. **Use git-crypt** for sensitive deployment configurations
3. **Review reports** before committing to public repositories
4. **Archive old reports** to reduce repository size

### Cost Management

1. **Monitor cost trends** across deployment reports
2. **Set budget alerts** for monthly spending limits
3. **Use Standard SKUs** for development environments
4. **Clean up test resources** promptly after validation

### Operational Excellence

1. **Review security scores** and implement recommendations
2. **Track resource growth** across deployment cycles
3. **Validate testing commands** work as documented
4. **Update documentation** when adding new templates

## 📈 Advanced Features

### Custom Cost Analysis

Add custom cost calculations:

```bash
# Add to deployment-reports/costs/custom-cost-rules.json
{
  "rules": [
    {
      "resourceType": "Microsoft.ContainerRegistry/registries",
      "sku": "Standard",
      "monthlyCost": 15.00
    },
    {
      "resourceType": "Microsoft.ContainerRegistry/registries",
      "sku": "Premium",
      "monthlyCost": 150.00
    }
  ]
}
```

### Security Benchmarking

Track security improvements over time:

```bash
# Compare security scores across deployments
jq '.security.overall_score' deployment-reports/*/deployment-summary.json
```

### Resource Optimization

Identify optimization opportunities:

```bash
# Find high-cost resources
jq '.resources_by_type[] | select(.count > 5)' \
  deployment-reports/latest/resources/resource-summary.json
```

---

## 🔗 Related Resources

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Azure Cost Management](https://docs.microsoft.com/en-us/azure/cost-management-billing/)
- [Azure Security Center](https://docs.microsoft.com/en-us/azure/security-center/)
- [Pre-commit Hooks Guide](pre-commit-hooks-guide.md)
- [AVM Deployment Guide](avm-deployment-guide.md)

---

**Last Updated:** 2025-09-29
**Version:** 1.0.0
