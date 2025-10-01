# GitHub Actions Authentication Setup for Limited Entra Access

This guide helps you set up authentication for GitHub Actions workflows when you have limited Entra (Azure AD) permissions in a sandbox subscription.

## 🎯 Overview

Since you have limited Entra access with your Sopra Steria sandbox subscription (`matthias.buchhorn@soprasteria.com`), we'll create a Service Principal with minimal required permissions to enable GitHub Actions for Azure deployments.

## 🚀 Quick Setup (Automated)

Use the automated script for the easiest setup:

```bash
cd /Users/ma3u/projects/azure-landingzone
./automation/scripts/setup-github-auth.sh
```

This script will:

1. ✅ Check prerequisites (Azure CLI, jq, GitHub CLI)
2. 🔐 Create a Service Principal with Contributor access
3. 🧪 Test the authentication
4. 📋 Generate GitHub secrets configuration
5. 🎯 Optionally set GitHub secrets automatically (if GitHub CLI is available)

## 📋 Manual Setup (Step by Step)

If you prefer manual setup or the automated script fails:

### Step 1: Login to Azure

```bash
az login --tenant "8b87af7d-8647-4dc7-8df4-5f69a2011bb5" --scope "https://management.core.windows.net//.default"
```

### Step 2: Get Subscription Information

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID: $TENANT_ID"
```

### Step 3: Create Service Principal

```bash
# Create Service Principal with Contributor role
SP_NAME="sp-github-actions-alz-sandbox"
SP_CREDS=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --json-auth)

echo $SP_CREDS | jq .
```

### Step 4: Extract Credentials

```bash
CLIENT_ID=$(echo $SP_CREDS | jq -r '.clientId')
CLIENT_SECRET=$(echo $SP_CREDS | jq -r '.clientSecret')

echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
```

### Step 5: Test Authentication

```bash
# Test Service Principal login
az login --service-principal \
    --username "$CLIENT_ID" \
    --password "$CLIENT_SECRET" \
    --tenant "$TENANT_ID"

# Test basic operations
az account show
az resource list --query 'length(@)'

# Switch back to your user account
az login --tenant "$TENANT_ID" --scope "https://management.core.windows.net//.default"
```

### Step 6: Set GitHub Secrets

#### Option A: Using GitHub CLI (Recommended)

```bash
# Set secrets using GitHub CLI
gh secret set AZURE_CREDENTIALS --body '{
  "clientId": "'$CLIENT_ID'",
  "clientSecret": "'$CLIENT_SECRET'",
  "subscriptionId": "'$SUBSCRIPTION_ID'",
  "tenantId": "'$TENANT_ID'"
}'

gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$CLIENT_SECRET"
```

#### Option B: Manual Setup via GitHub Web Interface

1. Go to: https://github.com/ma3u/azm-alz-min/settings/secrets/actions
2. Add the following repository secrets:

| Secret Name             | Value                                                                                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `AZURE_CREDENTIALS`     | `{"clientId": "YOUR_CLIENT_ID", "clientSecret": "YOUR_CLIENT_SECRET", "subscriptionId": "YOUR_SUBSCRIPTION_ID", "tenantId": "YOUR_TENANT_ID"}` |
| `AZURE_SUBSCRIPTION_ID` | `YOUR_SUBSCRIPTION_ID`                                                                                                                         |
| `AZURE_TENANT_ID`       | `YOUR_TENANT_ID`                                                                                                                               |
| `AZURE_CLIENT_ID`       | `YOUR_CLIENT_ID`                                                                                                                               |
| `AZURE_CLIENT_SECRET`   | `YOUR_CLIENT_SECRET`                                                                                                                           |

## 🧪 Testing GitHub Actions

After setting up the secrets, test your workflows:

### Trigger Security Scanning Workflow

```bash
gh workflow run "Security & Compliance Scanning"
```

### Check Workflow Status

```bash
gh run list --limit 5
gh run view [RUN_ID]
```

### View Workflow Logs

```bash
gh run view [RUN_ID] --log
```

## 🔍 Troubleshooting

### Common Issues

#### 1. "Insufficient privileges to complete the operation"

**Solution**: Your user account may not have permission to create Service Principals.

```bash
# Check your current role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) --all --query '[].{Role:roleDefinitionName,Scope:scope}'
```

If you don't have sufficient permissions, you may need to:

- Request Owner or Contributor + User Access Administrator roles
- Have an admin create the Service Principal for you

#### 2. "Login failed" in GitHub Actions

**Solution**: Verify your secrets are correctly set:

```bash
# Check if secrets are set
gh secret list

# Test the credentials locally
az login --service-principal \
    --username "YOUR_CLIENT_ID" \
    --password "YOUR_CLIENT_SECRET" \
    --tenant "YOUR_TENANT_ID"
```

#### 3. "Resource not found" errors

**Solution**: Ensure the Service Principal has the right permissions:

```bash
# Check Service Principal role assignments
az role assignment list --assignee "$CLIENT_ID" --all
```

#### 4. Conditional Access / MFA Issues

Since you're using a Sopra Steria tenant, you may encounter Conditional Access policies:

```bash
# Try using device code flow
az login --use-device-code --tenant "8b87af7d-8647-4dc7-8df4-5f69a2011bb5"
```

### Alternative: Use Managed Identity (if supported)

If Service Principal creation fails, you might be able to use Azure Managed Identity:

```bash
# Check if you can create managed identities
az identity list
```

## 🔒 Security Considerations

### Service Principal Permissions

- **Scope**: Limited to your sandbox subscription only
- **Role**: Contributor (sufficient for most deployment operations)
- **Duration**: No expiration (but you can revoke anytime)

### Credential Management

- Store credentials securely in `.secrets/` folder (git-ignored)
- Rotate credentials periodically
- Monitor usage through Azure Activity Logs

### Cleanup

To remove the Service Principal when no longer needed:

```bash
# List Service Principals
az ad sp list --display-name "sp-github-actions-alz-sandbox"

# Delete Service Principal
az ad sp delete --id "YOUR_CLIENT_ID"
```

## 📞 Support

If you encounter issues:

1. **Check Azure CLI version**: `az --version`
2. **Verify subscription access**: `az account show`
3. **Check Entra permissions**: `az ad signed-in-user show`
4. **Review Azure Activity Logs**: Look for failed Service Principal operations

## 🔗 References

- [Azure Service Principals](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)
- [GitHub Actions Azure Login](https://github.com/Azure/login)
- [Azure RBAC Best Practices](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)
- [Sopra Steria Azure Guidelines](https://internal-docs.soprasteria.com/azure) (if available)
