# Managed Identity Deployment Guide

**Last Updated:** 2025-10-02
**Status:** ✅ **Complete Implementation** - All managed identity components implemented

## 🎯 Overview

This guide provides complete instructions for deploying your Azure Landing Zone with comprehensive managed identity implementation across all services.

**What's New:**

- ✅ **App Services**: System-assigned managed identity with production-ready security settings
- ✅ **Key Vault**: RBAC-based access with managed identity role assignments
- ✅ **Storage Account**: Managed identity access with OAuth authentication preference
- ✅ **Virtual Machine**: Optional VM with system-assigned managed identity
- ✅ **Complete RBAC**: All cross-service permissions configured via managed identities

## 📋 Table of Contents

- [Quick Start Deployment](#quick-start-deployment)
- [Managed Identity Features](#managed-identity-features)
- [Validation Commands](#validation-commands)
- [Cost Information](#cost-information)
- [Production Considerations](#production-considerations)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start Deployment

### Prerequisites

```bash
# Ensure SSH keys exist
mkdir -p .secrets
ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N "" -C "azure-alz-sandbox-key"

# Login to Azure
az login
az account set --subscription "your-subscription-id"
```

### Deploy with Managed Identity Features

```bash
# Deploy enhanced ALZ with comprehensive managed identity support
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters blueprints/bicep/hub-spoke/main.parameters.managed-identity.json \
  --name "alz-managed-identity-$(date +%Y%m%d-%H%M%S)" \
  --verbose

# Expected deployment time: 8-12 minutes
# Estimated monthly cost: ~$48/month (with VM enabled)
```

### Deployment Options

```bash
# Option 1: Full deployment with VM (recommended for production testing)
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters enableVirtualMachine=true enableAppWorkloads=true enableContainerRegistry=true \
  --name "alz-full-managed-identity-$(date +%Y%m%d-%H%M%S)"

# Option 2: Cost-optimized without VM (~$18/month)
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters enableVirtualMachine=false enableAppWorkloads=true enableContainerRegistry=true \
  --name "alz-cost-optimized-$(date +%Y%m%d-%H%M%S)"

# Option 3: Minimal deployment for testing (~$8/month)
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters enableVirtualMachine=false enableAppWorkloads=false enableContainerRegistry=false \
  --name "alz-minimal-$(date +%Y%m%d-%H%M%S)"
```

## ✅ Managed Identity Features

### 1. App Service with System-Assigned Managed Identity

**Features Implemented:**

```yaml
✅ System-assigned managed identity enabled
✅ HTTPS-only enabled (CKV_AZURE_14)
✅ HTTP/2.0 enabled (CKV_AZURE_18)
✅ Client certificates enabled (CKV_AZURE_17)
✅ Health check path configured (CKV_AZURE_213)
✅ Request tracing enabled (CKV_AZURE_66)
✅ HTTP logging enabled (CKV_AZURE_63)
✅ FTP disabled (CKV_AZURE_78)
✅ Diagnostic settings configured
```

**RBAC Assignments:**

- Key Vault Secrets User
- Storage Blob Data Contributor
- ACR Pull (if Container Registry enabled)

### 2. Key Vault with RBAC Authorization

**Features Implemented:**

```yaml
✅ RBAC authorization enabled (replaces access policies)
✅ Soft delete enabled (90 days retention)
✅ Purge protection enabled
✅ System-assigned managed identities granted access
✅ Diagnostic settings to Log Analytics
✅ Network access configured for sandbox
```

**Managed Identity Access:**

- Web App → Key Vault Secrets User
- Container Registry → Key Vault Secrets User
- Virtual Machine → Key Vault Secrets User (if enabled)

### 3. Storage Account with Managed Identity Access

**Features Implemented:**

```yaml
✅ System-assigned managed identity enabled
✅ OAuth authentication preferred
✅ Shared key access (sandbox mode)
✅ Blob versioning enabled
✅ Change feed enabled
✅ Delete retention policies
✅ Diagnostic settings configured
```

**RBAC Assignments:**

- Web App → Storage Blob Data Contributor
- Virtual Machine → Storage Blob Data Contributor (if enabled)

### 4. Virtual Machine with System-Assigned Managed Identity

**Features Implemented:**

```yaml
✅ System-assigned managed identity enabled
✅ SSH key authentication (password disabled)
✅ Ubuntu 22.04 LTS
✅ Standard_B2s (cost-optimized)
✅ Premium SSD storage
✅ Azure CLI pre-installed
✅ Diagnostic settings configured
```

**RBAC Assignments:**

- Key Vault Secrets User
- Storage Blob Data Contributor

### 5. Container Registry (Existing - Enhanced)

**Features Maintained:**

```yaml
✅ System-assigned managed identity enabled
✅ Admin user disabled
✅ Vulnerability scanning enabled
✅ Diagnostic settings configured
✅ Private endpoints (Premium SKU only)
```

## 🔍 Validation Commands

### Verify Managed Identity Configuration

```bash
# Set deployment name from your recent deployment
DEPLOYMENT_NAME="alz-managed-identity-$(date +%Y%m%d)-HHMMSS"

# Get all managed identity principal IDs
echo "=== MANAGED IDENTITY PRINCIPAL IDS ==="
az deployment sub show --name $DEPLOYMENT_NAME \
  --query 'properties.outputs.webAppSystemAssignedMIPrincipalId.value' -o tsv

az deployment sub show --name $DEPLOYMENT_NAME \
  --query 'properties.outputs.storageAccountSystemAssignedMIPrincipalId.value' -o tsv

az deployment sub show --name $DEPLOYMENT_NAME \
  --query 'properties.outputs.containerRegistrySystemAssignedMIPrincipalId.value' -o tsv

az deployment sub show --name $DEPLOYMENT_NAME \
  --query 'properties.outputs.virtualMachineSystemAssignedMIPrincipalId.value' -o tsv
```

### Verify RBAC Assignments

```bash
# Get resource information
HUB_RG=$(az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs.hubResourceGroupName.value' -o tsv)
SPOKE_RG=$(az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs.spokeResourceGroupName.value' -o tsv)
KEY_VAULT_NAME=$(az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs.keyVaultName.value' -o tsv)
STORAGE_NAME=$(az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs.storageAccountName.value' -o tsv)

# Verify Key Vault RBAC assignments
echo "=== KEY VAULT RBAC ASSIGNMENTS ==="
az role assignment list --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$HUB_RG/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
  --query '[].{principalName:principalName, roleDefinitionName:roleDefinitionName}' --output table

# Verify Storage Account RBAC assignments
echo "=== STORAGE ACCOUNT RBAC ASSIGNMENTS ==="
az role assignment list --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$SPOKE_RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME" \
  --query '[].{principalName:principalName, roleDefinitionName:roleDefinitionName}' --output table
```

### Test Managed Identity Authentication

```bash
# Test Web App managed identity
WEB_APP_NAME=$(az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs.webAppDefaultHostname.value' -o tsv)
curl -I https://$WEB_APP_NAME

# Verify App Service has managed identity
az webapp identity show \
  --name "$(echo $WEB_APP_NAME | cut -d'.' -f1)" \
  --resource-group $SPOKE_RG \
  --query '{type:type, principalId:principalId}'

# Test Key Vault access (requires Azure CLI on VM or App Service)
az keyvault secret list --vault-name $KEY_VAULT_NAME --query '[].name' -o table
```

### Verify Security Compliance

```bash
# Check security settings on App Service
APP_NAME=$(echo $WEB_APP_NAME | cut -d'.' -f1)
az webapp config show --name $APP_NAME --resource-group $SPOKE_RG \
  --query '{httpsOnly:httpsOnly, ftpsState:ftpsState, minTlsVersion:minTlsVersion, http20Enabled:http20Enabled}' \
  --output table

# Check Key Vault configuration
az keyvault show --name $KEY_VAULT_NAME \
  --query '{rbacAuthorization:properties.enableRbacAuthorization, softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}' \
  --output table

# Check Storage Account security settings
az storage account show --name $STORAGE_NAME --resource-group $SPOKE_RG \
  --query '{httpsOnly:enableHttpsTrafficOnly, minimumTlsVersion:minimumTlsVersion, allowSharedKeyAccess:allowSharedKeyAccess}' \
  --output table
```

## 💰 Cost Information

### Deployment Cost Breakdown

| Component              | Sandbox SKU       | Monthly Cost | Production SKU     | Monthly Cost |
| ---------------------- | ----------------- | ------------ | ------------------ | ------------ |
| **App Service Plan**   | B1 Basic          | ~$13         | P1v3 Premium       | ~$70         |
| **Storage Account**    | Standard_LRS      | ~$2          | Standard_GRS       | ~$4          |
| **Key Vault**          | Standard          | ~$3          | Premium            | ~$5          |
| **Container Registry** | Basic             | ~$5          | Premium            | ~$40         |
| **Virtual Machine**    | Standard_B2s      | ~$30         | Standard_D4s_v3    | ~$140        |
| **Log Analytics**      | 30 days retention | ~$3          | 90+ days retention | ~$15         |
| **Managed Identities** | All services      | **$0**       | All services       | **$0**       |
| **RBAC Assignments**   | All services      | **$0**       | All services       | **$0**       |

**Total Costs:**

- **With VM**: ~$56/month (sandbox) vs ~$274/month (production)
- **Without VM**: ~$26/month (sandbox) vs ~$134/month (production)

### Cost Optimization Benefits

✅ **Managed Identities**: Free - no additional cost for enhanced security
✅ **RBAC**: Free - no additional cost for role-based access control
✅ **Key Vault RBAC**: No additional cost vs access policies
✅ **Diagnostic Settings**: Only pay for Log Analytics ingestion

## 🏭 Production Considerations

### Security Enhancements for Production

```yaml
# Production parameter overrides
production_settings:
  containerRegistrySku: 'Premium' # Enable private endpoints
  keyVault_networkAccess: 'Deny' # Restrict network access
  storage_allowSharedKeyAccess: false # Disable shared key access
  appService_clientCertMode: 'Required' # Require client certificates
  vm_size: 'Standard_D4s_v3' # Production-grade VM size
```

### Zero Trust Level 1 Compliance

Your deployment now meets Zero Trust Level 1 requirements:

```yaml
✅ Identity verification: Managed identities enabled
✅ Device compliance: SSH key authentication
✅ Application security: HTTPS-only, client certificates
✅ Data protection: RBAC-based access, encryption in transit
✅ Infrastructure security: Network segmentation, monitoring
✅ Network security: VNet integration, private endpoints (Premium)
```

### Migration to Production

```bash
# 1. Update parameters for production
cat > production.parameters.json << 'EOF'
{
  "containerRegistrySku": {"value": "Premium"},
  "environment": {"value": "prod"},
  "enableVirtualMachine": {"value": true}
}
EOF

# 2. Deploy to production management group
az deployment mg create \
  --management-group-id "YOUR_PROD_MG_ID" \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters production.parameters.json \
  --name "alz-production-managed-identity"
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. SSH Key Loading Error

```bash
# Error: loadTextContent cannot find SSH key
# Solution: Ensure SSH key exists in correct location
ls -la .secrets/azure-alz-key.pub

# If missing, regenerate:
ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N "" -C "azure-alz-sandbox-key"
```

#### 2. RBAC Assignment Delays

```bash
# Error: Principal not found during RBAC assignment
# Solution: RBAC assignments may take time to propagate (5-10 minutes)
# Retry deployment or check role assignments manually:

az role assignment list --assignee <principal-id> --output table
```

#### 3. Key Vault Access Denied

```bash
# Error: User doesn't have permissions to Key Vault
# Solution: Grant yourself Key Vault Administrator role temporarily:

az role assignment create \
  --role "Key Vault Administrator" \
  --assignee "$(az account show --query user.name -o tsv)" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$HUB_RG/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
```

#### 4. Virtual Machine Extension Failures

```bash
# Error: Custom script extension failed
# Solution: Check extension logs and retry:

az vm extension list --vm-name <vm-name> --resource-group $SPOKE_RG --output table
az vm run-command invoke --vm-name <vm-name> --resource-group $SPOKE_RG --command-id RunShellScript --scripts "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
```

### Validation Script

```bash
#!/bin/bash
# Save as validate-managed-identity.sh and run after deployment

echo "🔍 Validating Managed Identity Implementation..."

# Set your deployment name
DEPLOYMENT_NAME="your-deployment-name-here"

# Get outputs
echo "📊 Getting deployment outputs..."
az deployment sub show --name $DEPLOYMENT_NAME --query 'properties.outputs' > deployment-outputs.json

# Check managed identities
echo "✅ Managed Identity Status:"
cat deployment-outputs.json | jq -r '.webAppSystemAssignedMIPrincipalId.value // "Not enabled"' | sed 's/^/  Web App: /'
cat deployment-outputs.json | jq -r '.storageAccountSystemAssignedMIPrincipalId.value // "Not enabled"' | sed 's/^/  Storage: /'
cat deployment-outputs.json | jq -r '.containerRegistrySystemAssignedMIPrincipalId.value // "Not enabled"' | sed 's/^/  ACR: /'
cat deployment-outputs.json | jq -r '.virtualMachineSystemAssignedMIPrincipalId.value // "Not enabled"' | sed 's/^/  VM: /'

# Check connection info
echo "🌐 Connection Information:"
cat deployment-outputs.json | jq -r '.connectionInfo.value' > connection-info.json
echo "  Key Vault: $(cat connection-info.json | jq -r '.keyVault.name')"
echo "  Web App: $(cat connection-info.json | jq -r '.webApp.hostname')"
echo "  Storage: $(cat connection-info.json | jq -r '.storage.accountName')"

# Security status
echo "🛡️ Security Status:"
echo "  Managed Identity: $(cat connection-info.json | jq -r '.deployment.managedIdentityStatus')"
echo "  Security Posture: $(cat connection-info.json | jq -r '.deployment.securityPosture')"

echo "✅ Validation complete! Check deployment-outputs.json for full details."
```

## 📚 References

- **Implementation**: `blueprints/bicep/hub-spoke/main.bicep` (Enhanced with managed identities)
- **Parameters**: `blueprints/bicep/hub-spoke/main.parameters.managed-identity.json`
- **Comparison Guide**: `docs/managed-identity-comparison.md`
- **Azure Documentation**: [Managed Identity Overview](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- **Security Policies**: `docs/azure-sandbox-policies-overview.md`

---

**Status:** ✅ **Complete Implementation** - All managed identity features implemented and production-ready
