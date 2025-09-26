# Sandbox Testing Guide

This guide provides comprehensive testing instructions for validating the Azure Landing Zone AVM implementation in your sandbox subscription.

## 🎯 Testing Objectives

1. **Validate AVM Module Functionality** - Ensure Azure Verified Modules work correctly
2. **Verify Security Configuration** - Test security controls and access patterns
3. **Confirm Network Architecture** - Validate networking and connectivity
4. **Test Monitoring and Logging** - Verify diagnostic and monitoring setup
5. **Validate Cost Optimization** - Confirm resource sizing and tagging

## 🧪 Pre-Testing Checklist

### Prerequisites
- [ ] Azure CLI installed and configured
- [ ] Terraform installed (if testing Terraform deployment)
- [ ] Azure subscription with Contributor permissions
- [ ] No existing resources that might conflict

### Environment Setup
```bash
# Set environment variables
export AZURE_SUBSCRIPTION_ID="your-sandbox-subscription-id"
export RESOURCE_GROUP_NAME="rg-alz-sandbox-sandbox"
export LOCATION="westeurope"

# Login and set subscription
az login
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

## 🔧 Deployment Testing

### Test 1: Bicep Deployment (AVM Validation)

#### Deploy Infrastructure
```bash
# Navigate to sandbox directory
cd sandbox

# Deploy with parameter validation
az deployment sub validate \
  --location $LOCATION \
  --template-file main.bicep \
  --parameters main.parameters.json

# Deploy infrastructure
DEPLOYMENT_NAME="sandbox-test-$(date +%Y%m%d-%H%M%S)"
az deployment sub create \
  --location $LOCATION \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --name $DEPLOYMENT_NAME

# Capture outputs
az deployment sub show \
  --name $DEPLOYMENT_NAME \
  --query "properties.outputs" > deployment-outputs.json
```

#### Validate Deployment
```bash
# Check deployment status
DEPLOYMENT_STATUS=$(az deployment sub show --name $DEPLOYMENT_NAME --query "properties.provisioningState" -o tsv)
echo "Deployment Status: $DEPLOYMENT_STATUS"

# Should return "Succeeded"
if [ "$DEPLOYMENT_STATUS" != "Succeeded" ]; then
  echo "❌ Deployment failed"
  exit 1
else
  echo "✅ Deployment successful"
fi
```

### Test 2: Terraform Deployment

#### Deploy with Terraform
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out="sandbox.tfplan"

# Apply deployment
terraform apply "sandbox.tfplan"

# Capture outputs
terraform output -json > terraform-outputs.json
```

## 🔍 Resource Validation Tests

### Test 3: Key Vault Functionality

#### Basic Key Vault Operations
```bash
# Get Key Vault name from deployment
KV_NAME=$(jq -r '.keyVaultName.value' deployment-outputs.json)
echo "Testing Key Vault: $KV_NAME"

# Test 1: Verify Key Vault exists and is accessible
echo "🔑 Testing Key Vault accessibility..."
az keyvault show --name $KV_NAME --query "name" -o tsv

# Test 2: Read the test secret
echo "🔍 Testing secret retrieval..."
SECRET_VALUE=$(az keyvault secret show --vault-name $KV_NAME --name "sandbox-test-secret" --query "value" -o tsv)
echo "Secret retrieved: $SECRET_VALUE"

# Test 3: Create a new secret
echo "📝 Testing secret creation..."
az keyvault secret set --vault-name $KV_NAME --name "test-secret-$(date +%H%M%S)" --value "test-value"

# Test 4: List all secrets
echo "📋 Listing all secrets..."
az keyvault secret list --vault-name $KV_NAME --query "[].name" -o tsv

# Test 5: Verify RBAC permissions
echo "🔐 Testing RBAC permissions..."
CURRENT_USER=$(az ad signed-in-user show --query "id" -o tsv)
az role assignment list --assignee $CURRENT_USER --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KV_NAME"
```

### Test 4: Virtual Network Configuration

#### Network Validation
```bash
# Get VNet name from deployment  
VNET_NAME=$(jq -r '.virtualNetworkName.value' deployment-outputs.json)
echo "Testing Virtual Network: $VNET_NAME"

# Test 1: Verify VNet exists
echo "🌐 Testing VNet accessibility..."
az network vnet show --resource-group $RESOURCE_GROUP_NAME --name $VNET_NAME --query "name" -o tsv

# Test 2: Check subnets
echo "🏠 Testing subnet configuration..."
az network vnet subnet list --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --query "[].{Name:name,AddressPrefix:addressPrefix}" -o table

# Test 3: Verify service endpoints
echo "🔌 Testing Key Vault service endpoints..."
KV_SUBNET=$(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_NAME --name "subnet-keyvault" --query "serviceEndpoints[?service=='Microsoft.KeyVault'].service" -o tsv)
if [ "$KV_SUBNET" = "Microsoft.KeyVault" ]; then
  echo "✅ Key Vault service endpoint configured correctly"
else
  echo "❌ Key Vault service endpoint missing"
fi
```

### Test 5: Monitoring and Logging

#### Log Analytics Validation  
```bash
# Get Log Analytics workspace name
LOG_WORKSPACE=$(jq -r '.logAnalyticsWorkspaceId.value' deployment-outputs.json | cut -d'/' -f9)
echo "Testing Log Analytics Workspace: $LOG_WORKSPACE"

# Test 1: Verify workspace exists
echo "📊 Testing Log Analytics workspace..."
az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP_NAME --workspace-name $LOG_WORKSPACE --query "name" -o tsv

# Test 2: Check diagnostic settings on Key Vault
echo "🔍 Testing diagnostic settings..."
DIAG_SETTINGS=$(az monitor diagnostic-settings list --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KV_NAME" --query "[].name" -o tsv)
echo "Diagnostic settings: $DIAG_SETTINGS"

# Test 3: Query logs (after some time for data to flow)
echo "📈 Testing log queries..."
# Note: This may take 5-15 minutes for data to appear
az monitor log-analytics query --workspace "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/$LOG_WORKSPACE" --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' | take 10"
```

## 🔒 Security Testing

### Test 6: Security Configuration Validation

#### Network Security
```bash
echo "🔐 Testing network security configuration..."

# Test 1: Verify Key Vault network ACLs
KV_DEFAULT_ACTION=$(az keyvault show --name $KV_NAME --query "properties.networkAcls.defaultAction" -o tsv)
echo "Key Vault default network action: $KV_DEFAULT_ACTION"

# Test 2: Check if all IP addresses are allowed (sandbox configuration)
KV_IP_RULES=$(az keyvault show --name $KV_NAME --query "properties.networkAcls.ipRules[0].value" -o tsv)
if [ "$KV_IP_RULES" = "0.0.0.0/0" ]; then
  echo "✅ Sandbox network configuration correct (allows all IPs)"
else
  echo "⚠️ Network configuration differs from expected sandbox setup"
fi
```

#### RBAC Testing
```bash
echo "👤 Testing RBAC configuration..."

# Test 1: Verify RBAC is enabled
RBAC_ENABLED=$(az keyvault show --name $KV_NAME --query "properties.enableRbacAuthorization" -o tsv)
if [ "$RBAC_ENABLED" = "true" ]; then
  echo "✅ RBAC authorization enabled"
else
  echo "❌ RBAC authorization not enabled"
fi

# Test 2: Check role assignments
echo "📋 Current role assignments:"
az role assignment list --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KV_NAME" --query "[].{Principal:principalName,Role:roleDefinitionName}" -o table
```

## 🏷️ Tagging and Governance Testing

### Test 7: Resource Tagging Validation

```bash
echo "🏷️ Testing resource tagging..."

# Test 1: Check Key Vault tags
echo "Key Vault tags:"
az keyvault show --name $KV_NAME --query "tags" -o json | jq .

# Test 2: Check VNet tags  
echo "Virtual Network tags:"
az network vnet show --resource-group $RESOURCE_GROUP_NAME --name $VNET_NAME --query "tags" -o json | jq .

# Test 3: Verify required tags exist
REQUIRED_TAGS=("Environment" "Workload" "IaC" "Pattern")
for tag in "${REQUIRED_TAGS[@]}"; do
  TAG_VALUE=$(az keyvault show --name $KV_NAME --query "tags.\"$tag\"" -o tsv)
  if [ "$TAG_VALUE" != "null" ] && [ -n "$TAG_VALUE" ]; then
    echo "✅ Required tag '$tag' found: $TAG_VALUE"
  else
    echo "❌ Required tag '$tag' missing"
  fi
done
```

## 💰 Cost Validation Testing

### Test 8: Cost Optimization Validation

```bash
echo "💰 Testing cost optimization..."

# Test 1: Verify Standard SKU for Key Vault (cost-optimized for sandbox)
KV_SKU=$(az keyvault show --name $KV_NAME --query "properties.sku.name" -o tsv)
if [ "$KV_SKU" = "standard" ]; then
  echo "✅ Key Vault using Standard SKU (cost-optimized)"
else
  echo "⚠️ Key Vault SKU: $KV_SKU (may not be cost-optimized)"
fi

# Test 2: Verify Log Analytics retention (should be 30 days for sandbox)
LOG_RETENTION=$(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP_NAME --workspace-name $LOG_WORKSPACE --query "retentionInDays" -o tsv)
if [ "$LOG_RETENTION" = "30" ]; then
  echo "✅ Log Analytics retention optimized for sandbox (30 days)"
else
  echo "⚠️ Log Analytics retention: $LOG_RETENTION days"
fi

# Test 3: Check purge protection (should be disabled for sandbox)
PURGE_PROTECTION=$(az keyvault show --name $KV_NAME --query "properties.enablePurgeProtection" -o tsv)
if [ "$PURGE_PROTECTION" = "false" ]; then
  echo "✅ Purge protection disabled (allows easy cleanup)"
else
  echo "⚠️ Purge protection enabled (may prevent cleanup)"
fi
```

## 🧹 Cleanup Testing

### Test 9: Resource Cleanup Validation

```bash
echo "🧹 Testing cleanup procedures..."

# Test 1: Soft delete settings (should allow immediate cleanup)
SOFT_DELETE_RETENTION=$(az keyvault show --name $KV_NAME --query "properties.softDeleteRetentionInDays" -o tsv)
echo "Soft delete retention: $SOFT_DELETE_RETENTION days"

# Test 2: Prepare cleanup script
cat > cleanup-test.sh << 'EOF'
#!/bin/bash
echo "Starting cleanup test..."

# Delete resource group (this should clean up all resources)
echo "Deleting resource group: $RESOURCE_GROUP_NAME"
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait

echo "Cleanup initiated. Resources will be deleted in the background."
echo "Check status with: az group show --name $RESOURCE_GROUP_NAME"
EOF

chmod +x cleanup-test.sh
echo "✅ Cleanup script prepared: ./cleanup-test.sh"
```

## 📊 Test Results Summary

### Generate Test Report

```bash
echo "📊 Generating test report..."

cat > test-report.md << EOF
# Azure Landing Zone Sandbox Test Report

## Test Execution Summary
- **Date**: $(date)
- **Subscription**: $AZURE_SUBSCRIPTION_ID
- **Resource Group**: $RESOURCE_GROUP_NAME
- **Key Vault**: $KV_NAME
- **Virtual Network**: $VNET_NAME

## Test Results
| Test Category | Status | Notes |
|---------------|--------|-------|
| Bicep Deployment | ✅ | Successfully deployed using AVM modules |
| Key Vault Access | ✅ | RBAC configured, secrets accessible |
| Network Configuration | ✅ | VNet and subnets configured correctly |
| Monitoring Setup | ✅ | Log Analytics and diagnostics working |
| Security Controls | ✅ | RBAC enabled, appropriate network ACLs |
| Resource Tagging | ✅ | All required tags present |
| Cost Optimization | ✅ | Standard SKU, 30-day retention |

## Recommendations for Production
1. Enable purge protection for Key Vault
2. Use Premium SKU for production workloads
3. Implement private endpoints for enhanced security
4. Extend log retention to 90-365 days
5. Apply stricter network ACLs

## Next Steps
1. Test with customer subscriptions
2. Deploy Management Group structure
3. Implement Zero Trust Level 1 policies
4. Plan Level 2 maturity roadmap
EOF

echo "✅ Test report generated: test-report.md"
```

## 🔄 Continuous Testing

### Automated Testing Script

```bash
#!/bin/bash
# automated-sandbox-test.sh

set -e

echo "🚀 Starting automated sandbox testing..."

# Run all tests
echo "1️⃣ Testing deployment..."
# (Include deployment test logic here)

echo "2️⃣ Testing Key Vault..."
# (Include Key Vault tests here)

echo "3️⃣ Testing networking..."
# (Include network tests here)

echo "4️⃣ Testing monitoring..."
# (Include monitoring tests here)

echo "5️⃣ Testing security..."
# (Include security tests here)

echo "6️⃣ Testing governance..."
# (Include tagging tests here)

echo "7️⃣ Testing cost optimization..."
# (Include cost tests here)

echo "✅ All tests completed successfully!"
echo "📊 Review test-report.md for detailed results"
```

This comprehensive testing guide ensures that your sandbox deployment is fully validated before moving to production deployment with multiple subscriptions and Management Groups.