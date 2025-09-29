metadata name = 'Azure Landing Zone - Simple Sandbox Test'
metadata description = 'Simple sandbox test for AVM Key Vault deployment without complex dependencies.'

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

@description('The name prefix for the Key Vault.')
param keyVaultNamePrefix string = 'kv-alz'

@description('Enable diagnostic settings for resources.')
param enableDiagnostics bool = true

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

var keyVaultName = '${keyVaultNamePrefix}-${take(uniqueString(resourceGroup().id), 15)}'

// =======================
// LOG ANALYTICS WORKSPACE
// =======================

// Deploy Log Analytics Workspace using AVM (for diagnostics)
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.3.4' = if (enableDiagnostics) {
  name: 'logAnalyticsWorkspaceDeployment'
  params: {
    name: 'log-${workloadName}-${environment}-${take(uniqueString(resourceGroup().id), 8)}'
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
module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: 'keyVaultDeployment'
  params: {
    // Required parameters
    name: keyVaultName
    location: location

    // Security configuration - sandbox friendly
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: false // Disabled for sandbox to allow cleanup
    softDeleteRetentionInDays: 7 // Minimum for sandbox
    sku: 'standard' // Standard SKU for sandbox testing

    // Network configuration - open for sandbox
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Allow all for sandbox testing
    }

    // Diagnostic settings disabled for simple test
    diagnosticSettings: []

    // Resource tagging
    tags: commonTags
  }
}

// =======================
// OUTPUTS
// =======================

// Key Vault Outputs
output keyVaultId string = keyVault.outputs.resourceId
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// Log Analytics Outputs
output logAnalyticsWorkspaceId string = ''

// Common Outputs
output location string = location
output environment string = environment
output workloadName string = workloadName
output tags object = commonTags

// Testing Instructions
output testingInstructions object = {
  description: 'Instructions for testing the deployed infrastructure'
  keyVaultTesting: {
    testConnectivity: 'az keyvault show --name ${keyVault.outputs.name}'
    setSecretCommand: 'az keyvault secret set --vault-name ${keyVault.outputs.name} --name test-secret --value "Hello from sandbox"' // pragma: allowlist secret
    getSecretCommand: 'az keyvault secret show --vault-name ${keyVault.outputs.name} --name test-secret --query value -o tsv' // pragma: allowlist secret
    listSecretsCommand: 'az keyvault secret list --vault-name ${keyVault.outputs.name} --query "[].name" -o table' // pragma: allowlist secret
  }
  cleanup: {
    description: 'Commands to clean up sandbox resources'
    purgeKeyVaultCommand: 'az keyvault purge --name ${keyVault.outputs.name} --location ${location}'
    deleteResourceGroupCommand: 'az group delete --name ${resourceGroup().name} --yes --no-wait'
  }
}
