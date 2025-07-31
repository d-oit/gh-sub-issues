#!/bin/bash

# GitHub Wizard GitHub CLI Integration Module
# Provides GitHub CLI wrapper functions and repository operations

# Source display module for UI functions
GITHUB_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$GITHUB_MODULE_DIR/wizard-display.sh"

# Repository context variables
REPO_OWNER=""
REPO_NAME=""
BRANCH_NAME=""
IS_AUTHENTICATED=""
PROJECT_URL=""

# GitHub CLI authentication check
check_gh_auth() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    print_status_line "progress" "Checking GitHub CLI authentication..."
    log_verbose "check_gh_auth" "Starting GitHub CLI authentication check"
    
    # Check if GitHub CLI is installed
    if ! command -v gh >/dev/null 2>&1; then
        log_error "check_gh_auth" "GitHub CLI not found in PATH"
        print_error "GitHub CLI (gh) is not installed" "Please install GitHub CLI from https://cli.github.com/"
        return 1
    fi
    
    log_debug "check_gh_auth" "GitHub CLI found: $(gh --version | head -1)"
    
    # Check authentication status
    if ! gh auth status >/dev/null 2>&1; then
        IS_AUTHENTICATED="false"
        log_warn "check_gh_auth" "GitHub CLI authentication failed"
        print_status_line "error" "GitHub CLI is not authenticated"
        return 1
    fi
    
    IS_AUTHENTICATED="true"
    log_info "check_gh_auth" "GitHub CLI authentication successful"
    print_status_line "success" "GitHub CLI is authenticated"
    
    # Get authenticated user info for logging
    if [ "$DEBUG_MODE" = "true" ]; then
        local gh_user
        gh_user=$(gh_api_call "user" "check_gh_auth" --jq '.login' 2>/dev/null || echo "unknown")
        log_debug "check_gh_auth" "Authenticated as user: $gh_user"
    fi
    
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "check_gh_auth" "$start_time"
    fi
    
    return 0
}

# Get repository status and information
get_repo_status() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    print_status_line "progress" "Getting repository status..."
    log_verbose "get_repo_status" "Starting repository status check"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warn "get_repo_status" "Not in a git repository"
        print_status_line "warning" "Not in a git repository"
        return 1
    fi
    
    log_debug "get_repo_status" "Git repository detected"
    
    # Get repository context using GitHub CLI with performance monitoring
    local repo_info
    if ! repo_info=$(gh_api_call "repos/:owner/:repo" "get_repo_status" --template '{{.owner.login}},{{.name}}' 2>/dev/null); then
        # Fallback to gh repo view
        if ! repo_info=$(gh repo view --json owner,name 2>/dev/null); then
            log_error "get_repo_status" "Failed to get repository information from GitHub API"
            print_status_line "error" "Failed to get repository information"
            return 1
        fi
        
        if ! REPO_OWNER=$(echo "$repo_info" | jq -r '.owner.login' 2>/dev/null); then
            log_error "get_repo_status" "Failed to parse repository owner from JSON response"
            print_status_line "error" "Failed to parse repository owner"
            return 1
        fi
        
        if ! REPO_NAME=$(echo "$repo_info" | jq -r '.name' 2>/dev/null); then
            log_error "get_repo_status" "Failed to parse repository name from JSON response"
            print_status_line "error" "Failed to parse repository name"
            return 1
        fi
    else
        # Parse template output
        REPO_OWNER=$(echo "$repo_info" | cut -d',' -f1)
        REPO_NAME=$(echo "$repo_info" | cut -d',' -f2)
    fi
    
    if [ -z "$REPO_OWNER" ] || [ "$REPO_OWNER" = "null" ]; then
        log_error "get_repo_status" "Repository owner is empty or null"
        print_status_line "error" "Repository owner is empty"
        return 1
    fi
    
    if [ -z "$REPO_NAME" ] || [ "$REPO_NAME" = "null" ]; then
        log_error "get_repo_status" "Repository name is empty or null"
        print_status_line "error" "Repository name is empty"
        return 1
    fi
    
    log_info "get_repo_status" "Repository context: $REPO_OWNER/$REPO_NAME"
    
    # Get current branch
    if ! BRANCH_NAME=$(git branch --show-current 2>/dev/null); then
        BRANCH_NAME="unknown"
        log_debug "get_repo_status" "Could not determine current branch, using 'unknown'"
    else
        log_debug "get_repo_status" "Current branch: $BRANCH_NAME"
    fi
    
    print_status_line "success" "Repository: $REPO_OWNER/$REPO_NAME (branch: $BRANCH_NAME)"
    
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "get_repo_status" "$start_time"
    fi
    
    return 0
}

# Validate prerequisites for GitHub operations
validate_prerequisites() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    print_status_line "progress" "Validating prerequisites..."
    log_verbose "validate_prerequisites" "Starting prerequisite validation"
    
    local missing_deps=()
    local validation_passed=true
    
    # Check for GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("GitHub CLI (gh)")
        validation_passed=false
        log_error "validate_prerequisites" "GitHub CLI not found"
    else
        log_debug "validate_prerequisites" "GitHub CLI found: $(gh --version | head -1)"
    fi
    
    # Check for jq (used for JSON processing)
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
        validation_passed=false
        log_error "validate_prerequisites" "jq not found"
    else
        log_debug "validate_prerequisites" "jq found: $(jq --version)"
    fi
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
        validation_passed=false
        log_error "validate_prerequisites" "git not found"
    else
        log_debug "validate_prerequisites" "git found: $(git --version)"
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "validate_prerequisites" "Missing ${#missing_deps[@]} required dependencies: ${missing_deps[*]}"
        print_status_line "error" "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "   - $dep"
        done
        echo
        print_info "Installation instructions:"
        echo "   - GitHub CLI: https://cli.github.com/"
        echo "   - jq: https://stedolan.github.io/jq/download/"
        echo "   - git: https://git-scm.com/downloads"
        return 1
    fi
    
    # Check GitHub CLI authentication
    if ! check_gh_auth; then
        validation_passed=false
    fi
    
    # Check repository context
    if ! get_repo_status; then
        validation_passed=false
    fi
    
    if [ "$validation_passed" = "true" ]; then
        print_status_line "success" "All prerequisites validated"
        return 0
    else
        print_status_line "error" "Prerequisites validation failed"
        return 1
    fi
}

# Get repository context (exported variables)
get_repo_context() {
    if ! get_repo_status; then
        return 1
    fi
    
    # Export variables for use by other modules
    export REPO_OWNER
    export REPO_NAME
    export BRANCH_NAME
    export IS_AUTHENTICATED
    
    return 0
}

# Get issue counts and statistics with visual indicators
get_issue_stats() {
    print_status_line "progress" "Getting issue statistics..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Get open issues count
    local open_issues
    local open_issues_json
    if ! open_issues_json=$(gh issue list --state open --json number 2>/dev/null); then
        print_status_line "error" "Failed to get open issues"
        return 1
    fi
    
    if ! open_issues=$(echo "$open_issues_json" | jq '. | length' 2>/dev/null); then
        print_status_line "error" "Failed to parse open issues count"
        return 1
    fi
    
    # Get closed issues count
    local closed_issues
    local closed_issues_json
    if ! closed_issues_json=$(gh issue list --state closed --json number 2>/dev/null); then
        print_status_line "error" "Failed to get closed issues"
        return 1
    fi
    
    if ! closed_issues=$(echo "$closed_issues_json" | jq '. | length' 2>/dev/null); then
        print_status_line "error" "Failed to parse closed issues count"
        return 1
    fi
    
    # Calculate total and completion percentage
    local total_issues=$((open_issues + closed_issues))
    local completion_percentage=0
    if [ $total_issues -gt 0 ]; then
        completion_percentage=$(( (closed_issues * 100) / total_issues ))
    fi
    
    # Display with visual indicators
    local open_indicator="🔴"
    local closed_indicator="✅"
    local total_indicator="📊"
    
    if [ $open_issues -eq 0 ]; then
        open_indicator="✅"
    elif [ $open_issues -le 5 ]; then
        open_indicator="🟡"
    fi
    
    print_key_value "Open Issues" "$open_indicator $open_issues"
    print_key_value "Closed Issues" "$closed_indicator $closed_issues"
    print_key_value "Total Issues" "$total_indicator $total_issues"
    print_key_value "Completion Rate" "${completion_percentage}%"
    
    return 0
}

# Get recent repository activity with enhanced formatting
get_recent_activity() {
    print_status_line "progress" "Getting recent activity..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Get recent issues (last 5)
    echo
    print_header "Recent Issues (Last 5)"
    
    local recent_issues
    if recent_issues=$(gh issue list --limit 5 --json number,title,state,createdAt 2>/dev/null); then
        if [ "$(echo "$recent_issues" | jq '. | length' 2>/dev/null)" -gt 0 ]; then
            echo "$recent_issues" | jq -r '.[] | 
                if .state == "open" then
                    "🔴 #\(.number) \(.title) - \(.createdAt | fromdateiso8601 | strftime("%Y-%m-%d"))"
                else
                    "✅ #\(.number) \(.title) - \(.createdAt | fromdateiso8601 | strftime("%Y-%m-%d"))"
                end' 2>/dev/null || {
                # Fallback if jq date functions don't work
                echo "$recent_issues" | jq -r '.[] | 
                    if .state == "open" then
                        "🔴 #\(.number) \(.title) (open)"
                    else
                        "✅ #\(.number) \(.title) (closed)"
                    end' 2>/dev/null
            }
        else
            print_info "No recent issues found"
        fi
    else
        print_status_line "warning" "Failed to get recent issues"
    fi
    
    # Get recent pull requests (last 5)
    echo
    print_header "Recent Pull Requests (Last 5)"
    
    local recent_prs
    if recent_prs=$(gh pr list --limit 5 --json number,title,state,createdAt 2>/dev/null); then
        if [ "$(echo "$recent_prs" | jq '. | length' 2>/dev/null)" -gt 0 ]; then
            echo "$recent_prs" | jq -r '.[] | 
                if .state == "open" then
                    "🟢 #\(.number) \(.title) - \(.createdAt | fromdateiso8601 | strftime("%Y-%m-%d"))"
                elif .state == "merged" then
                    "🟣 #\(.number) \(.title) - \(.createdAt | fromdateiso8601 | strftime("%Y-%m-%d"))"
                else
                    "🔴 #\(.number) \(.title) - \(.createdAt | fromdateiso8601 | strftime("%Y-%m-%d"))"
                end' 2>/dev/null || {
                # Fallback if jq date functions don't work
                echo "$recent_prs" | jq -r '.[] | 
                    if .state == "open" then
                        "🟢 #\(.number) \(.title) (open)"
                    elif .state == "merged" then
                        "🟣 #\(.number) \(.title) (merged)"
                    else
                        "🔴 #\(.number) \(.title) (closed)"
                    end' 2>/dev/null
            }
        else
            print_info "No recent pull requests found"
        fi
    else
        print_status_line "warning" "Failed to get recent pull requests"
    fi
    
    return 0
}

# Get project board status with enhanced information
get_project_status() {
    print_status_line "progress" "Getting project board status..."
    
    if [ -z "${PROJECT_URL:-}" ]; then
        print_key_value "Project Board" "❌ Not configured"
        print_info "Set PROJECT_URL environment variable to enable project board integration"
        return 0
    fi
    
    # Extract project number from URL
    local project_number
    project_number=$(echo "$PROJECT_URL" | sed 's/.*\/projects\///')
    
    if [ -z "$project_number" ]; then
        print_status_line "error" "Invalid PROJECT_URL format"
        print_key_value "Project URL" "❌ Invalid format: $PROJECT_URL"
        return 1
    fi
    
    print_key_value "Project URL" "🔗 $PROJECT_URL"
    print_key_value "Project Number" "#$project_number"
    
    # Try to get project information with detailed output
    local project_info
    if project_info=$(gh project view "$project_number" --owner "$REPO_OWNER" --format json 2>/dev/null); then
        print_status_line "success" "✅ Project board accessible"
        
        # Try to extract project title if available
        local project_title
        if project_title=$(echo "$project_info" | jq -r '.title // "Unknown"' 2>/dev/null); then
            if [ "$project_title" != "null" ] && [ -n "$project_title" ]; then
                print_key_value "Project Title" "$project_title"
            fi
        fi
        
        # Get project items count if possible
        local items_count
        if items_count=$(gh project item-list "$project_number" --owner "$REPO_OWNER" --format json 2>/dev/null | jq '. | length' 2>/dev/null); then
            if [ "$items_count" != "null" ] && [ -n "$items_count" ]; then
                print_key_value "Project Items" "📋 $items_count items"
            fi
        fi
    else
        print_status_line "warning" "⚠️ Project board not accessible or doesn't exist"
        print_info "Check PROJECT_URL and permissions"
    fi
    
    return 0
}

# Create a new GitHub issue
create_github_issue() {
    local title="$1"
    local body="$2"
    local labels="${3:-}"
    local milestone="${4:-}"
    local quiet="${5:-false}"
    
    if [ "$quiet" != "true" ]; then
        print_status_line "progress" "Creating GitHub issue: $title"
    fi
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    # Build create command
    local create_args=("--title" "$title" "--body" "$body")
    
    if [ -n "$labels" ]; then
        create_args+=("--label" "$labels")
    fi
    
    if [ -n "$milestone" ]; then
        create_args+=("--milestone" "$milestone")
    fi
    
    # Create the issue
    local issue_url
    if ! issue_url=$(gh issue create "${create_args[@]}" 2>/dev/null); then
        if [ "$quiet" != "true" ]; then
            print_status_line "error" "Failed to create issue"
        fi
        return 1
    fi
    
    local issue_number
    issue_number=$(echo "$issue_url" | awk -F'/' '{print $NF}')
    
    if [ "$quiet" != "true" ]; then
        print_status_line "success" "Created issue #$issue_number"
    fi
    
    echo "$issue_number"
    return 0
}

# Update an existing GitHub issue
update_github_issue() {
    local issue_number="$1"
    shift
    
    print_status_line "progress" "Updating issue #$issue_number"
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Update the issue with provided arguments
    if ! gh issue edit "$issue_number" "$@" 2>/dev/null; then
        print_status_line "error" "Failed to update issue #$issue_number"
        return 1
    fi
    
    print_status_line "success" "Updated issue #$issue_number"
    return 0
}

# Link issues using parent-child relationship (GraphQL)
link_issues() {
    local parent_issue="$1"
    local child_issue="$2"
    
    print_status_line "progress" "Linking issue #$child_issue to parent #$parent_issue"
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Get parent and child issue IDs using GraphQL
    local parent_id
    if ! parent_id=$(gh api graphql -f query='query{repository(owner:"'"$REPO_OWNER"'",name:"'"$REPO_NAME"'"){issue(number:'"$parent_issue"'){id}}}' -q .data.repository.issue.id 2>/dev/null); then
        print_status_line "error" "Failed to get parent issue ID"
        return 1
    fi
    
    local child_id
    if ! child_id=$(gh api graphql -f query='query{repository(owner:"'"$REPO_OWNER"'",name:"'"$REPO_NAME"'"){issue(number:'"$child_issue"'){id}}}' -q .data.repository.issue.id 2>/dev/null); then
        print_status_line "error" "Failed to get child issue ID"
        return 1
    fi
    
    # Link child to parent using GraphQL mutation
    if ! gh api graphql \
        -H "GraphQL-Features: sub_issues" \
        -f query="
mutation {
  addSubIssue(input: {issueId: \"$parent_id\", subIssueId: \"$child_id\"}) {
    clientMutationId
  }
}" >/dev/null 2>&1; then
        print_status_line "warning" "Failed to create sub-issue relationship (feature may not be available)"
        return 1
    fi
    
    print_status_line "success" "Linked issue #$child_issue to parent #$parent_issue"
    return 0
}

# Add issue to project board
add_issue_to_project() {
    local issue_number="$1"
    local project_url="${2:-$PROJECT_URL}"
    
    if [ -z "$project_url" ]; then
        print_status_line "info" "No project URL provided, skipping project assignment"
        return 0
    fi
    
    print_status_line "progress" "Adding issue #$issue_number to project"
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Extract project number from URL
    local project_number
    project_number=$(echo "$project_url" | sed 's/.*\/projects\///')
    
    # Build issue URL
    local issue_url="https://github.com/$REPO_OWNER/$REPO_NAME/issues/$issue_number"
    
    # Add issue to project
    if ! gh project item-add "$project_number" --owner "$REPO_OWNER" --url "$issue_url" 2>/dev/null; then
        print_status_line "warning" "Failed to add issue #$issue_number to project"
        return 1
    fi
    
    print_status_line "success" "Added issue #$issue_number to project"
    return 0
}

# Check if repository has project boards
has_project_boards() {
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Try to list projects for the repository owner
    if gh project list --owner "$REPO_OWNER" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get GitHub CLI version information
get_gh_version() {
    if command -v gh >/dev/null 2>&1; then
        gh --version | head -1
    else
        echo "GitHub CLI not installed"
    fi
}

# Test GitHub CLI connectivity
test_gh_connectivity() {
    print_status_line "progress" "Testing GitHub CLI connectivity..."
    
    # Test basic API access
    if ! gh api user >/dev/null 2>&1; then
        print_status_line "error" "Failed to connect to GitHub API"
        return 1
    fi
    
    print_status_line "success" "GitHub CLI connectivity test passed"
    return 0
}

# Get repository health metrics
get_repo_health() {
    print_status_line "progress" "Analyzing repository health..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    local health_score=0
    local max_score=5
    local health_indicators=()
    
    # Check if repository has README
    if gh api "repos/$REPO_OWNER/$REPO_NAME/contents/README.md" >/dev/null 2>&1; then
        health_score=$((health_score + 1))
        health_indicators+=("✅ README.md present")
    else
        health_indicators+=("❌ README.md missing")
    fi
    
    # Check if repository has LICENSE
    if gh api "repos/$REPO_OWNER/$REPO_NAME/license" >/dev/null 2>&1; then
        health_score=$((health_score + 1))
        health_indicators+=("✅ License present")
    else
        health_indicators+=("❌ License missing")
    fi
    
    # Check if repository has recent commits (last 30 days)
    local recent_commits
    if recent_commits=$(gh api "repos/$REPO_OWNER/$REPO_NAME/commits?since=$(date -d '30 days ago' -Iseconds 2>/dev/null || date -v-30d -Iseconds 2>/dev/null || echo '2024-01-01T00:00:00Z')" 2>/dev/null); then
        local commit_count
        commit_count=$(echo "$recent_commits" | jq '. | length' 2>/dev/null || echo "0")
        if [ "$commit_count" -gt 0 ]; then
            health_score=$((health_score + 1))
            health_indicators+=("✅ Recent activity ($commit_count commits in 30 days)")
        else
            health_indicators+=("⚠️ No recent commits")
        fi
    else
        health_indicators+=("❓ Unable to check recent activity")
    fi
    
    # Check if repository has issues enabled
    local repo_info
    if repo_info=$(gh repo view --json hasIssuesEnabled 2>/dev/null); then
        local issues_enabled
        issues_enabled=$(echo "$repo_info" | jq -r '.hasIssuesEnabled' 2>/dev/null)
        if [ "$issues_enabled" = "true" ]; then
            health_score=$((health_score + 1))
            health_indicators+=("✅ Issues enabled")
        else
            health_indicators+=("❌ Issues disabled")
        fi
    fi
    
    # Check if repository has branch protection
    if gh api "repos/$REPO_OWNER/$REPO_NAME/branches/$BRANCH_NAME/protection" >/dev/null 2>&1; then
        health_score=$((health_score + 1))
        health_indicators+=("✅ Branch protection enabled")
    else
        health_indicators+=("⚠️ No branch protection")
    fi
    
    # Calculate health percentage
    local health_percentage=$(( (health_score * 100) / max_score ))
    
    echo
    print_header "Repository Health Score"
    print_key_value "Health Score" "$health_score/$max_score ($health_percentage%)"
    
    # Display health indicators
    for indicator in "${health_indicators[@]}"; do
        echo "  $indicator"
    done
    
    return 0
}

# Auto-refresh status dashboard
auto_refresh_dashboard() {
    local refresh_interval="${1:-30}"  # Default 30 seconds
    local max_refreshes="${2:-10}"     # Default 10 refreshes
    local refresh_count=0
    
    print_info "Auto-refresh enabled (every ${refresh_interval}s, max ${max_refreshes} refreshes)"
    print_info "Press Ctrl+C to stop auto-refresh"
    
    while [ $refresh_count -lt $max_refreshes ]; do
        sleep "$refresh_interval"
        refresh_count=$((refresh_count + 1))
        
        clear_screen true
        print_header "Auto-Refreshed Status Dashboard (Refresh #$refresh_count)"
        display_status_dashboard
        
        echo
        print_info "Next refresh in ${refresh_interval}s... (Refresh $refresh_count/$max_refreshes)"
    done
    
    print_info "Auto-refresh completed after $max_refreshes refreshes"
}

# Display comprehensive status dashboard
display_status_dashboard() {
    clear_screen true
    print_header "GitHub Repository Status Dashboard"
    
    # Check prerequisites first
    if ! validate_prerequisites >/dev/null 2>&1; then
        print_error "Prerequisites validation failed. Please check your setup."
        echo
        print_prompt "Press Enter to continue"
        read -r
        return 1
    fi
    
    # Repository Information Section
    print_header "Repository Information"
    print_key_value "Repository" "$REPO_OWNER/$REPO_NAME"
    print_key_value "Current Branch" "$BRANCH_NAME"
    print_key_value "GitHub CLI Auth" "$([ "$IS_AUTHENTICATED" = "true" ] && echo "✅ Authenticated" || echo "❌ Not Authenticated")"
    print_key_value "GitHub CLI Version" "$(get_gh_version)"
    
    # Issue Statistics Section
    echo
    print_header "Issue Statistics"
    get_issue_stats
    
    # Project Board Status Section
    echo
    print_header "Project Board Status"
    get_project_status
    
    # Recent Activity Section
    get_recent_activity
    
    # Real-time Status Updates
    echo
    print_header "System Status"
    test_gh_connectivity >/dev/null 2>&1
    local connectivity_status=$?
    if [ $connectivity_status -eq 0 ]; then
        print_status_line "success" "GitHub API connectivity: Online"
    else
        print_status_line "error" "GitHub API connectivity: Offline"
    fi
    
    # Display last updated timestamp
    print_key_value "Last Updated" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo
    print_prompt "Press Enter to continue or 'r' to refresh"
    read -r response
    
    # Handle refresh option
    if [ "$response" = "r" ] || [ "$response" = "R" ]; then
        display_status_dashboard
    fi
}

# Display comprehensive repository status (legacy function for compatibility)
display_repo_status() {
    display_status_dashboard
}

# Release wizard functionality

# Release context variables
CURRENT_VERSION=""
NEW_VERSION=""
RELEASE_TYPE=""
RELEASE_NOTES=""
RELEASE_TITLE=""

# Get current version from git tags
get_current_version() {
    print_status_line "progress" "Getting current version..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Get latest tag that looks like a version
    local latest_tag
    if latest_tag=$(git describe --tags --abbrev=0 --match="v*" 2>/dev/null || git describe --tags --abbrev=0 --match="[0-9]*" 2>/dev/null); then
        # Clean up version (remove 'v' prefix if present)
        CURRENT_VERSION=$(echo "$latest_tag" | sed 's/^v//')
        print_status_line "success" "Current version: $CURRENT_VERSION"
        return 0
    else
        # No tags found, assume this is the first release
        CURRENT_VERSION="0.0.0"
        print_status_line "info" "No version tags found, assuming first release (0.0.0)"
        return 0
    fi
}

# Validate version format (semantic versioning)
validate_version_format() {
    local version="$1"
    
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Calculate next version based on release type
calculate_next_version() {
    local current="$1"
    local release_type="$2"
    
    if ! validate_version_format "$current"; then
        print_status_line "error" "Invalid current version format: $current"
        return 1
    fi
    
    # Parse version components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"
    
    case "$release_type" in
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
            print_status_line "error" "Invalid release type: $release_type"
            return 1
            ;;
    esac
    
    NEW_VERSION="$major.$minor.$patch"
    print_status_line "success" "Next version: $NEW_VERSION ($release_type)"
    return 0
}

# Validate release prerequisites
validate_release_prerequisites() {
    print_status_line "progress" "Validating release prerequisites..."
    
    local validation_passed=true
    local issues=()
    
    # Check basic prerequisites first
    if ! validate_prerequisites >/dev/null 2>&1; then
        issues+=("Basic prerequisites not met")
        validation_passed=false
    fi
    
    # Check if we're on the main/master branch
    if [ "$BRANCH_NAME" != "main" ] && [ "$BRANCH_NAME" != "master" ]; then
        issues+=("Not on main/master branch (current: $BRANCH_NAME)")
        validation_passed=false
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        issues+=("Uncommitted changes detected")
        validation_passed=false
    fi
    
    # Check for unpushed commits
    if git log origin/"$BRANCH_NAME".."$BRANCH_NAME" --oneline 2>/dev/null | grep -q .; then
        issues+=("Unpushed commits detected")
        validation_passed=false
    fi
    
    # Check if repository is clean
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        issues+=("Working directory is not clean")
        validation_passed=false
    fi
    
    # Check for required files
    if [ ! -f "README.md" ]; then
        issues+=("README.md file missing")
        validation_passed=false
    fi
    
    # Check if there are any open issues with release-blocking labels
    local blocking_issues
    if blocking_issues=$(gh issue list --label "release-blocker" --state open --json number 2>/dev/null); then
        local count
        count=$(echo "$blocking_issues" | jq '. | length' 2>/dev/null || echo "0")
        if [ "$count" -gt 0 ]; then
            issues+=("$count release-blocking issues are open")
            validation_passed=false
        fi
    fi
    
    # Report validation results
    if [ "$validation_passed" = "true" ]; then
        print_status_line "success" "All release prerequisites validated"
        return 0
    else
        print_status_line "error" "Release prerequisites validation failed:"
        for issue in "${issues[@]}"; do
            echo "   ❌ $issue"
        done
        echo
        print_info "Please resolve these issues before creating a release"
        return 1
    fi
}

# Generate release notes
generate_release_notes() {
    local from_version="$1"
    local to_version="$2"
    
    print_status_line "progress" "Generating release notes..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    local from_tag="v$from_version"
    local to_ref="HEAD"
    
    # If from_version is 0.0.0, get all commits
    if [ "$from_version" = "0.0.0" ]; then
        from_tag=""
    fi
    
    # Get commit range
    local commit_range
    if [ -n "$from_tag" ]; then
        commit_range="$from_tag..$to_ref"
    else
        commit_range="$to_ref"
    fi
    
    # Generate release notes using GitHub CLI
    local notes_content=""
    
    # Try to use GitHub's automatic release notes generation
    if [ -n "$from_tag" ] && git rev-parse "$from_tag" >/dev/null 2>&1; then
        # Use GitHub CLI to generate release notes
        if notes_content=$(gh api repos/"$REPO_OWNER"/"$REPO_NAME"/releases/generate-notes \
            -f tag_name="v$to_version" \
            -f target_commitish="$BRANCH_NAME" \
            -f previous_tag_name="$from_tag" \
            --jq '.body' 2>/dev/null); then
            RELEASE_NOTES="$notes_content"
            print_status_line "success" "Generated automatic release notes"
            return 0
        fi
    fi
    
    # Fallback: Generate manual release notes from commits
    print_status_line "info" "Generating manual release notes from commits..."
    
    local commits
    if [ -n "$from_tag" ]; then
        commits=$(git log "$commit_range" --oneline --no-merges 2>/dev/null || echo "")
    else
        commits=$(git log --oneline --no-merges 2>/dev/null || echo "")
    fi
    
    if [ -z "$commits" ]; then
        RELEASE_NOTES="## What's Changed

No significant changes in this release.

**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/commits/v$to_version"
    else
        # Categorize commits
        local features=()
        local fixes=()
        local other=()
        
        while IFS= read -r commit; do
            if [ -n "$commit" ]; then
                local commit_msg=$(echo "$commit" | cut -d' ' -f2-)
                local commit_hash=$(echo "$commit" | cut -d' ' -f1)
                
                if [[ "$commit_msg" =~ ^(feat|feature)(\(.*\))?:.*$ ]]; then
                    features+=("- $commit_msg ($commit_hash)")
                elif [[ "$commit_msg" =~ ^(fix|bugfix)(\(.*\))?:.*$ ]]; then
                    fixes+=("- $commit_msg ($commit_hash)")
                else
                    other+=("- $commit_msg ($commit_hash)")
                fi
            fi
        done <<< "$commits"
        
        # Build release notes
        RELEASE_NOTES="## What's Changed"
        
        if [ ${#features[@]} -gt 0 ]; then
            RELEASE_NOTES="$RELEASE_NOTES

### ✨ New Features"
            for feature in "${features[@]}"; do
                RELEASE_NOTES="$RELEASE_NOTES
$feature"
            done
        fi
        
        if [ ${#fixes[@]} -gt 0 ]; then
            RELEASE_NOTES="$RELEASE_NOTES

### 🐛 Bug Fixes"
            for fix in "${fixes[@]}"; do
                RELEASE_NOTES="$RELEASE_NOTES
$fix"
            done
        fi
        
        if [ ${#other[@]} -gt 0 ]; then
            RELEASE_NOTES="$RELEASE_NOTES

### 🔧 Other Changes"
            for change in "${other[@]}"; do
                RELEASE_NOTES="$RELEASE_NOTES
$change"
            done
        fi
        
        RELEASE_NOTES="$RELEASE_NOTES

**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/v$from_version...v$to_version"
    fi
    
    print_status_line "success" "Generated release notes"
    return 0
}

# Create GitHub release
create_github_release() {
    local version="$1"
    local title="$2"
    local notes="$3"
    local prerelease="${4:-false}"
    local draft="${5:-false}"
    
    print_status_line "progress" "Creating GitHub release v$version..."
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context; then
            return 1
        fi
    fi
    
    # Build release creation arguments
    local create_args=("--tag" "v$version" "--title" "$title" "--notes" "$notes")
    
    if [ "$prerelease" = "true" ]; then
        create_args+=("--prerelease")
    fi
    
    if [ "$draft" = "true" ]; then
        create_args+=("--draft")
    fi
    
    # Create the release
    local release_url
    if release_url=$(gh release create "${create_args[@]}" 2>/dev/null); then
        print_status_line "success" "Created release: $release_url"
        echo "$release_url"
        return 0
    else
        print_status_line "error" "Failed to create release"
        return 1
    fi
}

# Interactive release wizard
interactive_release_wizard() {
    while true; do
        clear_screen true
        print_header "Release Wizard"
        
        # Validate prerequisites first
        if ! validate_prerequisites >/dev/null 2>&1; then
            print_error "Prerequisites validation failed. Please check your setup."
            echo
            print_prompt "Press Enter to return to main menu"
            read -r
            return 1
        fi
        
        echo
        print_menu_option "1" "Create New Release"
        print_menu_option "2" "Check Release Prerequisites"
        print_menu_option "3" "View Current Version"
        print_menu_option "4" "Preview Release Notes"
        print_menu_option "5" "Return to Main Menu"
        echo
        
        print_prompt "Select an option (1-5): "
        read -r choice
        
        case "$choice" in
            1)
                create_release_interactive
                ;;
            2)
                check_release_prerequisites_interactive
                ;;
            3)
                view_current_version_interactive
                ;;
            4)
                preview_release_notes_interactive
                ;;
            5)
                return 0
                ;;
            *)
                print_error "Invalid option. Please select 1-5."
                sleep 2
                ;;
        esac
    done
}

# Interactive release creation with full workflow
create_release_interactive() {
    clear_screen true
    print_header "Create New Release"
    
    # Step 1: Check prerequisites
    print_status_line "progress" "Checking release prerequisites..."
    if ! validate_release_prerequisites; then
        echo
        print_prompt "Prerequisites check failed. Do you want to continue anyway? (y/N): "
        read -r continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            return 0
        fi
        print_status_line "warning" "Continuing with failed prerequisites..."
    fi
    
    # Step 2: Get current version
    if ! get_current_version; then
        print_error "Failed to get current version"
        print_prompt "Press Enter to continue"
        read -r
        return 1
    fi
    
    # Step 3: Select release type
    echo
    print_header "Release Type Selection"
    print_key_value "Current Version" "$CURRENT_VERSION"
    echo
    print_menu_option "1" "Major Release (breaking changes)"
    print_menu_option "2" "Minor Release (new features)"
    print_menu_option "3" "Patch Release (bug fixes)"
    print_menu_option "4" "Custom Version"
    print_menu_option "5" "Cancel"
    echo
    
    while true; do
        print_prompt "Select release type (1-5): "
        read -r release_choice
        
        case "$release_choice" in
            1)
                RELEASE_TYPE="major"
                if calculate_next_version "$CURRENT_VERSION" "major"; then
                    break
                fi
                ;;
            2)
                RELEASE_TYPE="minor"
                if calculate_next_version "$CURRENT_VERSION" "minor"; then
                    break
                fi
                ;;
            3)
                RELEASE_TYPE="patch"
                if calculate_next_version "$CURRENT_VERSION" "patch"; then
                    break
                fi
                ;;
            4)
                print_prompt "Enter custom version (e.g., 1.2.3): "
                read -r custom_version
                if validate_version_format "$custom_version"; then
                    NEW_VERSION="$custom_version"
                    RELEASE_TYPE="custom"
                    print_status_line "success" "Custom version: $NEW_VERSION"
                    break
                else
                    print_error "Invalid version format. Please use semantic versioning (e.g., 1.2.3)"
                    continue
                fi
                ;;
            5)
                return 0
                ;;
            *)
                print_error "Invalid option. Please select 1-5."
                continue
                ;;
        esac
    done
    
    # Step 4: Generate release notes
    echo
    print_status_line "progress" "Generating release notes..."
    if ! generate_release_notes "$CURRENT_VERSION" "$NEW_VERSION"; then
        print_error "Failed to generate release notes"
        print_prompt "Continue with empty release notes? (y/N): "
        read -r continue_empty
        if [[ ! "$continue_empty" =~ ^[Yy]$ ]]; then
            return 0
        fi
        RELEASE_NOTES="Release v$NEW_VERSION"
    fi
    
    # Step 5: Set release title
    RELEASE_TITLE="Release v$NEW_VERSION"
    print_prompt "Enter release title (default: $RELEASE_TITLE): "
    read -r custom_title
    if [ -n "$custom_title" ]; then
        RELEASE_TITLE="$custom_title"
    fi
    
    # Step 6: Release options
    echo
    print_header "Release Options"
    print_prompt "Create as draft release? (y/N): "
    read -r is_draft
    local draft_flag="false"
    if [[ "$is_draft" =~ ^[Yy]$ ]]; then
        draft_flag="true"
    fi
    
    print_prompt "Mark as pre-release? (y/N): "
    read -r is_prerelease
    local prerelease_flag="false"
    if [[ "$is_prerelease" =~ ^[Yy]$ ]]; then
        prerelease_flag="true"
    fi
    
    # Step 7: Show confirmation
    echo
    print_header "Release Confirmation"
    print_key_value "Current Version" "$CURRENT_VERSION"
    print_key_value "New Version" "$NEW_VERSION"
    print_key_value "Release Type" "$RELEASE_TYPE"
    print_key_value "Release Title" "$RELEASE_TITLE"
    print_key_value "Draft" "$([ "$draft_flag" = "true" ] && echo "Yes" || echo "No")"
    print_key_value "Pre-release" "$([ "$prerelease_flag" = "true" ] && echo "Yes" || echo "No")"
    
    echo
    print_header "Release Notes Preview"
    echo "$RELEASE_NOTES" | head -10
    if [ $(echo "$RELEASE_NOTES" | wc -l) -gt 10 ]; then
        echo "... (truncated)"
    fi
    
    echo
    print_prompt "Create this release? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Release creation cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Step 8: Create the release
    echo
    print_status_line "progress" "Creating release..."
    
    local release_url
    if release_url=$(create_github_release "$NEW_VERSION" "$RELEASE_TITLE" "$RELEASE_NOTES" "$prerelease_flag" "$draft_flag"); then
        echo
        print_status_line "success" "Release created successfully!"
        print_key_value "Release URL" "$release_url"
        
        # Offer to open release in browser
        print_prompt "Open release in browser? (y/N): "
        read -r open_browser
        if [[ "$open_browser" =~ ^[Yy]$ ]]; then
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$release_url" >/dev/null 2>&1 &
            elif command -v open >/dev/null 2>&1; then
                open "$release_url" >/dev/null 2>&1 &
            elif command -v start >/dev/null 2>&1; then
                start "$release_url" >/dev/null 2>&1 &
            else
                print_info "Please open the URL manually: $release_url"
            fi
        fi
    else
        print_error "Failed to create release"
        echo
        print_header "Recovery Options"
        print_menu_option "1" "Retry release creation"
        print_menu_option "2" "Create as draft and fix manually"
        print_menu_option "3" "Cancel and return to menu"
        echo
        
        print_prompt "Select recovery option (1-3): "
        read -r recovery_choice
        
        case "$recovery_choice" in
            1)
                print_info "Retrying release creation..."
                sleep 2
                create_release_interactive
                return
                ;;
            2)
                print_info "Creating draft release..."
                if create_github_release "$NEW_VERSION" "$RELEASE_TITLE" "$RELEASE_NOTES" "$prerelease_flag" "true"; then
                    print_status_line "success" "Draft release created. You can edit and publish it manually."
                else
                    print_error "Failed to create draft release"
                fi
                ;;
            3)
                print_info "Release creation cancelled"
                ;;
        esac
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Check release prerequisites interactively
check_release_prerequisites_interactive() {
    clear_screen true
    print_header "Release Prerequisites Check"
    
    validate_release_prerequisites
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# View current version interactively
view_current_version_interactive() {
    clear_screen true
    print_header "Current Version Information"
    
    if get_current_version; then
        print_key_value "Current Version" "$CURRENT_VERSION"
        
        # Show version history
        echo
        print_header "Recent Version History"
        local recent_tags
        if recent_tags=$(git tag --sort=-version:refname | head -5 2>/dev/null); then
            if [ -n "$recent_tags" ]; then
                echo "$recent_tags" | while read -r tag; do
                    if [ -n "$tag" ]; then
                        local tag_date
                        tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
                        print_key_value "$tag" "$tag_date"
                    fi
                done
            else
                print_info "No version tags found"
            fi
        else
            print_info "Unable to retrieve version history"
        fi
        
        # Show next version previews
        echo
        print_header "Next Version Previews"
        local major minor patch
        IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
        print_key_value "Next Major" "$((major + 1)).0.0"
        print_key_value "Next Minor" "$major.$((minor + 1)).0"
        print_key_value "Next Patch" "$major.$minor.$((patch + 1))"
    else
        print_error "Failed to get current version information"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Preview release notes interactively
preview_release_notes_interactive() {
    clear_screen true
    print_header "Release Notes Preview"
    
    # Get current version
    if ! get_current_version; then
        print_error "Failed to get current version"
        print_prompt "Press Enter to continue"
        read -r
        return 1
    fi
    
    # Ask for target version
    print_prompt "Enter target version for preview (default: next patch): "
    read -r target_version
    
    if [ -z "$target_version" ]; then
        if ! calculate_next_version "$CURRENT_VERSION" "patch"; then
            print_error "Failed to calculate next version"
            print_prompt "Press Enter to continue"
            read -r
            return 1
        fi
        target_version="$NEW_VERSION"
    elif ! validate_version_format "$target_version"; then
        print_error "Invalid version format"
        print_prompt "Press Enter to continue"
        read -r
        return 1
    fi
    
    # Generate release notes
    if generate_release_notes "$CURRENT_VERSION" "$target_version"; then
        echo
        print_header "Release Notes for v$target_version"
        echo "$RELEASE_NOTES"
    else
        print_error "Failed to generate release notes"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Initialize GitHub module
init_github_module() {
    # Clear any existing context
    REPO_OWNER=""
    REPO_NAME=""
    BRANCH_NAME=""
    IS_AUTHENTICATED=""
    
    # Clear release context
    CURRENT_VERSION=""
    NEW_VERSION=""
    RELEASE_TYPE=""
    RELEASE_NOTES=""
    RELEASE_TITLE=""
    
    # Load PROJECT_URL from environment if available
    PROJECT_URL="${PROJECT_URL:-}"
    
    print_info "GitHub CLI integration module initialized"
}

# Interactive status dashboard menu
interactive_status_dashboard() {
    while true; do
        display_status_dashboard
        
        echo
        print_header "Status Dashboard Options"
        print_menu_option "1" "Refresh Status"
        print_menu_option "2" "Repository Health Check"
        print_menu_option "3" "Auto-Refresh (30s intervals)"
        print_menu_option "4" "Return to Main Menu"
        echo
        
        print_prompt "Select an option (1-4): "
        read -r choice
        
        case "$choice" in
            1)
                print_status_line "progress" "Refreshing status..."
                sleep 1
                continue
                ;;
            2)
                clear_screen true
                print_header "Repository Health Analysis"
                get_repo_health
                echo
                print_prompt "Press Enter to continue"
                read -r
                ;;
            3)
                clear_screen true
                print_header "Auto-Refresh Dashboard"
                print_info "Starting auto-refresh mode..."
                auto_refresh_dashboard 30 5
                ;;
            4)
                return 0
                ;;
            *)
                print_error "Invalid option. Please select 1-4."
                sleep 2
                ;;
        esac
    done
}

# Issue management operations

# Interactive issue management menu
interactive_issue_management() {
    while true; do
        clear_screen true
        print_header "Issue Management"
        
        # Validate prerequisites first
        if ! validate_prerequisites >/dev/null 2>&1; then
            print_error "Prerequisites validation failed. Please check your setup."
            echo
            print_prompt "Press Enter to return to main menu"
            read -r
            return 1
        fi
        
        echo
        print_menu_option "1" "Create New Issue"
        print_menu_option "2" "Update Existing Issue"
        print_menu_option "3" "Link Issues (Parent-Child)"
        print_menu_option "4" "Bulk Issue Operations"
        print_menu_option "5" "List Issues"
        print_menu_option "6" "Return to Main Menu"
        echo
        
        print_prompt "Select an option (1-6): "
        read -r choice
        
        case "$choice" in
            1)
                create_issue_interactive
                ;;
            2)
                update_issue_interactive
                ;;
            3)
                link_issues_interactive
                ;;
            4)
                bulk_issue_operations
                ;;
            5)
                list_issues_interactive
                ;;
            6)
                return 0
                ;;
            *)
                print_error "Invalid option. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

# Interactive issue creation with validation and confirmation
create_issue_interactive() {
    clear_screen true
    print_header "Create New Issue"
    
    local title body labels milestone assignees parent_issue add_to_project
    
    # Get issue title
    while true; do
        print_prompt "Enter issue title: "
        read -r title
        
        if [ -z "$title" ]; then
            print_error "Issue title cannot be empty"
            continue
        fi
        
        if [ ${#title} -lt 5 ]; then
            print_error "Issue title must be at least 5 characters long"
            continue
        fi
        
        break
    done
    
    # Get issue body
    print_prompt "Enter issue description (press Enter for empty line, type 'END' on new line to finish): "
    body=""
    while true; do
        read -r line
        if [ "$line" = "END" ]; then
            break
        fi
        if [ -n "$body" ]; then
            body="$body\n$line"
        else
            body="$line"
        fi
    done
    
    # Get labels (optional)
    print_prompt "Enter labels (comma-separated, optional): "
    read -r labels
    
    # Get milestone (optional)
    print_prompt "Enter milestone (optional): "
    read -r milestone
    
    # Get assignees (optional)
    print_prompt "Enter assignees (comma-separated, optional): "
    read -r assignees
    
    # Ask about parent issue
    print_prompt "Is this a child issue? (y/N): "
    read -r is_child
    if [[ "$is_child" =~ ^[Yy]$ ]]; then
        print_prompt "Enter parent issue number: "
        read -r parent_issue
        
        # Validate parent issue exists
        if [ -n "$parent_issue" ]; then
            if ! validate_issue_exists "$parent_issue"; then
                print_error "Parent issue #$parent_issue does not exist"
                print_prompt "Continue without parent? (y/N): "
                read -r continue_without_parent
                if [[ ! "$continue_without_parent" =~ ^[Yy]$ ]]; then
                    return 0
                fi
                parent_issue=""
            fi
        fi
    fi
    
    # Ask about project board
    if [ -n "${PROJECT_URL:-}" ]; then
        print_prompt "Add to project board? (Y/n): "
        read -r add_to_project
        if [[ ! "$add_to_project" =~ ^[Nn]$ ]]; then
            add_to_project="yes"
        else
            add_to_project="no"
        fi
    else
        add_to_project="no"
    fi
    
    # Show confirmation
    echo
    print_header "Issue Creation Confirmation"
    print_key_value "Title" "$title"
    print_key_value "Description" "$(echo -e "$body" | head -3 | tr '\n' ' ')$([ $(echo -e "$body" | wc -l) -gt 3 ] && echo "...")"
    [ -n "$labels" ] && print_key_value "Labels" "$labels"
    [ -n "$milestone" ] && print_key_value "Milestone" "$milestone"
    [ -n "$assignees" ] && print_key_value "Assignees" "$assignees"
    [ -n "$parent_issue" ] && print_key_value "Parent Issue" "#$parent_issue"
    [ "$add_to_project" = "yes" ] && print_key_value "Add to Project" "Yes"
    
    echo
    print_prompt "Create this issue? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Issue creation cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Create the issue
    print_status_line "progress" "Creating issue..."
    
    local create_args=("--title" "$title" "--body" "$body")
    
    if [ -n "$labels" ]; then
        create_args+=("--label" "$labels")
    fi
    
    if [ -n "$milestone" ]; then
        create_args+=("--milestone" "$milestone")
    fi
    
    if [ -n "$assignees" ]; then
        create_args+=("--assignee" "$assignees")
    fi
    
    local issue_number
    if issue_number=$(create_issue_with_args "${create_args[@]}"); then
        print_status_line "success" "Created issue #$issue_number"
        
        # Link to parent if specified
        if [ -n "$parent_issue" ]; then
            print_status_line "progress" "Linking to parent issue #$parent_issue..."
            if link_issues "$parent_issue" "$issue_number" >/dev/null 2>&1; then
                print_status_line "success" "Linked to parent issue #$parent_issue"
            else
                print_status_line "warning" "Failed to link to parent issue (feature may not be available)"
            fi
        fi
        
        # Add to project if requested
        if [ "$add_to_project" = "yes" ]; then
            print_status_line "progress" "Adding to project board..."
            if add_issue_to_project "$issue_number" >/dev/null 2>&1; then
                print_status_line "success" "Added to project board"
            else
                print_status_line "warning" "Failed to add to project board"
            fi
        fi
        
        echo
        print_info "Issue created successfully: https://github.com/$REPO_OWNER/$REPO_NAME/issues/$issue_number"
    else
        print_status_line "error" "Failed to create issue"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Helper function to create issue with arguments
create_issue_with_args() {
    local issue_url
    if ! issue_url=$(gh issue create "$@" 2>/dev/null); then
        return 1
    fi
    
    local issue_number
    issue_number=$(echo "$issue_url" | awk -F'/' '{print $NF}')
    echo "$issue_number"
    return 0
}

# Interactive issue update with validation and confirmation
update_issue_interactive() {
    clear_screen true
    print_header "Update Existing Issue"
    
    local issue_number
    
    # Get issue number
    while true; do
        print_prompt "Enter issue number to update: "
        read -r issue_number
        
        if [ -z "$issue_number" ]; then
            print_error "Issue number cannot be empty"
            continue
        fi
        
        if ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
            print_error "Issue number must be a positive integer"
            continue
        fi
        
        # Validate issue exists
        if ! validate_issue_exists "$issue_number"; then
            print_error "Issue #$issue_number does not exist"
            continue
        fi
        
        break
    done
    
    # Show current issue information
    print_status_line "progress" "Fetching current issue information..."
    local current_issue
    if current_issue=$(gh issue view "$issue_number" --json title,body,state,labels,milestone,assignees 2>/dev/null); then
        echo
        print_header "Current Issue Information"
        
        local current_title current_body current_state current_labels current_milestone current_assignees
        current_title=$(echo "$current_issue" | jq -r '.title // "N/A"' 2>/dev/null)
        current_body=$(echo "$current_issue" | jq -r '.body // "N/A"' 2>/dev/null)
        current_state=$(echo "$current_issue" | jq -r '.state // "N/A"' 2>/dev/null)
        current_labels=$(echo "$current_issue" | jq -r '.labels[]?.name // empty' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        current_milestone=$(echo "$current_issue" | jq -r '.milestone.title // "N/A"' 2>/dev/null)
        current_assignees=$(echo "$current_issue" | jq -r '.assignees[]?.login // empty' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        
        print_key_value "Title" "$current_title"
        print_key_value "State" "$current_state"
        print_key_value "Labels" "${current_labels:-None}"
        print_key_value "Milestone" "${current_milestone:-None}"
        print_key_value "Assignees" "${current_assignees:-None}"
        print_key_value "Description" "$(echo "$current_body" | head -3 | tr '\n' ' ')$([ $(echo "$current_body" | wc -l) -gt 3 ] && echo "...")"
    else
        print_status_line "warning" "Could not fetch current issue information"
    fi
    
    echo
    print_header "Update Options"
    print_menu_option "1" "Update Title"
    print_menu_option "2" "Update Description"
    print_menu_option "3" "Update Labels"
    print_menu_option "4" "Update Milestone"
    print_menu_option "5" "Update Assignees"
    print_menu_option "6" "Change State (open/close)"
    print_menu_option "7" "Update Multiple Fields"
    print_menu_option "8" "Cancel"
    echo
    
    print_prompt "Select update option (1-8): "
    read -r update_choice
    
    local update_args=()
    
    case "$update_choice" in
        1)
            print_prompt "Enter new title: "
            read -r new_title
            if [ -n "$new_title" ]; then
                update_args+=("--title" "$new_title")
            fi
            ;;
        2)
            print_prompt "Enter new description (press Enter for empty line, type 'END' on new line to finish): "
            local new_body=""
            while true; do
                read -r line
                if [ "$line" = "END" ]; then
                    break
                fi
                if [ -n "$new_body" ]; then
                    new_body="$new_body\n$line"
                else
                    new_body="$line"
                fi
            done
            if [ -n "$new_body" ]; then
                update_args+=("--body" "$new_body")
            fi
            ;;
        3)
            print_prompt "Enter new labels (comma-separated): "
            read -r new_labels
            if [ -n "$new_labels" ]; then
                update_args+=("--add-label" "$new_labels")
            fi
            ;;
        4)
            print_prompt "Enter new milestone: "
            read -r new_milestone
            if [ -n "$new_milestone" ]; then
                update_args+=("--milestone" "$new_milestone")
            fi
            ;;
        5)
            print_prompt "Enter new assignees (comma-separated): "
            read -r new_assignees
            if [ -n "$new_assignees" ]; then
                update_args+=("--add-assignee" "$new_assignees")
            fi
            ;;
        6)
            print_prompt "Change state to (open/close): "
            read -r new_state
            if [ "$new_state" = "close" ] || [ "$new_state" = "closed" ]; then
                update_args+=("--add-label" "closed")
            elif [ "$new_state" = "open" ] || [ "$new_state" = "reopen" ]; then
                update_args+=("--remove-label" "closed")
            fi
            ;;
        7)
            # Multiple field updates
            print_prompt "Update title? (y/N): "
            read -r update_title
            if [[ "$update_title" =~ ^[Yy]$ ]]; then
                print_prompt "Enter new title: "
                read -r new_title
                if [ -n "$new_title" ]; then
                    update_args+=("--title" "$new_title")
                fi
            fi
            
            print_prompt "Update labels? (y/N): "
            read -r update_labels
            if [[ "$update_labels" =~ ^[Yy]$ ]]; then
                print_prompt "Enter new labels (comma-separated): "
                read -r new_labels
                if [ -n "$new_labels" ]; then
                    update_args+=("--add-label" "$new_labels")
                fi
            fi
            
            print_prompt "Update milestone? (y/N): "
            read -r update_milestone
            if [[ "$update_milestone" =~ ^[Yy]$ ]]; then
                print_prompt "Enter new milestone: "
                read -r new_milestone
                if [ -n "$new_milestone" ]; then
                    update_args+=("--milestone" "$new_milestone")
                fi
            fi
            ;;
        8)
            print_info "Update cancelled"
            print_prompt "Press Enter to continue"
            read -r
            return 0
            ;;
        *)
            print_error "Invalid option"
            print_prompt "Press Enter to continue"
            read -r
            return 0
            ;;
    esac
    
    if [ ${#update_args[@]} -eq 0 ]; then
        print_info "No changes specified"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Update Confirmation"
    print_key_value "Issue Number" "#$issue_number"
    print_key_value "Updates" "${update_args[*]}"
    
    echo
    print_prompt "Apply these updates? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Update cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Apply updates
    print_status_line "progress" "Updating issue #$issue_number..."
    
    if update_github_issue "$issue_number" "${update_args[@]}" >/dev/null 2>&1; then
        print_status_line "success" "Issue #$issue_number updated successfully"
        echo
        print_info "View updated issue: https://github.com/$REPO_OWNER/$REPO_NAME/issues/$issue_number"
    else
        print_status_line "error" "Failed to update issue #$issue_number"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Interactive issue linking with verification
link_issues_interactive() {
    clear_screen true
    print_header "Link Issues (Parent-Child Relationship)"
    
    local parent_issue child_issue
    
    # Get parent issue number
    while true; do
        print_prompt "Enter parent issue number: "
        read -r parent_issue
        
        if [ -z "$parent_issue" ]; then
            print_error "Parent issue number cannot be empty"
            continue
        fi
        
        if ! [[ "$parent_issue" =~ ^[0-9]+$ ]]; then
            print_error "Issue number must be a positive integer"
            continue
        fi
        
        # Validate parent issue exists
        if ! validate_issue_exists "$parent_issue"; then
            print_error "Parent issue #$parent_issue does not exist"
            continue
        fi
        
        break
    done
    
    # Get child issue number
    while true; do
        print_prompt "Enter child issue number: "
        read -r child_issue
        
        if [ -z "$child_issue" ]; then
            print_error "Child issue number cannot be empty"
            continue
        fi
        
        if ! [[ "$child_issue" =~ ^[0-9]+$ ]]; then
            print_error "Issue number must be a positive integer"
            continue
        fi
        
        if [ "$child_issue" = "$parent_issue" ]; then
            print_error "Child issue cannot be the same as parent issue"
            continue
        fi
        
        # Validate child issue exists
        if ! validate_issue_exists "$child_issue"; then
            print_error "Child issue #$child_issue does not exist"
            continue
        fi
        
        break
    done
    
    # Show issue information for verification
    print_status_line "progress" "Fetching issue information for verification..."
    
    local parent_info child_info
    parent_info=$(gh issue view "$parent_issue" --json title,state 2>/dev/null || echo '{"title":"Unknown","state":"unknown"}')
    child_info=$(gh issue view "$child_issue" --json title,state 2>/dev/null || echo '{"title":"Unknown","state":"unknown"}')
    
    local parent_title parent_state child_title child_state
    parent_title=$(echo "$parent_info" | jq -r '.title // "Unknown"' 2>/dev/null)
    parent_state=$(echo "$parent_info" | jq -r '.state // "unknown"' 2>/dev/null)
    child_title=$(echo "$child_info" | jq -r '.title // "Unknown"' 2>/dev/null)
    child_state=$(echo "$child_info" | jq -r '.state // "unknown"' 2>/dev/null)
    
    echo
    print_header "Link Verification"
    print_key_value "Parent Issue" "#$parent_issue: $parent_title ($parent_state)"
    print_key_value "Child Issue" "#$child_issue: $child_title ($child_state)"
    
    echo
    print_prompt "Link these issues? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Linking cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Perform linking
    print_status_line "progress" "Linking issues..."
    
    if link_issues "$parent_issue" "$child_issue" >/dev/null 2>&1; then
        print_status_line "success" "Successfully linked issue #$child_issue to parent #$parent_issue"
        echo
        print_info "Parent issue: https://github.com/$REPO_OWNER/$REPO_NAME/issues/$parent_issue"
        print_info "Child issue: https://github.com/$REPO_OWNER/$REPO_NAME/issues/$child_issue"
    else
        print_status_line "warning" "Failed to create sub-issue relationship"
        print_info "This feature may not be available in your repository or GitHub plan"
        print_info "Consider adding a comment to link the issues manually"
        
        echo
        print_prompt "Add linking comment to child issue? (Y/n): "
        read -r add_comment
        
        if [[ ! "$add_comment" =~ ^[Nn]$ ]]; then
            local comment_body="Related to parent issue #$parent_issue"
            if gh issue comment "$child_issue" --body "$comment_body" >/dev/null 2>&1; then
                print_status_line "success" "Added linking comment to issue #$child_issue"
            else
                print_status_line "warning" "Failed to add linking comment"
            fi
        fi
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk issue operations interface
bulk_issue_operations() {
    clear_screen true
    print_header "Bulk Issue Operations"
    
    echo
    print_menu_option "1" "Bulk Label Update"
    print_menu_option "2" "Bulk Milestone Assignment"
    print_menu_option "3" "Bulk State Change (Open/Close)"
    print_menu_option "4" "Bulk Project Assignment"
    print_menu_option "5" "Bulk Issue Creation from Template"
    print_menu_option "6" "Return to Issue Management"
    echo
    
    print_prompt "Select bulk operation (1-6): "
    read -r choice
    
    case "$choice" in
        1)
            bulk_label_update
            ;;
        2)
            bulk_milestone_assignment
            ;;
        3)
            bulk_state_change
            ;;
        4)
            bulk_project_assignment
            ;;
        5)
            bulk_issue_creation
            ;;
        6)
            return 0
            ;;
        *)
            print_error "Invalid option. Please select 1-6."
            sleep 2
            ;;
    esac
}

# Bulk label update
bulk_label_update() {
    clear_screen true
    print_header "Bulk Label Update"
    
    local issue_numbers labels action
    
    # Get issue numbers
    print_prompt "Enter issue numbers (space-separated): "
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Validate issue numbers
    local valid_issues=()
    for issue in $issue_numbers; do
        if [[ "$issue" =~ ^[0-9]+$ ]] && validate_issue_exists "$issue"; then
            valid_issues+=("$issue")
        else
            print_status_line "warning" "Skipping invalid or non-existent issue: #$issue"
        fi
    done
    
    if [ ${#valid_issues[@]} -eq 0 ]; then
        print_error "No valid issues found"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Get labels and action
    print_prompt "Enter labels (comma-separated): "
    read -r labels
    
    if [ -z "$labels" ]; then
        print_error "No labels provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    print_prompt "Action (add/remove): "
    read -r action
    
    if [ "$action" != "add" ] && [ "$action" != "remove" ]; then
        print_error "Invalid action. Must be 'add' or 'remove'"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Bulk Label Update Confirmation"
    print_key_value "Issues" "${valid_issues[*]}"
    print_key_value "Labels" "$labels"
    print_key_value "Action" "$action"
    
    echo
    print_prompt "Apply bulk label update? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Bulk update cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Apply bulk update
    local success_count=0
    local total_count=${#valid_issues[@]}
    
    for issue in "${valid_issues[@]}"; do
        print_status_line "progress" "Updating issue #$issue..."
        
        local update_args
        if [ "$action" = "add" ]; then
            update_args=("--add-label" "$labels")
        else
            update_args=("--remove-label" "$labels")
        fi
        
        if update_github_issue "$issue" "${update_args[@]}" >/dev/null 2>&1; then
            print_status_line "success" "Updated issue #$issue"
            success_count=$((success_count + 1))
        else
            print_status_line "error" "Failed to update issue #$issue"
        fi
    done
    
    echo
    print_key_value "Total Issues" "$total_count"
    print_key_value "Successfully Updated" "$success_count"
    print_key_value "Failed" "$((total_count - success_count))"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk milestone assignment
bulk_milestone_assignment() {
    clear_screen true
    print_header "Bulk Milestone Assignment"
    
    local issue_numbers milestone
    
    # Get issue numbers
    print_prompt "Enter issue numbers (space-separated): "
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Get milestone
    print_prompt "Enter milestone name: "
    read -r milestone
    
    if [ -z "$milestone" ]; then
        print_error "No milestone provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Validate issue numbers
    local valid_issues=()
    for issue in $issue_numbers; do
        if [[ "$issue" =~ ^[0-9]+$ ]] && validate_issue_exists "$issue"; then
            valid_issues+=("$issue")
        else
            print_status_line "warning" "Skipping invalid or non-existent issue: #$issue"
        fi
    done
    
    if [ ${#valid_issues[@]} -eq 0 ]; then
        print_error "No valid issues found"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Bulk Milestone Assignment Confirmation"
    print_key_value "Issues" "${valid_issues[*]}"
    print_key_value "Milestone" "$milestone"
    
    echo
    print_prompt "Apply bulk milestone assignment? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Bulk assignment cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Apply bulk assignment
    local success_count=0
    local total_count=${#valid_issues[@]}
    
    for issue in "${valid_issues[@]}"; do
        print_status_line "progress" "Assigning milestone to issue #$issue..."
        
        if update_github_issue "$issue" --milestone "$milestone" >/dev/null 2>&1; then
            print_status_line "success" "Updated issue #$issue"
            success_count=$((success_count + 1))
        else
            print_status_line "error" "Failed to update issue #$issue"
        fi
    done
    
    echo
    print_key_value "Total Issues" "$total_count"
    print_key_value "Successfully Updated" "$success_count"
    print_key_value "Failed" "$((total_count - success_count))"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk state change
bulk_state_change() {
    clear_screen true
    print_header "Bulk State Change"
    
    local issue_numbers new_state
    
    # Get issue numbers
    print_prompt "Enter issue numbers (space-separated): "
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Get new state
    print_prompt "New state (open/close): "
    read -r new_state
    
    if [ "$new_state" != "open" ] && [ "$new_state" != "close" ]; then
        print_error "Invalid state. Must be 'open' or 'close'"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Validate issue numbers
    local valid_issues=()
    for issue in $issue_numbers; do
        if [[ "$issue" =~ ^[0-9]+$ ]] && validate_issue_exists "$issue"; then
            valid_issues+=("$issue")
        else
            print_status_line "warning" "Skipping invalid or non-existent issue: #$issue"
        fi
    done
    
    if [ ${#valid_issues[@]} -eq 0 ]; then
        print_error "No valid issues found"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Bulk State Change Confirmation"
    print_key_value "Issues" "${valid_issues[*]}"
    print_key_value "New State" "$new_state"
    
    echo
    print_prompt "Apply bulk state change? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Bulk state change cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Apply bulk state change
    local success_count=0
    local total_count=${#valid_issues[@]}
    
    for issue in "${valid_issues[@]}"; do
        print_status_line "progress" "Changing state of issue #$issue to $new_state..."
        
        if [ "$new_state" = "close" ]; then
            gh_command="gh issue close $issue"
        else
            gh_command="gh issue reopen $issue"
        fi
        
        if eval "$gh_command" >/dev/null 2>&1; then
            print_status_line "success" "Updated issue #$issue"
            success_count=$((success_count + 1))
        else
            print_status_line "error" "Failed to update issue #$issue"
        fi
    done
    
    echo
    print_key_value "Total Issues" "$total_count"
    print_key_value "Successfully Updated" "$success_count"
    print_key_value "Failed" "$((total_count - success_count))"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk project assignment
bulk_project_assignment() {
    clear_screen true
    print_header "Bulk Project Assignment"
    
    if [ -z "${PROJECT_URL:-}" ]; then
        print_error "PROJECT_URL not configured"
        print_info "Set PROJECT_URL environment variable to enable project board integration"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    local issue_numbers
    
    # Get issue numbers
    print_prompt "Enter issue numbers (space-separated): "
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Validate issue numbers
    local valid_issues=()
    for issue in $issue_numbers; do
        if [[ "$issue" =~ ^[0-9]+$ ]] && validate_issue_exists "$issue"; then
            valid_issues+=("$issue")
        else
            print_status_line "warning" "Skipping invalid or non-existent issue: #$issue"
        fi
    done
    
    if [ ${#valid_issues[@]} -eq 0 ]; then
        print_error "No valid issues found"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Bulk Project Assignment Confirmation"
    print_key_value "Issues" "${valid_issues[*]}"
    print_key_value "Project URL" "$PROJECT_URL"
    
    echo
    print_prompt "Add all issues to project? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Bulk project assignment cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Apply bulk project assignment
    local success_count=0
    local total_count=${#valid_issues[@]}
    
    for issue in "${valid_issues[@]}"; do
        print_status_line "progress" "Adding issue #$issue to project..."
        
        if add_issue_to_project "$issue" >/dev/null 2>&1; then
            print_status_line "success" "Added issue #$issue to project"
            success_count=$((success_count + 1))
        else
            print_status_line "error" "Failed to add issue #$issue to project"
        fi
    done
    
    echo
    print_key_value "Total Issues" "$total_count"
    print_key_value "Successfully Added" "$success_count"
    print_key_value "Failed" "$((total_count - success_count))"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk issue creation from template
bulk_issue_creation() {
    clear_screen true
    print_header "Bulk Issue Creation from Template"
    
    local template_title template_body template_labels template_milestone count
    
    # Get template information
    print_prompt "Enter template title (use {N} for numbering): "
    read -r template_title
    
    if [ -z "$template_title" ]; then
        print_error "Template title cannot be empty"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    print_prompt "Enter template description (use {N} for numbering, press Enter for empty line, type 'END' on new line to finish): "
    template_body=""
    while true; do
        read -r line
        if [ "$line" = "END" ]; then
            break
        fi
        if [ -n "$template_body" ]; then
            template_body="$template_body\n$line"
        else
            template_body="$line"
        fi
    done
    
    print_prompt "Enter template labels (comma-separated, optional): "
    read -r template_labels
    
    print_prompt "Enter template milestone (optional): "
    read -r template_milestone
    
    print_prompt "How many issues to create: "
    read -r count
    
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -eq 0 ]; then
        print_error "Count must be a positive integer"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    if [ "$count" -gt 20 ]; then
        print_error "Maximum 20 issues can be created at once"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Show confirmation
    echo
    print_header "Bulk Issue Creation Confirmation"
    print_key_value "Template Title" "$template_title"
    print_key_value "Template Description" "$(echo -e "$template_body" | head -2 | tr '\n' ' ')..."
    [ -n "$template_labels" ] && print_key_value "Template Labels" "$template_labels"
    [ -n "$template_milestone" ] && print_key_value "Template Milestone" "$template_milestone"
    print_key_value "Number of Issues" "$count"
    
    echo
    print_prompt "Create $count issues from template? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Bulk creation cancelled"
        print_prompt "Press Enter to continue"
        read -r
        return 0
    fi
    
    # Create issues
    local success_count=0
    local created_issues=()
    
    for ((i=1; i<=count; i++)); do
        print_status_line "progress" "Creating issue $i of $count..."
        
        # Replace {N} with current number
        local current_title="${template_title/\{N\}/$i}"
        local current_body="${template_body/\{N\}/$i}"
        
        local create_args=("--title" "$current_title" "--body" "$current_body")
        
        if [ -n "$template_labels" ]; then
            create_args+=("--label" "$template_labels")
        fi
        
        if [ -n "$template_milestone" ]; then
            create_args+=("--milestone" "$template_milestone")
        fi
        
        local issue_number
        if issue_number=$(create_issue_with_args "${create_args[@]}"); then
            print_status_line "success" "Created issue #$issue_number"
            success_count=$((success_count + 1))
            created_issues+=("$issue_number")
        else
            print_status_line "error" "Failed to create issue $i"
        fi
    done
    
    echo
    print_key_value "Total Issues" "$count"
    print_key_value "Successfully Created" "$success_count"
    print_key_value "Failed" "$((count - success_count))"
    
    if [ ${#created_issues[@]} -gt 0 ]; then
        echo
        print_info "Created issues: ${created_issues[*]}"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# List issues with filtering options
list_issues_interactive() {
    clear_screen true
    print_header "List Issues"
    
    echo
    print_menu_option "1" "List All Open Issues"
    print_menu_option "2" "List All Closed Issues"
    print_menu_option "3" "List Issues by Label"
    print_menu_option "4" "List Issues by Milestone"
    print_menu_option "5" "List Issues by Assignee"
    print_menu_option "6" "Custom Filter"
    print_menu_option "7" "Return to Issue Management"
    echo
    
    print_prompt "Select listing option (1-7): "
    read -r choice
    
    local filter_args=()
    local filter_description=""
    
    case "$choice" in
        1)
            filter_args=("--state" "open")
            filter_description="All Open Issues"
            ;;
        2)
            filter_args=("--state" "closed")
            filter_description="All Closed Issues"
            ;;
        3)
            print_prompt "Enter label to filter by: "
            read -r label
            if [ -n "$label" ]; then
                filter_args=("--label" "$label")
                filter_description="Issues with label: $label"
            else
                print_error "No label provided"
                return 0
            fi
            ;;
        4)
            print_prompt "Enter milestone to filter by: "
            read -r milestone
            if [ -n "$milestone" ]; then
                filter_args=("--milestone" "$milestone")
                filter_description="Issues in milestone: $milestone"
            else
                print_error "No milestone provided"
                return 0
            fi
            ;;
        5)
            print_prompt "Enter assignee to filter by: "
            read -r assignee
            if [ -n "$assignee" ]; then
                filter_args=("--assignee" "$assignee")
                filter_description="Issues assigned to: $assignee"
            else
                print_error "No assignee provided"
                return 0
            fi
            ;;
        6)
            print_prompt "Enter custom filter (e.g., --state open --label bug): "
            read -r custom_filter
            if [ -n "$custom_filter" ]; then
                # Split custom filter into array
                read -ra filter_args <<< "$custom_filter"
                filter_description="Custom filter: $custom_filter"
            else
                print_error "No filter provided"
                return 0
            fi
            ;;
        7)
            return 0
            ;;
        *)
            print_error "Invalid option. Please select 1-7."
            sleep 2
            return 0
            ;;
    esac
    
    # List issues
    clear_screen true
    print_header "$filter_description"
    
    print_status_line "progress" "Fetching issues..."
    
    local issues
    if issues=$(gh issue list "${filter_args[@]}" --json number,title,state,labels,milestone,assignees,createdAt --limit 50 2>/dev/null); then
        local issue_count
        issue_count=$(echo "$issues" | jq '. | length' 2>/dev/null)
        
        if [ "$issue_count" -eq 0 ]; then
            print_info "No issues found matching the filter criteria"
        else
            echo
            print_key_value "Total Issues Found" "$issue_count"
            echo
            
            # Display issues in a formatted table
            echo "$issues" | jq -r '.[] | 
                "\(.number)|\(.title)|\(.state)|\(.labels[]?.name // "none" | tostring)|\(.milestone.title // "none")|\(.assignees[]?.login // "none" | tostring)|\(.createdAt)"' 2>/dev/null | \
            while IFS='|' read -r number title state labels milestone assignees created_at; do
                local state_icon
                case "$state" in
                    "open") state_icon="🔴" ;;
                    "closed") state_icon="✅" ;;
                    *) state_icon="❓" ;;
                esac
                
                echo "$state_icon #$number: $title"
                [ "$labels" != "none" ] && echo "   Labels: $labels"
                [ "$milestone" != "none" ] && echo "   Milestone: $milestone"
                [ "$assignees" != "none" ] && echo "   Assignees: $assignees"
                echo "   Created: $(echo "$created_at" | cut -d'T' -f1)"
                echo
            done
        fi
    else
        print_status_line "error" "Failed to fetch issues"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Helper function to validate if an issue exists
validate_issue_exists() {
    local issue_number="$1"
    
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if ! get_repo_context >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    # Try to get issue information
    if gh issue view "$issue_number" --json number >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Cleanup GitHub module
cleanup_github_module() {
    REPO_OWNER=""
    REPO_NAME=""
    BRANCH_NAME=""
    IS_AUTHENTICATED=""
    PROJECT_URL=""
    
    # Clear release context
    CURRENT_VERSION=""
    NEW_VERSION=""
    RELEASE_TYPE=""
    RELEASE_NOTES=""
    RELEASE_TITLE=""
    
    print_info "GitHub CLI integration module cleaned up"
}