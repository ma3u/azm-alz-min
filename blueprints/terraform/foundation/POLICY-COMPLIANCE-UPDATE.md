# Policy Compliance Update - October 2024

## 🔄 Configuration Updates

This document outlines the configuration changes made to ensure compliance with DEP (Development Environment Policy) restrictions for PER-SBX (sandbox) environments.

### 📋 Changes Summary

| Component                  | Previous Value  | Updated Value        | Reason                                   |
| -------------------------- | --------------- | -------------------- | ---------------------------------------- |
| **App Service Plan SKU**   | EP1             | B1                   | Compliance with PER-SBX allowed SKUs     |
| **AKS Kubernetes Version** | 1.31            | 1.27                 | Latest stable non-preview version        |
| **Deployment Tag**         | Warp-AI-Sandbox | GithubAction-Sandbox | GitHub Actions deployment identification |

### 🏗️ App Service Plan SKU Compliance

According to DEP policy for **Development Environment (PER-SBX)**, the allowed SKUs are:

| Usage Type | Tier  | Allowed SKU | Description                                                                     |
| ---------- | ----- | ----------- | ------------------------------------------------------------------------------- |
| PER-SBX    | Free  | Free F1     | Practice usage, lightweight web applications, small-scale APIs, static websites |
| PER-SBX    | Basic | Basic B1    | ✅ **Selected for this deployment**                                             |
| PER-SBX    | Basic | Basic B2    | Alternative option                                                              |
| PER-SBX    | Basic | Basic B3    | Alternative option                                                              |

**Decision**: Selected **B1** as it provides a good balance of features and cost for development workloads while remaining compliant with policy restrictions.

### 🚀 AKS Version Update

- **Previous**: 1.31 (bleeding edge)
- **Current**: 1.27.102 (latest stable)
- **Rationale**: Using the latest stable, non-preview version for production readiness

### 🏷️ Deployment Tags

Updated deployment identification tags:

```hcl
locals {
  common_tags = {
    Environment  = var.environment
    Organization = var.organization_prefix
    Pattern      = "ALZ-Sandbox-Simple"
    IaC          = "Terraform-AVM-Simple"
    DeployedBy   = "GithubAction-Sandbox"  # Updated
    Purpose      = "Sandbox-Testing"
  }
}
```

## 🔐 Private AKS Cluster Access

The AKS cluster is configured as a private cluster for security. Access options:

### Option 1: VM in Same VNet (Recommended)

```bash
# Create a VM in the same VNet for cluster management
az vm create \
  --resource-group rg-alz-spoke-sandbox \
  --name vm-aks-jumpbox \
  --vnet-name vnet-alz-spoke-sandbox \
  --subnet snet-private-endpoints \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys
```

### Option 2: AKS Command Invoke

```bash
# Use command invoke feature (requires cluster to be running)
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name aks-alz-sandbox-<unique-suffix> \
  --command "kubectl get nodes"
```

### Option 3: Virtual Network Peering

Set up VNet peering between your management network and the AKS cluster VNet following [Microsoft documentation](https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cazure-portal#options-for-connecting-to-the-private-cluster).

## 📊 Resource Overview

### Core Infrastructure

- **Hub VNet**: 10.0.0.0/16

  - Bastion Subnet: 10.0.1.0/24
  - Shared Services: 10.0.3.0/24
  - ACR Private Endpoints: 10.0.4.0/24
  - Gateway Subnet: 10.0.100.0/24

- **Spoke VNet**: 10.1.0.0/16
  - Web Apps: 10.1.2.0/24
  - Private Endpoints: 10.1.11.0/24
  - AKS Nodes: 10.1.20.0/22 (1024 IPs)

### AKS Configuration

- **Version**: 1.27.102
- **Type**: Private cluster
- **System Node Pool**: 2x Standard_d4s_v5
- **User Node Pool**: 2x Standard_d4s_v5
- **Network Plugin**: Azure CNI
- **Network Policy**: Azure
- **Monitoring**: Log Analytics + Key Vault Secrets Provider

## 🚦 GitHub Actions Integration

The configuration is optimized for GitHub Actions deployment with:

- Proper service principal authentication
- Resource group targeting
- Policy-compliant resource specifications
- Comprehensive tagging strategy

## ✅ Next Steps

1. **Clean up existing resources**: `terraform destroy`
2. **Commit changes to GitHub**: Updated configuration files
3. **Trigger GitHub Actions**: Monitor deployment via workflow
4. **Verify deployment**: Check resources in Azure portal
5. **Set up cluster access**: Choose appropriate access method
6. **Test connectivity**: Validate AKS cluster functionality

## 📚 References

- [Azure App Service Plan Pricing](https://azure.microsoft.com/en-us/pricing/details/app-service/windows/)
- [AKS Private Clusters](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
- [AKS Supported Versions](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)
- [DEP Policy Documentation](https://docs.dep.soprasteria.com/docs/platforms/azure/restriction-policies/)
