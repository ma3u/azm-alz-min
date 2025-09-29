metadata name = 'Azure Landing Zone - AVM Storage Test'
metadata description = 'Simple AVM test using Storage Account to demonstrate ALZ pattern without policy restrictions.'

targetScope = 'resourceGroup'

// =======================
// PARAMETERS
// =======================

@description('The primary Azure region for deployment.')
param location string = resourceGroup().location

@description('The environment name for resource tagging and naming.')
@allowed([
  'sandbox'
  'dev'
  'test'
])
param environment string = 'sandbox'

@description('The workload name for resource tagging.')
param workloadName string = 'alz-sandbox'

@description('The name prefix for the Storage Account.')
param storageAccountNamePrefix string = 'stalz'

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
  DeployedBy: 'Warp-AI-Assistant'
}

// Storage account name must be globally unique and 3-24 characters
var storageAccountName = '${storageAccountNamePrefix}${environment}${take(uniqueString(resourceGroup().id), 10)}'

// =======================
// STORAGE ACCOUNT
// =======================

// Deploy Storage Account using AVM
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: 'storageAccountDeployment'
  params: {
    // Required parameters
    name: storageAccountName
    location: location

    // Storage configuration
    kind: 'StorageV2'
    skuName: 'Standard_LRS'

    // Security configuration
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_2'

    // Network access
    publicNetworkAccess: 'Enabled'

    // Resource tagging
    tags: commonTags
  }
}

// =======================
// OUTPUTS
// =======================

// Storage Account Outputs
output storageAccountId string = storageAccount.outputs.resourceId
output storageAccountName string = storageAccount.outputs.name
output storageAccountPrimaryEndpoint string = storageAccount.outputs.primaryBlobEndpoint

// Common Outputs
output location string = location
output environment string = environment
output workloadName string = workloadName
output tags object = commonTags

// Testing Instructions
output testingInstructions object = {
  description: 'Instructions for testing the deployed AVM Storage Account'
  storageAccountTesting: {
    checkStorageAccount: 'az storage account show --name ${storageAccount.outputs.name} --resource-group ${resourceGroup().name}'
    listStorageKeys: 'az storage account keys list --account-name ${storageAccount.outputs.name} --resource-group ${resourceGroup().name}'
    createContainer: 'az storage container create --name test-container --account-name ${storageAccount.outputs.name} --auth-mode key'
    uploadBlob: 'az storage blob upload --file README.md --container-name test-container --name test-blob.md --account-name ${storageAccount.outputs.name} --auth-mode key'
  }
  avmValidation: {
    description: 'This deployment demonstrates Azure Verified Module (AVM) usage'
    moduleUsed: 'br/public:avm/res/storage/storage-account:0.9.1'
    benefits: [
      'Microsoft-validated configuration'
      'Security best practices by default'
      'Consistent parameter schema'
      'Regular updates and maintenance'
    ]
  }
  cleanup: {
    description: 'Commands to clean up sandbox resources'
    deleteResourceGroupCommand: 'az group delete --name ${resourceGroup().name} --yes --no-wait'
  }
}
