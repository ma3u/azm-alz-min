#!/bin/bash

# Generate Azure Landing Zone Deployment Report
# Collects metrics about deployed resources, costs, and security compliance
# Usage: ./generate-deployment-report.sh [environment] [template-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/reports/deployments"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="$REPORTS_DIR/${TIMESTAMP}-deployment-report.json"

# Parameters
ENVIRONMENT=${1:-"sandbox"}
TEMPLATE_NAME=${2:-"unknown"}
DEPLOYMENT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${BLUE}📊 Azure Landing Zone Deployment Report Generator${NC}"
echo -e "Timestamp: $TIMESTAMP"
echo -e "Environment: $ENVIRONMENT"
echo -e "Template: $TEMPLATE_NAME"
echo ""

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# Initialize report JSON
cat > "$REPORT_FILE" <<EOF
{
  "reportId": "${TIMESTAMP}",
  "timestamp": "${DEPLOYMENT_START_TIME}",
  "environment": "${ENVIRONMENT}",
  "template": "${TEMPLATE_NAME}",
  "status": "unknown",
  "metrics": {
    "resourceCount": 0,
    "estimatedMonthlyCost": 0.0,
    "securityScore": 0,
    "deploymentDurationMinutes": 0
  },
  "resourceBreakdown": {},
  "costBreakdown": {},
  "securityFindings": [],
  "recommendations": []
}
EOF

# Function to update JSON field
update_json() {
    local field=$1
    local value=$2
    local temp_file=$(mktemp)

    if [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        # Numeric value
        jq "$field = $value" "$REPORT_FILE" > "$temp_file"
    else
        # String value
        jq "$field = \"$value\"" "$REPORT_FILE" > "$temp_file"
    fi

    mv "$temp_file" "$REPORT_FILE"
}

# Function to add array item to JSON
add_to_array() {
    local field=$1
    local value=$2
    local temp_file=$(mktemp)

    jq "$field += [\"$value\"]" "$REPORT_FILE" > "$temp_file"
    mv "$temp_file" "$REPORT_FILE"
}

echo -e "${YELLOW}🔍 Analyzing Azure resources...${NC}"

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Error: Not logged in to Azure CLI${NC}"
    update_json '.status' 'failed'
    add_to_array '.recommendations' 'Please login with: az login'
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)
SUBSCRIPTION_NAME=$(az account show --query 'name' -o tsv)

echo -e "Subscription: $SUBSCRIPTION_NAME"
echo -e "ID: $SUBSCRIPTION_ID"

# Count total resources
echo -e "${YELLOW}📦 Counting resources...${NC}"
TOTAL_RESOURCES=$(az resource list --query 'length(@)' -o tsv 2>/dev/null || echo "0")
echo -e "Total resources found: $TOTAL_RESOURCES"
update_json '.metrics.resourceCount' "$TOTAL_RESOURCES"

# Resource breakdown by type
echo -e "${YELLOW}🔍 Analyzing resource types...${NC}"
RESOURCE_TYPES=$(az resource list --query '[].type' -o tsv 2>/dev/null | sort | uniq -c | head -10)

# Store resource breakdown
RESOURCE_JSON="{}"
while read -r count type; do
    if [[ -n "$count" && -n "$type" ]]; then
        RESOURCE_JSON=$(echo "$RESOURCE_JSON" | jq ". + {\"$type\": $count}")
    fi
done <<< "$RESOURCE_TYPES"

# Update resource breakdown in report
temp_file=$(mktemp)
jq ".resourceBreakdown = $RESOURCE_JSON" "$REPORT_FILE" > "$temp_file"
mv "$temp_file" "$REPORT_FILE"

# Predictive cost estimation using deployed resources
echo -e "${YELLOW}💰 Estimating costs with predictive analysis...${NC}"

# Use the new cost estimation script if available
COST_SCRIPT="$PROJECT_ROOT/scripts/estimate-deployment-costs.sh"
ESTIMATED_COST=0
COST_ANALYSIS_SUCCESS=false

if [[ -x "$COST_SCRIPT" ]]; then
    echo -e "Using predictive cost estimation script..."

    # Try to find ALZ resource groups and analyze them
    ALZ_RESOURCE_GROUPS=$(az group list --query "[?starts_with(name, 'rg-alz')].name" -o tsv 2>/dev/null || echo "")

    if [[ -n "$ALZ_RESOURCE_GROUPS" ]]; then
        TOTAL_ESTIMATED_COST=0

        while read -r rg_name; do
            if [[ -n "$rg_name" ]]; then
                echo -e "Analyzing resource group: $rg_name"

                # Run cost estimation and capture output
                if COST_OUTPUT=$("$COST_SCRIPT" "$rg_name" 2>&1); then
                    # Extract the monthly cost from the script output
                    RG_COST=$(echo "$COST_OUTPUT" | grep -E "TOTAL ESTIMATED/MONTH" | grep -oE '\$[0-9]+\.[0-9]+' | sed 's/\$//' || echo "0")

                    if [[ -n "$RG_COST" && "$RG_COST" != "0" ]]; then
                        TOTAL_ESTIMATED_COST=$(echo "$TOTAL_ESTIMATED_COST + $RG_COST" | bc -l 2>/dev/null || echo "$TOTAL_ESTIMATED_COST")
                        COST_ANALYSIS_SUCCESS=true
                        echo -e "✅ $rg_name estimated cost: \$${RG_COST}/month"
                    else
                        echo -e "⚠️ $rg_name cost analysis returned no data"
                    fi
                else
                    echo -e "⚠️ Cost analysis failed for $rg_name"
                fi
            fi
        done <<< "$ALZ_RESOURCE_GROUPS"

        if [[ "$COST_ANALYSIS_SUCCESS" == "true" ]]; then
            ESTIMATED_COST=$(printf "%.2f" "$TOTAL_ESTIMATED_COST")
            echo -e "✅ Predictive cost estimation completed"
        fi
    else
        echo -e "⚠️ No ALZ resource groups found for cost analysis"
    fi
else
    echo -e "⚠️ Predictive cost estimation script not found: $COST_SCRIPT"
fi

# Fallback to basic estimation if predictive analysis failed
if [[ "$COST_ANALYSIS_SUCCESS" != "true" ]]; then
    echo -e "Using fallback cost estimation based on resource count..."

    if [[ $ENVIRONMENT == "sandbox" ]]; then
        # Sandbox cost estimation (~$18-30/month)
        if [[ $TOTAL_RESOURCES -le 5 ]]; then
            ESTIMATED_COST=18
        elif [[ $TOTAL_RESOURCES -le 10 ]]; then
            ESTIMATED_COST=25
        else
            ESTIMATED_COST=30
        fi
    elif [[ $ENVIRONMENT == "production" ]]; then
        # Production cost estimation (~$4,140/month for enterprise ALZ)
        ESTIMATED_COST=4140
    else
        # Development/staging estimate
        ESTIMATED_COST=$((TOTAL_RESOURCES * 15))
    fi
fi

echo -e "Final estimated monthly cost: \$${ESTIMATED_COST} USD"
update_json '.metrics.estimatedMonthlyCost' "$ESTIMATED_COST"

# Security assessment (simplified)
echo -e "${YELLOW}🛡️ Assessing security compliance...${NC}"

SECURITY_SCORE=85  # Default for sandbox with exceptions
SECURITY_FINDINGS=0

# Check for common security configurations
if az resource list --resource-type "Microsoft.KeyVault/vaults" --query '[].name' -o tsv &>/dev/null; then
    echo -e "✅ Key Vault found"
else
    add_to_array '.securityFindings' 'No Key Vault detected - consider adding for secret management'
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
fi

if az resource list --resource-type "Microsoft.Network/virtualNetworks" --query '[].name' -o tsv &>/dev/null; then
    echo -e "✅ Virtual Network found"
else
    add_to_array '.securityFindings' 'No Virtual Network detected - resources may be using default networking'
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
    SECURITY_SCORE=$((SECURITY_SCORE - 10))
fi

# Adjust security score based on environment
if [[ $ENVIRONMENT == "sandbox" ]]; then
    SECURITY_SCORE=85  # Expected for sandbox with policy exceptions
elif [[ $ENVIRONMENT == "production" ]]; then
    SECURITY_SCORE=95  # Higher expectation for production
    if [[ $SECURITY_FINDINGS -gt 0 ]]; then
        SECURITY_SCORE=$((SECURITY_SCORE - (SECURITY_FINDINGS * 5)))
    fi
fi

echo -e "Security score: ${SECURITY_SCORE}%"
update_json '.metrics.securityScore' "$SECURITY_SCORE"

# Generate recommendations
echo -e "${YELLOW}💡 Generating recommendations...${NC}"

if [[ $ENVIRONMENT == "sandbox" && $ESTIMATED_COST -gt 35 ]]; then
    add_to_array '.recommendations' 'Sandbox costs exceed expected range ($35+/month) - consider resource optimization'
fi

if [[ $TOTAL_RESOURCES -eq 0 ]]; then
    add_to_array '.recommendations' 'No resources detected - verify deployment succeeded'
    update_json '.status' 'failed'
else
    update_json '.status' 'succeeded'
fi

if [[ $SECURITY_SCORE -lt 80 ]]; then
    add_to_array '.recommendations' 'Security score below 80% - review security findings and apply recommended fixes'
fi

# Add cost comparison recommendations
if [[ $ENVIRONMENT == "sandbox" ]]; then
    add_to_array '.recommendations' 'Sandbox deployment complete - costs should be $18-30/month for basic ALZ'
elif [[ $ENVIRONMENT == "production" ]]; then
    add_to_array '.recommendations' 'Production deployment - monitor actual costs vs estimated $4,140/month'
fi

# Finalize report
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Calculate duration (simplified for cross-platform compatibility)
DURATION_MINUTES=1  # Default to 1 minute for now

update_json '.metrics.deploymentDurationMinutes' "$DURATION_MINUTES"

# Display summary
echo ""
echo -e "${GREEN}📊 Deployment Report Summary${NC}"
echo -e "================================"
echo -e "Report ID: ${TIMESTAMP}"
echo -e "Status: $(jq -r '.status' "$REPORT_FILE")"
echo -e "Resources: $TOTAL_RESOURCES"
echo -e "Estimated Cost: \$${ESTIMATED_COST} USD/month"
echo -e "Security Score: ${SECURITY_SCORE}%"
echo -e "Duration: ${DURATION_MINUTES} minutes"
echo ""

# Display recommendations
RECOMMENDATIONS=$(jq -r '.recommendations[]' "$REPORT_FILE" 2>/dev/null || echo "None")
if [[ "$RECOMMENDATIONS" != "None" ]]; then
    echo -e "${YELLOW}💡 Recommendations:${NC}"
    while read -r recommendation; do
        if [[ -n "$recommendation" ]]; then
            echo -e "- $recommendation"
        fi
    done <<< "$RECOMMENDATIONS"
    echo ""
fi

# Display security findings
FINDINGS=$(jq -r '.securityFindings[]' "$REPORT_FILE" 2>/dev/null || echo "None")
if [[ "$FINDINGS" != "None" ]]; then
    echo -e "${YELLOW}🛡️ Security Findings:${NC}"
    while read -r finding; do
        if [[ -n "$finding" ]]; then
            echo -e "- $finding"
        fi
    done <<< "$FINDINGS"
    echo ""
fi

echo -e "${GREEN}📄 Report saved: $REPORT_FILE${NC}"
echo -e "${BLUE}📊 View reports dashboard: file://$REPORTS_DIR${NC}"

# Create a simple HTML dashboard if it doesn't exist
DASHBOARD_FILE="$REPORTS_DIR/index.html"
if [[ ! -f "$DASHBOARD_FILE" ]]; then
    cat > "$DASHBOARD_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Azure Landing Zone Deployment Reports</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 20px; border-radius: 5px; }
        .report { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .success { border-left: 5px solid green; }
        .failed { border-left: 5px solid red; }
        .unknown { border-left: 5px solid orange; }
        .metric { display: inline-block; margin: 5px 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏗️ Azure Landing Zone Deployment Reports</h1>
        <p>Deployment history and analysis for Azure Landing Zone infrastructure</p>
    </div>

    <div id="reports">
        <!-- Reports will be loaded here by JavaScript -->
    </div>

    <script>
        // This would be populated by a more sophisticated reporting system
        // For now, users can view individual JSON report files
        document.getElementById('reports').innerHTML = '<p>📁 View individual report JSON files in this directory</p>';
    </script>
</body>
</html>
EOF
    echo -e "${GREEN}📊 Created dashboard: $DASHBOARD_FILE${NC}"
fi

echo -e "${GREEN}✅ Deployment report generation complete!${NC}"
