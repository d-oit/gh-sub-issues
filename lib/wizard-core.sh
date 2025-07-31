#!/bin/bash

# GitHub Wizard Core Module
# Provides menu navigation, user input handling, and workflow orchestration

# Source display module for UI functions
CORE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CORE_MODULE_DIR/wizard-display.sh"
source "$CORE_MODULE_DIR/wizard-github.sh"

# Error handling configuration
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=2
ERROR_LOG_FILE="${CORE_MODULE_DIR}/../wizard-errors.log"

# Initialize core module logging
init_core_logging() {
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "wizard_core" "Core module initialized"
        log_debug "wizard_core" "Error log file: $ERROR_LOG_FILE"
        log_debug "wizard_core" "Max retry attempts: $MAX_RETRY_ATTEMPTS"
        log_debug "wizard_core" "Retry delay: ${RETRY_DELAY}s"
    fi
}

# Menu state management
CURRENT_MENU="main"
declare -a MENU_HISTORY=()
USER_SELECTION=""
WIZARD_RUNNING=true

# Menu definitions
declare -A MAIN_MENU_OPTIONS=(
    [1]="Status Dashboard"
    [2]="Release Wizard"
    [3]="Issue Management"
    [4]="Configuration"
    [5]="Exit"
)

declare -A STATUS_MENU_OPTIONS=(
    [1]="Repository Status"
    [2]="Issue Summary"
    [3]="Recent Activity"
    [4]="Project Board Status"
    [5]="Return to Main Menu"
)

declare -A RELEASE_MENU_OPTIONS=(
    [1]="Release Wizard (Create/Manage Releases)"
    [2]="View Current Version Information"
    [3]="Check Release Prerequisites"
    [4]="Return to Main Menu"
)

declare -A ISSUE_MENU_OPTIONS=(
    [1]="Create Issue"
    [2]="Update Issue"
    [3]="Link Issues"
    [4]="Bulk Operations"
    [5]="Return to Main Menu"
)

declare -A CONFIG_MENU_OPTIONS=(
    [1]="View Configuration"
    [2]="Update Settings"
    [3]="Test GitHub CLI"
    [4]="Return to Main Menu"
)

# Display and handle main menu
show_main_menu() {
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    log_verbose "show_main_menu" "Displaying main menu"
    clear_screen true
    
    print_header "Main Menu"
    
    echo "Welcome to the GitHub Issue Manager Wizard!"
    echo "Select an option to get started:"
    echo
    
    # Display menu options
    for key in $(printf '%s\n' "${!MAIN_MENU_OPTIONS[@]}" | sort -n); do
        print_menu_option "$key" "${MAIN_MENU_OPTIONS[$key]}"
    done
    
    echo
    print_prompt "Enter your choice (1-5)"
    
    # Handle user input
    read -r USER_SELECTION
    log_debug "show_main_menu" "User selected option: $USER_SELECTION"
    
    case "$USER_SELECTION" in
        1)
            log_info "show_main_menu" "Navigating to status dashboard"
            navigate_to_section "status"
            ;;
        2)
            log_info "show_main_menu" "Navigating to release wizard"
            navigate_to_section "release"
            ;;
        3)
            log_info "show_main_menu" "Navigating to issue management"
            navigate_to_section "issue"
            ;;
        4)
            log_info "show_main_menu" "Navigating to configuration"
            navigate_to_section "config"
            ;;
        5)
            log_info "show_main_menu" "User requested exit"
            exit_wizard
            ;;
        *)
            log_warn "show_main_menu" "Invalid menu selection: $USER_SELECTION"
            if ! handle_user_input "$USER_SELECTION" "1-5" "main_menu"; then
                show_main_menu
            fi
            ;;
    esac
    
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "show_main_menu" "$start_time"
    fi
}

# Navigate to a specific section
navigate_to_section() {
    local section="$1"
    local start_time
    if command -v date >/dev/null 2>&1; then
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
    fi
    
    log_verbose "navigate_to_section" "Navigating from '$CURRENT_MENU' to '$section'"
    
    # Add current menu to history for return navigation
    MENU_HISTORY+=("$CURRENT_MENU")
    CURRENT_MENU="$section"
    
    log_debug "navigate_to_section" "Menu history: ${MENU_HISTORY[*]}"
    log_debug "navigate_to_section" "Current menu set to: $CURRENT_MENU"
    
    case "$section" in
        "status")
            log_info "navigate_to_section" "Showing status dashboard"
            show_status_menu
            ;;
        "release")
            log_info "navigate_to_section" "Showing release wizard"
            show_release_menu
            ;;
        "issue")
            log_info "navigate_to_section" "Showing issue management"
            show_issue_menu
            ;;
        "config")
            log_info "navigate_to_section" "Showing configuration menu"
            show_config_menu
            ;;
        "main")
            log_info "navigate_to_section" "Returning to main menu"
            show_main_menu
            ;;
        *)
            log_error "navigate_to_section" "Unknown section requested: $section"
            print_error "Unknown section: $section"
            return_to_main
            ;;
    esac
    
    if [ "$ENABLE_LOGGING" = "true" ] && [ -n "$start_time" ]; then
        log_timing "navigate_to_section" "$start_time"
    fi
}

# Display status dashboard menu
show_status_menu() {
    clear_screen true
    
    print_header "Status Dashboard"
    
    echo "View repository and project status information:"
    echo
    
    # Display menu options
    for key in $(printf '%s\n' "${!STATUS_MENU_OPTIONS[@]}" | sort -n); do
        print_menu_option "$key" "${STATUS_MENU_OPTIONS[$key]}"
    done
    
    echo
    print_prompt "Enter your choice (1-5)"
    
    read -r USER_SELECTION
    
    case "$USER_SELECTION" in
        1)
            display_repo_status
            show_status_menu
            ;;
        2)
            clear_screen true
            print_header "Issue Summary"
            get_issue_stats
            echo
            print_prompt "Press Enter to continue"
            read -r
            show_status_menu
            ;;
        3)
            clear_screen true
            print_header "Recent Activity"
            get_recent_activity
            echo
            print_prompt "Press Enter to continue"
            read -r
            show_status_menu
            ;;
        4)
            clear_screen true
            print_header "Project Board Status"
            get_project_status
            echo
            print_prompt "Press Enter to continue"
            read -r
            show_status_menu
            ;;
        5)
            return_to_main
            ;;
        *)
            if ! handle_user_input "$USER_SELECTION" "1-5" "status_menu"; then
                show_status_menu
            fi
            ;;
    esac
}

# Display release wizard menu
show_release_menu() {
    clear_screen true
    
    print_header "Release Wizard"
    
    echo "Manage releases and version control:"
    echo
    
    # Display menu options
    for key in $(printf '%s\n' "${!RELEASE_MENU_OPTIONS[@]}" | sort -n); do
        print_menu_option "$key" "${RELEASE_MENU_OPTIONS[$key]}"
    done
    
    echo
    print_prompt "Enter your choice (1-4)"
    
    read -r USER_SELECTION
    
    case "$USER_SELECTION" in
        1)
            # Call the interactive release wizard
            interactive_release_wizard
            show_release_menu
            ;;
        2)
            # View current version information
            view_current_version_interactive
            show_release_menu
            ;;
        3)
            # Check release prerequisites
            check_release_prerequisites_interactive
            show_release_menu
            ;;
        4)
            return_to_main
            ;;
        *)
            if ! handle_user_input "$USER_SELECTION" "1-4" "release_menu"; then
                show_release_menu
            fi
            ;;
    esac
}

# Display issue management menu
show_issue_menu() {
    clear_screen true
    
    print_header "Issue Management"
    
    echo "Create, update, and manage GitHub issues:"
    echo
    
    # Display menu options
    for key in $(printf '%s\n' "${!ISSUE_MENU_OPTIONS[@]}" | sort -n); do
        print_menu_option "$key" "${ISSUE_MENU_OPTIONS[$key]}"
    done
    
    echo
    print_prompt "Enter your choice (1-5)"
    
    read -r USER_SELECTION
    
    case "$USER_SELECTION" in
        1)
            # Create Issue workflow
            execute_create_issue_workflow
            show_issue_menu
            ;;
        2)
            # Update Issue workflow
            execute_update_issue_workflow
            show_issue_menu
            ;;
        3)
            # Link Issues workflow
            execute_link_issues_workflow
            show_issue_menu
            ;;
        4)
            # Bulk Operations workflow
            execute_bulk_operations_workflow
            show_issue_menu
            ;;
        5)
            return_to_main
            ;;
        *)
            if ! handle_user_input "$USER_SELECTION" "1-5" "issue_menu"; then
                show_issue_menu
            fi
            ;;
    esac
}

# Display configuration menu
show_config_menu() {
    clear_screen true
    
    print_header "Configuration"
    
    echo "Manage wizard settings and GitHub CLI configuration:"
    echo
    
    # Display menu options
    for key in $(printf '%s\n' "${!CONFIG_MENU_OPTIONS[@]}" | sort -n); do
        print_menu_option "$key" "${CONFIG_MENU_OPTIONS[$key]}"
    done
    
    echo
    print_prompt "Enter your choice (1-4)"
    
    read -r USER_SELECTION
    
    case "$USER_SELECTION" in
        1)
            # View Configuration
            execute_view_configuration
            show_config_menu
            ;;
        2)
            # Update Settings
            execute_update_settings
            show_config_menu
            ;;
        3)
            clear_screen true
            print_header "GitHub CLI Test"
            
            print_info "Testing GitHub CLI connectivity and authentication..."
            echo
            
            if check_gh_auth; then
                echo
                if test_gh_connectivity; then
                    echo
                    print_success "GitHub CLI test completed successfully"
                else
                    print_error "GitHub CLI connectivity test failed"
                fi
            else
                print_error "GitHub CLI authentication test failed"
            fi
            
            echo
            print_prompt "Press Enter to continue"
            read -r
            show_config_menu
            ;;
        4)
            return_to_main
            ;;
        *)
            if ! handle_user_input "$USER_SELECTION" "1-4" "config_menu"; then
                show_config_menu
            fi
            ;;
    esac
}

# Handle user input with validation (enhanced with error handling)
handle_user_input() {
    local input="$1"
    local valid_options="$2"
    local menu_context="${3:-main}"
    
    # Use enhanced validation with error handling
    if validate_input_with_guidance "$input" "menu_option" "$valid_options" "$menu_context"; then
        return 0
    else
        return 1
    fi
}

# Return to main menu
return_to_main() {
    # Clear menu history and reset to main
    MENU_HISTORY=()
    CURRENT_MENU="main"
    show_main_menu
}

# Navigate back to previous menu
navigate_back() {
    if [[ ${#MENU_HISTORY[@]} -gt 0 ]]; then
        # Get the last menu from history
        local previous_menu="${MENU_HISTORY[-1]}"
        # Remove it from history
        unset 'MENU_HISTORY[-1]'
        # Navigate to previous menu
        CURRENT_MENU="$previous_menu"
        navigate_to_section "$previous_menu"
    else
        # If no history, go to main menu
        return_to_main
    fi
}

# Exit wizard with confirmation
exit_wizard() {
    clear_screen
    
    print_header "Exit Wizard"
    
    print_confirmation "Are you sure you want to exit the GitHub Wizard?" "n"
    read -r confirmation
    
    case "$confirmation" in
        [Yy]|[Yy][Ee][Ss])
            print_success "Thank you for using the GitHub Issue Manager Wizard!"
            echo "Goodbye!"
            WIZARD_RUNNING=false
            exit 0
            ;;
        *)
            print_info "Returning to main menu..."
            sleep 1
            show_main_menu
            ;;
    esac
}

# Execute workflow with cross-module integration
execute_workflow() {
    local workflow_type="$1"
    local workflow_data="$2"
    
    export CURRENT_WORKFLOW="$workflow_type"
    export WORKFLOW_CONTEXT="$workflow_data"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "execute_workflow" "Starting workflow: $workflow_type"
    fi
    
    case "$workflow_type" in
        "status")
            execute_status_workflow "$workflow_data"
            ;;
        "release")
            execute_release_workflow "$workflow_data"
            ;;
        "issue")
            execute_issue_workflow "$workflow_data"
            ;;
        *)
            print_warning "Unknown workflow type: $workflow_type"
            export OPERATION_RESULT="error"
            return 1
            ;;
    esac
    
    export LAST_OPERATION="$workflow_type"
    
    if [ "$ENABLE_LOGGING" = "true" ]; then
        log_info "execute_workflow" "Completed workflow: $workflow_type (Result: ${OPERATION_RESULT:-success})"
    fi
}

# Issue Management Workflows

# Execute create issue workflow
execute_create_issue_workflow() {
    clear_screen true
    print_header "Create New Issue"
    
    # Get issue details from user
    print_prompt "Enter issue title"
    read -r issue_title
    
    if [ -z "$issue_title" ]; then
        print_error "Issue title is required"
        sleep 2
        return 1
    fi
    
    print_prompt "Enter issue description (press Enter twice to finish)"
    local issue_body=""
    local line
    local empty_lines=0
    
    while true; do
        read -r line
        if [ -z "$line" ]; then
            ((empty_lines++))
            if [ $empty_lines -ge 2 ]; then
                break
            fi
            issue_body="$issue_body"$'\n'
        else
            empty_lines=0
            if [ -n "$issue_body" ]; then
                issue_body="$issue_body"$'\n'"$line"
            else
                issue_body="$line"
            fi
        fi
    done
    
    print_prompt "Enter labels (comma-separated, optional)"
    read -r issue_labels
    
    # Create the issue using GitHub module
    print_status_line "progress" "Creating issue..."
    
    local issue_number
    if issue_number=$(create_github_issue "$issue_title" "$issue_body" "$issue_labels" "" "false"); then
        print_success "Issue #$issue_number created successfully"
        
        # Add to project if configured
        if [ -n "${PROJECT_URL:-}" ]; then
            add_issue_to_project "$issue_number"
        fi
        
        export OPERATION_RESULT="success"
        export LAST_CREATED_ISSUE="$issue_number"
    else
        print_error "Failed to create issue"
        export OPERATION_RESULT="error"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Execute update issue workflow
execute_update_issue_workflow() {
    clear_screen true
    print_header "Update Issue"
    
    print_prompt "Enter issue number to update"
    read -r issue_number
    
    if [ -z "$issue_number" ] || ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
        print_error "Valid issue number is required"
        sleep 2
        return 1
    fi
    
    # Show current issue details
    print_status_line "progress" "Fetching issue details..."
    
    if gh issue view "$issue_number" --json title,body,state,labels >/dev/null 2>&1; then
        print_info "Current issue details:"
        gh issue view "$issue_number"
        echo
    else
        print_error "Issue #$issue_number not found"
        sleep 2
        return 1
    fi
    
    # Get update options
    echo "What would you like to update?"
    print_menu_option "1" "Title"
    print_menu_option "2" "Body/Description"
    print_menu_option "3" "Labels"
    print_menu_option "4" "State (open/close)"
    echo
    
    print_prompt "Enter your choice (1-4)"
    read -r update_choice
    
    case "$update_choice" in
        1)
            print_prompt "Enter new title"
            read -r new_title
            if [ -n "$new_title" ]; then
                update_github_issue "$issue_number" --title "$new_title"
            fi
            ;;
        2)
            print_prompt "Enter new description (press Enter twice to finish)"
            local new_body=""
            local line
            local empty_lines=0
            
            while true; do
                read -r line
                if [ -z "$line" ]; then
                    ((empty_lines++))
                    if [ $empty_lines -ge 2 ]; then
                        break
                    fi
                    new_body="$new_body"$'\n'
                else
                    empty_lines=0
                    if [ -n "$new_body" ]; then
                        new_body="$new_body"$'\n'"$line"
                    else
                        new_body="$line"
                    fi
                fi
            done
            
            if [ -n "$new_body" ]; then
                update_github_issue "$issue_number" --body "$new_body"
            fi
            ;;
        3)
            print_prompt "Enter new labels (comma-separated)"
            read -r new_labels
            if [ -n "$new_labels" ]; then
                # Clear existing labels and add new ones
                update_github_issue "$issue_number" --add-label "$new_labels"
            fi
            ;;
        4)
            print_confirmation "Close this issue?" "n"
            read -r close_choice
            case "$close_choice" in
                [Yy]|[Yy][Ee][Ss])
                    gh issue close "$issue_number"
                    print_success "Issue #$issue_number closed"
                    ;;
                *)
                    gh issue reopen "$issue_number" 2>/dev/null
                    print_success "Issue #$issue_number reopened"
                    ;;
            esac
            ;;
        *)
            print_error "Invalid choice"
            sleep 2
            return 1
            ;;
    esac
    
    export OPERATION_RESULT="success"
    export LAST_UPDATED_ISSUE="$issue_number"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Execute link issues workflow
execute_link_issues_workflow() {
    clear_screen true
    print_header "Link Issues (Parent-Child Relationship)"
    
    print_prompt "Enter parent issue number"
    read -r parent_issue
    
    if [ -z "$parent_issue" ] || ! [[ "$parent_issue" =~ ^[0-9]+$ ]]; then
        print_error "Valid parent issue number is required"
        sleep 2
        return 1
    fi
    
    print_prompt "Enter child issue number"
    read -r child_issue
    
    if [ -z "$child_issue" ] || ! [[ "$child_issue" =~ ^[0-9]+$ ]]; then
        print_error "Valid child issue number is required"
        sleep 2
        return 1
    fi
    
    if [ "$parent_issue" = "$child_issue" ]; then
        print_error "Parent and child issues cannot be the same"
        sleep 2
        return 1
    fi
    
    # Verify both issues exist
    if ! gh issue view "$parent_issue" >/dev/null 2>&1; then
        print_error "Parent issue #$parent_issue not found"
        sleep 2
        return 1
    fi
    
    if ! gh issue view "$child_issue" >/dev/null 2>&1; then
        print_error "Child issue #$child_issue not found"
        sleep 2
        return 1
    fi
    
    # Show issue details for confirmation
    echo "Parent Issue:"
    gh issue view "$parent_issue" --json title --template "  #{{.number}}: {{.title}}"
    echo
    echo "Child Issue:"
    gh issue view "$child_issue" --json title --template "  #{{.number}}: {{.title}}"
    echo
    
    print_confirmation "Link these issues?" "y"
    read -r confirm_link
    
    case "$confirm_link" in
        [Yy]|[Yy][Ee][Ss])
            if link_issues "$parent_issue" "$child_issue"; then
                export OPERATION_RESULT="success"
                export LAST_LINKED_ISSUES="$parent_issue,$child_issue"
            else
                export OPERATION_RESULT="error"
            fi
            ;;
        *)
            print_info "Link operation cancelled"
            export OPERATION_RESULT="cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Execute bulk operations workflow
execute_bulk_operations_workflow() {
    clear_screen true
    print_header "Bulk Issue Operations"
    
    echo "Available bulk operations:"
    print_menu_option "1" "Close multiple issues"
    print_menu_option "2" "Add labels to multiple issues"
    print_menu_option "3" "Add multiple issues to project"
    print_menu_option "4" "Create multiple related issues"
    echo
    
    print_prompt "Enter your choice (1-4)"
    read -r bulk_choice
    
    case "$bulk_choice" in
        1)
            execute_bulk_close_issues
            ;;
        2)
            execute_bulk_add_labels
            ;;
        3)
            execute_bulk_add_to_project
            ;;
        4)
            execute_bulk_create_issues
            ;;
        *)
            print_error "Invalid choice"
            sleep 2
            return 1
            ;;
    esac
}

# Bulk close issues
execute_bulk_close_issues() {
    print_prompt "Enter issue numbers to close (space-separated)"
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        sleep 2
        return 1
    fi
    
    local issues_array=($issue_numbers)
    local closed_count=0
    local failed_count=0
    
    print_confirmation "Close ${#issues_array[@]} issues?" "n"
    read -r confirm_bulk
    
    case "$confirm_bulk" in
        [Yy]|[Yy][Ee][Ss])
            for issue_num in "${issues_array[@]}"; do
                if [[ "$issue_num" =~ ^[0-9]+$ ]]; then
                    if gh issue close "$issue_num" >/dev/null 2>&1; then
                        print_status_line "success" "Closed issue #$issue_num"
                        ((closed_count++))
                    else
                        print_status_line "error" "Failed to close issue #$issue_num"
                        ((failed_count++))
                    fi
                else
                    print_status_line "warning" "Invalid issue number: $issue_num"
                    ((failed_count++))
                fi
            done
            
            print_success "Bulk close completed: $closed_count closed, $failed_count failed"
            export OPERATION_RESULT="success"
            ;;
        *)
            print_info "Bulk close cancelled"
            export OPERATION_RESULT="cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk add labels
execute_bulk_add_labels() {
    print_prompt "Enter issue numbers (space-separated)"
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        sleep 2
        return 1
    fi
    
    print_prompt "Enter labels to add (comma-separated)"
    read -r labels
    
    if [ -z "$labels" ]; then
        print_error "No labels provided"
        sleep 2
        return 1
    fi
    
    local issues_array=($issue_numbers)
    local success_count=0
    local failed_count=0
    
    print_confirmation "Add labels '$labels' to ${#issues_array[@]} issues?" "n"
    read -r confirm_bulk
    
    case "$confirm_bulk" in
        [Yy]|[Yy][Ee][Ss])
            for issue_num in "${issues_array[@]}"; do
                if [[ "$issue_num" =~ ^[0-9]+$ ]]; then
                    if gh issue edit "$issue_num" --add-label "$labels" >/dev/null 2>&1; then
                        print_status_line "success" "Added labels to issue #$issue_num"
                        ((success_count++))
                    else
                        print_status_line "error" "Failed to add labels to issue #$issue_num"
                        ((failed_count++))
                    fi
                else
                    print_status_line "warning" "Invalid issue number: $issue_num"
                    ((failed_count++))
                fi
            done
            
            print_success "Bulk label operation completed: $success_count succeeded, $failed_count failed"
            export OPERATION_RESULT="success"
            ;;
        *)
            print_info "Bulk label operation cancelled"
            export OPERATION_RESULT="cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk add to project
execute_bulk_add_to_project() {
    if [ -z "${PROJECT_URL:-}" ]; then
        print_error "PROJECT_URL not configured"
        print_info "Set PROJECT_URL environment variable to enable project operations"
        sleep 3
        return 1
    fi
    
    print_prompt "Enter issue numbers to add to project (space-separated)"
    read -r issue_numbers
    
    if [ -z "$issue_numbers" ]; then
        print_error "No issue numbers provided"
        sleep 2
        return 1
    fi
    
    local issues_array=($issue_numbers)
    local success_count=0
    local failed_count=0
    
    print_confirmation "Add ${#issues_array[@]} issues to project?" "n"
    read -r confirm_bulk
    
    case "$confirm_bulk" in
        [Yy]|[Yy][Ee][Ss])
            for issue_num in "${issues_array[@]}"; do
                if [[ "$issue_num" =~ ^[0-9]+$ ]]; then
                    if add_issue_to_project "$issue_num"; then
                        ((success_count++))
                    else
                        ((failed_count++))
                    fi
                else
                    print_status_line "warning" "Invalid issue number: $issue_num"
                    ((failed_count++))
                fi
            done
            
            print_success "Bulk project operation completed: $success_count succeeded, $failed_count failed"
            export OPERATION_RESULT="success"
            ;;
        *)
            print_info "Bulk project operation cancelled"
            export OPERATION_RESULT="cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Bulk create related issues
execute_bulk_create_issues() {
    print_prompt "Enter parent issue number (optional, press Enter to skip)"
    read -r parent_issue
    
    print_prompt "Enter number of issues to create"
    read -r issue_count
    
    if [ -z "$issue_count" ] || ! [[ "$issue_count" =~ ^[0-9]+$ ]] || [ "$issue_count" -lt 1 ] || [ "$issue_count" -gt 10 ]; then
        print_error "Please enter a number between 1 and 10"
        sleep 2
        return 1
    fi
    
    print_prompt "Enter common title prefix"
    read -r title_prefix
    
    if [ -z "$title_prefix" ]; then
        print_error "Title prefix is required"
        sleep 2
        return 1
    fi
    
    print_prompt "Enter common labels (comma-separated, optional)"
    read -r common_labels
    
    local created_issues=()
    local failed_count=0
    
    print_confirmation "Create $issue_count issues with prefix '$title_prefix'?" "n"
    read -r confirm_bulk
    
    case "$confirm_bulk" in
        [Yy]|[Yy][Ee][Ss])
            for ((i=1; i<=issue_count; i++)); do
                local issue_title="$title_prefix $i"
                local issue_body="Auto-generated issue $i of $issue_count"
                
                if [ -n "$parent_issue" ] && [[ "$parent_issue" =~ ^[0-9]+$ ]]; then
                    issue_body="$issue_body"$'\n\n'"Related to #$parent_issue"
                fi
                
                local new_issue_number
                if new_issue_number=$(create_github_issue "$issue_title" "$issue_body" "$common_labels" "" "true"); then
                    created_issues+=("$new_issue_number")
                    print_status_line "success" "Created issue #$new_issue_number: $issue_title"
                    
                    # Link to parent if specified
                    if [ -n "$parent_issue" ] && [[ "$parent_issue" =~ ^[0-9]+$ ]]; then
                        link_issues "$parent_issue" "$new_issue_number" >/dev/null 2>&1
                    fi
                    
                    # Add to project if configured
                    if [ -n "${PROJECT_URL:-}" ]; then
                        add_issue_to_project "$new_issue_number" >/dev/null 2>&1
                    fi
                else
                    print_status_line "error" "Failed to create issue: $issue_title"
                    ((failed_count++))
                fi
            done
            
            print_success "Bulk create completed: ${#created_issues[@]} created, $failed_count failed"
            export OPERATION_RESULT="success"
            export LAST_CREATED_ISSUES="${created_issues[*]}"
            ;;
        *)
            print_info "Bulk create cancelled"
            export OPERATION_RESULT="cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Get current menu context
get_current_menu() {
    echo "$CURRENT_MENU"
}

# Get menu history
get_menu_history() {
    printf '%s\n' "${MENU_HISTORY[@]}"
}

# Check if wizard is running
is_wizard_running() {
    [[ "$WIZARD_RUNNING" == "true" ]]
}

# Get wizard running status as string (for display purposes)
get_wizard_status() {
    if [[ "$WIZARD_RUNNING" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Initialize wizard core
init_wizard_core() {
    CURRENT_MENU="main"
    MENU_HISTORY=()
    USER_SELECTION=""
    WIZARD_RUNNING=true
    
    print_info "GitHub Wizard Core initialized successfully"
}

# Cleanup wizard core
cleanup_wizard_core() {
    CURRENT_MENU=""
    MENU_HISTORY=()
    USER_SELECTION=""
    WIZARD_RUNNING=false
    
    print_info "GitHub Wizard Core cleaned up"
}

# ============================================================================
# ERROR HANDLING SYSTEM
# ============================================================================

# Main error handling function with categorization
handle_error() {
    local error_type="$1"
    local error_message="$2"
    local recovery_action="${3:-}"
    local context="${4:-unknown}"
    
    # Log error for debugging
    log_error "$error_type" "$error_message" "$context"
    
    case "$error_type" in
        "auth")
            handle_auth_error "$error_message" "$recovery_action"
            ;;
        "network")
            handle_network_error "$error_message" "$recovery_action"
            ;;
        "input")
            handle_input_error "$error_message" "$recovery_action"
            ;;
        "dependency")
            handle_dependency_error "$error_message" "$recovery_action"
            ;;
        "github")
            handle_github_error "$error_message" "$recovery_action"
            ;;
        "config")
            handle_config_error "$error_message" "$recovery_action"
            ;;
        *)
            handle_generic_error "$error_type" "$error_message" "$recovery_action"
            ;;
    esac
}

# Handle authentication errors
handle_auth_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    clear_screen
    print_header "Authentication Error"
    print_error "Authentication required: $error_message"
    echo
    
    case "$recovery_action" in
        "setup_auth")
            offer_auth_setup
            ;;
        "retry_auth")
            offer_auth_retry
            ;;
        *)
            offer_auth_setup
            ;;
    esac
}

# Handle network errors with retry logic
handle_network_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Network error: $error_message"
    echo
    
    case "$recovery_action" in
        "retry")
            offer_retry_operation
            ;;
        "timeout")
            handle_timeout_error "$error_message"
            ;;
        *)
            offer_retry_operation
            ;;
    esac
}

# Handle input validation errors
handle_input_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Invalid input: $error_message"
    echo
    
    case "$recovery_action" in
        "correction")
            offer_input_correction
            ;;
        "menu_retry")
            print_info "Please select a valid menu option"
            ;;
        *)
            offer_input_correction
            ;;
    esac
}

# Handle dependency errors
handle_dependency_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Missing dependency: $error_message"
    echo
    
    case "$recovery_action" in
        "install_guide")
            offer_installation_guide "$error_message"
            ;;
        "check_deps")
            offer_dependency_check
            ;;
        *)
            offer_installation_guide "$error_message"
            ;;
    esac
}

# Handle GitHub-specific errors
handle_github_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "GitHub operation failed: $error_message"
    echo
    
    case "$recovery_action" in
        "rate_limit")
            handle_rate_limit_error
            ;;
        "permissions")
            handle_permissions_error
            ;;
        "not_found")
            handle_not_found_error "$error_message"
            ;;
        *)
            offer_retry_operation
            ;;
    esac
}

# Handle configuration errors
handle_config_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Configuration error: $error_message"
    echo
    
    case "$recovery_action" in
        "setup_config")
            offer_config_setup
            ;;
        "validate_config")
            offer_config_validation
            ;;
        *)
            offer_config_setup
            ;;
    esac
}

# Handle generic errors
handle_generic_error() {
    local error_type="$1"
    local error_message="$2"
    local recovery_action="$3"
    
    print_error "Error ($error_type): $error_message"
    echo
    
    print_info "Available options:"
    print_menu_option "1" "Retry operation"
    print_menu_option "2" "Return to main menu"
    print_menu_option "3" "Exit wizard"
    echo
    
    print_prompt "Enter your choice (1-3)"
    read -r error_choice
    
    case "$error_choice" in
        1)
            return 0  # Allow retry
            ;;
        2)
            return_to_main
            ;;
        3)
            exit_wizard
            ;;
        *)
            print_warning "Invalid choice, returning to main menu"
            return_to_main
            ;;
    esac
}

# ============================================================================
# ERROR RECOVERY FUNCTIONS
# ============================================================================

# Offer authentication setup
offer_auth_setup() {
    print_info "GitHub CLI authentication is required"
    echo
    print_info "To authenticate with GitHub CLI:"
    echo "  1. Run: gh auth login"
    echo "  2. Follow the prompts to authenticate"
    echo "  3. Return to the wizard"
    echo
    
    print_confirmation "Would you like to run 'gh auth login' now?" "y"
    read -r auth_choice
    
    case "$auth_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_status_line "progress" "Starting GitHub CLI authentication..."
            if gh auth login; then
                print_success "Authentication completed successfully"
                return 0
            else
                print_error "Authentication failed"
                return 1
            fi
            ;;
        *)
            print_info "Please authenticate manually and restart the wizard"
            return 1
            ;;
    esac
}

# Offer authentication retry
offer_auth_retry() {
    print_info "Checking authentication status..."
    
    if check_gh_auth; then
        print_success "Authentication is now valid"
        return 0
    else
        print_warning "Authentication still invalid"
        offer_auth_setup
        return $?
    fi
}

# Offer retry operation with backoff
offer_retry_operation() {
    local attempt_count="${RETRY_ATTEMPT_COUNT:-1}"
    
    if [ "$attempt_count" -ge "$MAX_RETRY_ATTEMPTS" ]; then
        print_error "Maximum retry attempts ($MAX_RETRY_ATTEMPTS) reached"
        print_info "Available options:"
        print_menu_option "1" "Return to main menu"
        print_menu_option "2" "Exit wizard"
        echo
        
        print_prompt "Enter your choice (1-2)"
        read -r max_retry_choice
        
        case "$max_retry_choice" in
            1)
                return_to_main
                ;;
            2)
                exit_wizard
                ;;
            *)
                return_to_main
                ;;
        esac
        return 1
    fi
    
    print_info "Retry options:"
    print_menu_option "1" "Retry now (attempt $((attempt_count + 1))/$MAX_RETRY_ATTEMPTS)"
    print_menu_option "2" "Wait and retry (${RETRY_DELAY}s delay)"
    print_menu_option "3" "Return to main menu"
    echo
    
    print_prompt "Enter your choice (1-3)"
    read -r retry_choice
    
    case "$retry_choice" in
        1)
            export RETRY_ATTEMPT_COUNT=$((attempt_count + 1))
            return 0
            ;;
        2)
            print_status_line "progress" "Waiting ${RETRY_DELAY} seconds before retry..."
            sleep "$RETRY_DELAY"
            export RETRY_ATTEMPT_COUNT=$((attempt_count + 1))
            return 0
            ;;
        3)
            return_to_main
            return 1
            ;;
        *)
            print_warning "Invalid choice, returning to main menu"
            return_to_main
            return 1
            ;;
    esac
}

# Handle timeout errors
handle_timeout_error() {
    local error_message="$1"
    
    print_warning "Operation timed out: $error_message"
    print_info "This might be due to network connectivity or GitHub API issues"
    echo
    
    offer_retry_operation
}

# Offer input correction
offer_input_correction() {
    print_info "Please check your input and try again"
    print_info "Common issues:"
    echo "  • Menu options: Enter a number from the available range"
    echo "  • Issue numbers: Enter positive integers only"
    echo "  • Text input: Avoid special characters that might cause issues"
    echo
    
    print_prompt "Press Enter to continue"
    read -r
}

# Offer installation guide
offer_installation_guide() {
    local missing_tool="$1"
    
    case "$missing_tool" in
        *"gh"*|*"GitHub CLI"*)
            print_info "GitHub CLI installation guide:"
            echo "  • macOS: brew install gh"
            echo "  • Ubuntu/Debian: sudo apt install gh"
            echo "  • Windows: winget install GitHub.cli"
            echo "  • Or visit: https://cli.github.com/"
            ;;
        *"git"*)
            print_info "Git installation guide:"
            echo "  • macOS: brew install git"
            echo "  • Ubuntu/Debian: sudo apt install git"
            echo "  • Windows: Download from https://git-scm.com/"
            ;;
        *"jq"*)
            print_info "jq installation guide:"
            echo "  • macOS: brew install jq"
            echo "  • Ubuntu/Debian: sudo apt install jq"
            echo "  • Windows: Download from https://stedolan.github.io/jq/"
            ;;
        *)
            print_info "Please install the required dependency: $missing_tool"
            print_info "Check your system's package manager or the tool's official website"
            ;;
    esac
    
    echo
    print_confirmation "Have you installed the missing dependency?" "n"
    read -r install_choice
    
    case "$install_choice" in
        [Yy]|[Yy][Ee][Ss])
            offer_dependency_check
            ;;
        *)
            print_info "Please install the dependency and restart the wizard"
            exit 1
            ;;
    esac
}

# Offer dependency check
offer_dependency_check() {
    print_status_line "progress" "Checking dependencies..."
    
    local missing_deps=()
    
    # Check GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("GitHub CLI (gh)")
    fi
    
    # Check git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("Git")
    fi
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All dependencies are available"
        return 0
    else
        print_error "Missing dependencies: ${missing_deps[*]}"
        for dep in "${missing_deps[@]}"; do
            offer_installation_guide "$dep"
        done
        return 1
    fi
}

# Handle rate limit errors
handle_rate_limit_error() {
    print_warning "GitHub API rate limit exceeded"
    print_info "Rate limits reset every hour"
    echo
    
    # Try to get rate limit info
    if command -v gh >/dev/null 2>&1; then
        print_info "Current rate limit status:"
        gh api rate_limit 2>/dev/null | jq -r '.rate | "Remaining: \(.remaining)/\(.limit), Resets at: \(.reset | strftime("%Y-%m-%d %H:%M:%S"))"' 2>/dev/null || echo "Unable to fetch rate limit details"
    fi
    
    echo
    print_info "Options:"
    print_menu_option "1" "Wait and retry in 5 minutes"
    print_menu_option "2" "Return to main menu"
    print_menu_option "3" "Exit wizard"
    echo
    
    print_prompt "Enter your choice (1-3)"
    read -r rate_choice
    
    case "$rate_choice" in
        1)
            print_status_line "progress" "Waiting 5 minutes for rate limit reset..."
            sleep 300
            return 0
            ;;
        2)
            return_to_main
            ;;
        3)
            exit_wizard
            ;;
        *)
            return_to_main
            ;;
    esac
}

# Handle permissions errors
handle_permissions_error() {
    print_error "Insufficient permissions for this operation"
    print_info "This might be due to:"
    echo "  • Repository access permissions"
    echo "  • GitHub token scope limitations"
    echo "  • Organization restrictions"
    echo
    
    print_info "Possible solutions:"
    echo "  1. Check repository permissions in GitHub"
    echo "  2. Re-authenticate with broader scopes: gh auth refresh -s repo,project"
    echo "  3. Contact repository administrator"
    echo
    
    print_confirmation "Would you like to try re-authenticating?" "n"
    read -r reauth_choice
    
    case "$reauth_choice" in
        [Yy]|[Yy][Ee][Ss])
            if gh auth refresh -s repo,project; then
                print_success "Re-authentication completed"
                return 0
            else
                print_error "Re-authentication failed"
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Handle not found errors
handle_not_found_error() {
    local error_message="$1"
    
    print_error "Resource not found: $error_message"
    print_info "This might be due to:"
    echo "  • Incorrect issue/PR number"
    echo "  • Resource was deleted"
    echo "  • Insufficient permissions to view"
    echo
    
    print_confirmation "Would you like to try a different resource?" "y"
    read -r retry_choice
    
    case "$retry_choice" in
        [Yy]|[Yy][Ee][Ss])
            return 0  # Allow retry with different input
            ;;
        *)
            return 1
            ;;
    esac
}

# Offer configuration setup
offer_config_setup() {
    print_info "Configuration setup required"
    print_info "The wizard needs proper configuration to function"
    echo
    
    print_info "Configuration options:"
    print_menu_option "1" "Create basic configuration"
    print_menu_option "2" "Load existing configuration"
    print_menu_option "3" "Manual configuration guide"
    print_menu_option "4" "Return to main menu"
    echo
    
    print_prompt "Enter your choice (1-4)"
    read -r config_choice
    
    case "$config_choice" in
        1)
            create_basic_config
            ;;
        2)
            load_existing_config
            ;;
        3)
            show_manual_config_guide
            ;;
        4)
            return_to_main
            ;;
        *)
            print_warning "Invalid choice, returning to main menu"
            return_to_main
            ;;
    esac
}

# Offer configuration validation
offer_config_validation() {
    print_status_line "progress" "Validating configuration..."
    
    local config_issues=()
    
    # Check for .env file
    if [ ! -f ".env" ]; then
        config_issues+=("Missing .env file")
    fi
    
    # Check PROJECT_URL if needed
    if [ -z "${PROJECT_URL:-}" ]; then
        config_issues+=("PROJECT_URL not set (optional for project board features)")
    fi
    
    # Check GitHub CLI auth
    if ! check_gh_auth >/dev/null 2>&1; then
        config_issues+=("GitHub CLI not authenticated")
    fi
    
    if [ ${#config_issues[@]} -eq 0 ]; then
        print_success "Configuration validation passed"
        return 0
    else
        print_warning "Configuration issues found:"
        for issue in "${config_issues[@]}"; do
            echo "  • $issue"
        done
        echo
        
        print_confirmation "Would you like to fix these issues?" "y"
        read -r fix_choice
        
        case "$fix_choice" in
            [Yy]|[Yy][Ee][Ss])
                offer_config_setup
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# Create basic configuration
create_basic_config() {
    print_status_line "progress" "Creating basic configuration..."
    
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
# GitHub Wizard Configuration
# Enable logging (true/false)
ENABLE_LOGGING=true

# Project board URL (optional)
# PROJECT_URL=https://github.com/users/username/projects/1

# Log level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL=INFO
EOF
        print_success "Created .env file with basic configuration"
    else
        print_info ".env file already exists"
    fi
    
    # Source the new configuration
    if [ -f ".env" ]; then
        source .env
        print_success "Configuration loaded successfully"
    fi
}

# Load existing configuration
load_existing_config() {
    print_status_line "progress" "Loading existing configuration..."
    
    if [ -f ".env" ]; then
        source .env
        print_success "Configuration loaded from .env file"
        
        # Show current configuration
        print_info "Current configuration:"
        echo "  • Logging: ${ENABLE_LOGGING:-false}"
        echo "  • Log Level: ${LOG_LEVEL:-INFO}"
        echo "  • Project URL: ${PROJECT_URL:-not set}"
    else
        print_error "No .env file found"
        print_info "Would you like to create one?"
        create_basic_config
    fi
}

# Show manual configuration guide
show_manual_config_guide() {
    clear_screen
    print_header "Manual Configuration Guide"
    
    echo "The GitHub Wizard uses environment variables for configuration."
    echo "Create a .env file in your project root with the following options:"
    echo
    echo "# Required settings"
    echo "ENABLE_LOGGING=true"
    echo "LOG_LEVEL=INFO"
    echo
    echo "# Optional settings"
    echo "PROJECT_URL=https://github.com/users/username/projects/1"
    echo
    echo "Available log levels: DEBUG, INFO, WARN, ERROR"
    echo
    echo "For project board integration, set PROJECT_URL to your GitHub project URL."
    echo
    
    print_prompt "Press Enter to continue"
    read -r
}

# ============================================================================
# INPUT VALIDATION WITH GUIDANCE
# ============================================================================

# Enhanced input validation with correction guidance
validate_input_with_guidance() {
    local input="$1"
    local input_type="$2"
    local expected_format="$3"
    local context="${4:-}"
    
    case "$input_type" in
        "menu_option")
            validate_menu_option "$input" "$expected_format" "$context"
            ;;
        "issue_number")
            validate_issue_number "$input"
            ;;
        "version")
            validate_version_format "$input"
            ;;
        "text")
            validate_text_input "$input" "$expected_format"
            ;;
        "confirmation")
            validate_confirmation "$input"
            ;;
        *)
            print_error "Unknown input type: $input_type"
            return 1
            ;;
    esac
}

# Validate menu option input
validate_menu_option() {
    local input="$1"
    local valid_range="$2"
    local menu_context="$3"
    
    # Check if input is a number
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        handle_error "input" "Please enter a number" "correction"
        return 1
    fi
    
    # Parse range (e.g., "1-5")
    local min_option="${valid_range%-*}"
    local max_option="${valid_range#*-}"
    
    # Validate range
    if [ "$input" -lt "$min_option" ] || [ "$input" -gt "$max_option" ]; then
        handle_error "input" "Please enter a number between $min_option and $max_option" "menu_retry"
        return 1
    fi
    
    return 0
}

# Validate issue number
validate_issue_number() {
    local input="$1"
    
    if [ -z "$input" ]; then
        handle_error "input" "Issue number cannot be empty" "correction"
        return 1
    fi
    
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        handle_error "input" "Issue number must be a positive integer" "correction"
        return 1
    fi
    
    if [ "$input" -eq 0 ]; then
        handle_error "input" "Issue number must be greater than 0" "correction"
        return 1
    fi
    
    return 0
}

# Validate version format
validate_version_format() {
    local input="$1"
    
    if [ -z "$input" ]; then
        handle_error "input" "Version cannot be empty" "correction"
        return 1
    fi
    
    # Check semantic version format (x.y.z)
    if ! [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        handle_error "input" "Version must be in format x.y.z (e.g., 1.2.3)" "correction"
        return 1
    fi
    
    return 0
}

# Validate text input
validate_text_input() {
    local input="$1"
    local min_length="${2:-1}"
    
    if [ ${#input} -lt "$min_length" ]; then
        handle_error "input" "Input must be at least $min_length characters long" "correction"
        return 1
    fi
    
    # Check for potentially problematic characters
    if [[ "$input" =~ [[:cntrl:]] ]]; then
        handle_error "input" "Input contains invalid control characters" "correction"
        return 1
    fi
    
    return 0
}

# Validate confirmation input
validate_confirmation() {
    local input="$1"
    
    case "$input" in
        [Yy]|[Yy][Ee][Ss]|[Nn]|[Nn][Oo]|"")
            return 0
            ;;
        *)
            handle_error "input" "Please enter 'y' for yes or 'n' for no" "correction"
            return 1
            ;;
    esac
}

# ============================================================================
# LOGGING AND ERROR TRACKING
# ============================================================================

# Log error for debugging and tracking
log_error() {
    local error_type="$1"
    local error_message="$2"
    local context="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log entry
    local log_entry="[$timestamp] ERROR [$error_type] $context: $error_message"
    
    # Write to error log file
    echo "$log_entry" >> "$ERROR_LOG_FILE"
    
    # Also log to main log if logging is enabled
    if [ "$ENABLE_LOGGING" = "true" ] && command -v log_error >/dev/null 2>&1; then
        log_error "wizard-core" "$error_message" "$context"
    fi
}

# Get error statistics
get_error_stats() {
    if [ -f "$ERROR_LOG_FILE" ]; then
        local total_errors=$(wc -l < "$ERROR_LOG_FILE")
        local recent_errors=$(tail -n 10 "$ERROR_LOG_FILE" | wc -l)
        
        echo "Total errors logged: $total_errors"
        echo "Recent errors (last 10): $recent_errors"
        
        if [ "$total_errors" -gt 0 ]; then
            echo
            echo "Most recent errors:"
            tail -n 5 "$ERROR_LOG_FILE" | while read -r line; do
                echo "  $line"
            done
        fi
    else
        echo "No error log file found"
    fi
}

# Clear error log
clear_error_log() {
    if [ -f "$ERROR_LOG_FILE" ]; then
        > "$ERROR_LOG_FILE"
        print_success "Error log cleared"
    else
        print_info "No error log file to clear"
    fi
}

# Handle input validation errors
handle_input_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Invalid input: $error_message"
    echo
    
    case "$recovery_action" in
        "retry_input")
            request_input_again
            ;;
        "show_help")
            show_input_help
            ;;
        *)
            request_input_again
            ;;
    esac
}

# Handle dependency errors
handle_dependency_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    clear_screen
    print_header "Dependency Error"
    print_error "Missing dependency: $error_message"
    echo
    
    case "$recovery_action" in
        "install_gh")
            offer_gh_installation_guide
            ;;
        "install_git")
            offer_git_installation_guide
            ;;
        *)
            offer_installation_guide "$error_message"
            ;;
    esac
}

# Handle GitHub-specific errors
handle_github_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "GitHub error: $error_message"
    echo
    
    case "$recovery_action" in
        "rate_limit")
            handle_rate_limit_error
            ;;
        "permissions")
            handle_permissions_error
            ;;
        "repo_not_found")
            handle_repo_not_found_error
            ;;
        *)
            offer_retry_operation
            ;;
    esac
}

# Handle configuration errors
handle_config_error() {
    local error_message="$1"
    local recovery_action="$2"
    
    print_error "Configuration error: $error_message"
    echo
    
    case "$recovery_action" in
        "create_config")
            offer_config_creation
            ;;
        "fix_config")
            offer_config_fix
            ;;
        *)
            offer_config_help
            ;;
    esac
}

# Handle generic errors
handle_generic_error() {
    local error_type="$1"
    local error_message="$2"
    local recovery_action="$3"
    
    print_error "Error ($error_type): $error_message"
    echo
    
    print_info "Please try again or contact support if the problem persists."
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# ============================================================================
# RECOVERY MECHANISMS
# ============================================================================

# Offer authentication setup
offer_auth_setup() {
    print_info "To use this wizard, you need to authenticate with GitHub CLI."
    echo
    print_info "Steps to authenticate:"
    print_info "1. Run: gh auth login"
    print_info "2. Follow the prompts to authenticate"
    print_info "3. Return to this wizard"
    echo
    
    print_confirmation "Would you like to run 'gh auth login' now?" "y"
    read -r auth_choice
    
    case "$auth_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Running GitHub CLI authentication..."
            if command -v gh >/dev/null 2>&1; then
                gh auth login
                if check_gh_auth; then
                    print_success "Authentication successful!"
                    sleep 2
                    return 0
                else
                    print_error "Authentication failed. Please try again manually."
                    sleep 3
                    return 1
                fi
            else
                print_error "GitHub CLI not found. Please install it first."
                offer_gh_installation_guide
                return 1
            fi
            ;;
        *)
            print_info "Please authenticate manually and restart the wizard."
            sleep 2
            return 1
            ;;
    esac
}

# Offer authentication retry
offer_auth_retry() {
    print_confirmation "Would you like to retry authentication?" "y"
    read -r retry_choice
    
    case "$retry_choice" in
        [Yy]|[Yy][Ee][Ss])
            if check_gh_auth; then
                print_success "Authentication successful!"
                return 0
            else
                print_error "Authentication still failing."
                offer_auth_setup
                return 1
            fi
            ;;
        *)
            print_info "Returning to main menu..."
            sleep 1
            return_to_main
            ;;
    esac
}

# Offer retry with exponential backoff
offer_retry() {
    local operation="$1"
    local attempt_count="${2:-1}"
    
    if [[ $attempt_count -gt $MAX_RETRY_ATTEMPTS ]]; then
        print_error "Maximum retry attempts reached for $operation."
        print_info "Please check your connection and try again later."
        echo
        print_prompt "Press Enter to continue"
        read -r
        return 1
    fi
    
    print_confirmation "Would you like to retry the $operation? (Attempt $attempt_count/$MAX_RETRY_ATTEMPTS)" "y"
    read -r retry_choice
    
    case "$retry_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
            return 0
            ;;
        *)
            print_info "Operation cancelled by user."
            return 1
            ;;
    esac
}

# Offer offline mode for network issues
offer_offline_mode() {
    print_info "Network connectivity issues detected."
    echo
    print_info "You can continue with limited functionality:"
    print_info "- View cached repository information"
    print_info "- Access configuration settings"
    print_info "- View help and documentation"
    echo
    
    print_confirmation "Would you like to continue in offline mode?" "n"
    read -r offline_choice
    
    case "$offline_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Continuing in offline mode..."
            export WIZARD_OFFLINE_MODE=true
            return 0
            ;;
        *)
            print_info "Please check your network connection and try again."
            return 1
            ;;
    esac
}

# Request input again with guidance
request_input_again() {
    print_info "Please provide valid input."
    show_input_help
    return 0
}

# Show input help
show_input_help() {
    echo
    print_info "Input Guidelines:"
    print_info "- Enter a number corresponding to the menu option"
    print_info "- Use only digits (0-9)"
    print_info "- Choose from the displayed options"
    echo
}

# Offer installation guide
offer_installation_guide() {
    local dependency="$1"
    
    print_info "Installation guide for: $dependency"
    echo
    
    case "$dependency" in
        *"gh"*|*"GitHub CLI"*)
            offer_gh_installation_guide
            ;;
        *"git"*)
            offer_git_installation_guide
            ;;
        *)
            print_info "Please install the required dependency: $dependency"
            print_info "Refer to the official documentation for installation instructions."
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue after installation"
    read -r
}

# GitHub CLI installation guide
offer_gh_installation_guide() {
    print_info "GitHub CLI Installation Guide:"
    echo
    print_info "Windows:"
    print_info "  winget install --id GitHub.cli"
    print_info "  or download from: https://github.com/cli/cli/releases"
    echo
    print_info "macOS:"
    print_info "  brew install gh"
    echo
    print_info "Linux (Ubuntu/Debian):"
    print_info "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    print_info "  sudo apt update && sudo apt install gh"
    echo
    print_info "After installation, run: gh auth login"
    echo
    
    print_confirmation "Would you like to open the GitHub CLI website?" "n"
    read -r open_choice
    
    case "$open_choice" in
        [Yy]|[Yy][Ee][Ss])
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "https://cli.github.com/"
            elif command -v open >/dev/null 2>&1; then
                open "https://cli.github.com/"
            elif command -v start >/dev/null 2>&1; then
                start "https://cli.github.com/"
            else
                print_info "Please visit: https://cli.github.com/"
            fi
            ;;
    esac
}

# Git installation guide
offer_git_installation_guide() {
    print_info "Git Installation Guide:"
    echo
    print_info "Windows:"
    print_info "  Download from: https://git-scm.com/download/win"
    echo
    print_info "macOS:"
    print_info "  brew install git"
    print_info "  or download from: https://git-scm.com/download/mac"
    echo
    print_info "Linux (Ubuntu/Debian):"
    print_info "  sudo apt update && sudo apt install git"
    echo
    print_info "Linux (CentOS/RHEL):"
    print_info "  sudo yum install git"
    echo
}

# Handle rate limit errors
handle_rate_limit_error() {
    print_warning "GitHub API rate limit exceeded."
    echo
    print_info "Rate limits reset every hour. You can:"
    print_info "1. Wait for the rate limit to reset"
    print_info "2. Use a GitHub token for higher limits"
    print_info "3. Continue with cached data (limited functionality)"
    echo
    
    print_confirmation "Would you like to continue with cached data?" "y"
    read -r cache_choice
    
    case "$cache_choice" in
        [Yy]|[Yy][Ee][Ss])
            export WIZARD_USE_CACHE=true
            print_info "Using cached data where available..."
            ;;
        *)
            print_info "Please wait for rate limit reset or configure authentication token."
            ;;
    esac
}

# Handle permissions errors
handle_permissions_error() {
    print_error "Insufficient permissions for this operation."
    echo
    print_info "This may be due to:"
    print_info "- Repository access restrictions"
    print_info "- Organization policies"
    print_info "- Token scope limitations"
    echo
    print_info "Please contact the repository owner or check your access permissions."
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Handle repository not found errors
handle_repo_not_found_error() {
    print_error "Repository not found or not accessible."
    echo
    print_info "Please ensure:"
    print_info "- You are in a Git repository directory"
    print_info "- The repository exists on GitHub"
    print_info "- You have access to the repository"
    echo
    
    print_confirmation "Would you like to check the current directory?" "y"
    read -r check_choice
    
    case "$check_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Current directory: $(pwd)"
            if [[ -d ".git" ]]; then
                print_success "Git repository detected"
                local remote_url=$(git remote get-url origin 2>/dev/null || echo "No remote origin found")
                print_info "Remote origin: $remote_url"
            else
                print_error "Not a Git repository"
                print_info "Please navigate to a Git repository directory and try again."
            fi
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Offer configuration creation
offer_config_creation() {
    print_info "Configuration file not found."
    echo
    print_confirmation "Would you like to create a default configuration?" "y"
    read -r create_choice
    
    case "$create_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Creating default configuration..."
            # This would call configuration creation functions
            print_info "Configuration creation will be implemented in the configuration task."
            ;;
        *)
            print_info "Please create configuration manually or run the configuration wizard."
            ;;
    esac
}

# Offer configuration fix
offer_config_fix() {
    print_info "Configuration issues detected."
    echo
    print_info "Common fixes:"
    print_info "- Check file permissions"
    print_info "- Verify file format"
    print_info "- Ensure required values are set"
    echo
    
    print_confirmation "Would you like to reset to default configuration?" "n"
    read -r reset_choice
    
    case "$reset_choice" in
        [Yy]|[Yy][Ee][Ss])
            print_info "Resetting configuration..."
            # This would call configuration reset functions
            print_info "Configuration reset will be implemented in the configuration task."
            ;;
        *)
            print_info "Please fix configuration manually or contact support."
            ;;
    esac
}

# Offer configuration help
offer_config_help() {
    print_info "Configuration Help:"
    echo
    print_info "The wizard uses the following configuration sources:"
    print_info "- .env files in the project directory"
    print_info "- Environment variables"
    print_info "- GitHub CLI configuration"
    echo
    print_info "For more help, use the Configuration menu option."
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# ============================================================================
# ENHANCED INPUT VALIDATION
# ============================================================================

# Enhanced input validation with correction guidance
validate_input_with_guidance() {
    local input="$1"
    local validation_type="$2"
    local valid_options="$3"
    local context="${4:-general}"
    
    case "$validation_type" in
        "menu_option")
            validate_menu_option "$input" "$valid_options" "$context"
            ;;
        "yes_no")
            validate_yes_no "$input" "$context"
            ;;
        "number")
            validate_number "$input" "$context"
            ;;
        "version")
            validate_version "$input" "$context"
            ;;
        "issue_number")
            validate_issue_number "$input" "$context"
            ;;
        *)
            validate_generic "$input" "$validation_type" "$context"
            ;;
    esac
}

# Validate menu option input
validate_menu_option() {
    local input="$1"
    local valid_options="$2"
    local context="$3"
    
    # Trim whitespace
    input=$(echo "$input" | xargs)
    
    # Check if input is empty
    if [[ -z "$input" ]]; then
        handle_error "input" "No input provided" "retry_input" "$context"
        return 1
    fi
    
    # Check if input is numeric
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        handle_error "input" "Please enter a number, not text" "show_help" "$context"
        return 1
    fi
    
    # Parse valid options range
    local min_option max_option
    if [[ "$valid_options" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        min_option="${BASH_REMATCH[1]}"
        max_option="${BASH_REMATCH[2]}"
        
        if [[ $input -lt $min_option ]] || [[ $input -gt $max_option ]]; then
            handle_error "input" "Please choose a number between $min_option and $max_option" "show_help" "$context"
            return 1
        fi
    fi
    
    return 0
}

# Validate yes/no input
validate_yes_no() {
    local input="$1"
    local context="$2"
    
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | xargs)
    
    if [[ -z "$input" ]]; then
        return 0  # Allow empty input for default
    fi
    
    case "$input" in
        y|yes|n|no)
            return 0
            ;;
        *)
            handle_error "input" "Please enter 'y' for yes or 'n' for no" "show_help" "$context"
            return 1
            ;;
    esac
}

# Validate number input
validate_number() {
    local input="$1"
    local context="$2"
    
    input=$(echo "$input" | xargs)
    
    if [[ -z "$input" ]]; then
        handle_error "input" "Number required" "retry_input" "$context"
        return 1
    fi
    
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        handle_error "input" "Please enter a valid number (digits only)" "show_help" "$context"
        return 1
    fi
    
    return 0
}

# Validate version input
validate_version() {
    local input="$1"
    local context="$2"
    
    input=$(echo "$input" | xargs)
    
    if [[ -z "$input" ]]; then
        handle_error "input" "Version required" "retry_input" "$context"
        return 1
    fi
    
    if ! [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        handle_error "input" "Please enter version in format X.Y.Z (e.g., 1.2.3)" "show_help" "$context"
        return 1
    fi
    
    return 0
}

# Validate issue number input
validate_issue_number() {
    local input="$1"
    local context="$2"
    
    input=$(echo "$input" | xargs)
    
    if [[ -z "$input" ]]; then
        handle_error "input" "Issue number required" "retry_input" "$context"
        return 1
    fi
    
    if ! [[ "$input" =~ ^[0-9]+$ ]] || [[ $input -eq 0 ]]; then
        handle_error "input" "Please enter a valid issue number (positive integer)" "show_help" "$context"
        return 1
    fi
    
    return 0
}

# Generic validation
validate_generic() {
    local input="$1"
    local validation_type="$2"
    local context="$3"
    
    if [[ -z "$input" ]]; then
        handle_error "input" "Input required for $validation_type" "retry_input" "$context"
        return 1
    fi
    
    return 0
}

# ============================================================================
# ERROR LOGGING
# ============================================================================

# Log error to file
log_error() {
    local error_type="$1"
    local error_message="$2"
    local context="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$ERROR_LOG_FILE")
    [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"
    
    # Log error with timestamp
    echo "[$timestamp] ERROR [$error_type] [$context] $error_message" >> "$ERROR_LOG_FILE"
}

# Get recent errors from log
get_recent_errors() {
    local count="${1:-10}"
    
    if [[ -f "$ERROR_LOG_FILE" ]]; then
        tail -n "$count" "$ERROR_LOG_FILE"
    else
        echo "No error log found"
    fi
}

# Clear error log
clear_error_log() {
    if [[ -f "$ERROR_LOG_FILE" ]]; then
        > "$ERROR_LOG_FILE"
        print_info "Error log cleared"
    else
        print_info "No error log to clear"
    fi
}

# ============================================================================
# OPERATION WRAPPERS WITH ERROR HANDLING
# ============================================================================

# Execute operation with retry logic
execute_with_retry() {
    local operation_name="$1"
    local operation_function="$2"
    shift 2
    local operation_args=("$@")
    
    local attempt=1
    local max_attempts=$MAX_RETRY_ATTEMPTS
    
    while [[ $attempt -le $max_attempts ]]; do
        print_info "Executing $operation_name (attempt $attempt/$max_attempts)..."
        
        if "$operation_function" "${operation_args[@]}"; then
            print_success "$operation_name completed successfully"
            return 0
        else
            local exit_code=$?
            
            if [[ $attempt -eq $max_attempts ]]; then
                handle_error "network" "$operation_name failed after $max_attempts attempts" "retry" "$operation_name"
                return $exit_code
            fi
            
            print_warning "$operation_name failed (attempt $attempt/$max_attempts)"
            
            if offer_retry "$operation_name" $((attempt + 1)); then
                ((attempt++))
                continue
            else
                return $exit_code
            fi
        fi
    done
}

# Safe GitHub operation wrapper
safe_github_operation() {
    local operation_name="$1"
    local operation_function="$2"
    shift 2
    local operation_args=("$@")
    
    # Check prerequisites
    if ! check_github_prerequisites; then
        return 1
    fi
    
    # Execute with error handling
    if ! "$operation_function" "${operation_args[@]}"; then
        local exit_code=$?
        
        # Analyze error and provide appropriate handling
        case $exit_code in
            1)
                handle_error "github" "Operation failed: $operation_name" "retry" "$operation_name"
                ;;
            2)
                handle_error "auth" "Authentication required for $operation_name" "setup_auth" "$operation_name"
                ;;
            3)
                handle_error "network" "Network error during $operation_name" "retry" "$operation_name"
                ;;
            4)
                handle_error "github" "Rate limit exceeded during $operation_name" "rate_limit" "$operation_name"
                ;;
            *)
                handle_error "github" "Unknown error during $operation_name (exit code: $exit_code)" "retry" "$operation_name"
                ;;
        esac
        
        return $exit_code
    fi
    
    return 0
}

# Check GitHub prerequisites
check_github_prerequisites() {
    # Check if GitHub CLI is installed
    if ! command -v gh >/dev/null 2>&1; then
        handle_error "dependency" "GitHub CLI not found" "install_gh" "prerequisites"
        return 1
    fi
    
    # Check if Git is installed
    if ! command -v git >/dev/null 2>&1; then
        handle_error "dependency" "Git not found" "install_git" "prerequisites"
        return 1
    fi
    
    # Check if we're in a Git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        handle_error "github" "Not in a Git repository" "repo_not_found" "prerequisites"
        return 1
    fi
    
    # Check GitHub CLI authentication
    if ! check_gh_auth >/dev/null 2>&1; then
        handle_error "auth" "GitHub CLI not authenticated" "setup_auth" "prerequisites"
        return 1
    fi
    
    return 0
}

# Safe input prompt with validation
safe_input_prompt() {
    local prompt_text="$1"
    local validation_type="$2"
    local valid_options="${3:-}"
    local context="${4:-input}"
    local max_attempts="${5:-3}"
    
    local attempt=1
    local user_input
    
    while [[ $attempt -le $max_attempts ]]; do
        print_prompt "$prompt_text"
        read -r user_input
        
        if validate_input_with_guidance "$user_input" "$validation_type" "$valid_options" "$context"; then
            echo "$user_input"
            return 0
        fi
        
        ((attempt++))
        
        if [[ $attempt -le $max_attempts ]]; then
            print_info "Please try again (attempt $attempt/$max_attempts)..."
        fi
    done
    
    print_error "Maximum input attempts reached"
    return 1
}

# Safe confirmation prompt
safe_confirmation_prompt() {
    local prompt_text="$1"
    local default_value="${2:-n}"
    local context="${3:-confirmation}"
    
    local user_input
    
    print_confirmation "$prompt_text" "$default_value"
    read -r user_input
    
    if validate_input_with_guidance "$user_input" "yes_no" "" "$context"; then
        # Normalize the response
        user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]' | xargs)
        
        case "$user_input" in
            ""|"$default_value")
                echo "$default_value"
                ;;
            y|yes)
                echo "y"
                ;;
            n|no)
                echo "n"
                ;;
        esac
        return 0
    else
        echo "$default_value"
        return 1
    fi
}
# Configuration Management Workflows

# Execute view configuration workflow
execute_view_configuration() {
    clear_screen true
    print_header "Current Configuration"
    
    # Display environment variables
    print_header "Environment Variables"
    print_key_value "GITHUB_TOKEN" "${GITHUB_TOKEN:+[SET]} ${GITHUB_TOKEN:-[NOT SET]}"
    print_key_value "PROJECT_URL" "${PROJECT_URL:-[NOT SET]}"
    print_key_value "ENABLE_LOGGING" "${ENABLE_LOGGING:-false}"
    print_key_value "LOG_LEVEL" "${LOG_LEVEL:-INFO}"
    print_key_value "LOG_FILE" "${LOG_FILE:-./logs/gh-issue-manager.log}"
    
    echo
    print_header "Repository Context"
    if [ -n "${REPO_OWNER:-}" ] && [ -n "${REPO_NAME:-}" ]; then
        print_key_value "Repository" "$REPO_OWNER/$REPO_NAME"
        print_key_value "Branch" "${BRANCH_NAME:-unknown}"
        print_key_value "GitHub CLI Auth" "${IS_AUTHENTICATED:-unknown}"
    else
        print_info "No repository context available"
    fi
    
    echo
    print_header "Wizard Session"
    print_key_value "Session ID" "${WIZARD_SESSION_ID:-unknown}"
    print_key_value "Start Time" "${WIZARD_START_TIME:-unknown}"
    print_key_value "Current Workflow" "${CURRENT_WORKFLOW:-none}"
    print_key_value "Last Operation" "${LAST_OPERATION:-none}"
    print_key_value "Operation Result" "${OPERATION_RESULT:-none}"
    
    echo
    print_header "System Information"
    print_key_value "GitHub CLI Version" "$(get_gh_version)"
    print_key_value "Git Version" "$(git --version 2>/dev/null || echo 'Not available')"
    print_key_value "jq Version" "$(jq --version 2>/dev/null || echo 'Not available')"
    
    # Check .env file status
    echo
    print_header "Configuration Files"
    if [ -f ".env" ]; then
        print_key_value ".env file" "✅ Present"
        local env_lines=$(wc -l < .env 2>/dev/null || echo "0")
        print_key_value ".env lines" "$env_lines"
    else
        print_key_value ".env file" "❌ Missing"
    fi
    
    if [ -f ".env.local" ]; then
        print_key_value ".env.local file" "✅ Present"
    else
        print_key_value ".env.local file" "❌ Missing"
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Execute update settings workflow
execute_update_settings() {
    clear_screen true
    print_header "Update Settings"
    
    echo "What would you like to update?"
    print_menu_option "1" "Logging Settings"
    print_menu_option "2" "Project URL"
    print_menu_option "3" "Create/Update .env file"
    print_menu_option "4" "Reset to defaults"
    echo
    
    print_prompt "Enter your choice (1-4)"
    read -r settings_choice
    
    case "$settings_choice" in
        1)
            execute_update_logging_settings
            ;;
        2)
            execute_update_project_url
            ;;
        3)
            execute_update_env_file
            ;;
        4)
            execute_reset_settings
            ;;
        *)
            print_error "Invalid choice"
            sleep 2
            ;;
    esac
}

# Update logging settings
execute_update_logging_settings() {
    clear_screen true
    print_header "Update Logging Settings"
    
    print_key_value "Current Logging" "${ENABLE_LOGGING:-false}"
    print_key_value "Current Log Level" "${LOG_LEVEL:-INFO}"
    print_key_value "Current Log File" "${LOG_FILE:-./logs/gh-issue-manager.log}"
    echo
    
    print_confirmation "Enable logging?" "${ENABLE_LOGGING:-false}"
    read -r enable_logging
    
    case "$enable_logging" in
        [Yy]|[Yy][Ee][Ss])
            update_config "ENABLE_LOGGING" "true"
            
            echo "Available log levels:"
            print_menu_option "1" "DEBUG (most verbose)"
            print_menu_option "2" "INFO (default)"
            print_menu_option "3" "WARN (warnings only)"
            print_menu_option "4" "ERROR (errors only)"
            echo
            
            print_prompt "Select log level (1-4, default: 2)"
            read -r log_level_choice
            
            case "$log_level_choice" in
                1) update_config "LOG_LEVEL" "DEBUG" ;;
                2|"") update_config "LOG_LEVEL" "INFO" ;;
                3) update_config "LOG_LEVEL" "WARN" ;;
                4) update_config "LOG_LEVEL" "ERROR" ;;
                *) 
                    print_warning "Invalid choice, using INFO"
                    update_config "LOG_LEVEL" "INFO"
                    ;;
            esac
            
            print_success "Logging settings updated"
            ;;
        *)
            update_config "ENABLE_LOGGING" "false"
            print_info "Logging disabled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Update project URL
execute_update_project_url() {
    clear_screen true
    print_header "Update Project URL"
    
    print_key_value "Current Project URL" "${PROJECT_URL:-[NOT SET]}"
    echo
    
    print_info "Project URL format: https://github.com/orgs/ORG/projects/N"
    print_info "                or: https://github.com/users/USER/projects/N"
    echo
    
    print_prompt "Enter new project URL (or press Enter to clear)"
    read -r new_project_url
    
    if [ -z "$new_project_url" ]; then
        export PROJECT_URL=""
        print_info "Project URL cleared"
    else
        if update_config "PROJECT_URL" "$new_project_url"; then
            print_success "Project URL updated successfully"
        else
            print_error "Invalid project URL format"
        fi
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Update .env file
execute_update_env_file() {
    clear_screen true
    print_header "Create/Update .env File"
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        print_confirmation "Overwrite existing .env file?" "n"
        read -r overwrite_choice
        
        case "$overwrite_choice" in
            [Yy]|[Yy][Ee][Ss])
                ;;
            *)
                print_info "Operation cancelled"
                sleep 2
                return
                ;;
        esac
    fi
    
    # Create .env file with current settings
    cat > .env << EOF
# GitHub Issue Manager Wizard Configuration
# Generated on $(date)

# GitHub Token (optional, uses gh CLI token if not set)
GITHUB_TOKEN=${GITHUB_TOKEN:-}

# Project Board URL (optional)
PROJECT_URL=${PROJECT_URL:-}

# Logging Configuration
ENABLE_LOGGING=${ENABLE_LOGGING:-false}
LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-./logs/gh-issue-manager.log}

# Wizard Session Configuration
WIZARD_AUTO_REFRESH=${WIZARD_AUTO_REFRESH:-false}
WIZARD_CONFIRM_DESTRUCTIVE=${WIZARD_CONFIRM_DESTRUCTIVE:-true}
EOF
    
    print_success ".env file created/updated successfully"
    print_info "You can edit .env manually for additional customization"
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Reset settings to defaults
execute_reset_settings() {
    clear_screen true
    print_header "Reset Settings to Defaults"
    
    print_warning "This will reset all wizard settings to their default values"
    print_confirmation "Are you sure you want to reset all settings?" "n"
    read -r reset_choice
    
    case "$reset_choice" in
        [Yy]|[Yy][Ee][Ss])
            # Reset environment variables to defaults
            export GITHUB_TOKEN=""
            export PROJECT_URL=""
            export ENABLE_LOGGING="false"
            export LOG_LEVEL="INFO"
            export LOG_FILE="./logs/gh-issue-manager.log"
            
            # Clear session variables
            export CURRENT_WORKFLOW=""
            export WORKFLOW_CONTEXT=""
            export LAST_OPERATION=""
            export OPERATION_RESULT=""
            
            print_success "Settings reset to defaults"
            
            print_confirmation "Create new .env file with default values?" "y"
            read -r create_env_choice
            
            case "$create_env_choice" in
                [Yy]|[Yy][Ee][Ss])
                    execute_update_env_file
                    ;;
            esac
            ;;
        *)
            print_info "Reset cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Status and Release workflow functions
execute_status_workflow() {
    local workflow_data="$1"
    display_status_dashboard
    export OPERATION_RESULT="success"
}

execute_release_workflow() {
    local workflow_data="$1"
    interactive_release_wizard
    export OPERATION_RESULT="success"
}

execute_issue_workflow() {
    local workflow_data="$1"
    # This is handled by the specific issue workflow functions
    export OPERATION_RESULT="success"
}

# Update .env file
execute_update_env_file() {
    clear_screen true
    print_header "Create/Update .env File"
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        print_confirmation "Overwrite existing .env file?" "n"
        read -r overwrite_choice
        
        case "$overwrite_choice" in
            [Yy]|[Yy][Ee][Ss])
                create_env_file
                ;;
            *)
                print_info "Keeping existing .env file"
                ;;
        esac
    else
        create_env_file
    fi
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Create .env file
create_env_file() {
    cat > .env << 'EOF'
# GitHub Issue Manager Wizard Configuration

# Enable logging (true/false)
ENABLE_LOGGING=true

# Log level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL=INFO

# Log file path
LOG_FILE=./logs/gh-issue-manager.log

# Project board URL (optional)
# PROJECT_URL=https://github.com/orgs/your-org/projects/1
# PROJECT_URL=https://github.com/users/your-username/projects/1

# GitHub token (optional - gh CLI handles auth)
# GITHUB_TOKEN=your_token_here
EOF
    
    print_success ".env file created successfully"
    
    # Source the new configuration
    source .env
    print_info "Configuration loaded"
}

# Reset settings to defaults
execute_reset_settings() {
    clear_screen true
    print_header "Reset Settings"
    
    print_warning "This will reset all settings to default values"
    print_confirmation "Are you sure you want to continue?" "n"
    read -r reset_choice
    
    case "$reset_choice" in
        [Yy]|[Yy][Ee][Ss])
            # Reset environment variables
            export ENABLE_LOGGING="true"
            export LOG_LEVEL="INFO"
            export LOG_FILE="./logs/gh-issue-manager.log"
            unset PROJECT_URL
            
            # Recreate .env file with defaults
            create_env_file
            
            print_success "Settings reset to defaults"
            ;;
        *)
            print_info "Reset cancelled"
            ;;
    esac
    
    echo
    print_prompt "Press Enter to continue"
    read -r
}

# Update configuration helper
update_config_setting() {
    local key="$1"
    local value="$2"
    
    # Update in current session
    export "$key"="$value"
    
    # Update in .env file if it exists
    if [ -f ".env" ]; then
        if grep -q "^$key=" .env; then
            # Update existing line
            sed -i "s/^$key=.*/$key=$value/" .env
        else
            # Add new line
            echo "$key=$value" >> .env
        fi
    fi
}