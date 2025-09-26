metadata name = 'Zero Trust Security Policies - Level 1'
metadata description = 'Basic Zero Trust security policies for first maturity level with minimal impact on operations'

targetScope = 'managementGroup'

// =======================
// PARAMETERS
// =======================

@description('Root Management Group ID')
param rootManagementGroupId string

@description('Platform Management Group ID')
param platformManagementGroupId string

@description('Landing Zones Management Group ID')
param landingZonesManagementGroupId string

@description('Production Management Group ID')
param productionManagementGroupId string

@description('Non-Production Management Group ID')
param nonProductionManagementGroupId string

@description('Sandbox Management Group ID')
param sandboxManagementGroupId string

@description('Enable policy remediation tasks')
param enableRemediation bool = false

// =======================
// VARIABLES
// =======================

var zeroTrustPolicies = {
  // Identity and Access Management (Basic)
  multifactorAuthentication: {
    displayName: 'Zero Trust - MFA Required'
    description: 'Requires multi-factor authentication for administrative accounts'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/9297c21d-2ed6-4474-b48f-163f75654ce3'
    parameters: {}
  }
  
  // Network Security (Basic)
  networkSecurityGroups: {
    displayName: 'Zero Trust - NSG Flow Logs'
    description: 'Network Security Groups should have flow logs enabled'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/c251913d-7d24-4958-af87-478ed3b9ba41'
    parameters: {}
  }
  
  // Data Protection (Basic)
  storageAccountsHttps: {
    displayName: 'Zero Trust - Storage HTTPS Only'
    description: 'Storage accounts should only accept HTTPS traffic'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
    parameters: {}
  }
  
  sqlServerTlsVersion: {
    displayName: 'Zero Trust - SQL TLS 1.2'
    description: 'SQL servers should use minimum TLS version 1.2'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/32e6bbec-16b6-44c2-be37-c5b672d103cf'
    parameters: {
      minimalTlsVersion: {
        value: '1.2'
      }
    }
  }
  
  // Device Trust (Basic)
  vmExtensionsApproved: {
    displayName: 'Zero Trust - Approved VM Extensions'
    description: 'Only approved VM extensions should be installed'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/c0e996f8-39cf-4af9-9f45-83fbde810432'
    parameters: {
      approvedExtensions: {
        value: [
          'MicrosoftMonitoringAgent'
          'AzureNetworkWatcherExtension'
          'AzureDiskEncryption'
          'KeyVaultForLinux'
          'KeyVaultForWindows'
        ]
      }
    }
  }
  
  // Application Security (Basic)
  keyVaultFirewall: {
    displayName: 'Zero Trust - Key Vault Firewall'
    description: 'Key Vault should have firewall enabled'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/55615ac9-af46-4a59-874e-391cc3dfb490'
    parameters: {}
  }
  
  appServiceHttps: {
    displayName: 'Zero Trust - App Service HTTPS Only'
    description: 'App Service should only be accessible over HTTPS'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a4af4a39-4135-47fb-b175-47fbdf85311d'
    parameters: {}
  }
  
  // Visibility and Analytics (Basic)
  logAnalyticsDeployment: {
    displayName: 'Zero Trust - Log Analytics Required'
    description: 'Deploy Log Analytics workspace for centralized logging'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/8e3e61b3-0b32-22d5-4edf-55f87fdb5955'
    parameters: {
      logAnalyticsWorkspaceId: {
        value: '/subscriptions/placeholder/resourceGroups/rg-platform-management-prod/providers/Microsoft.OperationalInsights/workspaces/log-platform-prod'
      }
    }
  }
  
  activityLogRetention: {
    displayName: 'Zero Trust - Activity Log Retention'
    description: 'Activity logs should be retained for at least 90 days'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/b02aacc0-b073-424e-8298-42b22829ee0a'
    parameters: {
      requiredRetentionDays: {
        value: '90'
      }
    }
  }
}

// =======================
// POLICY ASSIGNMENTS
// =======================

// Root Level Policies (Apply to all subscriptions)
resource rootLevelPolicies 'Microsoft.Authorization/policyAssignments@2022-06-01' = [for (policy, index) in items(zeroTrustPolicies): {
  name: 'zt-l1-root-${index}'
  properties: {
    displayName: policy.value.displayName
    description: policy.value.description
    policyDefinitionId: policy.value.policyDefinitionId
    parameters: policy.value.parameters
    enforcementMode: 'Default'
    metadata: {
      category: 'Zero Trust Level 1'
      version: '1.0.0'
      maturityLevel: 'Basic'
    }
  }
  identity: enableRemediation ? {
    type: 'SystemAssigned'
  } : null
}]

// Production-Specific Policies (Stricter controls)
resource productionMfaPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'zt-l1-prod-mfa-strict'
  scope: '/providers/Microsoft.Management/managementGroups/${productionManagementGroupId}'
  properties: {
    displayName: 'Zero Trust - Production MFA Enforcement'
    description: 'Strict MFA enforcement for production environments'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/9297c21d-2ed6-4474-b48f-163f75654ce3'
    parameters: {}
    enforcementMode: 'Default'
    metadata: {
      category: 'Zero Trust Level 1'
      environment: 'Production'
      strictness: 'High'
    }
  }
}

// Sandbox Relaxed Policies
resource sandboxRelaxedPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'zt-l1-sandbox-relaxed'
  scope: '/providers/Microsoft.Management/managementGroups/${sandboxManagementGroupId}'
  properties: {
    displayName: 'Zero Trust - Sandbox Learning Mode'
    description: 'Relaxed policies for sandbox environments with audit-only mode'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
    parameters: {}
    enforcementMode: 'DoNotEnforce' // Audit only for sandbox
    metadata: {
      category: 'Zero Trust Level 1'
      environment: 'Sandbox'
      mode: 'Learning'
    }
  }
}

// =======================
// POLICY INITIATIVES
// =======================

// Zero Trust Level 1 Initiative
resource zeroTrustLevel1Initiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: 'zero-trust-level1-initiative'
  properties: {
    displayName: 'Zero Trust Security Framework - Level 1'
    description: 'Comprehensive policy set implementing Zero Trust principles at basic maturity level'
    metadata: {
      category: 'Zero Trust'
      version: '1.0.0'
      maturityLevel: 'Level 1 - Basic'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'AuditIfNotExists'
          'DeployIfNotExists'
        ]
        defaultValue: 'Audit'
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: zeroTrustPolicies.multifactorAuthentication.policyDefinitionId
        parameters: {}
        groupNames: ['Identity']
      }
      {
        policyDefinitionId: zeroTrustPolicies.networkSecurityGroups.policyDefinitionId
        parameters: {}
        groupNames: ['Network']
      }
      {
        policyDefinitionId: zeroTrustPolicies.storageAccountsHttps.policyDefinitionId
        parameters: {}
        groupNames: ['Data']
      }
      {
        policyDefinitionId: zeroTrustPolicies.keyVaultFirewall.policyDefinitionId
        parameters: {}
        groupNames: ['Applications']
      }
      {
        policyDefinitionId: zeroTrustPolicies.activityLogRetention.policyDefinitionId
        parameters: {}
        groupNames: ['Visibility']
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'Identity'
        displayName: 'Identity Verification'
        description: 'Policies ensuring proper identity verification and access controls'
      }
      {
        name: 'Network'
        displayName: 'Network Security'
        description: 'Policies ensuring secure network configurations'
      }
      {
        name: 'Data'
        displayName: 'Data Protection'
        description: 'Policies ensuring data is protected in transit and at rest'
      }
      {
        name: 'Applications'
        displayName: 'Application Security'
        description: 'Policies ensuring secure application configurations'
      }
      {
        name: 'Visibility'
        displayName: 'Visibility and Analytics'
        description: 'Policies ensuring comprehensive monitoring and logging'
      }
    ]
  }
}

// Assign the Initiative to the Root Management Group
resource initiativeAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'zero-trust-l1-initiative-assignment'
  properties: {
    displayName: 'Zero Trust Level 1 Initiative Assignment'
    description: 'Assignment of Zero Trust Level 1 policies across the organization'
    policyDefinitionId: zeroTrustLevel1Initiative.id
    parameters: {
      effect: {
        value: 'Audit' // Start with Audit mode for Level 1
      }
    }
    enforcementMode: 'Default'
    metadata: {
      assignedBy: 'Azure Landing Zone Deployment'
      assignedDate: '2024-09-26'
      version: '1.0.0'
    }
  }
}

// =======================
// OUTPUTS
// =======================

output policyAssignments object = {
  rootLevelPolicies: length(rootLevelPolicies)
  productionPolicies: 1
  sandboxPolicies: 1
  initiatives: 1
}

output zeroTrustMaturity object = {
  level: 1
  description: 'Basic Zero Trust implementation'
  policiesIncluded: length(items(zeroTrustPolicies))
  nextLevel: 'Level 2 - Advanced'
  nextLevelFeatures: [
    'Conditional Access policies'
    'Advanced threat protection'
    'Just-in-time access'
    'Enhanced monitoring and alerting'
  ]
}

output complianceFrameworks array = [
  'NIST Cybersecurity Framework'
  'ISO 27001'
  'CIS Controls'
  'Azure Security Benchmark'
]