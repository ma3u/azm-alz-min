metadata name = 'Spoke VNet - Application Workloads'
metadata description = 'Deploys spoke VNet with application services: Web Apps, Container Apps, PostgreSQL, Storage, Application Gateway using Azure Verified Modules'

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

@description('Spoke VNet address prefix')
param spokeVnetAddressPrefix string = '10.1.0.0/16'

@description('Hub VNet ID for peering')
param hubVnetId string

@description('Azure Firewall private IP for routing')
param azureFirewallPrivateIp string

@description('Enable Application Gateway deployment')
param enableAppGateway bool = true

@description('Enable Web Apps deployment')
param enableWebApps bool = true

@description('Enable Container Apps deployment')
param enableContainerApps bool = true

@description('Enable PostgreSQL deployment')
param enablePostgreSQL bool = true

@description('Enable Storage Account deployment')
param enableStorage bool = true

@description('Database administrator username')
@secure()
param dbAdministratorLogin string = 'alzadmin'

@description('Database administrator password')
@secure()
param dbAdministratorPassword string

// =======================
// VARIABLES
// =======================

var commonTags = {
  Environment: environment
  Project: 'Azure-Landing-Zone'
  Pattern: 'Hub-Spoke'
  Component: 'Spoke-Network'
  IaC: 'Bicep-AVM'
  DeployedBy: 'Warp-AI-Assistant'
}

// Naming convention
var namingPrefix = '${organizationPrefix}-spoke-${environment}'

// Subnet definitions
var subnets = [
  {
    name: 'snet-appgateway'
    addressPrefix: '10.1.1.0/24'
    networkSecurityGroup: {
      id: appGatewayNsg.outputs.resourceId
    }
  }
  {
    name: 'snet-webapps'
    addressPrefix: '10.1.2.0/24'
    delegations: [
      {
        name: 'Microsoft.Web.serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    networkSecurityGroup: {
      id: webAppsNsg.outputs.resourceId
    }
  }
  {
    name: 'snet-containerapps'
    addressPrefix: '10.1.3.0/24'
    delegations: [
      {
        name: 'Microsoft.App.environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
    networkSecurityGroup: {
      id: containerAppsNsg.outputs.resourceId
    }
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
    networkSecurityGroup: {
      id: databaseNsg.outputs.resourceId
    }
  }
  {
    name: 'snet-privateendpoints'
    addressPrefix: '10.1.11.0/24'
    networkSecurityGroup: {
      id: privateEndpointsNsg.outputs.resourceId
    }
  }
  {
    name: 'snet-storage'
    addressPrefix: '10.1.12.0/24'
    networkSecurityGroup: {
      id: storageNsg.outputs.resourceId
    }
  }
]

// =======================
// NETWORK SECURITY GROUPS
// =======================

// Application Gateway NSG
module appGatewayNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'appGatewayNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-appgateway'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAppGatewayInfrastructure'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Web Apps NSG
module webAppsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'webAppsNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-webapps'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowAppGatewayInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: '10.1.1.0/24' // App Gateway subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Container Apps NSG
module containerAppsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'containerAppsNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-containerapps'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowContainerAppsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
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

// Database NSG
module databaseNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'databaseNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-database'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowPostgreSQLFromApps'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5432'
          sourceAddressPrefixes: ['10.1.2.0/24', '10.1.3.0/24'] // Web Apps and Container Apps subnets
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Private Endpoints NSG
module privateEndpointsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'privateEndpointsNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-privateendpoints'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowPrivateEndpointsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
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

// Storage NSG
module storageNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'storageNsgDeployment'
  params: {
    name: 'nsg-${namingPrefix}-storage'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowStorageFromApps'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefixes: ['10.1.2.0/24', '10.1.3.0/24'] // Web Apps and Container Apps subnets
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
// SPOKE VIRTUAL NETWORK
// =======================

module spokeVnet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'spokeVnetDeployment'
  params: {
    name: 'vnet-${namingPrefix}'
    location: location
    addressPrefixes: [spokeVnetAddressPrefix]
    tags: commonTags

    subnets: subnets
  }
  dependsOn: [
    appGatewayNsg
    webAppsNsg
    containerAppsNsg
    databaseNsg
    privateEndpointsNsg
    storageNsg
  ]
}

// =======================
// VNET PEERING
// =======================

// Peering from spoke to hub
module spokeToHubPeering 'br/public:avm/res/network/virtual-network-peering:0.1.1' = {
  name: 'spokeToHubPeeringDeployment'
  params: {
    localVnetName: spokeVnet.outputs.name
    remoteVirtualNetworkId: hubVnetId
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
  }
  dependsOn: [
    spokeVnet
  ]
}

// =======================
// ROUTE TABLES
// =======================

// Route table for forcing traffic through Azure Firewall
module spokeRouteTable 'br/public:avm/res/network/route-table:0.2.2' = {
  name: 'spokeRouteTableDeployment'
  params: {
    name: 'rt-${namingPrefix}-spoke'
    location: location
    tags: commonTags

    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIp
        }
      }
      {
        name: 'LocalVNetRoute'
        properties: {
          addressPrefix: spokeVnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

// =======================
// STORAGE ACCOUNT
// =======================

module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = if (enableStorage) {
  name: 'storageAccountDeployment'
  params: {
    name: 'st${organizationPrefix}spoke${environment}${take(uniqueString(resourceGroup().id), 8)}'
    location: location
    tags: commonTags

    kind: 'StorageV2'
    skuName: 'Standard_LRS'

    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_2'

    publicNetworkAccess: 'Disabled'

    privateEndpoints: [
      {
        subnetResourceId: '${spokeVnet.outputs.resourceId}/subnets/snet-privateendpoints'
        service: 'blob'
        privateDnsZoneResourceIds: [privateDnsZoneBlob.outputs.resourceId]
        tags: commonTags
      }
    ]
  }
  dependsOn: [
    spokeVnet
    privateDnsZoneBlob
  ]
}

// =======================
// WEB APPS
// =======================

// App Service Plan
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = if (enableWebApps) {
  name: 'appServicePlanDeployment'
  params: {
    name: 'asp-${namingPrefix}'
    location: location
    tags: commonTags

    sku: {
      name: 'P1v3'
      tier: 'PremiumV3'
      size: 'P1v3'
      capacity: 1
    }

    kind: 'app'
  }
}

// Web App
module webApp 'br/public:avm/res/web/site:0.3.7' = if (enableWebApps) {
  name: 'webAppDeployment'
  params: {
    name: 'app-${namingPrefix}-web'
    location: location
    tags: commonTags

    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId

    httpsOnly: true
    publicNetworkAccess: 'Disabled'

    virtualNetworkSubnetId: '${spokeVnet.outputs.resourceId}/subnets/snet-webapps'

    privateEndpoints: [
      {
        subnetResourceId: '${spokeVnet.outputs.resourceId}/subnets/snet-privateendpoints'
        service: 'sites'
        privateDnsZoneResourceIds: [privateDnsZoneWebSites.outputs.resourceId]
        tags: commonTags
      }
    ]

    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      use32BitWorkerProcess: false
      webSocketsEnabled: false

      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.name};SecretName=appinsights-key)'
        }
      ]
    }
  }
  dependsOn: [
    spokeVnet
    appServicePlan
    privateDnsZoneWebSites
  ]
}

// =======================
// CONTAINER APPS
// =======================

// Log Analytics Workspace for Container Apps
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.3.4' = if (enableContainerApps) {
  name: 'logAnalyticsDeployment'
  params: {
    name: 'log-${namingPrefix}-containerApps'
    location: location
    tags: commonTags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// Container Apps Environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = if (enableContainerApps) {
  name: 'containerAppsEnvironmentDeployment'
  params: {
    name: 'cae-${namingPrefix}'
    location: location
    tags: commonTags

    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId

    infrastructureSubnetId: '${spokeVnet.outputs.resourceId}/subnets/snet-containerapps'
    internal: true

    zoneRedundant: false
  }
  dependsOn: [
    spokeVnet
    logAnalyticsWorkspace
  ]
}

// Container App Job
module containerAppJob 'br/public:avm/res/app/job:0.1.1' = if (enableContainerApps) {
  name: 'containerAppJobDeployment'
  params: {
    name: 'caj-${namingPrefix}-batch'
    location: location
    tags: commonTags

    managedEnvironmentResourceId: containerAppsEnvironment.outputs.resourceId

    containers: [
      {
        name: 'batch-processor'
        image: 'mcr.microsoft.com/azure-cli:latest'
        resources: {
          cpu: '0.25'
          memory: '0.5Gi'
        }
        command: ['/bin/sh']
        args: ['-c', 'echo "Processing batch job in ${environment} environment"; sleep 30; echo "Job completed"']
      }
    ]

    scheduleTriggerConfig: {
      cronExpression: '0 */6 * * *' // Every 6 hours
      parallelism: 1
      completions: 1
    }

    replicaTimeout: 300
    replicaRetryLimit: 3
  }
  dependsOn: [
    containerAppsEnvironment
  ]
}

// =======================
// POSTGRESQL FLEXIBLE SERVER
// =======================

module postgreSQLServer 'br/public:avm/res/db-for-postgresql/flexible-server:0.1.4' = if (enablePostgreSQL) {
  name: 'postgreSQLServerDeployment'
  params: {
    name: 'psql-${namingPrefix}-${take(uniqueString(resourceGroup().id), 8)}'
    location: location
    tags: commonTags

    skuName: 'Standard_B1ms'
    tier: 'Burstable'

    storageSizeGB: 32
    version: '15'

    administratorLogin: dbAdministratorLogin
    administratorLoginPassword: dbAdministratorPassword

    delegatedSubnetResourceId: '${spokeVnet.outputs.resourceId}/subnets/snet-database'
    privateDnsZoneResourceId: privateDnsZonePostgreSQL.outputs.resourceId

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
    spokeVnet
    privateDnsZonePostgreSQL
  ]
}

// =======================
// APPLICATION GATEWAY v2
// =======================

// Public IP for Application Gateway
module appGatewayPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableAppGateway) {
  name: 'appGatewayPublicIpDeployment'
  params: {
    name: 'pip-${namingPrefix}-appgateway'
    location: location
    tags: commonTags
    publicIpAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: ['1', '2', '3']
  }
}

// Application Gateway
module applicationGateway 'br/public:avm/res/network/application-gateway:0.1.2' = if (enableAppGateway) {
  name: 'applicationGatewayDeployment'
  params: {
    name: 'agw-${namingPrefix}'
    location: location
    tags: commonTags

    sku: 'WAF_v2'
    capacity: 2
    enableHttp2: true

    subnetResourceId: '${spokeVnet.outputs.resourceId}/subnets/snet-appgateway'

    frontendIPConfigurations: [
      {
        name: 'frontendIPConfig'
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
        backendAddresses: [
          {
            fqdn: enableWebApps ? webApp.outputs.defaultHostname : ''
          }
        ]
      }
    ]

    backendHttpSettingsCollection: [
      {
        name: 'webAppBackendSettings'
        port: 443
        protocol: 'Https'
        cookieBasedAffinity: 'Disabled'
        pickHostNameFromBackendAddress: true
        requestTimeout: 30
      }
    ]

    httpListeners: [
      {
        name: 'webAppListener'
        frontendIPConfigurationName: 'frontendIPConfig'
        frontendPortName: 'port80'
        protocol: 'Http'
      }
    ]

    requestRoutingRules: [
      {
        name: 'webAppRoutingRule'
        ruleType: 'Basic'
        httpListenerName: 'webAppListener'
        backendAddressPoolName: 'webAppBackendPool'
        backendHttpSettingsName: 'webAppBackendSettings'
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
    spokeVnet
    appGatewayPublicIp
    webApp
  ]
}

// =======================
// KEY VAULT FOR SECRETS
// =======================

module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: 'keyVaultDeployment'
  params: {
    name: 'kv-${namingPrefix}-${take(uniqueString(resourceGroup().id), 8)}'
    location: location
    tags: commonTags

    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: environment == 'prod'
    softDeleteRetentionInDays: 90
    sku: 'standard'

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }

    privateEndpoints: [
      {
        subnetResourceId: '${spokeVnet.outputs.resourceId}/subnets/snet-privateendpoints'
        service: 'vault'
        privateDnsZoneResourceIds: [privateDnsZoneKeyVault.outputs.resourceId]
        tags: commonTags
      }
    ]
  }
  dependsOn: [
    spokeVnet
    privateDnsZoneKeyVault
  ]
}

// =======================
// PRIVATE DNS ZONES
// =======================

module privateDnsZoneBlob 'br/public:avm/res/network/private-dns-zone:0.2.4' = if (enableStorage) {
  name: 'privateDnsZoneBlobDeployment'
  params: {
    name: 'privatelink.blob.core.windows.net'
    tags: commonTags

    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: spokeVnet.outputs.resourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: hubVnetId
        registrationEnabled: false
      }
    ]
  }
  dependsOn: [
    spokeVnet
  ]
}

module privateDnsZoneWebSites 'br/public:avm/res/network/private-dns-zone:0.2.4' = if (enableWebApps) {
  name: 'privateDnsZoneWebSitesDeployment'
  params: {
    name: 'privatelink.azurewebsites.net'
    tags: commonTags

    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: spokeVnet.outputs.resourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: hubVnetId
        registrationEnabled: false
      }
    ]
  }
  dependsOn: [
    spokeVnet
  ]
}

module privateDnsZonePostgreSQL 'br/public:avm/res/network/private-dns-zone:0.2.4' = if (enablePostgreSQL) {
  name: 'privateDnsZonePostgreSQLDeployment'
  params: {
    name: 'privatelink.postgres.database.azure.com'
    tags: commonTags

    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: spokeVnet.outputs.resourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: hubVnetId
        registrationEnabled: false
      }
    ]
  }
  dependsOn: [
    spokeVnet
  ]
}

module privateDnsZoneKeyVault 'br/public:avm/res/network/private-dns-zone:0.2.4' = {
  name: 'privateDnsZoneKeyVaultDeployment'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    tags: commonTags

    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: spokeVnet.outputs.resourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: hubVnetId
        registrationEnabled: false
      }
    ]
  }
  dependsOn: [
    spokeVnet
  ]
}

// =======================
// OUTPUTS
// =======================

// Network outputs
output spokeVnetId string = spokeVnet.outputs.resourceId
output spokeVnetName string = spokeVnet.outputs.name
output spokeVnetAddressSpace array = spokeVnet.outputs.addressPrefixes

// Application Gateway outputs
output applicationGatewayId string = enableAppGateway ? applicationGateway.outputs.resourceId : ''
output appGatewayPublicIpAddress string = enableAppGateway ? appGatewayPublicIp.outputs.ipAddress : ''

// Web App outputs
output webAppId string = enableWebApps ? webApp.outputs.resourceId : ''
output webAppDefaultHostname string = enableWebApps ? webApp.outputs.defaultHostname : ''
output appServicePlanId string = enableWebApps ? appServicePlan.outputs.resourceId : ''

// Container Apps outputs
output containerAppsEnvironmentId string = enableContainerApps ? containerAppsEnvironment.outputs.resourceId : ''
output containerAppJobId string = enableContainerApps ? containerAppJob.outputs.resourceId : ''

// Storage outputs
output storageAccountId string = enableStorage ? storageAccount.outputs.resourceId : ''
output storageAccountName string = enableStorage ? storageAccount.outputs.name : ''

// Database outputs
output postgreSQLServerId string = enablePostgreSQL ? postgreSQLServer.outputs.resourceId : ''
output postgreSQLServerFqdn string = enablePostgreSQL ? postgreSQLServer.outputs.fqdn : ''

// Key Vault outputs
output keyVaultId string = keyVault.outputs.resourceId
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// Subnet outputs
output appGatewaySubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-appgateway'
output webAppsSubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-webapps'
output containerAppsSubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-containerapps'
output databaseSubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-database'
output privateEndpointsSubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-privateendpoints'
output storageSubnetId string = '${spokeVnet.outputs.resourceId}/subnets/snet-storage'

// Common outputs
output location string = location
output environment string = environment
output tags object = commonTags
