# Terraform ALZ CI/CD Deployment Guide

This guide explains the automated Terraform deployment workflow for Azure Landing Zone infrastructure using GitHub Actions.

## 🚀 Workflow Overview

The Terraform ALZ deployment workflow (`terraform-alz-deployment.yml`) provides automated infrastructure deployment with the following features:

- **🔍 Automatic Triggering**: Runs on Terraform file changes
- **✅ Comprehensive Validation**: Format, security, and configuration checks
- **📋 Plan & Apply**: Safe deployment with plan artifacts
- **🌍 Multi-Environment**: Support for sandbox, dev, test environments
- **🛡️ Security-First**: Built-in security scanning and governance
- **🗑️ Cleanup Options**: Optional resource destruction for testing

## 🎯 Trigger Conditions

### Automatic Triggers

The workflow automatically triggers on:

```yaml
# Push to main/develop branches with Terraform changes
push:
  branches: [main, develop]
  paths:
    - 'infra/terraform/**/*.tf'
    - 'infra/terraform/**/*.tfvars'
    - 'infra/terraform/**/*.tfvars.json'

# Pull requests to main/develop with Terraform changes
pull_request:
  branches: [main, develop]
  paths:
    - 'infra/terraform/**/*.tf'
    - 'infra/terraform/**/*.tfvars'
```

### Manual Triggers

Manual execution via GitHub Actions UI with options:

- **Environment**: `sandbox` (default), `dev`, `test`
- **Destroy**: Enable resource cleanup after deployment
- **Auto-approve**: Skip manual approval (use with caution)

## 🔧 Workflow Jobs

### 1. Terraform Plan & Validation

**Purpose**: Validate and plan Terraform changes

**Key Steps**:

- 🎨 **Format Check**: Ensures consistent code formatting
- ✅ **Validation**: Validates Terraform syntax and configuration
- 🛡️ **Security Scan**: Checks for hardcoded secrets and insecure configurations
- 📋 **Plan Creation**: Generates execution plan for review

**Security Checks**:

```bash
# Hardcoded secrets detection
grep -iE "(password|secret|key|token).*=.*\"[^\"]{8,}\""

# Insecure configurations
- public_network_access_enabled = true
- admin_enabled = true
- https_only = false
```

### 2. Terraform Apply

**Purpose**: Deploy infrastructure changes

**Conditions**:

- ✅ Plan job succeeded with changes detected
- 🎯 Running on main/develop branch OR manual trigger
- 🛡️ Environment protection rules apply

**Key Features**:

- 📊 **Terraform Outputs**: Captures and uploads deployment outputs
- 🏷️ **Workspace Management**: Uses environment-specific workspaces
- 📝 **Deployment Summary**: Provides detailed deployment information

### 3. Terraform Destroy (Optional)

**Purpose**: Clean up test resources

**Conditions**:

- ✅ Apply job succeeded
- 🗑️ Destroy option enabled in manual trigger
- ⏱️ Waits 5 minutes before cleanup

## 🌍 Environment Strategy

### Sandbox Environment

- **Purpose**: Testing and validation
- **Approval**: No manual approval required
- **Resources**: Cost-optimized configurations
- **Cleanup**: Automatic with destroy option

### Development Environment

- **Purpose**: Development team integration
- **Approval**: Optional manual approval
- **Resources**: Development-appropriate sizing
- **Cleanup**: Manual or scheduled

### Production Environment

- **Purpose**: Live workloads (future)
- **Approval**: **Required** manual approval
- **Resources**: Production-grade configurations
- **Cleanup**: Manual only with additional safeguards

## 📋 Configuration Requirements

### GitHub Secrets

Required secrets for Azure authentication:

```bash
# Azure Service Principal credentials
AZURE_CLIENT_ID       # Service principal client ID
AZURE_CLIENT_SECRET   # Service principal client secret
AZURE_SUBSCRIPTION_ID # Target Azure subscription
AZURE_TENANT_ID       # Azure tenant ID

# Azure CLI credential JSON (alternative)
AZURE_CREDENTIALS     # JSON with clientId, clientSecret, subscriptionId, tenantId
```

### Repository Settings

**Environments** (configured in GitHub repository settings):

```yaml
sandbox:
  protection_rules: [] # No approval required

development:
  protection_rules:
    - required_reviewers: 1 # Optional approval

production:
  protection_rules:
    - required_reviewers: 2 # Required approval
    - branch_policy: main # Main branch only
```

## 🔍 Usage Examples

### Example 1: Sandbox Deployment via Push

```bash
# Make changes to Terraform files
echo 'variable "new_feature" { default = true }' >> infra/terraform/simple-sandbox/variables.tf

# Commit and push to develop branch
git add .
git commit -m "feat: add new terraform feature"
git push origin develop

# Workflow automatically triggers:
# ✅ Plan & Validation → 🚀 Apply to Sandbox
```

### Example 2: Manual Production Deployment

```bash
# 1. Navigate to GitHub Actions tab
# 2. Select "Terraform ALZ Deployment"
# 3. Click "Run workflow"
# 4. Configure:
#    - Environment: production
#    - Destroy: false
#    - Auto-approve: false
# 5. Click "Run workflow"

# Workflow execution:
# ✅ Plan & Validation → ⏳ Waiting for Approval → 🚀 Apply to Production
```

### Example 3: Test Deployment with Cleanup

```bash
# Manual workflow run with cleanup
# Configuration:
# - Environment: sandbox
# - Destroy: true
# - Auto-approve: true

# Workflow execution:
# ✅ Plan & Validation → 🚀 Apply to Sandbox → ⏱️ Wait 5min → 🗑️ Destroy Resources
```

## 📊 Workflow Outputs

### Plan Stage Outputs

```json
{
  "tfplanExitCode": "2",
  "changes_detected": "true"
}
```

### Apply Stage Outputs

```json
{
  "connection_info": {
    "web_app": {
      "hostname": "app-alz-web-sandbox.azurewebsites.net"
    },
    "container_registry": {
      "login_server": "acralzsandboxrzvc8h8b.azurecr.io"
    }
  }
}
```

### GitHub Summary

The workflow creates detailed summaries:

```markdown
## 🎉 Deployment Summary

**Environment:** sandbox
**Terraform Version:** 1.9.8  
**Deployment Time:** 2025-09-26 21:45:00 UTC

### 📋 Resources Deployed

- ✅ Hub Resource Group: rg-alz-hub-sandbox
- ✅ Container Registry: acralzsandboxrzvc8h8b
- ✅ Virtual Networks: Hub-Spoke with peering
```

## 🛡️ Security & Governance

### Built-in Security Checks

1. **Secret Detection**: Prevents hardcoded credentials
2. **Configuration Validation**: Enforces security best practices
3. **Plan Review**: Requires plan approval for sensitive environments
4. **Environment Protection**: GitHub environment rules

### Compliance Features

- **Audit Trail**: All deployments logged in GitHub Actions
- **Approval Gates**: Manual approval for production deployments
- **Change Tracking**: Git-based change history
- **Rollback Capability**: Terraform state management for rollbacks

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentication Failures

```bash
Error: building account: unable to configure ResourceManagerAccount
```

**Solution**: Verify Azure service principal credentials in GitHub secrets.

#### 2. Format Check Failures

```bash
❌ Format issues found in infra/terraform/simple-sandbox
```

**Solution**: Run `terraform fmt -recursive` locally before committing.

#### 3. Plan Failures

```bash
❌ Terraform plan failed
```

**Solution**: Check Terraform validation errors and resource conflicts.

#### 4. Environment Protection

```bash
⏳ Waiting for approval in environment 'production'
```

**Solution**: Approve deployment in GitHub repository → Environments → production.

### Debug Commands

```bash
# Check workflow logs in GitHub Actions
# Manual terraform operations:

cd infra/terraform/simple-sandbox

# Check current state
terraform state list

# Manual plan
terraform plan -var-file="terraform.tfvars"

# Check workspace
terraform workspace list
```

## 🚀 Advanced Configuration

### Custom Environments

Add new environments by:

1. **Update workflow environment mapping**:

```yaml
environment:
  name: ${{ github.event.inputs.environment || 'sandbox' }}
```

2. **Configure GitHub environment protection**:

```yaml
staging:
  protection_rules:
    - required_reviewers: 1
    - wait_timer: 5
```

3. **Add environment-specific variables**:

```yaml
env:
  TF_VAR_environment: ${{ github.event.inputs.environment }}
```

### Custom Validation

Extend security scanning:

```yaml
- name: 🔍 Custom Policy Check
  run: |
    # Custom policy validation
    if grep -r "allow_all" infra/terraform/; then
      echo "❌ 'allow_all' configurations not permitted"
      exit 1
    fi
```

### Backend Configuration

For production use, configure Terraform backend:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "alz-sandbox.tfstate"
  }
}
```

## 📈 Best Practices

### Development Workflow

1. **Branch Strategy**: Use feature branches for changes
2. **Small Changes**: Keep Terraform changes focused and small
3. **Testing**: Use sandbox environment for testing
4. **Documentation**: Update docs with infrastructure changes

### Security Practices

1. **Secrets Management**: Never commit secrets to repository
2. **Least Privilege**: Use minimal required permissions
3. **Environment Isolation**: Separate environments with workspace
4. **Approval Gates**: Require manual approval for production

### Monitoring & Maintenance

1. **Workflow Health**: Monitor GitHub Actions for failures
2. **Resource Monitoring**: Monitor deployed Azure resources
3. **State Management**: Regularly backup Terraform state
4. **Cost Management**: Monitor and optimize resource costs

## 📚 Related Documentation

- [Terraform Deployment Guide](terraform-deployment-guide.md)
- [Pre-commit Hooks Guide](pre-commit-hooks-guide.md)
- [Security & Compliance](security-compliance.md)
- [AVM Modules Guide](avm-modules-guide.md)
