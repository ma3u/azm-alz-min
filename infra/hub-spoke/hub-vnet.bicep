metadata name = 'Hub VNet - Core Networking Services'
metadata description = 'Deploys hub VNet with Azure Firewall, Bastion, DNS resolver using Azure Verified Modules'

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
}

// Naming convention
var namingPrefix = '${organizationPrefix}-hub-${environment}'

// Subnet definitions
var subnets = [
  {
    name: 'AzureBastionSubnet' // Fixed name required by Azure Bastion
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: bastionNsg.outputs.resourceId
    }
  }
  {
    name: 'AzureFirewallSubnet' // Fixed name required by Azure Firewall
    addressPrefix: '10.0.2.0/24'
  }
  {
    name: 'snet-dns-resolver'
    addressPrefix: '10.0.3.0/24'
    delegations: [
      {
        name: 'Microsoft.Network.dnsResolvers'
        properties: {
          serviceName: 'Microsoft.Network/dnsResolvers'
        }
      }
    ]
    networkSecurityGroup: {
      id: dnsResolverNsg.outputs.resourceId
    }
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.4.0/24'
    networkSecurityGroup: {
      id: managementNsg.outputs.resourceId
    }
  }
  {
    name: 'GatewaySubnet' // Fixed name for VPN/ExpressRoute Gateway
    addressPrefix: '10.0.100.0/24'
  }
]

// =======================
// NETWORK SECURITY GROUPS
// =======================

// Bastion NSG with required rules
module bastionNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'bastionNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-bastion'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowHttpsInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['8080', '5701']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 150
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389']
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['8080', '5701']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

// DNS Resolver NSG
module dnsResolverNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'dnsResolverNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-dns-resolver'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowDnsResolverInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Management NSG
module managementNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'managementNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-management'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowBastionInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389']
          sourceAddressPrefix: '10.0.1.0/24' // Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// =======================
// HUB VIRTUAL NETWORK
// =======================

module hubVnet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'hubVnetDeployment'
  params: {
    name: 'vnet-${namingPrefix}'
    location: location
    addressPrefixes: [hubVnetAddressPrefix]
    tags: commonTags

    subnets: subnets
  }
  dependsOn: [
    bastionNsg
    dnsResolverNsg
    managementNsg
  ]
}

// =======================
// AZURE FIREWALL
// =======================

// Public IP for Azure Firewall
module firewallPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableFirewall) {
  name: 'firewallPublicIpDeployment'
  params: {
    name: 'pip-${namingPrefix}-firewall'
    location: location
    tags: commonTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: ['1', '2', '3']
  }
}

// Azure Firewall Policy
module firewallPolicy 'br/public:avm/res/network/firewall-policy:0.1.3' = if (enableFirewall) {
  name: 'firewallPolicyDeployment'
  params: {
    name: 'afwp-${namingPrefix}'
    location: location
    tags: commonTags

    ruleCollectionGroups: [
      {
        name: 'NetworkRuleCollectionGroup'
        priority: 200
        ruleCollections: [
          {
            name: 'AllowSpokeToInternet'
            priority: 100
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            action: {
              type: 'Allow'
            }
            rules: [
              {
                name: 'AllowSpokeOutbound'
                ruleType: 'NetworkRule'
                sourceAddresses: ['10.1.0.0/16'] // Spoke VNet
                destinationAddresses: ['0.0.0.0/0']
                destinationPorts: ['80', '443', '53']
                ipProtocols: ['TCP', 'UDP']
              }
            ]
          }
        ]
      }
      {
        name: 'ApplicationRuleCollectionGroup'
        priority: 300
        ruleCollections: [
          {
            name: 'AllowAzureServices'
            priority: 100
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            action: {
              type: 'Allow'
            }
            rules: [
              {
                name: 'AllowAzureAPIs'
                ruleType: 'ApplicationRule'
                sourceAddresses: ['10.1.0.0/16']
                targetFqdns: [
                  '*.azure.com'
                  '*.microsoft.com'
                  '*.windows.net'
                  '*.microsoftonline.com'
                ]
                fqdnTags: []
                protocols: [
                  {
                    protocolType: 'Https'
                    port: 443
                  }
                  {
                    protocolType: 'Http'
                    port: 80
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}

// Azure Firewall
module azureFirewall 'br/public:avm/res/network/azure-firewall:0.8.0' = if (enableFirewall) {
  name: 'azureFirewallDeployment'
  params: {
    name: 'afw-${namingPrefix}'
    location: location
    tags: commonTags

    azureSkuTier: firewallSkuTier

    publicIPAddressObject: {
      publicIPAddresses: [
        {
          name: 'pip-${namingPrefix}-firewall'
          publicIPAddressResourceId: firewallPublicIp.outputs.resourceId
        }
      ]
    }

    firewallPolicyId: firewallPolicy.outputs.resourceId

    ipConfigurations: [
      {
        name: 'ipConfig1'
        subnetId: '${hubVnet.outputs.resourceId}/subnets/AzureFirewallSubnet'
        publicIPAddressResourceId: firewallPublicIp.outputs.resourceId
      }
    ]

    zones: ['1', '2', '3']
  }
  dependsOn: [
    hubVnet
  ]
}

// =======================
// AZURE BASTION
// =======================

// Public IP for Azure Bastion
module bastionPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableBastion) {
  name: 'bastionPublicIpDeployment'
  params: {
    name: 'pip-${namingPrefix}-bastion'
    location: location
    tags: commonTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

// Azure Bastion
module azureBastion 'br/public:avm/res/network/bastion-host:0.8.0' = if (enableBastion) {
  name: 'azureBastionDeployment'
  params: {
    name: 'bas-${namingPrefix}'
    location: location
    tags: commonTags

    virtualNetworkId: hubVnet.outputs.resourceId

    publicIpAddressObject: {
      publicIPAddresses: [
        {
          name: 'pip-${namingPrefix}-bastion'
          publicIPAddressResourceId: bastionPublicIp.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    hubVnet
  ]
}

// =======================
// DNS PRIVATE RESOLVER
// =======================

module dnsPrivateResolver 'br/public:avm/res/network/private-dns-resolver:0.1.1' = if (enableDnsResolver) {
  name: 'dnsPrivateResolverDeployment'
  params: {
    name: 'dnspr-${namingPrefix}'
    location: location
    tags: commonTags

    virtualNetworkId: hubVnet.outputs.resourceId

    inboundEndpoints: [
      {
        name: 'inbound-endpoint'
        subnetId: '${hubVnet.outputs.resourceId}/subnets/snet-dns-resolver'
      }
    ]
  }
  dependsOn: [
    hubVnet
  ]
}

// =======================
// OUTPUTS
// =======================

// Network outputs
output hubVnetId string = hubVnet.outputs.resourceId
output hubVnetName string = hubVnet.outputs.name
output hubVnetAddressSpace array = hubVnet.outputs.addressPrefixes

// Firewall outputs
output azureFirewallId string = enableFirewall ? azureFirewall.outputs.resourceId : ''
output azureFirewallPrivateIp string = enableFirewall ? azureFirewall.outputs.privateIp : ''
output firewallPublicIpAddress string = enableFirewall ? firewallPublicIp.outputs.ipAddress : ''

// Bastion outputs
output azureBastionId string = enableBastion ? azureBastion.outputs.resourceId : ''
output bastionPublicIpAddress string = enableBastion ? bastionPublicIp.outputs.ipAddress : ''

// DNS Resolver outputs
output dnsPrivateResolverId string = enableDnsResolver ? dnsPrivateResolver.outputs.resourceId : ''

// Subnet outputs for reference by spoke
output bastionSubnetId string = '${hubVnet.outputs.resourceId}/subnets/AzureBastionSubnet'
output firewallSubnetId string = '${hubVnet.outputs.resourceId}/subnets/AzureFirewallSubnet'
output dnsResolverSubnetId string = '${hubVnet.outputs.resourceId}/subnets/snet-dns-resolver'
output managementSubnetId string = '${hubVnet.outputs.resourceId}/subnets/snet-management'
output gatewaySubnetId string = '${hubVnet.outputs.resourceId}/subnets/GatewaySubnet'

// Common outputs
output location string = location
output environment string = environment
output tags object = commonTags
