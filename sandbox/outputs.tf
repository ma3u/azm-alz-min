# Outputs for Azure Landing Zone Sandbox
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.sandbox.name
}

output "key_vault_name" {
  description = "Name of the created Key Vault"
  value       = azurerm_key_vault.sandbox.name
}

output "key_vault_uri" {
  description = "URI of the created Key Vault"
  value       = azurerm_key_vault.sandbox.vault_uri
  sensitive   = true
}

output "virtual_network_name" {
  description = "Name of the created Virtual Network"
  value       = azurerm_virtual_network.sandbox.name
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.sandbox.name
}

output "testing_commands" {
  description = "Commands to test the sandbox deployment"
  value = {
    test_secret_retrieval = "az keyvault secret show --vault-name ${azurerm_key_vault.sandbox.name} --name sandbox-test-secret"             # pragma: allowlist secret
    set_new_secret        = "az keyvault secret set --vault-name ${azurerm_key_vault.sandbox.name} --name test-secret --value 'test-value'" # pragma: allowlist secret
    list_secrets          = "az keyvault secret list --vault-name ${azurerm_key_vault.sandbox.name}"                                        # pragma: allowlist secret
    check_vnet            = "az network vnet show --resource-group ${azurerm_resource_group.sandbox.name} --name ${azurerm_virtual_network.sandbox.name}"
    cleanup_resources     = "az group delete --name ${azurerm_resource_group.sandbox.name} --yes --no-wait"
  }
}
