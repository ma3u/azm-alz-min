# Azure Landing Zone - Simple Sandbox Configuration
# This file contains the default values for the Terraform deployment,
# matching the Bicep parameters configuration.

# Primary configuration
location            = "westeurope"
environment         = "sandbox"
organization_prefix = "alz"

# Network configuration
hub_vnet_address_space   = "10.0.0.0/16"
spoke_vnet_address_space = "10.1.0.0/16"

# Feature flags
enable_bastion            = false # Set to true to enable Azure Bastion
enable_app_workloads      = true  # Enable web app and storage deployment
enable_container_registry = true  # Enable ACR with vulnerability scanning
