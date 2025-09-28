#!/bin/bash

# Azure Landing Zone Deployment Validation Script
# Last Updated: 2025-09-28
# Purpose: Validate templates, check AVM modules, and run basic pre-commit hooks

# set -e  # Commented out - handle errors manually for better reporting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_separator() {
    echo "=================================================="
}

# Function to run a check
run_check() {
    ((TOTAL_CHECKS++))
    local description="$1"
    local command="$2"

    print_status "Running: $description"

    if eval "$command" > /dev/null 2>&1; then
        print_success "$description"
        ((PASSED_CHECKS++))
        return 0
    else
        print_error "$description"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Header
print_separator
echo -e "${BLUE}🚀 Azure Landing Zone Deployment Validation${NC}"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
print_separator

# 1. Prerequisites Check
print_status "Checking prerequisites..."

PREREQ_CHECKS=0
PREREQ_PASSED=0

if command_exists az; then
    print_success "Azure CLI found"
    ((PREREQ_PASSED++))
else
    print_error "Azure CLI not found"
fi
((PREREQ_CHECKS++))

if command_exists jq; then
    print_success "jq found"
    ((PREREQ_PASSED++))
else
    print_error "jq not found"
fi
((PREREQ_CHECKS++))

if command_exists terraform1.9 || command_exists terraform; then
    print_success "Terraform found"
    ((PREREQ_PASSED++))
else
    print_error "Terraform not found"
fi
((PREREQ_CHECKS++))

if command_exists pre-commit; then
    print_success "pre-commit found"
    ((PREREQ_PASSED++))
else
    print_error "pre-commit not found"
fi
((PREREQ_CHECKS++))

print_separator

if [ $PREREQ_PASSED -ne $PREREQ_CHECKS ]; then
    print_warning "Prerequisites check: $PREREQ_PASSED/$PREREQ_CHECKS passed"
    print_warning "Some features may not work without all prerequisites"
else
    print_success "All prerequisites found"
fi

# 2. Bicep Template Validation
print_status "Validating Bicep templates..."

# Working templates
BICEP_TEMPLATES=(
    "infra/bicep/sandbox/main.bicep"
    "infra/accelerator/simple-sandbox.bicep"
    "sandbox/main.bicep"
)

for template in "${BICEP_TEMPLATES[@]}"; do
    if [ -f "$template" ]; then
        run_check "Bicep compilation: $template" "az bicep build --file '$template'"
    else
        print_warning "Template not found: $template"
    fi
done

print_separator

# 3. Terraform Template Validation
print_status "Validating Terraform templates..."

TERRAFORM_DIRS=(
    "infra/terraform/simple-sandbox"
    "sandbox"
)

for tf_dir in "${TERRAFORM_DIRS[@]}"; do
    if [ -d "$tf_dir" ]; then
        print_status "Validating Terraform in: $tf_dir"
        cd "$tf_dir"

        # Use terraform1.9 if available, otherwise terraform
        TF_CMD="terraform"
        if command_exists terraform1.9; then
            TF_CMD="terraform1.9"
        fi

        run_check "Terraform init: $tf_dir" "$TF_CMD init -backend=false"
        run_check "Terraform validate: $tf_dir" "$TF_CMD validate"

        cd - > /dev/null
    else
        print_warning "Terraform directory not found: $tf_dir"
    fi
done

print_separator

# 4. AVM Module Version Check
print_status "Checking AVM module versions..."

print_status "Checking latest AVM module versions..."

# Common AVM modules to check
AVM_MODULES=(
    "avm/res/key-vault/vault"
    "avm/res/network/virtual-network"
    "avm/res/web/serverfarm"
    "avm/res/web/site"
    "avm/res/storage/storage-account"
)

for module in "${AVM_MODULES[@]}"; do
    print_status "Checking: $module"

    # Convert path for API call - keep the original path structure
    if latest_version=$(az rest --method GET --url "https://mcr.microsoft.com/v2/bicep/$module/tags/list" 2>/dev/null | jq -r '.tags[]' | sort -V | tail -1 2>/dev/null); then
        if [ -n "$latest_version" ]; then
            print_success "$module: Latest version $latest_version"
            ((TOTAL_CHECKS++))
            ((PASSED_CHECKS++))
        else
            print_warning "$module: Could not determine latest version"
            ((TOTAL_CHECKS++))
        fi
    else
        print_warning "$module: API check failed"
        ((TOTAL_CHECKS++))
    fi
done

print_separator

# 5. Pre-commit Hooks Check
print_status "Running essential pre-commit hooks..."

PRECOMMIT_HOOKS=(
    "check-yaml"
    "check-json"
    "bicep-lint"
    "terraform_validate"
)

for hook in "${PRECOMMIT_HOOKS[@]}"; do
    run_check "Pre-commit hook: $hook" "pre-commit run $hook --all-files"
done

print_separator

# 6. Template Consistency Check
print_status "Checking template consistency..."

print_status "Verifying working templates exist..."

WORKING_TEMPLATES=(
    "infra/bicep/sandbox/main.bicep:✅ Primary sandbox template"
    "infra/terraform/simple-sandbox/main.tf:✅ Terraform equivalent"
    "infra/accelerator/simple-sandbox.bicep:✅ Quick demo"
    "sandbox/main.bicep:✅ Basic test template"
)

for template_info in "${WORKING_TEMPLATES[@]}"; do
    IFS=':' read -r template description <<< "$template_info"
    ((TOTAL_CHECKS++))
    if [ -f "$template" ]; then
        print_success "$description - Found: $template"
        ((PASSED_CHECKS++))
    else
        print_error "$description - Missing: $template"
        ((FAILED_CHECKS++))
    fi
done

print_separator

# 7. Security Configuration Check
print_status "Checking security configuration..."

((TOTAL_CHECKS++))
if [ -f ".checkov.yaml" ]; then
    print_success "Checkov configuration found"
    ((PASSED_CHECKS++))
else
    print_warning "Checkov configuration missing - create .checkov.yaml for sandbox exceptions"
fi

((TOTAL_CHECKS++))
if [ -f ".secrets.baseline" ]; then
    print_success "Secrets baseline found"
    ((PASSED_CHECKS++))
else
    print_warning "Secrets baseline missing"
fi

print_separator

# Final Summary
echo -e "${BLUE}📊 Validation Summary${NC}"
echo "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}🎉 All validations passed!${NC}"
    echo -e "${GREEN}✅ Templates are ready for deployment${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validations failed${NC}"
    echo -e "${YELLOW}⚠️  Review failed checks before deployment${NC}"
    exit 1
fi
