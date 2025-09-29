#!/bin/bash
# AVM Module Version Checker
# Validates AVM module versions in Bicep files and checks for updates

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

# Function to extract module path and version from AVM reference
parse_avm_module() {
    local module_ref="$1"
    local module_path=""
    local version=""

    # Extract path: br/public:avm/res/storage/storage-account:0.9.1
    if [[ "$module_ref" =~ br/public:avm/([^:]+):([^\'\"]+) ]]; then
        module_path="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
    fi

    echo "$module_path|$version"
}

# Function to check latest version of AVM module
check_latest_version() {
    local module_path="$1"
    local current_version="$2"

    # Convert module path to registry format
    local registry_path="${module_path//\//-}"
    local api_url="https://mcr.microsoft.com/v2/bicep/avm/${module_path}/tags/list"

    print_status "Checking latest version for: avm/${module_path}"

    # Try to get latest version from MCR
    if command -v curl &> /dev/null && command -v jq &> /dev/null; then
        local latest_versions
        latest_versions=$(curl -s "$api_url" 2>/dev/null | jq -r '.tags[]?' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -5)

        if [[ -n "$latest_versions" ]]; then
            local latest_version
            latest_version=$(echo "$latest_versions" | tail -1)

            print_status "Current: $current_version, Latest: $latest_version"

            if [[ "$current_version" != "$latest_version" ]]; then
                print_warning "AVM module avm/${module_path} has a newer version available"
                echo "  Current: $current_version"
                echo "  Latest:  $latest_version"
                echo "  Consider updating to: br/public:avm/${module_path}:${latest_version}"
                return 1
            else
                print_success "AVM module avm/${module_path} is up to date"
                return 0
            fi
        else
            print_warning "Could not fetch version information for avm/${module_path}"
            return 0
        fi
    else
        print_warning "curl or jq not available - skipping version check"
        return 0
    fi
}

# Function to validate AVM module usage patterns
validate_avm_usage() {
    local file="$1"
    local issues=0

    print_status "Validating AVM usage patterns in: $file"

    # Check for proper AVM module syntax
    while IFS= read -r line; do
        if [[ "$line" =~ module.*\'br/public:avm/ ]]; then
            # Extract the full module reference
            if [[ "$line" =~ \'(br/public:avm/[^\']+)\' ]]; then
                local module_ref="${BASH_REMATCH[1]}"

                # Parse module components
                IFS='|' read -r module_path version <<< "$(parse_avm_module "$module_ref")"

                if [[ -n "$module_path" && -n "$version" ]]; then
                    print_status "Found AVM module: $module_path:$version"

                    # Check if version is pinned (not latest)
                    if [[ "$version" == "latest" ]]; then
                        print_error "AVM module should use specific version, not 'latest': $module_ref"
                        issues=$((issues + 1))
                    elif [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        print_warning "AVM module version should follow semantic versioning: $version"
                        issues=$((issues + 1))
                    else
                        # Check if there's a newer version available
                        if ! check_latest_version "$module_path" "$version"; then
                            # Note: this is just a warning, not a failure
                            :
                        fi
                    fi
                else
                    print_error "Could not parse AVM module reference: $module_ref"
                    issues=$((issues + 1))
                fi
            fi
        fi
    done < "$file"

    # Check for deprecated patterns
    if grep -q "Microsoft\." "$file"; then
        print_status "Checking for raw Azure resource types..."
        local raw_resources
        raw_resources=$(grep -n "resource.*Microsoft\." "$file" || true)
        if [[ -n "$raw_resources" ]]; then
            print_warning "Consider using AVM modules instead of raw Azure resources:"
            echo "$raw_resources"
            print_status "Check https://azure.github.io/Azure-Verified-Modules/ for available modules"
        fi
    fi

    return $issues
}

# Function to suggest AVM modules for common resources
suggest_avm_modules() {
    local file="$1"

    print_status "Analyzing $file for AVM module opportunities..."

    # Common resource type to AVM module mappings
    declare -A avm_suggestions=(
        ["Microsoft.Storage/storageAccounts"]="avm/res/storage/storage-account"
        ["Microsoft.KeyVault/vaults"]="avm/res/key-vault/vault"
        ["Microsoft.Network/virtualNetworks"]="avm/res/network/virtual-network"
        ["Microsoft.Web/sites"]="avm/res/web/site"
        ["Microsoft.Web/serverfarms"]="avm/res/web/serverfarm"
        ["Microsoft.ContainerRegistry/registries"]="avm/res/container-registry/registry"
        ["Microsoft.OperationalInsights/workspaces"]="avm/res/operational-insights/workspace"
    )

    for resource_type in "${!avm_suggestions[@]}"; do
        if grep -q "$resource_type" "$file"; then
            print_status "💡 Suggestion: Consider using AVM module for $resource_type"
            echo "   Module: br/public:${avm_suggestions[$resource_type]}:<version>"
        fi
    done
}

# Main execution
main() {
    local files=("$@")
    local total_issues=0

    if [[ ${#files[@]} -eq 0 ]]; then
        print_error "No files provided"
        exit 1
    fi

    print_status "🔍 Starting AVM module version check..."

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_warning "File not found: $file"
            continue
        fi

        if [[ "$file" == *.bicep ]]; then
            print_status "Processing Bicep file: $file"

            # Check if file contains AVM modules
            if grep -q "br/public:avm/" "$file"; then
                if ! validate_avm_usage "$file"; then
                    total_issues=$((total_issues + 1))
                fi
            else
                print_warning "No AVM modules found in $file"
                suggest_avm_modules "$file"
            fi

            echo ""
        else
            print_status "Skipping non-Bicep file: $file"
        fi
    done

    if [[ $total_issues -gt 0 ]]; then
        print_error "Found $total_issues AVM module issues"
        print_status "💡 Tips:"
        echo "  • Always use specific versions instead of 'latest'"
        echo "  • Check https://azure.github.io/Azure-Verified-Modules/ for updates"
        echo "  • Use 'az rest' commands from WARP.md to check latest versions"
        exit 1
    else
        print_success "✅ All AVM modules are properly configured"
    fi
}

# Execute main function with all arguments
main "$@"
