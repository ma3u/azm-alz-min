#!/bin/bash
set -euo pipefail

# Setup script for Azure Landing Zone pre-commit hooks
# This script installs and configures all necessary tools for local development

echo "🚀 Setting up Azure Landing Zone pre-commit environment..."

# Check if we're on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    echo "📱 Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    echo "🐧 Detected Linux"
else
    echo "❌ Unsupported platform: $OSTYPE"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
set -e

# Setup script for pre-commit hooks in Azure Landing Zone repository
# This script installs and configures pre-commit hooks for Bicep and Terraform

echo "🔧 Setting up pre-commit hooks for Azure Landing Zone..."
echo "This will install tools for Bicep and Terraform validation."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on macOS or Linux
OS="$(uname)"
echo "Detected OS: $OS"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install pre-commit
install_precommit() {
    echo -e "${BLUE}📦 Installing pre-commit...${NC}"

    if command_exists brew; then
        echo "Using Homebrew to install pre-commit..."
        brew install pre-commit
    elif command_exists pip3; then
        echo "Using pip to install pre-commit..."
        pip3 install pre-commit
    elif command_exists pip; then
        echo "Using pip to install pre-commit..."
        pip install pre-commit
    else
        echo -e "${RED}❌ Could not find pip or brew. Please install pre-commit manually.${NC}"
        exit 1
    fi
}

# Function to install Azure CLI and Bicep
install_azure_cli() {
    echo -e "${BLUE}☁️ Installing Azure CLI and Bicep...${NC}"

    if command_exists az; then
        echo "Azure CLI already installed, checking Bicep..."
        az bicep install >/dev/null 2>&1 || true
        az bicep upgrade >/dev/null 2>&1 || true
    else
        if [[ "$OS" == "Darwin" ]]; then
            if command_exists brew; then
                echo "Installing Azure CLI via Homebrew..."
                brew install azure-cli
            else
                echo "Please install Homebrew first or install Azure CLI manually"
                exit 1
            fi
        else
            echo "Installing Azure CLI on Linux..."
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        fi

        echo "Installing Bicep CLI..."
        az bicep install
    fi
}

# Function to install Terraform tools
install_terraform_tools() {
    echo -e "${BLUE}🏗️ Installing Terraform tools...${NC}"

    # Install Terraform
    if ! command_exists terraform; then
        if [[ "$OS" == "Darwin" ]]; then
            if command_exists brew; then
                echo "Installing Terraform via Homebrew..."
                brew install terraform
            else
                echo -e "${YELLOW}⚠️  Homebrew not found. Please install Terraform manually.${NC}"
            fi
        else
            echo "Please install Terraform manually for Linux"
        fi
    else
        echo "Terraform already installed"
    fi

    # Install TFLint
    if ! command_exists tflint; then
        echo "Installing TFLint..."
        if [[ "$OS" == "Darwin" ]]; then
            if command_exists brew; then
                brew install tflint
            else
                curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
            fi
        else
            curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
        fi
    else
        echo "TFLint already installed"
    fi

    # Install tfsec
    if ! command_exists tfsec; then
        echo "Installing tfsec..."
        if [[ "$OS" == "Darwin" ]]; then
            if command_exists brew; then
                brew install tfsec
            else
                # Manual installation for macOS
                echo "Installing tfsec manually..."
                wget -q -O tfsec https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-darwin-amd64
                chmod +x tfsec
                sudo mv tfsec /usr/local/bin/
            fi
        else
            # Linux installation
            wget -q -O tfsec https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64
            chmod +x tfsec
            sudo mv tfsec /usr/local/bin/
        fi
    else
        echo "tfsec already installed"
    fi

    # Install Checkov
    if ! command_exists checkov; then
        echo "Installing Checkov..."
        if command_exists pip3; then
            pip3 install checkov
        elif command_exists pip; then
            pip install checkov
        else
            echo -e "${YELLOW}⚠️  pip not found. Please install Checkov manually: pip install checkov${NC}"
        fi
    else
        echo "Checkov already installed"
    fi
}

# Function to setup detect-secrets baseline
setup_detect_secrets() {
    echo -e "${BLUE}🔍 Setting up detect-secrets baseline...${NC}"

    if ! command_exists detect-secrets; then
        echo "Installing detect-secrets..."
        if command_exists pip3; then
            pip3 install detect-secrets
        elif command_exists pip; then
            pip install detect-secrets
        fi
    fi

    # Create secrets baseline if it doesn't exist
    if [[ ! -f .secrets.baseline ]]; then
        echo "Creating detect-secrets baseline..."
        detect-secrets scan --baseline .secrets.baseline
        echo -e "${GREEN}✅ Baseline created. Review .secrets.baseline file.${NC}"
    else
        echo "Secrets baseline already exists"
    fi
}

# Main installation process
echo -e "${GREEN}🚀 Starting installation...${NC}"

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

# Install pre-commit
if ! command_exists pre-commit; then
    install_precommit
else
    echo "pre-commit already installed"
fi

# Install Azure CLI and Bicep
install_azure_cli

# Install Terraform tools
install_terraform_tools

# Setup detect-secrets
setup_detect_secrets

# Install pre-commit hooks
echo -e "${BLUE}🪝 Installing pre-commit hooks...${NC}"
pre-commit install

# Run pre-commit on all files to test
echo -e "${BLUE}🧪 Testing pre-commit hooks...${NC}"
echo "Running pre-commit on all files (this may take a few minutes)..."

if pre-commit run --all-files; then
    echo -e "${GREEN}✅ All pre-commit hooks passed!${NC}"
else
    echo -e "${YELLOW}⚠️  Some hooks failed. This is normal for the first run.${NC}"
    echo -e "${YELLOW}   Fix any issues and commit again.${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}🎉 Pre-commit setup complete!${NC}"
echo ""
echo "📋 Installed tools:"
echo "  ✅ pre-commit"
echo "  ✅ Azure CLI + Bicep"
echo "  ✅ Terraform + TFLint + tfsec + Checkov"
echo "  ✅ detect-secrets"
echo ""
echo "🪝 Pre-commit hooks are now active and will run on every commit."
echo ""
echo "📖 Next steps:"
echo "  1. Review .secrets.baseline file and update as needed"
echo "  2. Make a test commit to see the hooks in action"
echo "  3. Configure any additional rules in .pre-commit-config.yaml"
echo ""
echo "🆘 If you need to skip hooks for a commit:"
echo "   git commit --no-verify -m 'your message'"
echo ""
echo -e "${BLUE}📚 Documentation: https://pre-commit.com/${NC}"
