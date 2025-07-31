#!/bin/bash

# Demo script for wizard-display.sh module
# This script demonstrates the visual formatting functions

# Get the project root and source the display module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/wizard-display.sh"

echo "GitHub Wizard Display Module Demo"
echo "=================================="
echo

# Demo print_header
print_header "Welcome to GitHub Wizard"
sleep 1

# Demo menu options
echo "Main Menu:"
print_menu_option "1" "Status Dashboard"
print_menu_option "2" "Release Wizard" "true"
print_menu_option "3" "Issue Management"
print_menu_option "4" "Configuration"
print_menu_option "5" "Exit"
echo
sleep 2

# Demo status lines
echo "Status Information:"
print_status_line "success" "GitHub CLI authenticated"
print_status_line "info" "Repository: gh-sub-issues"
print_status_line "warning" "3 open issues require attention"
print_status_line "error" "Rate limit approaching"
print_status_line "progress" "Syncing with remote repository"
echo
sleep 2

# Demo message functions
print_success "Release v1.2.3 created successfully" "Published to GitHub with 15 commits"
sleep 1

print_warning "Some tests are failing" "Consider running the test suite before release"
sleep 1

print_error "Failed to authenticate with GitHub" "Please run 'gh auth login' to authenticate"
sleep 1

print_info "Tip: Use 'gh repo view' to see repository details"
sleep 2

# Demo progress indicator
echo "Demonstrating progress indicator:"
for i in {1..10}; do
    show_progress $i 10 "Processing issues"
    sleep 0.3
done
echo
sleep 1

# Demo separator and utilities
print_separator 50 "="
print_centered "Repository Statistics" 50
print_separator 50 "="
echo

print_key_value "Total Issues" "42"
print_key_value "Open Issues" "15"
print_key_value "Closed Issues" "27"
print_key_value "Last Release" "v1.2.2"
echo

# Demo table
print_table_header "Issue #" "Status" "Title"
print_table_row "#123" "Open" "Fix bug in wizard"
print_table_row "#124" "Closed" "Add new feature"
print_table_row "#125" "Open" "Update documentation"
echo

# Demo prompts
print_prompt "Enter issue number" "123"
echo
print_confirmation "Create new release?" "y"
echo

print_header "Demo Complete"
echo "All display functions are working correctly!"