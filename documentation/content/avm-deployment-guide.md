# AVM Deployment Guide

This guide provides **essential deployment steps** for Azure Landing Zones using Azure Verified Modules. For comprehensive Azure Landing Zone guidance, see [Microsoft's official ALZ documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/).

## 🎯 Purpose

Deploy production-ready Azure Landing Zones using Microsoft's [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) with:

- **Sandbox testing** - Single subscription (~$18/month)
- **Enterprise production** - Multi-subscription with governance
- **Security by design** - Zero Trust Level 1 compliance
- **AI-assisted development** - Warp integration support

## 📋 Table of Contents

- [⚡ Quick Deployment](#-quick-deployment)
- [🛠️ Prerequisites](#️-prerequisites)
- [🧪 Sandbox Option](#-sandbox-option)
- [🏢 Enterprise Option](#-enterprise-option)
- [🚫 Troubleshooting](#-troubleshooting)
- [📚 Official Documentation](#-official-documentation)
- [📚 Related Documents](#-related-documents)

---

## ⚡ Quick Deployment

### Prerequisites Setup

```bash
# Generate SSH keys (one-time setup)
mkdir -p .secrets
ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N "" -C "azure-alz-key"

# Login to Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Sandbox Deployment (Recommended Start)

```bash
# Deploy sandbox ALZ (~$18/month)
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)"
```

**Result:** Hub-spoke ALZ with Web App, Storage, Log Analytics, VNet peering

---

## 🛠️ Prerequisites

**Required Tools:**

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.50.0+)
- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) or [Terraform 1.9+](https://releases.hashicorp.com/terraform/)
- Azure subscription with Contributor permissions

**Permissions:**

- **Sandbox:** Subscription Contributor
- **Enterprise:** Management Group Contributor + Subscription Creator

---

## 🧪 Sandbox Option

**Purpose:** Single subscription testing (~$18/month)

### Deployment

```bash
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)"
```

### What's Included

- **Hub-spoke networking** (10.0.0.0/16, 10.1.0.0/16)
- **Web App + Storage** with security compliance
- **Log Analytics** workspace for monitoring
- **VNet peering** between hub and spoke

### Validation

```bash
# Check deployment
az resource list --resource-group rg-alz-hub-sandbox --output table

# Test web app
WEBAPP_URL=$(az deployment sub show --name "DEPLOYMENT_NAME" --query 'properties.outputs.connectionInfo.value.webApp.hostname' -o tsv)
curl -I "https://$WEBAPP_URL"  # Should return 200
```

### Cleanup

```bash
az group delete --name rg-alz-hub-sandbox --yes --no-wait
az group delete --name rg-alz-spoke-sandbox --yes --no-wait
```

---

## 🏢 Enterprise Option

**Purpose:** Multi-subscription production with governance

### Prerequisites

- Management Group Contributor role
- Subscription Creator permissions
- Enterprise Azure AD tenant

### Deployment

```bash
az deployment mg create \
  --management-group-id "YOUR_MG_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-subscription-vending-corrected.bicep \
  --parameters @infra/accelerator/alz-subscription-vending-corrected.parameters.json \
  --name "alz-enterprise-$(date +%Y%m%d-%H%M%S)"
```

### What's Included

- **Subscription vending** with automated provisioning
- **Azure Firewall + DDoS** protection
- **Private endpoints** and DNS zones
- **Application Gateway** with WAF
- **Enterprise governance** policies

**Cost:** ~$4,140/month (enterprise-grade features)

**Reference:** [Azure DevOps Setup](azure-devops-setup.md) for enterprise CI/CD

---

## 🚫 Troubleshooting

### Common Issues

**Template Validation:**

```bash
# Validate before deployment
az deployment sub validate \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json
```

**AVM Module Issues:**

- Check module versions in working templates
- Reference: [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules)

**Permission Errors:**

```bash
# Check subscription access
az account show --query "{subscriptionId:id,name:name}" -o table

# Verify management group permissions (enterprise)
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --include-inherited
```

**Network Conflicts:**

- Default ranges: Hub (10.0.0.0/16), Spoke (10.1.0.0/16)
- Check existing VNets: `az network vnet list --query "[].addressSpace" -o table`

**Detailed Solutions:** [Pre-commit Errors Analysis](pre-commit-errors-analysis.md)

---

## 📚 Official Documentation

### Microsoft Resources

- [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) - Complete ALZ guidance
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) - Official AVM documentation
- [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules) - Source code for all AVM Bicep modules
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/) - Architecture principles

### Deployment Guides

- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/deployment) - Deployment commands
- [Bicep Language](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) - Infrastructure as Code
- [Management Groups](https://docs.microsoft.com/en-us/azure/governance/management-groups/) - Enterprise governance

---

## 📚 Related Documents

- [Azure Sandbox Policies Overview](azure-sandbox-policies-overview.md) - Policy requirements and naming conventions
- [Pre-commit Hooks Guide](pre-commit-hooks-guide.md) - Code validation setup
- [Terraform Deployment Guide](terraform-deployment-guide.md) - Terraform-specific procedures
- [Zero Trust Maturity Roadmap](zero-trust-maturity-roadmap.md) - Security progression planning
- [Azure DevOps Setup](azure-devops-setup.md) - Enterprise CI/CD pipelines

---

**Last Updated:** 2025-09-28
**Purpose:** Essential Azure Landing Zone deployment using Azure Verified Modules
