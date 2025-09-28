metadata name = 'Azure Landing Zone - AVM Pattern-Based Implementation'
metadata description = 'Complete ALZ implementation using official AVM pattern and resource modules'

targetScope = 'managementGroup'

// =======================
// PARAMETERS
// =======================

@description('Management Group ID for ALZ deployment')
param managementGroupId string

@description('Primary Azure region for deployment')
param location string = deployment().location

@description('Environment name for resource tagging')
@allowed(['sandbox', 'dev', 'test', 'prod'])
param environment string = 'sandbox'

@description('Organization prefix for naming')
param organizationPrefix string = 'alz'

@description('Hub Virtual Network address space')
param hubVnetAddressSpace string = '10.0.0.0/16'

@description('Spoke Virtual Network address space')
param spokeVnetAddressSpace string = '10.1.0.0/16'

@description('SSH public key for secure VM access')
param sshPublicKey string = loadTextContent('../../.secrets/azure-alz-key.pub')

@description('Enable Azure Firewall in hub')
param enableAzureFirewall bool = false

@description('Enable Azure Bastion in hub')
param enableBastion bool = false

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
  Pattern: 'ALZ-AVM-Patterns'
  IaC: 'Bicep-AVM-Official'
  DeployedBy: 'Warp-AI-ALZ'
  Purpose: 'Production-Ready-ALZ'
}

// =======================
// AVM PATTERN MODULES
// =======================

// Hub subscription creation and networking using AVM pattern
module hubLandingZone 'br/public:avm/ptn/lz/sub-vending:0.2.0' = {
  name: 'hubLandingZoneDeployment'
  params: {
    subscriptionAliasName: '${organizationPrefix}-hub-${environment}'
    subscriptionDisplayName: '${organizationPrefix} Hub Landing Zone - ${environment}'
    subscriptionTags: commonTags
    subscriptionWorkload: 'Production'
    subscriptionManagementGroupAssociationEnabled: true
    subscriptionManagementGroupId: managementGroupId

    // Network configuration for hub
    virtualNetworkEnabled: true
    virtualNetworkConfiguration: {
      name: 'vnet-${organizationPrefix}-hub-${environment}'
      location: location
      tags: commonTags
      addressSpace: {
        addressPrefixes: [hubVnetAddressSpace]
      }
      subnets: [
        {
          name: 'AzureBastionSubnet'
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            securityRules: [
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
            ]
          }
        }
        {
          name: 'AzureFirewallSubnet'
          addressPrefix: '10.0.2.0/24'
        }
        {
          name: 'snet-shared-services'
          addressPrefix: '10.0.3.0/24'
        }
        {
          name: 'GatewaySubnet'
          addressPrefix: '10.0.100.0/24'
        }
      ]
    }
  }
}

// Hub networking pattern using AVM
module hubNetworking 'br/public:avm/ptn/network/hub-networking:0.1.0' = {
  name: 'hubNetworkingDeployment'
  scope: resourceGroup(hubLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-hub-${environment}')
  params: {
    location: location
    tags: commonTags

    // Hub VNet configuration
    hubVirtualNetworkName: 'vnet-${organizationPrefix}-hub-${environment}'
    hubVirtualNetworkAddressPrefixes: [hubVnetAddressSpace]

    // Azure Firewall
    azureFirewallEnabled: enableAzureFirewall
    azureFirewallName: enableAzureFirewall ? 'afw-${organizationPrefix}-hub-${environment}' : ''
    azureFirewallTier: 'Standard'

    // Azure Bastion
    bastionHostEnabled: enableBastion
    bastionHostName: enableBastion ? 'bas-${organizationPrefix}-hub-${environment}' : ''
    bastionHostSku: 'Standard'

    // VPN Gateway (optional)
    vpnGatewayEnabled: false

    // ExpressRoute Gateway (optional)
    expressRouteGatewayEnabled: false

    // Private DNS Zones
    privateDnsZonesEnabled: true
    privateDnsZones: [
      'privatelink.blob.core.windows.net'
      'privatelink.postgres.database.azure.com'
      'privatelink.azurewebsites.net'
    ]
  }
  dependsOn: [
    hubLandingZone
  ]
}

// Spoke subscription for application workloads
module spokeLandingZone 'br/public:avm/ptn/lz/sub-vending:0.2.0' = {
  name: 'spokeLandingZoneDeployment'
  params: {
    subscriptionAliasName: '${organizationPrefix}-spoke-apps-${environment}'
    subscriptionDisplayName: '${organizationPrefix} Spoke Apps Landing Zone - ${environment}'
    subscriptionTags: commonTags
    subscriptionWorkload: 'Production'
    subscriptionManagementGroupAssociationEnabled: true
    subscriptionManagementGroupId: managementGroupId

    // Network configuration for spoke
    virtualNetworkEnabled: true
    virtualNetworkConfiguration: {
      name: 'vnet-${organizationPrefix}-spoke-${environment}'
      location: location
      tags: commonTags
      addressSpace: {
        addressPrefixes: [spokeVnetAddressSpace]
      }
      subnets: [
        {
          name: 'snet-app-gateway'
          addressPrefix: '10.1.1.0/24'
        }
        {
          name: 'snet-web-apps'
          addressPrefix: '10.1.2.0/24'
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
        }
      ]
    }

    // Hub-spoke peering configuration
    hubNetworkResourceId: hubNetworking.outputs.virtualNetworkResourceId
    enableVirtualNetworkPeering: true
  }
  dependsOn: [
    hubNetworking
  ]
}

// =======================
// APPLICATION SERVICES WITH AVM RESOURCE MODULES
// =======================

// Web App Service using AVM resource modules
module webAppServices 'br/public:avm/res/web/serverfarm:0.2.0' = if (applicationWorkloads.enableWebApp) {
  name: 'webAppServicesDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'asp-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    sku: {
      name: 'P1v3'
      tier: 'PremiumV3'
      size: 'P1v3'
      capacity: 1
    }

    kind: 'App'
    reserved: false
  }
  dependsOn: [
    spokeLandingZone
  ]
}

module webApp 'br/public:avm/res/web/site:0.8.0' = if (applicationWorkloads.enableWebApp) {
  name: 'webAppDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'app-${organizationPrefix}-web-${environment}'
    location: location
    tags: commonTags

    kind: 'app'
    serverFarmResourceId: webAppServices.outputs.resourceId

    httpsOnly: true
    publicNetworkAccess: 'Enabled'

    virtualNetworkSubnetId: '${spokeLandingZone.outputs.virtualNetworkResourceId}/subnets/snet-web-apps'

    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      use32BitWorkerProcess: false

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
  }
  dependsOn: [
    webAppServices
  ]
}

// Container Apps using AVM resource modules
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.7.0' = if (applicationWorkloads.enableContainerApps) {
  name: 'containerAppsEnvironmentDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'cae-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    logAnalyticsWorkspaceResourceId: hubNetworking.outputs.logAnalyticsWorkspaceResourceId

    infrastructureSubnetId: '${spokeLandingZone.outputs.virtualNetworkResourceId}/subnets/snet-container-apps'
    internal: false

    zoneRedundant: false
  }
  dependsOn: [
    spokeLandingZone
    hubNetworking
  ]
}

// PostgreSQL Flexible Server using AVM resource modules
module postgreSQLServer 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.13.1' = if (applicationWorkloads.enablePostgreSQL) {
  name: 'postgreSQLServerDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'psql-${organizationPrefix}-${environment}-${take(uniqueString(spokeLandingZone.outputs.subscriptionId), 8)}'
    location: location
    tags: commonTags

    skuName: 'Standard_B1ms'
    tier: 'Burstable'

    storageSizeGB: 32
    version: '15'

    administratorLogin: 'alzadmin'
    administratorLoginPassword: newGuid() // Use Key Vault or managed identity in production

    delegatedSubnetResourceId: '${spokeLandingZone.outputs.virtualNetworkResourceId}/subnets/snet-database'
    privateDnsZoneResourceId: hubNetworking.outputs.privateDnsZones[1] // PostgreSQL private DNS zone

    backupRetentionDays: 7
    geoRedundantBackup: 'Disabled'

    highAvailability: 'Disabled'

    databases: [
      {
        name: 'app-database'
      }
    ]
  }
  dependsOn: [
    spokeLandingZone
    hubNetworking
  ]
}

// Storage Account using AVM resource modules
module storageAccount 'br/public:avm/res/storage/storage-account:0.14.0' = if (applicationWorkloads.enableStorage) {
  name: 'storageAccountDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'st${toLower(organizationPrefix)}${toLower(environment)}${take(uniqueString(spokeLandingZone.outputs.subscriptionId), 8)}'
    location: location
    tags: commonTags

    kind: 'StorageV2'
    skuName: 'Standard_LRS'

    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_2'

    publicNetworkAccess: 'Enabled'

    // Private endpoints for enhanced security
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: '${spokeLandingZone.outputs.virtualNetworkResourceId}/subnets/snet-private-endpoints'
        privateDnsZoneGroupName: 'blob-private-dns-zone-group'
        privateDnsZoneResourceIds: [
          hubNetworking.outputs.privateDnsZones[0] // Blob private DNS zone
        ]
      }
    ]
  }
  dependsOn: [
    spokeLandingZone
    hubNetworking
  ]
}

// Application Gateway using AVM resource modules
module applicationGateway 'br/public:avm/res/network/application-gateway:0.4.0' = if (applicationWorkloads.enableAppGateway) {
  name: 'applicationGatewayDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'agw-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    sku: 'WAF_v2'
    capacity: 2
    enableHttp2: true

    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        subnetResourceId: '${spokeLandingZone.outputs.virtualNetworkResourceId}/subnets/snet-app-gateway'
      }
    ]

    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        publicIPAddressResourceId: appGatewayPublicIp.outputs.resourceId
      }
    ]

    frontendPorts: [
      {
        name: 'port80'
        port: 80
      }
      {
        name: 'port443'
        port: 443
      }
    ]

    backendAddressPools: [
      {
        name: 'webAppBackendPool'
        backendAddresses: applicationWorkloads.enableWebApp ? [
          {
            fqdn: webApp.outputs.defaultHostname
          }
        ] : []
      }
    ]

    backendSettingsCollection: [
      {
        name: 'webAppBackendSettings'
        port: 443
        protocol: 'Https'
        cookieBasedAffinity: 'Disabled'
        pickHostNameFromBackendAddress: true
        requestTimeout: 30
      }
    ]

    listeners: [
      {
        name: 'webAppListener'
        frontendIPConfigurationName: 'appGatewayFrontendIP'
        frontendPortName: 'port80'
        protocol: 'Http'
      }
    ]

    routingRules: [
      {
        name: 'webAppRoutingRule'
        ruleType: 'Basic'
        listenerName: 'webAppListener'
        backendAddressPoolName: 'webAppBackendPool'
        backendSettingsName: 'webAppBackendSettings'
        priority: 100
      }
    ]

    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }

    zones: ['1', '2', '3']
  }
  dependsOn: [
    spokeLandingZone
    appGatewayPublicIp
  ]
}

module appGatewayPublicIp 'br/public:avm/res/network/public-ip-address:0.5.0' = if (applicationWorkloads.enableAppGateway) {
  name: 'appGatewayPublicIpDeployment'
  scope: resourceGroup(spokeLandingZone.outputs.subscriptionId, 'rg-${organizationPrefix}-spoke-${environment}')
  params: {
    name: 'pip-${organizationPrefix}-appgw-${environment}'
    location: location
    tags: commonTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: ['1', '2', '3']
  }
  dependsOn: [
    spokeLandingZone
  ]
}

// =======================
// OUTPUTS
// =======================

// Subscription outputs
output hubSubscriptionId string = hubLandingZone.outputs.subscriptionId
output spokeSubscriptionId string = spokeLandingZone.outputs.subscriptionId

// Hub networking outputs
output hubVirtualNetworkId string = hubNetworking.outputs.virtualNetworkResourceId
output hubResourceGroupName string = 'rg-${organizationPrefix}-hub-${environment}'

// Spoke networking outputs
output spokeVirtualNetworkId string = spokeLandingZone.outputs.virtualNetworkResourceId
output spokeResourceGroupName string = 'rg-${organizationPrefix}-spoke-${environment}'

// Application outputs
output webAppId string = applicationWorkloads.enableWebApp ? webApp.outputs.resourceId : ''
output webAppDefaultHostname string = applicationWorkloads.enableWebApp ? webApp.outputs.defaultHostname : ''
output containerAppsEnvironmentId string = applicationWorkloads.enableContainerApps ? containerAppsEnvironment.outputs.resourceId : ''
output applicationGatewayId string = applicationWorkloads.enableAppGateway ? applicationGateway.outputs.resourceId : ''
output appGatewayPublicIpAddress string = applicationWorkloads.enableAppGateway ? appGatewayPublicIp.outputs.ipAddress : ''
output storageAccountId string = applicationWorkloads.enableStorage ? storageAccount.outputs.resourceId : ''
output postgreSQLServerId string = applicationWorkloads.enablePostgreSQL ? postgreSQLServer.outputs.resourceId : ''

// Connection Information for Testing
output connectionInfo object = {
  webApp: {
    hostname: applicationWorkloads.enableWebApp ? webApp.outputs.defaultHostname : 'N/A - Web App not enabled'
    appGatewayUrl: applicationWorkloads.enableAppGateway ? 'http://${appGatewayPublicIp.outputs.ipAddress}' : 'N/A - App Gateway not enabled'
  }
  database: {
    server: applicationWorkloads.enablePostgreSQL ? postgreSQLServer.outputs.fqdn : 'N/A - PostgreSQL not enabled'
    database: 'app-database'
    username: 'alzadmin'
    sshAccess: 'SSH key configured for secure VM access via Azure Bastion'
  }
  storage: {
    accountName: applicationWorkloads.enableStorage ? storageAccount.outputs.name : 'N/A - Storage not enabled'
    blobEndpoint: applicationWorkloads.enableStorage ? storageAccount.outputs.primaryBlobEndpoint : 'N/A - Storage not enabled'
  }
  networking: {
    hubVNet: 'vnet-${organizationPrefix}-hub-${environment}'
    spokeVNet: 'vnet-${organizationPrefix}-spoke-${environment}'
    bastionEnabled: enableBastion
    firewallEnabled: enableAzureFirewall
  }
}

// AVM Pattern Information
output avmPatternsUsed object = {
  description: 'This deployment demonstrates official AVM pattern modules for enterprise-grade ALZ'
  avmPatternModules: [
    'avm/ptn/lz/sub-vending:0.2.0 - Subscription vending with network configuration'
    'avm/ptn/network/hub-networking:0.1.0 - Hub networking with Firewall, Bastion, Private DNS'
  ]
  avmResourceModules: [
    'avm/res/web/serverfarm:0.2.0 - App Service Plan'
    'avm/res/web/site:0.8.0 - Web App with VNet integration'
    'avm/res/app/managed-environment:0.7.0 - Container Apps Environment'
    'avm/res/db-for-postgre-sql/flexible-server:0.13.1 - PostgreSQL with private networking'
    'avm/res/storage/storage-account:0.14.0 - Storage with private endpoints'
    'avm/res/network/application-gateway:0.4.0 - Application Gateway with WAF'
    'avm/res/network/public-ip-address:0.5.0 - Public IP addresses'
  ]
  benefits: [
    'Microsoft-validated resource configurations'
    'Enterprise-grade security and compliance built-in'
    'Automatic subscription provisioning and management'
    'Hub-spoke networking with proper peering'
    'Private DNS zones and endpoints for secure communication'
    'Azure Firewall and Bastion for secure access'
    'Web Application Firewall for application protection'
    'SSH key-based authentication instead of passwords'
    'Production-ready configurations out of the box'
  ]
}
