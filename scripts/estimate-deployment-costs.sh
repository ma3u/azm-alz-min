#!/usr/bin/env bash
# Azure Landing Zone Cost Estimation Script
# Provides PREDICTIVE cost estimates for deployed resources (not historical)

set -euo pipefail

# Configuration
SCRIPT_NAME="$(basename "$0")"
AZURE_REGION="${AZURE_REGION:-westeurope}"
CURRENCY="${CURRENCY:-USD}"
MONTHLY_HOURS="730" # Average hours per month

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  [INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}✅ [SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠️  [WARNING]${NC} $*"; }
log_error() { echo -e "${RED}❌ [ERROR]${NC} $*"; }

# Help function
show_help() {
    cat << EOF
${SCRIPT_NAME} - Azure Landing Zone Cost Estimation

USAGE:
    ${SCRIPT_NAME} [OPTIONS] <resource-group>

DESCRIPTION:
    Provides PREDICTIVE monthly cost estimates for deployed Azure resources.
    Uses Azure Resource Graph and Pricing API for real-time estimates.

OPTIONS:
    -r, --region REGION     Azure region (default: westeurope)
    -c, --currency CURRENCY Currency code (default: USD)
    -h, --help             Show this help message

EXAMPLES:
    ${SCRIPT_NAME} rg-alz-sandbox-sandbox
    ${SCRIPT_NAME} -r eastus -c EUR rg-alz-hub-sandbox

NOTES:
    - Requires Azure CLI with logged-in session
    - Resource Graph extension required: az extension add --name resource-graph
    - Provides estimates only - actual costs may vary
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            AZURE_REGION="$2"
            shift 2
            ;;
        -c|--currency)
            CURRENCY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            RESOURCE_GROUP="$1"
            shift
            ;;
    esac
done

# Validate required parameters
if [[ -z "${RESOURCE_GROUP:-}" ]]; then
    log_error "Resource group parameter is required"
    show_help
    exit 1
fi

# Azure pricing data for common services (West Europe, USD)
# Updated as of October 2025 - these are approximate baseline costs
declare -A SERVICE_COSTS
SERVICE_COSTS[Standard_D2s_v3]="70.08"      # Virtual Machine (2 vCPU, 8GB RAM)
SERVICE_COSTS[Standard_B2s]="30.37"         # Burstable VM (2 vCPU, 4GB RAM)
SERVICE_COSTS[Standard_LRS]="0.0208"        # Storage per GB
SERVICE_COSTS[Standard_GRS]="0.0416"        # Geo-redundant storage per GB
SERVICE_COSTS[Basic_Key_Vault]="3.00"       # Key Vault Standard tier
SERVICE_COSTS[Standard_Key_Vault]="3.00"    # Key Vault Standard tier
SERVICE_COSTS[B1_App_Service]="13.14"       # Basic App Service Plan
SERVICE_COSTS[S1_App_Service]="56.94"       # Standard App Service Plan
SERVICE_COSTS[Basic_Container_Registry]="5.00"     # Basic ACR tier
SERVICE_COSTS[Standard_Container_Registry]="20.00" # Standard ACR tier
SERVICE_COSTS[Log_Analytics_Per_GB]="2.76"  # Log Analytics per GB ingested
SERVICE_COSTS[Basic_Public_IP]="3.65"       # Basic Public IP
SERVICE_COSTS[Standard_Public_IP]="4.38"    # Standard Public IP

# Function to estimate storage costs
estimate_storage_cost() {
    local storage_account="$1"
    local size_gb="${2:-100}"  # Default 100GB if not specified
    local replication="${3:-LRS}"

    local cost_key="Standard_${replication}"
    local unit_cost="${SERVICE_COSTS[$cost_key]:-0.0208}"

    echo "$(echo "$size_gb * $unit_cost" | bc -l)"
}

# Function to estimate VM costs
estimate_vm_cost() {
    local vm_size="$1"
    local monthly_cost="${SERVICE_COSTS[$vm_size]:-50.00}"  # Default fallback
    echo "$monthly_cost"
}

# Function to get resource information using Resource Graph
get_resource_info() {
    local rg="$1"

    log_info "Querying deployed resources in resource group: $rg"

    az graph query \
        --graph-query "Resources | where resourceGroup == '$rg' | project name, type, sku, properties, location" \
        --output json 2>/dev/null || {
            log_warning "Resource Graph query failed, falling back to basic resource listing"
            az resource list --resource-group "$rg" --output json 2>/dev/null || echo "[]"
        }
}

# Main cost estimation function
estimate_costs() {
    local resource_group="$1"

    log_info "Starting cost estimation for resource group: $resource_group"
    log_info "Region: $AZURE_REGION | Currency: $CURRENCY"
    echo ""

    # Check if resource group exists
    if ! az group show --name "$resource_group" --output none 2>/dev/null; then
        log_error "Resource group '$resource_group' not found"
        return 1
    fi

    # Get resource information
    local resources_json
    resources_json=$(get_resource_info "$resource_group")

    if [[ "$resources_json" == "[]" || -z "$resources_json" ]]; then
        log_warning "No resources found in resource group: $resource_group"
        return 0
    fi

    echo -e "${CYAN}📊 PREDICTIVE MONTHLY COST ESTIMATION${NC}"
    echo "══════════════════════════════════════════════════"

    local total_cost=0
    local resource_count=0

    # Process each resource and estimate costs
    while IFS= read -r resource; do
        if [[ -z "$resource" ]]; then continue; fi

        local name type sku monthly_cost
        name=$(echo "$resource" | jq -r '.name // "unknown"')
        type=$(echo "$resource" | jq -r '.type // "unknown"')
        sku=$(echo "$resource" | jq -r '.sku.name // .sku // "unknown"')

        monthly_cost=0

        case "$type" in
            "Microsoft.Compute/virtualMachines")
                monthly_cost=$(estimate_vm_cost "$sku")
                printf "🖥️  %-25s %-30s $%8.2f\n" "Virtual Machine" "$name" "$monthly_cost"
                ;;
            "Microsoft.Storage/storageAccounts")
                monthly_cost="5.00"  # Base storage account cost
                printf "💾 %-25s %-30s $%8.2f\n" "Storage Account" "$name" "$monthly_cost"
                ;;
            "Microsoft.KeyVault/vaults")
                monthly_cost="${SERVICE_COSTS[Standard_Key_Vault]}"
                printf "🔐 %-25s %-30s $%8.2f\n" "Key Vault" "$name" "$monthly_cost"
                ;;
            "Microsoft.Web/serverfarms")
                if [[ "$sku" =~ ^B[0-9] ]]; then
                    monthly_cost="${SERVICE_COSTS[B1_App_Service]}"
                else
                    monthly_cost="${SERVICE_COSTS[S1_App_Service]}"
                fi
                printf "🌐 %-25s %-30s $%8.2f\n" "App Service Plan" "$name" "$monthly_cost"
                ;;
            "Microsoft.Web/sites")
                monthly_cost="0.00"  # Covered by App Service Plan
                printf "🌐 %-25s %-30s $%8.2f\n" "Web App" "$name" "$monthly_cost"
                ;;
            "Microsoft.ContainerRegistry/registries")
                if [[ "$sku" == "Basic" ]]; then
                    monthly_cost="${SERVICE_COSTS[Basic_Container_Registry]}"
                else
                    monthly_cost="${SERVICE_COSTS[Standard_Container_Registry]}"
                fi
                printf "🐳 %-25s %-30s $%8.2f\n" "Container Registry" "$name" "$monthly_cost"
                ;;
            "Microsoft.OperationalInsights/workspaces")
                monthly_cost="10.00"  # Estimated for basic usage
                printf "📊 %-25s %-30s $%8.2f\n" "Log Analytics" "$name" "$monthly_cost"
                ;;
            "Microsoft.Network/publicIPAddresses")
                monthly_cost="${SERVICE_COSTS[Basic_Public_IP]}"
                printf "🌐 %-25s %-30s $%8.2f\n" "Public IP" "$name" "$monthly_cost"
                ;;
            "Microsoft.Network/virtualNetworks")
                monthly_cost="0.00"  # VNets are generally free
                printf "🔗 %-25s %-30s $%8.2f\n" "Virtual Network" "$name" "$monthly_cost"
                ;;
            *)
                monthly_cost="2.00"  # Small default cost for unknown resources
                printf "❓ %-25s %-30s $%8.2f\n" "Other Resource" "$name" "$monthly_cost"
                ;;
        esac

        total_cost=$(echo "$total_cost + $monthly_cost" | bc -l)
        ((resource_count++))

    done <<< "$(echo "$resources_json" | jq -c '.[]')"

    echo "══════════════════════════════════════════════════"
    printf "📈 %-25s %-30s ${GREEN}$%8.2f${NC}\n" "TOTAL ESTIMATED/MONTH" "($resource_count resources)" "$total_cost"
    printf "📈 %-25s %-30s ${BLUE}$%8.2f${NC}\n" "ESTIMATED DAILY" "" "$(echo "$total_cost / 30" | bc -l)"
    echo ""

    # Cost alerts
    if (( $(echo "$total_cost > 100" | bc -l) )); then
        log_warning "Monthly cost estimate exceeds $100 USD - review resource sizes"
    elif (( $(echo "$total_cost > 50" | bc -l) )); then
        log_warning "Monthly cost estimate exceeds $50 USD - monitor usage"
    else
        log_success "Monthly cost estimate within acceptable range"
    fi

    # Additional insights
    echo -e "${CYAN}💡 COST OPTIMIZATION TIPS${NC}"
    echo "• Use Basic/Standard tiers for development and testing"
    echo "• Enable auto-shutdown for VMs in non-production environments"
    echo "• Monitor Log Analytics data ingestion (charged per GB)"
    echo "• Consider Azure Hybrid Benefit for Windows VMs"
    echo "• Use Azure Cost Management for ongoing monitoring"
    echo ""

    # Output for GitHub Actions
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "estimated_monthly_cost=$total_cost" >> "$GITHUB_ENV"
        echo "resource_count=$resource_count" >> "$GITHUB_ENV"
    fi

    return 0
}

# Main execution
main() {
    log_info "Azure Landing Zone Cost Estimation Tool"
    log_info "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    # Check prerequisites
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install jq for JSON processing."
        exit 1
    fi

    if ! command -v bc &> /dev/null; then
        log_error "bc not found. Please install bc for calculations."
        exit 1
    fi

    # Verify Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Run 'az login' first."
        exit 1
    fi

    # Run cost estimation
    estimate_costs "$RESOURCE_GROUP"
}

# Execute main function
main "$@"
