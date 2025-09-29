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
