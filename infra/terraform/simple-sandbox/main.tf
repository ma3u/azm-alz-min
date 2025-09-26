terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "fdf79377-e045-462f-ac4a-630ddee7e4c3"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Get current subscription for unique naming
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Random string for unique naming
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

locals {
  # Common tags matching the Bicep template
  common_tags = {
    Environment  = var.environment
    Organization = var.organization_prefix
    Pattern      = "ALZ-Sandbox-Simple"
    IaC          = "Terraform-AVM-Simple"
    DeployedBy   = "Warp-AI-Sandbox"
    Purpose      = "Sandbox-Testing"
  }

  # Resource group names
  hub_resource_group_name   = "rg-${var.organization_prefix}-hub-${var.environment}"
  spoke_resource_group_name = "rg-${var.organization_prefix}-spoke-${var.environment}"

  # Unique suffix for globally unique resources
  unique_suffix = random_string.unique.result
}

# =======================
# RESOURCE GROUPS
# =======================

resource "azurerm_resource_group" "hub" {
  name     = local.hub_resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    Component = "Hub-Network"
  })
}

resource "azurerm_resource_group" "spoke" {
  name     = local.spoke_resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    Component = "Spoke-Network"
  })
}

# =======================
# HUB NETWORKING
# =======================

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.organization_prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  address_space       = [var.hub_vnet_address_space]

  tags = local.common_tags
}

resource "azurerm_subnet" "hub_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "hub_shared_services" {
  name                 = "snet-shared-services"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "hub_acr_private_endpoints" {
  name                 = "snet-acr-private-endpoints"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.100.0/24"]
}

# =======================
# SPOKE NETWORKING
# =======================

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.organization_prefix}-spoke-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  address_space       = [var.spoke_vnet_address_space]

  tags = local.common_tags
}

resource "azurerm_subnet" "spoke_web_apps" {
  name                 = "snet-web-apps"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.2.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "spoke_private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.11.0/24"]
}

# =======================
# VNET PEERING
# =======================

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-${var.organization_prefix}-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.organization_prefix}-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.spoke.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

# =======================
# LOG ANALYTICS WORKSPACE
# =======================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.organization_prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# =======================
# CONTAINER REGISTRY (if enabled)
# =======================

resource "azurerm_container_registry" "main" {
  count               = var.enable_container_registry ? 1 : 0
  name                = "acr${var.organization_prefix}${var.environment}${local.unique_suffix}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  sku                 = "Premium"

  admin_enabled                 = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"

  tags = local.common_tags
}

# Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_container_registry ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.hub.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  count                 = var.enable_container_registry ? 1 : 0
  name                  = "hub-vnet-link"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.hub.id

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_spoke" {
  count                 = var.enable_container_registry ? 1 : 0
  name                  = "spoke-vnet-link"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.spoke.id

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.enable_container_registry ? 1 : 0
  name                = "pe-acr-${var.organization_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  subnet_id           = azurerm_subnet.hub_acr_private_endpoints.id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main[0].id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-acr"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = local.common_tags
}

# =======================
# APPLICATION SERVICES (if enabled)
# =======================

resource "azurerm_service_plan" "main" {
  count               = var.enable_app_workloads ? 1 : 0
  name                = "asp-${var.organization_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = local.common_tags
}

resource "azurerm_linux_web_app" "main" {
  count               = var.enable_app_workloads ? 1 : 0
  name                = "app-${var.organization_prefix}-web-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main[0].id

  virtual_network_subnet_id = azurerm_subnet.spoke_web_apps.id

  site_config {
    always_on = true
    application_stack {
      dotnet_version = "6.0"
    }
  }

  app_settings = {
    ENVIRONMENT  = var.environment
    ORGANIZATION = var.organization_prefix
  }

  tags = local.common_tags
}

resource "azurerm_storage_account" "main" {
  count               = var.enable_app_workloads ? 1 : 0
  name                = "st${var.organization_prefix}${var.environment}${local.unique_suffix}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location

  account_kind                     = "StorageV2"
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  shared_access_key_enabled        = true
  min_tls_version                  = "TLS1_2"
  public_network_access_enabled    = true

  tags = local.common_tags
}

# =======================
# AZURE BASTION (if enabled)
# =======================

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.organization_prefix}-bastion-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.organization_prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = local.common_tags
}
