#!/bin/bash
# Deployment Coordination Script
# Prevents concurrent deployments between GitHub Actions and Azure DevOps pipelines

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
LOCK_STORAGE_ACCOUNT="stdeploymentlock$(echo "$RANDOM" | sha1sum | head -c 8)"
LOCK_CONTAINER="deployment-locks"
LOCK_RESOURCE_GROUP="rg-deployment-coordination"
LOCK_TIMEOUT_MINUTES=30
DEPLOYMENT_TIMEOUT_MINUTES=120

# Script parameters
PIPELINE_TYPE=""
ENVIRONMENT=""
OPERATION=""
LOCK_KEY=""

# Function to display usage
usage() {
    echo "Usage: $0 <operation> <pipeline_type> <environment> [options]"
    echo ""
    echo "Operations:"
    echo "  acquire     - Acquire deployment lock"
    echo "  release     - Release deployment lock"
    echo "  check       - Check lock status"
    echo "  force-break - Force break existing lock (emergency use)"
    echo ""
    echo "Pipeline Types:"
    echo "  github      - GitHub Actions pipeline"
    echo "  azdevops    - Azure DevOps pipeline"
    echo ""
    echo "Environments:"
    echo "  sandbox     - Sandbox environment"
    echo "  dev         - Development environment"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 acquire github sandbox"
    echo "  $0 release azdevops prod"
    echo "  $0 check github sandbox"
    echo ""
}

# Function to setup coordination infrastructure
setup_coordination_infra() {
    print_status "Setting up deployment coordination infrastructure..."

    # Create resource group for coordination
    if ! az group show --name "$LOCK_RESOURCE_GROUP" --output none 2>/dev/null; then
        print_status "Creating coordination resource group..."
        az group create \
            --name "$LOCK_RESOURCE_GROUP" \
            --location "westeurope" \
            --tags Purpose="DeploymentCoordination" \
                   Environment="Global" \
                   CostCenter="DevOps"
    fi

    # Create storage account for locks (with globally unique name)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    UNIQUE_SUFFIX=$(echo -n "${SUBSCRIPTION_ID}coordination" | sha256sum | cut -c1-8)
    LOCK_STORAGE_ACCOUNT="stcoord${UNIQUE_SUFFIX}"

    if ! az storage account show --name "$LOCK_STORAGE_ACCOUNT" --resource-group "$LOCK_RESOURCE_GROUP" --output none 2>/dev/null; then
        print_status "Creating coordination storage account: $LOCK_STORAGE_ACCOUNT"
        az storage account create \
            --name "$LOCK_STORAGE_ACCOUNT" \
            --resource-group "$LOCK_RESOURCE_GROUP" \
            --location "westeurope" \
            --sku "Standard_LRS" \
            --kind "StorageV2" \
            --tags Purpose="DeploymentCoordination"
    fi

    # Create container for deployment locks
    STORAGE_KEY=$(az storage account keys list --resource-group "$LOCK_RESOURCE_GROUP" --account-name "$LOCK_STORAGE_ACCOUNT" --query '[0].value' -o tsv)

    if ! az storage container show --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --name "$LOCK_CONTAINER" --output none 2>/dev/null; then
        print_status "Creating locks container..."
        az storage container create \
            --account-name "$LOCK_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --name "$LOCK_CONTAINER" \
            --public-access off
    fi

    print_success "Coordination infrastructure ready"
    echo "Storage Account: $LOCK_STORAGE_ACCOUNT"
    echo "Container: $LOCK_CONTAINER"
    echo "Resource Group: $LOCK_RESOURCE_GROUP"
}

# Function to acquire deployment lock
acquire_lock() {
    local pipeline_type="$1"
    local environment="$2"
    local lock_key="deployment-lock-${environment}"

    print_status "Attempting to acquire deployment lock for $pipeline_type on $environment..."

    # Ensure coordination infrastructure exists
    setup_coordination_infra

    STORAGE_KEY=$(az storage account keys list --resource-group "$LOCK_RESOURCE_GROUP" --account-name "$LOCK_STORAGE_ACCOUNT" --query '[0].value' -o tsv)

    # Check if lock already exists
    if az storage blob show --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output none 2>/dev/null; then

        # Get lock information
        local lock_info
        lock_info=$(az storage blob download --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output tsv 2>/dev/null | head -1)

        local lock_pipeline lock_timestamp lock_build_id
        IFS='|' read -r lock_pipeline lock_timestamp lock_build_id <<< "$lock_info"

        print_warning "Deployment lock exists!"
        echo "  Locked by: $lock_pipeline"
        echo "  Timestamp: $lock_timestamp"
        echo "  Build ID: $lock_build_id"

        # Check lock age
        local lock_age_minutes
        lock_age_minutes=$(( ($(date +%s) - $(date -d "$lock_timestamp" +%s 2>/dev/null || echo "0")) / 60 ))

        if [[ $lock_age_minutes -gt $LOCK_TIMEOUT_MINUTES ]]; then
            print_warning "Lock is older than $LOCK_TIMEOUT_MINUTES minutes - attempting to break stale lock"
            force_break_lock "$environment"
        else
            print_error "Active deployment in progress by $lock_pipeline"
            print_status "Lock acquired at: $lock_timestamp (${lock_age_minutes} minutes ago)"
            print_status "Wait for completion or use 'force-break' in emergency"
            return 1
        fi
    fi

    # Acquire the lock
    local build_id="${GITHUB_RUN_ID:-${BUILD_BUILDNUMBER:-$(date +%s)}}"
    local lock_content="${pipeline_type}|$(date -u +"%Y-%m-%d %H:%M:%S UTC")|${build_id}"

    # Create lock file
    echo "$lock_content" | az storage blob upload \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$LOCK_CONTAINER" \
        --name "$lock_key" \
        --file /dev/stdin \
        --overwrite \
        --output none

    print_success "Deployment lock acquired successfully!"
    echo "  Pipeline: $pipeline_type"
    echo "  Environment: $environment"
    echo "  Build ID: $build_id"
    echo "  Lock Key: $lock_key"

    # Set environment variables for CI/CD systems
    echo "DEPLOYMENT_LOCK_ACQUIRED=true" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
    echo "##vso[task.setvariable variable=deploymentLockAcquired]true" 2>/dev/null || true

    return 0
}

# Function to release deployment lock
release_lock() {
    local pipeline_type="$1"
    local environment="$2"
    local lock_key="deployment-lock-${environment}"

    print_status "Releasing deployment lock for $pipeline_type on $environment..."

    STORAGE_KEY=$(az storage account keys list --resource-group "$LOCK_RESOURCE_GROUP" --account-name "$LOCK_STORAGE_ACCOUNT" --query '[0].value' -o tsv)

    # Verify lock ownership before releasing
    if az storage blob show --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output none 2>/dev/null; then

        local lock_info
        lock_info=$(az storage blob download --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output tsv 2>/dev/null | head -1)

        local lock_pipeline
        IFS='|' read -r lock_pipeline _ _ <<< "$lock_info"

        if [[ "$lock_pipeline" != "$pipeline_type" ]]; then
            print_warning "Lock owned by different pipeline: $lock_pipeline"
            print_status "Only the lock owner should release the lock"
            return 1
        fi

        # Delete the lock
        az storage blob delete \
            --account-name "$LOCK_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --container-name "$LOCK_CONTAINER" \
            --name "$lock_key" \
            --output none

        print_success "Deployment lock released successfully!"

        # Clear environment variables
        echo "DEPLOYMENT_LOCK_ACQUIRED=false" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
        echo "##vso[task.setvariable variable=deploymentLockAcquired]false" 2>/dev/null || true

    else
        print_warning "No deployment lock found for $environment"
    fi

    return 0
}

# Function to check lock status
check_lock() {
    local environment="$1"
    local lock_key="deployment-lock-${environment}"

    print_status "Checking deployment lock status for $environment..."

    if ! az group show --name "$LOCK_RESOURCE_GROUP" --output none 2>/dev/null; then
        print_status "No coordination infrastructure found - no active locks"
        return 0
    fi

    STORAGE_KEY=$(az storage account keys list --resource-group "$LOCK_RESOURCE_GROUP" --account-name "$LOCK_STORAGE_ACCOUNT" --query '[0].value' -o tsv 2>/dev/null || echo "")

    if [[ -z "$STORAGE_KEY" ]]; then
        print_warning "Cannot access coordination storage"
        return 1
    fi

    if az storage blob show --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output none 2>/dev/null; then

        local lock_info
        lock_info=$(az storage blob download --account-name "$LOCK_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --container-name "$LOCK_CONTAINER" --name "$lock_key" --output tsv 2>/dev/null | head -1)

        local lock_pipeline lock_timestamp lock_build_id
        IFS='|' read -r lock_pipeline lock_timestamp lock_build_id <<< "$lock_info"

        local lock_age_minutes
        lock_age_minutes=$(( ($(date +%s) - $(date -d "$lock_timestamp" +%s 2>/dev/null || echo "0")) / 60 ))

        print_warning "🔒 Deployment lock is ACTIVE"
        echo "  Environment: $environment"
        echo "  Locked by: $lock_pipeline"
        echo "  Timestamp: $lock_timestamp"
        echo "  Build ID: $lock_build_id"
        echo "  Lock Age: ${lock_age_minutes} minutes"

        if [[ $lock_age_minutes -gt $LOCK_TIMEOUT_MINUTES ]]; then
            print_warning "⚠️ Lock appears stale (older than $LOCK_TIMEOUT_MINUTES minutes)"
            print_status "Consider using 'force-break' if deployment is stuck"
        else
            print_status "✅ Lock is active and within timeout window"
        fi

        return 1  # Lock exists
    else
        print_success "🔓 No deployment lock found for $environment"
        print_status "Environment is available for deployment"
        return 0  # No lock
    fi
}

# Function to force break lock (emergency use)
force_break_lock() {
    local environment="$1"
    local lock_key="deployment-lock-${environment}"

    print_warning "🚨 FORCE BREAKING deployment lock for $environment"
    print_warning "This should only be used in emergency situations!"

    read -p "Are you sure you want to force break the lock? (yes/no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        print_status "Lock break cancelled"
        return 1
    fi

    STORAGE_KEY=$(az storage account keys list --resource-group "$LOCK_RESOURCE_GROUP" --account-name "$LOCK_STORAGE_ACCOUNT" --query '[0].value' -o tsv)

    # Delete the lock forcefully
    az storage blob delete \
        --account-name "$LOCK_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$LOCK_CONTAINER" \
        --name "$lock_key" \
        --output none 2>/dev/null || true

    print_success "🔓 Deployment lock forcefully removed!"
    print_warning "Monitor for any conflicting deployments"

    return 0
}

# Function to wait for lock release
wait_for_lock() {
    local environment="$1"
    local max_wait_minutes="${2:-$DEPLOYMENT_TIMEOUT_MINUTES}"

    print_status "Waiting for deployment lock to be released..."
    print_status "Maximum wait time: $max_wait_minutes minutes"

    local wait_start
    wait_start=$(date +%s)
    local wait_seconds=$((max_wait_minutes * 60))

    while true; do
        if check_lock "$environment" >/dev/null 2>&1; then
            # No lock found, we can proceed
            print_success "Deployment lock is now available!"
            return 0
        fi

        local elapsed_seconds
        elapsed_seconds=$(( $(date +%s) - wait_start ))

        if [[ $elapsed_seconds -ge $wait_seconds ]]; then
            print_error "Timeout waiting for deployment lock release"
            print_status "Consider checking the other pipeline's status or using force-break"
            return 1
        fi

        local remaining_minutes
        remaining_minutes=$(( (wait_seconds - elapsed_seconds) / 60 ))

        print_status "Waiting... ($remaining_minutes minutes remaining)"
        sleep 30  # Check every 30 seconds
    done
}

# Main execution
main() {
    # Parse arguments
    if [[ $# -lt 3 ]]; then
        usage
        exit 1
    fi

    OPERATION="$1"
    PIPELINE_TYPE="$2"
    ENVIRONMENT="$3"

    # Validate arguments
    case "$OPERATION" in
        acquire|release|check|force-break|wait) ;;
        *) print_error "Invalid operation: $OPERATION"; usage; exit 1 ;;
    esac

    case "$PIPELINE_TYPE" in
        github|azdevops) ;;
        *) print_error "Invalid pipeline type: $PIPELINE_TYPE"; usage; exit 1 ;;
    esac

    case "$ENVIRONMENT" in
        sandbox|dev|staging|prod) ;;
        *) print_error "Invalid environment: $ENVIRONMENT"; usage; exit 1 ;;
    esac

    # Set up storage account name
    if az account show --output none 2>/dev/null; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        UNIQUE_SUFFIX=$(echo -n "${SUBSCRIPTION_ID}coordination" | sha256sum | cut -c1-8)
        LOCK_STORAGE_ACCOUNT="stcoord${UNIQUE_SUFFIX}"
    fi

    print_status "🎯 Deployment Coordination"
    echo "Operation: $OPERATION"
    echo "Pipeline: $PIPELINE_TYPE"
    echo "Environment: $ENVIRONMENT"
    echo ""

    # Execute operation
    case "$OPERATION" in
        acquire)
            acquire_lock "$PIPELINE_TYPE" "$ENVIRONMENT"
            ;;
        release)
            release_lock "$PIPELINE_TYPE" "$ENVIRONMENT"
            ;;
        check)
            check_lock "$ENVIRONMENT"
            ;;
        force-break)
            force_break_lock "$ENVIRONMENT"
            ;;
        wait)
            wait_for_lock "$ENVIRONMENT" "${4:-$DEPLOYMENT_TIMEOUT_MINUTES}"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
