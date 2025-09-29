# AVM Modules Guide for Azure Landing Zone

## Overview

This guide outlines the Azure Verified Modules (AVM) that should be used for implementing a comprehensive Azure Landing Zone (ALZ). AVM provides Microsoft-validated, production-ready infrastructure modules.

## Why Use AVM Modules?

- **Microsoft Validated**: All modules are tested and validated by Microsoft
- **Production Ready**: Built with enterprise security and compliance in mind
- **Consistent**: Standardized parameter schemas across all modules
- **Maintained**: Regular updates and security patches from Microsoft
- **Best Practices**: Implements Azure Well-Architected Framework principles

## AVM Pattern Modules (Orchestration Level)

These high-level pattern modules orchestrate multiple resource modules to create complete architectures:

### Core Landing Zone Patterns

| Module                                           | Version | Purpose                                       | Template Reference       |
| ------------------------------------------------ | ------- | --------------------------------------------- | ------------------------ |
| `avm/ptn/lz/sub-vending`                         | 0.2.0   | Subscription creation and basic configuration | `alz-avm-patterns.bicep` |
| `avm/ptn/network/hub-networking`                 | 0.1.0   | Hub networking with Firewall, Bastion, DNS    | `alz-avm-patterns.bicep` |
| `avm/ptn/network/private-link-private-dns-zones` | Latest  | Private DNS zone management                   | Future enhancement       |

### Application Platform Patterns

| Module                    | Version | Purpose                                 | Use Case         |
| ------------------------- | ------- | --------------------------------------- | ---------------- |
| `avm/ptn/app-service-lza` | Latest  | App Service Landing Zone accelerator    | Web applications |
| `avm/ptn/aca-lza`         | Latest  | Container Apps Landing Zone accelerator | Microservices    |
| `avm/ptn/ai-platform`     | Latest  | AI/ML platform setup                    | AI workloads     |

## AVM Resource Modules (Component Level)

These modules deploy individual Azure resources with best practices:

### Networking Resources

| Resource               | Module                                   | Version | Security Features                   |
| ---------------------- | ---------------------------------------- | ------- | ----------------------------------- |
| Virtual Network        | `avm/res/network/virtual-network`        | 0.1.6+  | NSG integration, DDOS protection    |
| Network Security Group | `avm/res/network/network-security-group` | 0.1.3+  | Security rules, flow logs           |
| Azure Firewall         | `avm/res/network/azure-firewall`         | Latest  | Premium tier, DNS proxy             |
| Bastion Host           | `avm/res/network/bastion-host`           | 0.3.0+  | Standard/Premium SKU, native client |
| Application Gateway    | `avm/res/network/application-gateway`    | 0.4.0+  | WAF v2, SSL termination             |
| Private DNS Zone       | `avm/res/network/private-dns-zone`       | 0.2.4+  | VNet links, auto-registration       |
| Public IP Address      | `avm/res/network/public-ip-address`      | 0.5.0+  | Standard SKU, zone redundancy       |

### Compute & Applications

| Resource                   | Module                            | Version | Key Features                        |
| -------------------------- | --------------------------------- | ------- | ----------------------------------- |
| App Service Plan           | `avm/res/web/serverfarm`          | 0.2.0+  | Auto-scaling, zone redundancy       |
| Web App                    | `avm/res/web/site`                | 0.8.0+  | VNet integration, private endpoints |
| Container Apps Environment | `avm/res/app/managed-environment` | 0.7.0+  | VNet integration, KEDA scaling      |
| Container App Job          | `avm/res/app/job`                 | 0.1.1+  | Scheduled/event-driven jobs         |

### Data & Storage

| Resource                   | Module                                      | Version | Security Features                     |
| -------------------------- | ------------------------------------------- | ------- | ------------------------------------- |
| Storage Account            | `avm/res/storage/storage-account`           | 0.14.0+ | Private endpoints, encryption at rest |
| PostgreSQL Flexible Server | `avm/res/db-for-postgresql/flexible-server` | 0.4.0+  | VNet integration, high availability   |
| Key Vault                  | `avm/res/key-vault/vault`                   | 0.4.0+  | RBAC, soft delete, HSM backing        |

### Monitoring & Security

| Resource                | Module                                   | Version | Capabilities                    |
| ----------------------- | ---------------------------------------- | ------- | ------------------------------- |
| Log Analytics Workspace | `avm/res/operational-insights/workspace` | 0.3.4+  | Data retention, security events |
| Security Center         | `avm/res/security/assessment`            | Latest  | Compliance monitoring           |

## Implementation Strategy

### 1. Full AVM Pattern Approach (Recommended for Production)

Use the complete AVM pattern template for enterprise deployments:

```bash
# Deploy with full AVM patterns (requires Management Group scope)
az deployment mg create \
  --management-group-id "YOUR_MG_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-avm-patterns.bicep \
  --parameters infra/accelerator/alz-avm-patterns.parameters.json
```

**Benefits:**

- Automatic subscription provisioning
- Enterprise-grade networking with hub-spoke topology
- Built-in security and compliance
- Private DNS zones and endpoints
- Azure Firewall and Bastion integration

### 2. Simplified Sandbox Approach

Use individual resource modules for testing and development:

```bash
# Deploy to existing subscription (sandbox testing)
az deployment sub create \
  --location "westeurope" \
  --template-file infra/accelerator/sandbox-alz.bicep \
  --parameters infra/accelerator/sandbox-alz.parameters.json
```

**Benefits:**

- No subscription creation required
- Faster deployment for testing
- Uses same AVM resource modules
- SSH key-based authentication

## Security Enhancements

### SSH Key Authentication

- Generated RSA 4096-bit keys stored in `.secrets/`
- Keys automatically excluded from git via `.gitignore`
- Used for secure VM access via Azure Bastion
- Database authentication uses generated passwords (migrate to Key Vault for production)

### Network Security

- Network Security Groups with restrictive rules
- Private endpoints for storage and database
- Azure Firewall for hub traffic inspection
- Private DNS zones for service resolution
- Application Gateway with Web Application Firewall

## Migration Path

### Phase 1: Sandbox Testing

1. Deploy simplified sandbox template
2. Validate SSH key authentication
3. Test application workloads
4. Verify networking and security

### Phase 2: Production Preparation

1. Deploy full AVM pattern template
2. Configure management groups
3. Set up subscription vending
4. Implement private endpoints
5. Configure Azure Firewall policies

### Phase 3: Enterprise Integration

1. Integrate with existing identity systems
2. Configure hybrid connectivity
3. Implement compliance policies
4. Set up monitoring and alerting

## Troubleshooting

### Common Issues

- **Module not found**: Use `br/public:` prefix for public registry
- **Version conflicts**: Check latest versions in AVM documentation
- **Permission denied**: Ensure proper RBAC for management group deployments
- **SSH key not found**: Verify `.secrets/azure-alz-key.pub` exists

### Validation Commands

```bash
# Validate AVM pattern template
az deployment mg validate \
  --management-group-id "YOUR_MG_ID" \
  --location "westeurope" \
  --template-file infra/accelerator/alz-avm-patterns.bicep \
  --parameters infra/accelerator/alz-avm-patterns.parameters.json

# Build sandbox template
az bicep build --file infra/accelerator/sandbox-alz.bicep
```

## Best Practices

1. **Always validate** templates before deployment
2. **Use SSH keys** instead of passwords
3. **Implement private endpoints** for data services
4. **Enable monitoring** from day one
5. **Tag all resources** consistently
6. **Use managed identities** where possible
7. **Follow least privilege** access principles
8. **Implement backup strategies** for data services

## Next Steps

1. Review the generated templates
2. Customize parameters for your environment
3. Deploy the sandbox environment first
4. Plan your production deployment strategy
5. Implement monitoring and governance

## Resources

- [Azure Verified Modules Repository](https://github.com/Azure/bicep-registry-modules)
- [AVM Pattern Documentation](https://azure.github.io/Azure-Verified-Modules/)
- [Azure Landing Zone Documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
