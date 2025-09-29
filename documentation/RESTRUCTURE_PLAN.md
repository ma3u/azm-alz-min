# Azure Landing Zone - Repository Restructuring Plan

**Generated**: 2025-09-29T05:36:38Z
**Status**: Ready for Implementation

## 🎯 Objectives

- Create clear, logical folder hierarchy with descriptive names
- Separate working templates from deprecated/broken content
- Improve maintainability and user experience
- Preserve git history during restructuring

## 📊 Current vs. Proposed Structure

### Current Issues

- Confusing naming (`infra/accelerator`, mixed `sandbox/`)
- 4 different `main.bicep` files with redundant functionality
- Deprecated templates mixed with working ones (464MB of content)
- No clear environment separation

### Proposed Structure

```
azure-landingzone/
├── 📁 blueprints/           # Ready-to-deploy templates (PRODUCTION READY)
├── 📁 environments/         # Environment-specific configurations
├── 📁 modules/             # Reusable components
├── 📁 examples/            # Learning/testing materials
├── 📁 archived/            # Deprecated but preserved content
├── 📁 automation/          # CI/CD, scripts, workflows
└── 📁 documentation/       # Organized docs
```

## 🔄 Migration Mapping

### Working Templates → blueprints/

| Source                                   | Destination                                  | Status     |
| ---------------------------------------- | -------------------------------------------- | ---------- |
| `sandbox/main.bicep`                     | `blueprints/bicep/foundation/main.bicep`     | ✅ Working |
| `infra/accelerator/simple-sandbox.bicep` | `blueprints/bicep/hub-spoke/main.bicep`      | ✅ Working |
| `infra/terraform/simple-sandbox/`        | `blueprints/terraform/foundation/`           | ✅ Working |
| `infra/bicep/sandbox/main.bicep`         | `blueprints/bicep/foundation/advanced.bicep` | ✅ Working |

### Environment Configs → environments/

| Source                         | Destination                                           |
| ------------------------------ | ----------------------------------------------------- |
| `production/`                  | `environments/production/`                            |
| `sandbox/main.parameters.json` | `environments/development/foundation.parameters.json` |

### Deprecated Content → archived/

| Source                                     | Destination                  | Issues          |
| ------------------------------------------ | ---------------------------- | --------------- |
| `infra/accelerator/alz-avm-patterns.bicep` | `archived/broken-templates/` | 45+ errors      |
| `infra/accelerator/alz-hubspoke.bicep`     | `archived/broken-templates/` | 38+ errors      |
| `infra/hub-spoke/*.bicep`                  | `archived/broken-templates/` | 15+ errors each |
| `infra/bicep/main.bicep`                   | `archived/legacy-patterns/`  | Mixed scoping   |

### Testing Materials → examples/

| Source                       | Destination             |
| ---------------------------- | ----------------------- |
| `sandbox/simple-test.bicep`  | `examples/basic-tests/` |
| `sandbox/storage-test.bicep` | `examples/basic-tests/` |

## 🚀 Implementation Steps

### Phase 1: Create New Structure

```bash
# Create new directory structure
mkdir -p blueprints/{bicep/{foundation,hub-spoke,enterprise},terraform/{foundation}}
mkdir -p environments/{development,testing,production}
mkdir -p modules/{bicep,terraform}
mkdir -p examples/{basic-tests,proof-of-concepts}
mkdir -p archived/{broken-templates,legacy-patterns}
mkdir -p automation/{pipelines,scripts,workflows}
mkdir -p documentation/{deployment-guides,architecture,troubleshooting}
```

### Phase 2: Move Working Templates (Preserve Git History)

```bash
# Move working Bicep templates
git mv sandbox/main.bicep blueprints/bicep/foundation/main.bicep
git mv sandbox/main.parameters.json blueprints/bicep/foundation/main.parameters.json
git mv infra/accelerator/simple-sandbox.bicep blueprints/bicep/hub-spoke/main.bicep
git mv infra/accelerator/simple-sandbox.parameters.json blueprints/bicep/hub-spoke/main.parameters.json
git mv infra/bicep/sandbox/main.bicep blueprints/bicep/foundation/advanced.bicep

# Move working Terraform templates
git mv infra/terraform/simple-sandbox blueprints/terraform/foundation

# Move production configurations
git mv production environments/

# Move test files
git mv sandbox/simple-test.bicep examples/basic-tests/
git mv sandbox/storage-test.bicep examples/basic-tests/
git mv sandbox/TESTING.md examples/basic-tests/README.md
```

### Phase 3: Archive Deprecated Content

```bash
# Archive broken templates
git mv infra/accelerator/alz-avm-patterns.bicep archived/broken-templates/
git mv infra/accelerator/alz-hubspoke.bicep archived/broken-templates/
git mv infra/hub-spoke archived/broken-templates/hub-spoke-legacy
git mv infra/bicep/main.bicep archived/legacy-patterns/

# Clean up remaining empty directories
find infra/ -type d -empty -delete
```

### Phase 4: Reorganize Supporting Content

```bash
# Move automation content
git mv .github/workflows automation/workflows
git mv pipelines automation/
git mv scripts automation/

# Move documentation
git mv docs documentation/content

# Update remaining Terraform files
git mv infra/terraform/main.tf archived/legacy-patterns/terraform-main.tf
git mv infra/terraform/outputs.tf archived/legacy-patterns/terraform-outputs.tf
git mv infra/terraform/variables.tf archived/legacy-patterns/terraform-variables.tf
git mv infra/terraform/terraform.tfvars.example archived/legacy-patterns/
```

## 📝 File Updates Required

### 1. Update WARP.md References

- Update template paths in recommendations
- Update working template references
- Update validation script paths

### 2. Update Pre-commit Configuration

- Update exclusion paths for archived content
- Update hook paths for automation scripts

### 3. Update CI/CD Pipeline Paths

- Update GitHub Actions workflow paths
- Update Azure DevOps pipeline references
- Update script execution paths

### 4. Update Documentation

- Update all documentation links
- Update deployment guides with new paths
- Create new README files for each section

## 🧹 Cleanup Operations

### Files to Delete (No Git History Value)

```bash
# Remove empty Terraform state files and temp files
rm -f sandbox/main.tf sandbox/outputs.tf sandbox/variables.tf
rm -f infra/bicep/main.parameters.prod.json  # Duplicates production config
rm -rf node_modules/  # Node.js dependencies not needed
```

### Consolidation Opportunities

- Merge duplicate parameter files
- Consolidate similar test files
- Remove redundant documentation

## ✅ Success Criteria

1. **Clear Structure**: Each folder has a single, clear purpose
2. **Working Templates**: All templates in `blueprints/` compile and validate
3. **Preserved History**: Git history maintained for all important files
4. **Updated References**: All scripts, docs, and pipelines work with new paths
5. **Size Reduction**: Significant reduction in repository size (target: <200MB)
6. **Pre-commit Clean**: All validation passes on restructured repository

## 🔍 Validation Steps

1. Run comprehensive validation script
2. Test all working templates deploy successfully
3. Verify pre-commit hooks work with new structure
4. Confirm CI/CD pipelines execute properly
5. Check documentation links are not broken

---

**Next Steps**: Execute implementation phases in order, testing after each phase.
