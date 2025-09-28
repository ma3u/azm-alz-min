# Pre-commit Errors Analysis - Current Status

**Last Updated:** 2025-09-28  
**Status:** ✅ **Good State** - Most critical issues resolved, minor formatting issues remain

## 🎯 Purpose

This document tracks **current pre-commit hook status** and provides **quick troubleshooting** for Azure Landing Zone projects when hooks fail.

**Target Audience:** Developers experiencing pre-commit hook failures.

**When to Use:** Pre-commit hooks are failing and you need immediate solutions.

## 📋 Table of Contents

- [📊 Current Status](#-current-status)
- [🚨 Active Issues](#-active-issues)
- [🚀 Priority Fixes](#-priority-fixes)
- [📚 Official Documentation](#-official-documentation)
- [📚 Related Documents](#-related-documents)

---

## 📊 Current Status

**Recent Run Results (2025-09-28):**

| Hook                     | Status    | Issue                         | Priority  |
| ------------------------ | --------- | ----------------------------- | --------- |
| Trim Trailing Whitespace | ✅ Passed | None                          | -         |
| Fix End of Files         | ❌ Failed | Missing newlines at EOF       | 🟢 Low    |
| Check YAML               | ✅ Passed | None                          | -         |
| Check JSON               | ✅ Passed | None                          | -         |
| Bicep Lint               | ✅ Passed | None                          | -         |
| Bicep Format             | ✅ Passed | None                          | -         |
| Terraform Validate       | ✅ Passed | None                          | -         |
| Terraform tflint         | ❌ Failed | Module structure warnings     | 🟡 Medium |
| Checkov                  | ✅ Passed | Sandbox exceptions configured | -         |
| Prettier                 | ❌ Failed | Code formatting               | 🟢 Low    |
| Detect Secrets           | ✅ Passed | None                          | -         |

## 🚨 Active Issues

### 🟡 Medium Priority

| Issue                 | Description                           | Impact                           |
| --------------------- | ------------------------------------- | -------------------------------- |
| **Terraform tflint**  | Module structure warnings (11 issues) | Code organization best practices |
| **End-of-file-fixer** | Missing newlines at end of files      | Auto-fixed by hook               |
| **Prettier**          | Code formatting inconsistencies       | Auto-fixed by hook               |

### 🟢 Low Priority

All remaining issues are formatting-related and automatically fixed by running the hooks.

## 🚀 Priority Fixes

### 1. 🟡 Terraform Module Structure (Medium)

**Issue:** Variables and outputs should be in separate files per Terraform standards.

```bash
# Current structure in sandbox/:
# - Variables defined in terraform-sandbox.tf (should be in variables.tf)
# - Outputs defined in terraform-sandbox.tf (should be in outputs.tf)

# Fix: Move variables and outputs to proper files
# This is a code organization improvement, not a functional issue
```

### 2. 🟢 Auto-fix Formatting (Low)

```bash
# Fix all formatting issues automatically
pre-commit run --all-files

# Or fix specific issues:
pre-commit run end-of-file-fixer --all-files
pre-commit run prettier --all-files
```

### 3. ✅ Verify Current Status

```bash
# Check current hook status
pre-commit run --all-files

# Most hooks should now pass
# Remaining failures are minor formatting issues that auto-fix
```

**Note:** For detailed Checkov security policies and sandbox exceptions, see [Azure Sandbox Policies Overview](./azure-sandbox-policies-overview.md).

## 📚 Official Documentation

- **Primary:** [Pre-commit Framework](https://pre-commit.com/) - Hook configuration and troubleshooting
- **Azure Bicep:** [Bicep Linting Rules](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter) - BCP error codes
- **Terraform:** [Terraform Validation](https://www.terraform.io/docs/cli/commands/validate.html) - Syntax and configuration validation
- **TFLint:** [TFLint Rules](https://github.com/terraform-linters/tflint) - Terraform best practices

## 📚 Related Documents

- [Pre-commit Hooks Guide](./pre-commit-hooks-guide.md) - Complete setup and configuration
- [Azure Sandbox Policies Overview](./azure-sandbox-policies-overview.md) - **Detailed** Checkov rules and sandbox exceptions
- [AVM Deployment Guide](./avm-deployment-guide.md) - Azure Verified Modules usage
- [README.md](../README.md) - Main project overview and quick start

---

**Status:** ✅ **Good State** | **Most critical issues resolved, minor formatting remains**
