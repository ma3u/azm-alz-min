metadata name = 'Azure Landing Zone - Management Groups'
metadata description = 'CAF-compliant Management Group hierarchy with Zero Trust security framework (Level 1 maturity)'

targetScope = 'managementGroup'

// =======================
// PARAMETERS
// =======================

@description('The root Management Group ID where the hierarchy will be created')
param rootManagementGroupId string

@description('The organization name prefix for Management Groups')
param organizationPrefix string = 'alz'

@description('Enable deployment of policy assignments')
param deployPolicyAssignments bool = true

@description('Enable deployment of security policies')
param deploySecurityPolicies bool = true

// =======================
// VARIABLES
// =======================

// CAF-aligned Management Group structure
var managementGroupStructure = {
  root: {
    id: '${organizationPrefix}-root'
    displayName: '${organizationPrefix} Root'
    description: 'Root Management Group for ${organizationPrefix} organization'
  }
  platform: {
    id: '${organizationPrefix}-platform'
    displayName: '${organizationPrefix} Platform'
    description: 'Platform Management Group for shared services and governance'
  }
  landingZones: {
    id: '${organizationPrefix}-landingzones'
    displayName: '${organizationPrefix} Landing Zones'
    description: 'Landing Zones Management Group for workload subscriptions'
  }
  sandbox: {
    id: '${organizationPrefix}-sandbox'
    displayName: '${organizationPrefix} Sandbox'
    description: 'Sandbox Management Group for experimentation and testing'
  }
  // Platform sub-groups
  connectivity: {
    id: '${organizationPrefix}-platform-connectivity'
    displayName: '${organizationPrefix} Platform Connectivity'
    description: 'Connectivity services (Hub networks, DNS, etc.)'
    parent: '${organizationPrefix}-platform'
  }
  identity: {
    id: '${organizationPrefix}-platform-identity'
    displayName: '${organizationPrefix} Platform Identity'
    description: 'Identity and access management services'
    parent: '${organizationPrefix}-platform'
  }
  management: {
    id: '${organizationPrefix}-platform-management'
    displayName: '${organizationPrefix} Platform Management'
    description: 'Management and monitoring services'
    parent: '${organizationPrefix}-platform'
  }
  security: {
    id: '${organizationPrefix}-platform-security'
    displayName: '${organizationPrefix} Platform Security'
    description: 'Security services and governance'
    parent: '${organizationPrefix}-platform'
  }
  // Landing Zone sub-groups
  production: {
    id: '${organizationPrefix}-lz-production'
    displayName: '${organizationPrefix} Production'
    description: 'Production workload subscriptions'
    parent: '${organizationPrefix}-landingzones'
  }
  nonProduction: {
    id: '${organizationPrefix}-lz-nonproduction'
    displayName: '${organizationPrefix} Non-Production'
    description: 'Non-production workload subscriptions (dev, test, staging)'
    parent: '${organizationPrefix}-landingzones'
  }
}

// =======================
// MANAGEMENT GROUPS
// =======================

// Root Management Group
resource rootMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.root.id
  properties: {
    displayName: managementGroupStructure.root.displayName
    details: {
      parent: {
        id: '/providers/Microsoft.Management/managementGroups/${rootManagementGroupId}'
      }
    }
  }
}

// Platform Management Group
resource platformMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.platform.id
  properties: {
    displayName: managementGroupStructure.platform.displayName
    details: {
      parent: {
        id: rootMg.id
      }
    }
  }
}

// Landing Zones Management Group
resource landingZonesMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.landingZones.id
  properties: {
    displayName: managementGroupStructure.landingZones.displayName
    details: {
      parent: {
        id: rootMg.id
      }
    }
  }
}

// Sandbox Management Group
resource sandboxMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.sandbox.id
  properties: {
    displayName: managementGroupStructure.sandbox.displayName
    details: {
      parent: {
        id: rootMg.id
      }
    }
  }
}

// Platform Sub-Management Groups
resource connectivityMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.connectivity.id
  properties: {
    displayName: managementGroupStructure.connectivity.displayName
    details: {
      parent: {
        id: platformMg.id
      }
    }
  }
}

resource identityMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.identity.id
  properties: {
    displayName: managementGroupStructure.identity.displayName
    details: {
      parent: {
        id: platformMg.id
      }
    }
  }
}

resource managementMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.management.id
  properties: {
    displayName: managementGroupStructure.management.displayName
    details: {
      parent: {
        id: platformMg.id
      }
    }
  }
}

resource securityMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.security.id
  properties: {
    displayName: managementGroupStructure.security.displayName
    details: {
      parent: {
        id: platformMg.id
      }
    }
  }
}

// Landing Zone Sub-Management Groups
resource productionMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.production.id
  properties: {
    displayName: managementGroupStructure.production.displayName
    details: {
      parent: {
        id: landingZonesMg.id
      }
    }
  }
}

resource nonProductionMg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupStructure.nonProduction.id
  properties: {
    displayName: managementGroupStructure.nonProduction.displayName
    details: {
      parent: {
        id: landingZonesMg.id
      }
    }
  }
}

// =======================
// POLICY ASSIGNMENTS
// =======================

// Zero Trust Level 1 - Basic Security Policies
module zeroTrustPoliciesLevel1 'policies/zero-trust-level1.bicep' = if (deployPolicyAssignments && deploySecurityPolicies) {
  name: 'zeroTrustLevel1Policies'
  params: {
    rootManagementGroupId: rootMg.name
    platformManagementGroupId: platformMg.name
    landingZonesManagementGroupId: landingZonesMg.name
    productionManagementGroupId: productionMg.name
    nonProductionManagementGroupId: nonProductionMg.name
    sandboxManagementGroupId: sandboxMg.name
  }
}

// CAF Foundation Policies
module cafFoundationPolicies 'policies/caf-foundation.bicep' = if (deployPolicyAssignments) {
  name: 'cafFoundationPolicies'
  params: {
    rootManagementGroupId: rootMg.name
    platformManagementGroupId: platformMg.name
    landingZonesManagementGroupId: landingZonesMg.name
  }
  dependsOn: [
    zeroTrustPoliciesLevel1
  ]
}

// =======================
// OUTPUTS
// =======================

output managementGroupIds object = {
  root: rootMg.name
  platform: platformMg.name
  landingZones: landingZonesMg.name
  sandbox: sandboxMg.name
  connectivity: connectivityMg.name
  identity: identityMg.name
  management: managementMg.name
  security: securityMg.name
  production: productionMg.name
  nonProduction: nonProductionMg.name
}

output managementGroupStructure object = managementGroupStructure

output zeroTrustMaturity string = 'Level 1 - Basic'

output deploymentSummary object = {
  managementGroupsCreated: 10
  policiesDeployed: deployPolicyAssignments
  securityPoliciesDeployed: deploySecurityPolicies
  zeroTrustLevel: 1
  cafCompliant: true
}