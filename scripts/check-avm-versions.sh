#!/bin/bash
# Script to check AVM module versions in Bicep templates
set -euo pipefail

BICEP_FILE="$1"
WARNINGS=0

echo "🔍 Checking AVM module versions in: $BICEP_FILE"

# Check if file exists
if [[ ! -f "$BICEP_FILE" ]]; then
    echo "❌ File not found: $BICEP_FILE"
    exit 1
fi

# Extract AVM module references
if grep -q "br/public:avm/" "$BICEP_FILE"; then
    echo "✅ Found AVM modules in $BICEP_FILE"

    # Extract module versions and check they are not using 'latest'
    while IFS= read -r line; do
        if echo "$line" | grep -q "br/public:avm/.*:latest"; then
            echo "⚠️ Warning: Using 'latest' version tag in: $line"
            WARNINGS=$((WARNINGS + 1))
        elif echo "$line" | grep -qE "br/public:avm/.*:[0-9]+\.[0-9]+\.[0-9]+"; then
            echo "✅ Version pinned: $(echo "$line" | grep -oE "br/public:avm/[^']*")"
        fi
    done < <(grep "br/public:avm/" "$BICEP_FILE")

    if [[ $WARNINGS -gt 0 ]]; then
        echo "⚠️ Found $WARNINGS version warnings in $BICEP_FILE"
        echo "💡 Consider pinning to specific AVM module versions for production deployments"
    else
        echo "✅ All AVM modules use specific version tags"
    fi
else
    echo "ℹ️ No AVM modules found in $BICEP_FILE"
fi

exit 0
