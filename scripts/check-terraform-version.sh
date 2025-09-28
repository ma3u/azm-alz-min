#!/bin/bash
# Terraform Version Checker
# Validates Terraform version meets ALZ requirements (1.9+)

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

# Required Terraform version for ALZ
REQUIRED_TERRAFORM_VERSION="1.9.0"

# Function to compare version numbers
version_compare() {
    local version1=$1
    local version2=$2

    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}

    # Split versions into arrays
    IFS='.' read -ra VER1 <<< "$version1"
    IFS='.' read -ra VER2 <<< "$version2"

    # Compare major version
    if [[ ${VER1[0]} -gt ${VER2[0]} ]]; then
        return 0  # version1 > version2
    elif [[ ${VER1[0]} -lt ${VER2[0]} ]]; then
        return 1  # version1 < version2
    fi

    # Compare minor version
    if [[ ${VER1[1]} -gt ${VER2[1]} ]]; then
        return 0  # version1 > version2
    elif [[ ${VER1[1]} -lt ${VER2[1]} ]]; then
        return 1  # version1 < version2
    fi

    # Compare patch version
    if [[ ${VER1[2]:-0} -gt ${VER2[2]:-0} ]]; then
        return 0  # version1 > version2
    elif [[ ${VER1[2]:-0} -lt ${VER2[2]:-0} ]]; then
        return 1  # version1 < version2
    fi

    return 0  # versions are equal
}

# Function to check if terraform1.9 command exists
check_terraform19_command() {
    print_status "Checking for terraform1.9 command..."

    if command -v terraform1.9 &> /dev/null; then
        local tf19_version
        tf19_version=$(terraform1.9 version | head -1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        print_success "Found terraform1.9 command: $tf19_version"

        if version_compare "$tf19_version" "$REQUIRED_TERRAFORM_VERSION"; then
            print_success "terraform1.9 version meets requirements (>= $REQUIRED_TERRAFORM_VERSION)"
            return 0
        else
            print_error "terraform1.9 version $tf19_version is below required $REQUIRED_TERRAFORM_VERSION"
            return 1
        fi
    else
        print_error "terraform1.9 command not found"
        print_status "💡 Install Terraform 1.9+ and create terraform1.9 symlink or alias"
        return 1
    fi
}

# Function to check standard terraform command
check_terraform_command() {
    print_status "Checking standard terraform command..."

    if command -v terraform &> /dev/null; then
        local tf_version
        tf_version=$(terraform version | head -1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        print_status "Found terraform command: $tf_version"

        if version_compare "$tf_version" "$REQUIRED_TERRAFORM_VERSION"; then
            print_success "Standard terraform version meets requirements (>= $REQUIRED_TERRAFORM_VERSION)"
            print_warning "Consider using terraform1.9 command for consistency with project documentation"
            return 0
        else
            print_warning "Standard terraform version $tf_version is below required $REQUIRED_TERRAFORM_VERSION"
            return 1
        fi
    else
        print_error "terraform command not found"
        return 1
    fi
}

# Function to validate Terraform configuration files
validate_terraform_config() {
    local files=("$@")
    local issues=0

    for file in "${files[@]}"; do
        if [[ "$file" == *.tf ]]; then
            print_status "Validating Terraform configuration: $file"

            # Check for required_version constraint
            if grep -q "required_version" "$file"; then
                local version_constraint
                version_constraint=$(grep -A 1 "required_version" "$file" | grep -oE '">= [0-9]+\.[0-9]+\.[0-9]+"' || echo "")

                if [[ -n "$version_constraint" ]]; then
                    print_success "Found Terraform version constraint: $version_constraint"

                    # Extract version number
                    local constraint_version
                    constraint_version=$(echo "$version_constraint" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

                    if version_compare "$constraint_version" "$REQUIRED_TERRAFORM_VERSION"; then
                        print_success "Version constraint meets ALZ requirements"
                    else
                        print_error "Version constraint $constraint_version is below required $REQUIRED_TERRAFORM_VERSION"
                        issues=$((issues + 1))
                    fi
                else
                    print_warning "Required version constraint found but format not recognized"
                fi
            else
                print_warning "No required_version constraint found in $file"
                print_status "💡 Add: required_version = \">= $REQUIRED_TERRAFORM_VERSION\""
            fi

            # Check for AzureRM provider version
            if grep -q "azurerm" "$file"; then
                local azurerm_version
                azurerm_version=$(grep -A 5 "azurerm" "$file" | grep -oE '"~> [0-9]+\.[0-9]+\.[0-9]+"' || echo "")

                if [[ -n "$azurerm_version" ]]; then
                    print_success "Found AzureRM provider version constraint: $azurerm_version"

                    # Check if version is 3.100+ for ALZ compatibility
                    local azurerm_ver
                    azurerm_ver=$(echo "$azurerm_version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

                    if version_compare "$azurerm_ver" "3.100.0"; then
                        print_success "AzureRM provider version supports ALZ modules"
                    else
                        print_warning "AzureRM provider version $azurerm_ver may have compatibility issues with ALZ"
                        print_status "💡 Consider upgrading to AzureRM provider ~> 3.100.0"
                    fi
                fi
            fi

            echo ""
        fi
    done

    return $issues
}

# Function to provide installation guidance
provide_installation_guidance() {
    print_status "📋 Terraform 1.9+ Installation Guidance:"
    echo ""
    echo "🍎 macOS (Homebrew):"
    echo "  brew install terraform@1.9"
    echo "  ln -sf \$(brew --prefix terraform@1.9)/bin/terraform \$(brew --prefix)/bin/terraform1.9"
    echo ""
    echo "🐧 Linux (Ubuntu/Debian):"
    echo "  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com focal main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list"
    echo "  sudo apt update && sudo apt install terraform"
    echo "  sudo ln -sf \$(which terraform) /usr/local/bin/terraform1.9"
    echo ""
    echo "🪟 Windows (Chocolatey):"
    echo "  choco install terraform"
    echo "  # Create terraform1.9.exe alias manually"
    echo ""
    echo "🔗 Manual Installation:"
    echo "  1. Download from: https://releases.hashicorp.com/terraform/"
    echo "  2. Extract to PATH"
    echo "  3. Create terraform1.9 symlink/alias"
    echo ""
    print_status "✅ Verification Commands:"
    echo "  terraform1.9 version"
    echo "  terraform1.9 --help"
}

# Main execution
main() {
    local files=("$@")
    local has_errors=0

    print_status "🔧 Starting Terraform version validation for ALZ..."
    echo ""

    # Check terraform1.9 command (preferred)
    if ! check_terraform19_command; then
        has_errors=1

        # Fall back to checking standard terraform command
        if ! check_terraform_command; then
            print_error "No suitable Terraform version found"
            provide_installation_guidance
            exit 1
        else
            print_warning "Using standard terraform command instead of terraform1.9"
        fi
    fi

    echo ""

    # If files are provided, validate Terraform configuration
    if [[ ${#files[@]} -gt 0 ]]; then
        print_status "Validating Terraform configuration files..."
        if ! validate_terraform_config "${files[@]}"; then
            has_errors=1
        fi
    fi

    # Provide summary
    if [[ $has_errors -eq 0 ]]; then
        print_success "✅ Terraform version validation passed"
        print_status "💡 Remember to use terraform1.9 for all ALZ operations"
    else
        print_warning "⚠️  Terraform version validation completed with issues"
        print_status "💡 Address the issues above before proceeding with ALZ deployment"
        # Don't exit with error - this is a pre-commit hook
    fi

    echo ""
    print_status "🎯 Quick ALZ Commands:"
    echo "  cd infra/terraform/simple-sandbox"
    echo "  terraform1.9 init"
    echo "  terraform1.9 plan -var-file=terraform.tfvars"
    echo "  terraform1.9 apply -var-file=terraform.tfvars"
}

# Execute main function
main "$@"
