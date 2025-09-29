metadata name = 'ALZ Subscription Vending'
metadata description = 'ALZ-compliant subscription vending using official AVM sub-vending pattern'

targetScope = 'managementGroup'

// =======================
// PARAMETERS - ALZ Subscription Vending Standard
// =======================

@description('The management group ID to which the subscription will be associated')
param managementGroupId string = ''

@description('The subscription alias name')
@maxLength(63)
param subscriptionAliasName string

@description('The display name of the subscription')
@maxLength(63)
param subscriptionDisplayName string

@description('The billing scope for the subscription')
param subscriptionBillingScope string

@description('The workload type for the subscription')
@allowed(['Production', 'DevTest'])
param subscriptionWorkload string = 'Production'

@description('Environment for the landing zone')
@allowed(['prod', 'test', 'dev', 'sandbox'])
param environment string = 'prod'

@description('Organization prefix for naming')
param organizationPrefix string = 'alz'

@description('Enable virtual network creation')
param enableVirtualNetwork bool = true

@description('Virtual network address space')
param virtualNetworkAddressSpace array = ['10.0.0.0/16']

@description('Azure region for the virtual network')
param virtualNetworkLocation string

@description('Enable hub and spoke network peering')
param enableHubSpokeNetworking bool = true

@description('Hub virtual network resource ID for peering')
param hubVirtualNetworkResourceId string = ''

@description('Enable Azure Bastion in the landing zone')
param enableBastion bool = false

// =======================
// VARIABLES - ALZ Naming Standards
// =======================

var commonTags = {
  Environment: environment
  Project: 'Azure-Landing-Zone'
  Pattern: 'ALZ-Subscription-Vending'
  IaC: 'Bicep-AVM'
  DeployedBy: 'ALZ-IaC-Accelerator'
  Compliance: 'ALZ-Foundation'
  LandingZoneType: 'Spoke'
}

// ALZ standard naming
var namingPrefix = '${organizationPrefix}-${environment}'

// Base subnets for ALZ pattern
var baseSubnets = [
  {
    name: 'snet-workloads'
    addressPrefix: cidrSubnet(virtualNetworkAddressSpace[0], 24, 0) // First /24 subnet
    networkSecurityGroup: {
      name: 'nsg-${namingPrefix}-workloads'
      location: virtualNetworkLocation
      securityRules: [
        {
          name: 'AllowVnetInBound'
          properties: {
            description: 'Allow VNet traffic inbound'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 200
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowAzureLoadBalancerInBound'
          properties: {
            description: 'Allow Azure Load Balancer inbound'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'AzureLoadBalancer'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 210
            direction: 'Inbound'
          }
        }
        {
          name: 'DenyAllInBound'
          properties: {
            description: 'Deny all other inbound traffic'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Deny'
            priority: 4096
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowVnetOutBound'
          properties: {
            description: 'Allow VNet traffic outbound'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 200
            direction: 'Outbound'
          }
        }
        {
          name: 'AllowInternetOutBound'
          properties: {
            description: 'Allow Internet outbound'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: 'Internet'
            access: 'Allow'
            priority: 210
            direction: 'Outbound'
          }
        }
      ]
    }
  }
  {
    name: 'snet-private-endpoints'
    addressPrefix: cidrSubnet(virtualNetworkAddressSpace[0], 24, 1) // Second /24 subnet
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    networkSecurityGroup: {
      name: 'nsg-${namingPrefix}-private-endpoints'
      location: virtualNetworkLocation
      securityRules: [
        {
          name: 'AllowVnetInBound'
          properties: {
            description: 'Allow VNet traffic for private endpoints'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 200
            direction: 'Inbound'
          }
        }
      ]
    }
  }
]

// Add Bastion subnet if enabled
var bastionSubnet = [
  {
    name: 'AzureBastionSubnet' // Required name
    addressPrefix: cidrSubnet(virtualNetworkAddressSpace[0], 26, 8) // /26 subnet for Bastion
  }
]

// Combine subnets based on Bastion configuration
var finalSubnets = enableBastion ? concat(baseSubnets, bastionSubnet) : baseSubnets

// =======================
// ALZ SUBSCRIPTION VENDING PATTERN
// =======================

// Official AVM Subscription Vending Pattern
module subscriptionVending 'br/public:avm/ptn/lz/sub-vending:0.4.0' = {
  name: 'alzSubscriptionVendingDeployment'
  params: {
    // Subscription configuration
    subscriptionAliasEnabled: true
    subscriptionAliasName: subscriptionAliasName
    subscriptionDisplayName: subscriptionDisplayName
    subscriptionBillingScope: subscriptionBillingScope
    subscriptionWorkload: subscriptionWorkload

    // Management group association
    subscriptionManagementGroupAssociationEnabled: !empty(managementGroupId)
    subscriptionManagementGroupId: managementGroupId

    // Subscription tags following ALZ standards
    subscriptionTags: commonTags

    // Virtual network configuration
    virtualNetworkEnabled: enableVirtualNetwork
    virtualNetworkName: 'vnet-${namingPrefix}-spoke'
    virtualNetworkLocation: virtualNetworkLocation
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    virtualNetworkResourceGroupName: 'rg-${namingPrefix}-networking'
    virtualNetworkResourceGroupLockEnabled: true
    virtualNetworkSubnets: finalSubnets

    // Azure Bastion configuration (optional)
    virtualNetworkDeployBastion: enableBastion
    virtualNetworkBastionConfiguration: enableBastion ? {
      name: 'bas-${namingPrefix}'
      bastionSku: 'Standard'
      enableFileCopy: true
      enableIpConnect: true
      enableShareableLink: false
      scaleUnits: 2
    } : {}

    // Hub-Spoke peering configuration
    virtualNetworkPeeringEnabled: enableHubSpokeNetworking && !empty(hubVirtualNetworkResourceId)
    virtualNetworkUseRemoteGateways: false // Set to true if hub has gateways

    // Resource providers to register
    resourceProviders: {
      'Microsoft.Network': {
        resourceProviderFeatures: {}
      }
      'Microsoft.Storage': {
        resourceProviderFeatures: {}
      }
      'Microsoft.KeyVault': {
        resourceProviderFeatures: {}
      }
      'Microsoft.Web': {
        resourceProviderFeatures: {}
      }
      'Microsoft.Insights': {
        resourceProviderFeatures: {}
      }
      'Microsoft.OperationalInsights': {
        resourceProviderFeatures: {}
      }
    }

    // Role assignments for ALZ compliance (replace with actual principal IDs)
    roleAssignmentEnabled: false // Set to true when you have actual principal IDs
    roleAssignments: []
    /*
    roleAssignments: [
      {
        principalId: '00000000-0000-0000-0000-000000000000' // Replace with actual principal ID
        definition: 'Owner'
        relativeScope: ''
      }
      {
        principalId: '00000000-0000-0000-0000-000000000000' // Replace with actual principal ID
        definition: 'Network Contributor'
        relativeScope: '/resourceGroups/rg-${namingPrefix}-networking'
      }
    ]
    */
  }
}

// =======================
// OUTPUTS - ALZ Standard (limited by sub-vending module capabilities)
// =======================

// Available outputs from AVM sub-vending module
@description('The Subscription ID that has been created or used.')
output subscriptionId string = subscriptionVending.outputs.subscriptionId

@description('The Subscription Resource ID that has been created or used.')
output subscriptionResourceId string = subscriptionVending.outputs.subscriptionResourceId

@description('Virtual WAN Hub Connection Name (if applicable).')
output virtualWanHubConnectionName string = subscriptionVending.outputs.virtualWanHubConnectionName

@description('Failed Resource Providers (if any).')
output failedResourceProviders string = subscriptionVending.outputs.failedResourceProviders

@description('Failed Resource Provider Features (if any).')
output failedResourceProvidersFeatures string = subscriptionVending.outputs.failedResourceProvidersFeatures

// Derived outputs based on configuration (since sub-vending module doesn't expose all outputs)
@description('Virtual Network Name (derived from parameters).')
output virtualNetworkName string = enableVirtualNetwork ? 'vnet-${namingPrefix}-spoke' : ''

@description('Virtual Network Resource Group Name.')
output networkingResourceGroupName string = enableVirtualNetwork ? 'rg-${namingPrefix}-networking' : ''

@description('Virtual Network Address Space.')
output virtualNetworkAddressSpace array = enableVirtualNetwork ? virtualNetworkAddressSpace : []

@description('Bastion Configuration Status.')
output bastionEnabled bool = enableBastion

@description('Hub-Spoke Peering Status.')
output hubSpokePeeringEnabled bool = enableHubSpokeNetworking && !empty(hubVirtualNetworkResourceId)

// ALZ compliance metadata
@description('ALZ compliance and deployment metadata.')
output alzCompliance object = {
  pattern: 'ALZ Subscription Vending'
  framework: 'Azure Landing Zone'
  iacApproach: 'AVM Pattern Module'
  avmModuleVersion: '0.4.0'
  landingZoneType: 'Application-Landing-Zone'
  networkingPattern: enableHubSpokeNetworking ? 'Hub-Spoke' : 'Standalone'
  complianceFramework: 'ALZ-Foundation'
  subscriptionVendingEnabled: true
  governanceEnabled: true
  deploymentTimestamp: 'Runtime-Generated'
}

// Connection information for easy reference
@description('Connection information for deployed resources.')
output connectionInfo object = {
  subscriptionId: subscriptionVending.outputs.subscriptionId
  deployment: {
    organizationPrefix: organizationPrefix
    environment: environment
    location: virtualNetworkLocation
  }
  resourceGroups: {
    networking: enableVirtualNetwork ? 'rg-${namingPrefix}-networking' : null
  }
  networking: enableVirtualNetwork ? {
    virtualNetwork: {
      name: 'vnet-${namingPrefix}-spoke'
      addressSpace: virtualNetworkAddressSpace
    }
    subnets: {
      workloads: 'snet-workloads (${cidrSubnet(virtualNetworkAddressSpace[0], 24, 0)})'
      privateEndpoints: 'snet-private-endpoints (${cidrSubnet(virtualNetworkAddressSpace[0], 24, 1)})'
      bastion: enableBastion ? 'AzureBastionSubnet (${cidrSubnet(virtualNetworkAddressSpace[0], 26, 8)})' : null
    }
    peering: {
      hubSpokeEnabled: enableHubSpokeNetworking && !empty(hubVirtualNetworkResourceId)
      hubResourceId: hubVirtualNetworkResourceId != '' ? hubVirtualNetworkResourceId : null
    }
  } : null
  security: {
    bastionDeployed: enableBastion
    networkSecurityGroups: 2 // workloads + private-endpoints
  }
  tags: commonTags
}
