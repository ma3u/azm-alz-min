# Complete Deployment Guide: Azure Landing Zone with Key Vault

We are using Azure KeyVault to store our secrets for both Deployment options (Azure DevOps Pipeline, Github Actions) for the Azure Landing Zone infrastructure from initial setup to production deployment, including troubleshooting and best practices.

## 🎯 Overview

This deployment guide covers:

- **Pre-deployment preparation and validation**
- **Step-by-step deployment process**
- **Post-deployment configuration and validation**
- **Security hardening and compliance**
- **Monitoring and maintenance procedures**
- **Troubleshooting common issues**

## 📋 Prerequisites Checklist

### Azure Environment

- [ ] **Azure Subscription**: Active subscription with Contributor permissions
- [ ] **Resource Provider Registration**: Ensure Microsoft.KeyVault provider is registered
- [ ] **Subscription Limits**: Verify Key Vault quota availability in target region
- [ ] **Azure CLI**: Version 2.37.0 or later installed and configured

### Development Environment

- [ ] **Git**: Version control system installed
- [ ] **Code Editor**: VS Code with Bicep extension recommended
- [ ] **PowerShell/Bash**: Command line interface available
- [ ] **Network Access**: Unrestricted access to Azure APIs

### GitHub Setup

- [ ] **GitHub Account**: Access to ma3u/azm-alz-min repository
- [ ] **Personal Access Token**: For repository access if private operations needed
- [ ] **Local Git Configuration**: User name and email configured

### Azure DevOps Setup (Optional but Recommended)

- [ ] **Azure DevOps Organization**: Access to matthiasbuchhorn organization
- [ ] **Project Access**: Permission to avm-alz-min project
- [ ] **Service Principal**: Created for automated deployments

## 🚀 Phase 1: Initial Setup and Validation

### Step 1: Environment Verification

```bash
# Verify Azure CLI installation and login
az --version
az login
az account show

# List available subscriptions
az account list --output table

# Set target subscription
az account set --subscription "your-subscription-id"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv) --scope /subscriptions/$(az account show --query id -o tsv)
```

### Step 2: Repository Cloning and Setup

```bash
# Clone the repository
git clone https://github.com/ma3u/azm-alz-min.git
cd azm-alz-min

# Verify repository structure
ls -la
tree . # If tree command available

# Check current branch
git branch
git status
```

### Step 3: Bicep Environment Setup

```bash
# Install/update Bicep CLI
az bicep install
az bicep upgrade

# Verify Bicep version
az bicep version

# Validate template syntax
az bicep build --file infra/main.bicep
```

### Step 4: Resource Provider Registration

```bash
# Register required resource providers
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Insights

# Verify registration status
az provider show --namespace Microsoft.KeyVault --query "registrationState"
```

## 🎛️ Phase 2: Configuration and Customization

### Step 1: Parameter File Customization

Review and customize the parameter file for your environment:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "namePrefix": {
      "value": "kv-yourorg" // Customize this prefix
    },
    "location": {
      "value": "West Europe" // Change if different region needed
    }
  }
}
```

**Parameter Guidelines:**

- `namePrefix`: 2-10 characters, alphanumeric only
- Combined name must be ≤24 characters total
- Choose region based on compliance requirements

### Step 2: Template Customization (Optional)

For advanced scenarios, you might want to customize the main template:

```bicep
// Example: Adding network restrictions
networkAcls: {
  bypass: 'AzureServices'
  defaultAction: 'Deny'  // Changed from 'Allow'
  ipRules: [
    {
      value: '203.0.113.0/24'  // Your organization's IP range
    }
  ]
}

// Example: Adding diagnostic settings
diagnosticSettings: [
  {
    name: 'default'
    workspaceId: '/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace}'
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
]
```

### Step 3: Resource Group Preparation

```bash
# Create resource group
RESOURCE_GROUP="rg-avm-alz-min-dev"
LOCATION="westeurope"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags \
    Project="Azure-Landing-Zone" \
    Environment="Development" \
    CostCenter="IT-Infrastructure" \
    Owner="Platform-Team"

# Verify resource group creation
az group show --name $RESOURCE_GROUP --output table
```

## 🏗️ Phase 3: Deployment Execution

### Step 1: Pre-deployment Validation

```bash
# Validate template and parameters
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Check validation result
echo $? # Should return 0 for success
```

### Step 2: What-If Analysis

```bash
# Preview deployment changes
az deployment group what-if \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --result-format FullResourcePayloads

# Review the output carefully before proceeding
```

### Step 3: Execute Deployment

```bash
# Deploy with detailed logging
DEPLOYMENT_NAME="keyvault-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --name $DEPLOYMENT_NAME \
  --verbose

# Monitor deployment progress
az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query "properties.provisioningState" \
  --output tsv
```

### Step 4: Deployment Verification

```bash
# Get deployment outputs
az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query "properties.outputs" \
  --output table

# Extract Key Vault name and URI
KV_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query "properties.outputs.keyVaultName.value" \
  --output tsv)

KV_URI=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query "properties.outputs.keyVaultUri.value" \
  --output tsv)

echo "Key Vault Name: $KV_NAME"
echo "Key Vault URI: $KV_URI"
```

## 🔐 Phase 4: Security Configuration and Validation

### Step 1: Access Policy Configuration

```bash
# Get your user object ID
USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)

# Assign Key Vault Administrator role
az role assignment create \
  --assignee $USER_OBJECT_ID \
  --role "Key Vault Administrator" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME"

# Verify role assignment
az role assignment list \
  --assignee $USER_OBJECT_ID \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
  --output table
```

### Step 2: Security Feature Validation

```bash
# Verify security features are enabled
az keyvault show --name $KV_NAME --query "properties" --output yamlc

# Check specific security settings
echo "Soft Delete Enabled: $(az keyvault show --name $KV_NAME --query "properties.enableSoftDelete" -o tsv)"
echo "Purge Protection: $(az keyvault show --name $KV_NAME --query "properties.enablePurgeProtection" -o tsv)"
echo "RBAC Authorization: $(az keyvault show --name $KV_NAME --query "properties.enableRbacAuthorization" -o tsv)"
```

### Step 3: Test Secret Operations

```bash
# Test secret creation (validates access)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "deployment-test-secret" \
  --value "test-deployment-$(date +%s)"

# Test secret retrieval
az keyvault secret show \
  --vault-name $KV_NAME \
  --name "deployment-test-secret" \
  --query "value" \
  --output tsv

# Clean up test secret
az keyvault secret delete \
  --vault-name $KV_NAME \
  --name "deployment-test-secret"
```

## 📊 Phase 5: Monitoring and Logging Setup

### Step 1: Enable Diagnostic Logging

```bash
# Create Log Analytics workspace (if not exists)
WORKSPACE_NAME="law-avm-alz-min"
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --location $LOCATION

# Get workspace resource ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query "id" \
  --output tsv)

# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name "keyvault-diagnostics" \
  --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
  --workspace $WORKSPACE_ID \
  --logs '[
    {
      "category": "AuditEvent",
      "enabled": true,
      "retentionPolicy": {
        "enabled": true,
        "days": 90
      }
    }
  ]' \
  --metrics '[
    {
      "category": "AllMetrics",
      "enabled": true,
      "retentionPolicy": {
        "enabled": true,
        "days": 90
      }
    }
  ]'
```

### Step 2: Configure Alerts

```bash
# Create action group for notifications
az monitor action-group create \
  --name "keyvault-alerts" \
  --resource-group $RESOURCE_GROUP \
  --action email admin your-email@example.com

# Create metric alert for failed authentication attempts
az monitor metrics alert create \
  --name "KeyVault-Failed-Auth" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
  --condition "count 'Microsoft.KeyVault/vaults' 'ServiceApiResult' where ResultType includes 'Unauthorized' > 5" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --action keyvault-alerts
```

## 🔄 Phase 6: CI/CD Pipeline Setup (Optional)

### Step 1: Azure DevOps Service Connection

If using Azure DevOps for automated deployments:

```bash
# Create service principal for Azure DevOps
SERVICE_PRINCIPAL_NAME="sp-avm-alz-devops"
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

SP_OUTPUT=$(az ad sp create-for-rbac \
  --name $SERVICE_PRINCIPAL_NAME \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth)

echo "Save this output for Azure DevOps service connection:"
echo $SP_OUTPUT
```

### Step 2: Pipeline Variable Configuration

Update the pipeline variables file:

```yaml
# pipelines/variables/common.yml
variables:
  - name: azureSubscriptionId
    value: 'your-actual-subscription-id'

  - name: azureRegion
    value: 'West Europe'

  - name: resourceGroupPrefix
    value: 'rg-avm-alz-min'
```

## 🧪 Phase 7: Testing and Validation

- Step 1: Functional Testing
- Step 2: Performance Testing

---

**Next Steps**: After successful deployment, consider implementing the [Azure DevOps CI/CD pipeline](./azure-devops-setup.md) for automated deployments.
