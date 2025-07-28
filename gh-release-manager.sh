#!/bin/bash
set -euo pipefail
IFS=

# --- MCP Validation Header ---
# [MCP:REQUIRED] shellcheck validation
# [MCP:REQUIRED] POSIX compliance check
# [MCP:RECOMMENDED] Error handling coverage

# === LOGGING SYSTEM ===
# Reuse existing logging system from gh-issue-manager.sh

# Initialize logging system
log_init() {
    # Set default values if not provided
    ENABLE_LOGGING=${ENABLE_LOGGING:-false}
    LOG_LEVEL=${LOG_LEVEL:-INFO}
    LOG_FILE=${LOG_FILE:-./logs/gh-release-manager.log}
    
    # Create log directory if logging is enabled
    if [ "$ENABLE_LOGGING" = "true" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        log_info "log_init" "Logging initialized - Level: $LOG_LEVEL, File: $LOG_FILE"
    fi
}

# Main logging function
log_message() {
    local level="$1"
    local function_name="$2"
    local message="$3"
    local timestamp
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if logging is enabled
    if [ "$ENABLE_LOGGING" != "true" ]; then
        return 0
    fi
    
    # Check log level
    case "$LOG_LEVEL" in
        "DEBUG") allowed_levels="DEBUG INFO WARN ERROR" ;;
        "INFO")  allowed_levels="INFO WARN ERROR" ;;
        "WARN")  allowed_levels="WARN ERROR" ;;
        "ERROR") allowed_levels="ERROR" ;;
        *) allowed_levels="INFO WARN ERROR" ;;
    esac
    
    if [[ " $allowed_levels " =~ $level ]]; then
        echo "[$timestamp] [$level] [$function_name] $message" >> "$LOG_FILE"
        
        # Also output to console for ERROR and WARN
        if [ "$level" = "ERROR" ] || [ "$level" = "WARN" ]; then
            echo "[$timestamp] [$level] [$function_name] $message" >&2
        fi
    fi
}

# Logging wrapper functions
log_error() { log_message "ERROR" "$1" "$2"; }
log_warn()  { log_message "WARN"  "$1" "$2"; }
log_info()  { log_message "INFO"  "$1" "$2"; }
log_debug() { log_message "DEBUG" "$1" "$2"; }

# Performance timing function
log_timing() {
    local function_name="$1"
    local start_time="$2"
    local end_time
    local duration
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
    log_info "$function_name" "Execution time: ${duration}s"
}

# === CORE FUNCTIONS ===

# Global variables
DRY_RUN=false
VERSION_BUMP="patch"
PRE_RELEASE=false
PRE_RELEASE_TAG=""


# Show usage information
show_usage() {
    cat << EOF
GitHub Release Manager

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -M, --major         Increment major version (X.y.z -> X+1.0.0)
    -m, --minor         Increment minor version (x.Y.z -> x.Y+1.0)
    -p, --patch         Increment patch version (x.y.Z -> x.y.Z+1) [default]
    -a, --alpha TAG     Create alpha pre-release (x.y.z-alpha.TAG)
    -b, --beta TAG      Create beta pre-release (x.y.z-beta.TAG)
    -d, --dry-run       Show what would be done without making changes
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Create patch release (1.2.3 -> 1.2.4)
    $0 -m               # Create minor release (1.2.3 -> 1.3.0)
    $0 -M               # Create major release (1.2.3 -> 2.0.0)
    $0 -a 1             # Create alpha release (1.2.3 -> 1.2.4-alpha.1)
    $0 -d -m            # Dry run for minor release

ENVIRONMENT VARIABLES:
    ENABLE_LOGGING      Enable logging (default: false)
    LOG_LEVEL          Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
    LOG_FILE           Log file path (default: ./logs/gh-release-manager.log)

EOF
}

# Parse command line arguments
parse_arguments() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "parse_arguments" "Parsing command line arguments: $*"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -M|--major)
                VERSION_BUMP="major"
                log_debug "parse_arguments" "Set version bump to major"
                shift
                ;;
            -m|--minor)
                VERSION_BUMP="minor"
                log_debug "parse_arguments" "Set version bump to minor"
                shift
                ;;
            -p|--patch)
                VERSION_BUMP="patch"
                log_debug "parse_arguments" "Set version bump to patch"
                shift
                ;;
            -a|--alpha)
                PRE_RELEASE=true
                PRE_RELEASE_TAG="alpha.$2"
                log_debug "parse_arguments" "Set pre-release to alpha.$2"
                shift 2
                ;;
            -b|--beta)
                PRE_RELEASE=true
                PRE_RELEASE_TAG="beta.$2"
                log_debug "parse_arguments" "Set pre-release to beta.$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_debug "parse_arguments" "Enabled dry-run mode"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "parse_arguments" "Unknown option: $1"
                echo "Error: Unknown option: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "parse_arguments" "Arguments parsed - Bump: $VERSION_BUMP, Pre-release: $PRE_RELEASE, Pre-release Tag: $PRE_RELEASE_TAG, Dry-run: $DRY_RUN"
    log_timing "parse_arguments" "$start_time"
}

