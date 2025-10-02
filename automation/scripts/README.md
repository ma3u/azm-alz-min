# Deployment Validation Scripts

This directory contains scripts to help validate and test Azure Landing Zone templates.

## validate-deployment.sh

**Purpose:** Comprehensive validation of templates, AVM modules, and pre-commit hooks.

### Usage

```bash
# Run from project root
./scripts/validate-deployment.sh
```

### What it validates

1. **Prerequisites Check**

   - Azure CLI (`az`)
   - jq (JSON processor)
   - Terraform (`terraform1.9` or `terraform`)
   - Pre-commit hooks (`pre-commit`)

2. **Template Validation**

   - Bicep template compilation (`az bicep build`)
   - Terraform template validation (`terraform validate`)

3. **AVM Module Versions**

   - Checks latest versions of common AVM modules
   - Validates against Microsoft Container Registry

4. **Pre-commit Hooks**

   - Runs essential hooks: YAML, JSON, Bicep lint, Terraform validate
   - Reports current hook status

5. **Template Consistency**

   - Verifies working templates exist
   - Confirms template file structure

6. **Security Configuration**
   - Checks for `.checkov.yaml` configuration
   - Validates `.secrets.baseline` exists

### Output

The script provides:

- **Color-coded output** (Pass/Fail/Warning)
- **Detailed progress** for each validation step
- **Summary report** with total checks, passed, and failed
- **Exit codes**: 0 for success, 1 for failures

### Example Output

```
==================================================
🚀 Azure Landing Zone Deployment Validation
Date: 2025-09-28 15:30:45
==================================================
[INFO] Checking prerequisites...
[PASS] Azure CLI found
[PASS] jq found
[PASS] Terraform found
[PASS] pre-commit found
==================================================
[INFO] Validating Bicep templates...
[INFO] Running: Bicep compilation: infra/bicep/sandbox/main.bicep
[PASS] Bicep compilation: infra/bicep/sandbox/main.bicep
...
📊 Validation Summary
Total Checks: 25
Passed: 23
Failed: 2
❌ Some validations failed
⚠️  Review failed checks before deployment
```

### When to Use

- **Before template modifications** - Establish current state
- **After making changes** - Verify nothing is broken
- **Before deployment** - Final validation
- **During troubleshooting** - Identify current issues
- **In CI/CD pipelines** - Automated validation

### Prerequisites

Install required tools:

```bash
# macOS with Homebrew
brew install azure-cli jq terraform pre-commit

# Install pre-commit hooks
pre-commit install
```

### Troubleshooting

**Script fails with "command not found":**

- Install missing prerequisites listed above
- Ensure tools are in your PATH

**Template validation fails:**

- Check template syntax
- Verify AVM module versions are current
- Review [Pre-commit Errors Analysis](../docs/pre-commit-errors-analysis.md)

**Pre-commit hooks fail:**

- Run `pre-commit run --all-files` to see detailed errors
- Check [Pre-commit Hooks Guide](../docs/pre-commit-hooks-guide.md)

### Integration with WARP.md

This script is **mandatory** per WARP.md guidelines and should be run:

- Before any template modifications
- After template changes
- During troubleshooting
- Before deployment

See [WARP.md](../WARP.md) for complete AI assistant guidelines.
