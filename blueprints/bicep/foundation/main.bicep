metadata name = 'Azure Landing Zone - Sandbox Testing'
metadata description = 'Sandbox-friendly version for testing AVM patterns in a single subscription without subscription management.'

targetScope = 'subscription'

// =======================
// SANDBOX PARAMETERS
// =======================

@description('The primary Azure region for deployment.')
param location string = 'westeurope'

@description('The environment name for resource tagging and naming.')
@allowed([
  'sandbox'
  'dev'
  'test'
])
param environment string = 'sandbox'

@description('The workload name for resource tagging.')
param workloadName string = 'alz-sandbox'

// Virtual Network Configuration
@description('Whether to create a Virtual Network.')
param virtualNetworkEnabled bool = true

@description('The address prefix for the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

// Key Vault Configuration
@description('Whether to deploy Key Vault.')
param keyVaultEnabled bool = true

@description('The name prefix for the Key Vault.')
param keyVaultNamePrefix string = 'kv-alz-sb'

@description('Enable diagnostic settings for resources.')
param enableDiagnostics bool = true

@description('Enable private endpoints for Key Vault.')
param enablePrivateEndpoint bool = false

// Role Assignments
@description('Array of role assignments for Key Vault.')
param roleAssignments array = []

// =======================
// VARIABLES
// =======================

var commonTags = {
  Environment: environment
  Workload: workloadName
  IaC: 'Bicep-AVM'
  CostCenter: 'IT-Infrastructure'
  Pattern: 'Sandbox-Testing'
  Purpose: 'AVM-Validation'
}

var resourceGroupName = 'rg-${workloadName}-bi-${environment}'
var keyVaultName = '${keyVaultNamePrefix}-bi-${take(uniqueString(subscription().subscriptionId), 8)}'
var virtualNetworkName = 'vnet-${workloadName}-bi-${environment}'

// =======================
// RESOURCE GROUP
// =======================

// Deploy Resource Group using AVM
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// =======================
// VIRTUAL NETWORK
// =======================

// Deploy Virtual Network using AVM (scoped to resource group)
module virtualNetworkDeployment 'br/public:avm/res/network/virtual-network:0.7.1' = if (virtualNetworkEnabled) {
  name: 'virtualNetworkDeployment'
  scope: resourceGroup
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [virtualNetworkAddressPrefix]

    subnets: [
      {
        name: 'subnet-keyvault'
        addressPrefix: '10.0.1.0/24'
        serviceEndpoints: [
          'Microsoft.KeyVault'
        ]
      }
      {
        name: 'subnet-private-endpoints'
        addressPrefix: '10.0.2.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: 'subnet-workloads'
        addressPrefix: '10.0.10.0/24'
      }
    ]

    tags: commonTags
  }
}

// =======================
// LOG ANALYTICS WORKSPACE
// =======================

// Deploy Log Analytics Workspace using AVM (conditional)
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (enableDiagnostics) {
  name: 'logAnalyticsWorkspaceDeployment'
  scope: resourceGroup
  params: {
    name: 'log-${workloadName}-bi-${environment}-${take(uniqueString(subscription().subscriptionId), 8)}'
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30 // Sandbox retention
    tags: commonTags
  }
}

// =======================
// KEY VAULT
// =======================

// Deploy Key Vault using AVM
module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = if (keyVaultEnabled) {
  name: 'keyVaultDeployment'
  scope: resourceGroup
  params: {
    // Required parameters
    name: keyVaultName
    location: location

    // Security configuration
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true // Required by policy
    softDeleteRetentionInDays: 7 // Minimum for sandbox
    sku: 'standard' // Standard SKU for sandbox testing

    // Network configuration
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePrivateEndpoint ? 'Deny' : 'Allow'
      ipRules: [
        {
          value: '0.0.0.0/0' // Allow all IPs for sandbox testing
        }
      ]
    }

    // Private endpoint configuration (when VNet is enabled)
    privateEndpoints: enablePrivateEndpoint && virtualNetworkEnabled ? [
      {
        subnetResourceId: '${virtualNetworkDeployment.outputs.resourceId}/subnets/subnet-private-endpoints'
        tags: commonTags
      }
    ] : []

    // Diagnostic settings
    diagnosticSettings: enableDiagnostics ? [
      {
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
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
    ] : []

    // Role assignments
    roleAssignments: roleAssignments

    // Resource tagging
    tags: commonTags
  }
  dependsOn: [
    virtualNetworkDeployment
    logAnalyticsWorkspace
  ]
}

// =======================
// SANDBOX TESTING RESOURCES
// =======================

// Deploy a sample secret for testing using AVM resource module
module testSecret 'br/public:avm/res/key-vault/vault/secret:0.1.0' = if (keyVaultEnabled) {
  name: 'testSecretDeployment'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    name: 'sandbox-test-secret'
    value: 'This is a test secret for AVM validation'
    attributesEnabled: true
    tags: commonTags
  }
  dependsOn: [
    keyVault
  ]
}

// =======================
// OUTPUTS
// =======================

// Resource Group Outputs
output resourceGroupId string = resourceGroup.id
output resourceGroupName string = resourceGroup.name

// Network Outputs
output virtualNetworkId string = virtualNetworkEnabled ? virtualNetworkDeployment.outputs.resourceId : ''
output virtualNetworkName string = virtualNetworkEnabled ? virtualNetworkName : ''

// Key Vault Outputs
output keyVaultId string = keyVaultEnabled ? keyVault.outputs.resourceId : ''
output keyVaultName string = keyVaultEnabled ? keyVaultName : ''
output keyVaultUri string = keyVaultEnabled ? keyVault.outputs.uri : ''

// Log Analytics Outputs
output logAnalyticsWorkspaceId string = enableDiagnostics ? logAnalyticsWorkspace.outputs.resourceId : ''

// Common Outputs
output location string = location
output environment string = environment
output workloadName string = workloadName
output tags object = commonTags

// Sandbox Testing Outputs
output testingInstructions object = {
  description: 'Instructions for testing the deployed infrastructure'
  keyVaultTesting: keyVaultEnabled ? {
    testSecretCommand: 'az keyvault secret show --vault-name ${keyVault.outputs.name} --name sandbox-test-secret' // pragma: allowlist secret
    setSecretCommand: 'az keyvault secret set --vault-name ${keyVault.outputs.name} --name test-secret --value "test-value"' // pragma: allowlist secret
    listSecretsCommand: 'az keyvault secret list --vault-name ${keyVault.outputs.name}' // pragma: allowlist secret
    testSecretResourceId: testSecret.outputs.resourceId
  } : {}
  networkTesting: virtualNetworkEnabled ? {
    checkVnetCommand: 'az network vnet show --resource-group ${resourceGroup.name} --name ${virtualNetworkName}'
    listSubnetsCommand: 'az network vnet subnet list --resource-group ${resourceGroup.name} --vnet-name ${virtualNetworkName}'
  } : {}
  cleanup: {
    description: 'Commands to clean up sandbox resources'
    deleteResourceGroupCommand: 'az group delete --name ${resourceGroup.name} --yes --no-wait'
  }
}
