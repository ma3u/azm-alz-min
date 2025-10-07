# Private AKS Cluster Access Guide

## 🔐 Overview

This guide provides comprehensive instructions for accessing your private Azure Kubernetes Service (AKS) cluster deployed with this Terraform configuration. Since the cluster is configured as a private cluster, the API server endpoint has no public IP address and special connectivity is required.

## 📊 Cluster Configuration Details

Your AKS cluster is deployed with the following private cluster settings:

```hcl
private_cluster_enabled             = true
private_cluster_public_fqdn_enabled = false
private_dns_zone_id                 = "System"
```

**Key Information:**

- **Cluster Name**: `aks-alz-sandbox-<unique-suffix>`
- **Resource Group**: `rg-alz-spoke-sandbox`
- **VNet**: `vnet-alz-spoke-sandbox` (10.1.0.0/16)
- **AKS Subnet**: `snet-aks` (10.1.20.0/22)
- **Private FQDN**: `<cluster-name>-<random>.privatelink.westeurope.azmk8s.io`

## 🚀 Access Methods

### Option 1: Create Jump VM in Same VNet (Recommended)

This is the easiest and most secure method for accessing your private AKS cluster.

#### Step 1: Create the Jump VM

```bash
# Set variables
RESOURCE_GROUP="rg-alz-spoke-sandbox"
VM_NAME="vm-aks-jumpbox"
VNET_NAME="vnet-alz-spoke-sandbox"
SUBNET_NAME="snet-private-endpoints"
LOCATION="westeurope"

# Create the VM
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_B2s \
  --location $LOCATION \
  --tags "Environment=sandbox" "Purpose=AKS-Access" "DeployedBy=GithubAction-Sandbox"
```

#### Step 2: Install Required Tools on Jump VM

```bash
# SSH into the VM
az vm run-command invoke \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --command-id RunShellScript \
  --scripts '
    # Update system
    sudo apt-get update

    # Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install helm (optional)
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
  '
```

#### Step 3: Get AKS Credentials

```bash
# SSH into the VM
ssh azureuser@$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)

# On the VM, login to Azure
az login

# Set subscription if needed
az account set --subscription "fdf79377-e045-462f-ac4a-630ddee7e4c3"

# Get AKS credentials
az aks get-credentials \
  --resource-group rg-alz-spoke-sandbox \
  --name $(az aks list -g rg-alz-spoke-sandbox --query "[0].name" -o tsv) \
  --admin

# Test connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Option 2: AKS Command Invoke Feature

Use Azure's built-in command invoke feature to run kubectl commands without direct cluster access.

#### Basic Commands

```bash
# Get cluster name
CLUSTER_NAME=$(az aks list -g rg-alz-spoke-sandbox --query "[0].name" -o tsv)

# Get nodes
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl get nodes -o wide"

# Get pods in all namespaces
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl get pods --all-namespaces"

# Get cluster info
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl cluster-info"
```

#### Deploy Test Application

```bash
# Create test deployment
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl create deployment nginx --image=nginx:latest"

# Expose as service
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl expose deployment nginx --port=80 --type=ClusterIP"

# Check status
az aks command invoke \
  --resource-group rg-alz-spoke-sandbox \
  --name $CLUSTER_NAME \
  --command "kubectl get pods,svc -o wide"
```

### Option 3: Virtual Network Peering

Set up peering between your management network and the AKS VNet.

#### Prerequisites

- You have a management VNet in the same region
- Non-overlapping IP address ranges
- Proper DNS configuration

#### Setup Peering

```bash
# Variables for your management VNet
MGMT_VNET_NAME="vnet-management"
MGMT_RESOURCE_GROUP="rg-management"
MGMT_VNET_ID="/subscriptions/your-subscription/resourceGroups/rg-management/providers/Microsoft.Network/virtualNetworks/vnet-management"

# Variables for AKS VNet
AKS_VNET_NAME="vnet-alz-spoke-sandbox"
AKS_RESOURCE_GROUP="rg-alz-spoke-sandbox"
AKS_VNET_ID="/subscriptions/fdf79377-e045-462f-ac4a-630ddee7e4c3/resourceGroups/rg-alz-spoke-sandbox/providers/Microsoft.Network/virtualNetworks/vnet-alz-spoke-sandbox"

# Create peering from management to AKS VNet
az network vnet peering create \
  --resource-group $MGMT_RESOURCE_GROUP \
  --vnet-name $MGMT_VNET_NAME \
  --name "peer-mgmt-to-aks" \
  --remote-vnet $AKS_VNET_ID \
  --allow-forwarded-traffic

# Create peering from AKS VNet to management
az network vnet peering create \
  --resource-group $AKS_RESOURCE_GROUP \
  --vnet-name $AKS_VNET_NAME \
  --name "peer-aks-to-mgmt" \
  --remote-vnet $MGMT_VNET_ID \
  --allow-forwarded-traffic
```

#### Configure DNS (Required for Private Cluster)

```bash
# Get the private DNS zone resource ID
PRIVATE_DNS_ZONE_ID=$(az network private-dns zone list \
  --resource-group rg-alz-spoke-sandbox \
  --query "[?contains(name, 'privatelink')].id" -o tsv)

# Link management VNet to private DNS zone
az network private-dns link vnet create \
  --resource-group rg-alz-spoke-sandbox \
  --zone-name $(az network private-dns zone list -g rg-alz-spoke-sandbox --query "[0].name" -o tsv) \
  --name "management-vnet-link" \
  --virtual-network $MGMT_VNET_ID \
  --registration-enabled false
```

### Option 4: Azure Bastion Access

If you have Azure Bastion enabled in your hub VNet, you can use it to access the jump VM securely.

```bash
# Enable bastion in terraform.tfvars
echo 'enable_bastion = true' >> terraform.tfvars

# Apply terraform changes
terraform plan
terraform apply

# Use Bastion to connect to jump VM through Azure portal
# Navigate to: Azure Portal > Virtual Machines > vm-aks-jumpbox > Connect > Bastion
```

## 📋 Verification Commands

Once connected, verify your AKS cluster status:

### Basic Health Checks

```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes -o wide

# System pods
kubectl get pods -n kube-system

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Test Connectivity to Azure Services

```bash
# Test ACR connectivity (from within cluster)
kubectl run test-acr --image=nginx --rm -it -- bash
# Inside container:
# nslookup acralzsandboxxoi9q02m.azurecr.io

# Test Log Analytics integration
kubectl logs -n kube-system -l component=oms-agent
```

### Deploy Sample Application

```bash
# Create test namespace
kubectl create namespace test-app

# Deploy nginx
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: test-app
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Verify deployment
kubectl get all -n test-app
```

## 🔧 Troubleshooting

### Common Issues

#### DNS Resolution Problems

```bash
# Check DNS from jump VM
nslookup your-cluster-name.privatelink.westeurope.azmk8s.io

# Test from inside cluster
kubectl run dns-test --image=busybox --rm -it -- nslookup kubernetes.default.svc.cluster.local
```

#### Authentication Issues

```bash
# Check current context
kubectl config current-context

# View available contexts
kubectl config get-contexts

# Switch context if needed
kubectl config use-context your-cluster-name-admin
```

#### Network Connectivity

```bash
# Check routes from jump VM
ip route show

# Test connectivity to API server
telnet your-cluster-private-fqdn 443

# Check Azure service connectivity
curl -I https://management.azure.com
```

### Useful Azure CLI Commands

```bash
# Get cluster details
az aks show -g rg-alz-spoke-sandbox -n $CLUSTER_NAME --output table

# Check node pool status
az aks nodepool list -g rg-alz-spoke-sandbox --cluster-name $CLUSTER_NAME -o table

# View recent operations
az aks get-credentials -g rg-alz-spoke-sandbox -n $CLUSTER_NAME --admin --overwrite-existing

# Scale node pool
az aks nodepool scale -g rg-alz-spoke-sandbox --cluster-name $CLUSTER_NAME --name user --node-count 3
```

## 🛡️ Security Best Practices

1. **Access Control**: Use Azure AD integration for RBAC
2. **Network Security**: Implement network policies
3. **Image Security**: Scan container images in ACR
4. **Monitoring**: Enable Azure Monitor for containers
5. **Secrets Management**: Use Azure Key Vault integration

## 📊 Monitoring and Maintenance

### View Logs

```bash
# Pod logs
kubectl logs -f deployment/nginx-deployment -n test-app

# System component logs
kubectl logs -n kube-system -l component=coredns

# Audit logs (via Azure Monitor)
az monitor log-analytics query \
  --workspace $(az aks show -g rg-alz-spoke-sandbox -n $CLUSTER_NAME --query "addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID" -o tsv) \
  --analytics-query "ContainerLog | limit 100"
```

### Regular Maintenance

```bash
# Update node images
az aks nodepool upgrade -g rg-alz-spoke-sandbox --cluster-name $CLUSTER_NAME --name system --node-image-only

# Check for available updates
az aks get-upgrades -g rg-alz-spoke-sandbox -n $CLUSTER_NAME

# Perform cluster upgrade (when ready)
az aks upgrade -g rg-alz-spoke-sandbox -n $CLUSTER_NAME --kubernetes-version 1.27.15
```

## 🔗 Additional Resources

- [AKS Private Clusters Documentation](https://docs.microsoft.com/en-us/azure/aks/private-clusters)
- [AKS Command Invoke Documentation](https://docs.microsoft.com/en-us/azure/aks/command-invoke)
- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview)
- [Virtual Network Peering](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)

---

**📝 Note**: This guide assumes you have appropriate Azure permissions and the AKS cluster has been successfully deployed via the GitHub Actions workflow.
