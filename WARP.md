# WARP.md - AI Assistant Guide

This file provides **essential guidance for Warp AI** when working with this Azure Landing Zone repository. Focus on pre-commit hook support and avoid overwhelming users with code examples.

## 🎉 CURRENT STATUS (Updated Sep 30, 2025 - 05:40 UTC)

### ✅ GitHub Actions Authentication FULLY CONFIGURED

**Service Principal Setup Complete:**

- **Name:** `sp-github-actions-alz-sandbox`
- **Client ID:** `539d936b-8e13-444b-bc84-85b54bddf2c5`
- **Status:** ✅ WORKING - Authenticated and tested
- **Scope:** Limited to Sopra Steria sandbox subscription only
- **GitHub Secrets:** All 5 secrets configured and working

**Workflows Tested:**

- ✅ Security & Compliance Scanning - SUCCESS (authentication verified)
- ✅ Pre-commit hooks - Working (prettier formatting as expected)
- ✅ Service Principal can authenticate and access Azure resources
- ✅ All GitHub secrets properly encrypted and available to workflows

**Setup Files Created:**

- `automation/scripts/setup-github-auth.sh` - Automated setup script
- `docs/github-auth-setup-guide.md` - Manual setup guide
- `.secrets/github-auth-setup-report.md` - Complete setup documentation
- README.md updated with GitHub Actions Authentication Setup section

### 🚀 READY FOR NEXT PHASE: Infrastructure Deployment

**Available Templates (Ready to Deploy):**

- `blueprints/bicep/hub-spoke/main.bicep` - Battle-tested Hub-Spoke ALZ
- `blueprints/bicep/foundation/main.bicep` - Foundation ALZ template
- `blueprints/terraform/foundation/` - Terraform alternative

**Workflow Triggers:**

- Manual: `gh workflow run "🚀 Azure Landing Zone CI/CD Pipeline"`
- Automatic: Changes to `infra/**` directory will trigger deployment
- Files copied from blueprints to infra/ will trigger automated deployment

**Next Steps Available:**

1. 🏗️ **Deploy Infrastructure** - Copy template to `infra/` to trigger deployment
2. 🛡️ **Run Security Workflows** - All compliance scanning ready with authentication
3. 📊 **Generate Reports** - Deployment reporting with live Azure data
4. 🔄 **Scale Production** - Create additional Service Principals for prod environments

### 🏗️ DEPLOYMENT COMMANDS (Ready to Execute)

**Option 1: Manual Workflow Trigger (Recommended)**

```bash
# Trigger deployment workflow manually with specific environment
gh workflow run "🚀 Azure Landing Zone CI/CD Pipeline" \
  --field environment=sandbox \
  --field force_deploy=true
```

**Option 2: Automatic Trigger via File Changes**

```bash
# Copy working template to infra/ directory to trigger automatic deployment
mkdir -p infra/bicep/foundation
cp blueprints/bicep/foundation/main.bicep infra/bicep/foundation/main.bicep
cp blueprints/bicep/foundation/main.parameters.json infra/bicep/foundation/main.parameters.json
git add infra/
git commit -m "🚀 Deploy ALZ Foundation - Testing GitHub Actions authentication"
git push origin main
```

**Option 3: Direct Deployment Script (Bypass CI/CD)**

```bash
# Use deployment reporting script for immediate deployment + reporting
./automation/scripts/deploy-with-report.sh \
  blueprints/bicep/foundation/main.bicep \
  blueprints/bicep/foundation/main.parameters.json
```

### 📊 REPORT GENERATION (Post-Deployment)

**After any deployment, always generate reports:**

```bash
# Generate comprehensive deployment report with live Azure data
./automation/scripts/generate-deployment-report.sh

# Deploy reports to GitHub Pages for sharing
./automation/scripts/deploy-reports-to-pages.sh

# Check deployment status
gh run list --limit 5
```

### 🛡️ SECURITY WORKFLOW TESTING

**Test security scanning with authentication:**

```bash
# Trigger security workflow manually
gh workflow run "Security & Compliance Scanning"

# Check security scan results
gh run list --workflow="Security & Compliance Scanning" --limit 3
```

### 🎯 EXPECTED OUTCOMES

**Successful Foundation ALZ Deployment Should Create:**

- 📏 **Resource Group:** `rg-alz-sandbox-sandbox`
- 🔐 **Key Vault:** `kv-alz-sb-{unique-id}` with RBAC enabled
- 🌐 **Virtual Network:** `vnet-alz-sandbox-sandbox` (10.0.0.0/16)
  - Subnet: `subnet-keyvault` (10.0.1.0/24)
  - Subnet: `subnet-private-endpoints` (10.0.2.0/24)
  - Subnet: `subnet-workloads` (10.0.10.0/24)
- 📊 **Log Analytics:** `log-alz-sandbox-{unique-id}`
- 💰 **Estimated Cost:** ~$25-35/month (Standard Key Vault + VNet + Log Analytics)

**Workflow Success Indicators:**

- ✅ Azure authentication successful
- ✅ Bicep template compilation
- ✅ Security scanning completed
- ✅ Resource deployment successful
- ✅ Post-deployment validation passed

### 🔧 TROUBLESHOOTING GUIDE

**Common Issues and Solutions:**

1. **GitHub Actions Authentication Fails:**

   ```bash
   # Check secrets are configured
   gh secret list

   # Test Service Principal locally
   az login --service-principal \
     --username $(cat .secrets/sp-client-id.txt) \
     --password $(cat .secrets/sp-client-secret.txt) \
     --tenant 8b87af7d-8647-4dc7-8df4-5f69a2011bb5
   ```

2. **Workflow Not Triggering:**

   ```bash
   # Check workflow files exist and are valid
   gh workflow list

   # Force trigger manually
   gh workflow run "🚀 Azure Landing Zone CI/CD Pipeline" --field force_deploy=true
   ```

3. **Deployment Fails - Resource Names:**

   ```bash
   # Common issue: Key Vault name too long or already exists
   # Solution: Templates use uniqueString() - should be unique automatically
   # Check Azure portal for existing resources
   ```

4. **Security Scan Failures:**
   ```bash
   # Expected: Some security warnings in sandbox mode
   # Critical failures only block production deployments
   # Check .checkov.yaml for sandbox exceptions
   ```

## 🎯 Purpose

Warp AI should help users successfully run pre-commit hooks and follow established patterns. Always reference existing documentation instead of providing extensive code examples.

## 🚨 Critical Rules for AI Assistance

### Rule #1: Pre-commit Hook Support Priority

**Primary Focus:** Help users pass pre-commit validation by:

- Fixing naming convention violations
- Resolving security policy issues
- Correcting Bicep/Terraform syntax errors
- Guiding AVM module usage

**Reference:** [Pre-commit Hooks Guide](documentation/content/pre-commit-hooks-guide.md)

### Rule #2: Use Existing Working Templates

**Recommended templates (in priority order):**

1. `blueprints/bicep/hub-spoke/main.bicep` - Battle-tested sandbox ALZ (formerly simple-sandbox.bicep)
2. `blueprints/bicep/foundation/main.bicep` - Basic foundation ALZ
3. `blueprints/terraform/foundation/` - Terraform alternative

**Reference:** [AVM Deployment Guide](documentation/content/avm-deployment-guide.md)

### Rule #3: Reference Documentation, Don't Duplicate

Instead of providing extensive code examples, guide users to:

- [Azure Sandbox Policies Overview](documentation/content/azure-sandbox-policies-overview.md) - Policy rules
- [Pre-commit Errors Analysis](documentation/content/pre-commit-errors-analysis.md) - Common fixes
- [AVM Modules Guide](documentation/content/avm-modules-guide.md) - Module usage

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

## 📊 MANDATORY: Generate Deployment Reports After Each Deployment

**CRITICAL:** Always create deployment reports after successful infrastructure deployments to track costs, resources, and security metrics over time.

### Deployment Report Creation Process

```bash
# After successful deployment, generate comprehensive report
./automation/scripts/generate-deployment-report.sh
```

**Report includes:**

- 📦 **Resource Count**: Number of deployed Azure resources
- 💰 **Cost Analysis**: Estimated monthly costs in USD
- 🛡️ **Security Score**: Security policy compliance percentage
- ⏱️ **Deployment Time**: Duration and timestamp
- 📍 **Template Used**: Which ALZ template was deployed
- 🏷️ **Environment**: Sandbox, Development, or Production designation

**When to generate reports:**

1. **After sandbox deployments** - Track cost optimization (~$18-30/month expected)
2. **After production deployments** - Monitor enterprise costs (~$4,140/month expected)
3. **After template modifications** - Compare before/after metrics
4. **Monthly reviews** - Historical cost and security trend analysis

**Report storage:** All reports are stored in `reports/deployments/` with timestamp-based naming:

- Format: `YYYYMMDD-HHMMSS-deployment-report.json`
- Dashboard view: Available in the deployment reports interface

**Example report metrics for cost-optimized sandbox:**

```
Status: succeeded
Resources: 7-12 (depending on enabled features)
Cost: $18-30 USD/month
Security: 85-90% (with sandbox exceptions)
Template: hub-spoke sandbox ALZ
```

**Cost tracking benefits:**

- Validate sandbox stays within budget (~$20-30/month)
- Compare different ALZ template costs
- Monitor resource optimization opportunities
- Track security policy compliance over time
- Historical deployment success rates

## 🎯 AI Assistant Workflow

### 1. Pre-commit Hook Issues

**When users report pre-commit failures:**

1. Identify the specific hook that failed
2. Reference [Pre-commit Errors Analysis](documentation/content/pre-commit-errors-analysis.md) for solutions
3. Provide **minimal** fix commands (not extensive explanations)
4. Guide to relevant documentation section

### 2. Template Development

**When users want to create/modify templates:**

1. Check if existing template suits their needs
2. Reference [AVM Modules Guide](documentation/content/avm-modules-guide.md) for module selection
3. Guide to official AVM registries for latest versions:
   - Bicep: [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules)
   - Terraform: [AVM Terraform Registry](https://registry.terraform.io/search/modules?q=avm)
4. Avoid recreating functionality that exists in working templates

### 3. Post-Deployment Reporting

**When users complete deployments:**

1. **Immediately after deployment** - Always generate deployment report
2. **Verify cost expectations** - Sandbox should be ~$18-30/month, Enterprise ~$4,140/month
3. **Document any cost deviations** - Compare with expected baseline
4. **Archive reports** - Store in `reports/deployments/` directory
5. **Update deployment dashboard** - Refresh metrics for tracking

**AI should remind users:**

- "Don't forget to generate your deployment report!"
- "Let's verify the costs match your expectations"
- "Would you like me to help analyze the deployment metrics?"

### 4. Common Pre-commit Hook Failures

**Naming Convention Issues:**

- Fix with: Reference [Azure Sandbox Policies Overview](documentation/content/azure-sandbox-policies-overview.md)
- Key rule: Use `lower()` for storage accounts and container registries

**Security Policy Violations:**

- Fix with: Check [Pre-commit Errors Analysis](documentation/content/pre-commit-errors-analysis.md)
- Common: Missing HTTPS enforcement, public access enabled

**Terraform Validation:**

- Use `terraform1.9 validate` (not `terraform`)
- Reference: [Terraform Deployment Guide](documentation/content/terraform-deployment-guide.md)

**Bicep Compilation:**

- Use `az bicep build --file template.bicep`
- Reference: [AVM Deployment Guide](documentation/content/avm-deployment-guide.md)

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

- [Pre-commit Hooks Guide](documentation/content/pre-commit-hooks-guide.md) - Complete hook documentation
- [Pre-commit Errors Analysis](documentation/content/pre-commit-errors-analysis.md) - Common failures and fixes
- [Azure Sandbox Policies Overview](documentation/content/azure-sandbox-policies-overview.md) - Policy requirements

**Template Development:**

- [AVM Deployment Guide](documentation/content/avm-deployment-guide.md) - Azure Verified Modules usage
- [AVM Modules Guide](documentation/content/avm-modules-guide.md) - Module selection and best practices
- [Terraform Deployment Guide](documentation/content/terraform-deployment-guide.md) - Terraform-specific guidance

**Official Azure Documentation:**

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) - Official AVM registry
- [AVM Bicep Registry](https://github.com/Azure/bicep-registry-modules) - Source code for all AVM Bicep modules
- [AVM Terraform Registry](https://registry.terraform.io/search/modules?q=avm) - Terraform AVM modules search
- [Azure Landing Zones](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) - Microsoft ALZ guidance
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) - Bicep language reference

---

**Last Updated:** 2025-09-28
**Purpose:** Warp AI guidance for pre-commit hook support and template development
