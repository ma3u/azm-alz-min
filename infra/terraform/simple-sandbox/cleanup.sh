#!/bin/bash

# Terraform Cleanup Script
# This script will run in the background and clean up resources after 10 minutes

echo "$(date): Terraform cleanup script started. Will destroy resources in 10 minutes..."

# Wait for 10 minutes (600 seconds)
sleep 600

echo "$(date): Starting Terraform cleanup..."

# Navigate to the correct directory
cd "$(dirname "$0")"

# Check if terraform files exist
if [[ -f "main.tf" && -f "terraform.tfvars" ]]; then
    echo "$(date): Destroying Terraform resources..."

    # Destroy all resources
    terraform1.9 destroy -var-file="terraform.tfvars" -auto-approve

    if [ $? -eq 0 ]; then
        echo "$(date): ✅ Terraform resources destroyed successfully"

        # Clean up Terraform state files
        rm -rf .terraform .terraform.lock.hcl terraform.tfstate* tfplan
        echo "$(date): ✅ Terraform state files cleaned up"
    else
        echo "$(date): ❌ Failed to destroy Terraform resources"
    fi
else
    echo "$(date): ❌ Terraform configuration files not found"
fi

echo "$(date): Terraform cleanup script completed"
