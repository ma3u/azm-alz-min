metadata name = 'Hub VNet - ALZ Hub Networking Pattern'
metadata description = 'Deploys ALZ-compliant hub VNet using Azure Verified Module hub networking pattern'

targetScope = 'resourceGroup'

// =======================
// PARAMETERS
// =======================

@description('Primary Azure region for deployment')
param location string = resourceGroup().location

@description('Environment name for resource tagging')
@allowed(['dev', 'staging', 'prod', 'sandbox'])
param environment string = 'dev'

@description('Organization prefix for naming')
param organizationPrefix string = 'alz'

@description('Hub VNet address prefix')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Enable Azure Firewall deployment')
param enableFirewall bool = true

@description('Enable Azure Bastion deployment')
param enableBastion bool = true

@description('Enable DNS Private Resolver deployment')
param enableDnsResolver bool = true

@description('Firewall SKU tier')
@allowed(['Basic', 'Standard', 'Premium'])
param firewallSkuTier string = 'Standard'

// =======================
// VARIABLES
// =======================

var commonTags = {
  Environment: environment
  Project: 'Azure-Landing-Zone'
  Pattern: 'Hub-Spoke'
  Component: 'Hub-Network'
  IaC: 'Bicep-AVM'
  DeployedBy: 'Warp-AI-Assistant'
  Template: 'ALZ-HubNetworking-AVM'
}

// Naming convention following ALZ standards
var namingPrefix = '${organizationPrefix}-hub-${environment}'

// =======================
// HUB NETWORKING PATTERN MODULE
// =======================

// Using official AVM Hub Networking Pattern
module hubNetworking 'br/public:avm/ptn/network/hub-networking:0.5.0' = {
  name: 'hubNetworkingDeployment'
  params: {
    hubVirtualNetworkName: 'vnet-${namingPrefix}'
    hubVirtualNetworkAddressPrefix: hubVnetAddressPrefix
    location: location
    tags: commonTags

    // Firewall configuration
    enableAzureFirewall: enableFirewall
    azureFirewallName: enableFirewall ? 'afw-${namingPrefix}' : ''
    azureFirewallTier: firewallSkuTier
    azureFirewallZones: ['1', '2', '3']
    azureFirewallPolicyName: enableFirewall ? 'afwp-${namingPrefix}' : ''

    // Bastion configuration
    enableBastion: enableBastion
    bastionName: enableBastion ? 'bas-${namingPrefix}' : ''
    bastionSubnetAddressPrefix: '10.0.1.0/24'

    // DNS resolver configuration
    enableDnsResolver: enableDnsResolver
    dnsResolverName: enableDnsResolver ? 'dnspr-${namingPrefix}' : ''

    // Additional subnets
    subnets: [
      {
        name: 'snet-management'
        addressPrefix: '10.0.4.0/24'
        networkSecurityGroupName: 'nsg-${namingPrefix}-management'
        networkSecurityGroupSecurityRules: [
          {
            name: 'Allow-Management-Inbound'
            properties: {
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRanges: ['22', '3389', '443', '80']
              sourceAddressPrefix: '10.0.0.0/8'
              destinationAddressPrefix: '*'
              access: 'Allow'
              priority: 100
              direction: 'Inbound'
            }
          }
          {
            name: 'Allow-Management-Outbound'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '*'
              sourceAddressPrefix: '*'
              destinationAddressPrefix: '10.0.0.0/8'
              access: 'Allow'
              priority: 100
              direction: 'Outbound'
            }
          }
        ]
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.100.0/24'
      }
    ]

    // Public IP configurations
    publicIPAddressAvailabilityZones: ['1', '2', '3']

    // Enable diagnostics
    enableTelemetry: true
  }
}

// =======================
// OUTPUTS
// =======================

// Network outputs
output hubVnetId string = hubNetworking.outputs.virtualNetworkResourceId
output hubVnetName string = hubNetworking.outputs.virtualNetworkName
output hubVnetAddressSpace array = [hubVnetAddressPrefix]

// Firewall outputs (conditional)
output azureFirewallId string = enableFirewall ? hubNetworking.outputs.azureFirewallResourceId : ''
output azureFirewallPrivateIp string = enableFirewall ? hubNetworking.outputs.azureFirewallPrivateIp : ''
output firewallPublicIpAddress string = enableFirewall ? hubNetworking.outputs.azureFirewallPublicIp : ''

// Bastion outputs (conditional)
output azureBastionId string = enableBastion ? hubNetworking.outputs.bastionResourceId : ''
output bastionPublicIpAddress string = enableBastion ? hubNetworking.outputs.bastionPublicIpAddress : ''

// DNS Resolver outputs (conditional)
output dnsPrivateResolverId string = enableDnsResolver ? hubNetworking.outputs.dnsResolverResourceId : ''

// Subnet outputs for reference by spoke
output bastionSubnetId string = enableBastion ? '${hubNetworking.outputs.virtualNetworkResourceId}/subnets/AzureBastionSubnet' : ''
output firewallSubnetId string = enableFirewall ? '${hubNetworking.outputs.virtualNetworkResourceId}/subnets/AzureFirewallSubnet' : ''
output managementSubnetId string = '${hubNetworking.outputs.virtualNetworkResourceId}/subnets/snet-management'
output gatewaySubnetId string = '${hubNetworking.outputs.virtualNetworkResourceId}/subnets/GatewaySubnet'

// Resource Group info
output resourceGroupName string = resourceGroup().name
output location string = location

// ALZ compliance metadata
output alzCompliance object = {
  pattern: 'AVM Hub Networking Pattern'
  version: '0.5.0'
  compliance: 'ALZ Foundation'
  landingZoneType: 'Hub'
  networkingApproach: 'Hub-Spoke'
}
