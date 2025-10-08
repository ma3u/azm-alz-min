variable "location" {
  description = "Primary Azure region for deployment"
  type        = string
  default     = "westeurope"

  validation {
    condition = contains([
      "westeurope", "northeurope", "eastus", "eastus2", "westus", "westus2", "westus3",
      "centralus", "northcentralus", "southcentralus", "westcentralus",
      "canadacentral", "canadaeast", "brazilsouth", "uksouth", "ukwest",
      "francecentral", "francesouth", "germanywestcentral", "norwayeast",
      "switzerlandnorth", "switzerlandwest", "swedencentral", "australiaeast",
      "australiasoutheast", "eastasia", "southeastasia", "japaneast",
      "japanwest", "koreacentral", "koreasouth", "southindia", "centralindia",
      "westindia", "uaenorth", "southafricanorth"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "sandbox"

  validation {
    condition     = contains(["sandbox", "dev", "test"], var.environment)
    error_message = "Environment must be one of: sandbox, dev, test."
  }
}

variable "organization_prefix" {
  description = "Organization prefix for naming"
  type        = string
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.organization_prefix))
    error_message = "Organization prefix must be 2-10 lowercase alphanumeric characters."
  }
}

variable "hub_vnet_address_space" {
  description = "Hub Virtual Network address space"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.hub_vnet_address_space, 0))
    error_message = "Hub VNet address space must be a valid CIDR block."
  }
}

variable "spoke_vnet_address_space" {
  description = "Spoke Virtual Network address space"
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.spoke_vnet_address_space, 0))
    error_message = "Spoke VNet address space must be a valid CIDR block."
  }
}

variable "enable_bastion" {
  description = "Enable Azure Bastion in hub"
  type        = bool
  default     = false
}

variable "enable_app_workloads" {
  description = "Enable application workloads"
  type        = bool
  default     = true
}

variable "enable_container_registry" {
  description = "Enable Azure Container Registry in hub"
  type        = bool
  default     = true
}

# =======================
# AKS CONFIGURATION
# =======================

variable "enable_aks" {
  description = "Enable Azure Kubernetes Service in spoke"
  type        = bool
  default     = false
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.28"

  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.aks_kubernetes_version))
    error_message = "Kubernetes version must be 1.24 or higher."
  }
}

variable "aks_system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2

  validation {
    condition     = var.aks_system_node_count >= 1 && var.aks_system_node_count <= 5
    error_message = "System node count must be between 1 and 5."
  }
}

variable "aks_system_node_size" {
  description = "VM size for system node pool (must use approved enterprise sizes)"
  type        = string
  default     = "Standard_d4s_v5" # Recommended for new creation

  validation {
    condition = contains([
      # Dsv5 Series - Approved VM sizes
      "Standard_d2s_v5", "Standard_d4s_v5", "Standard_d8s_v5",
      "Standard_d16s_v5", "Standard_d32s_v5",
      # Ddsv5 Series - Approved VM sizes with cache disk
      "Standard_d2ds_v5", "Standard_d4ds_v5", "Standard_d8ds_v5",
      "Standard_d16ds_v5", "Standard_d32ds_v5"
    ], var.aks_system_node_size)
    error_message = "System node size must be an approved enterprise VM size (Dsv5 or Ddsv5 series only)."
  }
}

variable "enable_aks_user_node_pool" {
  description = "Enable user node pool for application workloads"
  type        = bool
  default     = true
}

variable "aks_user_node_count" {
  description = "Number of nodes in the user node pool"
  type        = number
  default     = 2

  validation {
    condition     = var.aks_user_node_count >= 1 && var.aks_user_node_count <= 10
    error_message = "User node count must be between 1 and 10."
  }
}

variable "aks_user_node_size" {
  description = "VM size for user node pool (must use approved enterprise sizes)"
  type        = string
  default     = "Standard_d4s_v5" # Recommended for new creation

  validation {
    condition = contains([
      # Dsv5 Series - Approved VM sizes
      "Standard_d2s_v5", "Standard_d4s_v5", "Standard_d8s_v5",
      "Standard_d16s_v5", "Standard_d32s_v5",
      # Ddsv5 Series - Approved VM sizes with cache disk
      "Standard_d2ds_v5", "Standard_d4ds_v5", "Standard_d8ds_v5",
      "Standard_d16ds_v5", "Standard_d32ds_v5"
    ], var.aks_user_node_size)
    error_message = "User node size must be an approved enterprise VM size (Dsv5 or Ddsv5 series only)."
  }
}

variable "aks_admin_group_object_ids" {
  description = "Object IDs of Azure AD groups that should have admin access to AKS"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.aks_admin_group_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "All admin group object IDs must be valid UUIDs."
  }
}

variable "enable_rbac_assignments" {
  description = "Enable RBAC role assignments (may require elevated permissions)"
  type        = bool
  default     = false # Disabled by default for sandbox environments
}
