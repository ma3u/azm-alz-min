metadata name = 'Azure Landing Zone - Hub Spoke with AVM Accelerator Patterns'
metadata description = 'Deploys Azure Landing Zone Hub-Spoke architecture using official AVM accelerator patterns'

targetScope = 'managementGroup'

// =======================
// PARAMETERS
// =======================

@description('Primary Azure region for deployment')
param location string = deployment().location

@description('Environment name for resource tagging')
@allowed(['dev', 'staging', 'prod', 'sandbox'])
param environment string = 'dev'

@description('Organization prefix for naming')
param organizationPrefix string = 'alz'

@description('Management Group ID where the landing zone will be deployed')
param managementGroupId string

@description('Billing scope for subscription creation (EA/MCA enrollment account)')
param billingScope string

@description('Hub Virtual Network address space')
param hubVnetAddressSpace string = '10.0.0.0/16'

@description('Spoke Virtual Network address space')
param spokeVnetAddressSpace string = '10.1.0.0/16'

@description('Enable Azure Firewall in hub')
param enableAzureFirewall bool = true

@description('Enable Azure Bastion in hub')
param enableBastion bool = true

@description('Enable VPN Gateway in hub')
param enableVpnGateway bool = false

@description('Enable ExpressRoute Gateway in hub')
param enableExpressRouteGateway bool = false

@description('Database administrator password')
@secure()
param dbAdministratorPassword string

@description('Application workload configuration')
param applicationWorkloads object = {
  enableWebApp: true
  enableContainerApps: true
  enablePostgreSQL: true
  enableStorage: true
  enableAppGateway: true
}

// =======================
// VARIABLES
// =======================

var commonTags = {
  Environment: environment
  Organization: organizationPrefix
  Pattern: 'ALZ-HubSpoke-AVM-Accelerator'
  IaC: 'Bicep-AVM-Patterns'
  DeployedBy: 'AVM-Accelerator'
}

// Subscription names
var hubSubscriptionName = '${organizationPrefix}-hub-${environment}'
var spokeSubscriptionName = '${organizationPrefix}-spoke-${environment}'

// =======================
// HUB SUBSCRIPTION WITH AVM PATTERN
// =======================

// Hub subscription using AVM subscription management pattern
module hubSubscription 'br/public:avm/ptn/lz/sub-vending:0.4.0' = {
  name: 'hubSubscriptionDeployment'
  params: {
    subscriptionAliasName: '${hubSubscriptionName}-sub'
    subscriptionDisplayName: hubSubscriptionName
    subscriptionBillingScope: billingScope
    subscriptionManagementGroupAssociationEnabled: true
    subscriptionManagementGroupId: managementGroupId
    subscriptionWorkload: 'Production'

    // Hub networking configuration
    virtualNetworkEnabled: true
    virtualNetworkName: 'vnet-${organizationPrefix}-hub-${environment}'
    virtualNetworkAddressPrefixes: [hubVnetAddressSpace]
    virtualNetworkLocation: location

    virtualNetworkVnetSubnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupName: 'nsg-hub-bastion'
        networkSecurityGroupRules: [
          {
            name: 'AllowHttpsInbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 120
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '443'
              sourceAddressPrefix: 'Internet'
              destinationAddressPrefix: '*'
            }
          }
          {
            name: 'AllowGatewayManagerInbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 130
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '443'
              sourceAddressPrefix: 'GatewayManager'
              destinationAddressPrefix: '*'
            }
          }
        ]
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.2.0/24'
      }
      {
        name: 'snet-shared-services'
        addressPrefix: '10.0.3.0/24'
        networkSecurityGroupName: 'nsg-hub-shared'
        networkSecurityGroupRules: [
          {
            name: 'AllowVNetInbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 100
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '*'
              sourceAddressPrefix: 'VirtualNetwork'
              destinationAddressPrefix: 'VirtualNetwork'
            }
          }
        ]
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.100.0/24'
      }
    ]

    virtualNetworkTags: commonTags

    // Role assignments
    roleAssignmentEnabled: true
    roleAssignments: [
      {
        principalId: '' // Will be populated with service principal
        roleDefinitionIdOrName: 'Network Contributor'
        description: 'Hub network management'
      }
    ]
  }
}

// =======================
// HUB NETWORKING PATTERN
// =======================

// Deploy hub networking using AVM hub networking pattern
module hubNetworking 'br/public:avm/ptn/network/hub-networking:0.1.0' = {
  name: 'hubNetworkingDeployment'
  scope: resourceGroup(hubSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-hub-${environment}')
  params: {
    hubVirtualNetworkName: 'vnet-${organizationPrefix}-hub-${environment}'
    hubVirtualNetworkAddressPrefixes: [hubVnetAddressSpace]
    location: location
    tags: commonTags

    // Azure Firewall configuration
    azureFirewallEnabled: enableAzureFirewall
    azureFirewallName: 'afw-${organizationPrefix}-hub-${environment}'
    azureFirewallTier: 'Standard'
    azureFirewallPolicyName: 'afwp-${organizationPrefix}-hub-${environment}'

    // Bastion configuration
    bastionEnabled: enableBastion
    bastionName: 'bas-${organizationPrefix}-hub-${environment}'
    bastionSku: 'Standard'

    // VPN Gateway configuration
    vpnGatewayEnabled: enableVpnGateway
    vpnGatewayName: enableVpnGateway ? 'vpngw-${organizationPrefix}-hub-${environment}' : ''
    vpnGatewaySku: enableVpnGateway ? 'VpnGw1' : ''

    // ExpressRoute Gateway configuration
    expressRouteGatewayEnabled: enableExpressRouteGateway
    expressRouteGatewayName: enableExpressRouteGateway ? 'ergw-${organizationPrefix}-hub-${environment}' : ''
    expressRouteGatewaySku: enableExpressRouteGateway ? 'Standard' : ''

    // DNS configuration
    dnsServerIps: []

    // Route table for spoke traffic
    hubRouteTableName: 'rt-${organizationPrefix}-hub-${environment}'
  }
  dependsOn: [
    hubSubscription
  ]
}

// =======================
// SPOKE SUBSCRIPTION WITH WORKLOADS
// =======================

// Spoke subscription for application workloads
module spokeSubscription 'br/public:avm/ptn/lz/sub-vending:0.4.0' = {
  name: 'spokeSubscriptionDeployment'
  params: {
    subscriptionAliasName: '${spokeSubscriptionName}-sub'
    subscriptionDisplayName: spokeSubscriptionName
    subscriptionBillingScope: billingScope
    subscriptionManagementGroupAssociationEnabled: true
    subscriptionManagementGroupId: managementGroupId
    subscriptionWorkload: 'Production'

    // Spoke networking configuration
    virtualNetworkEnabled: true
    virtualNetworkName: 'vnet-${organizationPrefix}-spoke-${environment}'
    virtualNetworkAddressPrefixes: [spokeVnetAddressSpace]
    virtualNetworkLocation: location

    virtualNetworkVnetSubnets: [
      {
        name: 'snet-app-gateway'
        addressPrefix: '10.1.1.0/24'
        networkSecurityGroupName: 'nsg-spoke-appgw'
        networkSecurityGroupRules: [
          {
            name: 'AllowHTTPSInbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 100
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRanges: ['80', '443']
              sourceAddressPrefix: 'Internet'
              destinationAddressPrefix: '*'
            }
          }
          {
            name: 'AllowGatewayManagerInbound'
            properties: {
              access: 'Allow'
              direction: 'Inbound'
              priority: 110
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '65200-65535'
              sourceAddressPrefix: 'GatewayManager'
              destinationAddressPrefix: '*'
            }
          }
        ]
      }
      {
        name: 'snet-web-apps'
        addressPrefix: '10.1.2.0/24'
        networkSecurityGroupName: 'nsg-spoke-webapp'
        delegations: [
          {
            name: 'Microsoft.Web.serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
      {
        name: 'snet-container-apps'
        addressPrefix: '10.1.3.0/24'
        networkSecurityGroupName: 'nsg-spoke-containerapp'
        delegations: [
          {
            name: 'Microsoft.App.environments'
            properties: {
              serviceName: 'Microsoft.App/environments'
            }
          }
        ]
      }
      {
        name: 'snet-database'
        addressPrefix: '10.1.10.0/24'
        networkSecurityGroupName: 'nsg-spoke-database'
        delegations: [
          {
            name: 'Microsoft.DBforPostgreSQL.flexibleServers'
            properties: {
              serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
            }
          }
        ]
      }
      {
        name: 'snet-private-endpoints'
        addressPrefix: '10.1.11.0/24'
        networkSecurityGroupName: 'nsg-spoke-pe'
      }
    ]

    virtualNetworkTags: commonTags

    // Hub-spoke peering
    virtualNetworkPeeringEnabled: true
    virtualNetworkPeeringsAll: [
      {
        remoteVirtualNetworkResourceId: hubNetworking.outputs.hubVirtualNetworkResourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        allowGatewayTransit: false
        useRemoteGateways: enableVpnGateway || enableExpressRouteGateway
      }
    ]
  }
  dependsOn: [
    hubNetworking
  ]
}

// =======================
// APPLICATION WORKLOADS PATTERN
// =======================

// Deploy application workloads using AVM application landing zone pattern
module applicationWorkloadsPattern 'br/public:avm/ptn/app/dapr-containerapp:0.1.0' = if (applicationWorkloads.enableContainerApps) {
  name: 'applicationWorkloadsDeployment'
  scope: resourceGroup(spokeSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    location: location
    environmentName: 'cae-${organizationPrefix}-${environment}'
    tags: commonTags

    // Container Apps Environment configuration
    containerAppsEnvironmentName: 'cae-${organizationPrefix}-${environment}'
    logAnalyticsWorkspaceName: 'log-${organizationPrefix}-spoke-${environment}'

    // Network integration
    containerAppsEnvironmentInfrastructureSubnetId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-container-apps'
    containerAppsEnvironmentInternal: true

    // Application configuration
    containerAppName: 'ca-${organizationPrefix}-app-${environment}'
    containerAppContainerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    containerAppContainerName: 'hello-world-app'

    // Dapr configuration
    daprEnabled: true
    daprAppId: '${organizationPrefix}-app'
    daprAppProtocol: 'http'
    daprAppPort: 80
  }
  dependsOn: [
    spokeSubscription
  ]
}

// =======================
// WEB APPLICATION PATTERN
// =======================

module webApplicationPattern 'br/public:avm/ptn/web/static-site:0.1.0' = if (applicationWorkloads.enableWebApp) {
  name: 'webApplicationDeployment'
  scope: resourceGroup(spokeSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    location: location
    name: 'app-${organizationPrefix}-web-${environment}'
    tags: commonTags

    // App Service Plan configuration
    appServicePlanName: 'asp-${organizationPrefix}-${environment}'
    appServicePlanSkuName: 'P1v3'

    // Network integration
    virtualNetworkSubnetId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-web-apps'

    // Private endpoint configuration
    privateEndpointEnabled: true
    privateEndpointSubnetId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-private-endpoints'

    // Application settings
    appSettings: [
      {
        name: 'ENVIRONMENT'
        value: environment
      }
      {
        name: 'ORGANIZATION'
        value: organizationPrefix
      }
    ]
  }
  dependsOn: [
    spokeSubscription
  ]
}

// =======================
// DATABASE PATTERN
// =======================

module databasePattern 'br/public:avm/ptn/data/private-analytical-workspace:0.1.0' = if (applicationWorkloads.enablePostgreSQL) {
  name: 'databasePatternDeployment'
  scope: resourceGroup(spokeSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    location: location
    name: 'db-${organizationPrefix}-${environment}'
    tags: commonTags

    // PostgreSQL configuration
    postgreSqlServerName: 'psql-${organizationPrefix}-${environment}-${take(uniqueString(spokeSubscription.outputs.subscriptionId), 8)}'
    postgreSqlServerAdministratorLogin: 'alzadmin'
    postgreSqlServerAdministratorLoginPassword: dbAdministratorPassword
    postgreSqlServerSkuName: 'Standard_B1ms'
    postgreSqlServerStorageSizeGB: 32

    // Network integration
    postgreSqlServerDelegatedSubnetId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-database'

    // Private DNS zone
    privateDnsZoneName: 'privatelink.postgres.database.azure.com'
    privateDnsZoneVirtualNetworkLinks: [
      {
        virtualNetworkResourceId: spokeSubscription.outputs.virtualNetworkResourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: hubNetworking.outputs.hubVirtualNetworkResourceId
        registrationEnabled: false
      }
    ]
  }
  dependsOn: [
    spokeSubscription
  ]
}

// =======================
// STORAGE PATTERN
// =======================

module storagePattern 'br/public:avm/ptn/storage/storage-account-private-endpoints:0.1.0' = if (applicationWorkloads.enableStorage) {
  name: 'storagePatternDeployment'
  scope: resourceGroup(spokeSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    location: location
    storageAccountName: 'st${organizationPrefix}spoke${environment}${take(uniqueString(spokeSubscription.outputs.subscriptionId), 8)}'
    tags: commonTags

    // Storage configuration
    storageAccountKind: 'StorageV2'
    storageAccountSkuName: 'Standard_LRS'
    storageAccountAccessTier: 'Hot'

    // Security configuration
    storageAccountAllowBlobPublicAccess: false
    storageAccountMinimumTlsVersion: 'TLS1_2'
    storageAccountPublicNetworkAccess: 'Disabled'

    // Private endpoint configuration
    privateEndpoints: [
      {
        name: 'pe-${organizationPrefix}-storage-blob-${environment}'
        service: 'blob'
        subnetResourceId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-private-endpoints'
        privateDnsZoneResourceIds: []
      }
    ]
  }
  dependsOn: [
    spokeSubscription
  ]
}

// =======================
// APPLICATION GATEWAY PATTERN
// =======================

module applicationGatewayPattern 'br/public:avm/ptn/network/application-gateway-web-application-firewall:0.1.0' = if (applicationWorkloads.enableAppGateway) {
  name: 'applicationGatewayDeployment'
  scope: resourceGroup(spokeSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    location: location
    applicationGatewayName: 'agw-${organizationPrefix}-${environment}'
    tags: commonTags

    // Application Gateway configuration
    applicationGatewaySkuName: 'WAF_v2'
    applicationGatewaySkuTier: 'WAF_v2'
    applicationGatewaySkuCapacity: 2

    // Network configuration
    applicationGatewaySubnetId: '${spokeSubscription.outputs.virtualNetworkResourceId}/subnets/snet-app-gateway'

    // Public IP configuration
    applicationGatewayPublicIpName: 'pip-${organizationPrefix}-appgw-${environment}'
    applicationGatewayPublicIpSku: 'Standard'
    applicationGatewayPublicIpAllocationMethod: 'Static'

    // Backend configuration
    applicationGatewayBackendAddressPools: [
      {
        name: 'webAppBackendPool'
        backendAddresses: applicationWorkloads.enableWebApp ? [
          {
            fqdn: webApplicationPattern.outputs.webAppDefaultHostname
          }
        ] : []
      }
    ]

    // WAF configuration
    webApplicationFirewallEnabled: true
    webApplicationFirewallMode: 'Prevention'
    webApplicationFirewallRuleSetType: 'OWASP'
    webApplicationFirewallRuleSetVersion: '3.2'
  }
  dependsOn: [
    spokeSubscription
    webApplicationPattern
  ]
}

// =======================
// PRIVATE DNS ZONES
// =======================

module privateDnsZones 'br/public:avm/ptn/network/private-dns-zones:0.1.0' = {
  name: 'privateDnsZonesDeployment'
  scope: resourceGroup(hubSubscription.outputs.subscriptionId, 'rg-${organizationPrefix}-hub-${environment}')
  params: {
    location: location
    tags: commonTags

    privateDnsZones: [
      {
        name: 'privatelink.azurewebsites.net'
        virtualNetworkLinks: [
          {
            virtualNetworkResourceId: hubNetworking.outputs.hubVirtualNetworkResourceId
            registrationEnabled: false
          }
          {
            virtualNetworkResourceId: spokeSubscription.outputs.virtualNetworkResourceId
            registrationEnabled: false
          }
        ]
      }
      {
        name: 'privatelink.blob.core.windows.net'
        virtualNetworkLinks: [
          {
            virtualNetworkResourceId: hubNetworking.outputs.hubVirtualNetworkResourceId
            registrationEnabled: false
          }
          {
            virtualNetworkResourceId: spokeSubscription.outputs.virtualNetworkResourceId
            registrationEnabled: false
          }
        ]
      }
      {
        name: 'privatelink.postgres.database.azure.com'
        virtualNetworkLinks: [
          {
            virtualNetworkResourceId: hubNetworking.outputs.hubVirtualNetworkResourceId
            registrationEnabled: false
          }
          {
            virtualNetworkResourceId: spokeSubscription.outputs.virtualNetworkResourceId
            registrationEnabled: false
          }
        ]
      }
    ]
  }
  dependsOn: [
    hubNetworking
    spokeSubscription
  ]
}

// =======================
// OUTPUTS
// =======================

// Subscription outputs
output hubSubscriptionId string = hubSubscription.outputs.subscriptionId
output spokeSubscriptionId string = spokeSubscription.outputs.subscriptionId

// Hub networking outputs
output hubVirtualNetworkId string = hubNetworking.outputs.hubVirtualNetworkResourceId
output azureFirewallId string = enableAzureFirewall ? hubNetworking.outputs.azureFirewallResourceId : ''
output bastionId string = enableBastion ? hubNetworking.outputs.bastionResourceId : ''

// Spoke networking outputs
output spokeVirtualNetworkId string = spokeSubscription.outputs.virtualNetworkResourceId

// Application outputs
output webAppId string = applicationWorkloads.enableWebApp ? webApplicationPattern.outputs.webAppResourceId : ''
output containerAppId string = applicationWorkloads.enableContainerApps ? applicationWorkloadsPattern.outputs.containerAppResourceId : ''
output applicationGatewayId string = applicationWorkloads.enableAppGateway ? applicationGatewayPattern.outputs.applicationGatewayResourceId : ''
output storageAccountId string = applicationWorkloads.enableStorage ? storagePattern.outputs.storageAccountResourceId : ''
output postgreSQLServerId string = applicationWorkloads.enablePostgreSQL ? databasePattern.outputs.postgreSqlServerResourceId : ''

// Connection information
output connectionInfo object = {
  subscriptions: {
    hub: hubSubscription.outputs.subscriptionId
    spoke: spokeSubscription.outputs.subscriptionId
  }
  networking: {
    hubVNet: hubNetworking.outputs.hubVirtualNetworkResourceId
    spokeVNet: spokeSubscription.outputs.virtualNetworkResourceId
    firewall: enableAzureFirewall ? hubNetworking.outputs.azureFirewallResourceId : ''
    bastion: enableBastion ? hubNetworking.outputs.bastionResourceId : ''
  }
  applications: {
    webApp: applicationWorkloads.enableWebApp ? webApplicationPattern.outputs.webAppDefaultHostname : ''
    applicationGateway: applicationWorkloads.enableAppGateway ? applicationGatewayPattern.outputs.applicationGatewayPublicIpAddress : ''
    database: applicationWorkloads.enablePostgreSQL ? databasePattern.outputs.postgreSqlServerFqdn : ''
    storage: applicationWorkloads.enableStorage ? storagePattern.outputs.storageAccountName : ''
  }
}

// AVM Accelerator Pattern Information
output avmAcceleratorInfo object = {
  description: 'This deployment uses official AVM accelerator patterns'
  patternsUsed: [
    'avm/ptn/lz/sub-vending:0.4.0'
    'avm/ptn/network/hub-networking:0.1.0'
    'avm/ptn/app/dapr-containerapp:0.1.0'
    'avm/ptn/web/static-site:0.1.0'
    'avm/ptn/data/private-analytical-workspace:0.1.0'
    'avm/ptn/storage/storage-account-private-endpoints:0.1.0'
    'avm/ptn/network/application-gateway-web-application-firewall:0.1.0'
    'avm/ptn/network/private-dns-zones:0.1.0'
  ]
  benefits: [
    'Microsoft-maintained and validated patterns'
    'Consistent deployment across environments'
    'Built-in security and compliance best practices'
    'Reduced template complexity and maintenance'
    'Faster time to production with proven patterns'
  ]
}
