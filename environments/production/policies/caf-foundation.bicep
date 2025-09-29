metadata name = 'CAF Foundation Policies'
metadata description = 'Cloud Adoption Framework foundation policies for governance and compliance'

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

@description('Enable policy remediation')
param enableRemediation bool = false

// =======================
// VARIABLES
// =======================

var cafPolicies = {
  // Naming and Tagging
  resourceNaming: {
    displayName: 'CAF - Resource Naming Standards'
    description: 'Enforce resource naming conventions aligned with CAF'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/56a5ee18-2ae6-4810-86f7-18e39ce5629b'
    parameters: {
      tagName: {
        value: 'Environment'
      }
      tagValue: {
        value: '[parameters(\'tagValue\')]'
      }
    }
  }

  requiredTags: {
    displayName: 'CAF - Required Tags'
    description: 'Require specific tags on resources for governance'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62'
    parameters: {
      tagName: {
        value: 'CostCenter'
      }
    }
  }

  // Cost Management
  budgetAlert: {
    displayName: 'CAF - Budget Alerts'
    description: 'Ensure subscriptions have budget alerts configured'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/5b9159ae-1701-4a6f-9a7a-aa9c8ddd0580'
    parameters: {}
  }

  // Resource Management
  allowedLocations: {
    displayName: 'CAF - Allowed Locations'
    description: 'Restrict resource deployment to approved Azure regions'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
    parameters: {
      listOfAllowedLocations: {
        value: [
          'westeurope'
          'northeurope'
          'uksouth'
          'ukwest'
        ]
      }
    }
  }

  allowedResourceTypes: {
    displayName: 'CAF - Allowed Resource Types'
    description: 'Restrict deployment to approved resource types'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c'
    parameters: {
      listOfAllowedResourceTypes: {
        value: [
          'Microsoft.KeyVault/vaults'
          'Microsoft.Network/virtualNetworks'
          'Microsoft.Network/networkSecurityGroups'
          'Microsoft.Network/privateEndpoints'
          'Microsoft.Storage/storageAccounts'
          'Microsoft.Compute/virtualMachines'
          'Microsoft.Web/sites'
          'Microsoft.Sql/servers'
          'Microsoft.Sql/servers/databases'
          'Microsoft.OperationalInsights/workspaces'
          'Microsoft.Insights/components'
        ]
      }
    }
  }

  // Security and Compliance
  storageAccountEncryption: {
    displayName: 'CAF - Storage Encryption'
    description: 'Storage accounts should use customer-managed keys for encryption'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/6fac406b-40ca-413b-bf8e-0bf964659c25'
    parameters: {}
  }

  sqlAuditing: {
    displayName: 'CAF - SQL Server Auditing'
    description: 'SQL Server auditing should be enabled'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a6fb4358-5bf4-4ad7-ba82-2cd2f41ce5e9'
    parameters: {}
  }

  // Monitoring and Logging
  diagnosticSettings: {
    displayName: 'CAF - Diagnostic Settings'
    description: 'Deploy diagnostic settings for Azure services'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9'
    parameters: {
      logAnalyticsWorkspaceId: {
        value: '/subscriptions/placeholder/resourceGroups/rg-platform-management-prod/providers/Microsoft.OperationalInsights/workspaces/log-platform-prod'
      }
    }
  }
}

// =======================
// CAF FOUNDATION INITIATIVE
// =======================

resource cafFoundationInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: 'caf-foundation-initiative'
  properties: {
    displayName: 'Cloud Adoption Framework - Foundation'
    description: 'Comprehensive policy set implementing CAF governance principles'
    metadata: {
      category: 'Cloud Adoption Framework'
      version: '1.0.0'
      framework: 'Microsoft CAF'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Policy Effect'
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
      allowedLocations: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed Locations'
          description: 'List of allowed Azure regions for resource deployment'
        }
        defaultValue: [
          'westeurope'
          'northeurope'
          'uksouth'
          'ukwest'
        ]
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: cafPolicies.requiredTags.policyDefinitionId
        parameters: {}
        groupNames: ['Governance']
      }
      {
        policyDefinitionId: cafPolicies.allowedLocations.policyDefinitionId
        parameters: {
          listOfAllowedLocations: {
            value: '[parameters(\'allowedLocations\')]'
          }
        }
        groupNames: ['Governance']
      }
      {
        policyDefinitionId: cafPolicies.allowedResourceTypes.policyDefinitionId
        parameters: {}
        groupNames: ['Governance']
      }
      {
        policyDefinitionId: cafPolicies.storageAccountEncryption.policyDefinitionId
        parameters: {}
        groupNames: ['Security']
      }
      {
        policyDefinitionId: cafPolicies.sqlAuditing.policyDefinitionId
        parameters: {}
        groupNames: ['Security']
      }
      {
        policyDefinitionId: cafPolicies.diagnosticSettings.policyDefinitionId
        parameters: {}
        groupNames: ['Monitoring']
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'Governance'
        displayName: 'Governance and Compliance'
        description: 'Policies ensuring proper governance and regulatory compliance'
      }
      {
        name: 'Security'
        displayName: 'Security Controls'
        description: 'Policies ensuring security best practices are followed'
      }
      {
        name: 'Monitoring'
        displayName: 'Monitoring and Logging'
        description: 'Policies ensuring comprehensive monitoring and audit trails'
      }
    ]
  }
}

// =======================
// POLICY ASSIGNMENTS
// =======================

// Assign CAF Foundation Initiative to Root
resource cafFoundationAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'caf-foundation-assignment'
  properties: {
    displayName: 'CAF Foundation Initiative Assignment'
    description: 'Assignment of CAF foundation policies for governance and compliance'
    policyDefinitionId: cafFoundationInitiative.id
    parameters: {
      effect: {
        value: 'Audit'
      }
      allowedLocations: {
        value: [
          'westeurope'
          'northeurope'
          'uksouth'
          'ukwest'
        ]
      }
    }
    enforcementMode: 'Default'
    metadata: {
      assignedBy: 'Azure Landing Zone Deployment'
      framework: 'Cloud Adoption Framework'
      version: '1.0.0'
    }
  }
  identity: enableRemediation ? {
    type: 'SystemAssigned'
  } : null
}

// Platform-specific assignments
resource platformTaggingPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'caf-platform-tagging'
  scope: '/providers/Microsoft.Management/managementGroups/${platformManagementGroupId}'
  properties: {
    displayName: 'CAF - Platform Resource Tagging'
    description: 'Enforce platform-specific tagging requirements'
    policyDefinitionId: cafPolicies.requiredTags.policyDefinitionId
    parameters: {
      tagName: {
        value: 'Platform-Service'
      }
    }
    enforcementMode: 'Default'
    metadata: {
      category: 'CAF Governance'
      scope: 'Platform'
    }
  }
}

// Landing Zones specific assignments
resource landingZoneTaggingPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'caf-lz-tagging'
  scope: '/providers/Microsoft.Management/managementGroups/${landingZonesManagementGroupId}'
  properties: {
    displayName: 'CAF - Landing Zone Resource Tagging'
    description: 'Enforce workload-specific tagging requirements'
    policyDefinitionId: cafPolicies.requiredTags.policyDefinitionId
    parameters: {
      tagName: {
        value: 'Workload-Owner'
      }
    }
    enforcementMode: 'Default'
    metadata: {
      category: 'CAF Governance'
      scope: 'Landing Zones'
    }
  }
}

// =======================
// OUTPUTS
// =======================

output policyInitiatives object = {
  cafFoundation: {
    id: cafFoundationInitiative.id
    name: cafFoundationInitiative.name
    assignmentId: cafFoundationAssignment.id
  }
}

output policyAssignments object = {
  foundationAssignment: cafFoundationAssignment.id
  platformTagging: platformTaggingPolicy.id
  landingZoneTagging: landingZoneTaggingPolicy.id
}

output cafCompliance object = {
  framework: 'Microsoft Cloud Adoption Framework'
  version: '1.0.0'
  pillars: [
    'Strategy'
    'Plan'
    'Ready'
    'Adopt'
    'Govern'
    'Manage'
  ]
  governancePolicies: length(items(cafPolicies))
  complianceFrameworks: [
    'ISO 27001'
    'SOC 2'
    'NIST Cybersecurity Framework'
    'CIS Controls'
  ]
}
