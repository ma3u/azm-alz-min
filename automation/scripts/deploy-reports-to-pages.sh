#!/bin/bash

# Deploy Deployment Reports to GitHub Pages
# This script pushes deployment reports to GitHub Pages via GitHub Actions workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
REPORTS_DIR="$PROJECT_ROOT/deployment-reports"
WORKFLOW_FILE="deploy-reports-to-pages"

echo -e "${BLUE}🚀 Azure Landing Zone - GitHub Pages Deployment${NC}"
echo -e "${BLUE}===============================================${NC}"

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first:"
        print_error "brew install gh"
        exit 1
    fi

    # Check if logged into GitHub
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub. Please run:"
        print_error "gh auth login"
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Not in a git repository"
        exit 1
    fi

    # Check if deployment reports exist
    if [ ! -d "$REPORTS_DIR" ] || [ ! -f "$REPORTS_DIR/index.html" ]; then
        print_error "No deployment reports found in $REPORTS_DIR"
        print_error "Please run: ./automation/scripts/deploy-with-report.sh"
        exit 1
    fi

    print_success "All prerequisites met"
}

# Get repository information
get_repo_info() {
    print_status "Getting repository information..."

    REPO_INFO=$(gh repo view --json name,owner,url)
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    REPO_OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
    REPO_URL=$(echo "$REPO_INFO" | jq -r '.url')

    print_status "Repository: $REPO_OWNER/$REPO_NAME"
    print_status "URL: $REPO_URL"
}

# Check GitHub Pages configuration
check_pages_config() {
    print_status "Checking GitHub Pages configuration..."

    # Check if Pages is enabled
    if gh api "repos/$REPO_OWNER/$REPO_NAME/pages" --silent 2>/dev/null; then
        PAGES_INFO=$(gh api "repos/$REPO_OWNER/$REPO_NAME/pages")
        PAGES_URL=$(echo "$PAGES_INFO" | jq -r '.html_url // empty')
        PAGES_SOURCE=$(echo "$PAGES_INFO" | jq -r '.source.branch // empty')

        if [ -n "$PAGES_URL" ]; then
            print_success "GitHub Pages is already configured"
            print_status "Pages URL: $PAGES_URL"
            print_status "Source branch: $PAGES_SOURCE"
        fi
    else
        print_warning "GitHub Pages is not configured yet"
        print_status "It will be automatically configured when the workflow runs"
    fi
}

# Commit and push reports
commit_and_push_reports() {
    print_status "Preparing deployment reports for GitHub Pages..."

    cd "$PROJECT_ROOT"

    # Check if there are changes to commit
    if git status --porcelain "$REPORTS_DIR" | grep -q .; then
        print_status "Committing updated deployment reports..."
        git add "$REPORTS_DIR"
        git commit -m "📊 Update deployment reports for GitHub Pages

- Updated deployment reports with latest data
- Ready for GitHub Pages deployment
- Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    else
        print_status "No changes to deployment reports detected"
    fi

    # Push to main branch
    print_status "Pushing to main branch..."
    git push origin main

    print_success "Reports pushed to main branch"
}

# Trigger GitHub Pages deployment workflow
trigger_deployment() {
    print_status "Triggering GitHub Pages deployment workflow..."

    # Trigger the workflow manually
    if gh workflow run "$WORKFLOW_FILE" --field force_deploy=true; then
        print_success "GitHub Pages deployment workflow triggered"

        # Wait a moment and show workflow status
        sleep 3
        print_status "Checking workflow status..."
        gh workflow view "$WORKFLOW_FILE" --web 2>/dev/null || true

        # Show recent workflow runs
        print_status "Recent workflow runs:"
        gh run list --workflow="$WORKFLOW_FILE" --limit=3

    else
        print_error "Failed to trigger GitHub Pages deployment workflow"
        exit 1
    fi
}

# Wait for deployment and get URL
wait_for_deployment() {
    print_status "Waiting for deployment to complete..."

    # Get the latest workflow run
    RUN_ID=$(gh run list --workflow="$WORKFLOW_FILE" --limit=1 --json databaseId --jq '.[0].databaseId')

    if [ -n "$RUN_ID" ]; then
        print_status "Monitoring workflow run ID: $RUN_ID"

        # Wait for completion (with timeout)
        TIMEOUT=300 # 5 minutes
        ELAPSED=0

        while [ $ELAPSED -lt $TIMEOUT ]; do
            STATUS=$(gh run view "$RUN_ID" --json status --jq '.status')

            case "$STATUS" in
                "completed")
                    CONCLUSION=$(gh run view "$RUN_ID" --json conclusion --jq '.conclusion')
                    if [ "$CONCLUSION" = "success" ]; then
                        print_success "Deployment completed successfully!"

                        # Get the Pages URL
                        if PAGES_URL=$(gh api "repos/$REPO_OWNER/$REPO_NAME/pages" --jq '.html_url' 2>/dev/null); then
                            echo ""
                            echo -e "${GREEN}🎉 Deployment Reports are now live!${NC}"
                            echo -e "${GREEN}📊 Dashboard URL: ${PAGES_URL}${NC}"
                            echo -e "${GREEN}🔗 Direct link: ${PAGES_URL}index.html${NC}"
                            echo ""
                        fi
                        return 0
                    else
                        print_error "Deployment failed with conclusion: $CONCLUSION"
                        print_error "Check the workflow logs: gh run view $RUN_ID --log"
                        exit 1
                    fi
                    ;;
                "in_progress"|"queued")
                    print_status "Deployment in progress... ($ELAPSED/${TIMEOUT}s)"
                    ;;
                *)
                    print_warning "Unknown status: $STATUS"
                    ;;
            esac

            sleep 10
            ELAPSED=$((ELAPSED + 10))
        done

        print_warning "Deployment is taking longer than expected"
        print_status "You can monitor it manually: gh run view $RUN_ID"
    fi
}

# Main execution
main() {
    print_status "Starting GitHub Pages deployment process..."
    echo ""

    check_prerequisites
    get_repo_info
    check_pages_config
    commit_and_push_reports
    trigger_deployment
    wait_for_deployment

    echo ""
    print_success "GitHub Pages deployment process completed!"
    print_status "Your deployment reports are now available online"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Deploy deployment reports to GitHub Pages"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check, -c    Only check prerequisites and configuration"
        echo "  --status, -s   Show current deployment status"
        echo ""
        echo "Examples:"
        echo "  $0                    # Deploy reports to GitHub Pages"
        echo "  $0 --check           # Check configuration only"
        echo "  $0 --status          # Show deployment status"
        exit 0
        ;;
    --check|-c)
        print_status "Configuration check mode"
        check_prerequisites
        get_repo_info
        check_pages_config
        print_success "Configuration check completed"
        exit 0
        ;;
    --status|-s)
        print_status "Checking deployment status..."
        get_repo_info
        check_pages_config

        # Show recent workflow runs
        print_status "Recent GitHub Pages deployments:"
        gh run list --workflow="$WORKFLOW_FILE" --limit=5 2>/dev/null || print_warning "No workflow runs found"
        exit 0
        ;;
    "")
        # Run main deployment
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_error "Use --help for usage information"
        exit 1
        ;;
esac
