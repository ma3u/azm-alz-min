targetScope = 'resourceGroup'

@description('The prefix for the Key Vault name. Will be combined with unique string.')
param namePrefix string = 'kv-lz'

@description('The location where the Key Vault will be deployed.')
param location string = resourceGroup().location

// Generate a unique name within the 24 character limit for Key Vault
var uniqueName = '${namePrefix}-${take(uniqueString(resourceGroup().id), 15)}'

module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: 'keyVaultDeployment'
  params: {
    // Required parameters
    name: uniqueName
    // Non-required parameters
    location: location
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'  // Changed from 'Deny' to avoid network issues in basic deployment
    }
    tags: {
      Environment: 'Production'
      Purpose: 'Landing Zone'
    }
    // Removed privateEndpoints and roleAssignments to avoid placeholder issues
    // These can be added later with actual values
  }
}

output keyVaultId string = keyVault.outputs.resourceId
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
