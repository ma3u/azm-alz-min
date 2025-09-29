metadata name = 'Azure Landing Zone - Sandbox Hub-Spoke with AVM Patterns'
metadata description = 'Simplified ALZ Hub-Spoke using AVM patterns for single subscription sandbox testing'

targetScope = 'subscription'

// =======================
// PARAMETERS
// =======================

@description('Primary Azure region for deployment')
param location string = deployment().location

@description('Environment name for resource tagging')
@allowed(['sandbox', 'dev', 'test'])
param environment string = 'sandbox'

@description('Organization prefix for naming')
param organizationPrefix string = 'alz'

@description('Hub Virtual Network address space')
param hubVnetAddressSpace string = '10.0.0.0/16'

@description('Spoke Virtual Network address space')
param spokeVnetAddressSpace string = '10.1.0.0/16'


@description('Enable Azure Bastion in hub')
param enableBastion bool = false

@description('SSH public key for secure VM access via Bastion')
param sshPublicKey string = loadTextContent('../../.secrets/azure-alz-key.pub')

@description('Database administrator login')
param dbAdministratorLogin string = 'alzadmin'

@description('Database administrator password - use Azure Key Vault or managed identity in production')
@secure()
param dbAdministratorPassword string = newGuid()

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
  Pattern: 'ALZ-HubSpoke-AVM-Sandbox'
  IaC: 'Bicep-AVM-Patterns'
  DeployedBy: 'Warp-AI-Sandbox'
  Purpose: 'AVM-Testing'
}

// Resource group names
var hubResourceGroupName = 'rg-${organizationPrefix}-hub-${environment}'
var spokeResourceGroupName = 'rg-${organizationPrefix}-spoke-${environment}'

// =======================
// RESOURCE GROUPS
// =======================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: hubResourceGroupName
  location: location
  tags: union(commonTags, {
    Component: 'Hub-Network'
  })
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: spokeResourceGroupName
  location: location
  tags: union(commonTags, {
    Component: 'Spoke-Network'
  })
}

// =======================
// HUB NETWORKING WITH AVM PATTERNS
// =======================

// Hub Virtual Network using AVM resource module
module hubVirtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'hubVirtualNetworkDeployment'
  scope: hubResourceGroup
  params: {
    name: 'vnet-${organizationPrefix}-hub-${environment}'
    location: location
    addressPrefixes: [hubVnetAddressSpace]
    tags: commonTags

    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroup: enableBastion ? {
          id: bastionNsg.outputs.resourceId
        } : {}
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.2.0/24'
      }
      {
        name: 'snet-shared-services'
        addressPrefix: '10.0.3.0/24'
        networkSecurityGroup: {
          id: hubSharedNsg.outputs.resourceId
        }
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.100.0/24'
      }
    ]
  }
  dependsOn: [
    hubSharedNsg
  ]
}

// Hub Network Security Groups
module bastionNsg 'br/public:avm/res/network/network-security-group:0.1.3' = if (enableBastion) {
  name: 'bastionNsgDeployment'
  scope: hubResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-hub-bastion-${environment}'
    location: location
    tags: commonTags

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
}

module hubSharedNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'hubSharedNsgDeployment'
  scope: hubResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-hub-shared-${environment}'
    location: location
    tags: commonTags

    securityRules: [
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
}

// Azure Bastion (optional for sandbox)
module azureBastion 'br/public:avm/res/network/bastion-host:0.3.0' = if (enableBastion) {
  name: 'azureBastionDeployment'
  scope: hubResourceGroup
  params: {
    name: 'bas-${organizationPrefix}-hub-${environment}'
    location: location
    tags: commonTags

    virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId

    publicIPAddressObject: {
      publicIPAddresses: [
        {
          name: 'pip-${organizationPrefix}-bastion-${environment}'
          publicIPAddressResourceId: bastionPublicIp.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    hubVirtualNetwork
    bastionPublicIp
  ]
}

module bastionPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (enableBastion) {
  name: 'bastionPublicIpDeployment'
  scope: hubResourceGroup
  params: {
    name: 'pip-${organizationPrefix}-bastion-${environment}'
    location: location
    tags: commonTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

// =======================
// SPOKE NETWORKING WITH AVM PATTERNS
// =======================

// Spoke Virtual Network using AVM resource module
module spokeVirtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'spokeVirtualNetworkDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'vnet-${organizationPrefix}-spoke-${environment}'
    location: location
    addressPrefixes: [spokeVnetAddressSpace]
    tags: commonTags

    subnets: [
      {
        name: 'snet-app-gateway'
        addressPrefix: '10.1.1.0/24'
        networkSecurityGroup: {
          id: appGatewayNsg.outputs.resourceId
        }
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
        networkSecurityGroup: {
          id: webAppsNsg.outputs.resourceId
        }
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
        name: 'snet-private-endpoints'
        addressPrefix: '10.1.11.0/24'
        networkSecurityGroup: {
          id: privateEndpointsNsg.outputs.resourceId
        }
      }
    ]
  }
  dependsOn: [
    appGatewayNsg
    webAppsNsg
    containerAppsNsg
    databaseNsg
    privateEndpointsNsg
  ]
}

// Spoke Network Security Groups
module appGatewayNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'appGatewayNsgDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-spoke-appgw-${environment}'
    location: location
    tags: commonTags

    securityRules: [
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
}

module webAppsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'webAppsNsgDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-spoke-webapp-${environment}'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowAppGatewayInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: '10.1.1.0/24'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module containerAppsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'containerAppsNsgDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-spoke-containerapp-${environment}'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module databaseNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'databaseNsgDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-spoke-database-${environment}'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowPostgreSQLFromApps'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5432'
          sourceAddressPrefixes: ['10.1.2.0/24', '10.1.3.0/24']
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module privateEndpointsNsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'privateEndpointsNsgDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nsg-${organizationPrefix}-spoke-pe-${environment}'
    location: location
    tags: commonTags

    securityRules: [
      {
        name: 'AllowPrivateEndpointsInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// =======================
// VNET PEERING (using native ARM resources for simplicity)
// =======================

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  name: '${hubVirtualNetwork.outputs.name}/hub-to-spoke-peering'
  scope: hubResourceGroup
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVirtualNetwork.outputs.resourceId
    }
  }
  dependsOn: [
    hubVirtualNetwork
    spokeVirtualNetwork
  ]
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  name: '${spokeVirtualNetwork.outputs.name}/spoke-to-hub-peering'
  scope: spokeResourceGroup
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVirtualNetwork.outputs.resourceId
    }
  }
  dependsOn: [
    hubVirtualNetwork
    spokeVirtualNetwork
  ]
}

// =======================
// APPLICATION SERVICES WITH AVM
// =======================

// Web App Service Plan using AVM
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = if (applicationWorkloads.enableWebApp) {
  name: 'appServicePlanDeployment'
  scope: spokeResourceGroup
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
  }
}

// Web App using AVM
module webApp 'br/public:avm/res/web/site:0.3.7' = if (applicationWorkloads.enableWebApp) {
  name: 'webAppDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'app-${organizationPrefix}-web-${environment}'
    location: location
    tags: commonTags

    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId

    httpsOnly: true
    publicNetworkAccess: 'Enabled' // Simplified for sandbox

    virtualNetworkSubnetId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-web-apps'

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
}

// Container Apps Environment using AVM
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = if (applicationWorkloads.enableContainerApps) {
  name: 'containerAppsEnvironmentDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'cae-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId

    infrastructureSubnetId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-container-apps'
    internal: false // Simplified for sandbox

    zoneRedundant: false
  }
  dependsOn: [
    containerAppsEnvironment
  ]
}

// Container App Job using AVM
module containerAppJob 'br/public:avm/res/app/job:0.1.1' = if (applicationWorkloads.enableContainerApps) {
  name: 'containerAppJobDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'caj-${organizationPrefix}-batch-${environment}'
    location: location
    tags: commonTags

    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    triggerType: 'Schedule'

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
      cronExpression: '0 */6 * * *'
      parallelism: 1
      completions: 1
    }

    replicaTimeout: 300
    replicaRetryLimit: 3
  }
}

// PostgreSQL Flexible Server using AVM
module postgreSQLServer 'br/public:avm/res/db-for-postgresql/flexible-server:0.2.0' = if (applicationWorkloads.enablePostgreSQL) {
  name: 'postgreSQLServerDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'psql-${organizationPrefix}-${environment}-${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    tags: commonTags

    skuName: 'Standard_B1ms'
    tier: 'Burstable'

    storageSizeGB: 32
    version: '15'

    administratorLogin: 'alzadmin'
    administratorLoginPassword: dbAdministratorPassword

    delegatedSubnetResourceId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-database'
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
    spokeVirtualNetwork
    privateDnsZonePostgreSQL
  ]
}

// Storage Account using AVM
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = if (applicationWorkloads.enableStorage) {
  name: 'storageAccountDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'st${organizationPrefix}spoke${environment}${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    tags: commonTags

    kind: 'StorageV2'
    skuName: 'Standard_LRS'

    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_2'

    publicNetworkAccess: 'Enabled' // Simplified for sandbox
  }
}

// Application Gateway using AVM
module applicationGateway 'br/public:avm/res/network/application-gateway:0.3.0' = if (applicationWorkloads.enableAppGateway) {
  name: 'applicationGatewayDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'agw-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    sku: 'WAF_v2'
    capacity: 2
    enableHttp2: true

    subnetResourceId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-app-gateway'

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
        backendAddresses: applicationWorkloads.enableWebApp ? [
          {
            fqdn: webApp.outputs.defaultHostname
          }
        ] : []
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
    spokeVirtualNetwork
    appGatewayPublicIp
  ]
}

module appGatewayPublicIp 'br/public:avm/res/network/public-ip-address:0.2.3' = if (applicationWorkloads.enableAppGateway) {
  name: 'appGatewayPublicIpDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'pip-${organizationPrefix}-appgw-${environment}'
    location: location
    tags: commonTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: ['1', '2', '3']
  }
}

// =======================
// SHARED SERVICES
// =======================

// Log Analytics Workspace using AVM
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.3.4' = {
  name: 'logAnalyticsDeployment'
  scope: hubResourceGroup
  params: {
    name: 'log-${organizationPrefix}-hub-${environment}'
    location: location
    tags: commonTags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// Private DNS Zones using AVM
module privateDnsZonePostgreSQL 'br/public:avm/res/network/private-dns-zone:0.2.4' = if (applicationWorkloads.enablePostgreSQL) {
  name: 'privateDnsZonePostgreSQLDeployment'
  scope: hubResourceGroup
  params: {
    name: 'privatelink.postgres.database.azure.com'
    tags: commonTags

    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
      {
        virtualNetworkResourceId: spokeVirtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

// =======================
// OUTPUTS
// =======================

// Resource Group outputs
output hubResourceGroupName string = hubResourceGroup.name
output spokeResourceGroupName string = spokeResourceGroup.name

// Hub networking outputs
output hubVirtualNetworkId string = hubVirtualNetwork.outputs.resourceId
output hubVirtualNetworkName string = hubVirtualNetwork.outputs.name
output bastionId string = enableBastion ? azureBastion.outputs.resourceId : ''

// Spoke networking outputs
output spokeVirtualNetworkId string = spokeVirtualNetwork.outputs.resourceId
output spokeVirtualNetworkName string = spokeVirtualNetwork.outputs.name

// Application outputs
output webAppId string = applicationWorkloads.enableWebApp ? webApp.outputs.resourceId : ''
output webAppDefaultHostname string = applicationWorkloads.enableWebApp ? webApp.outputs.defaultHostname : ''
output containerAppsEnvironmentId string = applicationWorkloads.enableContainerApps ? containerAppsEnvironment.outputs.resourceId : ''
output containerAppJobId string = applicationWorkloads.enableContainerApps ? containerAppJob.outputs.resourceId : ''
output applicationGatewayId string = applicationWorkloads.enableAppGateway ? applicationGateway.outputs.resourceId : ''
output appGatewayPublicIpAddress string = applicationWorkloads.enableAppGateway ? appGatewayPublicIp.outputs.ipAddress : ''
output storageAccountId string = applicationWorkloads.enableStorage ? storageAccount.outputs.resourceId : ''
output storageAccountName string = applicationWorkloads.enableStorage ? storageAccount.outputs.name : ''
output postgreSQLServerId string = applicationWorkloads.enablePostgreSQL ? postgreSQLServer.outputs.resourceId : ''
output postgreSQLServerFqdn string = applicationWorkloads.enablePostgreSQL ? postgreSQLServer.outputs.fqdn : ''

// Log Analytics outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.resourceId
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name

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
  }
  storage: {
    accountName: applicationWorkloads.enableStorage ? storageAccount.outputs.name : 'N/A - Storage not enabled'
    blobEndpoint: applicationWorkloads.enableStorage ? 'https://${storageAccount.outputs.name}.blob.${environment().suffixes.storage}' : 'N/A - Storage not enabled'
  }
  networking: {
    hubVNet: hubVirtualNetwork.outputs.name
    spokeVNet: spokeVirtualNetwork.outputs.name
  }
}

// AVM Pattern Information
output avmPatternsUsed object = {
  description: 'This sandbox deployment demonstrates AVM resource modules in hub-spoke pattern'
  avmModulesUsed: [
    'avm/res/network/virtual-network:0.1.6'
    'avm/res/network/network-security-group:0.1.3'
    'avm/res/network/virtual-network-peering:0.1.1'
    'avm/res/network/bastion-host:0.1.2'
    'avm/res/network/public-ip-address:0.2.3'
    'avm/res/web/serverfarm:0.1.1'
    'avm/res/web/site:0.3.7'
    'avm/res/app/managed-environment:0.4.5'
    'avm/res/app/job:0.1.1'
    'avm/res/db-for-postgresql/flexible-server:0.1.4'
    'avm/res/storage/storage-account:0.9.1'
    'avm/res/network/application-gateway:0.1.2'
    'avm/res/operational-insights/workspace:0.3.4'
    'avm/res/network/private-dns-zone:0.2.4'
  ]
  benefits: [
    'Microsoft-validated resource configurations'
    'Consistent parameter schema across resources'
    'Built-in security and compliance best practices'
    'Regular updates and maintenance by Microsoft'
    'Production-ready configurations out of the box'
  ]
}
