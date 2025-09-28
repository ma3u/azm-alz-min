# WARP.md - AI Assistant Guide

This file provides **essential guidance for Warp AI** when working with this Azure Landing Zone repository. Focus on pre-commit hook support and avoid overwhelming users with code examples.

## 🎯 Purpose

Warp AI should help users successfully run pre-commit hooks and follow established patterns. Always reference existing documentation instead of providing extensive code examples.

## 🚨 Critical Rules for AI Assistance

### Rule #1: Pre-commit Hook Support Priority

**Primary Focus:** Help users pass pre-commit validation by:

- Fixing naming convention violations
- Resolving security policy issues
- Correcting Bicep/Terraform syntax errors
- Guiding AVM module usage

**Reference:** [Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md)

### Rule #2: Use Existing Working Templates

**Recommended templates (in priority order):**

1. `infra/accelerator/simple-sandbox.bicep` - Battle-tested sandbox ALZ
2. `infra/accelerator/alz-subscription-vending-corrected.bicep` - Enterprise ALZ
3. `infra/terraform/simple-sandbox/` - Terraform alternative

**Reference:** [AVM Deployment Guide](docs/avm-deployment-guide.md)

### Rule #3: Reference Documentation, Don't Duplicate

Instead of providing extensive code examples, guide users to:

- [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - Policy rules
- [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - Common fixes
- [AVM Modules Guide](docs/avm-modules-guide.md) - Module usage

### Rule #4: Tool Version Awareness

**User Environment (macOS):**

- Terraform: Use `terraform1.9` (not `terraform`)
- Azure CLI: Standard `az` command
- Pre-commit: `pre-commit` framework

**Reference:** User has specific tool versions - always check before suggesting commands.

## 🊨 MANDATORY: Run Validation Before Any Template Changes

**CRITICAL:** Always run the deployment validation script before and after making any template modifications:

```bash
# Run comprehensive validation
./scripts/validate-deployment.sh
```

**This script validates:**

- ✅ Prerequisites (Azure CLI, Terraform, etc.)
- ✅ Bicep template compilation
- ✅ Terraform validation
- ✅ AVM module version checks
- ✅ Pre-commit hook status
- ✅ Template consistency
- ✅ Security configuration

**When to run:**

1. **Before making changes** - Establish baseline state
2. **After template modifications** - Verify changes don't break existing functionality
3. **Before deployment** - Final validation check
4. **When troubleshooting** - Identify current issues

**Note:** The script provides color-coded output and detailed summaries. If validation fails, review the failed checks before proceeding.

## 🎯 AI Assistant Workflow

### 1. Pre-commit Hook Issues

**When users report pre-commit failures:**

1. Identify the specific hook that failed
2. Reference [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) for solutions
3. Provide **minimal** fix commands (not extensive explanations)
4. Guide to relevant documentation section

### 2. Template Development

**When users want to create/modify templates:**

1. Check if existing template suits their needs
2. Reference [AVM Modules Guide](docs/avm-modules-guide.md) for module selection
3. Guide to official AVM registries for latest versions:
   - Bicep: [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules)
   - Terraform: [AVM Terraform Registry](https://registry.terraform.io/search/modules?q=avm)
4. Avoid recreating functionality that exists in working templates

### 3. Common Pre-commit Hook Failures

**Naming Convention Issues:**

- Fix with: Reference [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md)
- Key rule: Use `lower()` for storage accounts and container registries

**Security Policy Violations:**

- Fix with: Check [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md)
- Common: Missing HTTPS enforcement, public access enabled

**Terraform Validation:**

- Use `terraform1.9 validate` (not `terraform`)
- Reference: [Terraform Deployment Guide](docs/terraform-deployment-guide.md)

**Bicep Compilation:**

- Use `az bicep build --file template.bicep`
- Reference: [AVM Deployment Guide](docs/avm-deployment-guide.md)

## 🛠️ Essential Tool Commands

### Pre-commit Hook Validation

```bash
# Install and run pre-commit hooks
pre-commit install
pre-commit run --all-files
```

### Template Validation

```bash
# Bicep validation
az bicep build --file template.bicep

# Terraform validation (use terraform1.9)
terraform1.9 validate
```

### Quick AVM Module Check

```bash
# Check Bicep module availability
az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/avm/res/SERVICE/RESOURCE/tags/list" | jq -r '.tags[]' | sort -V | tail -5

# Browse Terraform AVM modules
# Visit: https://registry.terraform.io/search/modules?q=avm
```

---

## 📚 Related Documents

### Primary References for AI Assistance

**Pre-commit Hook Support:**

- [Pre-commit Hooks Guide](docs/pre-commit-hooks-guide.md) - Complete hook documentation
- [Pre-commit Errors Analysis](docs/pre-commit-errors-analysis.md) - Common failures and fixes
- [Azure Sandbox Policies Overview](docs/azure-sandbox-policies-overview.md) - Policy requirements

**Template Development:**

- [AVM Deployment Guide](docs/avm-deployment-guide.md) - Azure Verified Modules usage
- [AVM Modules Guide](docs/avm-modules-guide.md) - Module selection and best practices
- [Terraform Deployment Guide](docs/terraform-deployment-guide.md) - Terraform-specific guidance

**Official Azure Documentation:**

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) - Official AVM registry
- [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules) - Source code for all AVM Bicep modules
- [AVM Terraform Registry](https://registry.terraform.io/search/modules?q=avm) - Terraform AVM modules search
- [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) - Microsoft ALZ guidance
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) - Bicep language reference

---

**Last Updated:** 2025-09-28  
**Purpose:** Warp AI guidance for pre-commit hook support and template development
