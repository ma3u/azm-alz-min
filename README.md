# AI-Powered GitOps for Azure Landing Zones with Azure Verified Modules

[![Build Status](https://dev.azure.com/your-org/your-project/_apis/build/status/azure-landingzone?branchName=main)](https://dev.azure.com/your-org/your-project/_build/latest?definitionId=YOUR_BUILD_ID&branchName=main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure Verified Modules](https://img.shields.io/badge/AVM-Verified-blue.svg)](https://azure.github.io/Azure-Verified-Modules/)

This repository demonstrates **AI-powered GitOps practices** for Azure Landing Zones using [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/). Based on the [LinkedIn article](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D), this project showcases modern infrastructure deployment patterns combining **GitOps principles**, **AI-assisted development**, and **enterprise-grade security**.

## 📑 Table of Contents

- [🎯 Why This Matters](#-why-this-matters)
- [📁 GitOps Repository Structure](#-gitops-repository-structure)
- [🏗️ The Azure Verified Modules (AVM) Evolution](#️-the-azure-verified-modules-avm-evolution)
- [🧪 Sandbox Testing (Single Subscription)](#-sandbox-testing-single-subscription)
  - [Quick Sandbox Deployment](#quick-sandbox-deployment)
  - [Terraform Deployment (Native Provider)](#terraform-deployment-native-provider)
  - [Deployment Results & Validation](#deployment-results--validation)
  - [Bicep vs Terraform: Side-by-Side Comparison](#bicep-vs-terraform-side-by-side-comparison)
  - [Sandbox Features](#sandbox-features)
  - [Cleanup Sandbox](#cleanup-sandbox)
- [🏭 Production Deployment (Multi-Subscription)](#-production-deployment-multi-subscription)
  - [Management Group Architecture](#management-group-architecture)
  - [Security Framework (Zero Trust Level 1)](#security-framework-zero-trust-level-1)
  - [Production Deployment Steps](#production-deployment-steps)
  - [Well-Architected Framework Alignment](#well-architected-framework-alignment)
- [🚀 GitOps Quick Start](#-gitops-quick-start)
  - [Prerequisites](#prerequisites)
  - [Installation Commands](#installation-commands)
  - [GitOps Deployment Paths](#-gitops-deployment-paths)
- [📖 User Manual: Testing ALZ AVM in Sandbox](#-user-manual-testing-alz-avm-in-sandbox)
  - [Test Environment Setup](#test-environment-setup)
  - [Test Case 1: AVM Storage Account Deployment](#test-case-1-avm-storage-account-deployment-)
  - [Test Case 2: AVM Key Vault Deployment](#test-case-2-avm-key-vault-deployment-policy-restricted-️)
  - [Test Case 3: Resource Cleanup and Validation](#test-case-3-resource-cleanup-and-validation-)
  - [AVM Benefits Demonstrated](#avm-benefits-demonstrated)
  - [Recommendations for Production Use](#recommendations-for-production-use)
  - [Testing Checklist](#testing-checklist)
  - [Troubleshooting Guide](#troubleshooting-guide)
  - [Conclusion](#conclusion)
- [🔄 GitOps Security Architecture](#-gitops-security-architecture)
- [🛡️ ArgoCD vs Flux: Security-First Comparison](#️-argocd-vs-flux-security-first-comparison)
- [⚙️ Configuration Examples](#️-configuration-examples)
- [💰 Cost Optimization & Resource Management](#-cost-optimization--resource-management)
- [🔄 Enterprise CI/CD Integration](#-enterprise-cicd-integration)
- [🔍 Monitoring and Validation](#-monitoring-and-validation)
- [🤖 Pre-commit Hooks & Code Quality](#-pre-commit-hooks--code-quality)
- [🛡️ Security Considerations](#️-security-considerations)
- [🔧 Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📈 Zero Trust Maturity Roadmap](#-zero-trust-maturity-roadmap)
- [🛡️ Compliance & Governance](#️-compliance--governance)
- [📚 Additional Resources](#-additional-resources)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)

## 🎯 Why This Matters

The evolution of cloud infrastructure has reached a inflection point where **GitOps meets AI-powered development**. This repository demonstrates how [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) - Microsoft's production-ready Infrastructure as Code modules - can be orchestrated through GitOps workflows enhanced by AI development tools like [Warp](https://warp.dev).

### Key Benefits

- ✅ **14+ Million Deployments**: AVM modules are battle-tested with Microsoft's full production support
- ✅ **AI-Enhanced Development**: Leverage Warp's context-aware assistance for faster infrastructure iteration
- ✅ **GitOps Security**: Immutable audit trail with declarative security policies
- ✅ **Multi-Platform Support**: Both Bicep and Terraform implementations
- ✅ **Enterprise Ready**: Built-in compliance, security scanning, and approval workflows

## 📁 GitOps Repository Structure

```
azure-landingzone/
├── README.md                           # This comprehensive guide
├── WARP.md                            # AI-assisted development guidance
│
├── infra/                             # Infrastructure as Code
│   ├── accelerator/                   # Original AVM accelerator templates
│   │   ├── simple-sandbox.bicep       # Original sandbox ALZ template
│   │   ├── simple-sandbox.parameters.json # Original sandbox configuration
│   │   ├── alz-avm-patterns.bicep     # Enterprise ALZ with subscription vending
│   │   └── alz-avm-patterns.parameters.json # Enterprise configuration
│   ├── bicep/                         # Organized Bicep modules
│   │   ├── main.bicep                 # Main Key Vault deployment
│   │   ├── main.parameters.json       # Environment parameters
│   │   └── sandbox/                   # Sandbox-specific templates
│   │       ├── main.bicep             # Sandbox ALZ main template
│   │       └── main.parameters.json   # Sandbox ALZ parameters
│   └── terraform/                     # Terraform implementations
│       ├── main.tf                    # Key Vault with AzureRM provider
│       ├── variables.tf               # Variable definitions
│       ├── outputs.tf                 # Output values
│       ├── terraform.tfvars.example   # Example variables
│       └── simple-sandbox/            # ALZ sandbox implementation
│           ├── main.tf                # Main ALZ infrastructure
│           ├── variables.tf           # Input variables with validation
│           ├── terraform.tfvars       # Default configuration values
│           ├── outputs.tf             # Resource outputs
│           └── cleanup.sh             # Automated cleanup script
│
├── .github/                           # GitHub Actions CI/CD
│   └── workflows/
│       ├── ci-bicep.yml              # Bicep validation and deployment
│       ├── ci-terraform.yml          # Terraform validation and deployment
│       └── security-scan.yml         # Security and compliance scanning
│
├── pipelines/                         # Azure DevOps CI/CD
│   ├── azure-pipelines.yml           # Multi-stage pipeline
│   ├── templates/                     # Reusable pipeline templates
│   │   ├── bicep-deploy.yml          # Bicep deployment template
│   │   └── terraform-deploy.yml       # Terraform deployment template
│   └── variables/                     # Environment variables
│       ├── common.yml                # Shared variables
│       ├── dev.yml                   # Development environment
│       └── prod.yml                  # Production environment
│
├── gitops/                           # GitOps Configurations
│   ├── flux/                         # Flux v2 GitOps
│   │   ├── clusters/                 # Cluster configurations
│   │   ├── apps/                     # Application definitions
│   │   └── infrastructure/           # Infrastructure components
│   └── argocd/                       # ArgoCD GitOps
│       ├── applications/             # ArgoCD Applications
│       ├── projects/                 # ArgoCD Projects
│       └── repositories/             # Repository configurations
├── docs/                             # Comprehensive documentation
    ├── deployment-guide.md           # Step-by-step deployment
    ├── terraform-deployment-guide.md # Terraform-specific deployment guide
    ├── terraform-cicd-guide.md       # Terraform CI/CD automation with GitHub Actions
    ├── pre-commit-hooks-guide.md     # Comprehensive pre-commit hooks for Bicep & Terraform
    ├── acr-vulnerability-scanning-guide.md # Container registry security guide
    ├── avm-deployment-guide.md       # AVM deployment strategies
    ├── avm-modules-guide.md          # AVM modules reference
    ├── gitops-setup.md               # GitOps configuration guide
    ├── ai-development.md             # AI-powered development workflow
    └── security-compliance.md        # Security and compliance practices
```

## 🏗️ The Azure Verified Modules (AVM) Evolution

[Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) has matured over 2 years with **14+ million deployments**. Microsoft is moving to Version 1 with full FTE support, making AVM the **single Microsoft standard** for Infrastructure as Code modules, replacing the previous Bicep Registry Modules approach.

### Why AVM for Production?

- ✅ **Production Ready**: 14+ million real-world deployments
- ✅ **Microsoft Support**: Full FTE team responsibility
- ✅ **Security First**: Built-in compliance and security best practices
- ✅ **Consistency**: Standardized patterns across all Azure services
- ✅ **Community**: Open-source with enterprise backing

### Infrastructure Components (AVM-Powered)

#### 🔐 Azure Key Vault (Premium)

```bicep
module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: 'keyVaultDeployment'
  params: {
    name: uniqueName
    location: location
    enableRbacAuthorization: true    // Modern RBAC instead of access policies
    enableSoftDelete: true           // 90-day retention for accidental deletion
    enablePurgeProtection: true      // Prevents permanent deletion
    sku: 'premium'                   // HSM-backed keys for enhanced security
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'          // Zero-trust network access
    }
  }
}
```

#### 🏢 Enterprise Features

- **RBAC Authorization**: Fine-grained access control using Azure AD
- **Soft Delete & Purge Protection**: 90-day retention, prevents accidental deletion
- **Premium SKU**: HSM-backed keys and enhanced security capabilities
- **Network Access Controls**: Zero-trust network policies
- **Comprehensive Tagging**: Environment, purpose, and cost center tracking

## 🧪 Sandbox Testing (Single Subscription)

**Perfect for validating AVM patterns before production deployment!**

The sandbox environment allows you to test all AVM patterns in your single subscription without requiring Management Group permissions or subscription management.

### Quick Sandbox Deployment

#### Option 1: Bicep (Recommended for AVM validation)

```bash
# 1. Login and set subscription
az login
az account set --subscription "your-sandbox-subscription-id"

# 2. Deploy sandbox infrastructure
az deployment sub create \
  --location "westeurope" \
  --template-file infra/bicep/sandbox/main.bicep \
  --parameters infra/bicep/sandbox/main.parameters.json \
  --name "sandbox-$(date +%Y%m%d-%H%M%S)"

# 3. Test the deployment
SANDBOX_KV=$(az deployment sub show --name "sandbox-YYYYMMDD-HHMMSS" --query "properties.outputs.keyVaultName.value" -o tsv)
echo "Testing Key Vault: $SANDBOX_KV"
az keyvault secret show --vault-name $SANDBOX_KV --name sandbox-test-secret
```

#### Option 2: Terraform (Infrastructure validation)

```bash
# 1. Navigate to sandbox directory
cd infra/terraform/simple-sandbox

# 2. Initialize and deploy
terraform1.9 init
terraform1.9 plan -var-file="terraform.tfvars" -out="sandbox.tfplan"
terraform1.9 apply "sandbox.tfplan"

# 3. Test the deployment
terraform1.9 output connection_info
```

### Terraform Deployment (Native Provider)

**⚡ Modern Terraform 1.9+ with Native Azure Provider**

For those who prefer Terraform, we provide a complete implementation using native Azure provider resources instead of AVM modules. This approach offers direct control and the latest Terraform features.

```bash
# 1. Upgrade Terraform to version 1.9+ (required)
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_darwin_arm64.zip
unzip terraform_1.9.8_darwin_arm64.zip
sudo mv terraform /usr/local/bin/terraform1.9
sudo chmod +x /usr/local/bin/terraform1.9

# 2. Navigate to Terraform sandbox directory
cd infra/terraform/simple-sandbox

# 3. Initialize and validate
terraform1.9 init
terraform1.9 validate

# 4. Plan the deployment
terraform1.9 plan -var-file="terraform.tfvars" -out="tfplan"

# 5. Deploy infrastructure
terraform1.9 apply tfplan

# 6. View deployed resources
terraform1.9 state list
```

#### Terraform Configuration Features

- **Native Azure Provider**: Uses `azurerm` provider v4.46+ with latest features
- **Hub-Spoke Networking**: Automated VNet peering between hub (10.0.0.0/16) and spoke (10.1.0.0/16)
- **Container Registry**: Premium SKU with private endpoints and vulnerability scanning
- **Security First**: Admin user disabled, private network access only
- **Monitoring**: Log Analytics workspace with 30-day retention
- **Cost Optimized**: B1 App Service Plan, Standard storage, Premium ACR

#### Key Files Structure

```
infra/terraform/simple-sandbox/
├── main.tf              # Main infrastructure definition
├── variables.tf         # Input variables with validation
├── terraform.tfvars     # Default configuration values
├── outputs.tf           # Resource outputs and connection info
├── README.md            # Quick start guide
└── cleanup.sh           # Automated cleanup script
```

### Deployment Results & Validation

**✅ Live Deployment Results** (Sep 26, 2025 21:45 UTC)

We successfully deployed the Terraform sandbox infrastructure. Here are the actual results:

#### Successfully Deployed Resources (22 resources)

| **Component**        | **Resource Name**        | **Status**   | **Details**                   |
| -------------------- | ------------------------ | ------------ | ----------------------------- |
| Hub Resource Group   | `rg-alz-hub-sandbox`     | ✅ Deployed  | West Europe location          |
| Spoke Resource Group | `rg-alz-spoke-sandbox`   | ✅ Deployed  | West Europe location          |
| Hub VNet             | `vnet-alz-hub-sandbox`   | ✅ Deployed  | 10.0.0.0/16 with 4 subnets    |
| Spoke VNet           | `vnet-alz-spoke-sandbox` | ✅ Deployed  | 10.1.0.0/16 with 2 subnets    |
| VNet Peering         | Hub ↔ Spoke             | ✅ Connected | Bidirectional peering         |
| Container Registry   | `acralzsandboxrzvc8h8b`  | ✅ Deployed  | Premium SKU, private endpoint |
| Private DNS Zone     | `privatelink.azurecr.io` | ✅ Deployed  | Hub and spoke VNet links      |
| Private Endpoint     | `pe-acr-alz-sandbox`     | ✅ Approved  | Hub subnet (10.0.4.0/24)      |
| Storage Account      | `stalzsandboxrzvc8h8b`   | ✅ Deployed  | Standard LRS                  |
| App Service Plan     | `asp-alz-sandbox`        | ✅ Deployed  | B1 Linux plan                 |
| Log Analytics        | `log-alz-hub-sandbox`    | ✅ Deployed  | 30-day retention              |

#### Policy-Blocked Resources (Expected Behavior)

| **Component** | **Status**  | **Reason**                                              |
| ------------- | ----------- | ------------------------------------------------------- |
| Linux Web App | ⚠️ Blocked  | Company governance policy requires network restrictions |
| Azure Bastion | ⚠️ Disabled | Cost optimization (disabled in configuration)           |

#### Deployment Metrics

- **⏱️ Total Deployment Time**: ~3 minutes
- **💰 Estimated Monthly Cost**: ~$8-10 (without web app, ~$18 with full config)
- **🔧 Resources Created**: 22 out of 24 planned resources
- **⚙️ Terraform Version**: 1.9.8 with AzureRM provider 4.46.0

#### Validation Commands

After deployment, validate your infrastructure with these commands:

```bash
# Check resource groups
az group list --query "[?contains(name, 'alz')].{Name:name,Location:location}" --output table

# Verify VNet peering
az network vnet peering list \
  --resource-group rg-alz-hub-sandbox \
  --vnet-name vnet-alz-hub-sandbox \
  --query "[].{Name:name,State:peeringState}" --output table

# Check container registry
az acr show --name acralzsandboxrzvc8h8b \
  --query "{Name:name,Sku:sku.name,LoginServer:loginServer,AdminEnabled:adminUserEnabled}" \
  --output table

# Validate private endpoint
az network private-endpoint list \
  --resource-group rg-alz-hub-sandbox \
  --query "[?contains(name, 'acr')].{Name:name,State:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  --output table
```

#### Automatic Cleanup

The deployment includes an automatic cleanup script that runs 10 minutes after deployment:

```bash
# Check cleanup status
tail -f cleanup.log

# Manual cleanup if needed
terraform1.9 destroy -var-file="terraform.tfvars" -auto-approve
```

### Sandbox Features

- ✅ **Cost-Optimized**: Standard SKU, minimal retention periods
- ✅ **Easy Cleanup**: Purge protection disabled for quick teardown
- ✅ **Testing-Ready**: Pre-configured test resources and commands
- ✅ **AVM Validation**: Uses same AVM modules as production
- ✅ **Zero Risk**: No impact on production environments

### Cleanup Sandbox

```bash
# Bicep deployment cleanup
az group delete --name "rg-alz-sandbox-sandbox" --yes --no-wait

# Terraform cleanup
terraform destroy -auto-approve
```

## 🏭 Production Deployment (Multi-Subscription)

**Enterprise-ready with CAF compliance and Zero Trust security**

The production deployment creates a complete Azure Landing Zone with Management Groups, policies, and enterprise-grade security.

### Management Group Architecture

```mermaid
graph TB
    subgraph TenantRoot["Tenant Root Group"]
        Root[ALZ Root]
    end

    subgraph Platform["Platform Services"]
        Connectivity[Connectivity<br/>Hub networks, DNS]
        Identity[Identity<br/>Azure AD, PIM]
        Management[Management<br/>Monitoring, Automation]
        Security[Security<br/>Defender, Sentinel]
    end

    subgraph LandingZones["Landing Zones"]
        Production[Production<br/>Critical workloads]
        NonProd[Non-Production<br/>Dev, test, staging]
    end

    Sandbox[Sandbox<br/>Experimentation]

    Root --> Platform
    Root --> LandingZones
    Root --> Sandbox

    Platform -.-> Connectivity
    Platform -.-> Identity
    Platform -.-> Management
    Platform -.-> Security

    LandingZones -.-> Production
    LandingZones -.-> NonProd

    style Root fill:#0078d4,color:#fff
    style Platform fill:#50e6ff,color:#000
    style LandingZones fill:#50e6ff,color:#000
    style Sandbox fill:#ffd700,color:#000
```

### Security Framework (Zero Trust Level 1)

| **Security Pillar** | **Implementation**                   | **Maturity**    |
| ------------------- | ------------------------------------ | --------------- |
| **Identity**        | MFA + RBAC                           | Level 1 - Basic |
| **Network**         | NSG Flow Logs + Service Endpoints    | Level 1 - Basic |
| **Data**            | HTTPS + TLS 1.2 + Encryption at Rest | Level 1 - Basic |
| **Applications**    | Key Vault Firewall + App HTTPS       | Level 1 - Basic |
| **Visibility**      | 90-day Logs + Diagnostics            | Level 1 - Basic |

### Production Deployment Steps

#### Prerequisites

```bash
# Required permissions:
# - Management Group Contributor at Tenant Root
# - Subscription Owner on target subscriptions
# - Policy Contributor for policy assignments

# Required information:
# - Billing scope for subscription creation
# - Management Group hierarchy preferences
# - Network architecture (hub-spoke vs mesh)
```

#### Step 1: Deploy Management Groups

```bash
az deployment mg create \
  --management-group-id "your-tenant-root-group-id" \
  --location "westeurope" \
  --template-file production/management-groups.bicep \
  --parameters organizationPrefix="contoso" \
  --parameters rootManagementGroupId="your-tenant-root-group-id"
```

#### Step 2: Deploy Landing Zone Subscriptions

```bash
az deployment mg create \
  --management-group-id "contoso-lz-production" \
  --location "westeurope" \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/main.parameters.prod.json
```

### Well-Architected Framework Alignment

#### ✅ Security

- Zero Trust Level 1 policies enforced
- RBAC with least privilege principle
- Encryption in transit and at rest
- Comprehensive audit logging

#### ✅ Reliability

- Multi-region deployment support
- Automated backup and recovery
- Health monitoring and alerting
- Disaster recovery planning

#### ✅ Cost Optimization

- Right-sized resources by environment
- Automated cost management policies
- Resource lifecycle automation
- Budget alerts and controls

#### ✅ Operational Excellence

- Infrastructure as Code (Bicep + Terraform)
- Automated deployment pipelines
- Policy as Code governance
- Comprehensive monitoring

#### ✅ Performance Efficiency

- Premium SKUs for production workloads
- Private endpoints for optimal networking
- Auto-scaling capabilities
- Performance monitoring

## 🚀 GitOps Quick Start

### Prerequisites

#### Core Requirements

1. **Azure CLI** (`>= 2.50.0`) with Bicep extension
2. **Terraform** (`>= 1.5.0`) for Terraform examples
3. **Azure subscription** with Owner or Contributor permissions
4. **Git** repository (GitHub or Azure DevOps)

#### GitOps Tools (Choose Your Path)

- **Flux v2** for Kubernetes-native GitOps
- **ArgoCD** for enterprise GitOps with UI
- **GitHub Actions** for GitHub-native CI/CD
- **Azure DevOps** for enterprise CI/CD

#### AI Development Enhancement

- **[Warp Terminal](https://warp.dev)** for AI-powered development workflow
- **GitHub Copilot** or **Azure OpenAI** for code assistance

### Installation Commands

```bash
# Azure CLI and Bicep
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az bicep install && az bicep upgrade

# Terraform (macOS)
brew install terraform

# Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

### 🎯 GitOps Deployment Paths

#### Path 1: Direct Azure Deployment (Traditional)

```bash
# 1. Clone and setup
git clone https://github.com/your-org/azure-landingzone.git
cd azure-landingzone

# 2. Azure authentication
az login
az account set --subscription "your-subscription-id"

# 3. Create resource group
az group create --name "rg-avm-alz-min-dev" --location "westeurope"

# 4. Deploy with AVM Bicep
az deployment group create \
  --resource-group "rg-avm-alz-min-dev" \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/main.parameters.json \
  --name "avm-keyvault-$(date +%Y%m%d-%H%M%S)"
```

#### Path 2: GitHub Actions GitOps

```yaml
# .github/workflows/ci-bicep.yml
name: "AVM Bicep GitOps"
on:
  push:
    branches: [main, develop]
    paths: ["infra/bicep/**"]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy AVM Key Vault
        run: |
          az deployment group create \
            --resource-group ${{ vars.RESOURCE_GROUP }} \
            --template-file infra/bicep/main.bicep \
            --parameters infra/bicep/main.parameters.json
```

#### Path 3: Flux v2 GitOps (Kubernetes-Native)

```yaml
# gitops/flux/apps/azure-infra.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: azure-landingzone
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/your-org/azure-landingzone
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: azure-infrastructure
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: azure-landingzone
  path: "./infra/bicep"
  prune: true
  validation: client
```

#### Path 4: ArgoCD GitOps (Enterprise)

```yaml
# gitops/argocd/applications/azure-landingzone.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-landingzone
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://github.com/your-org/azure-landingzone
    targetRevision: main
```

## 📖 User Manual: Testing ALZ AVM in Sandbox

### Overview

This user manual documents the testing process for **Azure Landing Zone (ALZ) with Azure Verified Modules (AVM)** in a sandbox subscription environment. The tests validate that AVM patterns work correctly and demonstrate the security and operational benefits of using Microsoft's verified infrastructure modules.

### Test Environment Setup

**Test Environment:**

- **Subscription**: PER-SBX-MBUCHHORN (fdf79377-e045-462f-ac4a-630ddee7e4c3)
- **Tenant**: Sopra Steria (8b87af7d-8647-4dc7-8df4-5f69a2011bb5)
- **Region**: West Europe
- **Testing Date**: September 26, 2025
- **Tools**: Azure CLI 2.77.0, Bicep CLI 0.37.4, Warp AI Terminal

### Prerequisites Validation

#### 1. Azure CLI and Authentication

```bash
# Verify Azure CLI version
az --version
# Expected: azure-cli 2.77.0 or later

# Verify Bicep CLI
az bicep version
# Expected: Bicep CLI version 0.37.4 or later

# Login and verify subscription access
az login
az account show
# Verify correct subscription is selected
```

#### 2. Resource Group Creation

```bash
# Create dedicated test resource group
az group create --name "rg-alz-sandbox-test" --location "westeurope" \
  --tags Environment="sandbox" Pattern="AVM-Testing" DeployedBy="Warp-AI"

# Verify resource group creation
az group show --name "rg-alz-sandbox-test"
```

### Test Case 1: AVM Storage Account Deployment ✅

#### Test Objective

Validate Azure Verified Modules work correctly by deploying a Storage Account with enterprise security configurations.

#### Template Preparation

1. **Created**: `sandbox/storage-test.bicep` - AVM Storage Account template
2. **AVM Module Used**: `br/public:avm/res/storage/storage-account:0.9.1`
3. **Configuration**: Security-hardened with Microsoft best practices

#### Deployment Process

**Step 1: Template Validation**

```bash
# Validate Bicep syntax
az bicep build --file sandbox/storage-test.bicep
# Result: ✅ Template compiled successfully
```

**Step 2: What-If Analysis**

```bash
# Preview deployment changes
az deployment group what-if --resource-group "rg-alz-sandbox-test" \
  --template-file sandbox/storage-test.bicep --parameters environment=sandbox

# Results Preview:
# + Microsoft.Storage/storageAccounts/stalzsandboxkuk5klizdm [2022-09-01]
# + Microsoft.Storage/storageAccounts/.../blobServices/default [2022-09-01]
# ✅ 2 resources to create, 0 to modify, 0 to delete
```

**Step 3: Deployment Execution**

```bash
# Deploy infrastructure
DEPLOYMENT_NAME="alz-avm-storage-test-$(date +%Y%m%d-%H%M%S)"
az deployment group create --resource-group "rg-alz-sandbox-test" \
  --template-file sandbox/storage-test.bicep --parameters environment=sandbox \
  --name "$DEPLOYMENT_NAME"

# ✅ Result: Deployment succeeded in 27.58 seconds
```

#### Validation Results

**Deployed Resources:**

- **Storage Account**: `stalzsandboxkuk5klizdm`
- **Location**: West Europe
- **SKU**: Standard_LRS
- **Kind**: StorageV2
- **TLS Version**: TLS1_2 (✅ Security Best Practice)
- **Public Access**: False (✅ Security Best Practice)

**AVM Security Configurations Applied Automatically:**

```bash
# Verify security settings
az storage account show --name stalzsandboxkuk5klizdm \
  --resource-group rg-alz-sandbox-test \
  --query "{TLS:minimumTlsVersion, PublicAccess:allowBlobPublicAccess, \
           NetworkAccess:networkAcls.defaultAction}" --output table

# Results:
# TLS     PublicAccess  NetworkAccess
# ------  ------------  -------------
# TLS1_2  False         Deny          ✅ All security best practices applied
```

**Resource Tagging Validation:**

```bash
# Verify comprehensive tagging
az tag list --resource-id "/subscriptions/fdf79377-e045-462f-ac4a-630ddee7e4c3/resourceGroups/rg-alz-sandbox-test/providers/Microsoft.Storage/storageAccounts/stalzsandboxkuk5klizdm" \
  --query "properties.tags" --output table

# Results:
Environment    Workload     IaC        CostCenter         Pattern          Purpose         DeployedBy
-------------  -----------  ---------  -----------------  ---------------  --------------  -----------------
sandbox        alz-sandbox  Bicep-AVM  IT-Infrastructure  Sandbox-Testing  AVM-Validation  Warp-AI-Assistant
# ✅ All governance tags applied correctly
```

### Test Case 2: AVM Key Vault Deployment (Policy Restricted) ⚠️

#### Test Objective

Demonstrate Azure Verified Modules for Key Vault deployment and show how enterprise policies interact with AVM patterns.

#### Template Preparation

1. **Created**: `sandbox/simple-test.bicep` - AVM Key Vault template
2. **AVM Module Used**: `br/public:avm/res/key-vault/vault:0.4.0`
3. **Configuration**: Premium security with RBAC and soft delete

#### Deployment Attempt

**Step 1: Template Validation**

```bash
# Validate Bicep syntax
az bicep build --file sandbox/simple-test.bicep
# ✅ Template compiled successfully
```

**Step 2: What-If Analysis**

```bash
# Attempt What-If analysis
az deployment group what-if --resource-group "rg-alz-sandbox-test" \
  --template-file sandbox/simple-test.bicep --parameters environment=sandbox

# Result: ⚠️ Policy violation detected
# Error: RequestDisallowedByPolicy - Resource 'kv-alz-kuk5klizdm6bm' was disallowed by policy
# Reason: 'Please apply the DEP rule for restrictions: https://docs.dep.soprasteria.com/docs/platforms/azure/security-policies/security-keyvault/'
```

#### Key Learnings from Policy Interaction

1. **Enterprise Policy Governance**:

   - Company policies (Sopra Steria DEP rules) can restrict resource creation
   - Policies work correctly with AVM templates (no template issues)
   - What-If analysis catches policy violations before deployment

2. **AVM Template Validation**:

   - Template syntax was valid and compiled successfully
   - AVM module reference was correct: `br/public:avm/res/key-vault/vault:0.4.0`
   - All parameters and configurations were properly formatted

3. **Recommended Production Approach**:
   - Work with security team to understand DEP requirements
   - Modify AVM parameters to comply with enterprise policies
   - Use policy exemptions for approved testing scenarios

### Test Case 3: Resource Cleanup and Validation 🧹

#### Cleanup Process

```bash
# List all resources in test resource group
az resource list --resource-group rg-alz-sandbox-test \
  --query "[].{Name:name, Type:type, Location:location}" --output table

# Clean up test resources
az group delete --name "rg-alz-sandbox-test" --yes --no-wait

# ✅ Cleanup initiated successfully
```

### AVM Benefits Demonstrated

#### 1. **Microsoft-Validated Configurations**

- Storage Account deployed with enterprise security settings automatically
- TLS 1.2 enforcement, blob public access disabled, network access controls
- Comprehensive tagging and governance applied

#### 2. **Consistent Parameter Schema**

- Standardized naming conventions: `name`, `location`, `tags`
- Predictable security parameters: `enableRbacAuthorization`, `networkAcls`
- Common diagnostic settings pattern across all AVM modules

#### 3. **Security Best Practices by Default**

- Zero-trust networking (default action: deny)
- Modern authentication (RBAC over legacy access policies)
- Encryption and TLS standards automatically enforced

#### 4. **Enterprise Policy Compatibility**

- AVM templates work correctly with Azure Policy
- What-If analysis catches policy violations before deployment
- Templates can be customized to meet specific compliance requirements

### Recommendations for Production Use

#### 1. **Policy Management**

```bash
# Before production deployment, analyze policy requirements
az policy assignment list --scope "/subscriptions/{subscription-id}" \
  --query "[].{Name:displayName, Description:description}" --output table

# Test templates in sandbox environment first
az deployment group what-if --resource-group "test-rg" \
  --template-file your-template.bicep
```

#### 2. **Environment-Specific Configurations**

- **Sandbox**: Relaxed policies, cost-optimized SKUs, easy cleanup
- **Development**: Moderate security, standard SKUs, lifecycle management
- **Production**: Full security enforcement, premium SKUs, compliance monitoring

#### 3. **AVM Module Selection**

- Always use latest stable AVM versions: `br/public:avm/res/{service}/{resource}:latest`
- Review AVM module documentation for parameter options
- Test parameter combinations in sandbox before production

### Testing Checklist

**Pre-Deployment:**

- [ ] Azure CLI authenticated with correct subscription
- [ ] Bicep CLI installed and up-to-date
- [ ] Test resource group created
- [ ] Template syntax validated with `az bicep build`

**Deployment Testing:**

- [ ] What-If analysis completed successfully
- [ ] Deployment executed without errors
- [ ] Resource configuration verified
- [ ] Security settings validated
- [ ] Tagging compliance confirmed

**Post-Deployment:**

- [ ] Resource functionality tested
- [ ] Monitoring and logging verified
- [ ] Cost implications reviewed
- [ ] Cleanup procedures executed

### Troubleshooting Guide

**Common Issues:**

1. **Policy Violations**

   - **Symptom**: `RequestDisallowedByPolicy` error
   - **Solution**: Review enterprise policies, work with security team
   - **Prevention**: Use What-If analysis before deployment

2. **Naming Conflicts**

   - **Symptom**: Resource name already exists
   - **Solution**: Use `uniqueString()` function in templates
   - **Prevention**: Check for soft-deleted resources

3. **Permission Issues**

   - **Symptom**: Authorization errors during deployment
   - **Solution**: Verify RBAC permissions on subscription/resource group
   - **Prevention**: Use `az role assignment list` to verify access

4. **Template Syntax Errors**
   - **Symptom**: Bicep build failures
   - **Solution**: Review Bicep documentation and AVM parameter requirements
   - **Prevention**: Use Bicep extension in VS Code for real-time validation

### Conclusion

This sandbox testing successfully demonstrated:

✅ **AVM Module Functionality**: Storage Account deployed with enterprise security  
✅ **Policy Integration**: Enterprise policies work correctly with AVM templates  
✅ **Security Best Practices**: Automatic application of Microsoft security standards  
✅ **Operational Readiness**: What-If analysis, tagging, and cleanup procedures  
✅ **AI-Assisted Development**: Warp terminal enabled efficient testing and troubleshooting

The Azure Landing Zone with Azure Verified Modules pattern is **production-ready** and provides a solid foundation for enterprise infrastructure deployment with modern GitOps practices.
path: infra/bicep
destination:
server: https://management.azure.com
namespace: rg-avm-alz-min-prod
syncPolicy:
automated:
prune: true
selfHeal: true
syncOptions: - CreateNamespace=true

````

## 🔄 GitOps Security Architecture

As highlighted in the [LinkedIn article](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D), GitOps transforms your Git repository into your **entire system's control plane**, creating both opportunities and security implications:

### Security Benefits
✅ **Immutable audit trail** of every infrastructure change
✅ **Declarative security policies** stored as code
✅ **Automated compliance validation** through CI/CD pipelines
✅ **Rollback capabilities** for security incident response

### Security Considerations
⚠️ **Single point of failure** if Git repository is compromised
⚠️ **Secret management complexity** in declarative configurations
⚠️ **Privilege escalation** through repository access
⚠️ **Drift detection gaps** between declared and actual state

## 🛡️ ArgoCD vs Flux: Security-First Comparison

### ArgoCD Strengths (Enterprise)
- ✅ **Built-in SSO integration** with enterprise identity providers
- ✅ **Native RBAC** with fine-grained permissions
- ✅ **Multi-cluster security** with centralized policy enforcement
- ✅ **Audit logging** for compliance requirements
- ✅ **Web UI** for operations teams

### Flux Advantages (Cloud-Native)
- ✅ **Kubernetes-native RBAC** relying on cluster permissions
- ✅ **Command-line focused** workflow
- ✅ **Lightweight footprint** with minimal resource usage
- ✅ **GitOps Toolkit** modular architecture
- ✅ **Multi-tenancy** through Git repository structure

## ⚙️ Configuration Examples

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
````

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

## 💰 Cost Optimization & Resource Management

AI-powered GitOps enables intelligent resource lifecycle management:

### Automated Cost Controls

```yaml
# Resource lifecycle policies automatically cleaning up development resources
apiVersion: policy.azure.com/v1
kind: PolicyDefinition
metadata:
  name: cleanup-dev-resources
spec:
  policyRule:
    if:
      allOf:
        - field: "tags['Environment']"
          equals: "Development"
        - field: "Microsoft.Resources/subscriptions/resourceGroups/resources/createdTime"
          less: "[addDays(utcNow(), -7)]" # 7 days old
    then:
      effect: "delete"
```

### Cost Budgets as Code

```bicep
resource budget 'Microsoft.Consumption/budgets@2021-10-01' = {
  name: 'monthly-budget'
  properties: {
    category: 'Cost'
    amount: 1000
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '2024-01-01'
    }
    notifications: {
      'actual_GreaterThan_80_Percent': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: ['admin@company.com']
      }
    }
  }
}
```

### Right-Sizing Automation

```yaml
# Right-sizing automation based on actual resource utilization metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cost-optimizer
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: azure-resources
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## 🔄 Enterprise CI/CD Integration

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

## 🤖 Pre-commit Hooks & Code Quality

**Comprehensive Infrastructure as Code validation with automated security scanning**

The Azure Landing Zone project implements enterprise-grade pre-commit hooks that automatically validate, format, and secure your infrastructure code before it enters the repository.

### Key Features

- 🛡️ **Security-First**: Prevents security misconfigurations from entering codebase
- 🔍 **Multi-Tool Validation**: Bicep, Terraform, YAML, JSON, and secret scanning
- 🚀 **AVM Compliance**: Enforces Azure Verified Modules usage and standards
- ⚡ **Fast Feedback**: Catches issues locally before remote push
- 📊 **Compliance**: Validates against Azure policies and naming conventions

### Implemented Linters

#### Bicep Linting Stack

```bash
# 4 Bicep-specific hooks
bicep-lint              # Syntax validation & ARM compilation
bicep-format            # Code formatting consistency
bicep-avm-check         # AVM module version verification
bicep-security-scan     # Security misconfiguration detection
```

#### Terraform Linting Stack

```bash
# 5 Terraform-specific hooks
terraform_fmt           # Code formatting & alignment
terraform_validate      # Syntax & configuration validation
terraform_tflint        # Advanced linting & best practices
terraform_tfsec         # Security vulnerability scanning
terraform_checkov       # Compliance & policy validation
```

#### Security & Compliance Stack

```bash
# 4 Security-focused hooks
detect-secrets          # Prevents secret leakage
azure-policy-check      # Azure Policy compliance
resource-naming-check   # Naming convention enforcement
cost-estimation         # Cost impact analysis
```

### Security Validations

**Critical Issues (Block Commit)**

- ❌ Hardcoded secrets in templates
- ❌ HTTPS enforcement disabled
- ❌ Admin users enabled
- ❌ Public blob access enabled
- ❌ Weak TLS versions (< 1.2)

**Warning Issues (Allow with Warning)**

- ⚠️ Public network access enabled
- ⚠️ Default network action set to Allow
- ⚠️ Missing required tags
- ⚠️ Non-AVM modules detected

### Quick Start

```bash
# 1. Install pre-commit framework
pip3 install pre-commit --break-system-packages

# 2. Install required tools
brew install terraform tflint tfsec checkov
pip3 install detect-secrets --break-system-packages

# 3. Install hooks
pre-commit install

# 4. Run on all files (first time)
pre-commit run --all-files
```

### Example Validation Output

```bash
🔍 Verifying AVM module usage...
✅ AVM modules found in simple-sandbox.bicep
📦 Found AVM module: br/public:avm/res/container-registry/registry:0.9.3
⚠️  Warning: AVM module should use specific version

🛡️ Running security scans...
❌ Security issue: Public blob access enabled in storage.bicep
✅ No hardcoded secrets detected

🗺️ TFLint analysis:
Warning: variable "additional_tags" is declared but not used
✅ Terraform formatting applied
```

### Integration Benefits

- **GitHub Actions**: Automated validation on every PR
- **Local Development**: Fast feedback loop for developers
- **Team Consistency**: Standardized code quality across contributors
- **Security Compliance**: Prevents vulnerabilities before deployment
- **Cost Awareness**: Flags expensive resource configurations

📖 **[Complete Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md)** - Comprehensive documentation covering all hooks, troubleshooting, and best practices

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

## 📈 Zero Trust Maturity Roadmap

Our implementation follows Microsoft's Zero Trust Maturity Model with a clear progression path:

### 🎯 Level 1 - Basic (Current Implementation)

**Foundational security with minimal operational impact**

- ✅ **Identity**: MFA for admins, basic RBAC
- ✅ **Network**: NSG flow logs, service endpoints
- ✅ **Data**: HTTPS enforcement, TLS 1.2 minimum
- ✅ **Apps**: Key Vault firewall, basic security headers
- ✅ **Visibility**: 90-day audit logs, basic monitoring

**Policy Mode**: Audit (learning mode)
**Timeline**: Immediate deployment ready
**Business Impact**: Minimal, focuses on visibility

### 🚀 Level 2 - Advanced (6-12 months)

**Enhanced security through automation and conditional access**

- 🔄 **Identity**: Conditional Access, PIM, Identity Protection
- 🔄 **Network**: Private endpoints everywhere, Azure Firewall Premium
- 🔄 **Data**: Microsoft Purview, Always Encrypted, DLP policies
- 🔄 **Apps**: WAF, API Management security, advanced threat protection
- 🔄 **Visibility**: Azure Sentinel SIEM, automated incident response

**Policy Mode**: Enforce (blocking mode for critical policies)
**Timeline**: 6-12 months gradual rollout
**Business Impact**: Medium, requires user training

### 🏆 Level 3 - Optimal (12-24 months)

**AI-driven security with comprehensive automation**

- 🔮 **Identity**: Risk-based authentication, adaptive controls
- 🔮 **Network**: Software-defined perimeter, microsegmentation
- 🔮 **Data**: Automated classification, intelligent DLP
- 🔮 **Apps**: Zero trust application access, runtime protection
- 🔮 **Visibility**: XDR platform, predictive threat hunting

**Policy Mode**: Full automation with intelligent adaptation
**Timeline**: 12-24 months comprehensive implementation
**Business Impact**: Low (intelligent, context-aware security)

### 📊 Success Metrics by Level

| Metric                      | Level 1 Target | Level 2 Target | Level 3 Target |
| --------------------------- | -------------- | -------------- | -------------- |
| Zero Trust Score            | 40%            | 70%            | 90%            |
| Policy Compliance           | 80%            | 95%            | 99%            |
| MTTD (Mean Time to Detect)  | 2 hours        | 15 minutes     | 5 minutes      |
| MTTR (Mean Time to Respond) | 8 hours        | 4 hours        | 1 hour         |
| User Satisfaction           | 3.5/5          | 4.0/5          | 4.5/5          |

**📖 [Complete Roadmap](docs/zero-trust-maturity-roadmap.md)** - Detailed implementation guide for all maturity levels

## 🛡️ Compliance & Governance

### Regulatory Frameworks Supported

- ✅ **NIST Cybersecurity Framework** - Core security functions implementation
- ✅ **ISO 27001** - Information security management alignment
- ✅ **CIS Controls** - Center for Internet Security best practices
- ✅ **Azure Security Benchmark** - Microsoft cloud security baseline
- ✅ **SOC 2** - Service organization control compliance

### Cloud Adoption Framework (CAF) Alignment

| **CAF Pillar** | **Implementation**                                        |
| -------------- | --------------------------------------------------------- |
| **Strategy**   | Business alignment through security and cost optimization |
| **Plan**       | Phased rollout with measurable success criteria           |
| **Ready**      | Foundational Management Group structure and policies      |
| **Adopt**      | AVM-based infrastructure with security by design          |
| **Govern**     | Policy as Code with automated compliance monitoring       |
| **Manage**     | Comprehensive monitoring, alerting, and cost management   |

### Policy Framework

#### 📋 Governance Policies (Applied to all subscriptions)

- Resource naming standards
- Required tagging (CostCenter, Environment, Owner)
- Allowed Azure regions
- Approved resource types
- Budget alerts and cost controls

#### 🔒 Security Policies (Environment-specific)

- **Production**: Strict enforcement mode, comprehensive controls
- **Non-Production**: Audit mode with selected enforcement
- **Sandbox**: Learning mode with minimal restrictions

#### 📊 Monitoring Policies

- Diagnostic settings for all resources
- Log retention based on environment (30-365 days)
- Security monitoring and alerting
- Performance monitoring

## 📚 Additional Resources

### Core Documentation

- 📖 [LinkedIn Article: AI-Powered GitOps for Azure Landing Zones](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D)
- 🏗️ [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/)
- 🔧 [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- 🔐 [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
- 🏢 [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)

### GitOps & CI/CD

- 🔄 [Flux v2 Documentation](https://fluxcd.io/docs/)
- 🚀 [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- ⚙️ [GitHub Actions Documentation](https://docs.github.com/en/actions)
- 🔧 [Azure DevOps Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/)

### AI-Powered Development

- 🤖 [Warp AI Terminal](https://warp.dev)
- 🧠 [GitHub Copilot](https://github.com/features/copilot)
- ☁️ [Azure OpenAI Service](https://azure.microsoft.com/en-us/products/cognitive-services/openai-service)

### Security & Compliance

- 🛡️ [PSRule for Azure](https://github.com/Azure/PSRule.Rules.Azure)
- 📋 [Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/)
- 🔒 [Azure Security Benchmark](https://docs.microsoft.com/en-us/security/benchmark/azure/)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

This project is inspired by the growing intersection of AI-powered development tools and GitOps practices. Special thanks to:

- **Microsoft AVM Team** for creating production-ready Infrastructure as Code modules
- **GitOps Community** for establishing declarative infrastructure management patterns
- **Warp Team** for building AI-enhanced development workflows
- **Open Source Contributors** across Flux, ArgoCD, and Azure ecosystems

---

**📝 Article**: [AI-Powered GitOps for Azure Landing Zones](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D)  
**🏗️ AVM Version**: 0.4.0+  
**📅 Last Updated**: $(date '+%Y-%m-%d')  
**👨‍💻 Author**: Matthias Buchhorn-Roth
