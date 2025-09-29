# Variables for Azure Landing Zone - Terraform Implementation
# Aligned with AVM Bicep Sub-vending Pattern

# Environment and Naming Variables
variable "environment" {
  description = "The environment name for resource tagging and naming"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "workload_name" {
  description = "The workload name for resource tagging"
  type        = string
  default     = "landingzone"

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.workload_name))
    error_message = "Workload name must be 1-10 characters, lowercase letters and numbers only."
  }
}

variable "location" {
  description = "The primary Azure region for deployment"
  type        = string
  default     = "westeurope"
}

# Virtual Network Configuration
variable "virtual_network_enabled" {
  description = "Whether to create a Virtual Network"
  type        = bool
  default     = true
}

variable "virtual_network_address_prefix" {
  description = "The address prefix for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.virtual_network_address_prefix, 0))
    error_message = "Virtual network address prefix must be a valid CIDR block."
  }
}

# Key Vault Configuration
variable "key_vault_enabled" {
  description = "Whether to deploy Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_name_prefix" {
  description = "The name prefix for the Key Vault"
  type        = string
  default     = "kv-avm-lz"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,10}$", var.key_vault_name_prefix))
    error_message = "Key Vault name prefix must start with a letter, be 2-11 characters, and contain only letters, numbers, and hyphens."
  }
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for resources"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoints for Key Vault"
  type        = bool
  default     = false
}

# Role Assignments Configuration
variable "role_assignments" {
  description = "Array of role assignments for Key Vault"
  type = list(object({
    role_definition_name = string
    principal_id         = string
    description          = string
  }))
  default = []

  validation {
    condition = alltrue([
      for ra in var.role_assignments :
      contains([
        "Key Vault Administrator",
        "Key Vault Certificates Officer",
        "Key Vault Crypto Officer",
        "Key Vault Crypto Service Encryption User",
        "Key Vault Crypto User",
        "Key Vault Reader",
        "Key Vault Secrets Officer",
        "Key Vault Secrets User"
      ], ra.role_definition_name)
    ])
    error_message = "Role definition name must be a valid Key Vault RBAC role."
  }
}

# Additional Configuration Variables
