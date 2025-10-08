terraform {
  required_version = ">= 1.5"
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
    DeployedBy   = "GithubAction-Sandbox"
    Purpose      = "Sandbox-Testing"
  }

  # Resource group names
  hub_resource_group_name   = "rg-${var.organization_prefix}-tf-hub-${var.environment}"
  spoke_resource_group_name = "rg-${var.organization_prefix}-tf-spoke-${var.environment}"

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
  name                = "vnet-${var.organization_prefix}-tf-hub-${var.environment}"
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
  name                = "vnet-${var.organization_prefix}-tf-spoke-${var.environment}"
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

resource "azurerm_subnet" "spoke_aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.20.0/22"] # Large subnet for AKS nodes (1024 IPs)
}

# =======================
# VNET PEERING
# =======================

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-${var.organization_prefix}-tf-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.organization_prefix}-tf-spoke-to-hub"
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
  name                = "log-${var.organization_prefix}-tf-hub-${var.environment}"
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
  name                = lower("acr${var.organization_prefix}tf${var.environment}${local.unique_suffix}")
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
  name                = "pe-acr-${var.organization_prefix}-tf-${var.environment}"
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
  name                = "asp-${var.organization_prefix}-tf-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = local.common_tags
}

resource "azurerm_linux_web_app" "main" {
  count               = var.enable_app_workloads ? 1 : 0
  name                = "app-${var.organization_prefix}-tf-web-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main[0].id

  virtual_network_subnet_id = azurerm_subnet.spoke_web_apps.id

  # Security configurations to comply with DEP policies
  https_only                                     = true
  public_network_access_enabled                  = false
  client_certificate_enabled                     = false
  client_certificate_mode                        = "Required"
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    vnet_route_all_enabled            = true
    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"

    application_stack {
      dotnet_version = "6.0"
    }

    # Allow traffic only from the VNet
    ip_restriction {
      virtual_network_subnet_id = azurerm_subnet.spoke_web_apps.id
      name                      = "VNetRestriction"
      priority                  = 100
      action                    = "Allow"
    }

    # SCM site restrictions
    scm_ip_restriction {
      virtual_network_subnet_id = azurerm_subnet.spoke_web_apps.id
      name                      = "SCMVNetRestriction"
      priority                  = 100
      action                    = "Allow"
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
  name                = lower("st${var.organization_prefix}tf${var.environment}${local.unique_suffix}")
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
# AZURE KUBERNETES SERVICE (if enabled)
# =======================

resource "azurerm_kubernetes_cluster" "main" {
  count               = var.enable_aks ? 1 : 0
  name                = "aks-${var.organization_prefix}-tf-${var.environment}-${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  dns_prefix          = "aks-${var.organization_prefix}-tf-${var.environment}-${random_string.unique.result}"
  kubernetes_version  = var.aks_kubernetes_version
  sku_tier            = "Free" # Start with Free tier to avoid policy issues

  # Private cluster configuration
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"

  # Minimal security configurations
  role_based_access_control_enabled = true
  local_account_disabled            = false
  run_command_enabled               = true # Enable for initial setup
  # disk_encryption_set_id            = null

  # System-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Default node pool configuration
  default_node_pool {
    name                         = "system"
    node_count                   = var.aks_system_node_count
    vm_size                      = var.aks_system_node_size
    vnet_subnet_id               = azurerm_subnet.spoke_aks.id
    type                         = "VirtualMachineScaleSets"
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 5
    max_pods                     = 30
    os_disk_size_gb              = 128
    os_disk_type                 = "Managed"
    os_sku                       = "Ubuntu"
    only_critical_addons_enabled = true

    # Security enhancements for policy compliance
    # enable_host_encryption     = false  # Available in certain regions
    # enable_node_public_ip      = false  # Controlled by subnet configuration
    kubelet_disk_type = "OS"

    # Taints and labels for system workloads
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "tier"          = "system"
    }

    # Security and compliance
    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Network configuration - Enhanced for enterprise compliance
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure" # Use Azure Network Policy for security
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/16"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"

    # Load balancer configuration for private cluster
    load_balancer_profile {
      managed_outbound_ip_count = 1
      # Note: outbound_ip_address_ids and outbound_ip_prefix_ids conflict with managed_outbound_ip_count
    }
  }

  # Simplified Azure AD integration (optional - may trigger policies)
  # azure_active_directory_role_based_access_control {
  #   admin_group_object_ids = var.aks_admin_group_object_ids
  #   azure_rbac_enabled     = true
  # }

  # Basic monitoring integration
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  # Security features (may trigger policies - simplified)
  # microsoft_defender {
  #   log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  # }

  # Simplified configuration - avoid policy triggers
  azure_policy_enabled = false # Disable to avoid policy conflicts initially

  # Basic image management (commented out to avoid policy issues)
  # image_cleaner_enabled        = true
  # image_cleaner_interval_hours = 48

  # Workload identity (may trigger policies - disabled initially)
  workload_identity_enabled = false
  oidc_issuer_enabled       = false

  # Basic storage profile
  # storage_profile {
  #   blob_driver_enabled         = true
  #   disk_driver_enabled         = true
  #   file_driver_enabled         = true
  #   snapshot_controller_enabled = true
  # }

  # HTTP proxy configuration (if required by policy)
  # http_proxy_config {
  #   http_proxy  = "http://proxy.company.com:8080"
  #   https_proxy = "https://proxy.company.com:8080"
  #   no_proxy    = ["localhost", "127.0.0.1"]
  # }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                         = "random"
    max_graceful_termination_sec     = 600
    max_node_provisioning_time       = "15m"
    new_pod_scale_up_delay           = "0s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m" # pragma: allowlist secret
  }

  tags = local.common_tags

  # Maintenance configuration (disabled to avoid policy conflicts)
  # maintenance_window {
  #   allowed {
  #     day   = "Saturday"
  #     hours = [2, 3, 4]
  #   }
  #
  #   not_allowed {
  #     start = "2025-01-01T00:00:00Z"
  #     end   = "2025-01-02T00:00:00Z"
  #   }
  # }

  # Automatic channel upgrades (controlled via maintenance window)
  # automatic_channel_upgrade = "patch"  # Available in newer provider versions
  # node_os_channel_upgrade  = "NodeImage"  # Available in newer provider versions

  depends_on = [
    azurerm_log_analytics_workspace.main
  ]
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.enable_aks && var.enable_aks_user_node_pool ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main[0].id
  vm_size               = var.aks_user_node_size
  node_count            = var.aks_user_node_count
  vnet_subnet_id        = azurerm_subnet.spoke_aks.id

  # Auto-scaling configuration
  auto_scaling_enabled = true
  min_count            = 1
  max_count            = 10
  max_pods             = 30

  # Storage configuration with security enhancements
  os_disk_size_gb   = 128
  os_disk_type      = "Managed"
  os_type           = "Linux"
  os_sku            = "Ubuntu"
  kubelet_disk_type = "OS"

  # Security enhancements (commented out - controlled by subnet/cluster config)
  # enable_host_encryption = false  # Can be enabled if supported in region
  # enable_node_public_ip  = false  # Controlled by subnet configuration

  # Node labels and taints
  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "nodepoolos"    = "linux"
  }

  # Security and compliance
  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.common_tags
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.enable_aks && var.enable_container_registry ? 1 : 0
  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main[0].kubelet_identity[0].object_id
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
