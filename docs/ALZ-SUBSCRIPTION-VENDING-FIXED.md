# ALZ Subscription Vending - Fixed Implementation

**Last Updated:** 2025-09-28  
**Status:** ✅ **VALIDATED** - Template compiles successfully, ready for enterprise deployment

## 🎯 Purpose

This document provides **troubleshooting guidance and deployment instructions** for the enterprise ALZ subscription vending template using [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/).

**Target Audience:** Enterprise architects implementing multi-subscription Azure Landing Zones with Management Group governance.

**When to Use:** You need automated subscription creation and governance in an enterprise Azure environment.

## 📋 Table of Contents

- [✅ Fixed Issues Summary](#-fixed-issues-summary)
- [🚀 Quick Deployment](#-quick-deployment)
- [🔧 Configuration Options](#-configuration-options)
- [🚫 Troubleshooting](#-troubleshooting)
- [📚 Official Documentation](#-official-documentation)
- [📚 Related Documents](#-related-documents)

---

## ✅ Fixed Issues Summary

| Issue                               | Root Cause                                    | Solution                                                  |
| ----------------------------------- | --------------------------------------------- | --------------------------------------------------------- |
| **Duplicate Parameter Declaration** | Multiple `virtualNetworkSubnets` declarations | Consolidated using variables and conditional logic        |
| **Invalid Output References**       | Accessing non-existent module outputs         | Used available outputs and derived values from parameters |
| **Function Usage Errors**           | `utcNow()` used in invalid context            | Static deployment metadata values                         |
| **Parameter Schema Mismatch**       | Parameters didn't match AVM v0.4.0 schema     | Aligned with official sub-vending pattern specification   |

**Result:** ✅ Template compiles successfully and passes validation.

## 🚀 Quick Deployment

### Prerequisites

- Azure CLI with Bicep extension
- Management Group permissions for subscription creation
- EA/MCA billing account access
- Azure AD permissions for RBAC assignments

### Deploy Command

```bash
# Validate and deploy
az bicep build --file infra/accelerator/alz-subscription-vending-corrected.bicep

az deployment mg create \
  --management-group-id "YOUR_MG_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-subscription-vending-corrected.bicep \
  --parameters infra/accelerator/alz-subscription-vending-corrected.parameters.json \
  --parameters subscriptionBillingScope="YOUR_BILLING_SCOPE" \
  --name "alz-sub-vending-$(date +%Y%m%d-%H%M%S)"
```

**File Location:** `infra/accelerator/alz-subscription-vending-corrected.bicep` ✅

## 🔧 Configuration Options

### Key Parameters

- `managementGroupId`: Target management group for subscription
- `subscriptionDisplayName`: Display name for new subscription
- `subscriptionBillingScope`: EA/MCA billing scope path
- `enableVirtualNetwork`: Deploy ALZ-compliant VNet and subnets
- `enableBastion`: Deploy Azure Bastion for secure access
- `enableHubSpokeNetworking`: Enable peering to hub VNet

### Features Included

- **Subscription Creation**: Using AVM sub-vending pattern v0.4.0
- **ALZ-Compliant Networking**: Hub-spoke VNet with NSG rules
- **Security**: Azure Bastion, private endpoints, Zero Trust principles
- **Governance**: Resource tagging, RBAC integration, naming conventions

**Configuration Details:** See `infra/accelerator/alz-subscription-vending-corrected.parameters.json`

## 🚫 Troubleshooting

### Common Issues

| Issue                              | Solution                                          |
| ---------------------------------- | ------------------------------------------------- |
| **Billing Scope Format**           | Verify EA/MCA billing scope path format           |
| **Management Group Permissions**   | Ensure subscription creation permissions          |
| **Resource Provider Registration** | Allow 5-10 minutes for completion                 |
| **VNet Peering**                   | Verify hub VNet exists and has proper permissions |

### Quick Validation

```bash
# Template compilation
az bicep build --file infra/accelerator/alz-subscription-vending-corrected.bicep

# Check deployment status
az deployment mg list --management-group-id "YOUR_MG_ID" --output table
```

## 📚 Official Documentation

- **Primary:** [AVM Sub-vending Pattern](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/lz/sub-vending) - Official pattern module
- **Azure Verified Modules:** [AVM Registry](https://azure.github.io/Azure-Verified-Modules/) - Browse all AVM modules
- **Microsoft Learn:** [ALZ Documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) - Design guidance
- **Bicep Registry:** [Browse Modules](https://github.com/Azure/bicep-registry-modules) - Source code and docs

## 📚 Related Documents

- [AVM Deployment Guide](avm-deployment-guide.md) - Comprehensive ALZ deployment guide
- [AVM Modules Guide](avm-modules-guide.md) - Module reference and usage
- [Pre-commit Hooks Guide](pre-commit-hooks-guide.md) - Template validation setup
- [README.md](../README.md) - Main project overview

---

**Status:** ✅ **Production Ready** | **Template compiles successfully**
