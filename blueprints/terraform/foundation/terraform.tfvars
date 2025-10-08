environment               = "sandbox"
organization_prefix       = "alz"
location                  = "westeurope"
hub_vnet_address_space    = "10.0.0.0/16"
spoke_vnet_address_space  = "10.1.0.0/16"
enable_container_registry = true
enable_app_workloads      = false
enable_bastion            = false

# AKS Configuration (enabled for deployment with approved VM sizes)
enable_aks                 = true
aks_kubernetes_version     = "1.30.14"
aks_system_node_count      = 2
aks_system_node_size       = "Standard_d4s_v5" # Approved enterprise VM size (recommended)
enable_aks_user_node_pool  = true
aks_user_node_count        = 2
aks_user_node_size         = "Standard_d4s_v5" # Approved enterprise VM size (consistent)
aks_admin_group_object_ids = []                # Will use cluster admin for this demo
