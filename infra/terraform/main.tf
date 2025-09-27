# Azure Landing Zone - Terraform Implementation
# Complementing the AVM Bicep Sub-vending Pattern
# This configuration provides equivalent infrastructure using Terraform AzureRM provider

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }

  # Configure backend for state management
  backend "azurerm" {
    # Configure these values via backend config file or environment variables
    # storage_account_name = "terraformstate"
    # container_name       = "tfstate"
    # key                  = "azure-landingzone.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy               = false
      purge_soft_deleted_keys_on_destroy         = false
      purge_soft_deleted_secrets_on_destroy      = false
      purge_soft_deleted_certificates_on_destroy = false
      recover_soft_deleted_key_vaults            = true
      recover_soft_deleted_keys                  = true
      recover_soft_deleted_secrets               = true
      recover_soft_deleted_certificates          = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local variables
locals {
  common_tags = {
    Environment  = var.environment
    Workload     = var.workload_name
    IaC          = "Terraform"
    LastDeployed = formatdate("YYYY-MM-DD", timestamp())
    CostCenter   = "IT-Infrastructure"
    Pattern      = "AVM-Compatible"
  }

  resource_group_name = "rg-${var.workload_name}-${var.environment}"
  key_vault_name      = "${var.key_vault_name_prefix}-${var.environment}-${random_string.suffix.result}"
  vnet_name           = "vnet-${var.workload_name}-${var.environment}"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Virtual Network (conditional)
resource "azurerm_virtual_network" "main" {
  count = var.virtual_network_enabled ? 1 : 0

  name                = local.vnet_name
  address_space       = [var.virtual_network_address_prefix]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Subnets for Key Vault and Private Endpoints
resource "azurerm_subnet" "key_vault" {
  count = var.virtual_network_enabled ? 1 : 0

  name                 = "subnet-keyvault"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "private_endpoints" {
  count = var.virtual_network_enabled ? 1 : 0

  name                 = "subnet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.2.0/24"]

  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "workloads" {
  count = var.virtual_network_enabled ? 1 : 0

  name                 = "subnet-workloads"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.10.0/24"]
}

# Log Analytics Workspace for diagnostics
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_diagnostics ? 1 : 0

  name                = "log-${var.workload_name}-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 365 : 30
  tags                = local.common_tags
}

# Key Vault
resource "azurerm_key_vault" "main" {
  count = var.key_vault_enabled ? 1 : 0

  name                       = local.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true # Enable for all environments for better security

  # Modern RBAC authorization instead of access policies
  enable_rbac_authorization = true

  # Network ACLs
  network_acls {
    bypass         = "AzureServices"
    default_action = var.enable_private_endpoint ? "Deny" : "Allow"

    # Allow all IPs for non-production environments
    dynamic "ip_rules" {
      for_each = var.environment == "prod" ? [] : ["0.0.0.0/0"]
      content {
        value = ip_rules.value
      }
    }

    # Virtual network rules for Key Vault subnet
    dynamic "virtual_network_subnet_ids" {
      for_each = var.virtual_network_enabled && !var.enable_private_endpoint ? [azurerm_subnet.key_vault[0].id] : []
      content {
        subnet_id = virtual_network_subnet_ids.value
      }
    }
  }

  tags = local.common_tags
}

# Key Vault Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.key_vault_enabled && var.enable_diagnostics ? 1 : 0

  name                       = "diag-${local.key_vault_name}"
  target_resource_id         = azurerm_key_vault.main[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Private DNS Zone for Key Vault (conditional)
resource "azurerm_private_dns_zone" "key_vault" {
  count = var.enable_private_endpoint && var.virtual_network_enabled ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count = var.enable_private_endpoint && var.virtual_network_enabled ? 1 : 0

  name                  = "link-${local.vnet_name}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_private_endpoint && var.virtual_network_enabled && var.key_vault_enabled ? 1 : 0

  name                = "pe-${local.key_vault_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id

  private_service_connection {
    name                           = "psc-${local.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.main[0].id
    subresource_names              = ["Vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdz-group-${local.key_vault_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault[0].id]
  }

  tags = local.common_tags
}

# Role Assignments for Key Vault
resource "azurerm_role_assignment" "key_vault" {
  count = var.key_vault_enabled && length(var.role_assignments) > 0 ? length(var.role_assignments) : 0

  scope                = azurerm_key_vault.main[0].id
  role_definition_name = var.role_assignments[count.index].role_definition_name
  principal_id         = var.role_assignments[count.index].principal_id
  description          = var.role_assignments[count.index].description
}
