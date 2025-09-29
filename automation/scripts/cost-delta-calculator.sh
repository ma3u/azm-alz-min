#!/bin/bash

# Azure Landing Zone Cost Delta Calculator
# Calculates cost differences between current and previous deployments
# Used by pre-commit hooks for cost impact analysis

set -euo pipefail

# Configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"
REPORTS_DIR="${PROJECT_DIR}/deployment-reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

# Function to calculate cost from resource inventory
calculate_cost_from_resources() {
    local resource_file="$1"

    if [[ ! -f "$resource_file" ]]; then
        echo "0.00"
        return
    fi

    # Count resources by type
    local storage_accounts=$(jq '[.[] | select(.type | contains("Microsoft.Storage/storageAccounts"))] | length' "$resource_file" 2>/dev/null || echo "0")
    local vnets=$(jq '[.[] | select(.type | contains("Microsoft.Network/virtualNetworks"))] | length' "$resource_file" 2>/dev/null || echo "0")
    local app_plans=$(jq '[.[] | select(.type | contains("Microsoft.Web/serverFarms"))] | length' "$resource_file" 2>/dev/null || echo "0")
    local log_analytics=$(jq '[.[] | select(.type | contains("Microsoft.OperationalInsights/workspaces"))] | length' "$resource_file" 2>/dev/null || echo "0")
    local public_ips=$(jq '[.[] | select(.type | contains("Microsoft.Network/publicIPAddresses"))] | length' "$resource_file" 2>/dev/null || echo "0")

    # Calculate costs using sandbox pricing
    local storage_cost=$(echo "$storage_accounts * 2.50" | bc -l 2>/dev/null || echo "0.00")
    local networking_cost=$(echo "($vnets * 1.00) + ($public_ips * 4.00)" | bc -l 2>/dev/null || echo "0.00")
    local analytics_cost=$(echo "$log_analytics * 5.00" | bc -l 2>/dev/null || echo "0.00")
    local web_cost=$(echo "$app_plans * 13.00" | bc -l 2>/dev/null || echo "0.00")

    # Total cost (corrected logic)
    local total_cost=$(echo "$storage_cost + $networking_cost + $analytics_cost + $web_cost" | bc -l 2>/dev/null || echo "0.00")
    printf "%.2f" "$total_cost" 2>/dev/null || echo "0.00"
}

# Function to get deployment cost data
get_deployment_costs() {
    local output_file=$(mktemp)

    # Header
    echo "timestamp,deployment_id,status,resources,current_cost,original_cost,delta_amount,delta_percent" > "$output_file"

    # Process each deployment directory
    for dir in "${REPORTS_DIR}"/202509*; do
        if [[ -d "$dir" ]]; then
            local name=$(basename "$dir")
            local summary_file="$dir/deployment-summary.json"
            local resource_file="$dir/resources/resource-inventory.json"

            if [[ -f "$summary_file" ]]; then
                local deploy_status=$(jq -r '.deployment.status // "unknown"' "$summary_file" 2>/dev/null || echo "unknown")
                local resources=$(jq -r '.deployment.resources_deployed // "0"' "$summary_file" 2>/dev/null || echo "0")
                local original_cost=$(jq -r '.costs.estimated_monthly // "0.00"' "$summary_file" 2>/dev/null || echo "0.00")

                # Calculate current cost
                local current_cost=$(calculate_cost_from_resources "$resource_file")

                # Calculate delta
                local delta_amount="0.00"
                local delta_percent="0.0"

                if [[ "$original_cost" != "N/A" && "$original_cost" != "0.00" ]]; then
                    delta_amount=$(echo "$current_cost - $original_cost" | bc -l 2>/dev/null || echo "0.00")
                    delta_percent=$(echo "scale=1; ($delta_amount / $original_cost) * 100" | bc -l 2>/dev/null || echo "0.0")
                fi

                # Format timestamp for readability
                local timestamp=$(echo "$name" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')

                echo "$timestamp,$name,$deploy_status,$resources,$current_cost,$original_cost,$delta_amount,$delta_percent" >> "$output_file"
            fi
        fi
    done

    echo "$output_file"
}

# Function to display cost analysis
display_cost_analysis() {
    log_section "💰 Cost Delta Analysis"

    local cost_data_file=$(get_deployment_costs)

    # Display summary table
    echo "Deployment Analysis (Successful Deployments Only):"
    echo "=============================================="
    printf "%-12s | %-8s | %-4s | %-12s | %-12s | %-10s\n" "Deployment" "Status" "Rsrc" "Current" "Original" "Delta"
    echo "-------------|----------|------|--------------|--------------|----------"

    # Process and display data
    local total_savings=0
    local deployment_count=0

    while IFS=',' read -r timestamp deployment_id deploy_status resources current_cost original_cost delta_amount delta_percent; do
        if [[ "$deployment_id" != "deployment_id" && "$deploy_status" == "succeeded" ]]; then
            # Format display
            local short_id=$(echo "$deployment_id" | cut -c9-14)
            local delta_display=""

            if (( $(echo "$delta_amount < 0" | bc -l 2>/dev/null || echo "0") )); then
                delta_display="📉 -\$$(echo "$delta_amount * -1" | bc -l)"
            elif (( $(echo "$delta_amount > 0" | bc -l 2>/dev/null || echo "0") )); then
                delta_display="📈 +\$$delta_amount"
            else
                delta_display="➡️ \$0.00"
            fi

            printf "%-12s | %-8s | %-4s | \$%-11s | \$%-11s | %-10s\n" \
                "$short_id" "$deploy_status" "$resources" "$current_cost" "$original_cost" "$delta_display"

            # Accumulate savings
            total_savings=$(echo "$total_savings + $delta_amount" | bc -l 2>/dev/null || echo "$total_savings")
            ((deployment_count++))
        fi
    done < "$cost_data_file"

    echo ""

    # Summary statistics
    if [[ $deployment_count -gt 0 ]]; then
        local avg_savings=$(echo "scale=2; $total_savings / $deployment_count" | bc -l 2>/dev/null || echo "0.00")

        log_info "Summary Statistics:"
        echo "  📊 Successful Deployments: $deployment_count"
        echo "  💰 Total Cost Impact: \$$(printf "%.2f" "$total_savings")"
        echo "  📈 Average Per Deployment: \$$(printf "%.2f" "$avg_savings")"

        if (( $(echo "$total_savings < 0" | bc -l 2>/dev/null || echo "0") )); then
            log_success "Overall cost reduction achieved! 📉"
        elif (( $(echo "$total_savings > 0" | bc -l 2>/dev/null || echo "0") )); then
            log_warning "Cost increase detected 📈"
        else
            log_info "No net cost change ➡️"
        fi
    fi

    # Cleanup
    rm -f "$cost_data_file"
}

# Function to check for cost-impacting changes in git diff
check_template_changes() {
    local files_changed="$1"

    if [[ -z "$files_changed" ]]; then
        return 0
    fi

    log_section "📝 Template Change Impact Analysis"

    local has_cost_impact=false

    for file in $files_changed; do
        if [[ "$file" =~ \.(bicep|tf)$ ]]; then
            echo "Analyzing: $file"

            # Check for cost-impacting keywords
            local cost_keywords=("Premium" "Standard" "Basic" "sku" "tier" "capacity" "replicas")

            for keyword in "${cost_keywords[@]}"; do
                if git diff --cached "$file" 2>/dev/null | grep -i "$keyword" > /dev/null; then
                    echo "  ⚠️  Cost-impacting change detected: $keyword"
                    has_cost_impact=true
                fi
            done

            # Check for new resources
            if git diff --cached "$file" 2>/dev/null | grep -E "^\+.*resource " > /dev/null; then
                echo "  📦 New resources detected"
                has_cost_impact=true
            fi
        fi
    done

    if [[ "$has_cost_impact" == "true" ]]; then
        log_warning "Changes may impact deployment costs"
        return 1
    else
        log_success "No significant cost impact detected"
        return 0
    fi
}

# Main function
main() {
    local action="${1:-analysis}"
    local files_changed="${2:-}"

    case "$action" in
        "analysis"|"delta")
            display_cost_analysis
            ;;
        "precommit")
            if ! check_template_changes "$files_changed"; then
                log_warning "Consider reviewing cost implications before committing"
            fi
            display_cost_analysis
            ;;
        "help"|"--help")
            echo "Usage: $0 [analysis|precommit|help] [files...]"
            echo ""
            echo "Commands:"
            echo "  analysis   - Display cost delta analysis (default)"
            echo "  precommit  - Run pre-commit cost checks"
            echo "  help       - Show this help"
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Check prerequisites
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    log_error "bc is required but not installed"
    exit 1
fi

# Run main function
main "$@"
