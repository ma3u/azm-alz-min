# Essential GitHub Actions Workflows Guide

## 🎯 **Core Workflows for Sandbox Deployment**

### 1. **Bicep Deployment** 🔧

**File**: `.github/workflows/bicep-alz-sandbox.yml`

- **Purpose**: Deploy Azure Landing Zone using Bicep templates
- **Triggers**: Push to main (Bicep changes), manual dispatch
- **Use Case**: Hub-spoke and foundation architectures
- **Status**: ✅ **Working with Automated Reports**

### 2. **Terraform Deployment** 🚀

**File**: `.github/workflows/terraform-alz-deployment.yml`

- **Purpose**: Deploy Azure Landing Zone using Terraform
- **Triggers**: Push to main (Terraform changes), manual dispatch
- **Use Case**: Foundation architecture
- **Status**: ✅ **Working with Automated Reports**

### 3. **Full Terraform Deployment (Clean + Deploy)** 🔄

**File**: `.github/workflows/terraform-alz-full-deployment.yml`

- **Purpose**: Clean up existing resources and deploy fresh
- **Triggers**: Manual dispatch only
- **Use Case**: Complete refresh deployment
- **Status**: ✅ **Working** - Triggers main Terraform workflow

### 4. **Terraform Cleanup** 🗑️

**File**: `.github/workflows/terraform-alz-cleanup.yml`

- **Purpose**: Clean up ALZ resources (Bicep and Terraform)
- **Triggers**: Manual dispatch only
- **Requires**: Confirmation string "DELETE"
- **Status**: ✅ **Working** - Supports both tf and bi prefixes

### 5. **Infrastructure Validation** ✅

**File**: `.github/workflows/infrastructure-validation.yml`

- **Purpose**: Validate Bicep and Terraform templates
- **Triggers**: Pull requests, push to main
- **Use Case**: Pre-deployment validation
- **Status**: ✅ **Working**

### 6. **Security & Compliance** 🛡️

**File**: `.github/workflows/security-compliance.yml`

- **Purpose**: Security scanning and compliance checks
- **Triggers**: Push, pull requests
- **Use Case**: Security validation
- **Status**: ✅ **Working**

### 7. **Pre-commit Hooks** 🔍

**File**: `.github/workflows/pre-commit.yml`

- **Purpose**: Code quality and formatting checks
- **Triggers**: Push, pull requests
- **Use Case**: Code quality assurance
- **Status**: ✅ **Working**

### 8. **Cost Estimation (Infracost)** 💰

**File**: `.github/workflows/infracost.yml`

- **Purpose**: Infrastructure cost analysis
- **Triggers**: Pull requests (Terraform changes), manual dispatch
- **Use Case**: Cost awareness and optimization
- **Status**: ⚠️ **Needs Manual Trigger Enhancement**

### 9. **Deployment Reports to GitHub Pages** 📊

**File**: `.github/workflows/deploy-reports-to-pages.yml`

- **Purpose**: Publish deployment reports to GitHub Pages
- **Triggers**: Push to main (report changes), manual dispatch
- **Use Case**: Public deployment dashboard
- **Status**: ✅ **Working**

## 🚀 **Recommended Deployment Workflows**

### For **Sandbox Development**:

1. **🔧 Bicep ALZ Sandbox Deployment** - For hub-spoke architectures
2. **🚀 Terraform ALZ Deployment** - For foundation architecture
3. **💰 Infracost Cost Estimation** - For cost analysis (manual run)

### For **Production-Ready Deployment**:

1. **🔄 Full Terraform Deployment (Clean + Deploy)** - Complete fresh deployment
2. **✅ Infrastructure Validation** - Pre-deployment checks
3. **🛡️ Security & Compliance** - Security validation

### For **Maintenance**:

1. **🗑️ Terraform ALZ Cleanup** - Resource cleanup
2. **📊 Deploy Reports to GitHub Pages** - Dashboard updates

## 🔧 **Quick Action Guide**

### To Deploy Fresh Sandbox:

```bash
# Option 1: Full Clean + Deploy (Recommended)
1. Go to Actions → "🚀 Terraform ALZ Full Deployment (Clean + Deploy)"
2. Click "Run workflow"
3. Select environment: sandbox
4. Click "Run workflow"

# Option 2: Direct Terraform Deploy
1. Go to Actions → "Terraform ALZ Deployment"
2. Click "Run workflow"
3. Select environment: sandbox
4. Click "Run workflow"

# Option 3: Bicep Hub-Spoke Deploy
1. Go to Actions → "Bicep ALZ Sandbox Deployment"
2. Click "Run workflow"
3. Select environment: sandbox
4. Click "Run workflow"
```

### To Check Costs:

```bash
1. Go to Actions → "💰 Infracost Cost Estimation"
2. Click "Run workflow"
3. Click "Run workflow" (manual dispatch)
```

### To Clean Up Resources:

```bash
1. Go to Actions → "🗑️ Terraform ALZ Cleanup"
2. Click "Run workflow"
3. Environment: sandbox
4. Confirmation: DELETE (exactly)
5. Resource type: all
6. Click "Run workflow"
```

## 📊 **Automated Reporting**

All deployment workflows now automatically:

- ✅ Generate comprehensive deployment reports
- ✅ Commit reports to repository
- ✅ Upload as GitHub Actions artifacts
- ✅ Publish to GitHub Pages dashboard: https://ma3u.github.io/azm-alz-min/
- ✅ Include resource inventory, cost analysis, and security scoring

## ⚠️ **Current Issues & Fixes Needed**

1. **October Reports Missing**: No deployments run in October yet

   - **Fix**: Run any deployment workflow to generate October reports

2. **Infracost Manual Trigger**: Currently optimized for PR comments

   - **Fix**: Enhance to better support standalone manual runs

3. **GitHub Pages**: Working but needs October data
   - **Fix**: Automatically updates when new reports are committed

## 🎯 **Next Steps**

1. **Run a test deployment** to generate October 2025 reports
2. **Test Infracost workflow** with manual dispatch
3. **Verify all workflows** are generating reports correctly
4. **Update GitHub Pages** with latest deployment data

This guide covers all essential workflows for complete Azure Landing Zone deployment and management in sandbox environment with both Bicep and Terraform support.
