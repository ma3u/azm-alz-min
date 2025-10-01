#!/bin/bash
# Script to check Terraform version requirements
set -euo pipefail

FILE="$1"
WARNINGS=0

echo "🔧 Checking Terraform version requirements in: $FILE"

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

# Check for terraform version block
if grep -q "required_version" "$FILE"; then
    echo "✅ Found Terraform version requirements"

    # Extract version requirement
    version_req=$(grep -A 2 "required_version" "$FILE" | head -3)
    echo "Version requirement: $version_req"

    # Check for overly restrictive version pinning
    if echo "$version_req" | grep -q "= "; then
        echo "⚠️ Warning: Exact version pinning detected"
        echo "💡 Consider using ~> for patch-level flexibility"
        WARNINGS=$((WARNINGS + 1))
    elif echo "$version_req" | grep -q "~>"; then
        echo "✅ Uses flexible version constraint (~>)"
    fi
else
    echo "⚠️ Warning: No Terraform version requirement found"
    echo "💡 Consider adding terraform.required_version to ensure compatibility"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for required provider versions
if grep -q "required_providers" "$FILE"; then
    echo "✅ Found required provider versions"

    # Check for azurerm provider version
    if grep -q "azurerm" "$FILE"; then
        provider_version=$(grep -A 5 "azurerm" "$FILE" | grep "version" | head -1 || echo "No version found")
        echo "AzureRM provider: $provider_version"
    fi
else
    echo "⚠️ Warning: No required provider versions found"
    echo "💡 Consider specifying provider version requirements"
    WARNINGS=$((WARNINGS + 1))
fi

# Check current Terraform version compatibility
current_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "Not available")
if [[ "$current_version" != "Not available" ]]; then
    echo "ℹ️ Current Terraform version: $current_version"
else
    echo "ℹ️ Could not determine current Terraform version"
fi

if [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️ Found $WARNINGS version requirement warnings"
else
    echo "✅ Terraform version requirements look good"
fi

exit 0
