# Archived Content

This directory contains deprecated, broken, or legacy templates that are preserved for reference but should not be used for new deployments.

## 🗂️ Structure

```
archived/
├── broken-templates/     # Templates with compilation errors
└── legacy-patterns/      # Outdated approaches
```

## 🚨 Important Notice

**⚠️ DO NOT USE THESE TEMPLATES FOR PRODUCTION**

All content in this directory has been moved here because:
- ❌ Contains compilation errors (15-45+ errors per template)
- ❌ Uses deprecated patterns or non-existent modules
- ❌ Requires permissions not available in typical sandbox environments
- ❌ Has been superseded by better approaches in `blueprints/`

## 📂 Contents

### Broken Templates (`broken-templates/`)

These templates have significant issues that prevent deployment:

- `alz-avm-patterns.bicep` - 45+ errors, uses non-existent pattern modules
- `alz-hubspoke.bicep` - 38+ errors, API incompatibilities  
- `alz-subscription-vending-*.bicep` - Complex subscription vending issues
- `hub-spoke-legacy/` - Old hub-spoke implementations with parameter mismatches

### Legacy Patterns (`legacy-patterns/`)

These represent older approaches that have been replaced:

- `main.bicep` - Mixed scoping issues, replaced by foundation templates
- `terraform-*.tf` - Old Terraform patterns, replaced by foundation module

## 🔄 Migration Guide

If you were using these templates, migrate to:

| Old Template | New Template |
|-------------|-------------|
| Any broken template | `blueprints/bicep/foundation/main.bicep` |
| `alz-hubspoke.bicep` | `blueprints/bicep/hub-spoke/main.bicep` |
| Legacy Terraform | `blueprints/terraform/foundation/` |

## 📚 Learning Value

This content is preserved for:
- Understanding what doesn't work and why
- Learning from common AVM module mistakes
- Reference for troubleshooting similar issues
- Historical context of the repository evolution

## 🔍 Analysis

For detailed analysis of why these templates were deprecated, see:
- [documentation/content/experimental-avm-modules-deprecation.md](../documentation/content/experimental-avm-modules-deprecation.md)
- [RESTRUCTURE_PLAN.md](../RESTRUCTURE_PLAN.md)