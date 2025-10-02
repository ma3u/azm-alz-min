# AI-Powered GitOps for Azure Landing Zones with Azure Verified Modules

[![Build Status](https://github.com/ma3u/azm-alz-min/actions/workflows/azure-landing-zone-cicd.yml/badge.svg)](https://github.com/ma3u/azm-alz-min/actions/workflows/azure-landing-zone-cicd.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure Verified Modules](https://img.shields.io/badge/AVM-Verified-blue.svg)](https://azure.github.io/Azure-Verified-Modules/)

## Purpose

This repository demonstrates **AI-powered GitOps practices** for Azure Landing Zones using [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/). It showcases how modern AI tools like Warp can accelerate enterprise infrastructure deployment while maintaining security and compliance through automated validation and policy enforcement.

**What makes this different:** Instead of traditional manual infrastructure deployment, this project combines Microsoft's battle-tested AVM modules with GitOps automation and AI-assisted development to create a reproducible, secure, and cost-effective Azure Landing Zone in minutes rather than weeks.

Based on the [LinkedIn article](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D), this demonstrates modern infrastructure patterns that enterprise teams can adopt immediately.

> **📋 Repository Update (Sept 2025)**: This repository has been reorganized for better structure and usability. Documentation moved from nested folders to `docs/`, deployment reports now include interactive HTML dashboards in `deployment-reports/`, and production-ready templates are consolidated in `blueprints/` with development work in `infra/`. All links have been updated accordingly.

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
- [💰 FinOps & Cost Estimation](#-finops--cost-estimation)
  - [🔧 Infracost Integration](#-infracost-integration)
  - [📊 Cost Analysis Examples](#-cost-analysis-examples)
  - [⚙️ Setup & Configuration](#️-setup--configuration)
  - [🎯 Cost Optimization](#-cost-optimization)
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
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters blueprints/bicep/hub-spoke/main.parameters.json \
  --name "alz-sandbox-$(date +%Y%m%d-%H%M%S)"
```

**Cost:** ~$30/month sandbox environment (Standard Container Registry)
**Result:** Complete hub-spoke ALZ with security compliance

### 📊 Deploy with Comprehensive Reporting (Recommended)

**For detailed deployment insights and monitoring:**

```bash
# Deploy with full reporting, cost analysis, and security assessment
./automation/scripts/deploy-with-report.sh

# Or specify custom template
./automation/scripts/deploy-with-report.sh \
  blueprints/bicep/hub-spoke/main.bicep \
  blueprints/bicep/hub-spoke/main.parameters.json
```

**What you get:**

- 📋 **Pre-deployment validation** (prerequisites, pre-commit checks)
- 🏗️ **Automated deployment** with full error handling
- 📊 **Resource inventory** across all resource groups
- 💰 **Cost analysis** with service breakdown
- 🔒 **Security assessment** with recommendations
- 📈 **HTML/JSON reports** for sharing and audit trails
- 🔄 **Report history management** (keeps last 5 deployments)

**📊 [View Live Deployment Reports Dashboard](https://ma3u.github.io/azm-alz-min/)**

> **🌐 Live Dashboard**: Deployment reports are automatically published to GitHub Pages for easy sharing and viewing. The dashboard updates automatically when new reports are generated.
>
> **💡 Alternative Viewing Methods**:
>
> 1. **GitHub Pages**: https://ma3u.github.io/azm-alz-min/ (recommended - always up to date)
> 2. **Local viewing**: `open deployment-reports/index.html` (opens in your browser)
> 3. **Local server**: `cd deployment-reports && python3 -m http.server 8000` then visit `http://localhost:8000`
> 4. **GitHub Pages**: Enable Pages in repository settings to share reports online

**Report includes:**

- ✅ Deployment status and timing
- 📦 Complete resource inventory by type and location
- 💰 Monthly cost estimates with service breakdown
- 🔒 Security score (0-100) with findings and recommendations
- 🧪 Testing commands for validation
- 🧹 Cleanup commands for resource removal
- 📈 Interactive charts and dashboards
- 📋 Historical deployment tracking

### 🌐 Automated GitHub Pages Deployment

**Deploy reports to GitHub Pages automatically:**

```bash
# Deploy current reports to GitHub Pages (automated)
./automation/scripts/deploy-reports-to-pages.sh

# Check deployment status
./automation/scripts/deploy-reports-to-pages.sh --status

# Just check configuration
./automation/scripts/deploy-reports-to-pages.sh --check
```

**Auto-deployment triggers:**

- 🔄 **Automatic**: Every push to `main` branch with updated `deployment-reports/`
- 🔘 **Manual**: Run the deployment script or trigger GitHub Actions workflow
- 📊 **Live Updates**: Reports are automatically published to GitHub Pages within minutes

### 📖 Learn First (Recommended)

**New to Azure Landing Zones?** Start here:

- [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - Understand the rules and requirements
- [AVM Deployment Guide](docs/avm-deployment-guide.md) - Complete deployment walkthrough
- [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - Fix common issues

### 🔧 Developer Setup

**Setting up for contribution:**

```bash
git clone https://github.com/ma3u/azm-alz-min.git
cd azm-alz-min
pip install pre-commit && pre-commit install

# Run comprehensive validation
./automation/scripts/validate-deployment.sh
```

**The validation script checks:** Prerequisites, template compilation, AVM modules, pre-commit hooks, and security configuration.

**Official setup guides:**

- [Pre-commit Installation Guide](https://pre-commit.com/)
- [Azure CLI Setup](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Bicep Setup](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

### 🔐 GitHub Actions Authentication Setup

**For automated CI/CD pipelines with Azure authentication:**

This repository includes GitHub Actions workflows that require Azure authentication. Set up a Service Principal for secure, automated deployments:

**🚀 Automated Setup (Recommended):**

```bash
# Run the automated authentication setup script
./automation/scripts/setup-github-auth.sh
```

**What this creates:**

- ✅ **Service Principal:** `sp-github-actions-alz-sandbox` with Contributor access
- 🔒 **GitHub Secrets:** All 5 required secrets automatically set in your repository
- 📁 **Local Credentials:** Stored securely in `.secrets/` directory (git-ignored)
- 🧪 **Authentication Test:** Verifies Service Principal can access your Azure resources

**📋 Manual Setup (Alternative):**

If you prefer manual setup, follow the detailed guide: [GitHub Authentication Setup Guide](docs/github-auth-setup-guide.md)

**Required GitHub Secrets:**

- `AZURE_CREDENTIALS` - Full JSON credentials object
- `AZURE_CLIENT_ID` - Service Principal application ID
- `AZURE_CLIENT_SECRET` - Service Principal password
- `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID
- `AZURE_TENANT_ID` - Your Azure tenant ID

**🔍 Verify Setup:**

```bash
# Check if secrets are configured
gh secret list

# Test Service Principal authentication locally
az login --service-principal \
  --username $(cat .secrets/sp-client-id.txt) \
  --password $(cat .secrets/sp-client-secret.txt) \
  --tenant $(cat .secrets/azure-credentials.json | jq -r '.tenantId')
```

**🛡️ Security Notes:**

- Service Principal has **sandbox-only access** (limited to your subscription)
- Credentials are **encrypted in GitHub** and **git-ignored locally**
- Regular credential rotation recommended for production use
- Setup creates comprehensive audit trail in `.secrets/github-auth-setup-report.md`

> **💡 Pro Tip:** After setup, your GitHub Actions workflows will automatically authenticate and deploy without manual intervention. Check the Actions tab to see deployments in progress!

## 📋 Documentation Library

### 🎯 Essential Getting Started

- [📋 Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - **Main policy reference and rules**
- [⚡ AVM Deployment Guide](docs/avm-deployment-guide.md) - **Primary deployment walkthrough**
- [🔍 Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - **Fix common issues**

### 🔧 Development & Quality

- [🛠️ Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md) - Code quality automation
- [🔐 GitHub Authentication Setup Guide](docs/github-auth-setup-guide.md) - Service Principal setup for GitHub Actions
- [🏗️ Terraform Deployment Guide](docs/terraform-deployment-guide.md) - Terraform-specific procedures
- [🔄 Terraform CI/CD Guide](docs/terraform-cicd-guide.md) - GitHub Actions automation
- [📚 AVM Modules Guide](docs/avm-modules-guide.md) - AVM reference and best practices
- [📊 Deployment Reporting Guide](docs/deployment-reporting-guide.md) - Comprehensive deployment insights with HTML dashboards

### 🏭 Enterprise Integration

- [🏢 Azure DevOps Setup](docs/azure-devops-setup.md) - Enterprise CI/CD pipelines
- [🔄 GitHub-Azure DevOps Sync](docs/github-azuredevops-sync.md) - Dual repository strategy
- [🚀 Deployment Guide](docs/deployment-guide.md) - Classic step-by-step deployment

### 🛡️ Security & Compliance

- [🔒 ACR Vulnerability Scanning Guide](docs/acr-vulnerability-scanning-guide.md) - Container security
- [🛡️ Zero Trust Maturity Roadmap](docs/zero-trust-maturity-roadmap.md) - Security progression

## 🎯 How to Use This Repository

### 📍 Choose Your Journey

**🏃‍♂️ First-Time Users**

1. Read [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md)
2. Follow [AVM Deployment Guide](docs/avm-deployment-guide.md)
3. **Result:** Working ALZ (~$30/month, 10 minutes)

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

| Priority | Template                                 | Status         | Use Case      |
| -------- | ---------------------------------------- | -------------- | ------------- |
| **1st**  | `blueprints/bicep/hub-spoke/main.bicep`  | ✅ **WORKING** | Hub-Spoke ALZ |
| **2nd**  | `blueprints/bicep/foundation/main.bicep` | ✅ **WORKING** | Basic ALZ     |
| **3rd**  | `blueprints/terraform/foundation/`       | ✅ **WORKING** | Terraform ALZ |

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
- **💰 Cost-Effective:** Sandbox testing for ~$30/month
- **🤖 AI-Enhanced:** Warp integration for intelligent development
- **📏 Standardized:** Microsoft's 14+ million deployment track record

## 🏗️ Repository Structure

### 📂 Key Infrastructure Components

```
azure-landingzone/
├── blueprints/                  # 🚀 Production-ready templates (RECOMMENDED)
│   ├── bicep/                   # ✅ Bicep templates using AVM modules
│   │   ├── hub-spoke/           # Hub-spoke ALZ (~$30/month sandbox)
│   │   └── foundation/          # Basic foundation ALZ
│   └── terraform/               # ✅ Terraform alternatives with AVM
│       └── foundation/          # Terraform-based ALZ
├── infra/                       # 🔧 Development and legacy templates
│   ├── accelerator/             # Original AVM-based deployment templates
│   ├── bicep/                   # Development Bicep templates
│   │   └── sandbox/             # Sandbox-specific implementations
│   └── terraform/               # Development Terraform templates
├── docs/                        # 📚 Complete documentation library
├── automation/scripts/          # 🤖 Deployment and validation scripts
├── deployment-reports/          # 📊 Automated deployment reports with HTML dashboards
├── sandbox/                     # 🧪 Terraform sandbox examples and testing
├── .github/workflows/           # ⚙️ GitHub Actions CI/CD automation
├── environments/                # 🌍 Environment-specific configurations
├── examples/                    # 💡 Sample implementations and tutorials
└── archived/                    # 📦 Archived templates and deprecated code
```

### 🎯 Architecture Patterns

- **Hub-Spoke Architecture:** Cost-optimized networking with centralized services (~$30/month) - Available in `blueprints/bicep/hub-spoke/`
- **Foundation Pattern:** Basic single-subscription ALZ for development and testing - Available in `blueprints/bicep/foundation/`
- **Enterprise Pattern:** Multi-subscription with management groups and subscription vending - Available in `infra/accelerator/`
- **Security Framework:** [Zero Trust progression](docs/zero-trust-maturity-roadmap.md) from Level 1 to enterprise-grade
- **Deployment Reports:** Interactive HTML dashboards available in `deployment-reports/` with cost, security, and resource analysis

---

## 💡 Key Features

### 🚀 Deployment Options

- **Sandbox:** Single subscription testing (~$30/month)
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

---

## 💰 FinOps & Cost Estimation

**Professional infrastructure cost management** integrated into your deployment pipeline using industry-standard tools and real-time Azure pricing data.

### 🎯 Cost Management Strategy

**Why Cost Estimation Matters:**

- **Prevent Surprises:** Know costs before deploying infrastructure
- **Budget Planning:** Accurate monthly estimates for financial planning
- **Cost Optimization:** Identify expensive resources and alternatives
- **Compliance:** Track spending against budgets and policies

### 🔧 Infracost Integration

**[Infracost](https://infracost.io)** - Industry-standard Infrastructure as Code cost estimation:

- ✅ **Real-time Azure Pricing:** Direct API integration with Microsoft Azure pricing
- ✅ **400+ Resources Supported:** Comprehensive coverage of Azure services
- ✅ **CI/CD Native:** Automatic cost estimates on every pull request
- ✅ **Zero Maintenance:** No manual price updates or resource mapping
- ✅ **Free Tier:** 10,000 resources per month at no cost

#### Terraform Cost Analysis

**Automated cost estimation for Terraform templates:**

```bash
# Local cost analysis
cd blueprints/terraform/foundation
infracost breakdown --path .

# Project-wide analysis
infracost breakdown --config-file infracost.yml
```

**Example Output:**

```
Name                                    Monthly Qty  Unit         Monthly Cost

azurerm_container_registry.main
├─ Registry usage (Premium)                  30  days                $50.00
├─ Storage (over 500GB)                      100  GB                  $10.00
└─ Build vCPU                                0  seconds              $0.00

azurerm_service_plan.main
└─ Instance usage (B1)                       730  hours               $13.14

OVERALL TOTAL                                                        $73.14
```

#### Pull Request Integration

**Automatic cost analysis on every PR:**

- 💬 **PR Comments:** Detailed cost breakdowns posted automatically
- 📊 **Cost Diffs:** Compare costs between branches
- 🚨 **Cost Alerts:** Warnings for high-cost changes
- 📈 **Optimization Tips:** Recommendations for cost reduction

### 📊 Cost Analysis Examples

#### Real Infrastructure Costs (Tested October 2025)

**Azure Landing Zone Foundation Template:**

| Resource Type                  | Monthly Cost | Purpose                              | Optimization Options                 |
| ------------------------------ | ------------ | ------------------------------------ | ------------------------------------ |
| **Container Registry Premium** | $49.99       | Enterprise security, geo-replication | Basic tier: $5.00 (dev)              |
| **App Service Plan B1**        | $13.14       | Basic web workloads                  | Free tier (limitations)              |
| **Private Endpoint**           | $7.30        | Secure connectivity                  | Public endpoints (free, less secure) |
| **Private DNS Zone**           | $0.50        | DNS resolution                       | Required for private networking      |
| **Total Fixed Costs**          | **$70.94**   | **Per month**                        | **Sandbox optimized: ~$18**          |

**Usage-Based Resources:**

- **Log Analytics:** $2.76/GB ingested
- **Storage Account:** $0.0196/GB + operations
- **VNet Peering:** $0.01/GB transferred
- **Container Registry Storage:** $0.10/GB over 500GB

#### Cost Comparison by Environment

| Environment        | Monthly Cost | Key Features                      | Use Case                 |
| ------------------ | ------------ | --------------------------------- | ------------------------ |
| **Development**    | $18-25       | Basic tiers, public endpoints     | Learning, testing        |
| **Sandbox**        | $30-35       | Standard tiers, basic security    | Proof of concept         |
| **Production**     | $70-100      | Premium tiers, private networking | Enterprise workloads     |
| **Enterprise ALZ** | $4,140+      | Full compliance, redundancy       | Multi-subscription setup |

### ⚙️ Setup & Configuration

#### Quick Setup (5 minutes)

1. **Get Infracost API Key:**

   - Sign up at https://dashboard.infracost.io
   - Free tier: 10,000 resources/month

2. **Configure Locally:**

   ```bash
   # Install Infracost
   brew install infracost

   # Set API key
   infracost configure set api_key ico-your-api-key-here

   # Test on Azure Landing Zone
   cd blueprints/terraform/foundation
   infracost breakdown --path .
   ```

3. **GitHub Integration:**
   ```bash
   # Add repository secret
   Repository → Settings → Secrets and variables → Actions
   Name: INFRACOST_API_KEY
   Value: ico-your-api-key-here
   ```

#### Configuration Files

**Project Configuration** (`infracost.yml`):

```yaml
version: 0.1
projects:
  - path: blueprints/terraform/foundation
    name: alz-terraform-foundation
    terraform_plan_flags: -var-file=terraform.tfvars
currency: USD
```

**Usage Patterns** (`infracost-usage.yml`):

```yaml
resource_usage:
  azurerm_log_analytics_workspace.main:
    monthly_data_ingestion_gb: 50 # Monitoring data

  azurerm_storage_account.main:
    storage_gb: 1000 # Application data
    monthly_tier_1_requests: 100000 # Read operations
```

### 🎯 Cost Optimization

#### Development Environment Optimization

**Reduce costs to ~$18/month:**

```yaml
# terraform.tfvars - Development settings
enable_container_registry = false        # Save $50/month
# OR
container_registry_sku = "Basic"         # Save $45/month
enable_private_endpoints = false         # Save $8/month
app_service_plan_sku = "F1"              # Free tier (limitations)
```

#### Production Cost Management

**Optimize without sacrificing security:**

- **Reserved Instances:** 37% savings for predictable workloads
- **Azure Hybrid Benefit:** Use existing Windows licenses
- **Auto-shutdown:** Schedule VM downtime for dev/test environments
- **Right-sizing:** Monitor actual usage vs. allocated resources

#### Cost Monitoring Dashboard

**Track costs across environments:**

- 📊 **GitHub Actions Summary:** Automatic cost tracking in workflows
- 📈 **Deployment Reports:** Cost breakdown in HTML dashboards
- 🚨 **Budget Alerts:** Configurable thresholds for cost overruns
- 📱 **Mobile Notifications:** Slack/Teams integration for cost alerts

### 🔍 Troubleshooting & Best Practices

#### Common Issues

**Issue**: Infracost shows "price not found"

```bash
# Solution: Update to latest module versions
terraform init -upgrade
infracost breakdown --path .
```

**Issue**: Cost estimates seem high

```bash
# Solution: Check for premium SKUs
grep -r "Premium\|Standard" *.tf
# Consider Basic tiers for development
```

#### Best Practices

1. **Regular Reviews:** Review cost estimates monthly
2. **Environment Parity:** Keep cost configurations aligned across environments
3. **Team Training:** Ensure developers understand cost implications
4. **Budget Monitoring:** Set up Azure Cost Management budgets for actual tracking
5. **Automation:** Use Infracost in CI/CD for every infrastructure change

### 📚 Cost Resources

#### Documentation

- [Complete Cost Estimation Guide](docs/cost-estimation-guide.md) - Detailed setup and usage
- [Infracost Test Results](docs/infracost-test-results.md) - Real-world analysis results
- [Cost Optimization Examples](docs/cost-optimization-examples.md) - Savings strategies

#### Tools & APIs

- [Infracost Documentation](https://www.infracost.io/docs/) - Official Infracost docs
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) - Manual cost estimation
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/) - Actual spend tracking

---

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

**Cost-effective validation:** Test all AVM patterns in a single subscription for ~$30/month without Management Group requirements.

**Quick deployment:**

```bash
az login
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters blueprints/bicep/hub-spoke/main.parameters.json \
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

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Special thanks to:

- **[Azure Landing Zones Community](https://aka.ms/alz/community)** for enterprise-grade architecture guidance and patterns
- **[Azure Verified Modules (AVM) Community](https://aka.ms/avm/community)** for production-ready Infrastructure as Code modules
- **VS Code Extension Teams** for [Terraform](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform) and [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep) development tools
- **Warp Team** for building AI-enhanced development workflows

---

**📝 Article:** [AI-Powered GitOps for Azure Landing Zones](https://www.linkedin.com/pulse/ai-powered-gitops-azure-landing-zones-verified-matthias-buchhorn-roth-hqlke/?trackingId=28d0MXV%2Bux4OpZszqzWQxw%3D%3D)
**🏗️ AVM Version:** 0.4.0+
**📅 Last Updated:** 2025-09-28
**👨‍💻 Author:** Matthias Buchhorn-Roth
