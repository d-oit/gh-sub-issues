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

# Function to get the latest GitHub release version
get_latest_github_release() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "get_latest_github_release" "Attempting to fetch latest GitHub release..."

    local latest_release
    if ! latest_release=$(gh release view --json tagName --jq .tagName 2>/dev/null); then
        log_warn "get_latest_github_release" "No existing GitHub releases found. Starting from v0.0.0."
        echo "v0.0.0"
        log_timing "get_latest_github_release" "$start_time"
        return 0
    fi

    log_info "get_latest_github_release" "Latest GitHub release: $latest_release"
    echo "$latest_release"
    log_timing "get_latest_github_release" "$start_time"
}

# Function to calculate the next version based on semver rules
calculate_next_version() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "calculate_next_version" "Calculating next version..."

    local current_version="$1"
    local major=0
    local minor=0
    local patch=0

    # Extract major, minor, patch from current_version (e.g., v1.2.3 or 1.2.3-alpha.1)
    if [[ "$current_version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(-.+)?$ ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        patch=${BASH_REMATCH[3]}
    else
        log_error "calculate_next_version" "Invalid version format: $current_version"
        exit 1
    fi

    case "$VERSION_BUMP" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            log_error "calculate_next_version" "Unknown version bump type: $VERSION_BUMP"
            exit 1
            ;;
    esac

    local next_version="v${major}.${minor}.${patch}"

    if [ "$PRE_RELEASE" = true ]; then
        next_version="${next_version}-${PRE_RELEASE_TAG}"
    fi

    log_info "calculate_next_version" "Next version: $next_version (from $current_version)"
    echo "$next_version"
    log_timing "calculate_next_version" "$start_time"
}

# Function to get the creation date of a GitHub release
get_release_date() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "get_release_date" "Fetching creation date for release: $1"

    local release_tag="$1"
    local release_date
    if ! release_date=$(gh release view "$release_tag" --json createdAt --jq .createdAt 2>/dev/null); then
        log_error "get_release_date" "Failed to get creation date for release $release_tag"
        echo ""
        log_timing "get_release_date" "$start_time"
        return 1
    fi

    # Format date to YYYY-MM-DDTHH:MM:SSZ for gh issue list --since
    release_date=$(date -d "$release_date" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    if [ -z "$release_date" ]; then
        log_error "get_release_date" "Failed to parse date for release $release_tag: $release_date"
        echo ""
        log_timing "get_release_date" "$start_time"
        return 1
    fi

    log_info "get_release_date" "Release $release_tag created at: $release_date"
    echo "$release_date"
    log_timing "get_release_date" "$start_time"
}

# Function to get closed issues since a given date
get_closed_issues_since_last_release() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "get_closed_issues_since_last_release" "Fetching closed issues since $1..."

    local since_date="$1"
    local issues_json
    if [ -z "$since_date" ]; then
        log_info "get_closed_issues_since_last_release" "No since_date provided. Fetching all closed issues."
        issues_json=$(gh issue list --state closed --json number,title,url,labels 2>/dev/null)
    else
        issues_json=$(gh issue list --state closed --since "$since_date" --json number,title,url,labels 2>/dev/null)
    fi

    if [ -z "$issues_json" ] || [ "$issues_json" = "[]" ]; then
        log_info "get_closed_issues_since_last_release" "No closed issues found since $since_date."
        echo ""
        log_timing "get_closed_issues_since_last_release" "$start_time"
        return 0
    fi

    local changelog_entries=""
    local issue_count=0
    while IFS= read -r issue;
    do
        local number
        number=$(echo "$issue" | jq -r '.number')
        local title
        title=$(echo "$issue" | jq -r '.title')
        local url
        url=$(echo "$issue" | jq -r '.url')
        local labels
        labels=$(echo "$issue" | jq -r '.labels[].name' | paste -s -d, -)

        # Filter out issues with 'skip-changelog' label
        if [[ "$labels" == *"skip-changelog"* ]]; then
            log_debug "get_closed_issues_since_last_release" "Skipping issue #$number (\"$title\") due to 'skip-changelog' label."
            continue
        fi

        changelog_entries+="- $title (#$number) [Link]($url)\n"
        issue_count=$((issue_count + 1))
    done < <(echo "$issues_json" | jq -c '.[]')

    log_info "get_closed_issues_since_last_release" "Found $issue_count issues for changelog."
    printf "%b" "$changelog_entries"
    log_timing "get_closed_issues_since_last_release" "$start_time"
}

# Main function to orchestrate the release process
main() {
    log_init
    parse_arguments "$@"
    
    local latest_release
    latest_release=$(get_latest_github_release)
    log_info "main" "Current latest release: $latest_release"

    local next_version
    next_version=$(calculate_next_version "$latest_release")
    log_info "main" "Calculated next version: $next_version"

    if [ "$DRY_RUN" = true ]; then
        log_info "main" "Dry run enabled. Next version would be: $next_version"
        echo "Dry run: Next version would be $next_version"
        
        local last_release_date=""
        if [ "$latest_release" != "v0.0.0" ]; then
            last_release_date=$(get_release_date "$latest_release")
        fi

        local changelog_notes
        changelog_notes=$(get_closed_issues_since_last_release "$last_release_date")
        if [ -n "$changelog_notes" ]; then
            printf "%b" "\nProposed Changelog Entries:\n---\n${changelog_notes}---\n"
        else
            printf "%b" "\nNo new changelog entries found.\n"
        fi

        exit 0
    fi

    local last_release_date=""
    if [ "$latest_release" != "v0.0.0" ]; then
        last_release_date=$(get_release_date "$latest_release")
    fi

    local changelog_notes
    changelog_notes=$(get_closed_issues_since_last_release "$last_release_date")

    update_changelog "$next_version" "$changelog_notes"
    update_readme_version "$next_version"

    check_open_issues_in_milestone "$next_version"

    create_github_release "$next_version" "$changelog_notes"
    close_fixed_issues

    log_info "main" "Release process completed for version $next_version."
    echo "Release process completed for version $next_version."

    # Further steps will be added here
}

# Function to create a GitHub release
create_github_release() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "create_github_release" "Creating GitHub release..."

    local next_version="$1"
    local changelog_notes="$2"
    local release_name="Release $next_version"
    local release_tag="$next_version"

    local gh_release_cmd=(
        gh release create "$release_tag"
        --title "$release_name"
        --notes "$changelog_notes"
        --draft
    )

    if [ "$PRE_RELEASE" = true ]; then
        gh_release_cmd+=(--prerelease)
    fi

    log_info "create_github_release" "Executing: ${gh_release_cmd[*]}"
    if ! "${gh_release_cmd[@]}"; then
        log_error "create_github_release" "Failed to create GitHub release $release_tag."
        exit 1
    fi

    log_info "create_github_release" "Successfully created draft GitHub release $release_tag."
    log_timing "create_github_release" "$start_time"
}

# Function to close issues marked as 'fixed-in-next-release'
close_fixed_issues() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "close_fixed_issues" "Attempting to close issues marked 'fixed-in-next-release'..."

    local issues_to_close_json
    issues_to_close_json=$(gh issue list --state open --label "fixed-in-next-release" --json number,title 2>/dev/null)

    if [ -z "$issues_to_close_json" ] || [ "$issues_to_close_json" = "[]" ]; then
        log_info "close_fixed_issues" "No open issues found with 'fixed-in-next-release' label."
        log_timing "close_fixed_issues" "$start_time"
        return 0
    fi

    log_info "close_fixed_issues" "Found issues to close: $(echo "$issues_to_close_json" | jq -r 'length')"

    while IFS= read -r issue;
    do
        local issue_number
    issue_number=$(echo "$issue" | jq -r '.number')
    local issue_title
    issue_title=$(echo "$issue" | jq -r '.title')

        log_info "close_fixed_issues" "Closing issue #$issue_number: \"$issue_title\""
        if ! gh issue close "$issue_number" 2>/dev/null; then
            log_warn "close_fixed_issues" "Failed to close issue #$issue_number."
        else
            log_info "close_fixed_issues" "Successfully closed issue #$issue_number."
        fi
    done < <(echo "$issues_to_close_json" | jq -c '.[]')

    log_timing "close_fixed_issues" "$start_time"
}

# Function to check for open issues in the target milestone
check_open_issues_in_milestone() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "check_open_issues_in_milestone" "Checking for open issues in milestone $1..."

    local milestone_name="$1"
    local open_issues_json
    open_issues_json=$(gh issue list --state open --milestone "$milestone_name" --json number,title 2>/dev/null)

    if [ -n "$open_issues_json" ] && [ "$open_issues_json" != "[]" ]; then
        local issue_count
        issue_count=$(echo "$open_issues_json" | jq -r 'length')
        log_warn "check_open_issues_in_milestone" "Found $issue_count open issues in milestone '$milestone_name'. Please review them before proceeding with the release."
        echo "Warning: Found $issue_count open issues in milestone '$milestone_name':"
        echo "---"
        while IFS= read -r issue;
        do
            local number
            number=$(echo "$issue" | jq -r '.number')
            local title
            title=$(echo "$issue" | jq -r '.title')
            echo "- #$number: $title"
        done < <(echo "$open_issues_json" | jq -c '.[]')
        echo "---"
    else
        log_info "check_open_issues_in_milestone" "No open issues found in milestone '$milestone_name'."
    fi

    log_timing "check_open_issues_in_milestone" "$start_time"
}

# Function to update CHANGELOG.md
update_changelog() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "update_changelog" "Updating CHANGELOG.md..."

    local next_version="$1"
    local changelog_entries="$2"
    local current_date
    current_date=$(date +"%Y-%m-%d")

    local changelog_header="# Changelog\n\n"
    local new_section
    new_section="## $next_version ($current_date)
"

    if [ -n "$changelog_entries" ]; then
        new_section="${new_section}${changelog_entries}\n"
    else
        new_section+="- No significant changes.\n\n"
    fi

    if [ ! -f "CHANGELOG.md" ]; then
        log_info "update_changelog" "CHANGELOG.md not found. Creating new file."
        printf "%b" "${changelog_header}${new_section}" > CHANGELOG.md
    else
        # Read existing content, remove header, and prepend new section
        local existing_content
        existing_content=$(tail -n +3 CHANGELOG.md || true) # Skip first two lines (header)
        printf "%b" "${changelog_header}${new_section}${existing_content}" > CHANGELOG.md
    fi

    log_info "update_changelog" "CHANGELOG.md updated for version $next_version."
    log_timing "update_changelog" "$start_time"
}

# Function to update the version in README.md
update_readme_version() {
    local start_time
    start_time=$(date +%s.%N)
    log_debug "update_readme_version" "Updating README.md version..."

    local next_version="$1"
    local readme_file="README.md"

    if [ ! -f "$readme_file" ]; then
        log_warn "update_readme_version" "README.md not found. Skipping version update."
        log_timing "update_readme_version" "$start_time"
        return 0
    fi

    # Use sed to replace the version string. Assumes version is in format like 'vX.Y.Z'
    # This is a placeholder and might need adjustment based on actual README.md content
    # Example: replacing 'Current Version: v1.2.3' with 'Current Version: v1.2.4'
    # This regex looks for 'v' followed by digits and dots, optionally followed by a pre-release tag
    if sed -i "s/v[0-9]\+\.[0-9]\+\.[0-9]\+\(-\(alpha\|beta\)\.[0-9]\+\)\{0,1\}/$next_version/g" "$readme_file"; then
        log_info "update_readme_version" "README.md updated to version $next_version."
    else
        log_warn "update_readme_version" "Failed to update version in README.md. Pattern not found or sed error."
    fi

    log_timing "update_readme_version" "$start_time"
}

# Call the main function with all script arguments
main "$@"

