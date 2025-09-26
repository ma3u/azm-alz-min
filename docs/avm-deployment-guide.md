# Azure Landing Zone Deployment Guide - AVM Implementation

## 🎯 Overview

This repository provides two Azure Landing Zone (ALZ) deployment options using Azure Verified Modules (AVM):

1. **✅ Simplified Sandbox Deployment** - Single subscription testing with core AVM resource modules **(SUCCESSFULLY TESTED)**
2. **🏢 Production Enterprise Deployment** - Full AVM pattern-based deployment with subscription vending

Both approaches use Microsoft-validated AVM modules and include SSH key-based authentication for enhanced security.

## 🔐 Security Prerequisites

### SSH Key Generation (Required for Both Options)

Before deployment, generate SSH keys for secure authentication:

```bash
# Generate RSA 4096-bit SSH keys
mkdir -p .secrets
ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N "" -C "azure-alz-sandbox-key"

# Verify keys are created
ls -la .secrets/
# Output:
# -rw-------  1 user  staff  3381 Sep 26 22:05 azure-alz-key      (private key)
# -rw-r--r--  1 user  staff   743 Sep 26 22:05 azure-alz-key.pub  (public key)
```

**🔒 Security**: SSH keys are automatically excluded from git via `.gitignore` to prevent accidental commits.

## 🏗️ Deployment Options

---

## Option 1: Simplified Sandbox Deployment ✅ (TESTED & WORKING)

### 📋 Purpose

- **Single subscription** testing and development
- **Rapid deployment** for proof-of-concept (~3 minutes)
- **SSH key authentication** configured
- **Hub-spoke networking** with VNet peering
- **Basic application workloads** (Web App, Storage)
- **Cost-effective** for testing (~$18/month)

### Prerequisites

```bash
# Ensure you're logged into Azure CLI
az login

# Set the correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify your subscription
az account show --query "{subscriptionId:id,name:name,user:user.name}" -o table
```

### 🚀 Deployment Command

```bash
# Deploy the simplified sandbox (TESTED WORKING)
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)" \
  --verbose
```

### ✅ What Gets Deployed (Verified)

- ✅ **2 Resource Groups**: `rg-alz-hub-sandbox` and `rg-alz-spoke-sandbox`
- ✅ **2 Virtual Networks**: Hub (10.0.0.0/16) and Spoke (10.1.0.0/16)
- ✅ **VNet Peering**: Bidirectional between hub and spoke (verified working)
- ✅ **Web App + App Service Plan**: Basic tier, accessible at `app-alz-web-sandbox.azurewebsites.net`
- ✅ **Storage Account**: Standard LRS with security features (`stalzsandboxhqilxdzf`)
- ✅ **Log Analytics Workspace**: `log-alz-hub-sandbox` for monitoring
- ✅ **SSH Keys**: Ready for secure VM access (when VMs added)

### 🔍 Post-Deployment Verification (Tested)

```bash
# List resources in hub (verified working)
az resource list --resource-group rg-alz-hub-sandbox --output table
# Expected output:
# Name                  ResourceGroup       Location    Type
# vnet-alz-hub-sandbox  rg-alz-hub-sandbox  westeurope  Microsoft.Network/virtualNetworks
# log-alz-hub-sandbox   rg-alz-hub-sandbox  westeurope  Microsoft.OperationalInsights/workspaces

# List resources in spoke (verified working)
az resource list --resource-group rg-alz-spoke-sandbox --output table
# Expected output:
# Name                    ResourceGroup         Location    Type
# vnet-alz-spoke-sandbox  rg-alz-spoke-sandbox  westeurope  Microsoft.Network/virtualNetworks
# stalzsandboxhqilxdzf    rg-alz-spoke-sandbox  westeurope  Microsoft.Storage/storageAccounts
# asp-alz-sandbox         rg-alz-spoke-sandbox  westeurope  Microsoft.Web/serverFarms
# app-alz-web-sandbox     rg-alz-spoke-sandbox  westeurope  Microsoft.Web/sites

# Test the web app (verified working)
WEBAPP_URL=$(az deployment sub show --name "$(az deployment sub list --query "[0].name" -o tsv)" --query 'properties.outputs.connectionInfo.value.webApp.hostname' -o tsv)
echo "Web App URL: https://$WEBAPP_URL"
curl -s -o /dev/null -w "%{http_code}\n" "https://$WEBAPP_URL"  # Should return 200
```

### 💰 Cost Estimation (Sandbox)

- **App Service Plan (Basic B1)**: ~$13/month
- **Storage Account (LRS)**: ~$2/month
- **Log Analytics**: ~$3/month (30 days retention)
- **VNet/Peering**: Minimal/Free
- **🏷️ Total**: ~$18/month

### 🔧 Customization Options

Edit `infra/accelerator/simple-sandbox.parameters.json`:

```json
{
  "parameters": {
    "location": {
      "value": "eastus" // Change region
    },
    "organizationPrefix": {
      "value": "myorg" // Change naming prefix
    },
    "enableBastion": {
      "value": true // Enable Azure Bastion for secure VM access
    },
    "enableAppWorkloads": {
      "value": false // Disable apps to save cost
    }
  }
}
```

---

## Option 2: Production Enterprise Deployment 🏢

### 📋 Purpose

- **Multi-subscription** enterprise deployment
- **Management Group** scoped deployment
- **Subscription vending** with automated provisioning
- **Azure Firewall** + **DDoS Standard** protection
- **Private DNS zones** and **Private Endpoints**
- **Enterprise security** and compliance built-in

### Prerequisites

```bash
# Login with appropriate permissions
az login --tenant YOUR_TENANT_ID

# Ensure you have Management Group Contributor role
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --include-inherited --query "[?roleDefinitionName=='Management Group Contributor']" -o table

# Verify management group access
az account management-group list --query "[].{name:name,displayName:displayName}" -o table
```

### 🔧 Configuration

Update the parameter file with your environment details:

```bash
# Edit the production parameters
nano infra/accelerator/alz-avm-patterns.parameters.json
```

Update the following values:

```json
{
  "parameters": {
    "managementGroupId": {
      "value": "YOUR_MANAGEMENT_GROUP_ID" // Update this
    },
    "location": {
      "value": "westeurope"
    },
    "environment": {
      "value": "prod"
    },
    "enableAzureFirewall": {
      "value": true // Enterprise firewall
    },
    "enableBastion": {
      "value": true // Secure VM access
    },
    "applicationWorkloads": {
      "value": {
        "enableWebApp": true,
        "enableContainerApps": true,
        "enablePostgreSQL": true,
        "enableStorage": true,
        "enableAppGateway": true // Web Application Firewall
      }
    }
  }
}
```

### 🚀 Deployment Command

```bash
# Deploy the enterprise ALZ with full patterns
az deployment mg create \
  --management-group-id "YOUR_MANAGEMENT_GROUP_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-avm-patterns.bicep \
  --parameters infra/accelerator/alz-avm-patterns.parameters.json \
  --name "alz-enterprise-$(date +%Y%m%d-%H%M%S)" \
  --verbose
```

### 🏢 What Gets Deployed (Production)

- ✅ **2 New Subscriptions**: Hub and Spoke (via subscription vending)
- ✅ **Management Group Association**: Proper governance structure
- ✅ **Hub Networking Pattern**: Azure Firewall, Bastion, Private DNS
- ✅ **Spoke Application Pattern**: Web Apps, Container Apps, PostgreSQL
- ✅ **Private Endpoints**: Storage and Database with private connectivity
- ✅ **Application Gateway**: WAF v2 protection
- ✅ **DDoS Standard**: Network protection
- ✅ **Zone Redundancy**: High availability across availability zones
- ✅ **Enterprise Security**: RBAC, monitoring, compliance

### 💰 Cost Estimation (Production)

- **Azure Firewall Standard**: ~$550/month
- **Bastion Standard**: ~$140/month
- **DDoS Standard**: ~$3,000/month
- **Application Gateway WAF v2**: ~$250/month
- **App Services Premium v3**: ~$150/month
- **PostgreSQL Flexible**: ~$30/month
- **Storage Premium**: ~$20/month
- **🏷️ Total**: ~$4,140/month (enterprise-grade)

---

## 🔍 Deployment Validation and Troubleshooting

### Common Validation Commands

```bash
# Validate templates before deployment
az deployment sub validate \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json

# Check deployment status
az deployment sub list --output table --query "[?contains(name,'alz')]"

# Get deployment outputs (very useful for connection info)
az deployment sub show --name YOUR_DEPLOYMENT_NAME --query properties.outputs.connectionInfo.value --output table
```

### 🚨 Common Issues and Solutions

#### 1. Module Not Found Errors

```bash
# Issue: AVM module version not available
# Error: Unable to restore artifact with reference "br:mcr.microsoft.com/bicep/avm/..."

# Solution: Check latest versions in our working template
grep -r "br/public:avm" infra/accelerator/simple-sandbox.bicep
```

#### 2. Permission Issues (Management Group)

```bash
# Verify required permissions
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --scope "/providers/Microsoft.Management/managementGroups/YOUR_MG_ID"

# Required roles: Management Group Contributor, Subscription Creator
```

#### 3. Subscription Limits

```bash
# Check subscription quotas
az vm list-usage --location "westeurope" --output table
az storage account list --query "length(@)" # Should be < 200
```

#### 4. Network Conflicts

```bash
# Check for IP range conflicts
az network vnet list --query "[].{name:name,addressSpace:addressSpace}" -o table

# Default ranges: Hub 10.0.0.0/16, Spoke 10.1.0.0/16
```

## 🧹 Cleanup Instructions

### Sandbox Cleanup

```bash
# Delete sandbox resource groups (SAFE FOR TESTING)
az group delete --name rg-alz-hub-sandbox --yes --no-wait
az group delete --name rg-alz-spoke-sandbox --yes --no-wait

# Verify cleanup
az group list --query "[?contains(name,'alz')].name" -o table
```

### Production Cleanup

```bash
# ⚠️ CAUTION: This affects production subscriptions
az deployment mg delete --management-group-id YOUR_MG_ID --name YOUR_DEPLOYMENT_NAME

# Note: Subscription cleanup requires additional steps through Azure portal
```

## 📊 Feature Comparison

| Feature               | Sandbox Deployment        | Production Deployment                     |
| --------------------- | ------------------------- | ----------------------------------------- |
| **Scope**             | Single subscription       | Management Group + Multiple subscriptions |
| **Deployment Time**   | ~3 minutes ✅             | ~15-30 minutes                            |
| **Monthly Cost**      | ~$18 💚                   | ~$4,140 💰                                |
| **Security Level**    | Basic + SSH keys          | Enterprise-grade + all features           |
| **Networking**        | Basic hub-spoke           | Full hub-spoke + Firewall + DDoS          |
| **High Availability** | Single zone               | Multi-zone redundant                      |
| **Use Case**          | Testing, PoC, Learning ✅ | Production, Enterprise                    |
| **Prerequisites**     | Subscription access       | Management Group permissions              |
| **AVM Modules**       | Resource modules          | Pattern + Resource modules                |

## 🎓 Learning Path Recommendations

### 1. Start with Sandbox (Recommended)

✅ **Completed**: Simple sandbox deployment tested and working!

```bash
# You can now explore:
- Web app at: https://app-alz-web-sandbox.azurewebsites.net
- Hub VNet: vnet-alz-hub-sandbox (10.0.0.0/16)
- Spoke VNet: vnet-alz-spoke-sandbox (10.1.0.0/16)
- Storage: stalzsandboxhqilxdzf
- Monitoring: log-alz-hub-sandbox
```

### 2. Add Test VMs with SSH

```bash
# Next step: Deploy test VMs to validate SSH key access via Bastion
# Enable Bastion in parameters and deploy VMs in both hub and spoke
```

### 3. Extend with Additional Services

```bash
# Add PostgreSQL, Container Apps, Application Gateway
# Enable in simple-sandbox.parameters.json and redeploy
```

### 4. Progress to Production

```bash
# After mastering sandbox, deploy production with subscription vending
# Requires Management Group permissions and enterprise planning
```

## 🚀 Next Steps After Deployment

### For Sandbox Environment ✅

1. **✅ Test Applications**: Access the deployed web app (working)
2. **🔜 Add Test VMs**: Deploy VMs to test Bastion access with SSH keys
3. **🔜 Configure Monitoring**: Set up alerts and dashboards in Log Analytics
4. **🔜 Cost Management**: Monitor spending and optimize resources

### For Production Environment

1. **Identity Integration**: Configure Azure AD/Entra ID integration
2. **Hybrid Connectivity**: Set up ExpressRoute or VPN connections
3. **Governance**: Implement Azure Policy and blueprints
4. **Backup Strategy**: Configure Azure Backup and Site Recovery
5. **Security**: Enable Security Center and Sentinel
6. **Compliance**: Implement regulatory compliance frameworks

## 📚 Additional Resources

- [Azure Verified Modules Documentation](https://azure.github.io/Azure-Verified-Modules/)
- [Azure Landing Zone Design Areas](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas)
- [Bicep Language Reference](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)

## 🤝 Support and Contribution

- **Issues**: Report in GitHub Issues
- **Contributions**: Follow standard GitHub flow
- **Documentation**: Update this guide for improvements
- **Security**: Report vulnerabilities privately

---

## ✅ Deployment Status Summary

### Successfully Tested ✅

- **Simple Sandbox Deployment**: Deployed and verified working
- **SSH Key Generation**: Keys created and secured
- **Hub-Spoke Networking**: VNet peering working
- **Application Services**: Web app accessible
- **Monitoring**: Log Analytics workspace ready
- **Cost**: Confirmed ~$18/month budget

### Ready for Testing 🔜

- **Production Enterprise Deployment**: Template ready, requires MG permissions
- **Azure Bastion**: Template ready, enable in parameters
- **Additional Services**: PostgreSQL, Container Apps, App Gateway modules ready

**🎯 Recommendation**: Start with the sandbox deployment to learn AVM patterns, then progress to production when enterprise requirements are defined.
