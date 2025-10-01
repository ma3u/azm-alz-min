#!/bin/bash
# Script to validate Azure naming conventions
set -euo pipefail

FILE="$1"
WARNINGS=0

echo "🏷️ Validating naming conventions in: $FILE"

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

# Define naming patterns based on Azure CAF recommendations
check_naming_patterns() {
    local file="$1"

    # Resource group naming: rg-{workload}-{environment}
    if grep -q "name.*rg-" "$file"; then
        echo "✅ Resource group naming pattern found"
    fi

    # Storage account naming: st{workload}{env}{unique} (lowercase, no hyphens)
    if grep -qE "name.*st[a-z0-9]{3,24}" "$file"; then
        echo "✅ Storage account naming pattern found"
    fi

    # Key vault naming: kv-{workload}-{env}-{unique} (≤24 chars)
    if grep -q "name.*kv-" "$file"; then
        echo "✅ Key vault naming pattern found"
    fi

    # Check for hardcoded names (potential issue)
    if grep -qE "(name\s*=\s*['\"][a-zA-Z0-9-]+['\"])" "$file"; then
        local hardcoded_names
        hardcoded_names=$(grep -oE "(name\s*=\s*['\"][a-zA-Z0-9-]+['\"])" "$file" | head -3)
        echo "⚠️ Warning: Found potentially hardcoded resource names:"
        echo "$hardcoded_names"
        echo "💡 Consider using variables or uniqueString() for resource names"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Check for naming convention violations
if [[ "$FILE" == *.bicep ]]; then
    echo "🔍 Checking Bicep naming conventions..."
    check_naming_patterns "$FILE"

    # Check for uniqueString usage (good practice)
    if grep -q "uniqueString" "$FILE"; then
        echo "✅ Uses uniqueString() for unique naming"
    fi

elif [[ "$FILE" == *.tf ]]; then
    echo "🔍 Checking Terraform naming conventions..."
    check_naming_patterns "$FILE"

    # Check for random_string usage (good practice)
    if grep -q "random_string" "$FILE"; then
        echo "✅ Uses random_string for unique naming"
    fi
fi

if [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️ Found $WARNINGS naming convention warnings in $FILE"
else
    echo "✅ Naming conventions look good"
fi

exit 0
