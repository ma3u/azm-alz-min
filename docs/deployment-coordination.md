# Deployment Coordination System

This document explains how the deployment coordination system prevents concurrent deployments between GitHub Actions and Azure DevOps pipelines.

## 🎯 Problem Statement

When multiple CI/CD systems (GitHub Actions and Azure DevOps) deploy to the same Azure environment, they can cause:

- **Resource conflicts** - Two pipelines modifying the same resources simultaneously
- **State corruption** - Terraform/Bicep state files getting corrupted
- **Deployment failures** - Race conditions and lock conflicts
- **Inconsistent infrastructure** - Partial deployments overwriting each other

## 🔒 Solution: Distributed Locking

The deployment coordination system uses Azure Storage as a distributed lock mechanism:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  GitHub Actions │    │  Azure Storage   │    │  Azure DevOps   │
│                 │    │  (Lock Store)    │    │                 │
│  1. Check Lock  │───▶│                  │◀───│  1. Check Lock  │
│  2. Acquire     │    │ deployment-lock- │    │  2. Wait/Fail   │
│  3. Deploy      │    │ sandbox: {       │    │  3. Try Later   │
│  4. Release     │───▶│   pipeline: gh,  │    │                 │
│                 │    │   timestamp,     │    │                 │
│                 │    │   build_id       │    │                 │
│                 │    │ }                │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🏗️ Architecture Components

### 1. Coordination Infrastructure

- **Resource Group**: `rg-deployment-coordination`
- **Storage Account**: `stcoord{unique-suffix}` (globally unique)
- **Container**: `deployment-locks`
- **Lock Format**: `deployment-lock-{environment}`

### 2. Lock Information

Each lock contains:

```
{pipeline_type}|{timestamp}|{build_id}
```

Example:

```
github|2025-09-27 17:30:00 UTC|1234567890
```

### 3. Timeout Mechanisms

- **Lock Timeout**: 30 minutes (stale lock detection)
- **Deployment Timeout**: 120 minutes (max wait time)
- **Check Interval**: 30 seconds (polling frequency)

## 🚀 Usage Examples

### Basic Operations

```bash
# Check if environment is locked
./scripts/deployment-coordinator.sh check github sandbox

# Acquire deployment lock
./scripts/deployment-coordinator.sh acquire github sandbox

# Release deployment lock
./scripts/deployment-coordinator.sh release github sandbox

# Wait for lock to be released
./scripts/deployment-coordinator.sh wait sandbox 60

# Emergency: force break lock
./scripts/deployment-coordinator.sh force-break sandbox
```

### CI/CD Integration

#### GitHub Actions

```yaml
- name: 🎯 Acquire Deployment Lock
  run: |
    ./scripts/deployment-coordinator.sh acquire github ${{ matrix.env }} || {
      echo "❌ Another deployment in progress"
      exit 1
    }

- name: 🔓 Release Deployment Lock
  if: always()
  run: |
    ./scripts/deployment-coordinator.sh release github ${{ matrix.env }}
```

#### Azure DevOps

```yaml
- script: |
    ./scripts/deployment-coordinator.sh acquire azdevops sandbox || {
      echo "##vso[task.logissue type=error]Deployment lock failed"
      exit 1
    }
  displayName: 'Acquire Deployment Lock'
```

## 🛡️ Safety Features

### 1. Stale Lock Detection

- Locks older than 30 minutes are considered stale
- Automatic cleanup of expired locks
- Manual force-break option for emergencies

### 2. Ownership Validation

- Only the pipeline that acquired a lock can release it
- Pipeline type verification (github vs azdevops)
- Build ID tracking for audit

### 3. Error Handling

- Graceful failure when lock acquisition fails
- Clear error messages with troubleshooting steps
- Non-blocking lock release (warnings only)

### 4. Monitoring & Alerts

- Lock status logging in CI/CD outputs
- Pipeline variable setting for downstream jobs
- Integration with Azure Monitor (optional)

## 🔧 Configuration

### Environment Variables

```bash
# Set in CI/CD pipelines automatically
GITHUB_RUN_ID=1234567890           # GitHub Actions
BUILD_BUILDNUMBER=20230927.1       # Azure DevOps

# Optional: Custom lock timeout
LOCK_TIMEOUT_MINUTES=30
DEPLOYMENT_TIMEOUT_MINUTES=120
```

### Pipeline-Specific Settings

#### GitHub Actions

- Lock acquired before deployment starts
- Released after deployment completes (success/failure)
- Additional cleanup release in final stage

#### Azure DevOps

- Lock acquired in deployment environment
- Released immediately after successful deploy
- Cleanup release in feature branch cleanup

## 🚨 Troubleshooting

### Common Scenarios

#### 1. "Lock acquisition failed"

```bash
# Check who has the lock
./scripts/deployment-coordinator.sh check sandbox

# Wait for release (up to 60 minutes)
./scripts/deployment-coordinator.sh wait sandbox 60

# Emergency: force break (use carefully)
./scripts/deployment-coordinator.sh force-break sandbox
```

#### 2. "Stale lock detected"

- Locks older than 30 minutes are automatically cleaned
- Check if the original pipeline failed or is stuck
- Safe to proceed with deployment

#### 3. "Cannot access coordination storage"

- Verify Azure CLI authentication
- Check subscription permissions
- Ensure coordination infrastructure exists

### Debugging Commands

```bash
# Check coordination infrastructure
az group show --name rg-deployment-coordination

# List all locks
az storage blob list \
  --account-name stcoordXXXXXXXX \
  --container-name deployment-locks \
  --output table

# Manual lock inspection
az storage blob download \
  --account-name stcoordXXXXXXXX \
  --container-name deployment-locks \
  --name deployment-lock-sandbox \
  --output tsv
```

## 📋 Best Practices

### 1. Pipeline Design

- ✅ Always acquire lock before deployment
- ✅ Release lock in cleanup stages with `always()` condition
- ✅ Include lock status in deployment logs
- ❌ Never skip lock acquisition for "quick" deployments

### 2. Error Handling

- ✅ Fail fast when lock acquisition fails
- ✅ Provide clear error messages and next steps
- ✅ Use warnings (not errors) for lock release failures
- ❌ Don't force-break locks without investigation

### 3. Monitoring

- ✅ Monitor lock acquisition times and patterns
- ✅ Set up alerts for stuck deployments
- ✅ Review coordination infrastructure costs
- ✅ Audit lock usage for security compliance

### 4. Team Coordination

- ✅ Communicate planned deployments to team
- ✅ Use descriptive commit messages and PR titles
- ✅ Monitor both GitHub Actions and Azure DevOps
- ✅ Document any manual lock breaks

## 🔍 Monitoring & Analytics

### Lock Usage Metrics

```bash
# Recent deployments
az storage blob list \
  --account-name stcoordXXXXXXXX \
  --container-name deployment-locks \
  --query '[].{Name:name, Modified:properties.lastModified}' \
  --output table

# Lock conflicts (failed acquisitions)
# Check CI/CD pipeline logs for "Failed to acquire deployment lock"
```

### Cost Analysis

- Coordination infrastructure: ~$2-5/month
- Storage transactions: ~$0.01-0.10/month
- Total coordination cost: <$10/month

## 🚀 Future Enhancements

### Planned Features

1. **Web Dashboard** - Visual lock status and history
2. **Slack Integration** - Lock notifications in team channels
3. **Advanced Analytics** - Deployment patterns and conflicts
4. **Multi-Region Support** - Coordinate across Azure regions
5. **Queue System** - Automatic deployment queuing

### Integration Opportunities

1. **Azure Monitor** - Lock metrics and alerting
2. **Application Insights** - Deployment correlation
3. **Azure DevOps API** - Advanced pipeline coordination
4. **GitHub API** - Enhanced workflow management

---

## 📞 Support

For issues with deployment coordination:

1. **Check lock status**: `./scripts/deployment-coordinator.sh check {environment}`
2. **Review pipeline logs** for lock acquisition attempts
3. **Monitor Azure Storage** for coordination infrastructure health
4. **Contact DevOps team** for force-break decisions

**Remember**: The coordination system is designed to prevent conflicts, not cause delays. If you're seeing frequent lock conflicts, review your deployment cadence and consider staggered deployment windows.
