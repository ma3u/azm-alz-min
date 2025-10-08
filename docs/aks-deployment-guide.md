# AKS Deployment Guide for Azure Landing Zone

[![AKS Deployment](https://img.shields.io/badge/Deployment-Ready-green.svg)](https://docs.microsoft.com/en-us/azure/aks/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-blue.svg)](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
[![Private Cluster](https://img.shields.io/badge/Security-Private%20Cluster-orange.svg)](https://docs.microsoft.com/en-us/azure/aks/private-clusters)

## Overview

This guide provides step-by-step instructions for deploying Azure Kubernetes Service (AKS) within the Azure Landing Zone framework using Terraform. The deployment creates a production-ready, secure AKS cluster with enterprise features and policy compliance.

## Prerequisites

### Required Tools

```bash
# Azure CLI (version 2.50+)
az version

# Terraform (version 1.5+)
terraform version

# kubectl (latest stable)
kubectl version --client

# Optional: Helm for package management
helm version
```

### Required Permissions

- **Subscription Contributor**: For resource creation
- **Network Contributor**: For VNet integration
- **User Access Administrator**: For RBAC assignments

### Azure Quotas

Verify sufficient quotas for your deployment:

```bash
# Check VM quotas (need at least 8 vCPUs for default configuration)
az vm list-usage --location westeurope --query "[?localName=='Standard Dsv5 Family vCPUs']"

# Check public IP quotas (needed for load balancers)
az network list-usages --location westeurope --query "[?localName=='Public IP Addresses - Standard']"
```

## Quick Deployment

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/ma3u/azm-alz-min.git
cd azm-alz-min/blueprints/terraform/foundation

# Copy and edit configuration
cp terraform-aks-example.tfvars terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` with your specific settings:

```hcl
# Basic Configuration
location            = "westeurope"
environment         = "sandbox"
organization_prefix = "contoso"

# AKS Configuration
enable_aks                = true
aks_kubernetes_version    = "1.30"
aks_system_node_count     = 2
aks_system_node_size      = "Standard_d4s_v5"
enable_aks_user_node_pool = true
aks_user_node_count       = 2
aks_user_node_size        = "Standard_d4s_v5"

# Supporting Services
enable_container_registry = true
enable_app_workloads      = false  # Disable to focus on AKS
enable_bastion            = false  # Cost optimization
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment (review changes)
terraform plan -var-file="terraform.tfvars" -out="tfplan"

# Apply configuration
terraform apply tfplan
```

### 4. Configure kubectl Access

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --name aks-contoso-tf-sandbox-12345678 \
  --admin

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

## Detailed Configuration

### Network Configuration

The AKS deployment uses Azure CNI networking with the following configuration:

```hcl
# Subnet for AKS nodes and pods
resource "azurerm_subnet" "spoke_aks" {
  name                 = "snet-aks"
  address_prefixes     = ["10.1.20.0/22"]  # 1024 IPs
}

# Network profile for AKS
network_profile {
  network_plugin    = "azure"      # Azure CNI
  network_policy    = "azure"      # Network policies
  dns_service_ip    = "10.2.0.10"  # DNS service IP
  service_cidr      = "10.2.0.0/16" # Services CIDR
}
```

**IP Address Planning:**

- **Node IPs**: Allocated from VNet subnet (10.1.20.0/22)
- **Pod IPs**: Allocated from VNet (Azure CNI mode)
- **Service IPs**: Separate CIDR (10.2.0.0/16)
- **Load Balancer**: Uses Standard SKU with static IPs

### Security Configuration

#### Private Cluster Setup

```hcl
# Private cluster configuration
private_cluster_enabled             = true
private_cluster_public_fqdn_enabled = false
private_dns_zone_id                 = "System"
```

**Benefits:**

- No public API server endpoint
- Access only through private network
- Enhanced security for enterprise environments
- Integrated with Azure Private DNS

#### Identity and RBAC

```hcl
# Managed identity configuration
identity {
  type = "SystemAssigned"
}

# RBAC settings
role_based_access_control_enabled = true
local_account_disabled            = false  # For initial setup
```

#### Azure Container Registry Integration

```hcl
# Automatic ACR pull permission
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main[0].kubelet_identity[0].object_id
}
```

### Node Pool Configuration

#### System Node Pool

```hcl
default_node_pool {
  name                         = "system"
  node_count                   = 2
  vm_size                      = "Standard_d4s_v5"
  auto_scaling_enabled         = true
  min_count                    = 1
  max_count                    = 5
  only_critical_addons_enabled = true  # System workloads only
}
```

#### User Node Pool

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  vm_size               = "Standard_d4s_v5"
  node_count            = 2
  auto_scaling_enabled  = true
  min_count             = 1
  max_count             = 10
}
```

### Monitoring and Logging

```hcl
# Container Insights integration
oms_agent {
  log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
  msi_auth_for_monitoring_enabled = true
}
```

## Post-Deployment Configuration

### 1. Verify Cluster Status

```bash
# Check cluster information
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Verify storage classes
kubectl get storageclass
```

### 2. Test Private Networking

```bash
# Test ACR connectivity
kubectl run test-acr --image=nginx --restart=Never --dry-run=client -o yaml > test-pod.yaml

# Edit test-pod.yaml to use your ACR image
kubectl apply -f test-pod.yaml

# Check if image pulls successfully
kubectl describe pod test-acr
kubectl delete pod test-acr
```

### 3. Configure Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s

# Get external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### 4. Set Up Monitoring

```bash
# Verify Container Insights is working
az aks show -g rg-contoso-tf-spoke-sandbox -n aks-contoso-tf-sandbox-12345678 --query addonProfiles.omsAgent

# Check Log Analytics workspace
az monitor log-analytics workspace show --resource-group rg-contoso-tf-hub-sandbox --workspace-name log-contoso-tf-hub-sandbox
```

## Application Deployment Examples

### 1. Simple Web Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: nginx:1.21
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: '64Mi'
              cpu: '250m'
            limits:
              memory: '128Mi'
              cpu: '500m'
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: webapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp-service
                port:
                  number: 80
```

### 2. Application with Persistent Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
    spec:
      containers:
        - name: app
          image: postgres:13
          env:
            - name: POSTGRES_PASSWORD
              value: 'your-secure-password' # pragma: allowlist secret
          volumeMounts:
            - name: data-volume
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: '256Mi'
              cpu: '500m'
            limits:
              memory: '512Mi'
              cpu: '1000m'
      volumes:
        - name: data-volume
          persistentVolumeClaim:
            claimName: data-storage
```

### 3. Using Azure Key Vault Secrets

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: 'false'
    useVMManagedIdentity: 'true'
    userAssignedIdentityID: ''
    keyvaultName: 'kv-contoso-sb-12345678'
    cloudName: ''
    objects: |
      array:
        - |
          objectName: database-password # pragma: allowlist secret
          objectType: secret # pragma: allowlist secret
          objectVersion: ""
    tenantId: 'your-tenant-id'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      serviceAccountName: workload-identity-sa
      containers:
        - name: app
          image: your-app:latest
          volumeMounts:
            - name: secrets-store # pragma: allowlist secret
              mountPath: '/mnt/secrets-store' # pragma: allowlist secret
              readOnly: true
          env:
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef: # pragma: allowlist secret
                  name: database-password # pragma: allowlist secret
                  key: password # pragma: allowlist secret
      volumes:
        - name: secrets-store # pragma: allowlist secret
          csi:
            driver: secrets-store.csi.k8s.io # pragma: allowlist secret
            readOnly: true
            volumeAttributes:
              secretProviderClass: 'app-secrets' # pragma: allowlist secret
```

## Scaling and Performance

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Cluster Autoscaling

```bash
# View current autoscaler configuration
kubectl describe configmap cluster-autoscaler-status -n kube-system

# Check autoscaler logs
kubectl logs deployment/cluster-autoscaler -n kube-system

# Update node pool scaling limits
az aks nodepool update \
  --cluster-name aks-contoso-tf-sandbox-12345678 \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --name user \
  --min-count 2 \
  --max-count 20 \
  --enable-cluster-autoscaler
```

## Maintenance and Updates

### Kubernetes Version Upgrades

```bash
# Check available upgrades
az aks get-upgrades \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --name aks-contoso-tf-sandbox-12345678

# Upgrade cluster (control plane)
az aks upgrade \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --name aks-contoso-tf-sandbox-12345678 \
  --kubernetes-version 1.30.5 \
  --no-wait

# Upgrade node pools
az aks nodepool upgrade \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --cluster-name aks-contoso-tf-sandbox-12345678 \
  --name system \
  --kubernetes-version 1.30.5 \
  --no-wait
```

### Node Pool Management

```bash
# Add new node pool
az aks nodepool add \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --cluster-name aks-contoso-tf-sandbox-12345678 \
  --name gpu \
  --node-count 1 \
  --node-vm-size Standard_NC6s_v3 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 3

# Delete old node pool
az aks nodepool delete \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --cluster-name aks-contoso-tf-sandbox-12345678 \
  --name oldpool
```

## Security Best Practices

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-webapp
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
```

### Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: '4'
    requests.memory: 8Gi
    limits.cpu: '8'
    limits.memory: 16Gi
    persistentvolumeclaims: '10'
    pods: '20'
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Cannot Access AKS API Server

```bash
# Problem: Private cluster access issues
# Solution: Check network connectivity

# Verify private DNS resolution
nslookup aks-contoso-tf-sandbox-12345678-dns-12345678.hcp.westeurope.azmk8s.io

# Alternative: Use Azure Cloud Shell
az cloud-shell

# Get credentials in Cloud Shell
az aks get-credentials --resource-group rg-contoso-tf-spoke-sandbox --name aks-contoso-tf-sandbox-12345678
```

#### 2. Pods Stuck in Pending State

```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pod details
kubectl describe pod <pod-name>
```

#### 3. Image Pull Failures

```bash
# Verify ACR integration
az aks check-acr \
  --name aks-contoso-tf-sandbox-12345678 \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --acr acr-name

# Check service principal permissions
kubectl create secret docker-registry acr-secret \ # pragma: allowlist secret
  --docker-server=acr-name.azurecr.io \
  --docker-username=service-principal-id \
  --docker-password=service-principal-password # pragma: allowlist secret
```

### Diagnostic Commands

```bash
# Cluster health
kubectl get componentstatuses

# Node status
kubectl get nodes -o wide
kubectl describe node <node-name>

# Pod logs
kubectl logs <pod-name> -f
kubectl logs <pod-name> --previous

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## Cost Optimization

### Right-sizing Recommendations

```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Use metrics server for recommendations
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Spot Instance Node Pool

```bash
# Create spot instance node pool for non-critical workloads
az aks nodepool add \
  --resource-group rg-contoso-tf-spoke-sandbox \
  --cluster-name aks-contoso-tf-sandbox-12345678 \
  --name spot \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 10 \
  --node-vm-size Standard_d4s_v5 \
  --node-taints kubernetes.azure.com/scalesetpriority=spot:NoSchedule
```

## Cleanup

### Remove Resources

```bash
# Delete specific deployments
kubectl delete deployment webapp
kubectl delete service webapp-service
kubectl delete ingress webapp-ingress

# Delete entire namespace
kubectl delete namespace production

# Destroy infrastructure (Terraform)
terraform destroy -var-file="terraform.tfvars"
```

## Next Steps

After successful AKS deployment:

1. **Set up CI/CD pipelines** for automated deployments
2. **Configure backup strategies** for persistent volumes
3. **Implement monitoring and alerting** with Azure Monitor
4. **Set up disaster recovery** plans
5. **Plan for production hardening** and security

## Related Documentation

- [AKS Configuration Guide](aks-configuration-guide.md) - Detailed configuration reference
- [Hub-Spoke Design](hub-spoke-design.md) - Overall network architecture
- [Security Best Practices](azure-sandbox-policies-overview.md) - Security guidelines
- [Cost Optimization Guide](cost-estimation-guide.md) - Cost management strategies

---

**Need Help?**

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
