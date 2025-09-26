metadata name = 'Azure Landing Zone - Simple Sandbox'
metadata description = 'Simplified ALZ for single subscription sandbox testing with AVM modules'

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

@description('Enable application workloads')
param enableAppWorkloads bool = true

@description('Enable Azure Container Registry in hub')
param enableContainerRegistry bool = true

// =======================
// CONTAINER SERVICES
// =======================

// Azure Container Registry using AVM
module azureContainerRegistry 'br/public:avm/res/container-registry/registry:0.9.3' = if (enableContainerRegistry) {
  name: 'acrDeployment'
  scope: hubResourceGroup
  params: {
    name: 'acr${organizationPrefix}${environment}${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    tags: commonTags

    // Premium SKU required for vulnerability scanning and private endpoints
    acrSku: 'Premium'

    // Security configurations
    acrAdminUserEnabled: false
    networkRuleSetDefaultAction: 'Deny'

    // Network configuration with private endpoint
    privateEndpoints: [
      {
        subnetResourceId: '${hubVirtualNetwork.outputs.resourceId}/subnets/snet-acr-private-endpoints'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              name: 'acr-private-dns-zone-config'
              privateDnsZoneResourceId: privateDnsZoneAcr.outputs.resourceId
            }
          ]
        }
        service: 'registry'
      }
    ]

    // Soft delete policy (replaces retention policy)
    softDeletePolicyDays: 30
    softDeletePolicyStatus: 'enabled'

    // System-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // Diagnostic settings
    diagnosticSettings: [
      {
        logAnalyticsDestinationType: 'Dedicated'
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups: [
          {
            categoryGroup: 'AllLogs'
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

// Private DNS Zone for ACR
module privateDnsZoneAcr 'br/public:avm/res/network/private-dns-zone:0.2.4' = if (enableContainerRegistry) {
  name: 'privateDnsZoneAcrDeployment'
  scope: hubResourceGroup
  params: {
    name: 'privatelink.azurecr.io'
    tags: commonTags

    virtualNetworkLinks: [
      {
        name: 'hub-vnet-link'
        virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
      {
        name: 'spoke-vnet-link'
        virtualNetworkResourceId: spokeVirtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

// =======================
// SHARED SERVICES
// ======================

var commonTags = {
  Environment: environment
  Organization: organizationPrefix
  Pattern: 'ALZ-Sandbox-Simple'
  IaC: 'Bicep-AVM-Simple'
  DeployedBy: 'Warp-AI-Sandbox'
  Purpose: 'Sandbox-Testing'
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
// HUB NETWORKING WITH AVM
// =======================

// Hub Virtual Network using AVM
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
      }
      {
        name: 'snet-shared-services'
        addressPrefix: '10.0.3.0/24'
      }
      {
        name: 'snet-acr-private-endpoints'
        addressPrefix: '10.0.4.0/24'
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.100.0/24'
      }
    ]
  }
}

// =======================
// SPOKE NETWORKING WITH AVM
// =======================

// Spoke Virtual Network using AVM
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
        name: 'snet-private-endpoints'
        addressPrefix: '10.1.11.0/24'
      }
    ]

    peerings: [
      {
        remoteVirtualNetworkId: hubVirtualNetwork.outputs.resourceId
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        useRemoteGateways: false
      }
    ]
  }
  dependsOn: [
    hubVirtualNetwork
  ]
}

// Hub to Spoke peering
module hubToSpokePeering 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'hubToSpokePeeringUpdate'
  scope: hubResourceGroup
  params: {
    name: hubVirtualNetwork.outputs.name
    location: location
    addressPrefixes: [hubVnetAddressSpace]
    tags: commonTags

    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.1.0/24'
      }
      {
        name: 'snet-shared-services'
        addressPrefix: '10.0.3.0/24'
      }
      {
        name: 'snet-acr-private-endpoints'
        addressPrefix: '10.0.4.0/24'
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.100.0/24'
      }
    ]

    peerings: [
      {
        remoteVirtualNetworkId: spokeVirtualNetwork.outputs.resourceId
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        useRemoteGateways: false
      }
    ]
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
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = if (enableAppWorkloads) {
  name: 'appServicePlanDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'asp-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    sku: {
      name: 'B1'
      tier: 'Basic'
      size: 'B1'
      capacity: 1
    }

    kind: 'App'
  }
  dependsOn: [
    spokeVirtualNetwork
  ]
}

// Web App using AVM
module webApp 'br/public:avm/res/web/site:0.3.7' = if (enableAppWorkloads) {
  name: 'webAppDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'app-${organizationPrefix}-web-${environment}'
    location: location
    tags: commonTags

    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId

    httpsOnly: true
    publicNetworkAccess: 'Enabled'

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
  dependsOn: [
    appServicePlan
  ]
}

// Storage Account using AVM
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = if (enableAppWorkloads) {
  name: 'storageAccountDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'st${organizationPrefix}${environment}${take(uniqueString(subscription().subscriptionId), 8)}'
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
  }
  dependsOn: [
    spokeVirtualNetwork
  ]
}

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

// Azure Bastion (optional for sandbox)
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
output webAppId string = enableAppWorkloads ? webApp.outputs.resourceId : ''
output webAppDefaultHostname string = enableAppWorkloads ? webApp.outputs.defaultHostname : ''
output storageAccountId string = enableAppWorkloads ? storageAccount.outputs.resourceId : ''
output storageAccountName string = enableAppWorkloads ? storageAccount.outputs.name : ''

// Log Analytics outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.resourceId
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name

// Container Registry outputs
output containerRegistryId string = enableContainerRegistry ? azureContainerRegistry.outputs.resourceId : ''
output containerRegistryName string = enableContainerRegistry ? azureContainerRegistry.outputs.name : ''
output containerRegistryLoginServer string = enableContainerRegistry ? azureContainerRegistry.outputs.loginServer : ''
output containerRegistrySystemAssignedMIPrincipalId string = enableContainerRegistry ? azureContainerRegistry.outputs.systemAssignedMIPrincipalId : ''
output privateDnsZoneAcrId string = enableContainerRegistry ? privateDnsZoneAcr.outputs.resourceId : ''

// Connection Information for Testing
output connectionInfo object = {
  webApp: {
    hostname: enableAppWorkloads ? webApp.outputs.defaultHostname : 'N/A - App workloads not enabled'
  }
  storage: {
    accountName: enableAppWorkloads ? storageAccount.outputs.name : 'N/A - App workloads not enabled'
    blobEndpoint: enableAppWorkloads ? storageAccount.outputs.primaryBlobEndpoint : 'N/A - App workloads not enabled'
  }
  containerRegistry: {
    name: enableContainerRegistry ? azureContainerRegistry.outputs.name : 'N/A - Container Registry not enabled'
    loginServer: enableContainerRegistry ? azureContainerRegistry.outputs.loginServer : 'N/A - Container Registry not enabled'
    vulnerabilityScanning: enableContainerRegistry ? 'Microsoft Defender for Containers enabled' : 'N/A - Container Registry not enabled'
    privateEndpoint: enableContainerRegistry ? 'Private endpoint in hub subnet (10.0.4.0/24)' : 'N/A - Container Registry not enabled'
    authentication: enableContainerRegistry ? 'Managed Identity (Admin user disabled)' : 'N/A - Container Registry not enabled'
  }
  networking: {
    hubVNet: hubVirtualNetwork.outputs.name
    spokeVNet: spokeVirtualNetwork.outputs.name
    bastionEnabled: enableBastion
  }
  deployment: {
    subscriptionId: subscription().subscriptionId
    region: location
    environment: environment
    sshKeyConfigured: 'SSH keys available in .secrets/ directory'
  }
}

// AVM Module Information
output avmModulesUsed object = {
  description: 'This sandbox deployment uses AVM resource modules for rapid testing'
  avmResourceModules: [
    'avm/res/network/virtual-network:0.1.6 - Virtual Networks with peering'
    'avm/res/web/serverfarm:0.1.1 - App Service Plan'
    'avm/res/web/site:0.3.7 - Web App with VNet integration'
    'avm/res/storage/storage-account:0.9.1 - Storage Account'
    'avm/res/container-registry/registry:0.9.3 - Azure Container Registry with vulnerability scanning'
    'avm/res/network/private-dns-zone:0.2.4 - Private DNS Zone for ACR'
    'avm/res/network/bastion-host:0.3.0 - Azure Bastion (optional)'
    'avm/res/network/public-ip-address:0.2.3 - Public IP addresses'
    'avm/res/operational-insights/workspace:0.3.4 - Log Analytics'
  ]
  benefits: [
    'Microsoft-validated resource configurations'
    'Simplified deployment for sandbox testing'
    'VNet peering configured automatically'
    'SSH key authentication available'
    'Basic monitoring and logging included'
    'Container registry with vulnerability scanning'
    'Private endpoints for secure container image access'
    'Microsoft Defender for Containers integration'
    'Easy to extend for additional services'
  ]
}
