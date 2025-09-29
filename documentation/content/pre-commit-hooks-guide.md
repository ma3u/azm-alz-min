# Pre-commit Hooks Guide

This guide provides **essential setup and troubleshooting** for pre-commit hooks in the Azure Landing Zone project. For detailed configuration, see [official pre-commit documentation](https://pre-commit.com/).

## 🎯 Purpose

Pre-commit hooks automatically validate your infrastructure code before commits, ensuring:

- **Security compliance** - No hardcoded secrets or misconfigurations
- **Code quality** - Syntax validation and consistent formatting
- **AVM compliance** - Proper Azure Verified Modules usage
- **Policy adherence** - Azure naming conventions and governance

## 📋 Table of Contents

- [⚡ Quick Setup](#-quick-setup)
- [🔧 Available Hooks](#-available-hooks)
- [🚫 Common Issues & Fixes](#-common-issues--fixes)
- [📚 Official Documentation](#-official-documentation)
- [📚 Related Documents](#-related-documents)

---

## ⚡ Quick Setup

### Prerequisites

**Install required tools:** [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli), [Pre-commit](https://pre-commit.com/#install), [Terraform 1.9+](https://releases.hashicorp.com/terraform/)

### Installation

```bash
# Install pre-commit framework
pip install pre-commit

# Install pre-commit hooks in repository
pre-commit install

# Run on all files (first time)
pre-commit run --all-files
```

### Tool-Specific Setup

```bash
# macOS - Install validation tools
brew install tflint tfsec checkov
az bicep install

# Install secret detection
pip install detect-secrets
```

**Reference:** [Pre-commit Installation Guide](https://pre-commit.com/#install)

---

## 🔧 Available Hooks

### Bicep Validation

- **bicep-lint** - Syntax validation and ARM template compilation
- **bicep-format** - Code formatting consistency
- **bicep-avm-check** - Azure Verified Modules compliance
- **bicep-security-scan** - Security misconfiguration detection

### Terraform Validation

- **terraform_fmt** - Code formatting and alignment
- **terraform_validate** - Syntax and configuration validation
- **terraform_tflint** - Advanced linting and best practices
- **terraform_tfsec** - Security vulnerability scanning
- **terraform_checkov** - Compliance and policy validation

### Security & Compliance

- **detect-secrets** - Prevents secret leakage
- **azure-policy-check** - Azure Policy compliance
- **resource-naming-check** - Naming convention enforcement

**Configuration Details:** See [.pre-commit-config.yaml](.pre-commit-config.yaml)

---

## 🚫 Common Issues & Fixes

### 🔴 Bicep Issues

**Syntax Errors:**

```bash
# Fix: Validate template compilation
az bicep build --file template.bicep
```

**AVM Module Issues:**

- Use specific versions: `'br/public:avm/res/service/resource:0.4.0'`
- Check latest versions: [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules)

### 🔴 Terraform Issues

**Validation Failures:**

```bash
# Fix: Use correct Terraform version (macOS)
terraform1.9 validate  # Not 'terraform'
terraform1.9 fmt -recursive
```

**Naming Convention Violations:**

- Storage accounts: Use `lower()` function
- Follow [Azure naming conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)

### 🔴 Security Policy Violations

**Critical Issues (Must Fix):**

- ❌ Hardcoded secrets in code
- ❌ HTTPS enforcement disabled
- ❌ Public blob access enabled
- ❌ Weak TLS versions (< 1.2)

**Quick Fixes:**

```bicep
// Enable security best practices
properties: {
  httpsOnly: true
  minimumTlsVersion: 'TLS1_2'
  allowBlobPublicAccess: false
}
```

### 🛠️ Troubleshooting Steps

1. **Check specific hook failure:**

   ```bash
   pre-commit run [hook-name] --all-files
   ```

2. **Skip hook temporarily (debugging only):**

   ```bash
   SKIP=[hook-name] git commit -m "message"
   ```

3. **Update hooks:**
   ```bash
   pre-commit autoupdate
   pre-commit install --overwrite
   ```

**Detailed Analysis:** [Pre-commit Errors Analysis](pre-commit-errors-analysis.md)

---

## 📚 Official Documentation

### Tool Documentation

- [Pre-commit Framework](https://pre-commit.com/) - Installation and configuration
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/) - Azure command-line interface
- [Bicep Language](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) - Infrastructure as Code
- [Terraform](https://www.terraform.io/docs) - Multi-cloud infrastructure automation

### Validation Tools

- [TFLint](https://github.com/terraform-linters/tflint) - Terraform linter
- [TFSec](https://aquasecurity.github.io/tfsec/) - Terraform security scanner
- [Checkov](https://www.checkov.io/) - Infrastructure compliance scanner
- [detect-secrets](https://github.com/Yelp/detect-secrets) - Secret detection tool

### Azure Resources

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) - Official AVM documentation
- [Azure Security Benchmark](https://docs.microsoft.com/en-us/security/benchmark/azure/) - Security baseline
- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) - Resource naming guidelines

---

## 📚 Related Documents

- [Azure Sandbox Policies Overview](azure-sandbox-policies-overview.md) - Policy requirements and exceptions
- [Pre-commit Errors Analysis](pre-commit-errors-analysis.md) - Detailed error solutions
- [AVM Deployment Guide](avm-deployment-guide.md) - Azure Verified Modules usage
- [Terraform Deployment Guide](terraform-deployment-guide.md) - Terraform-specific procedures

---

**Last Updated:** 2025-09-28
**Purpose:** Essential pre-commit hooks setup and troubleshooting for Azure Landing Zone development
