metadata name = 'Azure Landing Zone - AVM Sub-vending Pattern'
metadata description = 'This module deploys an Azure Landing Zone using the AVM sub-vending pattern with Key Vault and supporting infrastructure.'

targetScope = 'managementGroup'

// =======================
// SUB-VENDING PARAMETERS
// =======================

// Subscription Configuration
@description('Optional. Whether to create a new Subscription using the Subscription Alias resource.')
param subscriptionAliasEnabled bool = true

@maxLength(63)
@description('The name of the subscription alias for the Landing Zone.')
param subscriptionDisplayName string = 'Azure Landing Zone - Key Vault'

@maxLength(63)
@description('The name of the Subscription Alias that will be created.')
param subscriptionAliasName string = 'alz-keyvault-sub'

@description('The Billing Scope for the new Subscription alias.')
param subscriptionBillingScope string = ''

@allowed([
  'DevTest'
  'Production'
])
@description('The workload type for the subscription.')
param subscriptionWorkload string = 'Production'

@description('Optional. An existing subscription ID if not creating a new one.')
param existingSubscriptionId string = ''

// Management Group Configuration
@description('Whether to move the Subscription to the specified Management Group.')
param subscriptionManagementGroupAssociationEnabled bool = true

@description('The destination Management Group ID for the subscription.')
param subscriptionManagementGroupId string = ''

// Environment and Naming
@description('The environment name for resource tagging and naming.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('The workload name for resource tagging.')
param workloadName string = 'landingzone'

@description('The primary Azure region for deployment.')
param location string = deployment().location

// Network Configuration
@description('Whether to create a Virtual Network in the subscription.')
param virtualNetworkEnabled bool = true

@description('The name of the Virtual Network to create.')
param virtualNetworkName string = 'vnet-${workloadName}-${environment}'

@description('The address prefix for the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

// Key Vault Configuration
@description('Whether to deploy Key Vault in the subscription.')
param keyVaultEnabled bool = true

@description('The name prefix for the Key Vault.')
param keyVaultNamePrefix string = 'kv-avm-lz'

@description('Enable diagnostic settings for Key Vault.')
param enableDiagnostics bool = true

@description('Enable private endpoints for Key Vault.')
param enablePrivateEndpoint bool = false

// Role Assignments
@description('Array of role assignments for the subscription and resources.')
param roleAssignments array = []

// =======================
// VARIABLES
// =======================

var commonTags = {
  Environment: environment
  Workload: workloadName
  IaC: 'Bicep-AVM'
  CostCenter: 'IT-Infrastructure'
  Pattern: 'Sub-vending'
}

var subscriptionResourceGroupName = 'rg-${workloadName}-${environment}'
var keyVaultName = '${keyVaultNamePrefix}-${environment}-${take(uniqueString(subscriptionAliasEnabled ? subscriptionAliasName : existingSubscriptionId), 8)}'

// =======================
// AVM SUB-VENDING MODULE
// =======================

// Deploy Landing Zone using AVM Sub-vending Pattern
// Note: Using a simplified approach since the sub-vending module requires specific subscription management permissions
// For production, use the actual AVM sub-vending module with proper EA/MCA billing scope
module resourceGroupDeployment 'br/public:avm/res/resources/resource-group:0.2.3' = {
  name: 'resourceGroupDeployment'
  params: {
    name: subscriptionResourceGroupName
    location: location
    tags: commonTags
  }
}

// Virtual Network deployment using AVM
module virtualNetworkDeployment 'br/public:avm/res/network/virtual-network:0.1.6' = if (virtualNetworkEnabled) {
  name: 'virtualNetworkDeployment'
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [virtualNetworkAddressPrefix]

    subnets: [
      {
        name: 'subnet-keyvault'
        addressPrefix: '10.0.1.0/24'
        serviceEndpoints: [
          {
            service: 'Microsoft.KeyVault'
          }
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
  dependsOn: [
    resourceGroupDeployment
  ]
}
}

// =======================
// KEY VAULT DEPLOYMENT
// =======================

// Deploy Key Vault using AVM Resource Module
module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = if (keyVaultEnabled) {
  name: 'keyVaultDeployment'
  params: {
    // Required parameters
    name: keyVaultName
    location: location

    // Security configuration
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: environment == 'prod'
    softDeleteRetentionInDays: 90
    sku: 'premium'

    // Network configuration
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePrivateEndpoint ? 'Deny' : 'Allow'
      ipRules: environment == 'prod' ? [] : [
        {
          value: '0.0.0.0/0'
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

    // Resource tagging
    tags: commonTags
  }
  dependsOn: [
    resourceGroupDeployment
    virtualNetworkDeployment
  ]
}

// =======================
// OUTPUTS
// =======================

// Resource Group Outputs
output resourceGroupId string = resourceGroupDeployment.outputs.resourceId
output resourceGroupName string = subscriptionResourceGroupName

// Network Outputs
output virtualNetworkId string = virtualNetworkEnabled ? virtualNetworkDeployment.outputs.resourceId : ''
output virtualNetworkName string = virtualNetworkEnabled ? virtualNetworkName : ''

// Key Vault Outputs
output keyVaultId string = keyVaultEnabled ? keyVault.outputs.resourceId : ''
output keyVaultName string = keyVaultEnabled ? keyVaultName : ''
output keyVaultUri string = keyVaultEnabled ? keyVault.outputs.uri : ''

// Common Outputs
output location string = location
output environment string = environment
output workloadName string = workloadName
output tags object = commonTags
