# Outputs for Azure Landing Zone - Terraform Implementation
# Aligned with AVM Bicep Sub-vending Pattern outputs

# Resource Group Outputs
output "resource_group_id" {
  description = "The ID of the created resource group"
  value       = azurerm_resource_group.main.id
}

output "resource_group_name" {
  description = "The name of the created resource group"
  value       = azurerm_resource_group.main.name
}

# Virtual Network Outputs
output "virtual_network_id" {
  description = "The ID of the created virtual network"
  value       = var.virtual_network_enabled ? azurerm_virtual_network.main[0].id : null
}

output "virtual_network_name" {
  description = "The name of the created virtual network"
  value       = var.virtual_network_enabled ? azurerm_virtual_network.main[0].name : null
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = var.virtual_network_enabled ? {
    key_vault         = azurerm_subnet.key_vault[0].id
    private_endpoints = azurerm_subnet.private_endpoints[0].id
    workloads         = azurerm_subnet.workloads[0].id
  } : {}
}

# Key Vault Outputs
output "key_vault_id" {
  description = "The ID of the created Key Vault"
  value       = var.key_vault_enabled ? azurerm_key_vault.main[0].id : null
  sensitive   = true
}

output "key_vault_name" {
  description = "The name of the created Key Vault"
  value       = var.key_vault_enabled ? azurerm_key_vault.main[0].name : null
}

output "key_vault_uri" {
  description = "The URI of the created Key Vault"
  value       = var.key_vault_enabled ? azurerm_key_vault.main[0].vault_uri : null
  sensitive   = true
}

output "key_vault_tenant_id" {
  description = "The Tenant ID associated with the Key Vault"
  value       = var.key_vault_enabled ? azurerm_key_vault.main[0].tenant_id : null
}

# Log Analytics Workspace Outputs
output "log_analytics_workspace_id" {
  description = "The ID of the created Log Analytics Workspace"
  value       = var.enable_diagnostics ? azurerm_log_analytics_workspace.main[0].id : null
}

output "log_analytics_workspace_name" {
  description = "The name of the created Log Analytics Workspace"
  value       = var.enable_diagnostics ? azurerm_log_analytics_workspace.main[0].name : null
}

output "log_analytics_workspace_workspace_id" {
  description = "The Workspace ID (Customer ID) of the Log Analytics Workspace"
  value       = var.enable_diagnostics ? azurerm_log_analytics_workspace.main[0].workspace_id : null
  sensitive   = true
}

output "log_analytics_workspace_primary_shared_key" {
  description = "The primary shared key of the Log Analytics Workspace"
  value       = var.enable_diagnostics ? azurerm_log_analytics_workspace.main[0].primary_shared_key : null
  sensitive   = true
}

# Private Endpoint Outputs
output "private_endpoint_id" {
  description = "The ID of the Key Vault private endpoint"
  value       = var.enable_private_endpoint && var.virtual_network_enabled && var.key_vault_enabled ? azurerm_private_endpoint.key_vault[0].id : null
}

output "private_endpoint_fqdn" {
  description = "The FQDN of the Key Vault private endpoint"
  value       = var.enable_private_endpoint && var.virtual_network_enabled && var.key_vault_enabled ? azurerm_private_endpoint.key_vault[0].private_service_connection[0].private_ip_address : null
  sensitive   = true
}

# Private DNS Zone Outputs
output "private_dns_zone_id" {
  description = "The ID of the Key Vault private DNS zone"
  value       = var.enable_private_endpoint && var.virtual_network_enabled ? azurerm_private_dns_zone.key_vault[0].id : null
}

output "private_dns_zone_name" {
  description = "The name of the Key Vault private DNS zone"
  value       = var.enable_private_endpoint && var.virtual_network_enabled ? azurerm_private_dns_zone.key_vault[0].name : null
}

# Common Outputs
output "location" {
  description = "The Azure region where resources are deployed"
  value       = var.location
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "workload_name" {
  description = "The workload name"
  value       = var.workload_name
}

output "common_tags" {
  description = "The common tags applied to all resources"
  value       = local.common_tags
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group_name      = azurerm_resource_group.main.name
    virtual_network_enabled  = var.virtual_network_enabled
    key_vault_enabled        = var.key_vault_enabled
    private_endpoint_enabled = var.enable_private_endpoint
    diagnostics_enabled      = var.enable_diagnostics
    environment              = var.environment
    location                 = var.location
  }
}
