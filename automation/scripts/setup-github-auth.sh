#!/bin/bash

# GitHub Actions Authentication Setup for Limited Entra Access
# This script helps setup authentication for GitHub workflows with sandbox subscription limitations
# Author: Warp AI Assistant
# Date: 2024-09-29

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
SECRETS_DIR="${PROJECT_ROOT}/.secrets"
SERVICE_PRINCIPAL_NAME="sp-github-actions-alz-sandbox"
USER_EMAIL="matthias.buchhorn@soprasteria.com"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if GitHub CLI is installed
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI is not installed. You'll need to set secrets manually."
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it: brew install jq"
        exit 1
    fi

    # Create secrets directory
    mkdir -p "${SECRETS_DIR}"

    log_success "Prerequisites check complete"
}

# Check Azure authentication
check_azure_auth() {
    log_section "Checking Azure Authentication"

    if ! az account show &> /dev/null; then
        log_warning "Not logged into Azure. Attempting login..."

        # Login with specific tenant for Sopra Steria
        az login --tenant "8b87af7d-8647-4dc7-8df4-5f69a2011bb5" --scope "https://management.core.windows.net//.default" || {
            log_error "Azure login failed. Please run 'az login' manually first."
            exit 1
        }
    fi

    # Get current subscription info
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    CURRENT_USER=$(az account show --query user.name -o tsv)

    log_info "Current Azure Context:"
    echo "  Subscription: $SUBSCRIPTION_NAME"
    echo "  ID: $SUBSCRIPTION_ID"
    echo "  Tenant: $TENANT_ID"
    echo "  User: $CURRENT_USER"

    if [[ "$CURRENT_USER" != "$USER_EMAIL" ]]; then
        log_warning "Expected user: $USER_EMAIL, but logged in as: $CURRENT_USER"
        log_info "This might work fine, but ensure you have the right permissions."
    fi

    export SUBSCRIPTION_ID TENANT_ID SUBSCRIPTION_NAME
    log_success "Azure authentication verified"
}

# Create Service Principal with limited permissions
create_service_principal() {
    log_section "Creating Service Principal"

    log_info "Creating Service Principal: $SERVICE_PRINCIPAL_NAME"
    log_info "This will have Contributor access to your subscription for GitHub Actions"

    # Check if Service Principal already exists
    if az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query '[0].appId' -o tsv | grep -q "."; then
        log_warning "Service Principal '$SERVICE_PRINCIPAL_NAME' already exists. Retrieving existing credentials..."
        SP_APP_ID=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query '[0].appId' -o tsv)

        # Reset credentials for existing SP
        SP_PASSWORD=$(az ad sp credential reset --id "$SP_APP_ID" --query password -o tsv)
        log_info "Credentials reset for existing Service Principal"
    else
        # Create new Service Principal
        SP_CREDS=$(az ad sp create-for-rbac \
            --name "$SERVICE_PRINCIPAL_NAME" \
            --role "Contributor" \
            --scope "/subscriptions/$SUBSCRIPTION_ID" \
            --json-auth)

        SP_APP_ID=$(echo "$SP_CREDS" | jq -r '.clientId')
        SP_PASSWORD=$(echo "$SP_CREDS" | jq -r '.clientSecret')

        log_success "Service Principal created successfully"
    fi

    # Store credentials
    echo "$SP_APP_ID" > "${SECRETS_DIR}/sp-client-id.txt"
    echo "$SP_PASSWORD" > "${SECRETS_DIR}/sp-client-secret.txt"

    # Create Azure credentials JSON for GitHub Actions
    cat > "${SECRETS_DIR}/azure-credentials.json" << EOF
{
  "clientId": "$SP_APP_ID",
  "clientSecret": "$SP_PASSWORD",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID"
}
EOF

    log_success "Service Principal credentials stored in ${SECRETS_DIR}/"

    export SP_APP_ID SP_PASSWORD
}

# Test Service Principal authentication
test_service_principal() {
    log_section "Testing Service Principal Authentication"

    log_info "Testing Service Principal authentication..."

    # Test login with Service Principal
    if az login --service-principal \
        --username "$SP_APP_ID" \
        --password "$SP_PASSWORD" \
        --tenant "$TENANT_ID" &> /dev/null; then

        # Test basic operations
        if az account show &> /dev/null && az resource list --query 'length(@)' -o tsv &> /dev/null; then
            log_success "Service Principal authentication test passed"
        else
            log_error "Service Principal can login but cannot access resources"
            return 1
        fi

        # Switch back to user account
        az login --tenant "$TENANT_ID" --scope "https://management.core.windows.net//.default" &> /dev/null
    else
        log_error "Service Principal authentication test failed"
        return 1
    fi
}

# Generate GitHub secrets configuration
generate_github_secrets() {
    log_section "Generating GitHub Secrets Configuration"

    # Create a comprehensive secrets configuration
    cat > "${SECRETS_DIR}/github-secrets.json" << EOF
{
  "secrets": {
    "AZURE_CREDENTIALS": $(cat "${SECRETS_DIR}/azure-credentials.json"),
    "AZURE_SUBSCRIPTION_ID": "$SUBSCRIPTION_ID",
    "AZURE_TENANT_ID": "$TENANT_ID",
    "AZURE_CLIENT_ID": "$SP_APP_ID",
    "AZURE_CLIENT_SECRET": "$SP_PASSWORD"
  },
  "setup_instructions": {
    "manual_setup": [
      "1. Go to https://github.com/ma3u/azm-alz-min/settings/secrets/actions",
      "2. Add the following secrets:",
      "   - AZURE_CREDENTIALS: Copy the entire JSON from azure-credentials.json",
      "   - AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID",
      "   - AZURE_TENANT_ID: $TENANT_ID",
      "   - AZURE_CLIENT_ID: $SP_APP_ID",
      "   - AZURE_CLIENT_SECRET: $SP_PASSWORD"
    ],
    "github_cli_setup": [
      "If you have GitHub CLI installed, run:",
      "gh secret set AZURE_CREDENTIALS < ${SECRETS_DIR}/azure-credentials.json",
      "gh secret set AZURE_SUBSCRIPTION_ID --body '$SUBSCRIPTION_ID'",
      "gh secret set AZURE_TENANT_ID --body '$TENANT_ID'",
      "gh secret set AZURE_CLIENT_ID --body '$SP_APP_ID'",
      "gh secret set AZURE_CLIENT_SECRET --body '$SP_PASSWORD'"
    ]
  }
}
EOF

    # Create individual secret files for easy CLI usage
    echo "$SUBSCRIPTION_ID" > "${SECRETS_DIR}/subscription-id.txt"
    echo "$TENANT_ID" > "${SECRETS_DIR}/tenant-id.txt"

    log_success "GitHub secrets configuration generated"
}

# Set up GitHub secrets using CLI (if available)
setup_github_secrets() {
    log_section "Setting up GitHub Secrets"

    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not available. You'll need to set secrets manually."
        return 0
    fi

    # Check if we're in a GitHub repository
    if ! gh repo view &> /dev/null; then
        log_warning "Not in a GitHub repository or not authenticated with GitHub CLI"
        log_info "Please run 'gh auth login' first, then re-run this script"
        return 0
    fi

    log_info "Setting GitHub repository secrets..."

    # Set secrets using GitHub CLI
    gh secret set AZURE_CREDENTIALS < "${SECRETS_DIR}/azure-credentials.json" && \
    gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" && \
    gh secret set AZURE_TENANT_ID --body "$TENANT_ID" && \
    gh secret set AZURE_CLIENT_ID --body "$SP_APP_ID" && \
    gh secret set AZURE_CLIENT_SECRET --body "$SP_PASSWORD" && \

    log_success "GitHub secrets set successfully using GitHub CLI"
}

# Display setup summary
display_summary() {
    log_section "Setup Summary"

    log_success "GitHub Actions authentication setup completed!"

    echo -e "${BOLD}📋 Summary:${NC}"
    echo "  • Service Principal: $SERVICE_PRINCIPAL_NAME"
    echo "  • Client ID: $SP_APP_ID"
    echo "  • Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    echo "  • Tenant: $TENANT_ID"
    echo ""

    echo -e "${BOLD}📁 Files Created:${NC}"
    echo "  • ${SECRETS_DIR}/azure-credentials.json"
    echo "  • ${SECRETS_DIR}/github-secrets.json"
    echo "  • ${SECRETS_DIR}/sp-client-id.txt"
    echo "  • ${SECRETS_DIR}/sp-client-secret.txt"
    echo ""

    echo -e "${BOLD}🔧 Next Steps:${NC}"
    if command -v gh &> /dev/null && gh repo view &> /dev/null; then
        echo "  ✅ GitHub secrets have been set automatically"
        echo "  🚀 Your GitHub Actions workflows should now work"
    else
        echo "  1. Set up GitHub secrets manually:"
        echo "     - Go to: https://github.com/ma3u/azm-alz-min/settings/secrets/actions"
        echo "     - Copy the contents of ${SECRETS_DIR}/github-secrets.json"
        echo "  2. Test GitHub Actions workflows"
    fi
    echo ""

    echo -e "${BOLD}🔒 Security Notes:${NC}"
    echo "  • Service Principal has Contributor access to your sandbox subscription only"
    echo "  • Credentials are stored securely in ${SECRETS_DIR}/ (git-ignored)"
    echo "  • You can revoke access anytime: az ad sp delete --id $SP_APP_ID"
    echo ""

    echo -e "${BOLD}🧪 Test Commands:${NC}"
    echo "  • Test Azure login: az login --service-principal -u $SP_APP_ID -p [password] --tenant $TENANT_ID"
    echo "  • View secrets: cat ${SECRETS_DIR}/github-secrets.json | jq '.setup_instructions'"
    echo "  • Trigger workflow: gh workflow run 'Security & Compliance Scanning'"
}

# Main execution
main() {
    echo -e "${CYAN}${BOLD}"
    echo "🔐 GitHub Actions Authentication Setup"
    echo "======================================"
    echo -e "${NC}"
    echo "This script will set up authentication for GitHub Actions workflows"
    echo "with your limited Entra access sandbox subscription."
    echo ""

    check_prerequisites
    check_azure_auth
    create_service_principal
    test_service_principal
    generate_github_secrets
    setup_github_secrets
    display_summary

    log_success "🎉 Setup completed successfully!"
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "This script sets up GitHub Actions authentication for Azure deployments"
            echo "with limited Entra access in a sandbox subscription."
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "What this script does:"
            echo "  1. Creates a Service Principal with Contributor access"
            echo "  2. Generates GitHub secrets configuration"
            echo "  3. Optionally sets up GitHub secrets via CLI"
            echo "  4. Tests the authentication setup"
            echo ""
            echo "Requirements:"
            echo "  • Azure CLI logged in as matthias.buchhorn@soprasteria.com"
            echo "  • Contributor or higher permissions on sandbox subscription"
            echo "  • jq installed for JSON processing"
            echo "  • GitHub CLI (optional, for automatic secret setup)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
