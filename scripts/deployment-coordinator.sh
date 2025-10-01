#!/bin/bash
set -euo pipefail

# Deployment Coordinator Script
# Manages deployment locks to prevent concurrent deployments
# Usage: ./deployment-coordinator.sh {acquire|release|check} {pipeline-type} {environment}

SCRIPT_NAME="deployment-coordinator.sh"
VERSION="1.0.0"

# Configuration
LOCK_STORAGE_ACCOUNT="${DEPLOYMENT_LOCK_STORAGE_ACCOUNT:-alzlockst$(echo $RANDOM | md5sum | head -c 10)}"
LOCK_CONTAINER="${DEPLOYMENT_LOCK_CONTAINER:-deployment-locks}"
LOCK_TIMEOUT_MINUTES="${DEPLOYMENT_LOCK_TIMEOUT_MINUTES:-30}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - Deployment Lock Coordinator

USAGE:
    $SCRIPT_NAME {acquire|release|check} {pipeline-type} {environment}

COMMANDS:
    acquire     - Acquire deployment lock for the specified environment
    release     - Release deployment lock for the specified environment
    check       - Check current deployment lock status

PARAMETERS:
    pipeline-type   - Type of pipeline: 'github', 'azdo', 'manual'
    environment     - Target environment: 'sandbox', 'dev', 'staging', 'prod'

EXAMPLES:
    $SCRIPT_NAME acquire github sandbox
    $SCRIPT_NAME release azdo prod
    $SCRIPT_NAME check manual dev

ENVIRONMENT VARIABLES:
    DEPLOYMENT_LOCK_STORAGE_ACCOUNT - Storage account for locks (optional)
    DEPLOYMENT_LOCK_CONTAINER       - Container name for locks (default: deployment-locks)
    DEPLOYMENT_LOCK_TIMEOUT_MINUTES - Lock timeout in minutes (default: 30)

REQUIREMENTS:
    - Azure CLI installed and authenticated
    - Storage account exists or will be created automatically
    - Appropriate Azure permissions for storage operations
EOF
}

# Validate Azure CLI authentication
validate_azure_auth() {
    if ! az account show > /dev/null 2>&1; then
        log_error "Azure CLI not authenticated. Please run 'az login' first."
        exit 1
    fi

    local subscription_name
    subscription_name=$(az account show --query name -o tsv)
    log_info "Using Azure subscription: $subscription_name"
}

# Ensure storage account and container exist
ensure_lock_storage() {
    local resource_group="rg-deployment-locks"

    # Create resource group if it doesn't exist
    if ! az group show --name "$resource_group" > /dev/null 2>&1; then
        log_info "Creating resource group: $resource_group"
        az group create --name "$resource_group" --location "westeurope" > /dev/null
    fi

    # Create storage account if it doesn't exist
    if ! az storage account show --name "$LOCK_STORAGE_ACCOUNT" --resource-group "$resource_group" > /dev/null 2>&1; then
        log_info "Creating storage account: $LOCK_STORAGE_ACCOUNT"
        az storage account create \
            --name "$LOCK_STORAGE_ACCOUNT" \
            --resource-group "$resource_group" \
            --location "westeurope" \
            --sku "Standard_LRS" \
            --kind "StorageV2" \
            --min-tls-version "TLS1_2" \
            > /dev/null
    fi

    # Get storage account key
    STORAGE_KEY=$(az storage account keys list \
        --resource-group "$resource_group" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --query '[0].value' -o tsv)

    # Create container if it doesn't exist
    if ! az storage container show \
        --name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" > /dev/null 2>&1; then
        log_info "Creating storage container: $LOCK_CONTAINER"
        az storage container create \
            --name "$LOCK_CONTAINER" \
            --account-name "$LOCK_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            > /dev/null
    fi
}

# Generate lock file name
get_lock_filename() {
    local environment="$1"
    echo "deployment-lock-${environment}.json"
}

# Acquire deployment lock
acquire_lock() {
    local pipeline_type="$1"
    local environment="$2"
    local lock_filename
    lock_filename=$(get_lock_filename "$environment")

    log_info "Attempting to acquire deployment lock for environment: $environment"

    # Check if lock already exists
    if az storage blob exists \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --output tsv | grep -q "True"; then

        # Check if lock is expired
        local lock_data
        lock_data=$(az storage blob download \
            --name "$lock_filename" \
            --container-name "$LOCK_CONTAINER" \
            --account-name "$LOCK_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --output tsv 2>/dev/null || echo "{}")

        local lock_timestamp
        lock_timestamp=$(echo "$lock_data" | jq -r '.timestamp // empty')

        if [ -n "$lock_timestamp" ]; then
            local current_timestamp
            current_timestamp=$(date -u +%s)
            local lock_age_minutes
            lock_age_minutes=$(( (current_timestamp - lock_timestamp) / 60 ))

            if [ "$lock_age_minutes" -lt "$LOCK_TIMEOUT_MINUTES" ]; then
                local lock_owner
                lock_owner=$(echo "$lock_data" | jq -r '.owner // "unknown"')
                log_error "Deployment lock already exists for environment: $environment"
                log_error "Lock owner: $lock_owner"
                log_error "Lock age: ${lock_age_minutes} minutes (timeout: ${LOCK_TIMEOUT_MINUTES} minutes)"
                return 1
            else
                log_warn "Found expired lock (${lock_age_minutes} minutes old), acquiring new lock"
            fi
        fi
    fi

    # Create lock data
    local lock_data
    lock_data=$(cat << EOF
{
  "environment": "$environment",
  "pipeline_type": "$pipeline_type",
  "owner": "$pipeline_type-$(whoami)-$(hostname)",
  "timestamp": $(date -u +%s),
  "human_timestamp": "$(date -u -Iseconds)",
  "timeout_minutes": $LOCK_TIMEOUT_MINUTES,
  "run_id": "${GITHUB_RUN_ID:-${BUILD_BUILDID:-manual-$(date +%s)}}",
  "repository": "${GITHUB_REPOSITORY:-manual}",
  "workflow": "${GITHUB_WORKFLOW:-manual}"
}
EOF
    )

    # Upload lock file
    echo "$lock_data" | az storage blob upload \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --data "@-" \
        --overwrite \
        > /dev/null

    log_success "Successfully acquired deployment lock for environment: $environment"
    log_info "Lock owner: $pipeline_type-$(whoami)-$(hostname)"
    log_info "Lock timeout: $LOCK_TIMEOUT_MINUTES minutes"

    return 0
}

# Release deployment lock
release_lock() {
    local pipeline_type="$1"
    local environment="$2"
    local lock_filename
    lock_filename=$(get_lock_filename "$environment")

    log_info "Attempting to release deployment lock for environment: $environment"

    # Check if lock exists
    if ! az storage blob exists \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --output tsv | grep -q "True"; then
        log_warn "No deployment lock found for environment: $environment"
        return 0
    fi

    # Delete lock file
    az storage blob delete \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        > /dev/null

    log_success "Successfully released deployment lock for environment: $environment"
    return 0
}

# Check deployment lock status
check_lock() {
    local environment="$1"
    local lock_filename
    lock_filename=$(get_lock_filename "$environment")

    log_info "Checking deployment lock status for environment: $environment"

    # Check if lock exists
    if ! az storage blob exists \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --output tsv | grep -q "True"; then
        log_info "No deployment lock found for environment: $environment"
        return 0
    fi

    # Get lock data
    local lock_data
    lock_data=$(az storage blob download \
        --name "$lock_filename" \
        --container-name "$LOCK_CONTAINER" \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --output tsv 2>/dev/null || echo "{}")

    # Parse lock information
    local lock_owner lock_timestamp lock_age_minutes pipeline_type
    lock_owner=$(echo "$lock_data" | jq -r '.owner // "unknown"')
    lock_timestamp=$(echo "$lock_data" | jq -r '.timestamp // 0')
    pipeline_type=$(echo "$lock_data" | jq -r '.pipeline_type // "unknown"')

    if [ "$lock_timestamp" != "0" ]; then
        local current_timestamp
        current_timestamp=$(date -u +%s)
        lock_age_minutes=$(( (current_timestamp - lock_timestamp) / 60 ))

        log_warn "Deployment lock ACTIVE for environment: $environment"
        echo "  Owner: $lock_owner"
        echo "  Pipeline Type: $pipeline_type"
        echo "  Age: ${lock_age_minutes} minutes"
        echo "  Timeout: $LOCK_TIMEOUT_MINUTES minutes"

        if [ "$lock_age_minutes" -ge "$LOCK_TIMEOUT_MINUTES" ]; then
            log_warn "Lock is EXPIRED (can be overridden)"
            return 2
        else
            log_info "Lock is ACTIVE"
            return 1
        fi
    else
        log_error "Invalid lock data found"
        return 3
    fi
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        show_help
        exit 1
    fi

    local command="$1"

    case "$command" in
        "acquire"|"release")
            if [ $# -ne 3 ]; then
                log_error "Missing parameters. Usage: $SCRIPT_NAME $command {pipeline-type} {environment}"
                exit 1
            fi
            local pipeline_type="$2"
            local environment="$3"
            ;;
        "check")
            if [ $# -ne 2 ]; then
                log_error "Missing parameters. Usage: $SCRIPT_NAME check {environment}"
                exit 1
            fi
            local environment="$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac

    # Validate parameters
    if [ -n "${environment:-}" ]; then
        case "$environment" in
            "sandbox"|"dev"|"staging"|"prod")
                ;;
            *)
                log_error "Invalid environment: $environment. Must be one of: sandbox, dev, staging, prod"
                exit 1
                ;;
        esac
    fi

    if [ -n "${pipeline_type:-}" ]; then
        case "$pipeline_type" in
            "github"|"azdo"|"manual")
                ;;
            *)
                log_error "Invalid pipeline type: $pipeline_type. Must be one of: github, azdo, manual"
                exit 1
                ;;
        esac
    fi

    # Validate Azure authentication
    validate_azure_auth

    # Ensure lock storage exists
    ensure_lock_storage

    # Execute command
    case "$command" in
        "acquire")
            acquire_lock "$pipeline_type" "$environment"
            ;;
        "release")
            release_lock "$pipeline_type" "$environment"
            ;;
        "check")
            check_lock "$environment"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
