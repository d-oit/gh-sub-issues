#!/bin/bash

# wizard-config.sh - Configuration management for GitHub Issue Manager Wizard
# This module handles environment loading, validation, and logging setup
# Integrates with the existing logging system from gh-issue-manager.sh

# === LOGGING SYSTEM INTEGRATION ===

# Debug and verbose mode variables
export DEBUG_MODE=${DEBUG_MODE:-false}
export VERBOSE_MODE=${VERBOSE_MODE:-false}
export LOG_ROTATION_SIZE=${LOG_ROTATION_SIZE:-10485760}  # 10MB default
export LOG_ROTATION_COUNT=${LOG_ROTATION_COUNT:-5}      # Keep 5 old logs
export PERFORMANCE_MONITORING=${PERFORMANCE_MONITORING:-false}

# Initialize logging system (compatible with gh-issue-manager.sh)
log_init() {
    # Set default values if not provided
    export ENABLE_LOGGING=${ENABLE_LOGGING:-false}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    export LOG_FILE=${LOG_FILE:-./logs/gh-issue-manager.log}
    
    # Enable debug logging if debug mode is on
    if [ "$DEBUG_MODE" = "true" ]; then
        export ENABLE_LOGGING="true"
        export LOG_LEVEL="DEBUG"
    fi
    
    # Create log directory if logging is enabled
    if [ "$ENABLE_LOGGING" = "true" ]; then
        local log_dir
        # Use cross-platform directory extraction
        if command -v dirname >/dev/null 2>&1; then
            log_dir=$(dirname "$LOG_FILE")
        else
            # Fallback for Windows/systems without dirname
            log_dir="${LOG_FILE%/*}"
            if [ "$log_dir" = "$LOG_FILE" ]; then
                log_dir="."
            fi
        fi
        
        if [ ! -d "$log_dir" ]; then
            # Try to create directory with cross-platform approach
            if command -v mkdir >/dev/null 2>&1; then
                if ! mkdir -p "$log_dir" 2>/dev/null; then
                    echo "Warning: Could not create log directory '$log_dir'. Logging disabled." >&2
                    export ENABLE_LOGGING="false"
                    return 1
                fi
            fi
        fi
        
        # Rotate logs if needed
        rotate_logs_if_needed
        
        log_info "log_init" "Logging initialized - Level: $LOG_LEVEL, File: $LOG_FILE"
        if [ "$DEBUG_MODE" = "true" ]; then
            log_debug "log_init" "Debug mode enabled"
        fi
        if [ "$VERBOSE_MODE" = "true" ]; then
            log_debug "log_init" "Verbose mode enabled"
        fi
        if [ "$PERFORMANCE_MONITORING" = "true" ]; then
            log_debug "log_init" "Performance monitoring enabled"
        fi
    fi
}

# Main logging function (compatible with gh-issue-manager.sh)
log_message() {
    local level="$1"
    local function_name="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    
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

# Verbose output function (prints to console when verbose mode is enabled)
log_verbose() {
    local function_name="$1"
    local message="$2"
    
    if [ "$VERBOSE_MODE" = "true" ]; then
        echo "[VERBOSE] [$function_name] $message"
    fi
    
    # Also log to file if logging is enabled
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "$function_name" "$message"
    fi
}

# === LOG ROTATION SYSTEM ===

# Check if log rotation is needed and perform it
rotate_logs_if_needed() {
    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi
    
    # Get file size (cross-platform approach)
    local file_size=0
    if command -v stat >/dev/null 2>&1; then
        # Try GNU stat first, then BSD stat
        if stat -c%s "$LOG_FILE" >/dev/null 2>&1; then
            file_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        elif stat -f%z "$LOG_FILE" >/dev/null 2>&1; then
            file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        fi
    elif command -v wc >/dev/null 2>&1; then
        # Fallback using wc
        file_size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ' || echo 0)
    fi
    
    # Rotate if file size exceeds limit
    if [ "$file_size" -gt "$LOG_ROTATION_SIZE" ]; then
        rotate_log_files
    fi
}

# Perform log file rotation
rotate_log_files() {
    local log_dir log_basename
    log_dir=$(dirname "$LOG_FILE")
    log_basename=$(basename "$LOG_FILE")
    
    # Remove oldest log if we've reached the rotation count
    local oldest_log="${log_dir}/${log_basename}.${LOG_ROTATION_COUNT}"
    if [ -f "$oldest_log" ]; then
        rm -f "$oldest_log" 2>/dev/null || true
    fi
    
    # Rotate existing logs
    local i=$((LOG_ROTATION_COUNT - 1))
    while [ $i -gt 0 ]; do
        local current_log="${log_dir}/${log_basename}.${i}"
        local next_log="${log_dir}/${log_basename}.$((i + 1))"
        
        if [ -f "$current_log" ]; then
            mv "$current_log" "$next_log" 2>/dev/null || true
        fi
        
        i=$((i - 1))
    done
    
    # Move current log to .1
    if [ -f "$LOG_FILE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
    fi
    
    # Create new empty log file
    touch "$LOG_FILE" 2>/dev/null || true
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "rotate_log_files" "Log rotation completed - old logs preserved with .1-.${LOG_ROTATION_COUNT} extensions"
    fi
}

# Performance timing function
log_timing() {
    local function_name="$1"
    local start_time="$2"
    local operation_type="${3:-general}"
    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local duration
    
    # Try to calculate duration with bc, fallback to awk if bc is not available
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
    elif command -v awk >/dev/null 2>&1; then
        duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}" 2>/dev/null || echo "N/A")
    else
        duration="N/A"
    fi
    
    local log_message="Execution time: ${duration}s"
    if [ "$operation_type" != "general" ]; then
        log_message="$operation_type execution time: ${duration}s"
    fi
    
    log_info "$function_name" "$log_message"
    
    # Performance monitoring - log slow operations
    if [ "$PERFORMANCE_MONITORING" = "true" ] && [ "$duration" != "N/A" ]; then
        # Check if operation took longer than threshold (2 seconds for API calls, 5 seconds for others)
        local threshold=5
        if [ "$operation_type" = "github_api" ]; then
            threshold=2
        fi
        
        # Compare duration with threshold (using awk for floating point comparison)
        if command -v awk >/dev/null 2>&1; then
            local is_slow
            is_slow=$(awk "BEGIN {print ($duration > $threshold) ? 1 : 0}" 2>/dev/null || echo 0)
            if [ "$is_slow" = "1" ]; then
                log_warn "$function_name" "SLOW OPERATION: $log_message (threshold: ${threshold}s)"
                if [ "$VERBOSE_MODE" = "true" ]; then
                    echo "[PERFORMANCE WARNING] Slow operation detected: $function_name took ${duration}s" >&2
                fi
            fi
        fi
    fi
}

# === GITHUB API PERFORMANCE MONITORING ===

# Wrapper for GitHub CLI commands with performance monitoring
gh_api_call() {
    local api_endpoint="$1"
    local function_name="${2:-gh_api_call}"
    shift 2
    local gh_args=("$@")
    
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "$function_name" "GitHub API call: $api_endpoint"
        if [ "$DEBUG_MODE" = "true" ]; then
            log_debug "$function_name" "Full command: gh api $api_endpoint ${gh_args[*]}"
        fi
    fi
    
    # Execute the GitHub CLI command
    local result exit_code
    if result=$(gh api "$api_endpoint" "${gh_args[@]}" 2>&1); then
        exit_code=0
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "$function_name" "GitHub API call successful"
        fi
    else
        exit_code=$?
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "$function_name" "GitHub API call failed: $result"
        fi
    fi
    
    # Log timing information
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "$function_name" "$start_time" "github_api"
    fi
    
    # Output result and return exit code
    echo "$result"
    return $exit_code
}

# Wrapper for GitHub CLI issue commands with performance monitoring
gh_issue_call() {
    local issue_command="$1"
    local function_name="${2:-gh_issue_call}"
    shift 2
    local gh_args=("$@")
    
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "$function_name" "GitHub issue command: $issue_command"
        if [ "$DEBUG_MODE" = "true" ]; then
            log_debug "$function_name" "Full command: gh issue $issue_command ${gh_args[*]}"
        fi
    fi
    
    # Execute the GitHub CLI command
    local result exit_code
    if result=$(gh issue "$issue_command" "${gh_args[@]}" 2>&1); then
        exit_code=0
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "$function_name" "GitHub issue command successful"
        fi
    else
        exit_code=$?
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "$function_name" "GitHub issue command failed: $result"
        fi
    fi
    
    # Log timing information
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "$function_name" "$start_time" "github_api"
    fi
    
    # Output result and return exit code
    echo "$result"
    return $exit_code
}

# Wrapper for GitHub CLI project commands with performance monitoring
gh_project_call() {
    local project_command="$1"
    local function_name="${2:-gh_project_call}"
    shift 2
    local gh_args=("$@")
    
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "$function_name" "GitHub project command: $project_command"
        if [ "$DEBUG_MODE" = "true" ]; then
            log_debug "$function_name" "Full command: gh project $project_command ${gh_args[*]}"
        fi
    fi
    
    # Execute the GitHub CLI command
    local result exit_code
    if result=$(gh project "$project_command" "${gh_args[@]}" 2>&1); then
        exit_code=0
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "$function_name" "GitHub project command successful"
        fi
    else
        exit_code=$?
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "$function_name" "GitHub project command failed: $result"
        fi
    fi
    
    # Log timing information
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "$function_name" "$start_time" "github_api"
    fi
    
    # Output result and return exit code
    echo "$result"
    return $exit_code
}

# === DEBUG AND VERBOSE MODE UTILITIES ===

# Enable debug mode
enable_debug_mode() {
    export DEBUG_MODE="true"
    export ENABLE_LOGGING="true"
    export LOG_LEVEL="DEBUG"
    export VERBOSE_MODE="true"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "enable_debug_mode" "Debug mode enabled - verbose logging activated"
    fi
    
    echo "Debug mode enabled - detailed logging and verbose output activated"
}

# Enable verbose mode
enable_verbose_mode() {
    export VERBOSE_MODE="true"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "enable_verbose_mode" "Verbose mode enabled"
    fi
    
    echo "Verbose mode enabled - detailed output activated"
}

# Enable performance monitoring
enable_performance_monitoring() {
    export PERFORMANCE_MONITORING="true"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "enable_performance_monitoring" "Performance monitoring enabled"
    fi
    
    echo "Performance monitoring enabled - slow operations will be logged"
}

# Debug helper function to dump current configuration
dump_debug_config() {
    if [ "$DEBUG_MODE" = "true" ] || [ "$VERBOSE_MODE" = "true" ]; then
        echo "=== DEBUG CONFIGURATION DUMP ==="
        echo "DEBUG_MODE: $DEBUG_MODE"
        echo "VERBOSE_MODE: $VERBOSE_MODE"
        echo "ENABLE_LOGGING: $ENABLE_LOGGING"
        echo "LOG_LEVEL: $LOG_LEVEL"
        echo "LOG_FILE: $LOG_FILE"
        echo "LOG_ROTATION_SIZE: $LOG_ROTATION_SIZE"
        echo "LOG_ROTATION_COUNT: $LOG_ROTATION_COUNT"
        echo "PERFORMANCE_MONITORING: $PERFORMANCE_MONITORING"
        echo "PROJECT_URL: ${PROJECT_URL:-'not set'}"
        echo "REPO_OWNER: ${REPO_OWNER:-'not set'}"
        echo "REPO_NAME: ${REPO_NAME:-'not set'}"
        echo "DEFAULT_BRANCH: ${DEFAULT_BRANCH:-'not set'}"
        echo "================================="
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "dump_debug_config" "Configuration dump completed"
    fi
}

# Parse command line arguments for debug/verbose flags
parse_debug_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug|-d)
                enable_debug_mode
                shift
                ;;
            --verbose|-v)
                enable_verbose_mode
                shift
                ;;
            --performance|-p)
                enable_performance_monitoring
                shift
                ;;
            --log-level)
                if [ -n "$2" ]; then
                    update_config "LOG_LEVEL" "$2"
                    shift 2
                else
                    echo "Error: --log-level requires a value (DEBUG, INFO, WARN, ERROR)" >&2
                    return 1
                fi
                ;;
            --log-file)
                if [ -n "$2" ]; then
                    export LOG_FILE="$2"
                    shift 2
                else
                    echo "Error: --log-file requires a path" >&2
                    return 1
                fi
                ;;
            *)
                # Return remaining arguments
                break
                ;;
        esac
    done
    
    # Return remaining arguments
    return 0
}

# === CONFIGURATION LOADING ===

# Load configuration from .env files and environment variables
load_config() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    # Initialize default values
    export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    export PROJECT_URL="${PROJECT_URL:-}"
    export ENABLE_LOGGING="${ENABLE_LOGGING:-false}"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export LOG_FILE="${LOG_FILE:-./logs/gh-issue-manager.log}"
    export DEBUG_MODE="${DEBUG_MODE:-false}"
    export VERBOSE_MODE="${VERBOSE_MODE:-false}"
    export LOG_ROTATION_SIZE="${LOG_ROTATION_SIZE:-10485760}"
    export LOG_ROTATION_COUNT="${LOG_ROTATION_COUNT:-5}"
    export PERFORMANCE_MONITORING="${PERFORMANCE_MONITORING:-false}"
    
    # Load from .env file if it exists
    if [ -f ".env" ]; then
        # Source .env file while ignoring comments and empty lines
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi
            
            # Export valid environment variable assignments
            if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                export "$line"
            fi
        done < ".env"
        
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_info "load_config" "Configuration loaded from .env file"
        fi
    else
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_warn "load_config" ".env file not found, using defaults"
        fi
    fi
    
    # Load from .env.local if it exists (for local overrides)
    if [ -f ".env.local" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi
            
            if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                export "$line"
            fi
        done < ".env.local"
        
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_info "load_config" "Local configuration loaded from .env.local file"
        fi
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "load_config" "$start_time"
    fi
    
    return 0
}

# === ENVIRONMENT VALIDATION ===

# Validate environment and check required tools
validate_environment() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    local validation_errors=()
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "validate_environment" "Starting environment validation"
    fi
    
    # Check for required tools
    if ! command -v gh >/dev/null 2>&1; then
        validation_errors+=("GitHub CLI (gh) is not installed or not in PATH")
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "validate_environment" "GitHub CLI not found"
        fi
    else
        # Check if GitHub CLI is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            validation_errors+=("GitHub CLI is not authenticated (run 'gh auth login')")
            if [ "$ENABLE_LOGGING" = "true" ]; then
                log_warn "validate_environment" "GitHub CLI not authenticated"
            fi
        else
            if [ "$ENABLE_LOGGING" = "true" ]; then
                local gh_user
                gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
                log_debug "validate_environment" "GitHub CLI authenticated as user: $gh_user"
            fi
        fi
        
        # Verify GitHub CLI version compatibility
        local gh_version
        gh_version=$(gh --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "validate_environment" "GitHub CLI version: $gh_version"
        fi
    fi
    
    # Check for jq (used for JSON processing)
    if ! command -v jq >/dev/null 2>&1; then
        validation_errors+=("jq is not installed or not in PATH")
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "validate_environment" "jq not found"
        fi
    else
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "validate_environment" "jq found: $(jq --version)"
        fi
    fi
    
    # Validate LOG_LEVEL if logging is enabled
    if [ "$ENABLE_LOGGING" = "true" ]; then
        case "$LOG_LEVEL" in
            "DEBUG"|"INFO"|"WARN"|"ERROR")
                log_debug "validate_environment" "Log level '$LOG_LEVEL' is valid"
                ;;
            *)
                validation_errors+=("Invalid LOG_LEVEL '$LOG_LEVEL'. Must be DEBUG, INFO, WARN, or ERROR")
                ;;
        esac
    fi
    
    # Validate PROJECT_URL format if provided
    if [ -n "$PROJECT_URL" ]; then
        if [[ ! "$PROJECT_URL" =~ ^https://github\.com/(orgs|users)/.+/projects/[0-9]+$ ]]; then
            validation_errors+=("Invalid PROJECT_URL format. Expected: https://github.com/orgs/ORG/projects/N or https://github.com/users/USER/projects/N")
            if [ "$ENABLE_LOGGING" = "true" ]; then
                log_warn "validate_environment" "Invalid PROJECT_URL format: $PROJECT_URL"
            fi
        else
            if [ "$ENABLE_LOGGING" = "true" ]; then
                log_debug "validate_environment" "PROJECT_URL format is valid"
            fi
        fi
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        validation_errors+=("Not in a git repository")
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "validate_environment" "Not in a git repository"
        fi
    else
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_debug "validate_environment" "Git repository detected"
        fi
    fi
    
    # Report validation results
    if [ ${#validation_errors[@]} -gt 0 ]; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "validate_environment" "Environment validation failed with ${#validation_errors[@]} errors"
            for error in "${validation_errors[@]}"; do
                log_error "validate_environment" "Validation error: $error"
            done
        fi
        
        # Print errors to stderr for user visibility
        echo "Environment validation failed:" >&2
        printf ' - %s\n' "${validation_errors[@]}" >&2
        return 1
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "validate_environment" "Environment validation successful"
        if [ -n "$start_time" ]; then
            log_timing "validate_environment" "$start_time"
        fi
    fi
    
    return 0
}

# === LOGGING SETUP ===

# Setup logging system (integrates with existing logging from gh-issue-manager.sh)
setup_logging() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    # Initialize logging system using the integrated log_init function
    if ! log_init; then
        return 1
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "setup_logging" "GitHub Wizard logging system initialized"
        if [ -n "$start_time" ]; then
            log_timing "setup_logging" "$start_time"
        fi
    fi
    
    return 0
}

# === CONFIGURATION UTILITIES ===

# Get project URL with validation
get_project_url() {
    if [ -n "$PROJECT_URL" ]; then
        echo "$PROJECT_URL"
        return 0
    else
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_warn "get_project_url" "PROJECT_URL not configured"
        fi
        return 1
    fi
}

# Update configuration at runtime
update_config() {
    local key="$1"
    local value="$2"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "update_config" "Key and value are required"
        fi
        return 1
    fi
    
    case "$key" in
        "LOG_LEVEL")
            case "$value" in
                "DEBUG"|"INFO"|"WARN"|"ERROR")
                    export LOG_LEVEL="$value"
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_info "update_config" "Log level updated to: $value"
                    fi
                    ;;
                *)
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_error "update_config" "Invalid log level: $value"
                    fi
                    return 1
                    ;;
            esac
            ;;
        "ENABLE_LOGGING")
            case "$value" in
                "true"|"false")
                    export ENABLE_LOGGING="$value"
                    if [ "$value" = "true" ]; then
                        if setup_logging; then
                            log_info "update_config" "Logging enabled"
                        fi
                    fi
                    ;;
                *)
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_error "update_config" "Invalid logging setting: $value"
                    fi
                    return 1
                    ;;
            esac
            ;;
        "PROJECT_URL")
            if [[ "$value" =~ ^https://github\.com/(orgs|users)/.+/projects/[0-9]+$ ]]; then
                export PROJECT_URL="$value"
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_info "update_config" "Project URL updated to: $value"
                fi
            else
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_error "update_config" "Invalid PROJECT_URL format: $value"
                fi
                return 1
            fi
            ;;
        "DEBUG_MODE")
            case "$value" in
                "true"|"false")
                    export DEBUG_MODE="$value"
                    if [ "$value" = "true" ]; then
                        enable_debug_mode
                    fi
                    ;;
                *)
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_error "update_config" "Invalid debug mode setting: $value"
                    fi
                    return 1
                    ;;
            esac
            ;;
        "VERBOSE_MODE")
            case "$value" in
                "true"|"false")
                    export VERBOSE_MODE="$value"
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_info "update_config" "Verbose mode set to: $value"
                    fi
                    ;;
                *)
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_error "update_config" "Invalid verbose mode setting: $value"
                    fi
                    return 1
                    ;;
            esac
            ;;
        "PERFORMANCE_MONITORING")
            case "$value" in
                "true"|"false")
                    export PERFORMANCE_MONITORING="$value"
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_info "update_config" "Performance monitoring set to: $value"
                    fi
                    ;;
                *)
                    if [ "$ENABLE_LOGGING" = "true" ]; then
                        log_error "update_config" "Invalid performance monitoring setting: $value"
                    fi
                    return 1
                    ;;
            esac
            ;;
        "LOG_ROTATION_SIZE")
            if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
                export LOG_ROTATION_SIZE="$value"
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_info "update_config" "Log rotation size set to: $value bytes"
                fi
            else
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_error "update_config" "Invalid log rotation size: $value (must be positive integer)"
                fi
                return 1
            fi
            ;;
        "LOG_ROTATION_COUNT")
            if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
                export LOG_ROTATION_COUNT="$value"
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_info "update_config" "Log rotation count set to: $value"
                fi
            else
                if [ "$ENABLE_LOGGING" = "true" ]; then
                    log_error "update_config" "Invalid log rotation count: $value (must be positive integer)"
                fi
                return 1
            fi
            ;;
        *)
            if [ "$ENABLE_LOGGING" = "true" ]; then
                log_error "update_config" "Unknown configuration key: $key"
            fi
            return 1
            ;;
    esac
    
    return 0
}

# === GITHUB CLI INTEGRATION ===

# Check GitHub CLI authentication and permissions
check_gh_auth() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "check_gh_auth" "Checking GitHub CLI authentication"
    fi
    
    # Check if gh CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "check_gh_auth" "GitHub CLI not found"
        fi
        return 1
    fi
    
    # Check authentication status
    if ! gh auth status >/dev/null 2>&1; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "check_gh_auth" "GitHub CLI not authenticated"
        fi
        echo "GitHub CLI is not authenticated. Please run 'gh auth login' first." >&2
        return 1
    fi
    
    # Get authenticated user info
    local gh_user gh_scopes
    gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    gh_scopes=$(gh auth status 2>&1 | grep -o 'Token scopes:.*' | cut -d: -f2 | tr -d ' ' || echo "unknown")
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "check_gh_auth" "Authenticated as user: $gh_user"
        log_debug "check_gh_auth" "Token scopes: $gh_scopes"
        if [ -n "$start_time" ]; then
            log_timing "check_gh_auth" "$start_time"
        fi
    fi
    
    return 0
}

# Get current repository context
get_repo_context() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "get_repo_context" "Getting repository context"
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "get_repo_context" "Not in a git repository"
        fi
        return 1
    fi
    
    # Get repository information using GitHub CLI
    local repo_info
    if repo_info=$(gh repo view --json owner,name,defaultBranchRef 2>/dev/null); then
        export REPO_OWNER=$(echo "$repo_info" | jq -r '.owner.login' 2>/dev/null || echo "")
        export REPO_NAME=$(echo "$repo_info" | jq -r '.name' 2>/dev/null || echo "")
        export DEFAULT_BRANCH=$(echo "$repo_info" | jq -r '.defaultBranchRef.name' 2>/dev/null || echo "main")
        
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_info "get_repo_context" "Repository: $REPO_OWNER/$REPO_NAME (default branch: $DEFAULT_BRANCH)"
            if [ -n "$start_time" ]; then
                log_timing "get_repo_context" "$start_time"
            fi
        fi
        return 0
    else
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "get_repo_context" "Failed to get repository information from GitHub"
        fi
        return 1
    fi
}

# Validate GitHub CLI prerequisites for wizard operations
validate_gh_prerequisites() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "validate_gh_prerequisites" "Validating GitHub CLI prerequisites"
    fi
    
    local validation_errors=()
    
    # Check authentication
    if ! check_gh_auth >/dev/null 2>&1; then
        validation_errors+=("GitHub CLI authentication required")
    fi
    
    # Check repository context
    if ! get_repo_context >/dev/null 2>&1; then
        validation_errors+=("Must be run from within a GitHub repository")
    fi
    
    # Check required permissions by testing API access
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        # Test repository read access
        if ! gh api "repos/$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1; then
            validation_errors+=("Insufficient permissions to access repository")
        fi
        
        # Test issues access
        if ! gh api "repos/$REPO_OWNER/$REPO_NAME/issues?per_page=1" >/dev/null 2>&1; then
            validation_errors+=("Insufficient permissions to access issues")
        fi
    fi
    
    # Report validation results
    if [ ${#validation_errors[@]} -gt 0 ]; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_error "validate_gh_prerequisites" "GitHub prerequisites validation failed"
            for error in "${validation_errors[@]}"; do
                log_error "validate_gh_prerequisites" "Error: $error"
            done
        fi
        
        echo "GitHub CLI prerequisites validation failed:" >&2
        printf ' - %s\n' "${validation_errors[@]}" >&2
        return 1
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "validate_gh_prerequisites" "GitHub CLI prerequisites validation successful"
        if [ -n "$start_time" ]; then
            log_timing "validate_gh_prerequisites" "$start_time"
        fi
    fi
    
    return 0
}

# === CONFIGURATION VALIDATION HELPERS ===

# Check if configuration is complete for wizard operations
validate_wizard_config() {
    local warnings=()
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_debug "validate_wizard_config" "Validating wizard-specific configuration"
    fi
    
    # Check if PROJECT_URL is configured (optional but recommended)
    if [ -z "$PROJECT_URL" ]; then
        warnings+=("PROJECT_URL not configured - project board features will be unavailable")
    fi
    
    # Check GitHub CLI authentication
    if ! check_gh_auth >/dev/null 2>&1; then
        warnings+=("GitHub CLI not authenticated - run 'gh auth login' to enable full functionality")
    fi
    
    # Check repository context
    if ! get_repo_context >/dev/null 2>&1; then
        warnings+=("Not in a GitHub repository - some features will be unavailable")
    fi
    
    # Check if GitHub token is available (for enhanced operations)
    if [ -z "$GITHUB_TOKEN" ]; then
        # Check if gh CLI has a token
        if ! gh auth token >/dev/null 2>&1; then
            warnings+=("No GitHub token available - some operations may be limited")
        fi
    fi
    
    # Report warnings
    if [ ${#warnings[@]} -gt 0 ]; then
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_warn "validate_wizard_config" "Configuration warnings found"
            for warning in "${warnings[@]}"; do
                log_warn "validate_wizard_config" "Warning: $warning"
            done
        fi
        
        # Print warnings to stderr for user visibility
        echo "Configuration warnings:" >&2
        printf ' - %s\n' "${warnings[@]}" >&2
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "validate_wizard_config" "Wizard configuration validation complete"
    fi
    
    return 0
}

# === ERROR HANDLING ===

# Handle configuration errors with user guidance
handle_config_error() {
    local error_type="$1"
    local error_message="$2"
    
    case "$error_type" in
        "missing_env")
            echo "Configuration Error: $error_message" >&2
            echo "To fix this:" >&2
            echo " 1. Copy .env.example to .env" >&2
            echo " 2. Edit .env with your configuration" >&2
            echo " 3. Run the wizard again" >&2
            ;;
        "invalid_format")
            echo "Configuration Error: $error_message" >&2
            echo "Please check your .env file format and try again." >&2
            ;;
        "permission_denied")
            echo "Configuration Error: $error_message" >&2
            echo "Please check file permissions and try again." >&2
            ;;
        *)
            echo "Configuration Error: $error_message" >&2
            ;;
    esac
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_error "handle_config_error" "$error_type: $error_message"
    fi
    
    return 1
}