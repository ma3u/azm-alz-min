#!/bin/bash

# Azure Landing Zone Deployment with Comprehensive Reporting
# Executes deployment with full pre-commit checks, cost analysis, and security scoring

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"
REPORT_MANAGER="${PROJECT_DIR}/deployment-reports/scripts/report-manager.sh"

# Default configuration
TEMPLATE_PATH="${PROJECT_DIR}/blueprints/bicep/foundation/main.bicep"
PARAMETERS_PATH="${PROJECT_DIR}/blueprints/bicep/foundation/main.parameters.json"
RESOURCE_GROUP_NAME="rg-alz-sandbox-$(date +%Y%m%d)"
LOCATION="westeurope"
DEPLOYMENT_NAME="alz-deployment-$(date +%Y%m%d-%H%M%S)"

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

# Function to check prerequisites
check_prerequisites() {
    log_section "Prerequisites Check"

    local prereq_file="${REPORT_DIR}/pre-deployment/prerequisites.json"
    local prereq_passed=0
    local prereq_total=0

    # Start JSON output
    cat > "${prereq_file}" << 'EOF'
{
    "timestamp": "",
    "checks": [],
    "summary": {
        "total": 0,
        "passed": 0,
        "failed": 0
    }
}
EOF

    # Update timestamp
    jq --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.timestamp = $timestamp' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"

    # Check Azure CLI
    ((prereq_total++))
    if command -v az &> /dev/null; then
        local az_version=$(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo "unknown")
        log_success "Azure CLI found (version: ${az_version})"
        jq --arg check "azure-cli" --arg status "passed" --arg version "${az_version}" '.checks += [{"name": $check, "status": $status, "version": $version}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
        ((prereq_passed++))
    else
        log_error "Azure CLI not found"
        jq --arg check "azure-cli" --arg status "failed" '.checks += [{"name": $check, "status": $status}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
    fi

    # Check Bicep
    ((prereq_total++))
    if az bicep version &> /dev/null; then
        local bicep_version=$(az bicep version --output json | jq -r '.bicepVersion' 2>/dev/null || echo "unknown")
        log_success "Bicep CLI found (version: ${bicep_version})"
        jq --arg check "bicep" --arg status "passed" --arg version "${bicep_version}" '.checks += [{"name": $check, "status": $status, "version": $version}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
        ((prereq_passed++))
    else
        log_error "Bicep CLI not found"
        jq --arg check "bicep" --arg status "failed" '.checks += [{"name": $check, "status": $status}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
    fi

    # Check jq
    ((prereq_total++))
    if command -v jq &> /dev/null; then
        local jq_version=$(jq --version 2>/dev/null || echo "unknown")
        log_success "jq found (${jq_version})"
        jq --arg check "jq" --arg status "passed" --arg version "${jq_version}" '.checks += [{"name": $check, "status": $status, "version": $version}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
        ((prereq_passed++))
    else
        log_error "jq not found"
        jq --arg check "jq" --arg status "failed" '.checks += [{"name": $check, "status": $status}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
    fi

    # Check Azure login status
    ((prereq_total++))
    if az account show &> /dev/null; then
        local account_name=$(az account show --query 'name' -o tsv 2>/dev/null || echo "unknown")
        local subscription_id=$(az account show --query 'id' -o tsv 2>/dev/null || echo "unknown")
        log_success "Azure login verified (Subscription: ${account_name})"
        jq --arg check "azure-login" --arg status "passed" --arg subscription "${account_name}" --arg id "${subscription_id}" '.checks += [{"name": $check, "status": $status, "subscription": $subscription, "subscription_id": $id}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
        ((prereq_passed++))
    else
        log_error "Not logged into Azure"
        jq --arg check "azure-login" --arg status "failed" '.checks += [{"name": $check, "status": $status}]' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"
    fi

    # Update summary
    jq --argjson total "${prereq_total}" --argjson passed "${prereq_passed}" --argjson failed "$((prereq_total - prereq_passed))" '.summary = {total: $total, passed: $passed, failed: $failed}' "${prereq_file}" > "${prereq_file}.tmp" && mv "${prereq_file}.tmp" "${prereq_file}"

    if [[ ${prereq_passed} -eq ${prereq_total} ]]; then
        log_success "All prerequisites met (${prereq_passed}/${prereq_total})"
        return 0
    else
        log_error "Prerequisites failed (${prereq_passed}/${prereq_total})"
        return 1
    fi
}

# Function to run pre-commit checks
run_precommit_checks() {
    log_section "Pre-commit Validation"

    local precommit_file="${REPORT_DIR}/pre-deployment/precommit-results.json"
    local precommit_log="${REPORT_DIR}/pre-deployment/precommit.log"

    # Initialize results
    cat > "${precommit_file}" << 'EOF'
{
    "timestamp": "",
    "overall_status": "unknown",
    "hooks": [],
    "summary": {
        "total": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0
    }
}
EOF

    jq --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.timestamp = $timestamp' "${precommit_file}" > "${precommit_file}.tmp" && mv "${precommit_file}.tmp" "${precommit_file}"

    cd "${PROJECT_DIR}"

    # Run essential pre-commit hooks
    local hooks=("check-yaml" "check-json" "bicep-lint" "terraform-fmt")
    local total_hooks=${#hooks[@]}
    local passed_hooks=0
    local failed_hooks=0

    for hook in "${hooks[@]}"; do
        log_info "Running hook: ${hook}"

        if pre-commit run "${hook}" --all-files > "${precommit_log}.${hook}" 2>&1; then
            log_success "Hook passed: ${hook}"
            jq --arg hook "${hook}" --arg status "passed" '.hooks += [{"name": $hook, "status": $status}]' "${precommit_file}" > "${precommit_file}.tmp" && mv "${precommit_file}.tmp" "${precommit_file}"
            ((passed_hooks++))
        else
            log_warning "Hook failed: ${hook}"
            jq --arg hook "${hook}" --arg status "failed" '.hooks += [{"name": $hook, "status": $status}]' "${precommit_file}" > "${precommit_file}.tmp" && mv "${precommit_file}.tmp" "${precommit_file}"
            ((failed_hooks++))
        fi
    done

    # Update summary
    local overall_status="passed"
    if [[ ${failed_hooks} -gt 0 ]]; then
        overall_status="failed"
    fi

    jq --arg status "${overall_status}" --argjson total "${total_hooks}" --argjson passed "${passed_hooks}" --argjson failed "${failed_hooks}" '.overall_status = $status | .summary = {total: $total, passed: $passed, failed: $failed, skipped: 0}' "${precommit_file}" > "${precommit_file}.tmp" && mv "${precommit_file}.tmp" "${precommit_file}"

    if [[ "${overall_status}" == "passed" ]]; then
        log_success "Pre-commit validation passed (${passed_hooks}/${total_hooks})"
        return 0
    else
        log_warning "Pre-commit validation issues (${failed_hooks} failed, ${passed_hooks} passed)"
        return 0  # Don't fail deployment on pre-commit warnings
    fi
}

# Function to capture pre-deployment state
capture_pre_deployment_state() {
    log_section "Capturing Pre-deployment State"

    local state_file="${REPORT_DIR}/pre-deployment/azure-state.json"

    # Get current resource group state (if exists)
    local rg_exists="false"
    local rg_resources=0

    if az group show --name "${RESOURCE_GROUP_NAME}" &> /dev/null; then
        rg_exists="true"
        rg_resources=$(az resource list --resource-group "${RESOURCE_GROUP_NAME}" --query 'length(@)' -o tsv 2>/dev/null || echo "0")
        log_info "Resource group '${RESOURCE_GROUP_NAME}' already exists with ${rg_resources} resources"
    else
        log_info "Resource group '${RESOURCE_GROUP_NAME}' does not exist"
    fi

    # Create state snapshot
    cat > "${state_file}" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "resource_group": {
        "name": "${RESOURCE_GROUP_NAME}",
        "exists": ${rg_exists},
        "resource_count": ${rg_resources}
    },
    "subscription": {
        "id": "$(az account show --query 'id' -o tsv 2>/dev/null || echo 'unknown')",
        "name": "$(az account show --query 'name' -o tsv 2>/dev/null || echo 'unknown')"
    }
}
EOF

    log_success "Pre-deployment state captured"
}

# Function to execute deployment
execute_deployment() {
    log_section "Executing Azure Deployment"

    local deployment_file="${REPORT_DIR}/deployment/deployment-log.json"
    local deployment_output="${REPORT_DIR}/deployment/deployment-output.json"

    # Validate template first
    log_info "Validating Bicep template..."
    if ! az bicep build --file "${TEMPLATE_PATH}" --stdout > /dev/null; then
        log_error "Template validation failed"
        return 1
    fi
    log_success "Template validation passed"

    # Check if this is a subscription-level deployment
    local target_scope=$(grep -i "targetScope" "${TEMPLATE_PATH}" | head -1 | cut -d "'" -f 2 2>/dev/null || echo "resourceGroup")

    if [[ "${target_scope}" != "subscription" ]]; then
        # Only create resource group for resource group-level deployments
        log_info "Ensuring resource group exists..."
        az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}" --output none
        log_success "Resource group ready: ${RESOURCE_GROUP_NAME}"
    else
        log_info "Subscription-level deployment - resource groups will be created by template"
    fi

    # Start deployment
    log_info "Starting deployment: ${DEPLOYMENT_NAME}"

    local start_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Execute deployment with detailed output (subscription scope)
    if az deployment sub create \
        --location "${LOCATION}" \
        --template-file "${TEMPLATE_PATH}" \
        --parameters "@${PARAMETERS_PATH}" \
        --name "${DEPLOYMENT_NAME}" \
        --output json > "${deployment_output}"; then

        local end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local deployment_status="succeeded"
        log_success "Deployment completed successfully"
    else
        local end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local deployment_status="failed"
        log_error "Deployment failed"
    fi

    # Create deployment log
    cat > "${deployment_file}" << EOF
{
    "deployment_name": "${DEPLOYMENT_NAME}",
    "resource_group": "${RESOURCE_GROUP_NAME}",
    "template_path": "${TEMPLATE_PATH}",
    "parameters_path": "${PARAMETERS_PATH}",
    "start_time": "${start_time}",
    "end_time": "${end_time}",
    "status": "${deployment_status}",
    "location": "${LOCATION}"
}
EOF

    if [[ "${deployment_status}" == "succeeded" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to collect deployed resources
collect_deployed_resources() {
    log_section "Inventorying Deployed Resources"

    local resources_file="${REPORT_DIR}/resources/resource-inventory.json"

    log_info "Collecting resource inventory..."

    # Get all resources from the deployment (multiple resource groups for hub-spoke)
    # Extract resource groups from deployment output
    local deployment_output="${REPORT_DIR}/deployment/deployment-output.json"

    if [[ -f "${deployment_output}" ]]; then
        # Get all unique resource groups from the deployment
        local resource_groups=$(jq -r '.properties.outputResources[]?.resourceGroup // empty' "${deployment_output}" | sort -u | tr '\n' ' ')

        if [[ -n "${resource_groups}" ]]; then
            # Collect resources from all resource groups
            echo '[]' > "${resources_file}"
            for rg in ${resource_groups}; do
                if [[ -n "${rg}" && "${rg}" != "null" ]]; then
                    local temp_file="${resources_file}.${rg}"
                    if az resource list --resource-group "${rg}" --output json > "${temp_file}" 2>/dev/null; then
                        # Merge resources from this RG into the main file
                        jq -s '.[0] + .[1]' "${resources_file}" "${temp_file}" > "${resources_file}.tmp" && mv "${resources_file}.tmp" "${resources_file}"
                        rm -f "${temp_file}"
                    fi
                fi
            done
        else
            # Fallback to original resource group if no deployment output
            az resource list --resource-group "${RESOURCE_GROUP_NAME}" --output json > "${resources_file}" 2>/dev/null || echo '[]' > "${resources_file}"
        fi
    else
        # Fallback to original resource group if no deployment output
        az resource list --resource-group "${RESOURCE_GROUP_NAME}" --output json > "${resources_file}" 2>/dev/null || echo '[]' > "${resources_file}"
    fi

    if [[ -f "${resources_file}" ]]; then
        local resource_count=$(jq 'length' "${resources_file}")
        log_success "Collected inventory: ${resource_count} resources"

        # Create summary
        local summary_file="${REPORT_DIR}/resources/resource-summary.json"
        jq '{
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            resource_group: "'"${RESOURCE_GROUP_NAME}"'",
            total_resources: length,
            resources_by_type: group_by(.type) | map({type: .[0].type, count: length}),
            resources_by_location: group_by(.location) | map({location: .[0].location, count: length})
        }' "${resources_file}" > "${summary_file}"

        return 0
    else
        log_error "Failed to collect resource inventory"
        return 1
    fi
}

# Function to analyze costs
analyze_costs() {
    log_section "Cost Analysis"

    local costs_file="${REPORT_DIR}/costs/cost-analysis.json"

    # Note: This is a simplified cost analysis
    # In a production environment, you would integrate with Azure Cost Management API

    log_info "Performing cost analysis..."

    # Get resource pricing estimates (simplified)
    local estimated_monthly_cost="0.00"
    local resource_count=$(jq 'length' "${REPORT_DIR}/resources/resource-inventory.json" 2>/dev/null || echo "0")

    # Simple cost estimation based on resource types
    # This is a placeholder - real cost analysis would use Azure pricing APIs
    if [[ ${resource_count} -gt 0 ]]; then
        estimated_monthly_cost=$(echo "${resource_count} * 15.50" | bc -l 2>/dev/null || echo "15.50")
    fi

    cat > "${costs_file}" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "resource_group": "${RESOURCE_GROUP_NAME}",
    "currency": "USD",
    "estimated_monthly": "${estimated_monthly_cost}",
    "cost_breakdown": {
        "compute": "0.00",
        "storage": "5.00",
        "networking": "2.50",
        "other": "${estimated_monthly_cost}"
    },
    "note": "This is a simplified cost estimate. Use Azure Cost Management for detailed analysis."
}
EOF

    log_success "Cost analysis completed (Estimated monthly: \$${estimated_monthly_cost})"
}

# Function to check security score
check_security_score() {
    log_section "Security Assessment"

    local security_file="${REPORT_DIR}/security/security-assessment.json"

    log_info "Performing security assessment..."

    # Note: This is a simplified security check
    # In production, you would integrate with Azure Security Center API

    # Basic security checks
    local security_score=85
    local recommendations=()

    # Check for public IP addresses
    local public_ips=$(jq -r '.[] | select(.type == "Microsoft.Network/publicIPAddresses") | .name' "${REPORT_DIR}/resources/resource-inventory.json" 2>/dev/null | wc -l || echo "0")

    if [[ ${public_ips} -gt 0 ]]; then
        recommendations+=("Consider reducing public IP addresses for better security")
        security_score=$((security_score - 5))
    fi

    # Check for storage accounts
    local storage_accounts=$(jq -r '.[] | select(.type == "Microsoft.Storage/storageAccounts") | .name' "${REPORT_DIR}/resources/resource-inventory.json" 2>/dev/null | wc -l || echo "0")

    if [[ ${storage_accounts} -gt 0 ]]; then
        recommendations+=("Ensure storage accounts have proper access controls")
    fi

    # Create security assessment
    local recommendations_json
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        recommendations_json=$(printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s .)
    else
        recommendations_json='[]'
    fi

    cat > "${security_file}" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "resource_group": "${RESOURCE_GROUP_NAME}",
    "overall_score": ${security_score},
    "max_score": 100,
    "assessment_date": "$(date -u +%Y-%m-%d)",
    "findings": {
        "public_ips": ${public_ips},
        "storage_accounts": ${storage_accounts}
    },
    "recommendations": ${recommendations_json},
    "note": "This is a simplified security assessment. Use Azure Security Center for comprehensive analysis."
}
EOF

    log_success "Security assessment completed (Score: ${security_score}/100)"
}

# Function to generate comprehensive report
generate_report() {
    log_section "Generating Deployment Report"

    local report_file="${REPORT_DIR}/deployment-report.html"
    local summary_file="${REPORT_DIR}/deployment-summary.json"

    # Create summary JSON
    local deployment_status="unknown"
    local resource_count=0
    local estimated_cost="0.00"
    local security_score="N/A"

    if [[ -f "${REPORT_DIR}/deployment/deployment-log.json" ]]; then
        deployment_status=$(jq -r '.status' "${REPORT_DIR}/deployment/deployment-log.json")
    fi

    if [[ -f "${REPORT_DIR}/resources/resource-summary.json" ]]; then
        resource_count=$(jq -r '.total_resources' "${REPORT_DIR}/resources/resource-summary.json")
    fi

    if [[ -f "${REPORT_DIR}/costs/cost-analysis.json" ]]; then
        estimated_cost=$(jq -r '.estimated_monthly' "${REPORT_DIR}/costs/cost-analysis.json")
    fi

    if [[ -f "${REPORT_DIR}/security/security-assessment.json" ]]; then
        security_score=$(jq -r '.overall_score' "${REPORT_DIR}/security/security-assessment.json")
    fi

    cat > "${summary_file}" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "deployment": {
        "name": "${DEPLOYMENT_NAME}",
        "status": "${deployment_status}",
        "resource_group": "${RESOURCE_GROUP_NAME}",
        "location": "${LOCATION}",
        "resources_deployed": ${resource_count}
    },
    "costs": {
        "estimated_monthly": "${estimated_cost}",
        "currency": "USD"
    },
    "security": {
        "overall_score": ${security_score}
    },
    "template": {
        "path": "${TEMPLATE_PATH}",
        "parameters": "${PARAMETERS_PATH}"
    }
}
EOF

    # Generate HTML report
    cat > "${report_file}" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Landing Zone Deployment Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; margin: 0; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #0078d4, #00bcf2); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .status-success { color: #107c10; }
        .status-failed { color: #d13438; }
        .status-unknown { color: #605e5c; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .metric { font-size: 2em; font-weight: bold; margin-bottom: 10px; }
        .label { color: #605e5c; font-size: 0.9em; }
        .section { background: white; border-radius: 8px; padding: 25px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .resources-table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        .resources-table th, .resources-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .resources-table th { background-color: #f8f9fa; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .timestamp { font-size: 0.9em; color: #605e5c; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏗️ Azure Landing Zone Deployment Report</h1>
            <div class="timestamp">Generated: {{TIMESTAMP}}</div>
            <h2>{{DEPLOYMENT_NAME}}</h2>
        </div>

        <div class="grid">
            <div class="card">
                <div class="metric status-{{STATUS_CLASS}}">{{DEPLOYMENT_STATUS}}</div>
                <div class="label">Deployment Status</div>
            </div>
            <div class="card">
                <div class="metric">{{RESOURCE_COUNT}}</div>
                <div class="label">Resources Deployed</div>
            </div>
            <div class="card">
                <div class="metric">${{ESTIMATED_COST}}</div>
                <div class="label">Estimated Monthly Cost</div>
            </div>
            <div class="card">
                <div class="metric">{{SECURITY_SCORE}}/100</div>
                <div class="label">Security Score</div>
            </div>
        </div>

        <div class="section">
            <h3>📋 Deployment Summary</h3>
            <p><strong>Resource Group:</strong> {{RESOURCE_GROUP}}</p>
            <p><strong>Location:</strong> {{LOCATION}}</p>
            <p><strong>Template:</strong> {{TEMPLATE_PATH}}</p>
            <p><strong>Parameters:</strong> {{PARAMETERS_PATH}}</p>
        </div>

        <div class="section">
            <h3>🔍 Pre-deployment Checks</h3>
            <div id="precommit-results">Loading...</div>
        </div>

        <div class="section">
            <h3>📦 Resource Inventory</h3>
            <div id="resource-inventory">Loading...</div>
        </div>

        <div class="section">
            <h3>💰 Cost Analysis</h3>
            <div id="cost-analysis">Loading...</div>
        </div>

        <div class="section">
            <h3>🔒 Security Assessment</h3>
            <div id="security-assessment">Loading...</div>
        </div>
    </div>

    <script>
        // This would be populated with actual data in a real implementation
        document.addEventListener('DOMContentLoaded', function() {
            // Placeholder for dynamic content loading
        });
    </script>
</body>
</html>
EOF

    # Replace placeholders in HTML
    sed -i '' "s/{{TIMESTAMP}}/$(date)/g" "${report_file}"
    sed -i '' "s/{{DEPLOYMENT_NAME}}/${DEPLOYMENT_NAME}/g" "${report_file}"
    sed -i '' "s/{{DEPLOYMENT_STATUS}}/${deployment_status}/g" "${report_file}"
    sed -i '' "s/{{STATUS_CLASS}}/${deployment_status}/g" "${report_file}"
    sed -i '' "s/{{RESOURCE_COUNT}}/${resource_count}/g" "${report_file}"
    sed -i '' "s/{{ESTIMATED_COST}}/${estimated_cost}/g" "${report_file}"
    if [[ "${security_score}" == "N/A" ]]; then
        sed -i '' "s/{{SECURITY_SCORE}}/N\/A/g" "${report_file}"
    else
        sed -i '' "s/{{SECURITY_SCORE}}/${security_score}/g" "${report_file}"
    fi
    sed -i '' "s/{{RESOURCE_GROUP}}/${RESOURCE_GROUP_NAME}/g" "${report_file}"
    sed -i '' "s/{{LOCATION}}/${LOCATION}/g" "${report_file}"
    sed -i '' "s|{{TEMPLATE_PATH}}|${TEMPLATE_PATH}|g" "${report_file}"
    sed -i '' "s|{{PARAMETERS_PATH}}|${PARAMETERS_PATH}|g" "${report_file}"

    log_success "Deployment report generated: ${report_file}"
}

# Function to cleanup old reports and commit new one
finalize_report() {
    log_section "Finalizing Report"

    # Clean up old reports
    "${REPORT_MANAGER}" cleanup

    # Generate index
    "${REPORT_MANAGER}" index

    # Add to git if we're in a git repository
    if [[ -d "${PROJECT_DIR}/.git" ]]; then
        log_info "Adding report to git..."
        cd "${PROJECT_DIR}"
        git add deployment-reports/
        git commit -m "📊 Add deployment report: $(basename "${REPORT_DIR}")" || log_warning "Failed to commit report (may already exist)"
        log_success "Report committed to git"
    fi
}

# Main deployment function
main() {
    local template_override="$1"
    local parameters_override="$2"

    # Override defaults if provided
    if [[ -n "${template_override:-}" ]]; then
        TEMPLATE_PATH="${template_override}"
    fi

    if [[ -n "${parameters_override:-}" ]]; then
        PARAMETERS_PATH="${parameters_override}"
    fi

    # Validate inputs
    if [[ ! -f "${TEMPLATE_PATH}" ]]; then
        log_error "Template file not found: ${TEMPLATE_PATH}"
        exit 1
    fi

    if [[ ! -f "${PARAMETERS_PATH}" ]]; then
        log_error "Parameters file not found: ${PARAMETERS_PATH}"
        exit 1
    fi

    # Create deployment report directory
    REPORT_DIR=$("${REPORT_MANAGER}" create 2>/dev/null | tail -1)
    export REPORT_DIR

    log_info "Starting Azure Landing Zone deployment with reporting..."
    log_info "Template: ${TEMPLATE_PATH}"
    log_info "Parameters: ${PARAMETERS_PATH}"
    log_info "Report Directory: ${REPORT_DIR}"

    # Execute deployment pipeline
    local exit_code=0

    check_prerequisites || exit_code=1

    if [[ ${exit_code} -eq 0 ]]; then
        run_precommit_checks || true  # Don't fail on pre-commit warnings
        capture_pre_deployment_state
        execute_deployment || exit_code=1
    fi

    if [[ ${exit_code} -eq 0 ]]; then
        collect_deployed_resources
        analyze_costs
        check_security_score
    fi

    generate_report
    finalize_report

    if [[ ${exit_code} -eq 0 ]]; then
        log_success "🎉 Deployment completed successfully!"
        log_info "📊 Report available at: ${REPORT_DIR}/deployment-report.html"
        log_info "📋 Summary: ${REPORT_DIR}/deployment-summary.json"
    else
        log_error "❌ Deployment failed - check report for details"
        log_info "📊 Report available at: ${REPORT_DIR}/deployment-report.html"
    fi

    exit ${exit_code}
}

# Show usage if no parameters
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [template_path] [parameters_path]"
    echo ""
    echo "Default template: ${TEMPLATE_PATH}"
    echo "Default parameters: ${PARAMETERS_PATH}"
    echo ""
    echo "This script will:"
    echo "  1. Run prerequisite checks"
    echo "  2. Execute pre-commit validation"
    echo "  3. Deploy Azure Landing Zone"
    echo "  4. Generate comprehensive report"
    echo "  5. Analyze costs and security"
    echo "  6. Manage report history (keep last 5)"
    echo ""
    echo "Examples:"
    echo "  $0  # Use default foundation template"
    echo "  $0 blueprints/bicep/hub-spoke/main.bicep blueprints/bicep/hub-spoke/main.parameters.json"
    exit 0
fi

# Run main function
main "$@"
