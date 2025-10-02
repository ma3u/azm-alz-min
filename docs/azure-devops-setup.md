# Azure DevOps Setup Guide for Azure Landing Zone

This guide provides step-by-step instructions for setting up Azure DevOps CI/CD pipelines for your Azure Landing Zone project.

## 📋 Prerequisites

- **Azure DevOps Organization**: `matthiasbuchhorn`
- **Azure DevOps Project**: `avm-alz-min`
- **GitHub Repository**: [ma3u/azm-alz-min](https://github.com/ma3u/azm-alz-min)
- **Azure Subscription**: With Contributor permissions
- **Azure CLI**: Installed and configured

## 🏗️ Azure DevOps Project Structure

```
matthiasbuchhorn (Organization)
└── avm-alz-min (Project)
    ├── Repositories
    │   └── Connected to GitHub: ma3u/azm-alz-min
    ├── Pipelines
    │   └── azure-pipelines.yml (CI/CD Pipeline)
    ├── Library
    │   ├── Variable Groups
    │   └── Secure Files
    ├── Environments
    │   ├── avm-alz-min-dev
    │   └── avm-alz-min-prod
    └── Service Connections
        └── azure-service-connection-avm-alz-min
```

## 🔧 Step-by-Step Setup

### Step 1: Create Service Principal

First, create a Service Principal for Azure DevOps to deploy resources:

```bash
# Set variables
SUBSCRIPTION_ID="your-subscription-id"
SERVICE_PRINCIPAL_NAME="sp-avm-alz-min-devops"

# Create service principal
az ad sp create-for-rbac \
  --name "$SERVICE_PRINCIPAL_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth

# Save the output - you'll need it for the service connection
```

**Expected Output:**

```json
{
  "clientId": "xxxx-xxxx-xxxx-xxxx",
  "clientSecret": "xxxx-xxxx-xxxx-xxxx", // pragma: allowlist secret
  "subscriptionId": "xxxx-xxxx-xxxx-xxxx",
  "tenantId": "xxxx-xxxx-xxxx-xxxx"
}
```

### Step 2: Create Azure Service Connection

1. **Navigate to Azure DevOps**:

   - Go to [Azure DevOps](https://dev.azure.com/matthiasbuchhorn/avm-alz-min)

2. **Create Service Connection**:

   - Go to **Project Settings** → **Service connections**
   - Click **New service connection**
   - Select **Azure Resource Manager**
   - Choose **Service principal (manual)**

3. **Configure Connection**:

   - **Connection Name**: `azure-service-connection-avm-alz-min`
   - **Subscription ID**: Your Azure subscription ID
   - **Subscription Name**: Your subscription name
   - **Service Principal ID**: `clientId` from Step 1
   - **Service Principal Key**: `clientSecret` from Step 1
   - **Tenant ID**: `tenantId` from Step 1

4. **Verify and Save**:
   - Click **Verify** to test the connection
   - Grant access to all pipelines (or manage per pipeline)
   - Click **Save**

### Step 3: Create Variable Groups

1. **Navigate to Library**:

   - Go to **Pipelines** → **Library**
   - Click **+ Variable group**

2. **Create Dev Environment Variables**:

   ```yaml
   Name: azure-landingzone-dev
   Variables:
     - RESOURCE_GROUP_NAME: rg-avm-alz-min-dev
     - ENVIRONMENT_NAME: dev
     - KEY_VAULT_NAME_PREFIX: kv-dev
   ```

3. **Create Prod Environment Variables**:

   ```yaml
   Name: azure-landingzone-prod
   Variables:
     - RESOURCE_GROUP_NAME: rg-avm-alz-min-prod
     - ENVIRONMENT_NAME: prod
     - KEY_VAULT_NAME_PREFIX: kv-prod
   ```

4. **Create Common Variables**:
   ```yaml
   Name: azure-landingzone-common
   Variables:
     - AZURE_SUBSCRIPTION_ID: your-subscription-id
     - AZURE_REGION: West Europe
     - PROJECT_NAME: avm-alz-min
     - NOTIFICATION_EMAIL: matthias.buchhorn@example.com
   ```

### Step 4: Create Environments

1. **Navigate to Environments**:

   - Go to **Pipelines** → **Environments**
   - Click **New environment**

2. **Create Development Environment**:

   - **Name**: `avm-alz-min-dev`
   - **Description**: Development environment for Azure Landing Zone
   - **Resource**: None (we'll add Azure resources later)

3. **Create Production Environment**:

   - **Name**: `avm-alz-min-prod`
   - **Description**: Production environment for Azure Landing Zone
   - **Resource**: None

4. **Configure Approval Gates** (Production only):
   - Select `avm-alz-min-prod` environment
   - Click **Approvals and checks**
   - Add **Approvals** check
   - Add your user as an approver
   - Set minimum number of approvers to 1

### Step 5: Connect GitHub Repository

1. **Method 1: GitHub Integration (Recommended)**:

   - Go to **Project Settings** → **GitHub connections**
   - Click **Connect your GitHub account**
   - Authorize Azure DevOps to access your GitHub account
   - Select the repository: `ma3u/azm-alz-min`

2. **Method 2: Service Connection**:
   - Go to **Project Settings** → **Service connections**
   - Create new **GitHub** service connection
   - Use Personal Access Token for authentication

### Step 6: Create Pipeline

1. **Navigate to Pipelines**:

   - Go to **Pipelines** → **Pipelines**
   - Click **New pipeline**

2. **Select Repository**:

   - Choose **GitHub**
   - Select repository: `ma3u/azm-alz-min`
   - Authorize if prompted

3. **Configure Pipeline**:

   - Choose **Existing Azure Pipelines YAML file**
   - Select branch: `main`
   - Select path: `/pipelines/azure-pipelines.yml`

4. **Update Variables**:

   - Before running, update `pipelines/variables/common.yml`:

   ```yaml
   - name: azureSubscriptionId
     value: 'YOUR_ACTUAL_SUBSCRIPTION_ID'
   ```

5. **Save and Run**:
   - Click **Save and run**
   - Commit directly to main branch
   - Monitor the pipeline execution

## 🔒 Security Configuration

### Branch Protection

1. **Repository Settings** (on GitHub):

   - Go to repository **Settings** → **Branches**
   - Add rule for `main` branch:
     - Require pull request reviews
     - Require status checks to pass
     - Include administrators

2. **Azure DevOps Branch Policies**:
   - Go to **Repos** → **Branches**
   - Select `main` branch policies:
     - Require a minimum number of reviewers
     - Check for linked work items
     - Check for comment resolution

### Service Principal Permissions

```bash
# Assign additional permissions if needed
az role assignment create \
  --assignee "$SERVICE_PRINCIPAL_ID" \
  --role "Key Vault Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# For specific resource groups
az role assignment create \
  --assignee "$SERVICE_PRINCIPAL_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-avm-alz-min-dev"
```

## 🚀 Pipeline Features

### Continuous Integration (CI)

- **Triggers**: Commits to `main`, `develop`, `feature/*` branches
- **Path Filters**: Only runs when `infra/` or `pipelines/` change
- **Validation**: Bicep linting and ARM template generation
- **Security**: PSRule for Azure compliance scanning
- **Artifacts**: Publishes templates for deployment

### Continuous Deployment (CD)

- **Development**: Auto-deploy from `main` and `develop` branches
- **Production**: Auto-deploy from `main` with approval gate
- **What-If**: Shows changes before deployment
- **Validation**: Post-deployment testing
- **Rollback**: Manual rollback capability

### Security & Compliance

- **PSRule Scanning**: Azure security best practices
- **Template Validation**: ARM/Bicep syntax checking
- **Service Principal**: Least-privilege access
- **Secrets Management**: Azure Key Vault integration
- **Audit Trail**: Full deployment history

## 📊 Monitoring and Notifications

### Pipeline Notifications

1. **Email Notifications**:

   - Go to **Project Settings** → **Notifications**
   - Subscribe to build completion events
   - Configure for build failures

2. **Slack Integration** (Optional):
   ```yaml
   # Add to pipeline
   - task: SlackNotification@1
     inputs:
       SlackApiToken: '$(SlackToken)'
       Channel: '#devops'
       Message: 'Deployment completed: $(Build.DefinitionName)'
   ```

### Azure Monitor Integration

```yaml
# Add monitoring step to pipeline
- task: AzureCLI@2
  displayName: 'Configure Monitoring'
  inputs:
    azureSubscription: '$(azureServiceConnection)'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Enable diagnostic settings
      az monitor diagnostic-settings create \
        --name "pipeline-monitoring" \
        --resource "$KV_RESOURCE_ID" \
        --logs '[{"category": "AuditEvent", "enabled": true}]' \
        --workspace "$LOG_ANALYTICS_WORKSPACE_ID"
```

## 🔧 Troubleshooting

### Common Issues

1. **Service Connection Fails**:

   ```bash
   # Verify service principal permissions
   az role assignment list --assignee "$SERVICE_PRINCIPAL_ID"

   # Check subscription access
   az account show --subscription "$SUBSCRIPTION_ID"
   ```

2. **Pipeline Fails at Deployment**:

   - Check resource group exists
   - Verify service principal has Contributor role
   - Ensure subscription ID is correct

3. **What-If Analysis Fails**:
   ```bash
   # Test locally
   az deployment group what-if \
     --resource-group "rg-test" \
     --template-file "infra/main.bicep" \
     --parameters "infra/main.parameters.json"
   ```

### Debug Commands

```bash
# Check Azure CLI version in pipeline
az --version

# List available locations
az account list-locations --output table

# Validate template locally
az deployment group validate \
  --resource-group "rg-avm-alz-min-dev" \
  --template-file "infra/main.bicep" \
  --parameters "infra/main.parameters.json"
```

## 🎯 Best Practices

### Pipeline Design

- ✅ Use template-based deployments
- ✅ Implement proper approval gates
- ✅ Enable parallel jobs when possible
- ✅ Use artifact caching
- ✅ Implement proper error handling

### Security

- ✅ Use service principals (not personal accounts)
- ✅ Implement least-privilege access
- ✅ Store secrets in Azure Key Vault
- ✅ Enable audit logging
- ✅ Use branch protection policies

### Monitoring

- ✅ Set up build notifications
- ✅ Monitor deployment success rates
- ✅ Track deployment duration
- ✅ Implement health checks
- ✅ Use Azure Monitor integration

## 📚 Additional Resources

- [Azure DevOps Documentation](https://docs.microsoft.com/en-us/azure/devops/)
- [Azure Bicep in Azure DevOps](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cloud-shell)
- [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)
- [Azure Service Principal Best Practices](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)

---

**Next Steps**: After completing this setup, proceed to the [GitHub-Azure DevOps Sync Guide](./github-azuredevops-sync.md) for repository synchronization.
