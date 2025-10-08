# GitHub Actions Workflows Documentation

This document provides an overview of all GitHub Actions workflows in this Azure Landing Zone repository.

## 🎯 Core Deployment Workflows

### 1. Bicep ALZ Sandbox (`bicep-alz-sandbox.yml`)

**Purpose**: Deploy and validate Azure Landing Zone using Bicep templates
**Triggers**:

- Manual dispatch with environment selection
- Push to `main` branch (paths: `blueprints/bicep/**`)

**Features**:

- 🧪 What-if deployment analysis
- 🔒 Security scans with Trivy and Checkov
- 📊 Cost estimation with Infracost
- 🧹 Automatic resource cleanup after deployment
- 📄 Deployment reports generation
- ✅ Bicep template validation and linting

**Parameters**:

- `environment`: Target environment (sandbox, dev, staging, prod)
- `auto_approve`: Skip manual approval for deployment
- `cleanup_after_deploy`: Clean up resources after successful deployment

### 2. Terraform ALZ Deployment (`terraform-alz-deployment.yml`)

**Purpose**: Deploy Azure Landing Zone using Terraform
**Triggers**:

- Manual dispatch with environment selection
- Push to `main` branch (paths: `blueprints/terraform/**`)

**Features**:

- 🔄 Automatic state management with workspace selection
- 🔍 Resource conflict detection and import handling
- 🛡️ Security compliance scanning
- 💰 Cost estimation and analysis
- 📋 Terraform plan validation
- 🧹 Post-deployment cleanup capability

**Parameters**:

- `environment`: Target environment (sandbox, dev, staging, prod)
- `auto_approve`: Skip manual approval for deployment
- `cleanup_enabled`: Enable resource cleanup after deployment

**Recent Improvements**:

- ✅ Enhanced error handling for existing resource conflicts
- 📥 Automatic resource import when conflicts detected
- 🔄 Retry logic for failed deployments due to resource conflicts

### 3. Terraform ALZ Full Deployment (`terraform-alz-full-deployment.yml`)

**Purpose**: Complete full-scale Terraform ALZ deployment with all components
**Triggers**: Manual dispatch only (for production-ready deployments)

**Features**:

- 🏗️ Full enterprise-scale deployment
- 🔐 Enhanced security validation
- 📊 Comprehensive cost analysis
- 🎯 Multi-subscription support
- 📈 Advanced monitoring and alerting setup

## 🔒 Security & Compliance

### 4. Security Compliance (`security-compliance.yml`)

**Purpose**: Comprehensive security scanning and compliance validation
**Triggers**:

- Pull requests to `main`
- Manual dispatch
- Schedule: Daily at 2 AM UTC

**Tools Used**:

- 🛡️ Trivy for vulnerability scanning
- ✅ Checkov for infrastructure-as-code security
- 🔍 Azure Policy compliance checks
- 🔐 Secret scanning and validation

### 5. Infrastructure Validation (`infrastructure-validation.yml`)

**Purpose**: Validate infrastructure code quality and best practices
**Triggers**:

- Pull requests
- Push to feature branches

**Validations**:

- 📝 Terraform/Bicep syntax validation
- 🎨 Code formatting checks
- 📊 Template complexity analysis
- 🏷️ Naming convention validation

## 🧹 Cleanup & Maintenance

### 6. Terraform ALZ Cleanup (`terraform-alz-cleanup.yml`)

**Purpose**: Clean up Terraform-deployed ALZ resources
**Triggers**:

- Manual dispatch
- Scheduled cleanup (can be configured)

**Features**:

- 🗑️ Complete resource group cleanup with 'tf' prefix
- 🔄 Workspace-aware cleanup
- 🛡️ Safety checks and confirmation prompts
- 📋 Cleanup summary reporting

**Parameters**:

- `environment`: Environment to clean up
- `force_cleanup`: Skip confirmation prompts
- `resource_group_pattern`: Custom pattern for resource groups to clean

## 💰 Cost Management

### 7. Infracost (`infracost.yml`)

**Purpose**: Automated cost estimation for infrastructure changes
**Triggers**:

- Pull requests
- Manual dispatch

**Features**:

- 💵 Cost diff analysis on PRs
- 📊 Monthly cost projections
- 🎯 Resource-level cost breakdown
- 📈 Cost trend analysis

## 🔄 Development Workflows

### 8. Pre-commit (`pre-commit.yml`)

**Purpose**: Automated code quality checks before commits
**Triggers**: Pull requests

**Checks**:

- 🎨 Code formatting (Terraform, Bicep, YAML)
- 🔍 Linting and syntax validation
- 🛡️ Security pre-checks
- 📝 Documentation updates

### 9. Deploy Reports to Pages (`deploy-reports-to-pages.yml`)

**Purpose**: Publish deployment reports and documentation to GitHub Pages
**Triggers**:

- Completion of deployment workflows
- Manual dispatch

**Content**:

- 📊 Deployment summaries
- 💰 Cost analysis reports
- 🔒 Security scan results
- 📈 Infrastructure metrics

## 🚀 Usage Guidelines

### For Sandbox Development

1. Use `bicep-alz-sandbox.yml` for Bicep-based deployments
2. Use `terraform-alz-deployment.yml` for Terraform-based deployments
3. Enable `cleanup_after_deploy` to automatically clean up test resources
4. Monitor costs through Infracost integration

### For Production Deployments

1. Use `terraform-alz-full-deployment.yml` for complete enterprise deployments
2. Always review security compliance results before deployment
3. Ensure all validation workflows pass
4. Use manual approval gates for critical environments

### Cleanup Best Practices

1. Run cleanup workflows regularly for sandbox environments
2. Use resource group naming prefixes ('tf' for Terraform, 'bi' for Bicep) for easy identification
3. Monitor resource usage and costs through reports

## 🔧 Configuration

### Required Secrets

- `ARM_CLIENT_ID`: Azure service principal client ID
- `ARM_CLIENT_SECRET`: Azure service principal secret
- `ARM_SUBSCRIPTION_ID`: Target Azure subscription ID
- `ARM_TENANT_ID`: Azure tenant ID
- `INFRACOST_API_KEY`: Infracost API key for cost estimation

### Environment Configuration

Each workflow supports multiple environments with different approval requirements:

- **sandbox**: Auto-approval available, automatic cleanup
- **dev**: Manual approval, optional cleanup
- **staging**: Manual approval, no automatic cleanup
- **prod**: Manual approval, enhanced security checks

## 📚 Additional Resources

- [Azure Landing Zone Documentation](../docs/README.md)
- [Terraform Configuration](../blueprints/terraform/README.md)
- [Bicep Templates](../blueprints/bicep/README.md)
- [Security Guidelines](../docs/security/README.md)
- [Cost Management](../docs/cost-management/README.md)
