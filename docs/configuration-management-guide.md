# Azure Landing Zone Configuration Management Guide

## Overview

This guide explains the centralized configuration management system for Azure Landing Zone deployments. The system uses a single YAML configuration file to control component enablement across both Bicep and Terraform implementations.

## Key Benefits

- **Single Source of Truth**: One configuration file controls all deployments
- **Environment-Specific Overrides**: Different settings for dev, test, and production
- **Component Flexibility**: Enable/disable services based on requirements
- **Cost Optimization**: Automatic SKU adjustments for different environments
- **Consistency**: Same configuration generates both Bicep and Terraform files

## Configuration File Structure

The main configuration file is located at `config/alz-components.yaml` and contains the following sections:

### Global Settings

```yaml
global:
  environment: 'sandbox' # Environment name
  organizationPrefix: 'alz' # Naming prefix
  location: 'westeurope' # Azure region
```

### Component Categories

- **Networking**: VNets, subnets, peering, firewalls
- **Security**: Bastion, Key Vault, managed identities
- **Applications**: Web Apps, Container Apps, Functions
- **Containers**: ACR, AKS clusters
- **Data**: PostgreSQL, Storage Accounts
- **Monitoring**: Log Analytics, Application Insights
- **Identity**: Managed identities, RBAC

## Usage Examples

### 1. Generate Configuration Files

**Generate all files:**

```bash
# Generate both Bicep and Terraform configurations
./scripts/parse-config.py config/alz-components.yaml --all

# Output:
# ✅ Generated Bicep parameters: main.parameters.generated.json
# ✅ Generated Terraform variables: terraform.generated.tfvars
# ✅ Generated status report: component-status.md
```

**Generate specific files:**

```bash
# Just Bicep parameters
./scripts/parse-config.py config/alz-components.yaml \
  --bicep-output blueprints/bicep/hub-spoke/main.parameters.json

# Just Terraform variables
./scripts/parse-config.py config/alz-components.yaml \
  --terraform-output blueprints/terraform/foundation/terraform.tfvars

# Component status report
./scripts/parse-config.py config/alz-components.yaml \
  --status-report docs/current-component-status.md
```

### 2. Environment-Specific Deployments

**Sandbox Environment (Cost-Optimized):**

```yaml
global:
  environment: 'sandbox'

containers:
  containerRegistry:
    enabled: true
    sku: 'Standard' # Cost savings vs Premium

applications:
  webApps:
    enabled: true
    servicePlan:
      sku: 'B1' # Basic tier for testing

security:
  azureFirewall:
    enabled: false # Skip expensive components
```

**Production Environment (Full Security):**

```yaml
global:
  environment: 'prod'

security:
  azureFirewall:
    enabled: true # Full security stack
    sku: 'Premium'
  keyVault:
    sku: 'premium' # HSM support

monitoring:
  sentinelSiem:
    enabled: true # Advanced threat detection
  defender:
    enabled: true
```

### 3. AKS-Focused Configuration

**Enable AKS with optimized settings:**

```yaml
containers:
  aks:
    enabled: true
    version: '1.30'
    privateCluster: true

    systemNodePool:
      nodeCount: 2
      vmSize: 'Standard_d4s_v5'
      autoScaling: true
      minCount: 1
      maxCount: 5

    userNodePool:
      enabled: true
      nodeCount: 2
      vmSize: 'Standard_d4s_v5'
      autoScaling: true
      minCount: 0
      maxCount: 10
```

### 4. Development vs Production Overrides

The configuration supports environment-specific overrides:

```yaml
# Default configuration
containers:
  containerRegistry:
    sku: 'Premium'

# Environment-specific overrides
environments:
  sandbox:
    containers:
      containerRegistry:
        sku: 'Standard' # Override for cost savings
        publicNetworkAccess: true # Allow public access for testing

  prod:
    containers:
      containerRegistry:
        sku: 'Premium' # Keep premium for production
        geoReplication: true # Enable disaster recovery
```

## Component Implementation Status

| Component          | Bicep Status | Terraform Status | Configuration Key                        |
| ------------------ | ------------ | ---------------- | ---------------------------------------- |
| **Networking**     |
| Hub VNet           | ✅ Complete  | ✅ Complete      | `networking.hubVnet.enabled`             |
| Spoke VNet         | ✅ Complete  | ✅ Complete      | `networking.spokeVnet.enabled`           |
| VNet Peering       | ✅ Complete  | ✅ Complete      | `networking.peering.enabled`             |
| **Security**       |
| Azure Firewall     | ⚠️ Basic     | ⚠️ Basic         | `security.azureFirewall.enabled`         |
| Azure Bastion      | ✅ Complete  | ⚠️ Partial       | `security.azureBastion.enabled`          |
| Key Vault          | ✅ Complete  | ✅ Complete      | `identity.keyVault.enabled`              |
| **Applications**   |
| Web Apps           | ✅ Complete  | ✅ Complete      | `applications.webApps.enabled`           |
| Container Apps     | ⚠️ Basic     | ❌ Missing       | `applications.containerApps.enabled`     |
| Functions          | ⚠️ Basic     | ❌ Missing       | `applications.functions.enabled`         |
| **Containers**     |
| Container Registry | ✅ Complete  | ✅ Complete      | `containers.containerRegistry.enabled`   |
| AKS                | ⚠️ Basic     | ✅ Complete      | `containers.aks.enabled`                 |
| **Data Services**  |
| PostgreSQL         | ❌ Missing   | ❌ Missing       | `data.postgresql.enabled`                |
| Storage Account    | ✅ Complete  | ✅ Complete      | `data.storageAccount.enabled`            |
| **Monitoring**     |
| Log Analytics      | ✅ Complete  | ✅ Complete      | `monitoring.logAnalytics.enabled`        |
| App Insights       | ❌ Missing   | ❌ Missing       | `monitoring.applicationInsights.enabled` |

**Legend:** ✅ Complete, ⚠️ Partial, ❌ Missing

## Deployment Workflow

### 1. Configure Components

```bash
# Edit the main configuration file
vim config/alz-components.yaml

# Set environment and enable desired components
# Adjust SKUs for cost optimization
```

### 2. Generate Deployment Files

```bash
# Generate both Bicep and Terraform configurations
./scripts/parse-config.py config/alz-components.yaml --all

# Validate generated configurations
git diff --name-only  # Review changes
```

### 3. Deploy Infrastructure

**Using Bicep:**

```bash
# Deploy with generated parameters
az deployment sub create \
  --location "westeurope" \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters main.parameters.generated.json \
  --name "alz-$(date +%Y%m%d-%H%M%S)"
```

**Using Terraform:**

```bash
# Deploy with generated variables
cd blueprints/terraform/foundation
terraform init
terraform plan -var-file="terraform.generated.tfvars" -out="tfplan"
terraform apply tfplan
```

### 4. Monitor and Validate

```bash
# Check component status report
cat component-status.md

# Validate deployment
./automation/scripts/validate-deployment.sh
```

## Advanced Configuration Patterns

### Cost Optimization by Environment

**Automatically adjust SKUs based on environment:**

```yaml
costOptimization:
  dev:
    containerRegistry:
      sku: 'Basic' # $5/month vs $50/month
    webApps:
      servicePlan:
        sku: 'F1' # Free tier
  prod:
    containerRegistry:
      sku: 'Premium' # Full features
      geoReplication: true # Disaster recovery
```

### Conditional Component Dependencies

**Enable components based on other components:**

```yaml
containers:
  aks:
    enabled: true
# Automatically enable ACR when AKS is enabled
# Automatically configure private endpoints
# Set up RBAC assignments for AKS → ACR access
```

### Network Topology Customization

**Customize network ranges for different environments:**

```yaml
networking:
  hubVnet:
    addressSpace: '10.0.0.0/16'
    subnets:
      aks: '10.1.20.0/22' # 1024 IPs for large clusters
      postgresql: '10.1.10.0/26' # 62 IPs for database

environments:
  prod:
    networking:
      hubVnet:
        addressSpace: '172.16.0.0/16' # Different range for production
```

## Validation and Best Practices

### Configuration Validation

The configuration system includes built-in validation:

```yaml
validation:
  required:
    - 'global.environment'
    - 'global.organizationPrefix'
    - 'global.location'

  constraints:
    organizationPrefix:
      pattern: '^[a-z0-9]+$'
      minLength: 2
      maxLength: 10

    environment:
      allowedValues: ['sandbox', 'dev', 'test', 'prod']
```

### Best Practices

1. **Version Control**: Always commit configuration changes with descriptive messages
2. **Environment Isolation**: Use separate configuration files for different environments
3. **Cost Monitoring**: Review SKU settings regularly to optimize costs
4. **Security Review**: Validate security settings before production deployments
5. **Documentation**: Keep component status documentation updated

### Common Patterns

**Basic Development Setup:**

```yaml
# Minimal configuration for development
applications:
  webApps:
    enabled: true

containers:
  containerRegistry:
    enabled: true
    sku: 'Standard'

data:
  storageAccount:
    enabled: true

monitoring:
  logAnalytics:
    enabled: true
```

**Full Production Setup:**

```yaml
# Complete production configuration
security:
  azureFirewall:
    enabled: true
  keyVault:
    sku: 'premium'

applications:
  webApps:
    enabled: true
  containerApps:
    enabled: true

containers:
  aks:
    enabled: true
    privateCluster: true
  containerRegistry:
    enabled: true
    sku: 'Premium'
    geoReplication: true

data:
  postgresql:
    enabled: true
    highAvailability: true

monitoring:
  logAnalytics:
    enabled: true
  sentinelSiem:
    enabled: true
  defender:
    enabled: true
```

## Troubleshooting

### Common Issues

**Configuration not applied:**

```bash
# Regenerate configuration files
./scripts/parse-config.py config/alz-components.yaml --all

# Check for syntax errors in YAML
python3 -c "import yaml; yaml.safe_load(open('config/alz-components.yaml'))"
```

**Deployment failures:**

```bash
# Check generated parameter files
cat main.parameters.generated.json | jq '.'
cat terraform.generated.tfvars

# Validate against templates
az deployment sub validate \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters main.parameters.generated.json
```

**Cost surprises:**

```bash
# Review component status and SKU settings
./scripts/parse-config.py config/alz-components.yaml --status-report
cat component-status.md

# Check cost optimization settings
grep -A 10 "costOptimization:" config/alz-components.yaml
```

## Integration with CI/CD

### GitHub Actions Integration

```yaml
# .github/workflows/deploy-alz.yml
name: Deploy Azure Landing Zone
on:
  push:
    paths:
      - 'config/alz-components.yaml'
      - 'blueprints/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate Configuration
        run: |
          ./scripts/parse-config.py config/alz-components.yaml --all

      - name: Deploy Infrastructure
        run: |
          az deployment sub create \
            --location "westeurope" \
            --template-file blueprints/bicep/hub-spoke/main.bicep \
            --parameters main.parameters.generated.json
```

### Azure DevOps Integration

```yaml
# azure-pipelines.yml
trigger:
  paths:
    include:
      - config/alz-components.yaml
      - blueprints/*

stages:
  - stage: GenerateConfig
    jobs:
      - job: ParseConfig
        steps:
          - script: ./scripts/parse-config.py config/alz-components.yaml --all
            displayName: 'Generate deployment configurations'

          - task: PublishBuildArtifacts@1
            inputs:
              artifactName: 'configurations'
```

## Future Enhancements

### Planned Features

1. **GUI Configuration Editor**: Web-based interface for editing configurations
2. **Cost Estimation Integration**: Automatic cost calculation based on configuration
3. **Policy Validation**: Validate configurations against Azure policies
4. **Template Generation**: Generate custom Bicep/Terraform templates
5. **Multi-Region Support**: Configure deployments across multiple regions

### Contributing

To contribute to the configuration system:

1. Fork the repository
2. Create a feature branch
3. Update configuration schema in `config/alz-components.yaml`
4. Update parser in `scripts/parse-config.py`
5. Add tests and documentation
6. Submit a pull request

---

For questions or support, see the main [README.md](../README.md) or create an issue in the repository.
