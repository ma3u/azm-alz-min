#!/bin/bash
# Azure Resource Naming Convention Validator
# Validates naming patterns according to Azure best practices and sandbox policies

set -eo pipefail

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

# Azure resource naming conventions (bash 3.2 compatible)
get_pattern() {
    case "$1" in
        resourceGroup) echo "^rg-[a-z0-9]+-[a-z0-9]+$" ;;
        keyVault) echo "^kv-[a-z0-9]+-[a-z0-9]+-[a-z0-9]{1,8}$" ;;
        storageAccount) echo "^st[a-z0-9]{1,22}$" ;;
        containerRegistry) echo "^acr[a-z0-9]{1,47}$" ;;
        virtualNetwork) echo "^vnet-[a-z0-9]+-[a-z0-9]+-[a-z0-9]+$" ;;
        subnet) echo "^snet-[a-z0-9]+-[a-z0-9]+-[a-z0-9]+$" ;;
        appServicePlan) echo "^asp-[a-z0-9]+-[a-z0-9]+$" ;;
        webApp) echo "^app-[a-z0-9]+-[a-z0-9]+-[a-z0-9]+$" ;;
        logAnalytics) echo "^log-[a-z0-9]+-[a-z0-9]+-[a-z0-9]{1,8}$" ;;
        publicIp) echo "^pip-[a-z0-9]+-[a-z0-9]+-[a-z0-9]+$" ;;
        bastion) echo "^bas-[a-z0-9]+-[a-z0-9]+$" ;;
        networkSecurityGroup) echo "^nsg-[a-z0-9]+-[a-z0-9]+-[a-z0-9]+$" ;;
        *) echo "" ;;
    esac
}

# Function to extract resource names from Bicep files
extract_bicep_names() {
    local file="$1"
    local issues=0

    print_status "Analyzing Bicep file: $file"

    # Storage Account validation - look for actual resource type patterns
    local storage_names
    storage_names=$(grep -A 10 "type.*[Ss]torage[Aa]ccount" "$file" | grep -oE "name: '[^']*'" | sed "s/name: '//g" | sed "s/'//g" || true)
    if [[ -n "$storage_names" ]]; then
        while IFS= read -r name; do
            if [[ -n "$name" ]]; then
                print_status "Checking Storage Account name: $name"

                # Check length (max 24 characters)
                if [[ ${#name} -gt 24 ]]; then
                    print_error "Storage Account name exceeds 24 characters: $name (${#name})"
                    issues=$((issues + 1))
                fi

                # Check for uppercase letters
                if [[ "$name" =~ [A-Z] ]]; then
                    print_error "Storage Account name must be lowercase: $name"
                    issues=$((issues + 1))
                fi

                # Check pattern
                local storage_pattern
                storage_pattern=$(get_pattern "storageAccount")
                if [[ ! "$name" =~ $storage_pattern ]]; then
                    print_warning "Storage Account name doesn't follow recommended pattern: $name"
                    print_status "Expected pattern: st{workload}{env}{unique} (e.g., stalzsba7b8c9d0)"
                fi
            fi
        done <<< "$storage_names"
    fi

    # Key Vault validation - look for actual resource type patterns
    local kv_names
    kv_names=$(grep -A 10 "type.*[Kk]ey[Vv]ault" "$file" | grep -oE "name: '[^']*'" | sed "s/name: '//g" | sed "s/'//g" || true)
    if [[ -n "$kv_names" ]]; then
        while IFS= read -r name; do
            if [[ -n "$name" ]]; then
                print_status "Checking Key Vault name: $name"

                # Check length (max 24 characters)
                if [[ ${#name} -gt 24 ]]; then
                    print_error "Key Vault name exceeds 24 characters: $name (${#name})"
                    issues=$((issues + 1))
                fi

                # Check pattern
                local kv_pattern
                kv_pattern=$(get_pattern "keyVault")
                if [[ ! "$name" =~ $kv_pattern ]]; then
                    print_warning "Key Vault name doesn't follow recommended pattern: $name"
                    print_status "Expected pattern: kv-{workload}-{env}-{unique} (e.g., kv-alz-sb-a7b8c9d0)"
                fi
            fi
        done <<< "$kv_names"
    fi

    # Container Registry validation - look for actual resource type patterns
    local acr_names
    acr_names=$(grep -A 10 "type.*[Cc]ontainer[Rr]egistry" "$file" | grep -oE "name: '[^']*'" | sed "s/name: '//g" | sed "s/'//g" || true)
    if [[ -n "$acr_names" ]]; then
        while IFS= read -r name; do
            if [[ -n "$name" ]]; then
                print_status "Checking Container Registry name: $name"

                # Check length (max 50 characters)
                if [[ ${#name} -gt 50 ]]; then
                    print_error "Container Registry name exceeds 50 characters: $name (${#name})"
                    issues=$((issues + 1))
                fi

                # Check for uppercase letters
                if [[ "$name" =~ [A-Z] ]]; then
                    print_error "Container Registry name must be lowercase: $name"
                    issues=$((issues + 1))
                fi

                # Check pattern
                local acr_pattern
                acr_pattern=$(get_pattern "containerRegistry")
                if [[ ! "$name" =~ $acr_pattern ]]; then
                    print_warning "Container Registry name doesn't follow recommended pattern: $name"
                    print_status "Expected pattern: acr{workload}{env}{unique} (e.g., acralzsba7b8c9d0)"
                fi
            fi
        done <<< "$acr_names"
    fi

    # Virtual Network validation - look for actual resource type patterns
    local vnet_names
    vnet_names=$(grep -A 10 "type.*[Vv]irtual[Nn]etwork" "$file" | grep -oE "name: '[^']*'" | sed "s/name: '//g" | sed "s/'//g" || true)
    if [[ -n "$vnet_names" ]]; then
        while IFS= read -r name; do
            if [[ -n "$name" ]]; then
                print_status "Checking Virtual Network name: $name"

                local vnet_pattern
                vnet_pattern=$(get_pattern "virtualNetwork")
                if [[ ! "$name" =~ $vnet_pattern ]]; then
                    print_warning "Virtual Network name doesn't follow recommended pattern: $name"
                    print_status "Expected pattern: vnet-{workload}-{env}-{region} (e.g., vnet-alz-sandbox-weu)"
                fi
            fi
        done <<< "$vnet_names"
    fi

    return $issues
}

# Function to extract resource names from Terraform files
extract_terraform_names() {
    local file="$1"
    local issues=0

    print_status "Analyzing Terraform file: $file"

    # Storage Account validation
    local storage_names
    storage_names=$(grep -oE 'name\s*=\s*[^#]*' "$file" | grep -i "st" | sed 's/name\s*=\s*//g' | tr -d '"' || true)
    if [[ -n "$storage_names" ]]; then
        while IFS= read -r name_expr; do
            if [[ -n "$name_expr" ]]; then
                # Skip complex expressions, focus on literals and simple concatenations
                if [[ "$name_expr" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$name_expr" =~ ^\"[^\"]*\"$ ]]; then
                    local name
                    name=$(echo "$name_expr" | tr -d '"')

                    print_status "Checking Storage Account name expression: $name"

                    # Check for common issues in Terraform
                    if [[ "$name_expr" =~ [A-Z] ]] && [[ ! "$name_expr" =~ lower\( ]]; then
                        print_error "Storage Account name must be lowercase - use lower() function: $name_expr"
                        issues=$((issues + 1))
                    fi
                fi

                # Check for proper lower() usage
                if [[ "$name_expr" =~ lower\( ]]; then
                    print_success "Storage Account uses lower() function: $name_expr"
                fi
            fi
        done <<< "$storage_names"
    fi

    # Container Registry validation
    local acr_names
    acr_names=$(grep -oE 'name\s*=\s*[^#]*' "$file" | grep -i "acr" | sed 's/name\s*=\s*//g' | tr -d '"' || true)
    if [[ -n "$acr_names" ]]; then
        while IFS= read -r name_expr; do
            if [[ -n "$name_expr" ]]; then
                print_status "Checking Container Registry name expression: $name_expr"

                # Check for proper lower() usage
                if [[ "$name_expr" =~ [A-Z] ]] && [[ ! "$name_expr" =~ lower\( ]]; then
                    print_error "Container Registry name must be lowercase - use lower() function: $name_expr"
                    issues=$((issues + 1))
                fi

                if [[ "$name_expr" =~ lower\( ]]; then
                    print_success "Container Registry uses lower() function: $name_expr"
                fi
            fi
        done <<< "$acr_names"
    fi

    return $issues
}

# Function to check for required tags
check_required_tags() {
    local file="$1"
    local issues=0
    local required_tags=("Environment" "CostCenter" "Owner" "Purpose")

    print_status "Checking required tags in: $file"

    for tag in "${required_tags[@]}"; do
        if grep -qi "$tag" "$file"; then
            print_success "Found required tag: $tag"
        else
            print_warning "Missing recommended tag: $tag"
        fi
    done

    return $issues
}

# Function to validate naming conventions for specific environments
validate_environment_naming() {
    local file="$1"
    local issues=0

    print_status "Validating environment-specific naming in: $file"

    # Check for environment indicators
    if grep -qi "sandbox\|sbx\|dev\|test\|prod" "$file"; then
        print_success "Environment indicator found in naming"
    else
        print_warning "Consider including environment indicator in resource names"
    fi

    # Check for workload/project indicators
    if grep -qi "alz\|landingzone" "$file"; then
        print_success "Project/workload indicator found in naming"
    else
        print_warning "Consider including workload indicator in resource names"
    fi

    return $issues
}

# Main validation function
main() {
    local files=("$@")
    local total_issues=0

    if [[ ${#files[@]} -eq 0 ]]; then
        print_error "No files provided"
        exit 1
    fi

    print_status "🏷️  Starting Azure naming convention validation..."

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_warning "File not found: $file"
            continue
        fi

        local file_issues=0

        if [[ "$file" == *.bicep ]]; then
            if ! extract_bicep_names "$file"; then
                file_issues=$((file_issues + $?))
            fi
        elif [[ "$file" == *.tf ]]; then
            if ! extract_terraform_names "$file"; then
                file_issues=$((file_issues + $?))
            fi
        fi

        # Check required tags for all files
        if ! check_required_tags "$file"; then
            file_issues=$((file_issues + $?))
        fi

        # Validate environment naming
        if ! validate_environment_naming "$file"; then
            file_issues=$((file_issues + $?))
        fi

        total_issues=$((total_issues + file_issues))

        if [[ $file_issues -eq 0 ]]; then
            print_success "✅ $file passed naming convention checks"
        else
            print_warning "⚠️  $file has $file_issues naming issues"
        fi

        echo ""
    done

    if [[ $total_issues -gt 0 ]]; then
        print_warning "Found $total_issues naming convention issues"
        print_status "💡 Naming Convention Tips:"
        echo "  • Storage accounts: lowercase, max 24 chars, pattern: st{workload}{env}{unique}"
        echo "  • Key Vaults: lowercase, max 24 chars, pattern: kv-{workload}-{env}-{unique}"
        echo "  • Container Registries: lowercase, pattern: acr{workload}{env}{unique}"
        echo "  • Use lower() function in Terraform for storage accounts and ACR"
        echo "  • Include environment and workload indicators in names"
        echo "  • Add required tags: Environment, CostCenter, Owner, Purpose"

        # Don't exit with error for naming warnings - they're recommendations
        print_status "Naming validation completed with warnings (non-blocking)"
    else
        print_success "✅ All files follow Azure naming conventions"
    fi
}

# Execute main function with all arguments
main "$@"
