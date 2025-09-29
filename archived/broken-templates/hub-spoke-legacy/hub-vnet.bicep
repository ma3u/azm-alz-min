metadata name = 'ALZ Hub Virtual Network'
metadata description = 'ALZ-compliant hub VNet with individual AVM resource modules following IaC Accelerator patterns'

targetScope = 'resourceGroup'

// =======================
// PARAMETERS - ALZ Standard
// =======================

@description('Primary Azure region for deployment')
param location string = resourceGroup().location

@description('Environment name for resource tagging')
@allowed(['dev', 'staging', 'prod', 'sandbox'])
param environment string = 'dev'

@description('Organization prefix for naming - ALZ standard')
param organizationPrefix string = 'alz'

@description('Hub VNet address space - ALZ standard 10.0.0.0/16')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Enable Azure Firewall deployment')
param enableFirewall bool = true

@description('Enable Azure Bastion deployment')
param enableBastion bool = true

@description('Enable DNS Private Resolver deployment')
param enableDnsResolver bool = true

@description('Firewall SKU tier - ALZ recommendation: Standard')
@allowed(['Basic', 'Standard', 'Premium'])
param firewallSkuTier string = 'Standard'

// =======================
// VARIABLES - ALZ Naming Standards
// =======================

var commonTags = {
  Environment: environment
  Project: 'Azure-Landing-Zone'
  Pattern: 'Hub-Spoke-ALZ'
  Component: 'Hub-Network'
  IaC: 'Bicep-AVM'
  DeployedBy: 'ALZ-IaC-Accelerator'
  Compliance: 'ALZ-Foundation'
}

// ALZ naming convention
var naming = {
  prefix: '${organizationPrefix}-hub-${environment}'
  vnet: 'vnet-${organizationPrefix}-hub-${environment}'
  firewall: 'afw-${organizationPrefix}-hub-${environment}'
  bastion: 'bas-${organizationPrefix}-hub-${environment}'
  dnsResolver: 'dnspr-${organizationPrefix}-hub-${environment}'
}

// ALZ Hub subnet layout
var subnets = [
  {
    name: 'AzureFirewallSubnet' // Required name for Azure Firewall
    addressPrefix: '10.0.2.0/24'
  }
  {
    name: 'AzureBastionSubnet' // Required name for Azure Bastion
    addressPrefix: '10.0.1.0/24'
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
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.4.0/24'
  }
  {
    name: 'GatewaySubnet' // Required name for VPN/ER Gateway
    addressPrefix: '10.0.100.0/24'
  }
]

// =======================
// HUB VIRTUAL NETWORK - ALZ Core
// =======================

module hubVnet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'hubVnetDeployment'
  params: {
    name: naming.vnet
    location: location
    tags: commonTags

    addressPrefixes: [hubVnetAddressPrefix]
    subnets: subnets

    // ALZ standard - DDoS protection plan (optional)
    // ddosProtectionPlanResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${organizationPrefix}-management-${environment}/providers/Microsoft.Network/ddosProtectionPlans/ddos-plan-${organizationPrefix}-${environment}'

    // Enable diagnostics for ALZ monitoring
    diagnosticSettings: [
      {
        name: 'hubVnetDiagnostics'
        workspaceResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${organizationPrefix}-management-${environment}/providers/Microsoft.OperationalInsights/workspaces/log-${organizationPrefix}-management-${environment}'
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]

    // ALZ role assignments for network management
    roleAssignments: []
  }
}

// =======================
// AZURE FIREWALL - ALZ Security
// =======================

// Firewall Policy - ALZ security baseline
module firewallPolicy 'br/public:avm/res/network/firewall-policy:0.1.3' = if (enableFirewall) {
  name: 'firewallPolicyDeployment'
  params: {
    name: 'afwp-${naming.prefix}'
    location: location
    tags: commonTags

    // ALZ firewall policy configuration
    tier: firewallSkuTier

    // ALZ rule collection groups
    ruleCollectionGroups: [
      {
        name: 'DefaultNetworkRuleCollectionGroup'
        priority: 200
        ruleCollections: [
          {
            name: 'AllowAzureCloud'
            priority: 100
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            action: {
              type: 'Allow'
            }
            rules: [
              {
                name: 'AllowAzurePlatformDNS'
                ruleType: 'NetworkRule'
                sourceAddresses: ['10.0.0.0/8']
                destinationAddresses: ['168.63.129.16']
                destinationPorts: ['53']
                ipProtocols: ['TCP', 'UDP']
              }
            ]
          }
        ]
      }
      {
        name: 'DefaultApplicationRuleCollectionGroup'
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
                name: 'AllowWindowsUpdate'
                ruleType: 'ApplicationRule'
                sourceAddresses: ['10.0.0.0/8']
                targetFqdns: [
                  '*.update.microsoft.com'
                  '*.windowsupdate.microsoft.com'
                ]
                protocols: [
                  {
                    protocolType: 'Https'
                    port: 443
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

// Firewall Public IP
module firewallPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableFirewall) {
  name: 'firewallPublicIpDeployment'
  params: {
    name: 'pip-${naming.prefix}-firewall'
    location: location
    tags: commonTags

    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: [1, 2, 3]
  }
}

// Azure Firewall
module azureFirewall 'br/public:avm/res/network/azure-firewall:0.8.0' = if (enableFirewall) {
  name: 'azureFirewallDeployment'
  params: {
    name: naming.firewall
    location: location
    tags: commonTags

    azureSkuTier: firewallSkuTier

    // Link to firewall policy
    firewallPolicyId: enableFirewall ? firewallPolicy.outputs.resourceId : ''

    // Hub VNet association - using subnet ID directly
    publicIPResourceID: enableFirewall ? firewallPublicIp.outputs.resourceId : ''

    // Enable diagnostics
    diagnosticSettings: [
      {
        name: 'firewallDiagnostics'
        workspaceResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${organizationPrefix}-management-${environment}/providers/Microsoft.OperationalInsights/workspaces/log-${organizationPrefix}-management-${environment}'
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
  }
}

// =======================
// AZURE BASTION - ALZ Access
// =======================

// Bastion Public IP
module bastionPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableBastion) {
  name: 'bastionPublicIpDeployment'
  params: {
    name: 'pip-${naming.prefix}-bastion'
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
    name: naming.bastion
    location: location
    tags: commonTags

    // ALZ standard configuration
    skuName: 'Standard'
    scaleUnits: 2

    // Hub VNet integration
    virtualNetworkResourceId: hubVnet.outputs.resourceId

    // Public IP configuration
    publicIPAddressObject: {
      publicIPAddresses: [
        {
          name: 'pip-${naming.prefix}-bastion'
          publicIPAddressResourceId: enableBastion ? bastionPublicIp.outputs.resourceId : ''
        }
      ]
    }

    // ALZ security features
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: true
    enableShareableLink: false
    enableSessionRecording: false

    // Enable diagnostics
    diagnosticSettings: [
      {
        name: 'bastionDiagnostics'
        workspaceResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${organizationPrefix}-management-${environment}/providers/Microsoft.OperationalInsights/workspaces/log-${organizationPrefix}-management-${environment}'
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
      }
    ]
  }
}

// =======================
// DNS PRIVATE RESOLVER - ALZ Networking
// =======================

module dnsPrivateResolver 'br/public:avm/res/network/dns-resolver:0.5.4' = if (enableDnsResolver) {
  name: 'dnsPrivateResolverDeployment'
  params: {
    name: naming.dnsResolver
    location: location
    tags: commonTags

    // Hub VNet integration
    virtualNetworkResourceId: hubVnet.outputs.resourceId

    // Inbound endpoints for ALZ workloads
    inboundEndpoints: [
      {
        name: 'inbound-endpoint'
        subnetResourceId: '${hubVnet.outputs.resourceId}/subnets/snet-dns-resolver'
      }
    ]

    // Enable diagnostics
    diagnosticSettings: [
      {
        name: 'dnsResolverDiagnostics'
        workspaceResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${organizationPrefix}-management-${environment}/providers/Microsoft.OperationalInsights/workspaces/log-${organizationPrefix}-management-${environment}'
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
  }
}

// =======================
// OUTPUTS - ALZ Standard
// =======================

// Network outputs for ALZ spoke connectivity
output hubVirtualNetworkResourceId string = hubVnet.outputs.resourceId
output hubVirtualNetworkName string = hubVnet.outputs.name
output hubVirtualNetworkAddressSpace array = [hubVnetAddressPrefix]

// Subnet resource IDs for ALZ workload deployment
output azureFirewallSubnetResourceId string = '${hubVnet.outputs.resourceId}/subnets/AzureFirewallSubnet'
output azureBastionSubnetResourceId string = '${hubVnet.outputs.resourceId}/subnets/AzureBastionSubnet'
output dnsResolverSubnetResourceId string = '${hubVnet.outputs.resourceId}/subnets/snet-dns-resolver'
output managementSubnetResourceId string = '${hubVnet.outputs.resourceId}/subnets/snet-management'
output gatewaySubnetResourceId string = '${hubVnet.outputs.resourceId}/subnets/GatewaySubnet'

// Azure Firewall outputs for ALZ routing
output azureFirewallResourceId string = enableFirewall ? azureFirewall.outputs.resourceId : ''
output azureFirewallPrivateIPAddress string = enableFirewall ? azureFirewall.outputs.privateIp : ''
output azureFirewallPublicIPAddress string = enableFirewall ? firewallPublicIp.outputs.ipAddress : ''

// Azure Bastion outputs for ALZ access management
output azureBastionResourceId string = enableBastion ? azureBastion.outputs.resourceId : ''
output azureBastionPublicIPAddress string = enableBastion ? bastionPublicIp.outputs.ipAddress : ''

// DNS Private Resolver outputs for ALZ name resolution
output dnsPrivateResolverResourceId string = enableDnsResolver ? dnsPrivateResolver.outputs.resourceId : ''

// ALZ compliance and metadata
output alzCompliance object = {
  pattern: 'ALZ Hub Virtual Network'
  framework: 'Azure Landing Zone'
  iacdApproach: 'Individual AVM Resources'
  avmVersion: '2024-Q4'
  landingZoneType: 'Platform-Hub'
  networkingPattern: 'Hub-Spoke'
  securityBaseline: 'ALZ-Foundation'
  monitoringEnabled: true
  diagnosticsEnabled: true
}
