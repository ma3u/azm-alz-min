# Azure Landing Zone - Key Vault Deployment

[![Build Status](https://dev.azure.com/your-org/your-project/_apis/build/status/azure-landingzone?branchName=main)](https://dev.azure.com/your-org/your-project/_build/latest?definitionId=YOUR_BUILD_ID&branchName=main)

This project provides Infrastructure as Code (IaC) for deploying a secure Azure Key Vault as part of an Azure Landing Zone using Bicep templates.

## 📁 Project Structure

```
azure-landingzone/
├── README.md                    # This file
├── infra/                       # Infrastructure templates
│   ├── main.bicep              # Main Bicep template
│   ├── main.parameters.json    # Parameters file
│   └── main.json              # Generated ARM template (auto-generated)
├── pipelines/                   # Azure DevOps pipeline configurations
│   ├── azure-pipelines.yml     # Main CI/CD pipeline
│   ├── templates/              # Pipeline templates
│   │   └── bicep-deploy.yml    # Reusable deployment template
│   └── variables/              # Variable templates
│       └── common.yml          # Common variables
└── docs/                       # Documentation
    └── deployment-guide.md     # Detailed deployment guide
```

## 🏗️ Infrastructure Components

### Key Vault Configuration
- **SKU**: Premium
- **Soft Delete**: Enabled (90 days retention)
- **Purge Protection**: Enabled
- **RBAC Authorization**: Enabled
- **Network Access**: Configurable (default: Allow all)
- **Tags**: Environment and Purpose tags applied

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and configured
2. **Bicep CLI** installed (via Azure CLI)
3. **Azure subscription** with appropriate permissions
4. **Resource Group** created in target Azure subscription

### Local Deployment

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd azure-landingzone
   ```

2. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Review and update parameters** (optional):
   ```bash
   # Edit parameters if needed
   code infra/main.parameters.json
   ```

4. **Validate the template**:
   ```bash
   az deployment group validate \
     --resource-group your-resource-group \
     --template-file infra/main.bicep \
     --parameters infra/main.parameters.json
   ```

5. **Preview changes** (What-If):
   ```bash
   az deployment group what-if \
     --resource-group your-resource-group \
     --template-file infra/main.bicep \
     --parameters infra/main.parameters.json
   ```

6. **Deploy**:
   ```bash
   az deployment group create \
     --resource-group your-resource-group \
     --template-file infra/main.bicep \
     --parameters infra/main.parameters.json \
     --name "keyvault-deployment-$(date +%Y%m%d-%H%M%S)"
   ```

## ⚙️ Configuration

### Parameters

The deployment accepts the following parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `namePrefix` | string | `kv-lz` | Prefix for Key Vault name (combined with unique string) |
| `location` | string | `resourceGroup().location` | Azure region for deployment |

### Customization

To customize the deployment:

1. **Modify parameters**:
   ```json
   {
     "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
       "namePrefix": {
         "value": "your-prefix"
       }
     }
   }
   ```

2. **Add network restrictions** (edit `main.bicep`):
   ```bicep
   networkAcls: {
     bypass: 'AzureServices'
     defaultAction: 'Deny'
     ipRules: [
       {
         value: 'your-ip-address/32'
       }
     ]
   }
   ```

3. **Add role assignments** (edit `main.bicep`):
   ```bicep
   roleAssignments: [
     {
       roleDefinitionIdOrName: 'Key Vault Administrator'
       principalId: 'your-user-or-service-principal-id'
       principalType: 'User' // or 'ServicePrincipal'
     }
   ]
   ```

## 🔄 Azure DevOps CI/CD Integration

### Setup Instructions

1. **Create Service Connection**:
   - Go to Project Settings → Service connections
   - Create new Azure Resource Manager connection
   - Use Service Principal (recommended) or Managed Identity
   - Name it `azure-service-connection`

2. **Create Variable Groups**:
   - Go to Pipelines → Library
   - Create variable group: `azure-landingzone-variables`
   - Add variables:
     - `AZURE_SUBSCRIPTION_ID`: Your subscription ID
     - `RESOURCE_GROUP_NAME`: Target resource group name
     - `AZURE_REGION`: Deployment region (e.g., westeurope)

3. **Set up Pipeline**:
   - Go to Pipelines → Create Pipeline
   - Select your repository
   - Choose "Existing Azure Pipelines YAML file"
   - Select `/pipelines/azure-pipelines.yml`

### Pipeline Features

The CI/CD pipeline includes:

- **Continuous Integration (CI)**:
  - Triggered on commits to `main` branch
  - Validates Bicep templates
  - Runs security scanning
  - Builds and publishes artifacts

- **Continuous Deployment (CD)**:
  - Deploys to Dev environment automatically
  - Manual approval gates for Prod deployment
  - What-If analysis before deployment
  - Deployment validation and smoke tests

### Pipeline Triggers

```yaml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - infra/*
      - pipelines/*
```

## 🔍 Monitoring and Validation

### Post-Deployment Validation

After deployment, validate the Key Vault:

```bash
# List deployments
az deployment group list --resource-group your-resource-group --output table

# Get Key Vault details
az keyvault show --name kv-lz-uniquestring --resource-group your-resource-group

# Test Key Vault access
az keyvault secret set --vault-name kv-lz-uniquestring --name test-secret --value "test-value"
az keyvault secret show --vault-name kv-lz-uniquestring --name test-secret
```

### Monitoring Resources

The deployed resources include:
- Azure Activity Log monitoring
- Key Vault diagnostic settings (can be configured)
- Resource tags for cost tracking and management

## 🛡️ Security Considerations

### Best Practices Implemented

1. **RBAC Authorization**: Uses Azure RBAC instead of access policies
2. **Soft Delete Protection**: Prevents accidental deletion
3. **Purge Protection**: Prevents permanent deletion during retention period
4. **Premium SKU**: Enhanced security features and HSM backing
5. **Tagging**: Proper resource tagging for governance

### Additional Security Recommendations

1. **Network Restrictions**:
   ```bicep
   networkAcls: {
     bypass: 'AzureServices'
     defaultAction: 'Deny'
     virtualNetworkRules: [/* your VNet rules */]
     ipRules: [/* your IP rules */]
   }
   ```

2. **Private Endpoints**: Configure private connectivity
3. **Monitoring**: Enable diagnostic logs and alerts
4. **Key Rotation**: Implement automated key rotation policies

## 🔧 Troubleshooting

### Common Issues

1. **Name Length Error**:
   ```
   Error: Length of the value should be less than or equal to '24'
   ```
   **Solution**: Ensure `namePrefix` + unique string ≤ 24 characters

2. **Permission Errors**:
   ```
   Error: Insufficient privileges to complete the operation
   ```
   **Solution**: Ensure service principal has `Contributor` role

3. **Template Validation Errors**:
   **Solution**: Run `az bicep build --file infra/main.bicep` to check syntax

### Getting Help

1. Check Azure Activity Log for detailed error messages
2. Use `az deployment group show` for deployment details
3. Validate templates with `az deployment group validate`
4. Review parameter files for template expressions

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push branch: `git push origin feature/new-feature`
5. Submit Pull Request

### Development Workflow

1. Make changes to Bicep templates
2. Test locally with `az deployment group what-if`
3. Validate with pipeline in feature branch
4. Create PR to `main` branch
5. Automated deployment after approval

## 📚 Additional Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Azure DevOps Pipeline Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Generated**: $(date)
**Version**: 1.0.0
**Maintainer**: Your Team Name