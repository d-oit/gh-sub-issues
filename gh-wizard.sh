#!/bin/bash

# GitHub Issue Manager Wizard
# Interactive command-line interface for managing GitHub issues, releases, and project workflows

set -euo pipefail

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === DEPENDENCY VALIDATION ===

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("GitHub CLI (gh)")
    fi
    
    # Check for jq (used for JSON processing)
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies:" >&2
        printf ' - %s\n' "${missing_deps[@]}" >&2
        echo >&2
        echo "Installation instructions:" >&2
        echo " - GitHub CLI: https://cli.github.com/" >&2
        echo " - jq: https://stedolan.github.io/jq/download/" >&2
        echo " - git: https://git-scm.com/downloads" >&2
        return 1
    fi
    
    return 0
}

# Validate module files exist
validate_modules() {
    local missing_modules=()
    local required_modules=(
        "lib/wizard-config.sh"
        "lib/wizard-display.sh" 
        "lib/wizard-core.sh"
        "lib/wizard-github.sh"
    )
    
    for module in "${required_modules[@]}"; do
        if [ ! -f "${SCRIPT_DIR}/${module}" ]; then
            missing_modules+=("$module")
        fi
    done
    
    if [ ${#missing_modules[@]} -gt 0 ]; then
        echo "Error: Missing required module files:" >&2
        printf ' - %s\n' "${missing_modules[@]}" >&2
        echo >&2
        echo "Please ensure all wizard modules are present in the lib/ directory." >&2
        return 1
    fi
    
    return 0
}

# === MODULE LOADING ===

# Load modules with error handling
load_modules() {
    local modules=(
        "lib/wizard-config.sh"
        "lib/wizard-display.sh"
        "lib/wizard-core.sh"
        "lib/wizard-github.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="${SCRIPT_DIR}/${module}"
        if [ -f "$module_path" ]; then
            # shellcheck source=/dev/null
            if ! source "$module_path"; then
                echo "Error: Failed to load module: $module" >&2
                return 1
            fi
        else
            echo "Error: Module not found: $module" >&2
            return 1
        fi
    done
    
    return 0
}

# === INITIALIZATION ===

# Initialize wizard environment
initialize_wizard() {
    # Load configuration first
    if ! load_config; then
        echo "Error: Failed to load configuration" >&2
        return 1
    fi
    
    # Setup logging system
    if ! setup_logging; then
        echo "Warning: Failed to setup logging system" >&2
        # Continue without logging
    fi
    
    # Validate environment
    if ! validate_environment; then
        echo "Error: Environment validation failed" >&2
        echo "Please resolve the above issues and try again." >&2
        return 1
    fi
    
    # Validate wizard-specific configuration
    validate_wizard_config
    
    # Initialize cross-module state management
    init_cross_module_state
    
    # Initialize core module logging if available
    if command -v init_core_logging >/dev/null 2>&1; then
        init_core_logging
    fi
    
    return 0
}

# Initialize cross-module state management
init_cross_module_state() {
    # Export shared variables for cross-module communication
    export WIZARD_SESSION_ID="wizard_$(date +%s)"
    export WIZARD_START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Initialize shared state variables
    export CURRENT_WORKFLOW=""
    export WORKFLOW_CONTEXT=""
    export LAST_OPERATION=""
    export OPERATION_RESULT=""
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "init_cross_module_state" "Cross-module state initialized (Session: $WIZARD_SESSION_ID)"
    fi
}

# === COMMAND LINE ARGUMENT PARSING ===

# Show usage information
show_usage() {
    echo "GitHub Issue Manager Wizard"
    echo "Interactive command-line interface for managing GitHub issues, releases, and project workflows"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --debug              Enable debug mode (verbose logging and output)"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -p, --performance        Enable performance monitoring"
    echo "  --log-level LEVEL        Set log level (DEBUG, INFO, WARN, ERROR)"
    echo "  --log-file PATH          Set log file path"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ENABLE_LOGGING           Enable logging (true/false)"
    echo "  LOG_LEVEL               Log level (DEBUG/INFO/WARN/ERROR)"
    echo "  LOG_FILE                Log file path"
    echo "  DEBUG_MODE              Enable debug mode (true/false)"
    echo "  VERBOSE_MODE            Enable verbose mode (true/false)"
    echo "  PERFORMANCE_MONITORING  Enable performance monitoring (true/false)"
    echo "  PROJECT_URL             GitHub project URL for auto-assignment"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run wizard with default settings"
    echo "  $0 --debug              # Run with debug mode enabled"
    echo "  $0 --verbose --performance  # Run with verbose output and performance monitoring"
    echo "  $0 --log-level DEBUG --log-file ./debug.log  # Custom logging configuration"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--debug)
                enable_debug_mode
                shift
                ;;
            -v|--verbose)
                enable_verbose_mode
                shift
                ;;
            -p|--performance)
                enable_performance_monitoring
                shift
                ;;
            --log-level)
                if [ -n "$2" ]; then
                    export LOG_LEVEL="$2"
                    shift 2
                else
                    echo "Error: --log-level requires a value (DEBUG, INFO, WARN, ERROR)" >&2
                    exit 1
                fi
                ;;
            --log-file)
                if [ -n "$2" ]; then
                    export LOG_FILE="$2"
                    shift 2
                else
                    echo "Error: --log-file requires a path" >&2
                    exit 1
                fi
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# === MAIN FUNCTION ===

# Main function
main() {
    # Handle help option first (before dependency checks)
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi
    
    # Validate and load modules
    if ! validate_modules; then
        exit 1
    fi
    
    if ! load_modules; then
        exit 1
    fi
    
    # Parse command line arguments after loading modules (so debug functions are available)
    parse_arguments "$@"
    
    # Initialize wizard environment
    if ! initialize_wizard; then
        exit 1
    fi
    
    # Display debug configuration if debug mode is enabled
    if [ "$DEBUG_MODE" = "true" ] || [ "$VERBOSE_MODE" = "true" ]; then
        dump_debug_config
        echo
    fi
    
    # Display welcome header
    clear_screen
    print_header "GitHub Issue Manager Wizard"
    
    # Check GitHub CLI authentication
    if ! check_gh_auth; then
        print_error "GitHub CLI authentication required"
        print_info "Please run 'gh auth login' to authenticate with GitHub"
        echo
        print_info "After authentication, run this wizard again"
        exit 1
    fi
    
    # Get repository context for better user experience
    if get_repo_context >/dev/null 2>&1; then
        print_success "Repository detected: ${REPO_OWNER}/${REPO_NAME}"
        
        # Log successful repository detection
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_info "main" "Repository context established: ${REPO_OWNER}/${REPO_NAME}"
        fi
    else
        print_warning "Not in a GitHub repository" "Some features may be limited"
        
        # Log repository detection failure
        if [ "$ENABLE_LOGGING" = "true" ]; then
            log_warn "main" "No repository context available - running in limited mode"
        fi
    fi
    
    # Initialize wizard core
    init_wizard_core
    
    # Log wizard startup
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "main" "GitHub Wizard started successfully (Session: $WIZARD_SESSION_ID)"
    fi
    
    # Start main menu loop
    show_main_menu
}

# === ERROR HANDLING ===

# Handle errors with user guidance
handle_error() {
    local error_type="$1"
    local error_message="$2"
    
    case "$error_type" in
        "dependency")
            print_error "Missing Dependency" "$error_message"
            echo "Please install the missing dependency and try again."
            ;;
        "auth")
            print_error "Authentication Error" "$error_message"
            echo "Please run 'gh auth login' to authenticate with GitHub."
            ;;
        "network")
            print_error "Network Error" "$error_message"
            echo "Please check your internet connection and try again."
            ;;
        "permission")
            print_error "Permission Error" "$error_message"
            echo "Please check your GitHub permissions and try again."
            ;;
        *)
            print_error "Error" "$error_message"
            ;;
    esac
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_error "handle_error" "$error_type: $error_message"
    fi
}

# === CLEANUP ===

# Cleanup function
cleanup() {
    print_info "Exiting GitHub Wizard..."
    
    # Cleanup wizard core if it was initialized
    if command -v cleanup_wizard_core >/dev/null 2>&1; then
        cleanup_wizard_core
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "main" "GitHub Wizard session ended"
    fi
    
    exit 0
}

# Cleanup on error
cleanup_on_error() {
    local exit_code=$?
    print_error "An unexpected error occurred (exit code: $exit_code)"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_error "main" "Wizard terminated with error code: $exit_code"
    fi
    
    cleanup
}

# === SIGNAL HANDLERS ===

# Set up signal handlers
trap cleanup SIGINT SIGTERM
trap cleanup_on_error ERR

# === ENTRY POINT ===

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi