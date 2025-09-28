# Modern Azure Landing Zone Setup Guide

This guide walks through setting up the modernized hub-spoke architecture with Entra Private Access, eliminating VPN and Bastion dependencies.

## 🎯 Prerequisites

### Required Licenses

- **Microsoft Entra ID P1/P2** - For Conditional Access and Private Access
- **Azure subscription** with Owner or Contributor permissions
- **Microsoft Entra Private Access** - Part of Microsoft Entra Suite

### Tools Required

```bash
# Install required tools on macOS
brew install azure-cli
brew install jq
brew install terraform

# Install specific Terraform version for consistency
brew install terraform@1.9

# Create symlink as documented in WARP.md
sudo ln -sf $(brew --prefix terraform@1.9)/bin/terraform /usr/local/bin/terraform1.9
```

### Initial Setup

```bash
# Clone and navigate to project
cd /Users/ma3u/projects/azure-landingzone

# Login to Azure
az login
az account set --subscription "your-subscription-id"

# Verify Terraform version
terraform1.9 version  # Should show v1.9.x
```

## 🔑 Step 1: Set up CI/CD Secret Management

This is the foundational step that enables secure deployment coordination:

```bash
# Set up Azure Key Vault for CI/CD secrets
./scripts/setup-keyvault-cicd.sh

# Verify Key Vault deployment
az keyvault list --query "[?starts_with(name,'kv-alz-cicd')].{Name:name,Location:location}" -o table
```

**Expected Output:**

```
Name                Location
------------------  ----------
kv-alz-cicd-a7b8c9  westeurope
```

### Configure GitHub Repository Secrets

1. Navigate to your GitHub repository → Settings → Secrets and variables → Actions
2. Add the following repository secrets using content from `.secrets/github-azure-credentials.json`:

```json
AZURE_CREDENTIALS = {
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "..."
}
```

3. Additional secrets from Key Vault:

```bash
# Get the Key Vault name
KEY_VAULT_NAME=$(cat .secrets/keyvault-name.txt)

# Add these as GitHub repository secrets:
AZURE_SUBSCRIPTION_ID = "your-subscription-id"
AZURE_TENANT_ID = "your-tenant-id"
KEY_VAULT_NAME = "$KEY_VAULT_NAME"
```

### Configure Azure DevOps Service Connection

1. Navigate to Azure DevOps → Project Settings → Service connections
2. Create new service connection → Azure Resource Manager → Service principal (manual)
3. Use credentials from Key Vault:

```bash
# Retrieve service principal details
az keyvault secret show --vault-name $KEY_VAULT_NAME --name devops-sp-client-id --query value -o tsv
az keyvault secret show --vault-name $KEY_VAULT_NAME --name devops-sp-client-secret --query value -o tsv
az keyvault secret show --vault-name $KEY_VAULT_NAME --name devops-sp-tenant-id --query value -o tsv
```

## 🏗️ Step 2: Deploy Hub Infrastructure (Foundation)

Deploy the centralized hub services using modern AVM modules:

```bash
# Acquire deployment lock to prevent conflicts
./scripts/deployment-coordinator.sh acquire github sandbox

# Deploy hub infrastructure
az deployment sub create \
  --location westeurope \
  --template-file infra/bicep/hub/main.bicep \
  --parameters @infra/bicep/hub/main.parameters.json \
  --name "hub-deployment-$(date +%Y%m%d-%H%M%S)" \
  --verbose

# Release deployment lock
./scripts/deployment-coordinator.sh release github sandbox
```

**Hub Components Deployed:**

- Hub VNet (10.0.0.0/16) with optimized subnets
- Azure Firewall Premium with IDPS and TLS inspection
- Private DNS Resolver for hybrid DNS resolution
- Entra Private Access Connector (replaces VPN/Bastion)
- Log Analytics Workspace for centralized monitoring
- Managed identities for service authentication

## 🌐 Step 3: Configure Entra Private Access

Replace traditional VPN/Bastion with Zero Trust access:

### Enable Entra Private Access

1. Navigate to Entra admin center → Global Secure Access
2. Enable **Microsoft Entra Private Access**
3. Configure **Global Secure Access Connector**

### Deploy Private Access Connector

```bash
# Download and install connector on hub VM or container
# This replaces the need for Azure Bastion and VPN Gateway

# Create connector registration (automated via Bicep)
az deployment group create \
  --resource-group rg-alz-hub-sandbox \
  --template-file infra/bicep/private-access/connector.bicep \
  --parameters @infra/bicep/private-access/connector.parameters.json
```

### Configure Conditional Access Policies

```bash
# Create Conditional Access policy for admin access
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --body '{
    "displayName": "ALZ Admin Access - Require MFA and Compliant Device",
    "state": "enabled",
    "conditions": {
      "applications": {
        "includeApplications": ["Private-Access-App-ID"]
      },
      "users": {
        "includeGroups": ["ALZ-Administrators"]
      }
    },
    "grantControls": {
      "operator": "AND",
      "builtInControls": ["mfa", "compliantDevice"]
    }
  }'
```

## 🔧 Step 4: Deploy Application Infrastructure

Deploy the application spoke with compute services:

```bash
# Deploy application spoke
./scripts/deployment-coordinator.sh acquire github sandbox

az deployment sub create \
  --location westeurope \
  --template-file infra/bicep/spoke-app/main.bicep \
  --parameters @infra/bicep/spoke-app/main.parameters.json \
  --name "app-spoke-deployment-$(date +%Y%m%d-%H%M%S)" \
  --verbose

./scripts/deployment-coordinator.sh release github sandbox
```

**Application Components:**

- Application Spoke VNet (10.1.0.0/16) with VNet peering
- Application Gateway v2 with WAF and zone redundancy
- Azure Web Apps with VNet integration
- Container Apps environment for microservices
- Azure Functions Premium with private networking

## 💾 Step 5: Deploy Data Services with Private Endpoints

Secure all data services with private networking:

```bash
# Deploy data services
./scripts/deployment-coordinator.sh acquire github sandbox

az deployment sub create \
  --location westeurope \
  --template-file infra/bicep/data-services/main.bicep \
  --parameters @infra/bicep/data-services/main.parameters.json \
  --name "data-services-deployment-$(date +%Y%m%d-%H%M%S)" \
  --verbose

./scripts/deployment-coordinator.sh release github sandbox
```

**Data Components:**

- PostgreSQL Flexible Server with private networking
- Azure Storage Account with private endpoints
- Azure Container Registry Premium with private access
- Azure Key Vault with private endpoints
- Private DNS zones for all services

## 🛠️ Step 6: Deploy Management Infrastructure

Set up the management spoke for operations:

```bash
# Deploy management spoke
./scripts/deployment-coordinator.sh acquire github sandbox

az deployment sub create \
  --location westeurope \
  --template-file infra/bicep/spoke-mgmt/main.bicep \
  --parameters @infra/bicep/spoke-mgmt/main.parameters.json \
  --name "mgmt-spoke-deployment-$(date +%Y%m%d-%H%M%S)" \
  --verbose

./scripts/deployment-coordinator.sh release github sandbox
```

**Management Components:**

- Management Spoke VNet (10.2.0.0/16)
- Self-hosted DevOps agents for private deployments
- Monitoring and observability tools
- Backup and recovery services

## 🔒 Step 7: Security Hardening and Validation

Configure security policies and validate the deployment:

### Network Security Groups

```bash
# Apply NSG rules using AVM modules
./scripts/configure-network-security.sh

# Validate NSG rules
az network nsg list --query "[].{Name:name,Location:location,Rules:length(securityRules)}" -o table
```

### Private Endpoint Connectivity

```bash
# Test private endpoint connectivity
./scripts/test-private-endpoints.sh

# Expected output: All private endpoints should resolve to private IPs
nslookup your-storage-account.blob.core.windows.net  # Should return 10.1.11.x
nslookup your-keyvault.vault.azure.net              # Should return 10.1.13.x
```

### Entra Private Access Testing

```bash
# Test admin access through Private Access (no VPN needed)
./scripts/test-private-access.sh

# Verify Zero Trust compliance
./scripts/verify-zero-trust-compliance.sh
```

## 📊 Step 8: Configure Monitoring and Alerting

Set up comprehensive monitoring:

```bash
# Deploy monitoring configuration
az deployment group create \
  --resource-group rg-alz-hub-sandbox \
  --template-file infra/bicep/monitoring/main.bicep \
  --parameters @infra/bicep/monitoring/main.parameters.json
```

### Key Monitoring Components:

- **Log Analytics Workspace**: Centralized logging
- **Application Insights**: Application performance monitoring
- **Azure Monitor Alerts**: Proactive alerting
- **Network Watcher**: Network connectivity monitoring
- **Security monitoring**: Sentinel integration

## 🧪 Step 9: Testing and Validation

Comprehensive testing of the deployed architecture:

### End-to-End Connectivity Tests

```bash
# Test public application access
curl -I https://your-app-gateway-fqdn.com  # Should return 200 OK

# Test private admin access (through Entra Private Access)
# Access Azure portal → Private endpoints → Test connectivity

# Test cross-spoke communication
./scripts/test-cross-spoke-connectivity.sh
```

### Security Validation

```bash
# Verify no public IPs on backend services
az network public-ip list --query "[?contains(name,'backend') || contains(name,'data')].{Name:name,IP:ipAddress}" -o table
# Should return empty result

# Verify all services use private endpoints
az network private-endpoint list --query "[].{Name:name,Service:privateLinkServiceConnections[0].privateLinkServiceId}" -o table
```

### Performance Testing

```bash
# Load test the application
az load test create \
  --name "alz-load-test" \
  --test-plan-file tests/load-test-plan.yaml

# Monitor results in Application Insights
```

## 🚀 Step 10: CI/CD Pipeline Testing

Test the coordinated deployment system:

### Trigger GitHub Actions

```bash
# Make a change to trigger GitHub Actions
echo "# Test change" >> README.md
git add . && git commit -m "Test GitHub Actions deployment"
git push origin main

# Monitor the pipeline in GitHub Actions tab
# Should see deployment lock acquisition and release
```

### Trigger Azure DevOps Pipeline

```bash
# Queue a manual build in Azure DevOps
# Should see conflict prevention if GitHub Actions is running
# Should succeed if no other deployments are active
```

### Test Deployment Coordination

```bash
# Manually test the coordination system
./scripts/test-coordination.sh

# Expected output: All coordination tests should pass
```

## ✅ Verification Checklist

### Network Architecture ✅

- [ ] Hub VNet deployed with Azure Firewall Premium
- [ ] Application spoke VNet deployed with services
- [ ] Management spoke VNet deployed with tools
- [ ] VNet peering established between hub and spokes
- [ ] Private DNS resolution working across VNets

### Security ✅

- [ ] No public IP addresses on backend services
- [ ] All data services use private endpoints
- [ ] Entra Private Access configured (no VPN/Bastion)
- [ ] NSG rules applied and validated
- [ ] Azure Firewall rules configured and tested

### Applications ✅

- [ ] Web Apps accessible via Application Gateway
- [ ] Container Apps deployed and scaled
- [ ] Functions executing with VNet integration
- [ ] Database connectivity through private networking
- [ ] Storage access via private endpoints

### CI/CD ✅

- [ ] GitHub repository secrets configured
- [ ] Azure DevOps service connection working
- [ ] Deployment coordination preventing conflicts
- [ ] Both pipelines can deploy successfully (when not conflicting)

### Monitoring ✅

- [ ] Log Analytics collecting logs from all services
- [ ] Application Insights monitoring app performance
- [ ] Azure Monitor alerts configured
- [ ] Security monitoring active

## 🎉 Success!

Your modern Azure Landing Zone is now fully deployed with:

- ✅ **Zero Trust Security**: Entra Private Access replaces VPN/Bastion
- ✅ **Private Networking**: All backend services use private endpoints
- ✅ **AVM Modules**: Latest Microsoft-verified infrastructure patterns
- ✅ **Coordinated CI/CD**: GitHub Actions and Azure DevOps coordination
- ✅ **Cost Optimized**: Right-sized services for sandbox environment
- ✅ **Highly Available**: Zone-redundant services where appropriate

## 📞 Next Steps

1. **Production Planning**: Scale up SKUs for production workloads
2. **Additional Spokes**: Add more application spokes as needed
3. **Advanced Monitoring**: Configure custom dashboards and alerting
4. **Security Baseline**: Apply additional security policies as needed
5. **Disaster Recovery**: Configure cross-region replication

## 🚨 Important Notes

- **No VPN Client Required**: Admin access works from any location with Entra Private Access
- **No Azure Bastion Costs**: Eliminated by using modern identity-based access
- **Deployment Coordination**: Always use the coordination scripts to prevent conflicts
- **Security First**: All services are private by default with identity-based access control
- **Cost Monitoring**: Monitor costs regularly and optimize based on usage patterns

Your landing zone now represents a modern, secure, and cost-effective foundation for Azure workloads! 🚀
