# Azure Landing Zone - Sandbox Terraform Configuration
# Single subscription testing without subscription management

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
}

# Configure the Azure Provider for Sandbox
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy               = true # Allow cleanup in sandbox
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
      purge_soft_deleted_certificates_on_destroy = true
      recover_soft_deleted_key_vaults            = false # Don't recover in sandbox
      recover_soft_deleted_keys                  = false
      recover_soft_deleted_secrets               = false
      recover_soft_deleted_certificates          = false
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Variables are defined in variables.tf

# Data sources
data "azurerm_client_config" "current" {}

# Random suffix for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local variables
locals {
  common_tags = {
    Environment = var.environment
    Workload    = var.workload_name
    IaC         = "Terraform"
    CostCenter  = "IT-Infrastructure"
    Pattern     = "Sandbox-Testing"
    Purpose     = "AVM-Validation"
  }

  resource_group_name = "rg-${var.workload_name}-${var.environment}"
  key_vault_name      = "kv-alz-sb-${var.environment}-${random_string.suffix.result}"
  vnet_name           = "vnet-${var.workload_name}-${var.environment}"
}

# Resource Group
resource "azurerm_resource_group" "sandbox" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "sandbox" {
  name                = local.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.sandbox.location
  resource_group_name = azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

# Subnets
resource "azurerm_subnet" "key_vault" {
  name                 = "subnet-keyvault"
  resource_group_name  = azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.sandbox.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "subnet-private-endpoints"
  resource_group_name  = azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.sandbox.name
  address_prefixes     = ["10.0.2.0/24"]

  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "workloads" {
  name                 = "subnet-workloads"
  resource_group_name  = azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.sandbox.name
  address_prefixes     = ["10.0.10.0/24"]
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "sandbox" {
  name                = "log-${var.workload_name}-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.sandbox.location
  resource_group_name = azurerm_resource_group.sandbox.name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # Minimal retention for sandbox
  tags                = local.common_tags
}

# Key Vault
resource "azurerm_key_vault" "sandbox" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.sandbox.location
  resource_group_name        = azurerm_resource_group.sandbox.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard" # Standard SKU for sandbox
  soft_delete_retention_days = 7          # Minimum for sandbox
  purge_protection_enabled   = false      # Disabled for easy cleanup

  # Modern RBAC authorization
  enable_rbac_authorization = true

  # Network ACLs - permissive for sandbox
  network_acls {
    bypass         = "AzureServices"
    default_action = var.enable_private_endpoint ? "Deny" : "Allow"

    # Allow all IPs for sandbox testing
    ip_rules = ["0.0.0.0/0"]

    # Virtual network rules
    virtual_network_subnet_ids = var.enable_private_endpoint ? [] : [azurerm_subnet.key_vault.id]
  }

  tags = local.common_tags
}

# Key Vault Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "key_vault_sandbox" {
  name                       = "diag-${local.key_vault_name}"
  target_resource_id         = azurerm_key_vault.sandbox.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sandbox.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Sample Key Vault Secret for Testing
resource "azurerm_key_vault_secret" "sandbox_test" {
  name         = "sandbox-test-secret"
  value        = "This is a test secret for AVM validation"
  key_vault_id = azurerm_key_vault.sandbox.id

  # Add content type and expiration for compliance
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year from now

  tags = local.common_tags

  depends_on = [azurerm_key_vault.sandbox]
}

# Grant Key Vault Administrator role to current user (for testing)
resource "azurerm_role_assignment" "current_user_kv_admin" {
  scope                = azurerm_key_vault.sandbox.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Outputs are defined in outputs.tf
