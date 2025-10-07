# Managed Identity Comparison: Sandbox vs Production

**Last Updated:** $(date +%Y-%m-%d)
**Status:** ✅ **Active** - Managed identities implemented in sandbox, production policies defined

## 🎯 Overview

This document compares managed identity usage between your ALZ sandbox and production environments, highlighting security improvements and operational differences.

**Key Finding:** Managed identities are **already implemented** in sandbox and **mandatory** for production.

## 📋 Table of Contents

- [Current Implementation](#current-implementation)
- [Sandbox vs Production Comparison](#sandbox-vs-production-comparison)
- [Security Benefits](#security-benefits)
- [Migration Recommendations](#migration-recommendations)
- [Implementation Examples](#implementation-examples)

---

## 🔧 Current Implementation

### ✅ Sandbox Environment (Already Deployed)

**Container Registry with Managed Identity:**

```bicep
// System-assigned managed identity enabled
managedIdentities: {
  systemAssigned: true
}

// Admin user authentication disabled for security
acrAdminUserEnabled: false

// Authentication method: Managed Identity only
authentication: 'Managed Identity (Admin user disabled)'
```

**Key Benefits Already Realized:**

- ✅ No stored credentials or connection strings
- ✅ Automatic Azure AD integration
- ✅ Simplified access management
- ✅ Enhanced security posture

### 📈 Current Outputs Available

Your sandbox already provides managed identity information:

```bicep
output containerRegistrySystemAssignedMIPrincipalId string =
  enableContainerRegistry ? azureContainerRegistry.outputs.systemAssignedMIPrincipalId : ''
```

## 🔍 Sandbox vs Production Comparison

| Aspect                 | Sandbox (Current)     | Production (Planned)       | Improvement                |
| ---------------------- | --------------------- | -------------------------- | -------------------------- |
| **Container Registry** | ✅ System-assigned MI | ✅ System-assigned MI      | Consistent                 |
| **App Services**       | ⚠️ Not deployed yet   | ✅ Required (CKV_AZURE_71) | **Must implement**         |
| **Key Vault**          | ⚠️ Basic access       | ✅ MI-based access         | **Significant upgrade**    |
| **Storage Accounts**   | ⚠️ Key-based access   | ✅ MI-based access         | **Security improvement**   |
| **Virtual Machines**   | ⚠️ Not configured     | ✅ System-assigned MI      | **New requirement**        |
| **Policy Enforcement** | 📋 Audit mode         | 🚫 Deny mode               | **Stricter governance**    |
| **Remediation Tasks**  | ⚠️ Manual             | ✅ Automated MI            | **Operational efficiency** |

## 🛡️ Security Benefits

### Authentication Evolution

**Sandbox (Current State):**

```yaml
Container Registry: ✅ Managed Identity
App Services: ⚠️ Basic authentication
Key Vault: ⚠️ Access keys/connection strings
Storage: ⚠️ Account keys
```

**Production (Target State):**

```yaml
Container Registry: ✅ Managed Identity
App Services: ✅ Managed Identity (Required)
Key Vault: ✅ Managed Identity + RBAC
Storage: ✅ Managed Identity + RBAC
Virtual Machines: ✅ System-assigned MI
```

### Security Policy Enforcement

**Critical Policies (Production):**

- **CKV_AZURE_71**: App Service managed identity (**Always enforced**)
- **Zero Trust Level 1**: System-assigned identities for policy remediation
- **CAF Foundation**: Identity-based resource access

## 🚀 Migration Recommendations

### Phase 1: Immediate Improvements (Sandbox)

**1. Enable App Service Managed Identity**

```bicep
// Add to your App Service configuration
identity: {
  type: 'SystemAssigned'
}
```

**2. Configure Key Vault Access via Managed Identity**

```bicep
// Replace access policies with RBAC
roleAssignments: [
  {
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
  }
]
```

**3. Update Storage Account Access**

```bicep
// Enable managed identity access for storage
roleAssignments: [
  {
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  }
]
```

### Phase 2: Production Readiness

**1. Policy Compliance**

```yaml
# Ensure all services have managed identities
required_managed_identities:
  - App Services: SystemAssigned
  - Function Apps: SystemAssigned
  - Virtual Machines: SystemAssigned
  - Container Instances: SystemAssigned
  - Logic Apps: SystemAssigned
```

**2. RBAC Configuration**

```yaml
# Replace all key-based access with RBAC
rbac_assignments:
  - Key Vault: Key Vault Secrets User/Officer
  - Storage: Storage Blob Data Contributor
  - Container Registry: AcrPull/AcrPush
  - SQL Database: SQL DB Contributor
```

**3. Zero Trust Implementation**

```yaml
# Implement Zero Trust Level 1 policies
zero_trust_level1:
  - MFA Required: Enabled
  - Managed Identity: Required
  - Network Security: Enhanced
  - Audit Logging: Comprehensive
```

## 💻 Implementation Examples

### Current Sandbox Template Enhancement

**Add App Service Managed Identity:**

```bicep
// Enhance your current web app configuration
module webApp 'br/public:avm/res/web/site:0.3.7' = if (enableAppWorkloads) {
  name: 'webAppDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'app-${organizationPrefix}-web-${environment}'
    location: location
    tags: commonTags

    // ✅ ADD: System-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // ✅ ADD: HTTPS only (production ready)
    httpsOnly: true

    // Existing configuration...
    serverFarmResourceId: appServicePlan.outputs.resourceId
    appSettingsKeyValuePairs: {
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
  }
}
```

**Key Vault RBAC Assignment:**

```bicep
// Add after Key Vault deployment
module keyVaultRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.1.0' = if (enableAppWorkloads) {
  name: 'keyVaultWebAppRoleAssignment'
  scope: hubResourceGroup
  params: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

### Production-Ready Configuration

**Complete Managed Identity Setup:**

```bicep
// Production template example
var managedIdentityConfiguration = {
  webApp: {
    systemAssigned: true
    userAssigned: {} // Optional: for cross-subscription access
  }
  functionApp: {
    systemAssigned: true
  }
  virtualMachine: {
    systemAssigned: true
  }
  containerInstance: {
    systemAssigned: true
  }
}

// RBAC assignments for all services
var rbacAssignments = [
  {
    service: 'webApp'
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    scope: 'keyVault'
  }
  {
    service: 'webApp'
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    scope: 'storageAccount'
  }
  {
    service: 'webApp'
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    scope: 'containerRegistry'
  }
]
```

## 📊 Cost Impact

### Managed Identity vs Key-Based Authentication

| Approach             | Security  | Operational Overhead | Cost  | Production Readiness |
| -------------------- | --------- | -------------------- | ----- | -------------------- |
| **Key-Based**        | ⚠️ Medium | 🔴 High (rotation)   | 💚 $0 | ❌ Not recommended   |
| **Managed Identity** | ✅ High   | 💚 Low (automatic)   | 💚 $0 | ✅ Production ready  |

**Key Benefits:**

- ✅ **Zero additional cost** - Managed identities are free
- ✅ **Reduced operational overhead** - No key rotation needed
- ✅ **Enhanced security** - No stored credentials
- ✅ **Compliance ready** - Meets security policies

## 🔧 Next Steps

### Immediate Actions (Sandbox Enhancement)

1. **Update App Service configuration** to include managed identity
2. **Configure Key Vault RBAC** assignments for web app access
3. **Update Storage Account** permissions for managed identity access
4. **Test the enhanced configuration** to ensure functionality

### Production Preparation

1. **Review Zero Trust Level 1 policies** in `environments/production/policies/zero-trust-level1.bicep`
2. **Implement mandatory managed identities** for all Azure services
3. **Configure comprehensive RBAC assignments** replacing key-based access
4. **Set up policy remediation** with system-assigned managed identities

### Validation Commands

```bash
# Test managed identity authentication
az webapp identity show --name app-alz-web-sandbox --resource-group rg-alz-spoke-sandbox

# Verify RBAC assignments
az role assignment list --assignee <managed-identity-principal-id> --output table

# Check policy compliance
az policy state list --management-group-name <mg-name> --filter "complianceState eq 'NonCompliant'"
```

## 📚 References

- **Current Implementation**: `blueprints/bicep/hub-spoke/main.bicep` (Container Registry MI)
- **Production Policies**: `environments/production/policies/zero-trust-level1.bicep`
- **Security Policies**: `docs/azure-sandbox-policies-overview.md` (CKV_AZURE_71)
- **Microsoft Documentation**: [Managed Identity Overview](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)

---

**Status:** ✅ **Managed identities partially implemented** - Container Registry complete, App Services and other services ready for enhancement
