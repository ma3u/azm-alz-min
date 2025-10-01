# Deployment Success Summary

This document captures the current state of the Azure Landing Zone sandbox deployment and related CI/CD readiness.

## Overview

- Subscription: PER-SBX-MBUCHHORN (fdf79377-e045-462f-ac4a-630ddee7e4c3)
- Environment: sandbox
- Region: westeurope
- Deployment Type: Foundation (blueprints/bicep/foundation/main.bicep)
- Last Verified: 2025-10-01T15:52:56Z

## Deployed Resources

- Resource Group: rg-alz-sandbox-sandbox (Succeeded)
- Key Vault: kv-alz-sb-hqilxdzf (RBAC enabled, soft delete + purge protection)
- Virtual Network: vnet-alz-sandbox-sandbox (10.0.0.0/16)
  - subnet-keyvault (10.0.1.0/24, service endpoint: Microsoft.KeyVault)
  - subnet-private-endpoints (10.0.2.0/24)
  - subnet-workloads (10.0.10.0/24)
- Log Analytics: log-alz-sandbox-sandbox-hqilxdzf (PerGB2018, 30 days)

## AVM Module Versions (Updated)

- avm/res/network/virtual-network: 0.7.1
- avm/res/key-vault/vault: 0.13.3
- avm/res/operational-insights/workspace: 0.12.0
- avm/res/key-vault/vault/secret: 0.1.0 (latest)

## CI/CD Status

- Pre-commit hooks: Passing locally
- Security & Compliance Scanning: Last run succeeded
- Azure Landing Zone CI/CD Pipeline: Matrix output bug fixed (compact JSON)

## Known Gaps / Next Actions

- Hub-Spoke template requires refactor for latest AVM modules (peering, App Service Plan, Web App, Public IP APIs changed)
- Consider copying a template from blueprints to infra/ to trigger an automated deployment via CI/CD

## Validation Commands

- List resource groups: az group list --query "[?contains(name, 'alz')].{Name:name, Location:location}" -o table
- List resources: az resource list -g rg-alz-sandbox-sandbox -o table
- Inspect VNet: az network vnet show -g rg-alz-sandbox-sandbox -n vnet-alz-sandbox-sandbox -o json

## Cost Note

- Foundation setup estimated cost: ~$25-35/month (Key Vault + VNet + Log Analytics)
