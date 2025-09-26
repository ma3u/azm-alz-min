# Pre-commit Hooks Guide for Terraform and Bicep

This guide provides comprehensive documentation for the pre-commit hooks implemented in the Azure Landing Zone project, covering both Terraform and Bicep infrastructure as code validation.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Bicep Pre-commit Hooks](#bicep-pre-commit-hooks)
- [Terraform Pre-commit Hooks](#terraform-pre-commit-hooks)
- [Security and Compliance Hooks](#security-and-compliance-hooks)
- [Configuration Management](#configuration-management)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Integration with CI/CD](#integration-with-cicd)

## Overview

The Azure Landing Zone project implements a comprehensive set of pre-commit hooks that automatically validate, format, and secure your infrastructure code before it gets committed to the repository. This ensures high code quality, security compliance, and adherence to best practices.

### Key Benefits

- 🛡️ **Security First**: Prevents security misconfigurations from entering the codebase
- 🔍 **Quality Assurance**: Validates syntax, formatting, and best practices
- 🚀 **AVM Compliance**: Enforces Azure Verified Modules usage and standards
- ⚡ **Fast Feedback**: Catches issues locally before pushing to remote
- 🤝 **Team Consistency**: Ensures consistent code style across all contributors
- 📊 **Compliance**: Validates against Azure policies and naming conventions

## Quick Start

### Installation

```bash
# 1. Install pre-commit framework
pip3 install pre-commit --break-system-packages

# 2. Install required tools
brew install terraform tflint tfsec checkov

# 3. Install Azure CLI and Bicep (if not already installed)
brew install azure-cli
az bicep install

# 4. Install detect-secrets for secret scanning
pip3 install detect-secrets --break-system-packages

# 5. Install pre-commit hooks in the repository
cd /path/to/azure-landingzone
pre-commit install

# 6. Run setup script (optional - installs all tools automatically)
chmod +x scripts/setup-pre-commit.sh
./scripts/setup-pre-commit.sh
```

### First Run

```bash
# Run hooks on all files (first-time setup)
pre-commit run --all-files

# Run specific hook
pre-commit run bicep-lint --all-files
pre-commit run terraform_fmt --all-files
```

## Bicep Pre-commit Hooks

### 1. Bicep Lint

**Purpose**: Validates Bicep template syntax and compiles to ARM templates

```yaml
- id: bicep-lint
  name: Bicep Lint
  description: Lint Bicep files for syntax and best practices
  entry: az bicep build --file
  language: system
  files: \.bicep$
```

**What it checks:**

- ✅ Template syntax validation
- ✅ Parameter and variable references
- ✅ Resource dependencies
- ✅ ARM template compatibility
- ✅ Type safety and schema validation

**Example output:**

```bash
✅ infra/accelerator/simple-sandbox.bicep validation complete
⚠️  Warning BCP318: Module output may be null
❌ Error BCP035: Missing required property "scope"
```

**Common fixes:**

```bicep
// Fix missing scope
module example 'modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup  // Add missing scope
  params: {
    // parameters
  }
}

// Fix null reference
output result string = module.?outputs.?result ?? 'default-value'
```

### 2. Bicep Format

**Purpose**: Ensures consistent code formatting and structure

```yaml
- id: bicep-format
  name: Bicep Format
  description: Format Bicep files for consistency
  entry: bash -c
  # Validates files can be built correctly
```

**What it formats:**

- ✅ Consistent indentation (2 spaces)
- ✅ Property alignment
- ✅ Comment formatting
- ✅ Line length optimization
- ✅ Resource block organization

### 3. Bicep AVM Module Verification

**Purpose**: Enforces Azure Verified Modules (AVM) usage and compliance

```yaml
- id: bicep-avm-check
  name: Bicep AVM Module Verification
  description: Verify AVM module usage and versions
```

**What it checks:**

- 🔍 **AVM Module Detection**: Identifies `br/public:avm/` references
- 📦 **Version Pinning**: Ensures specific versions (not `:latest`)
- 📋 **Module Compliance**: Validates AVM parameter schemas
- ⚠️ **Best Practices**: Warns about non-AVM module usage

**Example output:**

```bash
🔍 Verifying AVM module usage...
✅ AVM modules found in simple-sandbox.bicep
📦 Found AVM module: br/public:avm/res/container-registry/registry:0.9.3
⚠️  Warning: AVM module should use specific version: br/public:avm/res/storage/storage-account:latest
✅ simple-sandbox.bicep AVM compliance check complete
```

**AVM Best Practices:**

```bicep
// ✅ Good: Specific version pinning
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: 'acrDeployment'
  scope: hubResourceGroup
  params: {
    name: acrName
    location: location
    acrSku: 'Premium'  // Use AVM parameter names
  }
}

// ❌ Bad: Using :latest
module storage 'br/public:avm/res/storage/storage-account:latest' = {
  // This will trigger a warning
}
```

### 4. Bicep Security Scan

**Purpose**: Identifies security misconfigurations and compliance issues

```yaml
- id: bicep-security-scan
  name: Bicep Security Scan
  description: Security analysis for Bicep templates
```

**Security Checks:**

#### Critical Issues (Block Commit)

- ❌ **Hardcoded Secrets**: Detects potential secrets in templates
- ❌ **HTTPS Enforcement Disabled**: `httpsOnly: false`
- ❌ **Admin Users Enabled**: `adminUserEnabled: true`
- ❌ **Public Blob Access**: `allowBlobPublicAccess: true`
- ❌ **Weak TLS Versions**: `minimumTlsVersion: 'TLS1_0'`

#### Warning Issues (Allow with Warning)

- ⚠️ **Public Network Access**: `publicNetworkAccess: 'Enabled'`
- ⚠️ **Default Allow Actions**: `defaultAction: 'Allow'`
- ⚠️ **Missing Soft Delete**: Key Vaults without soft delete

**Example fixes:**

```bicep
// ✅ Secure Configuration
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  properties: {
    allowBlobPublicAccess: false    // Disable public access
    httpsOnly: true                // Enforce HTTPS
    minimumTlsVersion: 'TLS1_2'    // Strong TLS version
    networkAcls: {
      defaultAction: 'Deny'        // Zero trust approach
    }
  }
}
```

## Terraform Pre-commit Hooks

### 1. Terraform Format

**Purpose**: Automatically formats Terraform code for consistency

```yaml
- id: terraform_fmt
  args:
    - --args=-diff
    - --args=-write=true
```

**What it formats:**

- ✅ **Indentation**: Consistent 2-space indentation
- ✅ **Alignment**: Property alignment within blocks
- ✅ **Spacing**: Consistent spacing around operators
- ✅ **Line Breaks**: Proper line breaks for readability

**Example formatting:**

```hcl
# Before formatting
resource"azurerm_storage_account""example"{
name="storageaccount"
location=azurerm_resource_group.example.location
account_tier="Standard"
}

# After formatting
resource "azurerm_storage_account" "example" {
  name         = "storageaccount"
  location     = azurerm_resource_group.example.location
  account_tier = "Standard"
}
```

### 2. Terraform Validate

**Purpose**: Validates Terraform configuration syntax and logic

```yaml
- id: terraform_validate
  args:
    - --args=-json
```

**What it validates:**

- ✅ **Syntax Errors**: HCL syntax validation
- ✅ **Resource Configuration**: Valid resource blocks
- ✅ **Variable References**: Proper variable usage
- ✅ **Provider Requirements**: Required providers defined
- ✅ **Type Consistency**: Variable and output types

**Example output:**

```json
{
  "format_version": "1.0",
  "valid": false,
  "error_count": 2,
  "diagnostics": [
    {
      "severity": "error",
      "summary": "Unsupported block type",
      "detail": "Blocks of type \"ip_rules\" are not expected here."
    }
  ]
}
```

### 3. TFLint (Advanced Terraform Linting)

**Purpose**: Advanced Terraform linting for best practices and standards

```yaml
- id: terraform_tflint
  args:
    - --args=--only=terraform_deprecated_interpolation
    - --args=--only=terraform_unused_declarations
    # ... more rules
```

**Enabled Rules:**

#### Code Quality

- `terraform_deprecated_interpolation`: Flags old `"${var.name}"` syntax
- `terraform_unused_declarations`: Finds unused variables, locals, outputs
- `terraform_comment_syntax`: Validates comment formatting

#### Documentation

- `terraform_documented_outputs`: Ensures outputs have descriptions
- `terraform_documented_variables`: Ensures variables have descriptions
- `terraform_typed_variables`: Ensures variables have type definitions

#### Standards

- `terraform_naming_convention`: Validates resource naming
- `terraform_required_version`: Ensures Terraform version constraints
- `terraform_required_providers`: Validates provider requirements
- `terraform_module_pinned_source`: Ensures module versions are pinned

**Example output:**

```bash
Warning: [Fixable] variable "additional_tags" is declared but not used
  on variables.tf line 110:
 110: variable "additional_tags" {

Reference: https://github.com/terraform-linters/tflint-ruleset-terraform/blob/v0.13.0/docs/rules/terraform_unused_declarations.md
```

### 4. tfsec (Terraform Security Scanner)

**Purpose**: Security-focused scanning for Terraform configurations

```yaml
- id: terraform_tfsec
  args:
    - --args=--minimum-severity=MEDIUM
    - --args=--exclude-downloaded-modules
```

**Security Categories:**

#### Network Security

- Key Vault network ACL configurations
- Storage account public access
- Network security group rules
- Firewall configurations

#### Data Protection

- Encryption at rest and in transit
- Key management practices
- Data classification and handling
- Backup and retention policies

#### Access Control

- RBAC configurations
- Service principal permissions
- Identity and authentication
- Privilege escalation risks

**Example output:**

```bash
Result #1 CRITICAL Vault network ACL does not block access by default
────────────────────────────────────────────────────────────────────────────────
  terraform-sandbox.tf:159
────────────────────────────────────────────────────────────────────────────────
  157    network_acls {
  158      bypass         = "AzureServices"
  159      default_action = var.enable_private_endpoint ? "Deny" : "Allow"
  160    }
```

### 5. Checkov (Compliance Scanner)

**Purpose**: Infrastructure as Code compliance and security scanning

```yaml
- id: terraform_checkov
  args:
    - --args=--skip-check CKV_AZURE_1 # Allow storage public access for sandbox
    - --args=--framework terraform
```

**Compliance Frameworks:**

- 🏛️ **CIS Benchmarks**: Center for Internet Security baselines
- 📋 **NIST**: National Institute of Standards and Technology
- 🔒 **SOC 2**: Service Organization Control 2
- ☁️ **Azure Security Benchmark**: Microsoft cloud security baseline
- 🌍 **GDPR**: General Data Protection Regulation compliance

**Policy Categories:**

- Identity and Access Management (IAM)
- Data protection and encryption
- Network security and segmentation
- Logging and monitoring
- Backup and disaster recovery
- Container security
- Secrets management

**Example output:**

```bash
Check: CKV_AZURE_33: "Ensure storage account uses the latest TLS version"
        FAILED for resource: azurerm_storage_account.sandbox
        File: /sandbox/terraform-sandbox.tf:120-135
        Guide: https://docs.bridgecrew.io/docs/ensure-storage-account-uses-the-latest-tls-version
```

## Security and Compliance Hooks

### 1. Detect Secrets

**Purpose**: Prevents secrets from being committed to the repository

```yaml
- id: detect-secrets
  args: ["--baseline", ".secrets.baseline"]
  exclude: \.secrets/
```

**Detection Capabilities:**

- 🔐 **API Keys**: AWS, Azure, GCP keys
- 🗝️ **Private Keys**: RSA, SSH private keys
- 🎫 **Tokens**: JWT, OAuth tokens
- 📧 **Credentials**: Database connection strings
- 🔢 **High Entropy**: Randomly generated strings

**Managing False Positives:**

```bash
# For documentation examples, add pragma comment
password = "example-password-here" # pragma: allowlist secret

# Update baseline for legitimate patterns
detect-secrets scan --baseline .secrets.baseline
```

### 2. Azure Policy Compliance Check

**Purpose**: Validates templates against common Azure policies

```yaml
- id: azure-policy-check
  name: Azure Policy Compliance Check
  description: Check templates against common Azure policies
```

**Policy Validations:**

#### Required Tags

- `Environment` (dev, test, prod)
- `CostCenter` (billing allocation)
- `Owner` (resource ownership)
- `Purpose` (resource purpose)

#### Naming Conventions

- Key Vault: `kv-*` pattern
- Storage Account: lowercase, no hyphens
- Container Registry: `acr*` pattern
- Resource Groups: `rg-*` pattern

**Example validation:**

```bash
Running Azure Policy compliance checks...
Checking simple-sandbox.bicep for required tags...
✅ simple-sandbox.bicep has all required tags
Checking naming conventions...
✅ simple-sandbox.bicep passed naming convention checks
```

### 3. Resource Naming Convention

**Purpose**: Enforces Azure resource naming standards

```yaml
- id: resource-naming-check
  name: Azure Resource Naming Convention
  description: Validate Azure resource naming conventions
```

**Naming Standards:**

- **Key Vault**: `kv-[workload]-[environment]-[region]`
- **Storage Account**: `st[workload][environment][unique]` (lowercase)
- **Container Registry**: `acr[workload][environment][unique]`
- **Virtual Network**: `vnet-[workload]-[environment]-[region]`
- **Subnet**: `snet-[purpose]-[workload]-[environment]`

### 4. Cost Estimation

**Purpose**: Analyzes cost implications of infrastructure changes

```yaml
- id: cost-estimation
  name: Infrastructure Cost Estimation
  description: Estimate costs for infrastructure changes
```

**Cost Analysis:**

- 💰 **Premium SKUs**: Flags expensive service tiers
- 🖥️ **Large VM Sizes**: Identifies high-cost compute resources
- 🌍 **Multi-Region**: Reviews geo-replication costs
- 🌐 **Public IPs**: Tracks additional networking costs
- 📊 **Resource Count**: Estimates deployment scale

## Configuration Management

### Pre-commit Configuration File

The main configuration is stored in `.pre-commit-config.yaml`:

```yaml
# Global configuration
default_stages: [pre-commit, pre-push]
fail_fast: false

# CI/CD specific configuration
ci:
  autoupdate_schedule: monthly
  skip: []
  submodules: false
```

### Environment-Specific Settings

Different environments can have different validation rules:

```bash
# Sandbox: Relaxed security for testing
--args=--skip-check CKV_AZURE_1  # Allow public storage access

# Production: Strict security enforcement
--args=--minimum-severity=LOW     # Catch all security issues
```

### Custom Hook Configuration

You can customize hook behavior through environment variables:

```bash
# Skip specific hooks for emergency commits
SKIP=terraform_tfsec,checkov git commit -m "Emergency fix"

# Run only specific hooks
pre-commit run terraform_fmt terraform_validate --all-files
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Tool Not Found Errors

**Error**: `command not found: terraform/tflint/tfsec`

**Solution**:

```bash
# Install missing tools
brew install terraform tflint tfsec checkov
pip3 install detect-secrets --break-system-packages

# Or run the setup script
./scripts/setup-pre-commit.sh
```

#### 2. Permission Denied

**Error**: `Permission denied` when running hooks

**Solution**:

```bash
# Fix script permissions
chmod +x scripts/setup-pre-commit.sh

# Reinstall hooks
pre-commit uninstall
pre-commit install
```

#### 3. Hook Configuration Errors

**Error**: `Hook failed` or configuration issues

**Solution**:

```bash
# Update hook configurations
pre-commit autoupdate

# Clean and reinstall
pre-commit clean
pre-commit install --install-hooks
```

#### 4. Terraform Init Failures

**Error**: `terraform init failed`

**Solution**:

```bash
# Initialize Terraform directories manually
cd infra/terraform && terraform init
cd sandbox && terraform init

# Or skip Terraform hooks temporarily
SKIP=terraform_validate,terraform_tflint git commit -m "Fix terraform config"
```

#### 5. False Positive Secret Detection

**Error**: Legitimate code flagged as secrets

**Solution**:

```bash
# Add pragma comment to code
secret_example = "not-a-real-secret"  # pragma: allowlist secret

# Update secrets baseline
detect-secrets scan --baseline .secrets.baseline
```

### Debug Mode

Run hooks with verbose output for debugging:

```bash
# Verbose mode
pre-commit run --verbose terraform_tflint

# Debug specific file
pre-commit run bicep-lint --files infra/main.bicep --verbose
```

### Manual Hook Execution

Test hooks individually:

```bash
# Test Bicep hooks
pre-commit run bicep-lint --all-files
pre-commit run bicep-security-scan --files infra/main.bicep

# Test Terraform hooks
pre-commit run terraform_fmt --files infra/terraform/
pre-commit run terraform_tfsec --files sandbox/
```

## Best Practices

### 1. Regular Maintenance

```bash
# Update hook versions monthly
pre-commit autoupdate

# Clean old hook environments
pre-commit clean

# Update tool versions
brew upgrade terraform tflint tfsec
pip3 install --upgrade detect-secrets checkov
```

### 2. Team Onboarding

```bash
# Setup script for new team members
./scripts/setup-pre-commit.sh

# Verify installation
pre-commit run --all-files

# Training commands
pre-commit run --help
pre-commit run terraform_fmt --files sandbox/terraform-sandbox.tf
```

### 3. Selective Hook Execution

```bash
# Skip hooks for specific commits
SKIP=terraform_tfsec git commit -m "WIP: terraform config"

# Run only formatting hooks
pre-commit run terraform_fmt bicep-format prettier

# Run security hooks only
pre-commit run detect-secrets bicep-security-scan terraform_tfsec
```

### 4. Performance Optimization

```bash
# Use specific file patterns
pre-commit run terraform_fmt --files infra/terraform/*.tf

# Skip slow hooks for quick iterations
SKIP=terraform_checkov,terraform_tfsec git commit -m "Quick fix"
```

### 5. Documentation Standards

```hcl
# Always document variables
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

# Document outputs
output "storage_account_name" {
  description = "Name of the created storage account"
  value       = azurerm_storage_account.main.name
}
```

## Integration with CI/CD

### GitHub Actions Integration

The pre-commit hooks integrate with GitHub Actions for comprehensive validation:

```yaml
# .github/workflows/infrastructure-validation.yml
- name: Run Pre-commit Hooks
  uses: pre-commit/action@v3.0.0
  with:
    extra_args: --all-files
```

### Azure DevOps Integration

```yaml
# azure-pipelines.yml
- script: |
    pre-commit run --all-files
  displayName: "Run Pre-commit Hooks"
```

### Local Development Workflow

```bash
# 1. Make infrastructure changes
vim infra/accelerator/simple-sandbox.bicep

# 2. Test changes locally
az bicep build --file infra/accelerator/simple-sandbox.bicep

# 3. Run pre-commit hooks
pre-commit run --files infra/accelerator/simple-sandbox.bicep

# 4. Commit changes (hooks run automatically)
git add .
git commit -m "feat: add container registry with vulnerability scanning"

# 5. Push to remote (triggers CI/CD)
git push origin feature/acr-integration
```

### Hook Performance Metrics

Monitor hook execution time:

```bash
# Time all hooks
time pre-commit run --all-files

# Profile specific hooks
time pre-commit run terraform_checkov --files sandbox/terraform-sandbox.tf
```

## Conclusion

The pre-commit hooks provide a comprehensive safety net for your infrastructure code, ensuring:

- 🛡️ **Security**: No security misconfigurations reach production
- 🔍 **Quality**: Consistent, high-quality infrastructure code
- 📋 **Compliance**: Adherence to Azure policies and standards
- 🚀 **Performance**: Fast feedback loop for developers
- 🤝 **Collaboration**: Consistent standards across the team

By following this guide, your team can maintain secure, compliant, and high-quality infrastructure as code while leveraging the power of Azure Verified Modules and modern DevOps practices.

---

## Quick Reference

### Essential Commands

```bash
# Setup
pre-commit install

# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run bicep-lint --files infra/main.bicep

# Skip hooks
SKIP=terraform_tfsec git commit -m "WIP"

# Update hooks
pre-commit autoupdate
```

### Support Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Bicep Best Practices](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices)
