# Blueprints - Production-Ready Templates

This directory contains **production-ready Azure Landing Zone templates** that have been tested and validated.

## 📁 Structure

```
blueprints/
├── bicep/
│   ├── foundation/     # Basic ALZ setup
│   ├── hub-spoke/      # Network topology
│   └── enterprise/     # Full-scale ALZ (future)
└── terraform/
    └── foundation/     # Terraform equivalent
```

## ✅ Available Templates

### Bicep Templates

#### Foundation (`bicep/foundation/`)

- **File**: `main.bicep`
- **Use Case**: Basic Azure Landing Zone setup
- **Features**: Key Vault, Virtual Network, Log Analytics
- **Cost**: ~$15/month
- **Deployment Time**: 5-10 minutes

```bash
az deployment sub create \
  --location westeurope \
  --template-file blueprints/bicep/foundation/main.bicep \
  --parameters blueprints/bicep/foundation/main.parameters.json
```

#### Hub-Spoke (`bicep/hub-spoke/`)

- **File**: `main.bicep`
- **Use Case**: Network topology with hub-spoke design
- **Features**: Hub-spoke networking, Azure Container Registry, Bastion
- **Cost**: ~$25/month
- **Deployment Time**: 10-15 minutes

```bash
az deployment sub create \
  --location westeurope \
  --template-file blueprints/bicep/hub-spoke/main.bicep \
  --parameters blueprints/bicep/hub-spoke/main.parameters.json
```

### Terraform Templates

#### Foundation (`terraform/foundation/`)

- **Use Case**: Terraform equivalent of Bicep foundation
- **Features**: Same as Bicep foundation template
- **Prerequisites**: Terraform 1.6+

```bash
cd blueprints/terraform/foundation/
terraform init
terraform plan
terraform apply
```

## 🔍 Validation

All templates in this directory:

- ✅ Compile without errors
- ✅ Pass security scans
- ✅ Use latest AVM modules
- ✅ Follow Azure naming conventions
- ✅ Include proper documentation

## 📚 Documentation

For detailed deployment guides, see [documentation/content/](../documentation/content/).
