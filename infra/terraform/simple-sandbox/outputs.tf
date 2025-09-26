# =======================
# RESOURCE GROUP OUTPUTS
# =======================

output "hub_resource_group_name" {
  description = "Name of the hub resource group"
  value       = azurerm_resource_group.hub.name
}

output "spoke_resource_group_name" {
  description = "Name of the spoke resource group"
  value       = azurerm_resource_group.spoke.name
}

# =======================
# HUB NETWORKING OUTPUTS
# =======================

output "hub_virtual_network_id" {
  description = "Resource ID of the hub virtual network"
  value       = azurerm_virtual_network.hub.id
}

output "hub_virtual_network_name" {
  description = "Name of the hub virtual network"
  value       = azurerm_virtual_network.hub.name
}

output "bastion_id" {
  description = "Resource ID of Azure Bastion (if enabled)"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].id : ""
}

# =======================
# SPOKE NETWORKING OUTPUTS
# =======================

output "spoke_virtual_network_id" {
  description = "Resource ID of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.id
}

output "spoke_virtual_network_name" {
  description = "Name of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.name
}

# =======================
# APPLICATION OUTPUTS
# =======================

output "web_app_id" {
  description = "Resource ID of the web app (if enabled)"
  value       = var.enable_app_workloads ? azurerm_linux_web_app.main[0].id : ""
}

output "web_app_default_hostname" {
  description = "Default hostname of the web app (if enabled)"
  value       = var.enable_app_workloads ? azurerm_linux_web_app.main[0].default_hostname : ""
}

output "storage_account_id" {
  description = "Resource ID of the storage account (if enabled)"
  value       = var.enable_app_workloads ? azurerm_storage_account.main[0].id : ""
}

output "storage_account_name" {
  description = "Name of the storage account (if enabled)"
  value       = var.enable_app_workloads ? azurerm_storage_account.main[0].name : ""
}

# =======================
# LOG ANALYTICS OUTPUTS
# =======================

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# =======================
# CONTAINER REGISTRY OUTPUTS
# =======================

output "container_registry_id" {
  description = "Resource ID of Azure Container Registry (if enabled)"
  value       = var.enable_container_registry ? azurerm_container_registry.main[0].id : ""
}

output "container_registry_name" {
  description = "Name of Azure Container Registry (if enabled)"
  value       = var.enable_container_registry ? azurerm_container_registry.main[0].name : ""
}

output "container_registry_login_server" {
  description = "Login server of Azure Container Registry (if enabled)"
  value       = var.enable_container_registry ? azurerm_container_registry.main[0].login_server : ""
}

output "private_dns_zone_acr_id" {
  description = "Resource ID of the ACR private DNS zone (if enabled)"
  value       = var.enable_container_registry ? azurerm_private_dns_zone.acr[0].id : ""
}

# =======================
# CONNECTION INFORMATION FOR TESTING
# =======================

output "connection_info" {
  description = "Connection information for testing and validation"
  value = {
    web_app = {
      hostname = var.enable_app_workloads ? azurerm_linux_web_app.main[0].default_hostname : "N/A - App workloads not enabled"
    }
    storage = {
      account_name  = var.enable_app_workloads ? azurerm_storage_account.main[0].name : "N/A - App workloads not enabled"
      blob_endpoint = var.enable_app_workloads ? azurerm_storage_account.main[0].primary_blob_endpoint : "N/A - App workloads not enabled"
    }
    container_registry = {
      name                   = var.enable_container_registry ? azurerm_container_registry.main[0].name : "N/A - Container Registry not enabled"
      login_server           = var.enable_container_registry ? azurerm_container_registry.main[0].login_server : "N/A - Container Registry not enabled"
      vulnerability_scanning = var.enable_container_registry ? "Premium SKU with security scanning available" : "N/A - Container Registry not enabled"
      private_endpoint       = var.enable_container_registry ? "Private endpoint in hub subnet (10.0.4.0/24)" : "N/A - Container Registry not enabled"
      authentication         = var.enable_container_registry ? "Managed Identity (Admin user disabled)" : "N/A - Container Registry not enabled"
    }
    networking = {
      hub_vnet        = azurerm_virtual_network.hub.name
      spoke_vnet      = azurerm_virtual_network.spoke.name
      bastion_enabled = var.enable_bastion
    }
    deployment = {
      subscription_id    = data.azurerm_subscription.current.subscription_id
      region             = var.location
      environment        = var.environment
      ssh_key_configured = "SSH keys available in .secrets/ directory"
      terraform_version  = "Native Azure Provider (v4.9+)"
    }
  }
}

# =======================
# DEPLOYMENT INFORMATION
# =======================

output "deployment_info" {
  description = "Information about this deployment approach"
  value = {
    description = "This Terraform deployment uses native Azure provider resources"
    approach    = "Native Azure Provider"
    provider_versions = {
      terraform = ">= 1.9"
      azurerm   = "~> 4.9"
      random    = "~> 3.6"
    }
    features = [
      "Hub-Spoke networking with VNet peering",
      "Azure Container Registry with private endpoints",
      "Web App with VNet integration",
      "Storage Account with security configurations",
      "Log Analytics workspace for monitoring",
      "Azure Bastion for secure access (optional)"
    ]
    benefits = [
      "Direct Azure provider resource control",
      "Latest Terraform and provider versions",
      "Full configuration flexibility",
      "Simplified dependency management",
      "Faster deployment compared to AVM modules",
      "Direct access to all provider features"
    ]
    cost_estimation = {
      minimal      = "~$2/month (networking only)"
      standard     = "~$18/month (with ACR + Web App)"
      with_bastion = "~$161/month (includes Azure Bastion)"
    }
  }
}
