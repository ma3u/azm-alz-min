# Example configuration for deploying ALZ with AKS
# Copy this to terraform.tfvars and customize as needed

environment              = "sandbox"
organization_prefix      = "alz"
location                 = "westeurope"
hub_vnet_address_space   = "10.0.0.0/16"
spoke_vnet_address_space = "10.1.0.0/16"

# Core services
enable_container_registry = true  # Required for AKS image storage
enable_app_workloads      = true  # Optional web app and storage
enable_bastion            = false # Cost optimization

# AKS Configuration - Enable for Kubernetes workloads
enable_aks                = true # ⚠️ ADDS ~$150/month cost!
aks_kubernetes_version    = "1.28"
aks_system_node_count     = 2                 # System node pool (required)
aks_system_node_size      = "Standard_D2s_v3" # 2 vCPUs, 8GB RAM
enable_aks_user_node_pool = true              # User workloads (recommended)
aks_user_node_count       = 2                 # User node pool size
aks_user_node_size        = "Standard_D2s_v3" # Match system nodes for consistency

# Azure AD Integration (REQUIRED for AKS)
# Get your group object IDs with: az ad group list --display-name "your-group-name" --query "[].id" -o tsv
aks_admin_group_object_ids = [
  # "12345678-1234-5678-9012-123456789012"  # Replace with your Azure AD group ID
]

# DEPLOYMENT NOTES:
# 1. Total monthly cost: ~$200 (AKS nodes + ACR + monitoring)
# 2. AKS will be deployed as a private cluster in the spoke VNet
# 3. Automatic integration with Log Analytics and Microsoft Defender
# 4. ACR integration with AcrPull role assignment
# 5. Auto-scaling enabled: 1-5 system nodes, 1-10 user nodes
# 6. VM sizes must comply with enterprise governance (Dsv5/Ddsv5 series only)
