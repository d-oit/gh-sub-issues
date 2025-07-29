#!/bin/bash
set -x
set -euo pipefail
IFS=

# --- MCP Validation Header ---
# [MCP:REQUIRED] shellcheck validation
# [MCP:REQUIRED] POSIX compliance check
# [MCP:RECOMMENDED] Error handling coverage

# === LOGGING SYSTEM ===

# Initialize logging system
log_init() {
    # Set default values if not provided
    ENABLE_LOGGING=${ENABLE_LOGGING:-false}
    LOG_LEVEL=${LOG_LEVEL:-INFO}
    LOG_FILE=${LOG_FILE:-./logs/gh-issue-manager.log}
    
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
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
    log_info "$function_name" "Execution time: ${duration}s"
}

# === ORIGINAL FUNCTIONS WITH LOGGING ===

validate_input() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "validate_input" "Starting input validation with $# arguments"
    
    for var in "$@"; do
        log_debug "validate_input" "Checking argument: '${var:0:50}...'"
        
        if [ -z "$var" ] || [[ "$var" =~ ^[[:space:]]*$ ]]; then
            log_error "validate_input" "Argument is empty or contains only whitespace"
            echo "Error: All arguments must be non-empty and contain non-whitespace characters" >&2
            return 1
        fi
    done
    
    log_info "validate_input" "Input validation successful"
    log_timing "validate_input" "$start_time"
}

check_dependencies() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "check_dependencies" "Checking required dependencies"
    
    local missing_deps=()
    
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh (GitHub CLI)")
        log_warn "check_dependencies" "GitHub CLI not found"
    else
        log_debug "check_dependencies" "GitHub CLI found: $(gh --version | head -1)"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
        log_warn "check_dependencies" "jq not found"
    else
        log_debug "check_dependencies" "jq found: $(jq --version)"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "check_dependencies" "Missing dependencies: ${missing_deps[*]}"
        echo "Error: Missing required dependencies:" >&2
        printf ' - %s\n' "${missing_deps[@]}" >&2
        return 1
    fi
    
    log_info "check_dependencies" "All dependencies satisfied"
    log_timing "check_dependencies" "$start_time"
}

load_environment() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "load_environment" "Loading environment configuration"
    
    if [ -f ".env" ]; then
        set -o allexport
        # shellcheck disable=SC1091
        source .env
        set +o allexport
        log_info "load_environment" "Loaded configuration from .env file"
        echo "Loaded configuration from .env file"
    else
        log_warn "load_environment" "No .env file found"
        echo "No .env file found, using current repo context"
    fi
    
    log_timing "load_environment" "$start_time"
}

get_repo_context() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "get_repo_context" "Getting repository context"
    
    if ! REPO_OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null); then
        log_error "get_repo_context" "Failed to get repository owner"
        echo "Error: Failed to get repository owner. Are you in a git repository with GitHub remote?" >&2
        return 1
    fi
    
    if [ -z "$REPO_OWNER" ]; then
        log_error "get_repo_context" "Repository owner is empty"
        echo "Error: Could not determine repository owner. The 'gh' command returned no output." >&2
        return 1
    fi
    
    if ! REPO_NAME=$(gh repo view --json name -q .name 2>/dev/null); then
        log_error "get_repo_context" "Failed to get repository name"
        echo "Error: Failed to get repository name. Are you in a git repository with GitHub remote?" >&2
        return 1
    fi
    
    if [ -z "$REPO_NAME" ]; then
        log_error "get_repo_context" "Repository name is empty"
        echo "Error: Could not determine repository name. The 'gh' command returned no output." >&2
        return 1
    fi
    
    log_info "get_repo_context" "Repository context: $REPO_OWNER/$REPO_NAME"
    echo "Repository context: $REPO_OWNER/$REPO_NAME"
    log_timing "get_repo_context" "$start_time"
}

create_issues() {
    local start_time
    start_time=$(date +%s.%N)
    local parent_title="$1"
    local parent_body="$2"
    local child_title="$3"
    local child_body="$4"

    log_info "create_issues" "Creating parent issue: '$parent_title'"
    log_debug "create_issues" "Parent body length: ${#parent_body} characters"

    local parent_output
    if ! parent_output=$(gh issue create --title "$parent_title" --body "$parent_body" 2>/dev/null); then
        log_error "create_issues" "Failed to create parent issue"
        echo "Error: Failed to create parent issue" >&2
        return 1
    fi
    if [ -z "$parent_output" ]; then
        log_error "create_issues" "Parent issue creation returned no output"
        echo "Error: Failed to get parent issue details from creation command." >&2
        return 1
    fi
    PARENT_ISSUE=$(echo "$parent_output" | awk -F'/' '{print $NF}')
    PARENT_ID="$(gh api graphql -f query='query{repository(owner:"'"$REPO_OWNER"'",name:"'"$REPO_NAME"'"){issue(number:'"$PARENT_ISSUE"'){id}}}' -q .data.repository.issue.id)"

    if [ -z "$PARENT_ISSUE" ] || [ "$PARENT_ISSUE" = "null" ]; then
        log_error "create_issues" "Failed to parse parent issue number"
        echo "Error: Could not parse parent issue number from output." >&2
        return 1
    fi
    log_info "create_issues" "Parent issue created: #$PARENT_ISSUE"

    log_info "create_issues" "Creating child issue: '$child_title'"
    log_debug "create_issues" "Child body length: ${#child_body} characters"

    local child_output
    if ! child_output=$(gh issue create --title "$child_title" --body "$child_body" 2>/dev/null); then
        log_error "create_issues" "Failed to create child issue"
        echo "Error: Failed to create child issue" >&2
        return 1
    fi
    if [ -z "$child_output" ]; then
        log_error "create_issues" "Child issue creation returned no output"
        echo "Error: Failed to get child issue details from creation command." >&2
        return 1
    fi
    CHILD_ISSUE=$(echo "$child_output" | awk -F'/' '{print $NF}')
    CHILD_ID="$(gh api graphql -f query='query{repository(owner:"'"$REPO_OWNER"'",name:"'"$REPO_NAME"'"){issue(number:'"$CHILD_ISSUE"'){id}}}' -q .data.repository.issue.id)"

    if [ -z "$CHILD_ISSUE" ] || [ "$CHILD_ISSUE" = "null" ]; then
        log_error "create_issues" "Failed to parse child issue number"
        echo "Error: Could not parse child issue number from output." >&2
        return 1
    fi
    log_info "create_issues" "Child issue created: #$CHILD_ISSUE"

    echo "Created issues: Parent #$PARENT_ISSUE, Child #$CHILD_ISSUE"
    log_timing "create_issues" "$start_time"
}

link_sub_issue() {
    local start_time=$(date +%s.%N)
    log_info "link_sub_issue" "Linking child issue #$CHILD_ISSUE to parent #$PARENT_ISSUE"
    log_debug "link_sub_issue" "Parent ID: $PARENT_ID, Child ID: $CHILD_ID"
    
    # Link child to parent using GraphQL
    if ! gh api graphql \
        -H "GraphQL-Features: sub_issues" \
        -f query="
mutation {
  addSubIssue(input: {issueId: \"$PARENT_ID\", subIssueId: \"$CHILD_ID\"}) {
    clientMutationId
  }
}" >/dev/null 2>&1; then
        log_warn "link_sub_issue" "Failed to create sub-issue relationship"
        echo "Warning: Failed to create sub-issue relationship. Feature may not be available."
    else
        log_info "link_sub_issue" "Successfully linked child #$CHILD_ISSUE to parent #$PARENT_ISSUE"
        echo "Linked child issue #$CHILD_ISSUE to parent #$PARENT_ISSUE"
    fi
    
    log_timing "link_sub_issue" "$start_time"
}

add_to_project() {
    local start_time=$(date +%s.%N)
    log_debug "add_to_project" "PROJECT_URL: ${PROJECT_URL:-'not set'}"
    
    if [ -n "${PROJECT_URL:-}" ]; then
        echo "Adding issues to project: $PROJECT_URL"
        log_info "add_to_project" "Adding issues to project: $PROJECT_URL"
        
        # Extract project number from URL
        PROJECT_NUMBER=$(echo "$PROJECT_URL" | sed 's/.*\/projects\///')
        log_debug "add_to_project" "Project number: $PROJECT_NUMBER"
        
        # Add parent issue to project using URL format
        PARENT_ISSUE_URL="https://github.com/$REPO_OWNER/$REPO_NAME/issues/$PARENT_ISSUE"
        log_debug "add_to_project" "Adding parent issue: $PARENT_ISSUE_URL"
        
        if ! gh project item-add "$PROJECT_NUMBER" --owner "$REPO_OWNER" --url "$PARENT_ISSUE_URL" 2>/dev/null; then
            log_warn "add_to_project" "Failed to add parent issue #$PARENT_ISSUE to project"
            echo "Warning: Failed to add parent issue to project board"
        else
            log_info "add_to_project" "Added parent issue #$PARENT_ISSUE to project"
            echo "✅ Added parent issue #$PARENT_ISSUE to project"
        fi
        
        # Add child issue to project using URL format
        CHILD_ISSUE_URL="https://github.com/$REPO_OWNER/$REPO_NAME/issues/$CHILD_ISSUE"
        log_debug "add_to_project" "Adding child issue: $CHILD_ISSUE_URL"
        
        if ! gh project item-add "$PROJECT_NUMBER" --owner "$REPO_OWNER" --url "$CHILD_ISSUE_URL" 2>/dev/null; then
            log_warn "add_to_project" "Failed to add child issue #$CHILD_ISSUE to project"
            echo "Warning: Failed to add child issue to project board"
        else
            log_info "add_to_project" "Added child issue #$CHILD_ISSUE to project"
            echo "✅ Added child issue #$CHILD_ISSUE to project"
        fi
    else
        log_info "add_to_project" "No PROJECT_URL configured, skipping project board assignment"
        echo "No PROJECT_URL configured, skipping project board assignment"
    fi
    
    log_timing "add_to_project" "$start_time"
}

# Function to update a GitHub issue
update_issue() {
    local start_time=$(date +%s.%N)
    log_debug "update_issue" "Updating issue #$1..."

    local issue_number="$1"
    local update_args=()

    shift # Remove issue_number from arguments

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                update_args+=(--title "$2")
                log_debug "update_issue" "Setting title to: $2"
                shift 2
                ;;
            --body)
                update_args+=(--body "$2")
                log_debug "update_issue" "Setting body to: $2"
                shift 2
                ;;
            --state)
                update_args+=(--state "$2")
                log_debug "update_issue" "Setting state to: $2"
                shift 2
                ;;
            --add-label)
                update_args+=(--add-label "$2")
                log_debug "update_issue" "Adding label: $2"
                shift 2
                ;;
            --remove-label)
                update_args+=(--remove-label "$2")
                log_debug "update_issue" "Removing label: $2"
                shift 2
                ;;
            --milestone)
                update_args+=(--milestone "$2")
                log_debug "update_issue" "Setting milestone to: $2"
                shift 2
                ;;
            *)
                log_warn "update_issue" "Unknown or unsupported argument for update_issue: $1"
                shift
                ;;
        esac
    done

    if [ ${#update_args[@]} -eq 0 ]; then
        log_warn "update_issue" "No update arguments provided for issue #$issue_number."
        log_timing "update_issue" "$start_time"
        return 0
    fi

    log_info "update_issue" "Executing: gh issue edit $issue_number ${update_args[*]}"
    if ! gh issue edit "$issue_number" "${update_args[@]}"; then
        log_error "update_issue" "Failed to update issue #$issue_number."
        echo "Error: Failed to update issue #$issue_number." >&2
        log_timing "update_issue" "$start_time"
        return 1
    fi

    log_info "update_issue" "Successfully updated issue #$issue_number."
    echo "✅ Successfully updated issue #$issue_number."
    log_timing "update_issue" "$start_time"
}

# Function to process "Files to Create" in an issue body
process_files_to_create_in_issue() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "process_files_to_create_in_issue" "Processing files to create for issue #$1..."

    local issue_number="$1"
    local issue_body
    issue_body=$(gh issue view "$issue_number" --json body --jq .body)

    if [ -z "$issue_body" ]; then
        log_warn "process_files_to_create_in_issue" "Issue #$issue_number has no body or failed to fetch."
        log_timing "process_files_to_create_in_issue" "$start_time"
        return 0
    fi

    local files_to_create_section
    files_to_create_section=$(echo "$issue_body" | sed -n '/^Files to Create:/,/^$/p')

    if [ -z "$files_to_create_section" ]; then
        log_info "process_files_to_create_in_issue" "No 'Files to Create:' section found in issue #$issue_number body."
        log_timing "process_files_to_create_in_issue" "$start_time"
        return 0
    fi

    local new_body="$issue_body"
    local files_modified=false

    # Extract filenames, skipping the header line
    echo "$files_to_create_section" | tail -n +2 | while IFS= read -r line;
    do
        local filename
        filename=$(echo "$line" | sed -e 's/^[[:space:]]*- //' -e 's/^[[:space:]]*//')

        if [ -z "$filename" ]; then
            continue
        fi

        if [ -f "$filename" ]; then
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local dirname
            dirname=$(dirname "$filename")
            local basename
            basename=$(basename "$filename")
            local name_part="${basename%.*}"
            local extension_part="${basename##*.}"

            local new_filename
            if [ "$name_part" != "$basename" ]; then # Has an extension
                new_filename="${dirname}/${name_part}_${timestamp}.${extension_part}"
            else
                new_filename="${dirname}/${basename}_${timestamp}"
            fi

            log_warn "process_files_to_create_in_issue" "File '$filename' already exists. Proposing new name: '$new_filename'."
            new_body=${new_body//"$filename"/"$new_filename"}
            files_modified=true
        fi
    done

    if [ "$files_modified" = true ]; then
        log_info "process_files_to_create_in_issue" "Updating issue #$issue_number body with new file names."
        if ! update_issue "$issue_number" --body "$new_body"; then
            log_error "process_files_to_create_in_issue" "Failed to update issue body for #$issue_number."
            return 1
        fi
    else
        log_info "process_files_to_create_in_issue" "No existing files found for issue #$issue_number. No update needed."
    fi

    log_timing "process_files_to_create_in_issue" "$start_time"
}

main() {
    local start_time
    start_time=$(date +%s.%N)

    log_init
    log_info "main" "GitHub Issue Manager started"

    local MODE="CREATE"
    local issue_number=""
    local update_args=()
    local PROCESS_FILES_MODE=false

    if [[ "$1" == "--update" ]]; then
        MODE="UPDATE"
        shift
        if [ -z "$1" ]; then
            log_error "main" "Missing issue number for --update."
            echo "Error: Missing issue number for --update." >&2
            show_usage
            exit 1
        fi
        issue_number="$1"
        shift
        update_args=("$@")
    elif [[ "$1" == "--process-files" ]]; then
        PROCESS_FILES_MODE=true
        shift
        if [ -z "$1" ]; then
            log_error "main" "Missing issue number for --process-files."
            echo "Error: Missing issue number for --process-files." >&2
            show_usage
            exit 1
        fi
        issue_number="$1"
        shift
    fi

    if ! check_dependencies; then exit 1; fi
    load_environment
    if ! get_repo_context; then exit 1; fi

    if [ "$MODE" == "CREATE" ]; then
        if [ $# -ne 4 ]; then
            log_error "main" "Invalid argument count for create mode: expected 4, got $#"
            echo "Error: Invalid argument count for create mode." >&2
            show_usage
            exit 1
        fi
        local parent_title="$1"
        local parent_body="$2"
        local child_title="$3"
        local child_body="$4"

        if ! validate_input "$parent_title" "$parent_body" "$child_title" "$child_body"; then exit 1; fi

        if ! create_issues "$parent_title" "$parent_body" "$child_title" "$child_body"; then 
            exit 1
        fi

        link_sub_issue
        add_to_project

        log_info "main" "Successfully completed: Parent #$PARENT_ISSUE, Child #$CHILD_ISSUE"
        echo "✅ Successfully created parent issue #$PARENT_ISSUE and child issue #$CHILD_ISSUE"
    elif [ "$MODE" == "UPDATE" ]; then
        if ! validate_input "$issue_number" "${update_args[@]}"; then exit 1; fi
        if ! update_issue "$issue_number" "${update_args[@]}"; then
            exit 1
        fi
    elif [ "$PROCESS_FILES_MODE" = true ]; then
        if ! validate_input "$issue_number"; then exit 1; fi
        if ! process_files_to_create_in_issue "$issue_number"; then
            exit 1
        fi
    else
        log_error "main" "Invalid mode or arguments provided."
        show_usage
        exit 1
    fi

    log_timing "main" "$start_time"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi