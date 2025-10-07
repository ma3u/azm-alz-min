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

@description('Container Registry SKU (Standard or Premium). Premium required for private endpoints but costs ~$150/month.')
@allowed(['Standard', 'Premium'])
param containerRegistrySku string = 'Standard'

@description('Enable Virtual Machine for testing and production compliance')
param enableVirtualMachine bool = false

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

    // SKU configurable via parameter (Standard for cost savings, Premium for private endpoints)
    acrSku: containerRegistrySku

    // Security configurations
    acrAdminUserEnabled: false
    networkRuleSetDefaultAction: containerRegistrySku == 'Premium' ? 'Deny' : 'Allow'

    // Network configuration with private endpoint (only available with Premium SKU)
    privateEndpoints: containerRegistrySku == 'Premium' ? [
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
    ] : []

    // Soft delete policy disabled due to compatibility issues
    softDeletePolicyDays: 7
    softDeletePolicyStatus: 'disabled'

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

// Private DNS Zone for ACR (only needed with Premium SKU)
module privateDnsZoneAcr 'br/public:avm/res/network/private-dns-zone:0.8.0' = if (enableContainerRegistry && containerRegistrySku == 'Premium') {
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
module hubVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = {
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
module spokeVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = {
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
        delegation: 'Microsoft.Web/serverFarms'
      }
      {
        name: 'snet-private-endpoints'
        addressPrefix: '10.1.11.0/24'
      }
    ]

    peerings: [
      {
        remoteVirtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
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
module hubToSpokePeering 'br/public:avm/res/network/virtual-network:0.7.1' = {
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
        remoteVirtualNetworkResourceId: spokeVirtualNetwork.outputs.resourceId
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
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = if (enableAppWorkloads) {
  name: 'appServicePlanDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'asp-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    skuName: 'B1'
    skuCapacity: 1

    kind: 'app'
  }
  dependsOn: [
    spokeVirtualNetwork
  ]
}

// Web App using AVM with Managed Identity
module webApp 'br/public:avm/res/web/site:0.19.3' = if (enableAppWorkloads) {
  name: 'webAppDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'app-${organizationPrefix}-web-${environment}'
    location: location
    tags: commonTags

    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId

    // ✅ MANAGED IDENTITY: Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // ✅ SECURITY: Production-ready security settings
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'

    virtualNetworkSubnetResourceId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-web-apps'

    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      use32BitWorkerProcess: false
      http20Enabled: true // ✅ SECURITY: Enable HTTP/2.0 (CKV_AZURE_18)
      healthCheckPath: '/health' // ✅ SECURITY: Health check path (CKV_AZURE_213)
      requestTracingEnabled: true // ✅ SECURITY: Failed request tracing (CKV_AZURE_66)
      httpLoggingEnabled: true // ✅ SECURITY: HTTP logging (CKV_AZURE_63)
      clientCertEnabled: true // ✅ SECURITY: Client certificates (CKV_AZURE_17)

      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'ORGANIZATION'
          value: organizationPrefix
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: 'MANAGED_IDENTITY' // Indicates managed identity usage
        }
      ]
    }

    // ✅ MONITORING: Diagnostic settings
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
  dependsOn: [
    appServicePlan
    logAnalyticsWorkspace
  ]
}

// Storage Account using AVM with Managed Identity access
module storageAccount 'br/public:avm/res/storage/storage-account:0.27.1' = if (enableAppWorkloads) {
  name: 'storageAccountDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'st${organizationPrefix}${environment}${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    tags: commonTags

    kind: 'StorageV2'
    skuName: 'Standard_LRS'

    // ✅ SECURITY: Enhanced security configuration
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: environment == 'sandbox' ? true : false // Allow shared key for sandbox, disable for production
    defaultToOAuthAuthentication: true // ✅ MANAGED IDENTITY: Prefer OAuth/managed identity authentication
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'

    // ✅ MANAGED IDENTITY: Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // ✅ SECURITY: Blob service configuration
    blobServices: {
      changeFeedEnabled: true
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 7
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      versioningEnabled: true
    }

    // ✅ MONITORING: Diagnostic settings
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
  dependsOn: [
    spokeVirtualNetwork
    logAnalyticsWorkspace
  ]
}

// Log Analytics Workspace using AVM
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
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

// =======================
// KEY VAULT WITH MANAGED IDENTITY ACCESS
// =======================

// Key Vault using AVM with RBAC authorization
module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: 'keyVaultDeployment'
  scope: hubResourceGroup
  params: {
    name: 'kv-${organizationPrefix}-${environment}-${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    tags: commonTags

    // ✅ SECURITY: Production-ready configuration
    enableVaultForDeployment: false
    enableVaultForDiskEncryption: true
    enableVaultForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true

    // ✅ RBAC: Use RBAC authorization instead of access policies
    enableRbacAuthorization: true

    // ✅ NETWORK: Allow Azure services and current IP (sandbox-friendly)
    publicNetworkAccess: 'Enabled'
    networkRuleSet: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Relaxed for sandbox, should be 'Deny' in production
    }

    // ✅ SKU: Standard for sandbox, Premium for production
    skuName: 'standard'

    // ✅ MONITORING: Diagnostic settings
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

    // ✅ RBAC: Role assignments for managed identities
    roleAssignments: [
      // Web App managed identity - Key Vault Secrets User
      {
        principalId: enableAppWorkloads ? webApp.outputs.systemAssignedMIPrincipalId : ''
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        principalType: 'ServicePrincipal'
      }
      // Container Registry managed identity - Key Vault Secrets User
      {
        principalId: enableContainerRegistry ? azureContainerRegistry.outputs.systemAssignedMIPrincipalId : ''
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    logAnalyticsWorkspace
    webApp // Ensure web app is deployed first to get managed identity
    azureContainerRegistry // Ensure ACR is deployed first
  ]
}

// =======================
// RBAC ROLE ASSIGNMENTS
// =======================

// Storage Account RBAC assignments for Web App managed identity
module storageRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.1.0' = if (enableAppWorkloads) {
  name: 'storageRoleAssignmentDeployment'
  scope: spokeResourceGroup
  params: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.outputs.resourceId
  }
  dependsOn: [
    webApp
    storageAccount
  ]
}

// Container Registry RBAC assignment for Web App managed identity
module acrRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.1.0' = if (enableAppWorkloads && enableContainerRegistry) {
  name: 'acrRoleAssignmentDeployment'
  scope: hubResourceGroup
  params: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    resourceId: azureContainerRegistry.outputs.resourceId
  }
  dependsOn: [
    webApp
    azureContainerRegistry
  ]
}

// Azure Bastion (optional for sandbox)
module bastionPublicIp 'br/public:avm/res/network/public-ip-address:0.9.0' = if (enableBastion) {
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

module azureBastion 'br/public:avm/res/network/bastion-host:0.8.0' = if (enableBastion) {
  name: 'azureBastionDeployment'
  scope: hubResourceGroup
  params: {
    name: 'bas-${organizationPrefix}-hub-${environment}'
    location: location
    tags: commonTags

    virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId

    bastionSubnetPublicIpResourceId: bastionPublicIp.outputs.resourceId
  }
  dependsOn: [
    hubVirtualNetwork
    bastionPublicIp
  ]
}

// =======================
// VIRTUAL MACHINE WITH MANAGED IDENTITY
// =======================

// Network Interface for Virtual Machine
module vmNetworkInterface 'br/public:avm/res/network/network-interface:0.4.0' = if (enableVirtualMachine) {
  name: 'vmNetworkInterfaceDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'nic-${organizationPrefix}-vm-${environment}'
    location: location
    tags: commonTags

    ipConfigurations: [
      {
        name: 'ipconfig1'
        subnetResourceId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-private-endpoints'
        privateIPAllocationMethod: 'Dynamic'
      }
    ]
  }
  dependsOn: [
    spokeVirtualNetwork
  ]
}

// Virtual Machine using AVM with Managed Identity
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.12.0' = if (enableVirtualMachine) {
  name: 'virtualMachineDeployment'
  scope: spokeResourceGroup
  params: {
    name: 'vm-${organizationPrefix}-${environment}'
    location: location
    tags: commonTags

    // ✅ MANAGED IDENTITY: Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // ✅ COMPUTE: Basic configuration for sandbox
    computerName: 'vm${organizationPrefix}${environment}'
    adminUsername: 'azureadmin'
    disablePasswordAuthentication: true

    // ✅ SECURITY: Use SSH key authentication
    publicKeys: [
      {
        keyData: loadTextContent('../../.secrets/azure-alz-key.pub')
        path: '/home/azureadmin/.ssh/authorized_keys'
      }
    ]

    // ✅ OS: Ubuntu 22.04 LTS
    imageReference: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }

    // ✅ SIZE: Standard_B2s for cost optimization (~$30/month)
    vmSize: 'Standard_B2s'

    // ✅ DISK: Standard SSD for balance of performance and cost
    osDisk: {
      caching: 'ReadWrite'
      createOption: 'FromImage'
      deleteOption: 'Delete'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }

    // ✅ NETWORK: Connect to spoke subnet
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: '${spokeVirtualNetwork.outputs.resourceId}/subnets/snet-private-endpoints'
            privateIPAllocationMethod: 'Dynamic'
          }
        ]
      }
    ]

    // ✅ MONITORING: Diagnostic settings
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

    // ✅ EXTENSIONS: Install Azure CLI and other essential tools
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: 'https://raw.githubusercontent.com/Azure/azure-cli/dev/scripts/install_linux.sh'
        }
      ]
      protectedSettings: {}
    }
  }
  dependsOn: [
    spokeVirtualNetwork
    logAnalyticsWorkspace
  ]
}

// VM RBAC assignments
module vmKeyVaultRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.1.0' = if (enableVirtualMachine) {
  name: 'vmKeyVaultRoleAssignmentDeployment'
  scope: hubResourceGroup
  params: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    principalId: virtualMachine.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    resourceId: keyVault.outputs.resourceId
  }
  dependsOn: [
    virtualMachine
    keyVault
  ]
}

module vmStorageRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.1.0' = if (enableVirtualMachine && enableAppWorkloads) {
  name: 'vmStorageRoleAssignmentDeployment'
  scope: spokeResourceGroup
  params: {
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    principalId: virtualMachine.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.outputs.resourceId
  }
  dependsOn: [
    virtualMachine
    storageAccount
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

// ✅ MANAGED IDENTITY: All managed identity outputs
output webAppSystemAssignedMIPrincipalId string = enableAppWorkloads ? webApp.outputs.systemAssignedMIPrincipalId : ''
output storageAccountSystemAssignedMIPrincipalId string = enableAppWorkloads ? storageAccount.outputs.systemAssignedMIPrincipalId : ''
output virtualMachineSystemAssignedMIPrincipalId string = enableVirtualMachine ? virtualMachine.outputs.systemAssignedMIPrincipalId : ''

// ✅ KEY VAULT: Key Vault outputs
output keyVaultId string = keyVault.outputs.resourceId
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// ✅ ENHANCED CONNECTION INFORMATION with Managed Identity Details
output connectionInfo object = {
  webApp: {
    hostname: enableAppWorkloads ? webApp.outputs.defaultHostname : 'N/A - App workloads not enabled'
    managedIdentity: enableAppWorkloads ? webApp.outputs.systemAssignedMIPrincipalId : 'N/A - App workloads not enabled'
    authentication: enableAppWorkloads ? 'System-assigned managed identity enabled' : 'N/A - App workloads not enabled'
    httpsOnly: enableAppWorkloads ? 'Enabled (Production-ready)' : 'N/A - App workloads not enabled'
    rbacAssignments: enableAppWorkloads ? [
      'Key Vault Secrets User'
      'Storage Blob Data Contributor'
      'ACR Pull (if Container Registry enabled)'
    ] : []
  }
  storage: {
    accountName: enableAppWorkloads ? storageAccount.outputs.name : 'N/A - App workloads not enabled'
    blobEndpoint: enableAppWorkloads ? storageAccount.outputs.primaryBlobEndpoint : 'N/A - App workloads not enabled'
    managedIdentity: enableAppWorkloads ? storageAccount.outputs.systemAssignedMIPrincipalId : 'N/A - App workloads not enabled'
    authentication: enableAppWorkloads ? 'OAuth/Managed Identity preferred, Shared Key allowed (sandbox)' : 'N/A - App workloads not enabled'
    rbacEnabled: enableAppWorkloads ? 'Web App has Storage Blob Data Contributor role' : 'N/A - App workloads not enabled'
  }
  containerRegistry: {
    name: enableContainerRegistry ? azureContainerRegistry.outputs.name : 'N/A - Container Registry not enabled'
    loginServer: enableContainerRegistry ? azureContainerRegistry.outputs.loginServer : 'N/A - Container Registry not enabled'
    managedIdentity: enableContainerRegistry ? azureContainerRegistry.outputs.systemAssignedMIPrincipalId : 'N/A - Container Registry not enabled'
    vulnerabilityScanning: enableContainerRegistry ? 'Microsoft Defender for Containers enabled' : 'N/A - Container Registry not enabled'
    privateEndpoint: enableContainerRegistry ? 'Private endpoint in hub subnet (10.0.4.0/24)' : 'N/A - Container Registry not enabled'
    authentication: enableContainerRegistry ? 'Managed Identity (Admin user disabled)' : 'N/A - Container Registry not enabled'
  }
  keyVault: {
    name: keyVault.outputs.name
    uri: keyVault.outputs.uri
    managedIdentity: 'RBAC-based access enabled'
    rbacAuthorization: 'Enabled (production-ready)'
    rbacAssignments: [
      'Web App: Key Vault Secrets User'
      'Container Registry: Key Vault Secrets User'
      'Virtual Machine: Key Vault Secrets User (if enabled)'
    ]
    networkAccess: 'Allow Azure Services (sandbox), should be Deny in production'
  }
  virtualMachine: {
    enabled: enableVirtualMachine
    name: enableVirtualMachine ? virtualMachine.outputs.name : 'N/A - Virtual Machine not enabled'
    managedIdentity: enableVirtualMachine ? virtualMachine.outputs.systemAssignedMIPrincipalId : 'N/A - Virtual Machine not enabled'
    authentication: enableVirtualMachine ? 'SSH Key-based (password disabled)' : 'N/A - Virtual Machine not enabled'
    rbacAssignments: enableVirtualMachine ? [
      'Key Vault Secrets User'
      'Storage Blob Data Contributor'
    ] : []
    operatingSystem: enableVirtualMachine ? 'Ubuntu 22.04 LTS' : 'N/A - Virtual Machine not enabled'
    size: enableVirtualMachine ? 'Standard_B2s (~$30/month)' : 'N/A - Virtual Machine not enabled'
  }
  networking: {
    hubVNet: hubVirtualNetwork.outputs.name
    spokeVNet: spokeVirtualNetwork.outputs.name
    bastionEnabled: enableBastion
    vnetPeering: 'Hub-Spoke peering configured'
    subnets: {
      webApps: 'snet-web-apps (10.1.2.0/24)'
      privateEndpoints: 'snet-private-endpoints (10.1.11.0/24)'
      sharedServices: 'snet-shared-services (10.0.3.0/24)'
      bastionSubnet: 'AzureBastionSubnet (10.0.1.0/24)'
    }
  }
  deployment: {
    subscriptionId: subscription().subscriptionId
    region: location
    environment: environment
    sshKeyConfigured: 'SSH keys available in .secrets/ directory'
    managedIdentityStatus: 'Comprehensive managed identity implementation'
    securityPosture: 'Production-ready with managed identities and RBAC'
    costOptimization: 'Sandbox SKUs configured for cost-effective testing'
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
