#!/bin/bash

# Deployment Report Manager
# Manages deployment reports, keeping last 5 runs and archiving older ones

set -euo pipefail

# Configuration
REPORT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
MAX_REPORTS=5
ARCHIVE_DIR="${REPORT_DIR}/archive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get deployment timestamp
get_timestamp() {
    date '+%Y%m%d-%H%M%S'
}

# Function to create new deployment directory
create_deployment_dir() {
    local timestamp="$1"
    local deployment_dir="${REPORT_DIR}/${timestamp}"

    mkdir -p "${deployment_dir}"/{pre-deployment,deployment,post-deployment,resources,costs,security}

    echo "${deployment_dir}"
}

# Function to clean up old reports
cleanup_old_reports() {
    log_info "Cleaning up old deployment reports..."

    # Get list of deployment directories (timestamp format: YYYYMMDD-HHMMSS)
    deployment_dirs=()
    while IFS= read -r -d '' dir; do
        deployment_dirs+=("$dir")
    done < <(find "${REPORT_DIR}" -maxdepth 1 -type d -name "????????-??????" -print0 | sort -rz)

    local total_reports=${#deployment_dirs[@]}
    log_info "Found ${total_reports} existing deployment reports"

    if [[ ${total_reports} -gt ${MAX_REPORTS} ]]; then
        local reports_to_archive=$((total_reports - MAX_REPORTS))
        log_info "Archiving ${reports_to_archive} old reports..."

        # Archive old reports
        for ((i=${MAX_REPORTS}; i<${total_reports}; i++)); do
            local old_report="${deployment_dirs[$i]}"
            local report_name=$(basename "${old_report}")
            local archive_file="${ARCHIVE_DIR}/deployment-report-${report_name}.tar.gz"

            log_info "Archiving report: ${report_name}"
            tar -czf "${archive_file}" -C "${REPORT_DIR}" "${report_name}"
            rm -rf "${old_report}"
            log_success "Archived: ${archive_file}"
        done
    else
        log_info "No cleanup needed (${total_reports}/${MAX_REPORTS} reports)"
    fi
}

# Function to list current reports
list_reports() {
    log_info "Current deployment reports:"

    deployment_dirs=()
    while IFS= read -r -d '' dir; do
        deployment_dirs+=("$dir")
    done < <(find "${REPORT_DIR}" -maxdepth 1 -type d -name "????????-??????" -print0 | sort -rz)

    if [[ ${#deployment_dirs[@]} -eq 0 ]]; then
        log_warning "No deployment reports found"
        return
    fi

    for dir in "${deployment_dirs[@]}"; do
        local report_name=$(basename "${dir}")
        local report_date=$(echo "${report_name}" | cut -d'-' -f1)
        local report_time=$(echo "${report_name}" | cut -d'-' -f2)

        # Format date and time for display
        local formatted_date="${report_date:0:4}-${report_date:4:2}-${report_date:6:2}"
        local formatted_time="${report_time:0:2}:${report_time:2:2}:${report_time:4:2}"

        echo "  📊 ${report_name} (${formatted_date} ${formatted_time})"

        # Show summary if deployment succeeded
        local summary_file="${dir}/deployment-summary.json"
        if [[ -f "${summary_file}" ]]; then
            local status=$(jq -r '.deployment.status // "unknown"' "${summary_file}" 2>/dev/null || echo "unknown")
            local resources=$(jq -r '.deployment.resources_deployed // "unknown"' "${summary_file}" 2>/dev/null || echo "unknown")
            echo "     Status: ${status}, Resources: ${resources}"
        fi
    done

    # Show archived reports
    if [[ -d "${ARCHIVE_DIR}" ]] && [[ $(find "${ARCHIVE_DIR}" -name "*.tar.gz" | wc -l) -gt 0 ]]; then
        echo ""
        log_info "Archived reports:"
        find "${ARCHIVE_DIR}" -name "*.tar.gz" | sort | while read -r archive; do
            echo "  📦 $(basename "${archive}")"
        done
    fi
}

# Function to restore archived report
restore_report() {
    local archive_name="$1"
    local archive_file="${ARCHIVE_DIR}/${archive_name}"

    if [[ ! -f "${archive_file}" ]]; then
        log_error "Archive not found: ${archive_name}"
        return 1
    fi

    log_info "Restoring archived report: ${archive_name}"
    tar -xzf "${archive_file}" -C "${REPORT_DIR}"
    log_success "Report restored from archive"
}

# Function to generate report index
generate_index() {
    local index_file="${REPORT_DIR}/index.html"

    log_info "Generating deployment report index..."

    cat > "${index_file}" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>Azure Landing Zone - Deployment Reports</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; margin: 40px; }
        .header { background: linear-gradient(135deg, #0078d4, #00bcf2); color: white; padding: 20px; border-radius: 8px; margin-bottom: 30px; }
        .report-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .report-card { border: 1px solid #ddd; border-radius: 8px; padding: 20px; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .status-success { color: #107c10; }
        .status-failed { color: #d13438; }
        .status-unknown { color: #605e5c; }
        .timestamp { font-size: 0.9em; color: #605e5c; }
        .metric { display: inline-block; margin-right: 15px; padding: 5px 10px; background: #f3f2f1; border-radius: 4px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏗️ Azure Landing Zone Deployment Reports</h1>
        <p>Deployment history and analysis for Azure Landing Zone infrastructure</p>
    </div>
EOF

    # Add deployment reports
    deployment_dirs=()
    while IFS= read -r -d '' dir; do
        deployment_dirs+=("$dir")
    done < <(find "${REPORT_DIR}" -maxdepth 1 -type d -name "????????-??????" -print0 | sort -rz)

    if [[ ${#deployment_dirs[@]} -gt 0 ]]; then
        echo '    <div class="report-grid">' >> "${index_file}"

        for dir in "${deployment_dirs[@]}"; do
            local report_name=$(basename "${dir}")
            local summary_file="${dir}/deployment-summary.json"

            if [[ -f "${summary_file}" ]]; then
                # Extract data from summary
                local status=$(jq -r '.deployment.status // "unknown"' "${summary_file}" 2>/dev/null || echo "unknown")
                local resources=$(jq -r '.deployment.resources_deployed // "0"' "${summary_file}" 2>/dev/null || echo "0")
                local cost=$(jq -r '.costs.estimated_monthly // "N/A"' "${summary_file}" 2>/dev/null || echo "N/A")
                local security_score=$(jq -r '.security.overall_score // "N/A"' "${summary_file}" 2>/dev/null || echo "N/A")

                cat >> "${index_file}" << EOF
        <div class="report-card">
            <h3><a href="${report_name}/deployment-report.html">${report_name}</a></h3>
            <div class="timestamp">$(echo "${report_name}" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')</div>
            <div style="margin: 15px 0;">
                <span class="status-${status}">Status: ${status}</span>
            </div>
            <div>
                <span class="metric">📦 Resources: ${resources}</span>
                <span class="metric">💰 Cost: ${cost}</span>
                <span class="metric">🔒 Security: ${security_score}</span>
            </div>
        </div>
EOF
            fi
        done

        echo '    </div>' >> "${index_file}"
    else
        echo '    <p>No deployment reports available.</p>' >> "${index_file}"
    fi

    echo '</body></html>' >> "${index_file}"

    log_success "Report index generated: ${index_file}"
}

# Main function
main() {
    local action="${1:-list}"

    case "${action}" in
        "create")
            local timestamp=$(get_timestamp)
            local deployment_dir=$(create_deployment_dir "${timestamp}")
            log_success "Created deployment directory: ${deployment_dir}"
            echo "${deployment_dir}"
            ;;
        "cleanup")
            cleanup_old_reports
            ;;
        "list")
            list_reports
            ;;
        "restore")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 restore <archive-name>"
                exit 1
            fi
            restore_report "$2"
            ;;
        "index")
            generate_index
            ;;
        *)
            echo "Usage: $0 {create|cleanup|list|restore|index}"
            echo ""
            echo "Commands:"
            echo "  create   - Create new deployment report directory"
            echo "  cleanup  - Archive old reports (keep last ${MAX_REPORTS})"
            echo "  list     - List current and archived reports"
            echo "  restore  - Restore archived report"
            echo "  index    - Generate HTML index of reports"
            exit 1
            ;;
    esac
}

# Ensure archive directory exists
mkdir -p "${ARCHIVE_DIR}"

# Run main function
main "$@"
