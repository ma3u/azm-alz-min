metadata name = 'Hub and Spoke Network Architecture'
metadata description = 'Orchestrates deployment of hub and spoke VNets with full application stack using Azure Verified Modules'

targetScope = 'subscription'

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

@description('Hub VNet address prefix')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Spoke VNet address prefix')
param spokeVnetAddressPrefix string = '10.1.0.0/16'

@description('Enable Azure Firewall in hub')
param enableFirewall bool = true

@description('Enable Azure Bastion in hub')
param enableBastion bool = true

@description('Enable DNS Private Resolver in hub')
param enableDnsResolver bool = true

@description('Enable Application Gateway in spoke')
param enableAppGateway bool = true

@description('Enable Web Apps in spoke')
param enableWebApps bool = true

@description('Enable Container Apps in spoke')
param enableContainerApps bool = true

@description('Enable PostgreSQL in spoke')
param enablePostgreSQL bool = true

@description('Enable Storage Account in spoke')
param enableStorage bool = true

@description('Firewall SKU tier')
@allowed(['Basic', 'Standard', 'Premium'])
param firewallSkuTier string = 'Standard'

@description('Database administrator username')
@secure()
param dbAdministratorLogin string

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
  IaC: 'Bicep-AVM'
  DeployedBy: 'Warp-AI-Assistant'
  DeploymentDate: utcNow('yyyy-MM-dd')
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
// HUB NETWORK DEPLOYMENT
// =======================

module hubNetworkDeployment 'hub-vnet.bicep' = {
  name: 'hubNetworkDeployment'
  scope: hubResourceGroup
  params: {
    location: location
    environment: environment
    organizationPrefix: organizationPrefix
    hubVnetAddressPrefix: hubVnetAddressPrefix
    enableFirewall: enableFirewall
    enableBastion: enableBastion
    enableDnsResolver: enableDnsResolver
    firewallSkuTier: firewallSkuTier
  }
}

// =======================
// SPOKE NETWORK DEPLOYMENT
// =======================

module spokeNetworkDeployment 'spoke-vnet.bicep' = {
  name: 'spokeNetworkDeployment'
  scope: spokeResourceGroup
  params: {
    location: location
    environment: environment
    organizationPrefix: organizationPrefix
    spokeVnetAddressPrefix: spokeVnetAddressPrefix
    hubVnetId: hubNetworkDeployment.outputs.hubVnetId
    azureFirewallPrivateIp: enableFirewall ? hubNetworkDeployment.outputs.azureFirewallPrivateIp : ''
    enableAppGateway: enableAppGateway
    enableWebApps: enableWebApps
    enableContainerApps: enableContainerApps
    enablePostgreSQL: enablePostgreSQL
    enableStorage: enableStorage
    dbAdministratorLogin: dbAdministratorLogin
    dbAdministratorPassword: dbAdministratorPassword
  }
  dependsOn: [
    hubNetworkDeployment
  ]
}

// =======================
// HUB TO SPOKE PEERING
// =======================

module hubToSpokePeering 'br/public:avm/res/network/virtual-network-peering:0.1.1' = {
  name: 'hubToSpokePeeringDeployment'
  scope: hubResourceGroup
  params: {
    localVnetName: hubNetworkDeployment.outputs.hubVnetName
    remoteVirtualNetworkId: spokeNetworkDeployment.outputs.spokeVnetId
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
  }
  dependsOn: [
    hubNetworkDeployment
    spokeNetworkDeployment
  ]
}

// =======================
// MONITORING AND DIAGNOSTICS
// =======================

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.3.4' = {
  name: 'centralLogAnalyticsDeployment'
  scope: hubResourceGroup
  params: {
    name: 'log-${organizationPrefix}-hub-${environment}'
    location: location
    tags: commonTags
    skuName: 'PerGB2018'
    dataRetention: 90

    diagnosticSettings: [
      {
        workspaceResourceId: '' // Self-reference will be ignored
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
            enabled: true
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
            enabled: true
          }
        ]
      }
    ]
  }
}

// =======================
// OUTPUTS
// =======================

// Subscription and Resource Group outputs
output subscriptionId string = subscription().subscriptionId
output hubResourceGroupName string = hubResourceGroup.name
output spokeResourceGroupName string = spokeResourceGroup.name

// Hub Network outputs
output hubVnetId string = hubNetworkDeployment.outputs.hubVnetId
output hubVnetName string = hubNetworkDeployment.outputs.hubVnetName
output hubVnetAddressSpace array = hubNetworkDeployment.outputs.hubVnetAddressSpace
output azureFirewallId string = hubNetworkDeployment.outputs.azureFirewallId
output azureFirewallPrivateIp string = hubNetworkDeployment.outputs.azureFirewallPrivateIp
output firewallPublicIpAddress string = hubNetworkDeployment.outputs.firewallPublicIpAddress
output azureBastionId string = hubNetworkDeployment.outputs.azureBastionId
output bastionPublicIpAddress string = hubNetworkDeployment.outputs.bastionPublicIpAddress
output dnsPrivateResolverId string = hubNetworkDeployment.outputs.dnsPrivateResolverId

// Spoke Network outputs
output spokeVnetId string = spokeNetworkDeployment.outputs.spokeVnetId
output spokeVnetName string = spokeNetworkDeployment.outputs.spokeVnetName
output spokeVnetAddressSpace array = spokeNetworkDeployment.outputs.spokeVnetAddressSpace

// Application Gateway outputs
output applicationGatewayId string = spokeNetworkDeployment.outputs.applicationGatewayId
output appGatewayPublicIpAddress string = spokeNetworkDeployment.outputs.appGatewayPublicIpAddress

// Web App outputs
output webAppId string = spokeNetworkDeployment.outputs.webAppId
output webAppDefaultHostname string = spokeNetworkDeployment.outputs.webAppDefaultHostname
output appServicePlanId string = spokeNetworkDeployment.outputs.appServicePlanId

// Container Apps outputs
output containerAppsEnvironmentId string = spokeNetworkDeployment.outputs.containerAppsEnvironmentId
output containerAppJobId string = spokeNetworkDeployment.outputs.containerAppJobId

// Storage outputs
output storageAccountId string = spokeNetworkDeployment.outputs.storageAccountId
output storageAccountName string = spokeNetworkDeployment.outputs.storageAccountName

// Database outputs
output postgreSQLServerId string = spokeNetworkDeployment.outputs.postgreSQLServerId
output postgreSQLServerFqdn string = spokeNetworkDeployment.outputs.postgreSQLServerFqdn

// Key Vault outputs
output keyVaultId string = spokeNetworkDeployment.outputs.keyVaultId
output keyVaultName string = spokeNetworkDeployment.outputs.keyVaultName
output keyVaultUri string = spokeNetworkDeployment.outputs.keyVaultUri

// Monitoring outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.resourceId
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name

// Common outputs
output location string = location
output environment string = environment
output tags object = commonTags

// Connection Information for Applications
output connectionInfo object = {
  applicationGateway: {
    publicIp: spokeNetworkDeployment.outputs.appGatewayPublicIpAddress
    webAppBackend: spokeNetworkDeployment.outputs.webAppDefaultHostname
  }
  database: {
    server: spokeNetworkDeployment.outputs.postgreSQLServerFqdn
    database: 'app-database'
    username: dbAdministratorLogin
  }
  keyVault: {
    vaultUri: spokeNetworkDeployment.outputs.keyVaultUri
    name: spokeNetworkDeployment.outputs.keyVaultName
  }
  storage: {
    accountName: spokeNetworkDeployment.outputs.storageAccountName
    blobEndpoint: 'https://${spokeNetworkDeployment.outputs.storageAccountName}.blob.core.windows.net'
  }
  networking: {
    hubVnet: hubNetworkDeployment.outputs.hubVnetName
    spokeVnet: spokeNetworkDeployment.outputs.spokeVnetName
    firewallPrivateIp: hubNetworkDeployment.outputs.azureFirewallPrivateIp
  }
}

// Testing and Validation Information
output testingInformation object = {
  description: 'Hub and Spoke Network Architecture Testing Information'
  connectivity: {
    bastionAccess: 'az network bastion ssh --name ${hubNetworkDeployment.outputs.azureBastionId} --resource-group ${hubResourceGroup.name} --target-resource-id <vm-resource-id> --auth-type password --username <username>'
    applicationGatewayUrl: 'http://${spokeNetworkDeployment.outputs.appGatewayPublicIpAddress}'
    webAppPrivateEndpoint: 'Access via private endpoint through VNet'
  }
  monitoring: {
    logAnalyticsWorkspace: logAnalyticsWorkspace.outputs.name
    queryKustoLogs: 'Use Kusto queries in Log Analytics to monitor traffic flow'
  }
  security: {
    firewallLogs: 'Check Azure Firewall logs for traffic inspection'
    nsgFlowLogs: 'Enable NSG Flow Logs for detailed network traffic analysis'
  }
}
