# 💰 Azure Landing Zone Cost Estimation Guide

## Overview

This guide explains the cost estimation approach for Azure Landing Zone infrastructure deployments, using **Infracost** for automated Terraform cost analysis and fallback methods for other templates.

## 🏗️ Cost Estimation Architecture

### Primary Approach: Infracost (Terraform)

- **Tool**: [Infracost](https://infracost.io) - Industry standard for IaC cost estimation
- **Scope**: All Terraform templates in `blueprints/terraform/`
- **Accuracy**: High - Uses real Azure pricing API
- **Update Frequency**: Real-time pricing data
- **CI/CD Integration**: Automated PR comments with cost diffs

### Fallback Approach: Template-Based Estimates

- **Scope**: Bicep templates and when Infracost is unavailable
- **Accuracy**: Moderate - Based on template patterns
- **Method**: Static estimates based on resource types and environment

## 🎯 Implementation Details

### 1. Infracost Configuration

**File**: `infracost.yml`

```yaml
version: 0.1
projects:
  - path: blueprints/terraform/foundation
    name: alz-terraform-foundation
    terraform_plan_flags: -var-file=terraform.tfvars
currency: USD
```

**Usage File**: `infracost-usage.yml` (optional)

- Defines typical usage patterns for more accurate estimates
- Includes storage sizes, compute hours, data transfer volumes
- Customizable per environment (sandbox vs production)

### 2. GitHub Actions Integration

**Workflow**: `.github/workflows/infracost.yml`

- **Triggers**: Pull requests touching Terraform files
- **Permissions**: Reads code, writes PR comments
- **Features**:
  - Cost estimates on PRs
  - Cost comparison between branches
  - Automated alerts for high costs
  - Detailed breakdowns by resource type

### 3. CI/CD Workflow Integration

**Workflow**: `.github/workflows/azure-landing-zone-cicd.yml`

- **Smart Detection**: Uses Infracost for Terraform, fallback for Bicep
- **Cost Tracking**: Stores estimates in environment variables
- **Alerting**: Warnings for costs > $50/month

## 📊 Cost Estimation Examples

### Terraform Foundation Template (Infracost)

```
Name                                         Monthly Qty  Unit         Monthly Cost

azurerm_container_registry.main
├─ Registry usage (Basic)                           1  monthly            $5.00
├─ Storage                                        100  GB                 $0.10
└─ Build vCPU                                       0  seconds            $0.00

azurerm_log_analytics_workspace.main
├─ Log data ingestion                             5   GB                 $11.50
├─ Log data export                                0   GB                 $0.00
└─ Basic logs data ingestion                      0   GB                 $0.00

azurerm_service_plan.main
└─ Basic (B1)                                   730   hours              $13.14

OVERALL TOTAL                                                             $29.74
```

### Fallback Estimates (Bicep/Template-Based)

- **Foundation Template**: $18/month (basic resources)
- **Hub-Spoke Template**: $35/month (networking + basic services)
- **Production Enterprise**: $4,140/month (full ALZ with premium features)

## 🔧 Setup Instructions

### Prerequisites

1. **Infracost Account**: Sign up at https://dashboard.infracost.io
2. **API Key**: Get your free API key (10,000 resources/month limit)
3. **GitHub Secrets**: Configure required secrets

### GitHub Secrets Configuration

```bash
# Required secrets for cost estimation
INFRACOST_API_KEY=ico-your-api-key-here
AZURE_CREDENTIALS={"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}
```

### Local Development Setup

```bash
# Install Infracost locally (macOS)
brew install infracost

# Configure API key
infracost configure set api_key ico-your-api-key-here

# Test cost estimation
cd blueprints/terraform/foundation
infracost breakdown --path .
```

## 🎨 Customization Options

### Environment-Specific Costs

Modify `infracost-usage.yml` to reflect your usage patterns:

```yaml
resource_usage:
  # Production environment - 24/7 operation
  azurerm_linux_virtual_machine.prod_vm:
    operating_system: linux
    monthly_hrs: 730

  # Development environment - 8 hours/day, 5 days/week
  azurerm_linux_virtual_machine.dev_vm:
    operating_system: linux
    monthly_hrs: 173
```

### Cost Policies

Set cost thresholds in workflows:

```yaml
# High cost alert threshold
COST_ALERT_THRESHOLD: '100'

# Warning threshold
COST_WARNING_THRESHOLD: '50'
```

### Multi-Currency Support

```yaml
# In infracost.yml
currency: EUR # USD, EUR, GBP, etc.
```

## 📈 Cost Monitoring & Optimization

### 1. PR-Level Cost Review

- **Automatic Comments**: Every PR shows cost impact
- **Cost Diffs**: Compare costs between changes
- **Approval Gates**: Block PRs with excessive cost increases

### 2. Resource-Level Insights

```
💰 Cost Breakdown by Service:
- Compute (VMs): $45.67 (62%)
- Storage: $12.34 (17%)
- Networking: $8.90 (12%)
- Monitoring: $6.83 (9%)
```

### 3. Optimization Recommendations

- **Right-sizing**: VM size recommendations
- **Reserved Instances**: For predictable workloads
- **Spot Instances**: For dev/test environments
- **Auto-shutdown**: Schedule VM downtime

## 🚨 Cost Alerting

### GitHub Actions Alerts

- **Warning**: Monthly cost > $50
- **Error**: Monthly cost > $100 (configurable)
- **PR Comments**: Detailed breakdown with recommendations

### Integration Options

- **Slack**: Cost alerts to team channels
- **Email**: Weekly cost summaries
- **Azure Cost Management**: Native Azure alerting

## 🔍 Troubleshooting

### Common Issues

**Issue**: Infracost API key invalid

```bash
# Solution: Update API key
infracost configure set api_key ico-new-api-key
```

**Issue**: Terraform init fails in CI/CD

```bash
# Solution: Check Azure credentials and permissions
az account show
```

**Issue**: Cost estimates seem inaccurate

```bash
# Solution: Update usage file with realistic values
# Edit infracost-usage.yml with actual usage patterns
```

### Debug Commands

```bash
# Test Infracost configuration
infracost breakdown --config-file infracost.yml --format json

# Validate Terraform configuration
terraform validate

# Check pricing data sources
infracost configure get pricing_api_endpoint
```

## 📚 Additional Resources

### Official Documentation

- [Infracost Documentation](https://www.infracost.io/docs/)
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/)

### Best Practices

- **Regular Reviews**: Review cost estimates monthly
- **Environment Parity**: Keep cost estimates updated across environments
- **Team Training**: Ensure team understands cost implications
- **Cost Budgets**: Set up Azure budgets for actual spend tracking

### Community Resources

- [Infracost GitHub](https://github.com/infracost/infracost)
- [Azure Cost Optimization Guide](https://docs.microsoft.com/azure/architecture/framework/cost/)
- [FinOps Foundation](https://www.finops.org/)

---

## 📝 Summary

This cost estimation approach provides:

✅ **Accurate Terraform Costs**: Real-time pricing via Infracost
✅ **Automated PR Integration**: Cost visibility before merge
✅ **Multi-Template Support**: Terraform + Bicep coverage
✅ **Configurable Alerting**: Prevent cost surprises
✅ **Optimization Guidance**: Actionable cost reduction tips

**Next Steps**: Configure your Infracost API key and start getting automated cost estimates on every infrastructure change!
