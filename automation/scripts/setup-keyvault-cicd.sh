#!/bin/bash
# Azure Key Vault CI/CD Setup Script
# Sets up Azure Key Vault with service principals and secrets for GitHub Actions and Azure DevOps

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Default values
ENVIRONMENT="sandbox"
LOCATION="westeurope"
RESOURCE_GROUP="rg-alz-cicd-${ENVIRONMENT}"
KEY_VAULT_PREFIX="kv-alz-cicd"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first (brew install jq on macOS)."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to create resource group
create_resource_group() {
    print_status "Creating resource group: $RESOURCE_GROUP"

    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group $RESOURCE_GROUP already exists"
    else
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags Environment="$ENVIRONMENT" \
                   Purpose="CI/CD" \
                   CostCenter="IT-Infrastructure" \
                   Owner="DevOps-Team"
        print_success "Resource group created successfully"
    fi
}

# Function to deploy Key Vault using Bicep template
deploy_key_vault() {
    print_status "Deploying Azure Key Vault using Bicep template..."

    # Generate unique Key Vault name
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    UNIQUE_SUFFIX=$(echo -n "${SUBSCRIPTION_ID}${RESOURCE_GROUP}" | sha256sum | cut -c1-8)
    KEY_VAULT_NAME="${KEY_VAULT_PREFIX}-${UNIQUE_SUFFIX}"

    # Ensure Key Vault name is within limits (24 characters max)
    if [ ${#KEY_VAULT_NAME} -gt 24 ]; then
        KEY_VAULT_NAME="${KEY_VAULT_PREFIX:0:15}-${UNIQUE_SUFFIX}"
    fi

    print_status "Key Vault name: $KEY_VAULT_NAME"

    # Create parameters file for Bicep deployment
    cat > "/tmp/keyvault-cicd-${TIMESTAMP}.parameters.json" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "keyVaultName": {
      "value": "$KEY_VAULT_NAME"
    },
    "location": {
      "value": "$LOCATION"
    },
    "environment": {
      "value": "$ENVIRONMENT"
    },
    "enabledForDeployment": {
      "value": true
    },
    "enabledForTemplateDeployment": {
      "value": true
    },
    "enabledForDiskEncryption": {
      "value": true
    },
    "enableSoftDelete": {
      "value": true
    },
    "enablePurgeProtection": {
      "value": false
    },
    "skuName": {
      "value": "standard"
    },
    "networkAcls": {
      "value": {
        "bypass": "AzureServices",
        "defaultAction": "Allow"
      }
    }
  }
}
EOF

    # Deploy using existing Bicep template
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$PROJECT_ROOT/infra/main.bicep" \
        --parameters @"/tmp/keyvault-cicd-${TIMESTAMP}.parameters.json" \
        --name "keyvault-cicd-${TIMESTAMP}"

    # Clean up temporary parameters file
    rm "/tmp/keyvault-cicd-${TIMESTAMP}.parameters.json"

    print_success "Key Vault deployed successfully: $KEY_VAULT_NAME"
    echo "$KEY_VAULT_NAME" > "$PROJECT_ROOT/.secrets/keyvault-name.txt"
}

# Function to create service principal for GitHub Actions
create_github_service_principal() {
    print_status "Creating service principal for GitHub Actions..."

    SP_NAME="sp-alz-github-actions-${ENVIRONMENT}"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    # Create service principal
    SP_JSON=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role "Contributor" \
        --scopes "/subscriptions/$SUBSCRIPTION_ID" \
        --sdk-auth)

    # Extract service principal details
    SP_CLIENT_ID=$(echo "$SP_JSON" | jq -r '.clientId')
    SP_CLIENT_SECRET=$(echo "$SP_JSON" | jq -r '.clientSecret')
    SP_TENANT_ID=$(echo "$SP_JSON" | jq -r '.tenantId')

    print_success "GitHub Actions service principal created: $SP_CLIENT_ID"

    # Store credentials in Key Vault
    KEY_VAULT_NAME=$(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "github-sp-client-id" \
        --value "$SP_CLIENT_ID"

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "github-sp-client-secret" \
        --value "$SP_CLIENT_SECRET"

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "github-sp-tenant-id" \
        --value "$SP_TENANT_ID"

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "azure-subscription-id" \
        --value "$SUBSCRIPTION_ID"

    # Save complete JSON for GitHub repository secret
    echo "$SP_JSON" > "$PROJECT_ROOT/.secrets/github-azure-credentials.json"

    print_success "GitHub Actions credentials stored in Key Vault"
}

# Function to create service principal for Azure DevOps
create_devops_service_principal() {
    print_status "Creating service principal for Azure DevOps..."

    SP_NAME="sp-alz-azure-devops-${ENVIRONMENT}"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    # Create service principal
    SP_JSON=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role "Contributor" \
        --scopes "/subscriptions/$SUBSCRIPTION_ID")

    # Extract service principal details
    SP_CLIENT_ID=$(echo "$SP_JSON" | jq -r '.appId')
    SP_CLIENT_SECRET=$(echo "$SP_JSON" | jq -r '.password')
    SP_TENANT_ID=$(echo "$SP_JSON" | jq -r '.tenant')

    print_success "Azure DevOps service principal created: $SP_CLIENT_ID"

    # Store credentials in Key Vault
    KEY_VAULT_NAME=$(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "devops-sp-client-id" \
        --value "$SP_CLIENT_ID"

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "devops-sp-client-secret" \
        --value "$SP_CLIENT_SECRET"

    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "devops-sp-tenant-id" \
        --value "$SP_TENANT_ID"

    print_success "Azure DevOps credentials stored in Key Vault"
}

# Function to store SSH keys in Key Vault
store_ssh_keys() {
    print_status "Storing SSH keys in Key Vault..."

    KEY_VAULT_NAME=$(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")
    SSH_PRIVATE_KEY_PATH="$PROJECT_ROOT/.secrets/azure-alz-key"
    SSH_PUBLIC_KEY_PATH="$PROJECT_ROOT/.secrets/azure-alz-key.pub"

    if [[ -f "$SSH_PRIVATE_KEY_PATH" && -f "$SSH_PUBLIC_KEY_PATH" ]]; then
        # Store SSH private key
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "ssh-private-key" \
            --file "$SSH_PRIVATE_KEY_PATH"

        # Store SSH public key
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "ssh-public-key" \
            --file "$SSH_PUBLIC_KEY_PATH"

        print_success "SSH keys stored in Key Vault"
    else
        print_warning "SSH keys not found in .secrets/ directory. Skipping..."
        print_status "Run this to generate SSH keys: ssh-keygen -t rsa -b 4096 -f .secrets/azure-alz-key -N ''"
    fi
}

# Function to set Key Vault access policies
configure_access_policies() {
    print_status "Configuring Key Vault access policies..."

    KEY_VAULT_NAME=$(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")

    # Get current user's object ID
    CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)

    # Grant current user full access
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --object-id "$CURRENT_USER_ID" \
        --secret-permissions all \
        --key-permissions all \
        --certificate-permissions all

    print_success "Access policies configured successfully"
}

# Function to create environment-specific configuration
create_environment_config() {
    print_status "Creating environment configuration file..."

    KEY_VAULT_NAME=$(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)

    cat > "$PROJECT_ROOT/.secrets/cicd-config.json" << EOF
{
  "environment": "$ENVIRONMENT",
  "azure": {
    "subscriptionId": "$SUBSCRIPTION_ID",
    "tenantId": "$TENANT_ID",
    "resourceGroup": "$RESOURCE_GROUP",
    "keyVaultName": "$KEY_VAULT_NAME",
    "location": "$LOCATION"
  },
  "github": {
    "secrets": {
      "AZURE_CREDENTIALS": "Complete SP JSON from github-azure-credentials.json",
      "AZURE_SUBSCRIPTION_ID": "$SUBSCRIPTION_ID",
      "AZURE_TENANT_ID": "$TENANT_ID",
      "KEY_VAULT_NAME": "$KEY_VAULT_NAME"
    }
  },
  "azureDevOps": {
    "serviceConnection": {
      "subscriptionId": "$SUBSCRIPTION_ID",
      "tenantId": "$TENANT_ID",
      "clientId": "Retrieved from devops-sp-client-id secret",
      "clientSecret": "Retrieved from devops-sp-client-secret secret" # pragma: allowlist secret
    }
  }
}
EOF

    print_success "Environment configuration created: .secrets/cicd-config.json"
}

# Function to display setup summary
display_summary() {
    print_success "Azure Key Vault CI/CD setup completed successfully!"
    echo ""
    print_status "Summary:"
    echo "  • Resource Group: $RESOURCE_GROUP"
    echo "  • Key Vault: $(cat "$PROJECT_ROOT/.secrets/keyvault-name.txt")"
    echo "  • Environment: $ENVIRONMENT"
    echo "  • Location: $LOCATION"
    echo ""
    print_status "Next steps:"
    echo "  1. Configure GitHub repository secrets using .secrets/github-azure-credentials.json"
    echo "  2. Set up Azure DevOps service connection using details in .secrets/cicd-config.json"
    echo "  3. Run GitHub Actions and Azure DevOps pipelines to test integration"
    echo ""
    print_warning "Security reminder:"
    echo "  • Keep .secrets/ directory secure and never commit to git"
    echo "  • Rotate service principal credentials regularly"
    echo "  • Monitor Key Vault access logs for suspicious activity"
}

# Main execution
main() {
    print_status "Starting Azure Key Vault CI/CD setup..."

    check_prerequisites
    create_resource_group
    deploy_key_vault
    create_github_service_principal
    create_devops_service_principal
    store_ssh_keys
    configure_access_policies
    create_environment_config
    display_summary
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment     Environment name (default: sandbox)"
            echo "  -l, --location        Azure region (default: westeurope)"
            echo "  -r, --resource-group  Resource group name (default: rg-alz-cicd-{environment})"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option $1"
            exit 1
            ;;
    esac
done

# Execute main function
main
