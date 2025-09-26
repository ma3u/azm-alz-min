# GitHub to Azure DevOps Repository Sync Guide

This guide explains how to synchronize your public GitHub repository (`ma3u/azm-alz-min`) with a private Azure DevOps repository while maintaining a clean CI/CD workflow.

## 🔄 Sync Strategies Overview

| Strategy                | Use Case                                 | Pros                               | Cons                 |
| ----------------------- | ---------------------------------------- | ---------------------------------- | -------------------- |
| **GitHub as Source**    | Open source project with private CI/CD   | Public visibility, GitHub features | Complex sync setup   |
| **Azure DevOps Mirror** | Private development with public showcase | Full Azure integration             | Manual sync required |
| **Dual Repository**     | Separate public/private concerns         | Clean separation                   | Potential drift      |

## 📋 Prerequisites

- **GitHub Repository**: [ma3u/azm-alz-min](https://github.com/ma3u/azm-alz-min) (Public)
- **Azure DevOps Organization**: `matthiasbuchhorn`
- **Azure DevOps Project**: `avm-alz-min`
- **GitHub Personal Access Token**: With repo permissions
- **Azure DevOps Personal Access Token**: With full access

## 🛠️ Method 1: Azure DevOps with GitHub Integration (Recommended)

This method uses GitHub as the source of truth while running Azure DevOps pipelines.

### Step 1: Connect GitHub Repository to Azure DevOps

1. **Navigate to Azure DevOps Project**:

   - Go to [Azure DevOps](https://dev.azure.com/matthiasbuchhorn/avm-alz-min)

2. **Create GitHub Service Connection**:

   ```yaml
   Service Connection Name: github-connection-azm-alz-min
   Connection Type: GitHub
   Authentication: Personal Access Token
   Token: <your-github-pat>
   ```

3. **Configure Pipeline to Use GitHub**:

   ```yaml
   # In azure-pipelines.yml
   resources:
     repositories:
       - repository: github-repo
         type: github
         endpoint: github-connection-azm-alz-min
         name: ma3u/azm-alz-min
         ref: refs/heads/main

   trigger:
     branches:
       include:
         - main
         - develop
   ```

### Step 2: Configure Branch Policies

1. **GitHub Branch Protection**:

   - Go to repository **Settings** → **Branches**
   - Protect `main` branch:
     ```yaml
     Branch Protection Rules:
       - Require pull request reviews (1 reviewer)
       - Require status checks to pass
       - Require branches to be up to date
       - Include administrators
     ```

2. **Azure DevOps Pipeline Trigger**:

   ```yaml
   # Pipeline triggers on GitHub events
   trigger:
     branches:
       include:
         - main
         - develop
         - feature/*
     paths:
       include:
         - infra/*
         - pipelines/*

   pr:
     branches:
       include:
         - main
         - develop
   ```

### Step 3: Setup Status Checks

Configure GitHub to require Azure DevOps pipeline success:

```bash
# Using GitHub CLI
gh api repos/ma3u/azm-alz-min/branches/main/protection \
  --method PUT \
  --field required_status_checks[strict]=true \
  --field required_status_checks[contexts][]="avm-alz-min - CI"
```

## 🔀 Method 2: Bidirectional Sync with Git Automation

### Step 1: Create Azure DevOps Repository

1. **Create Private Repository**:

   - Go to **Repos** in Azure DevOps
   - Create new repository: `avm-alz-min-private`

2. **Clone Both Repositories**:

   ```bash
   # Clone GitHub repo
   git clone https://github.com/ma3u/azm-alz-min.git
   cd azm-alz-min

   # Add Azure DevOps remote
   git remote add azuredevops https://matthiasbuchhorn@dev.azure.com/matthiasbuchhorn/avm-alz-min/_git/avm-alz-min-private
   ```

### Step 2: Create Sync Pipeline

Create a sync pipeline that runs on GitHub changes:

```yaml
# pipelines/sync-pipeline.yml
name: "Sync-$(Date:yyyyMMdd)-$(Rev:r)"

trigger:
  branches:
    include:
      - main

pool:
  vmImage: "ubuntu-latest"

variables:
  - name: githubRepo
    value: "https://github.com/ma3u/azm-alz-min.git"
  - name: azureDevOpsRepo
    value: "https://matthiasbuchhorn@dev.azure.com/matthiasbuchhorn/avm-alz-min/_git/avm-alz-min-private"

steps:
  - checkout: self
    persistCredentials: true

  - task: Bash@3
    displayName: "Sync to Azure DevOps"
    inputs:
      targetType: "inline"
      script: |
        # Configure git
        git config --global user.email "pipeline@azuredevops.com"
        git config --global user.name "Azure DevOps Pipeline"

        # Add Azure DevOps remote if it doesn't exist
        if ! git remote get-url azuredevops; then
          git remote add azuredevops $(azureDevOpsRepo)
        fi

        # Push to Azure DevOps
        git push azuredevops HEAD:main --force

        echo "Sync completed successfully"
```

### Step 3: Configure Azure DevOps Pipeline

```yaml
# Azure DevOps pipeline (runs on private repo)
trigger:
  branches:
    include:
      - main

resources:
  repositories:
    - repository: private-repo
      type: git
      name: avm-alz-min-private
      ref: refs/heads/main

stages:
  - stage: Deploy
    jobs:
      - job: DeployInfrastructure
        steps:
          - checkout: private-repo
          - template: templates/bicep-deploy.yml
```

## 🤖 Method 3: Automated Sync with GitHub Actions

### Step 1: Create GitHub Action for Sync

```yaml
# .github/workflows/sync-to-azuredevops.yml
name: Sync to Azure DevOps

on:
  push:
    branches: [main, develop]
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout GitHub repository
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure Git
        run: |
          git config --global user.email "action@github.com"
          git config --global user.name "GitHub Action"

      - name: Add Azure DevOps remote
        run: |
          git remote add azuredevops https://${{ secrets.AZUREDEVOPS_USERNAME }}:${{ secrets.AZUREDEVOPS_PAT }}@dev.azure.com/matthiasbuchhorn/avm-alz-min/_git/avm-alz-min-private

      - name: Push to Azure DevOps
        run: |
          git push azuredevops main --force
          echo "Sync completed to Azure DevOps"
```

### Step 2: Configure GitHub Secrets

Add these secrets to your GitHub repository:

```yaml
Repository Secrets:
  - AZUREDEVOPS_USERNAME: matthiasbuchhorn
  - AZUREDEVOPS_PAT: <your-azure-devops-pat>
```

### Step 3: Azure DevOps Pipeline Triggers

```yaml
# Azure DevOps pipeline triggered by sync
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infra/*
      - pipelines/*

schedules:
  - cron: "0 2 * * *" # Daily at 2 AM
    displayName: Daily sync check
    branches:
      include:
        - main
```

## 🔒 Security Considerations

### GitHub Repository (Public)

1. **Sensitive Information**:

   ```yaml
   # Never commit these to public repo:
   - Azure subscription IDs
   - Service principal credentials
   - Environment-specific secrets
   - Internal URLs or endpoints
   ```

2. **Use Parameter Files**:
   ```json
   {
     "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
       "namePrefix": {
         "value": "kv-public-demo"
       }
     }
   }
   ```

### Azure DevOps Repository (Private)

1. **Environment-Specific Configurations**:

   ```yaml
   # pipelines/variables/production.yml
   variables:
     - name: azureSubscriptionId
       value: "real-subscription-id"
     - name: resourceGroupPrefix
       value: "rg-prod-avm-alz"
   ```

2. **Secret Management**:
   ```yaml
   # Use Azure DevOps variable groups
   variables:
     - group: "azure-landingzone-secrets"
     - group: "azure-landingzone-prod"
   ```

## 📊 Monitoring and Maintenance

### Sync Health Monitoring

1. **GitHub Action Monitoring**:

   ```yaml
   # Add notification step
   - name: Notify on failure
     if: failure()
     uses: actions/github-script@v6
     with:
       script: |
         github.rest.issues.create({
           owner: context.repo.owner,
           repo: context.repo.repo,
           title: 'Azure DevOps sync failed',
           body: 'The sync to Azure DevOps failed. Please check the workflow.'
         })
   ```

2. **Azure DevOps Pipeline Status**:

   ```yaml
   # Add monitoring task
   - task: AzureCLI@2
     displayName: "Check Sync Status"
     inputs:
       scriptType: "bash"
       scriptLocation: "inlineScript"
       inlineScript: |
         # Compare commit hashes
         GITHUB_COMMIT=$(curl -s https://api.github.com/repos/ma3u/azm-alz-min/commits/main | jq -r '.sha')
         AZDO_COMMIT=$(git rev-parse HEAD)

         if [ "$GITHUB_COMMIT" != "$AZDO_COMMIT" ]; then
           echo "##vso[task.logissue type=warning]Repositories are out of sync"
         fi
   ```

### Regular Maintenance Tasks

1. **Weekly Repository Comparison**:

   ```bash
   #!/bin/bash
   # weekly-sync-check.sh

   # Compare repository states
   git fetch origin
   git fetch azuredevops

   if [ "$(git rev-parse origin/main)" != "$(git rev-parse azuredevops/main)" ]; then
     echo "Repositories are out of sync!"
     # Send notification or create issue
   fi
   ```

2. **Branch Cleanup**:
   ```yaml
   # Automated branch cleanup
   - task: PowerShell@2
     displayName: "Clean up merged branches"
     inputs:
       targetType: "inline"
       script: |
         git branch --merged | ForEach-Object {
           if ($_ -notmatch "main|develop") {
             git branch -d $_.Trim()
           }
         }
   ```

## 🎯 Best Practices

### Repository Management

- ✅ Use semantic versioning for releases
- ✅ Maintain clean commit history
- ✅ Use conventional commit messages
- ✅ Regularly sync repositories
- ✅ Monitor sync health

### Security

- ✅ Never store secrets in public repository
- ✅ Use different parameter files for environments
- ✅ Implement proper access controls
- ✅ Regular audit of sync permissions
- ✅ Use service accounts for automation

### Documentation

- ✅ Document sync procedures
- ✅ Maintain architecture diagrams
- ✅ Keep README files updated
- ✅ Document troubleshooting procedures
- ✅ Version control all configurations

## 🔧 Troubleshooting

### Common Sync Issues

1. **Authentication Failures**:

   ```bash
   # Test GitHub access
   curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

   # Test Azure DevOps access
   curl -u "username:$AZDO_PAT" https://dev.azure.com/matthiasbuchhorn/_apis/projects
   ```

2. **Merge Conflicts**:

   ```bash
   # Resolve conflicts during sync
   git fetch azuredevops
   git merge azuredevops/main
   # Resolve conflicts manually
   git commit -m "Resolve sync conflicts"
   git push origin main
   ```

3. **Branch Protection Conflicts**:
   ```bash
   # Temporarily disable branch protection
   gh api repos/ma3u/azm-alz-min/branches/main/protection --method DELETE
   # Perform sync
   # Re-enable protection
   ```

## 📈 Advanced Scenarios

### Multi-Environment Sync

```yaml
# Sync different environments to different repositories
environments:
  dev:
    github_branch: develop
    azdo_repo: avm-alz-min-dev
  prod:
    github_branch: main
    azdo_repo: avm-alz-min-prod
```

### Selective Sync

```yaml
# Only sync specific directories
rsync_options:
  include:
    - infra/
    - pipelines/
    - README.md
  exclude:
    - .git/
    - docs/sensitive/
```

---

**Next Steps**: After setting up synchronization, proceed to configure your [Azure DevOps Pipeline Setup](./azure-devops-setup.md).
