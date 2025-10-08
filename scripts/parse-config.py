#!/usr/bin/env python3
"""
Azure Landing Zone Configuration Parser
Generates Bicep and Terraform configuration files from YAML configuration
"""

import yaml
import json
import argparse
import os
from pathlib import Path
from typing import Dict, Any, Optional

class ALZConfigParser:
    def __init__(self, config_path: str):
        """Initialize with configuration file path."""
        self.config_path = Path(config_path)
        self.config = self.load_config()
        self.environment = self.config.get('global', {}).get('environment', 'sandbox')

    def load_config(self) -> Dict[str, Any]:
        """Load and validate YAML configuration."""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")

        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)

        # Apply environment-specific overrides
        env = config.get('global', {}).get('environment', 'sandbox')
        if 'environments' in config and env in config['environments']:
            env_overrides = config['environments'][env]
            config = self.merge_config(config, env_overrides)

        return config

    def merge_config(self, base: Dict, overrides: Dict) -> Dict:
        """Recursively merge configuration dictionaries."""
        result = base.copy()

        for key, value in overrides.items():
            if key == 'inherits':
                # Handle inheritance
                if value in base.get('environments', {}):
                    result = self.merge_config(result, base['environments'][value])
                continue

            if isinstance(value, dict) and key in result and isinstance(result[key], dict):
                result[key] = self.merge_config(result[key], value)
            else:
                result[key] = value

        return result

    def generate_bicep_parameters(self) -> Dict[str, Any]:
        """Generate Bicep parameters JSON from configuration."""
        params = {
            "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentParameters.json#",
            "contentVersion": "1.0.0.0",
            "parameters": {}
        }

        # Global parameters
        global_config = self.config.get('global', {})
        if 'location' in global_config:
            params['parameters']['location'] = {"value": global_config['location']}
        if 'environment' in global_config:
            params['parameters']['environment'] = {"value": global_config['environment']}
        if 'organizationPrefix' in global_config:
            params['parameters']['organizationPrefix'] = {"value": global_config['organizationPrefix']}

        # Networking parameters
        networking = self.config.get('networking', {})
        if 'hubVnet' in networking:
            params['parameters']['hubVnetAddressSpace'] = {
                "value": networking['hubVnet'].get('addressSpace', '10.0.0.0/16')
            }
        if 'spokeVnet' in networking:
            params['parameters']['spokeVnetAddressSpace'] = {
                "value": networking['spokeVnet'].get('addressSpace', '10.1.0.0/16')
            }

        # Security parameters
        security = self.config.get('security', {})
        if 'azureBastion' in security:
            params['parameters']['enableBastion'] = {
                "value": security['azureBastion'].get('enabled', False)
            }

        # Application parameters
        applications = self.config.get('applications', {})
        if 'webApps' in applications:
            params['parameters']['enableAppWorkloads'] = {
                "value": applications['webApps'].get('enabled', True)
            }

        # Container parameters
        containers = self.config.get('containers', {})
        if 'containerRegistry' in containers:
            acr_config = containers['containerRegistry']
            params['parameters']['enableContainerRegistry'] = {
                "value": acr_config.get('enabled', True)
            }
            params['parameters']['containerRegistrySku'] = {
                "value": acr_config.get('sku', 'Standard')
            }

        # Virtual machine parameters
        params['parameters']['enableVirtualMachine'] = {"value": False}

        return params

    def generate_terraform_variables(self) -> str:
        """Generate Terraform tfvars from configuration."""
        lines = []
        lines.append("# Generated from alz-components.yaml configuration")
        lines.append(f"# Environment: {self.environment}")
        lines.append("")

        # Global variables
        global_config = self.config.get('global', {})
        if 'environment' in global_config:
            lines.append(f'environment = "{global_config["environment"]}"')
        if 'organizationPrefix' in global_config:
            lines.append(f'organization_prefix = "{global_config["organizationPrefix"]}"')
        if 'location' in global_config:
            lines.append(f'location = "{global_config["location"]}"')

        lines.append("")

        # Networking variables
        networking = self.config.get('networking', {})
        if 'hubVnet' in networking:
            lines.append(f'hub_vnet_address_space = "{networking["hubVnet"].get("addressSpace", "10.0.0.0/16")}"')
        if 'spokeVnet' in networking:
            lines.append(f'spoke_vnet_address_space = "{networking["spokeVnet"].get("addressSpace", "10.1.0.0/16")}"')

        lines.append("")

        # Component enablement
        containers = self.config.get('containers', {})
        if 'containerRegistry' in containers:
            lines.append(f'enable_container_registry = {str(containers["containerRegistry"].get("enabled", True)).lower()}')

        applications = self.config.get('applications', {})
        if 'webApps' in applications:
            lines.append(f'enable_app_workloads = {str(applications["webApps"].get("enabled", True)).lower()}')

        security = self.config.get('security', {})
        if 'azureBastion' in security:
            lines.append(f'enable_bastion = {str(security["azureBastion"].get("enabled", False)).lower()}')

        # AKS Configuration
        aks_config = self.config.get('containers', {}).get('aks', {})
        if aks_config:
            lines.append("")
            lines.append("# AKS Configuration")
            lines.append(f'enable_aks = {str(aks_config.get("enabled", False)).lower()}')

            if aks_config.get('enabled', False):
                lines.append(f'aks_kubernetes_version = "{aks_config.get("version", "1.30")}"')

                # System node pool
                system_pool = aks_config.get('systemNodePool', {})
                lines.append(f'aks_system_node_count = {system_pool.get("nodeCount", 2)}')
                lines.append(f'aks_system_node_size = "{system_pool.get("vmSize", "Standard_d4s_v5")}"')

                # User node pool
                user_pool = aks_config.get('userNodePool', {})
                lines.append(f'enable_aks_user_node_pool = {str(user_pool.get("enabled", True)).lower()}')
                lines.append(f'aks_user_node_count = {user_pool.get("nodeCount", 2)}')
                lines.append(f'aks_user_node_size = "{user_pool.get("vmSize", "Standard_d4s_v5")}"')
                lines.append('aks_admin_group_object_ids = []')

        return '\n'.join(lines) + '\n'

    def generate_component_status_report(self) -> str:
        """Generate a status report of all components."""
        lines = []
        lines.append("# Azure Landing Zone Component Status Report")
        lines.append(f"Environment: {self.environment}")
        lines.append(f"Organization: {self.config.get('global', {}).get('organizationPrefix', 'N/A')}")
        lines.append("")

        # Networking
        lines.append("## Networking Components")
        networking = self.config.get('networking', {})
        lines.append(f"- Hub VNet: {'✅ Enabled' if networking.get('hubVnet', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Spoke VNet: {'✅ Enabled' if networking.get('spokeVnet', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- VNet Peering: {'✅ Enabled' if networking.get('peering', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        # Security
        lines.append("## Security Components")
        security = self.config.get('security', {})
        lines.append(f"- Azure Firewall: {'✅ Enabled' if security.get('azureFirewall', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Azure Bastion: {'✅ Enabled' if security.get('azureBastion', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Private DNS Resolver: {'✅ Enabled' if security.get('privateDnsResolver', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Entra Private Access: {'✅ Enabled' if security.get('entraPrivateAccess', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        # Applications
        lines.append("## Application Services")
        applications = self.config.get('applications', {})
        lines.append(f"- Web Apps: {'✅ Enabled' if applications.get('webApps', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Container Apps: {'✅ Enabled' if applications.get('containerApps', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Azure Functions: {'✅ Enabled' if applications.get('functions', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        # Containers
        lines.append("## Container Services")
        containers = self.config.get('containers', {})
        lines.append(f"- Container Registry: {'✅ Enabled' if containers.get('containerRegistry', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- AKS: {'✅ Enabled' if containers.get('aks', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        # Data Services
        lines.append("## Data Services")
        data = self.config.get('data', {})
        lines.append(f"- PostgreSQL: {'✅ Enabled' if data.get('postgresql', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Storage Account: {'✅ Enabled' if data.get('storageAccount', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        # Identity & Access
        lines.append("## Identity & Access Management")
        identity = self.config.get('identity', {})
        lines.append(f"- Key Vault: {'✅ Enabled' if identity.get('keyVault', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Managed Identity: {'✅ System Assigned' if identity.get('managedIdentity', {}).get('systemAssigned') else '❌ Disabled'}")
        lines.append("")

        # Monitoring
        lines.append("## Monitoring & Observability")
        monitoring = self.config.get('monitoring', {})
        lines.append(f"- Log Analytics: {'✅ Enabled' if monitoring.get('logAnalytics', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Application Insights: {'✅ Enabled' if monitoring.get('applicationInsights', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Microsoft Sentinel: {'✅ Enabled' if monitoring.get('sentinelSiem', {}).get('enabled') else '❌ Disabled'}")
        lines.append(f"- Microsoft Defender: {'✅ Enabled' if monitoring.get('defender', {}).get('enabled') else '❌ Disabled'}")
        lines.append("")

        return '\n'.join(lines)

    def save_bicep_parameters(self, output_path: str):
        """Save Bicep parameters to JSON file."""
        params = self.generate_bicep_parameters()
        with open(output_path, 'w') as f:
            json.dump(params, f, indent=2)

    def save_terraform_variables(self, output_path: str):
        """Save Terraform variables to tfvars file."""
        tfvars = self.generate_terraform_variables()
        with open(output_path, 'w') as f:
            f.write(tfvars)

    def save_status_report(self, output_path: str):
        """Save component status report to markdown file."""
        report = self.generate_component_status_report()
        with open(output_path, 'w') as f:
            f.write(report)

def main():
    parser = argparse.ArgumentParser(description='Parse ALZ configuration and generate deployment files')
    parser.add_argument('config', help='Path to YAML configuration file')
    parser.add_argument('--bicep-output', help='Output path for Bicep parameters JSON')
    parser.add_argument('--terraform-output', help='Output path for Terraform tfvars')
    parser.add_argument('--status-report', help='Output path for status report markdown')
    parser.add_argument('--all', action='store_true', help='Generate all output files with default names')

    args = parser.parse_args()

    try:
        config_parser = ALZConfigParser(args.config)

        if args.all or args.bicep_output:
            bicep_path = args.bicep_output or 'main.parameters.generated.json'
            config_parser.save_bicep_parameters(bicep_path)
            print(f"✅ Generated Bicep parameters: {bicep_path}")

        if args.all or args.terraform_output:
            terraform_path = args.terraform_output or 'terraform.generated.tfvars'
            config_parser.save_terraform_variables(terraform_path)
            print(f"✅ Generated Terraform variables: {terraform_path}")

        if args.all or args.status_report:
            report_path = args.status_report or 'component-status.md'
            config_parser.save_status_report(report_path)
            print(f"✅ Generated status report: {report_path}")

    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

    return 0

if __name__ == '__main__':
    exit(main())
