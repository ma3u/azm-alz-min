#!/bin/bash
# Documentation Update Script
# Automatically updates documentation when infrastructure files change

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

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to update Terraform documentation
update_terraform_docs() {
    local tf_dir="$1"

    if [[ ! -d "$tf_dir" ]]; then
        return 0
    fi

    print_status "Updating Terraform documentation for: $tf_dir"

    # Check if terraform-docs is available
    if command -v terraform-docs &> /dev/null; then
        cd "$tf_dir"

        # Generate documentation
        terraform-docs markdown table . > README.md

        print_success "Updated Terraform documentation: $tf_dir/README.md"
        cd "$PROJECT_ROOT"
    else
        print_warning "terraform-docs not found - skipping Terraform documentation update"
        print_status "Install: go install github.com/terraform-docs/terraform-docs@latest"
    fi
}

# Function to extract Bicep parameters and outputs
extract_bicep_info() {
    local bicep_file="$1"
    local doc_file="${bicep_file%.*}-README.md"

    print_status "Extracting Bicep documentation from: $bicep_file"

    # Create documentation header
    cat > "$doc_file" << EOF
# $(basename "$bicep_file" .bicep)

Auto-generated documentation for Bicep template: \`$(basename "$bicep_file")\`

## Description

$(grep -E "^//" "$bicep_file" | head -5 | sed 's|^//||' | sed 's|^ ||' || echo "Azure Landing Zone Bicep template")

## Parameters

| Name | Type | Description | Default |
|------|------|-------------|---------|
EOF

    # Extract parameters
    if grep -q "^param " "$bicep_file"; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^param[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                local param_name="${BASH_REMATCH[1]}"
                local param_type="${BASH_REMATCH[2]}"
                local param_rest="${BASH_REMATCH[3]}"
                local param_default=""
                local param_desc="N/A"

                # Extract default value if present
                if [[ "$param_rest" =~ =([^=]*) ]]; then
                    param_default="${BASH_REMATCH[1]// /}"
                fi

                # Look for description in comments above
                local line_num
                line_num=$(grep -n "^param $param_name" "$bicep_file" | cut -d: -f1)
                if [[ -n "$line_num" ]] && [[ $line_num -gt 1 ]]; then
                    local prev_line
                    prev_line=$(sed -n "$((line_num-1))p" "$bicep_file")
                    if [[ "$prev_line" =~ ^//[[:space:]]*(.+)$ ]]; then
                        param_desc="${BASH_REMATCH[1]}"
                    fi
                fi

                echo "| \`$param_name\` | $param_type | $param_desc | $param_default |" >> "$doc_file"
            fi
        done < <(grep "^param " "$bicep_file")
    else
        echo "| No parameters defined | | | |" >> "$doc_file"
    fi

    # Add outputs section
    cat >> "$doc_file" << EOF

## Outputs

| Name | Type | Description |
|------|------|-------------|
EOF

    # Extract outputs
    if grep -q "^output " "$bicep_file"; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^output[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                local output_name="${BASH_REMATCH[1]}"
                local output_type="${BASH_REMATCH[2]}"
                local output_desc="N/A"

                # Look for description in comments above
                local line_num
                line_num=$(grep -n "^output $output_name" "$bicep_file" | cut -d: -f1)
                if [[ -n "$line_num" ]] && [[ $line_num -gt 1 ]]; then
                    local prev_line
                    prev_line=$(sed -n "$((line_num-1))p" "$bicep_file")
                    if [[ "$prev_line" =~ ^//[[:space:]]*(.+)$ ]]; then
                        output_desc="${BASH_REMATCH[1]}"
                    fi
                fi

                echo "| \`$output_name\` | $output_type | $output_desc |" >> "$doc_file"
            fi
        done < <(grep "^output " "$bicep_file")
    else
        echo "| No outputs defined | | |" >> "$doc_file"
    fi

    # Add resources section
    cat >> "$doc_file" << EOF

## Resources

| Type | Name |
|------|------|
EOF

    # Extract resources (including modules)
    grep -E "^(resource|module) " "$bicep_file" | while IFS= read -r line; do
        if [[ "$line" =~ ^(resource|module)[[:space:]]+([^[:space:]]+)[[:space:]]+\'([^\']+)\' ]]; then
            local resource_name="${BASH_REMATCH[2]}"
            local resource_type="${BASH_REMATCH[3]}"
            echo "| $resource_type | $resource_name |" >> "$doc_file"
        fi
    done

    # Add footer
    cat >> "$doc_file" << EOF

## Deployment

\`\`\`bash
# Deploy this template
az deployment sub create \\
  --location westeurope \\
  --template-file $(basename "$bicep_file") \\
  --parameters @parameters.json \\
  --name "deployment-\$(date +%Y%m%d-%H%M%S)"
\`\`\`

## Validation

\`\`\`bash
# Validate template
az bicep build --file $(basename "$bicep_file")

# What-if analysis
az deployment sub what-if \\
  --location westeurope \\
  --template-file $(basename "$bicep_file") \\
  --parameters @parameters.json
\`\`\`

---
*Generated automatically by update-docs.sh on $(date)*
EOF

    print_success "Generated Bicep documentation: $doc_file"
}

# Function to update main README with deployment status
update_main_readme() {
    local readme_file="$PROJECT_ROOT/README.md"

    print_status "Updating main README.md with current infrastructure status"

    # Check if deployment info exists
    if [[ -f "$PROJECT_ROOT/.secrets/cicd-config.json" ]]; then
        local subscription_id
        subscription_id=$(grep -o '"subscriptionId": "[^"]*"' "$PROJECT_ROOT/.secrets/cicd-config.json" | cut -d'"' -f4 2>/dev/null || echo "N/A")

        local key_vault_name
        key_vault_name=$(grep -o '"keyVaultName": "[^"]*"' "$PROJECT_ROOT/.secrets/cicd-config.json" | cut -d'"' -f4 2>/dev/null || echo "N/A")

        # Update deployment status section
        local temp_file
        temp_file=$(mktemp)

        if grep -q "## Current Deployment Status" "$readme_file"; then
            # Replace existing section
            awk '
            /^## Current Deployment Status/ {
                print "## Current Deployment Status"
                print ""
                print "| Component | Status | Details |"
                print "|-----------|---------|---------|"
                print "| Azure Subscription | ✅ Active | '"$subscription_id"' |"
                print "| Key Vault (CI/CD) | ✅ Deployed | '"$key_vault_name"' |"
                print "| Pre-commit Hooks | ✅ Configured | Bicep, Terraform, Security |"
                print "| GitHub Actions | ⚠️ Pending | Workflow created, needs testing |"
                print "| Azure DevOps | ⚠️ Pending | Pipeline created, needs testing |"
                print ""
                print "*Last updated: $(date)*"
                print ""
                skip = 1
                next
            }
            /^## / && skip { skip = 0 }
            !skip { print }
            ' "$readme_file" > "$temp_file"
        else
            # Add new section before "## Prerequisites"
            awk '
            /^## Prerequisites/ {
                print "## Current Deployment Status"
                print ""
                print "| Component | Status | Details |"
                print "|-----------|---------|---------|"
                print "| Azure Subscription | ✅ Active | '"$subscription_id"' |"
                print "| Key Vault (CI/CD) | ✅ Deployed | '"$key_vault_name"' |"
                print "| Pre-commit Hooks | ✅ Configured | Bicep, Terraform, Security |"
                print "| GitHub Actions | ⚠️ Pending | Workflow created, needs testing |"
                print "| Azure DevOps | ⚠️ Pending | Pipeline created, needs testing |"
                print ""
                print "*Last updated: $(date)*"
                print ""
            }
            { print }
            ' "$readme_file" > "$temp_file"
        fi

        mv "$temp_file" "$readme_file"
        print_success "Updated deployment status in README.md"
    fi
}

# Function to generate infrastructure overview
generate_infrastructure_overview() {
    local overview_file="$PROJECT_ROOT/docs/infrastructure-overview.md"

    print_status "Generating infrastructure overview documentation"

    mkdir -p "$(dirname "$overview_file")"

    cat > "$overview_file" << EOF
# Infrastructure Overview

Auto-generated overview of Azure Landing Zone infrastructure components.

## Architecture

\`\`\`mermaid
graph TB
    subgraph "Azure Subscription"
        subgraph "Hub Resource Group"
            KV[Key Vault<br/>CI/CD Secrets]
            HUB[Hub VNet<br/>10.0.0.0/16]
            BASTION[Azure Bastion<br/>SSH Access]
        end

        subgraph "Spoke Resource Group"
            SPOKE[Spoke VNet<br/>10.1.0.0/16]
            APP[App Service<br/>Web Application]
            STORAGE[Storage Account<br/>Static Files]
        end

        subgraph "Management"
            LOG[Log Analytics<br/>Monitoring]
            ACR[Container Registry<br/>Images]
        end
    end

    HUB --> SPOKE
    BASTION --> SPOKE
    APP --> STORAGE
    LOG --> APP
    ACR --> APP
\`\`\`

## Components

### Core Infrastructure

EOF

    # Add Bicep templates
    if find "$PROJECT_ROOT/infra" -name "*.bicep" -type f | head -5 | while IFS= read -r bicep_file; do
        local rel_path
        rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$bicep_file")
        echo "- **$(basename "$bicep_file" .bicep)**: \`$rel_path\`" >> "$overview_file"
    done; then
        echo "" >> "$overview_file"
    fi

    # Add Terraform modules
    echo "### Terraform Modules" >> "$overview_file"
    echo "" >> "$overview_file"

    if find "$PROJECT_ROOT/infra" -name "*.tf" -type f | head -5 | while IFS= read -r tf_file; do
        local rel_path
        rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$tf_file")
        echo "- **$(dirname "$rel_path" | xargs basename)**: \`$rel_path\`" >> "$overview_file"
    done; then
        echo "" >> "$overview_file"
    fi

    # Add CI/CD information
    cat >> "$overview_file" << EOF
### CI/CD Configuration

- **Pre-commit Hooks**: \`.pre-commit-config.yaml\`
- **GitHub Actions**: \`.github/workflows/\`
- **Azure DevOps**: \`azure-pipelines.yml\`
- **Security Scanning**: Checkov configuration in \`.checkov.yaml\`

### Deployment Scripts

- **Key Vault Setup**: \`scripts/setup-keyvault-cicd.sh\`
- **AVM Version Check**: \`scripts/check-avm-versions.sh\`
- **Naming Validation**: \`scripts/validate-naming.sh\`
- **Terraform Version Check**: \`scripts/check-terraform-version.sh\`

## Deployment Commands

### Quick Start (Sandbox)

\`\`\`bash
# Set up CI/CD secrets
./scripts/setup-keyvault-cicd.sh

# Deploy sandbox ALZ
cd infra/bicep/sandbox
az deployment sub create \\
  --location westeurope \\
  --template-file main.bicep \\
  --parameters @main.parameters.json \\
  --name "alz-sandbox-\$(date +%Y%m%d-%H%M%S)"
\`\`\`

### Terraform Deployment

\`\`\`bash
# Initialize and apply
cd infra/terraform/simple-sandbox
terraform1.9 init
terraform1.9 plan -var-file=terraform.tfvars
terraform1.9 apply -var-file=terraform.tfvars
\`\`\`

## Security and Compliance

- **Pre-commit hooks** validate code before commits
- **Checkov scanning** ensures security compliance
- **AVM module verification** enforces Microsoft best practices
- **Naming convention validation** maintains consistency
- **Secret management** through Azure Key Vault

---
*Generated on $(date) by update-docs.sh*
EOF

    print_success "Generated infrastructure overview: $overview_file"
}

# Main execution
main() {
    local files=("$@")
    local updated_docs=false

    print_status "🔄 Starting documentation update process..."

    # If no files provided, process all infrastructure files
    if [[ ${#files[@]} -eq 0 ]]; then
        print_status "No specific files provided, checking for infrastructure changes..."

        # Check for staged changes in git
        if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
            local staged_files
            staged_files=$(git diff --cached --name-only --diff-filter=AM | grep -E '\.(bicep|tf|md)$' || true)

            if [[ -n "$staged_files" ]]; then
                print_status "Found staged infrastructure files:"
                echo "$staged_files"
                files=()
                while IFS= read -r file; do
                    files+=("$file")
                done <<< "$staged_files"
            fi
        fi
    fi

    # Process each file
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local abs_file
        abs_file=$(realpath "$file" 2>/dev/null || echo "$file")

        case "$file" in
            *.bicep)
                if [[ -f "$abs_file" ]]; then
                    extract_bicep_info "$abs_file"
                    updated_docs=true
                fi
                ;;
            *.tf)
                local tf_dir
                tf_dir=$(dirname "$abs_file")
                update_terraform_docs "$tf_dir"
                updated_docs=true
                ;;
            *.md)
                print_status "Markdown file changed: $file"
                # Could add markdown validation here
                ;;
        esac
    done

    # Update main documentation
    update_main_readme
    generate_infrastructure_overview
    updated_docs=true

    if [[ "$updated_docs" == true ]]; then
        print_success "✅ Documentation update completed"
        print_status "📝 Updated files may need to be staged for commit"

        # Suggest commands to stage updated docs
        if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
            print_status "💡 Stage updated documentation:"
            echo "  git add README.md docs/ **/*-README.md"
        fi
    else
        print_status "No documentation updates needed"
    fi
}

# Execute main function
main "$@"
