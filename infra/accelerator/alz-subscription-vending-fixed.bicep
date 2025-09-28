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

    // ALZ standard subnets
    virtualNetworkSubnets: [
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

    // Hub and spoke networking configuration
    virtualNetworkPeerings: enableHubSpokeNetworking && !empty(hubVirtualNetworkResourceId) ? [
      {
        remoteVirtualNetworkResourceId: hubVirtualNetworkResourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        allowGatewayTransit: false
        useRemoteGateways: true
        reciprocalPeering: true
      }
    ] : []

    // Azure Bastion configuration (optional)
    virtualNetworkSubnets: enableBastion ? concat(virtualNetworkSubnets, [
      {
        name: 'AzureBastionSubnet' // Required name
        addressPrefix: cidrSubnet(virtualNetworkAddressSpace[0], 24, 2) // Third /24 subnet
      }
    ]) : virtualNetworkSubnets

    deployBastion: enableBastion
    bastionConfiguration: enableBastion ? {
      name: 'bas-${namingPrefix}'
      location: virtualNetworkLocation
      skuName: 'Standard'
      publicIpName: 'pip-${namingPrefix}-bastion'
    } : {}

    // Resource providers to register
    resourceProviders: {
      'Microsoft.Network': ['*']
      'Microsoft.Storage': ['*']
      'Microsoft.KeyVault': ['*']
      'Microsoft.Web': ['*']
      'Microsoft.Insights': ['*']
      'Microsoft.OperationalInsights': ['*']
    }

    // Role assignments for ALZ compliance
    roleAssignmentEnabled: true
    roleAssignments: [
      {
        principalId: '00000000-0000-0000-0000-000000000000' // Replace with actual principal ID
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner role
        description: 'ALZ Platform Team Owner access'
      }
      {
        principalId: '00000000-0000-0000-0000-000000000000' // Replace with actual principal ID
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor role
        description: 'ALZ Network Team Contributor access'
      }
    ]
  }
}

// =======================
// OUTPUTS - ALZ Standard
// =======================

// Subscription information
output subscriptionId string = subscriptionVending.outputs.subscriptionId
output subscriptionResourceId string = subscriptionVending.outputs.subscriptionResourceId

// Virtual network information
output virtualNetworkName string = enableVirtualNetwork ? subscriptionVending.outputs.virtualNetworkName : ''
output virtualNetworkResourceId string = enableVirtualNetwork ? subscriptionVending.outputs.virtualNetworkResourceId : ''
output virtualNetworkAddressSpace array = enableVirtualNetwork ? virtualNetworkAddressSpace : []

// Subnet information
output workloadsSubnetResourceId string = enableVirtualNetwork ? '${subscriptionVending.outputs.virtualNetworkResourceId}/subnets/snet-workloads' : ''
output privateEndpointsSubnetResourceId string = enableVirtualNetwork ? '${subscriptionVending.outputs.virtualNetworkResourceId}/subnets/snet-private-endpoints' : ''
output bastionSubnetResourceId string = enableBastion && enableVirtualNetwork ? '${subscriptionVending.outputs.virtualNetworkResourceId}/subnets/AzureBastionSubnet' : ''

// Azure Bastion information
output bastionResourceId string = enableBastion ? subscriptionVending.outputs.bastionResourceId : ''
output bastionPublicIpAddress string = enableBastion ? subscriptionVending.outputs.bastionPublicIpAddress : ''

// Resource group information
output networkingResourceGroupName string = enableVirtualNetwork ? 'rg-${namingPrefix}-networking' : ''

// ALZ compliance metadata
output alzCompliance object = {
  pattern: 'ALZ Subscription Vending'
  framework: 'Azure Landing Zone'
  iacdApproach: 'AVM Pattern Module'
  avmModuleVersion: '0.4.0'
  landingZoneType: 'Application-Landing-Zone'
  networkingPattern: enableHubSpokeNetworking ? 'Hub-Spoke' : 'Standalone'
  complianceFramework: 'ALZ-Foundation'
  subscriptionVendingEnabled: true
  governanceEnabled: true
}
