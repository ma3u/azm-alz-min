# AI-Powered GitOps for Azure Landing Zones with Azure Verified Modules

[![Build Status](https://dev.azure.com/your-org/your-project/_apis/build/status/azure-landingzone?branchName=main)](https://dev.azure.com/your-org/your-project/_build/latest?definitionId=YOUR_BUILD_ID&branchName=main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure Verified Modules](https://img.shields.io/badge/AVM-Verified-blue.svg)](https://azure.github.io/Azure-Verified-Modules/)

## Purpose

This repository demonstrates **AI-powered GitOps practices** for Azure Landing Zones using [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/). It showcases how modern AI tools like Warp can accelerate enterprise infrastructure deployment while maintaining security and compliance through automated validation and policy enforcement.

**What makes this different:** Instead of traditional manual infrastructure deployment, this project combines Microsoft's battle-tested AVM modules with GitOps automation and AI-assisted development to create a reproducible, secure, and cost-effective Azure Landing Zone in minutes rather than weeks.

Based on the [LinkedIn article](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D), this demonstrates modern infrastructure patterns that enterprise teams can adopt immediately.

## 📋 Table of Contents

- [⚡ Quick Start - Choose Your Path](#-quick-start---choose-your-path)
  - [🚀 Deploy Now (10 minutes)](#-deploy-now-10-minutes)
  - [📖 Learn First (Recommended)](#-learn-first-recommended)
  - [🔧 Developer Setup](#-developer-setup)
- [📋 Documentation Library](#-documentation-library)
- [🎯 How to Use This Repository](#-how-to-use-this-repository)
- [🛡️ Repository Standards & Best Practices](#️-repository-standards--best-practices)
- [🏗️ Repository Structure](#️-repository-structure)
- [🎯 Why This Matters](#-why-this-matters)
- [💡 Key Features](#-key-features)
- [🎯 Azure Verified Modules (AVM) Overview](#-azure-verified-modules-avm-overview)
- [🧪 Testing & Deployment](#-testing--deployment)
- [📚 Learning Resources & Official Guides](#-learning-resources--official-guides)
- [🤝 Contributing](#-contributing)
- [📚 Related Documents](#-related-documents)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)

---

## ⚡ Quick Start - Choose Your Path

### 🚀 Deploy Now (10 minutes)

**Quick Azure Landing Zone deployment for testing:**

```bash
az login
az account set --subscription "your-subscription-id"
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)"
```

**Cost:** ~$18/month sandbox environment  
**Result:** Complete hub-spoke ALZ with security compliance

### 📖 Learn First (Recommended)

**New to Azure Landing Zones?** Start here:

- [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - Understand the rules and requirements
- [AVM Deployment Guide](docs/avm-deployment-guide.md) - Complete deployment walkthrough
- [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - Fix common issues

### 🔧 Developer Setup

**Setting up for contribution:**

```bash
git clone https://github.com/yourusername/azure-landingzone.git
cd azure-landingzone
pip install pre-commit && pre-commit install

# Run comprehensive validation
./scripts/validate-deployment.sh
```

**The validation script checks:** Prerequisites, template compilation, AVM modules, pre-commit hooks, and security configuration.

**Official setup guides:**

- [Pre-commit Installation Guide](https://pre-commit.com/)
- [Azure CLI Setup](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Bicep Setup](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

## 📋 Documentation Library

### 🎯 Essential Getting Started

- [📋 Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - **Main policy reference and rules**
- [⚡ AVM Deployment Guide](docs/avm-deployment-guide.md) - **Primary deployment walkthrough**
- [🔍 Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - **Fix common issues**

### 🔧 Development & Quality

- [🛠️ Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md) - Code quality automation
- [🏗️ Terraform Deployment Guide](docs/terraform-deployment-guide.md) - Terraform-specific procedures
- [🔄 Terraform CI/CD Guide](docs/terraform-cicd-guide.md) - GitHub Actions automation
- [📖 AVM Modules Guide](docs/avm-modules-guide.md) - AVM reference and best practices

### 🏭 Enterprise Integration

- [🏢 Azure DevOps Setup](docs/azure-devops-setup.md) - Enterprise CI/CD pipelines
- [🔄 GitHub-Azure DevOps Sync](docs/github-azuredevops-sync.md) - Dual repository strategy
- [🚀 Deployment Guide](docs/deployment-guide.md) - Classic step-by-step deployment

### 🛡️ Security & Compliance

- [🔒 ACR Vulnerability Scanning Guide](docs/acr-vulnerability-scanning-guide.md) - Container security
- [🛡️ Zero Trust Maturity Roadmap](docs/zero-trust-maturity-roadmap.md) - Security progression

### 🤖 AI-Powered Development

- [🤖 AI-Powered GitOps Article](docs/ai-powered-gitops-article.md) - AI methodology
- [WARP.md](WARP.md) - AI development guidance with policy rules

## 🎯 How to Use This Repository

### 📍 Choose Your Journey

**🏃‍♂️ First-Time Users**

1. Read [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md)
2. Follow [AVM Deployment Guide](docs/avm-deployment-guide.md)
3. **Result:** Working ALZ (~$18/month, 10 minutes)

**🔧 Developers**

1. Set up tools: [Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md)
2. Choose IaC: [Terraform Deployment Guide](docs/terraform-deployment-guide.md) or Bicep
3. Automate: [Terraform CI/CD Guide](docs/terraform-cicd-guide.md)

**🏭 Enterprise Teams**

1. Plan: [Azure DevOps Setup](docs/azure-devops-setup.md)
2. Secure: [Zero Trust Maturity Roadmap](docs/zero-trust-maturity-roadmap.md)
3. Scale: [GitHub-Azure DevOps Sync](docs/github-azuredevops-sync.md)

### 📍 Prerequisites

**Required:**

- Azure subscription with Contributor permissions
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.50.0+)
- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) or [Terraform 1.9+](https://releases.hashicorp.com/terraform/)

**Recommended:**

- [Warp Terminal](https://warp.dev) for AI assistance
- [Pre-commit framework](https://pre-commit.com/) for quality checks
- VS Code with [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep) or [Terraform](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform) extensions

**Check AVM module availability:**

```bash
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/{service}/{resource}/tags/list" | jq -r '.tags[]' | sort -V | tail -5
```

---

## 🛡️ Repository Standards & Best Practices

### 🎯 Template Priority (Use These)

| Priority | Template                                                     | Status         | Use Case       |
| -------- | ------------------------------------------------------------ | -------------- | -------------- |
| **1st**  | `infra/accelerator/simple-sandbox.bicep`                     | ✅ **WORKING** | Sandbox ALZ    |
| **2nd**  | `infra/accelerator/alz-subscription-vending-corrected.bicep` | ✅ **WORKING** | Enterprise ALZ |
| **3rd**  | `infra/terraform/simple-sandbox/`                            | ✅ **WORKING** | Terraform ALZ  |

### 📚 Development Rules

1. **Check AVM First:** Always verify module availability at [AVM Registry](https://azure.github.io/Azure-Verified-Modules/)
2. **Use Working Templates:** Start from tested templates above
3. **Follow Naming:** Use consistent Azure naming conventions
4. **Pre-commit Validation:** Run hooks before every commit

**Quick AVM pattern:**

```bicep
module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: 'keyVaultDeployment'
  params: {
    name: 'kv-${environment}-${uniqueString(subscription().id)}'
    location: location
    enableRbacAuthorization: true
  }
}
```

**For detailed guidance:** [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md)

---

## 🎯 Why This Matters

**The Problem:** Traditional Azure Landing Zone deployments take weeks of manual configuration, prone to security gaps and inconsistencies.

**Our Solution:** AI-enhanced GitOps using Microsoft's battle-tested [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) delivers secure, compliant infrastructure in minutes.

### Key Benefits

- **⚡ Speed:** Deploy complete ALZ in 10 minutes vs. weeks
- **🛡️ Security:** Built-in Zero Trust Level 1 compliance
- **💰 Cost-Effective:** Sandbox testing for ~$18/month
- **🤖 AI-Enhanced:** Warp integration for intelligent development
- **📏 Standardized:** Microsoft's 14+ million deployment track record

## 🏗️ Repository Structure

### 📂 Key Infrastructure Components

```
azure-landingzone/
├── infra/
│   ├── accelerator/              # ✅ Production-ready AVM templates
│   │   ├── simple-sandbox.bicep  # Working sandbox ALZ (~$18/month)
│   │   └── alz-subscription-vending-corrected.bicep  # Enterprise ALZ
│   ├── bicep/                   # Classic key vault examples
│   └── terraform/               # Terraform alternatives
├── docs/                        # Complete documentation library
├── .github/workflows/           # GitHub Actions CI/CD
└── gitops/                     # ArgoCD and Flux configurations
```

### 🎯 Architecture Patterns

**Sandbox Pattern:** Single subscription, hub-spoke networking, cost-optimized  
**Enterprise Pattern:** Management groups, subscription vending, full compliance  
**Security Framework:** Zero Trust Level 1 with progression roadmap

---

## 💡 Key Features

### 🚀 Deployment Options

- **Sandbox:** Single subscription testing (~$18/month)
- **Enterprise:** Multi-subscription with management groups
- **Hybrid:** Bicep and Terraform support

### 🛡️ Security & Compliance

- **Zero Trust Level 1:** MFA, RBAC, network segmentation
- **Policy as Code:** 13+ automated security validations
- **Audit Trail:** Complete GitOps change tracking

### 🤖 AI Integration

- **Warp Terminal:** Context-aware infrastructure assistance
- **Intelligent Debugging:** AI-powered error resolution
- **Template Generation:** Automated AVM module discovery

### 📊 Quality Assurance

- **Pre-commit Hooks:** 13+ validation tools
- **Multi-stage CI/CD:** GitHub Actions and Azure DevOps
- **Compliance Scanning:** Checkov, TFSec, PSRule integration

## 🎯 Azure Verified Modules (AVM) Overview

[Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) represents Microsoft's production-ready Infrastructure as Code standard with **14+ million deployments** and full enterprise support.

### Why AVM?

- **✅ Battle-Tested:** 14+ million real deployments
- **✅ Microsoft Backed:** Full FTE team support
- **✅ Security Built-in:** Compliance and best practices by default
- **✅ Consistent:** Standardized patterns across all Azure services

**Learn more:** [AVM Documentation](https://azure.github.io/Azure-Verified-Modules/) | [AVM Modules Guide](docs/avm-modules-guide.md)

## 🧪 Testing & Deployment

### Sandbox Testing (Recommended Start)

**Cost-effective validation:** Test all AVM patterns in a single subscription for ~$18/month without Management Group requirements.

**Quick deployment:**

```bash
az login
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/simple-sandbox.bicep \
  --parameters infra/accelerator/simple-sandbox.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)"
```

**Learn more:** [AVM Deployment Guide](docs/avm-deployment-guide.md) | [Terraform Deployment Guide](docs/terraform-deployment-guide.md)

### Enterprise Production

**Full-scale ALZ:** Management groups, subscription vending, compliance policies, and Zero Trust Level 1 security framework.

**Key components:** Hub-spoke networking, private endpoints, policy enforcement, cost management, monitoring.

**Learn more:** [Azure DevOps Setup](docs/azure-devops-setup.md) | [Zero Trust Maturity Roadmap](docs/zero-trust-maturity-roadmap.md)

---

## 📚 Learning Resources & Official Guides

### 🎯 Microsoft Official Documentation

- [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) - Microsoft's official ALZ guidance
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) - Complete AVM reference
- [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules) - Source code for all AVM Bicep modules
- [AVM Terraform Registry](https://registry.terraform.io/search/modules?q=avm) - Terraform AVM modules search
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/) - Enterprise architecture principles
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) - Infrastructure as Code with Bicep

### 🚀 Deployment Tutorials

- [Azure CLI Tutorial](https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli) - Get started with Azure CLI
- [Terraform on Azure](https://docs.microsoft.com/en-us/azure/developer/terraform/) - Official Terraform + Azure guide
- [GitHub Actions for Azure](https://docs.microsoft.com/en-us/azure/developer/github/github-actions) - CI/CD automation
- [Azure DevOps Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/) - Enterprise CI/CD

### 🛡️ Security & Compliance

- [Azure Security Benchmark](https://docs.microsoft.com/en-us/security/benchmark/azure/) - Security baseline
- [Zero Trust Architecture](https://docs.microsoft.com/en-us/security/zero-trust/) - Microsoft Zero Trust guidance
- [Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/) - Governance and compliance
- [Azure RBAC](https://docs.microsoft.com/en-us/azure/role-based-access-control/) - Access control best practices

### 🤖 AI-Enhanced Development

- [Warp Terminal](https://warp.dev) - AI-powered terminal for developers
- [GitHub Copilot](https://github.com/features/copilot) - AI pair programming
- [Azure OpenAI Service](https://azure.microsoft.com/en-us/products/cognitive-services/openai-service) - Enterprise AI services

---

## 🤝 Contributing

We welcome contributions! Please follow our development workflow:

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Install pre-commit hooks: `pre-commit install`
4. Make changes and test locally
5. Submit Pull Request

**Development guidelines:** [Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md)

---

## 📚 Related Documents

### 🎯 Essential Getting Started

- [📋 Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - **Main policy reference and rules**
- [⚡ AVM Deployment Guide](docs/avm-deployment-guide.md) - **Primary deployment walkthrough**
- [🔍 Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - **Fix common issues**

### 🔧 Development & Quality

- [🛠️ Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md) - Code quality automation
- [🏗️ Terraform Deployment Guide](docs/terraform-deployment-guide.md) - Terraform-specific procedures
- [🔄 Terraform CI/CD Guide](docs/terraform-cicd-guide.md) - GitHub Actions automation
- [📖 AVM Modules Guide](docs/avm-modules-guide.md) - AVM reference and best practices

### 🏭 Enterprise Integration

- [🏢 Azure DevOps Setup](docs/azure-devops-setup.md) - Enterprise CI/CD pipelines
- [🔄 GitHub-Azure DevOps Sync](docs/github-azuredevops-sync.md) - Dual repository strategy
- [🚀 Deployment Guide](docs/deployment-guide.md) - Classic step-by-step deployment

### 🛡️ Security & Compliance

- [🔒 ACR Vulnerability Scanning Guide](docs/acr-vulnerability-scanning-guide.md) - Container security
- [🛡️ Zero Trust Maturity Roadmap](docs/zero-trust-maturity-roadmap.md) - Security progression

### 🤖 AI-Powered Development

- [🤖 AI-Powered GitOps Article](docs/ai-powered-gitops-article.md) - AI methodology
- [WARP.md](WARP.md) - AI development guidance with policy rules

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Special thanks to:

- **Microsoft AVM Team** for creating production-ready Infrastructure as Code modules
- **GitOps Community** for establishing declarative infrastructure management patterns
- **Warp Team** for building AI-enhanced development workflows

---

**📝 Article:** [AI-Powered GitOps for Azure Landing Zones](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D)  
**🏗️ AVM Version:** 0.4.0+  
**📅 Last Updated:** 2025-09-28  
**👨‍💻 Author:** Matthias Buchhorn-Roth
