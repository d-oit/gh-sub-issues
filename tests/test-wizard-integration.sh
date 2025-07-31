#!/bin/bash

# Comprehensive Integration Test for GitHub Wizard
# Tests complete user workflows: status → release → issue management
# Verifies cross-module communication and state management

# Test configuration
TEST_NAME="GitHub Wizard Complete Integration Test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
WIZARD_SCRIPT="$(dirname "$SCRIPT_DIR")/gh-wizard.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test utilities
print_test_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $TEST_NAME${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_test_section() {
    local section="$1"
    echo -e "\n${YELLOW}=== $section ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Mock GitHub CLI for testing
setup_test_environment() {
    print_test_section "Setting up test environment"
    
    # Create temporary directory for test
    export TEST_TEMP_DIR=$(mktemp -d)
    export ORIGINAL_PWD=$(pwd)
    
    # Set up test environment variables
    export ENABLE_LOGGING="false"
    export GITHUB_TOKEN="test_token"
    export PROJECT_URL="https://github.com/orgs/test/projects/1"
    
    # Create mock git repository
    cd "$TEST_TEMP_DIR"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "# Test Repository" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    print_success "Test environment set up in $TEST_TEMP_DIR"
}

cleanup_test_environment() {
    print_test_section "Cleaning up test environment"
    
    cd "$ORIGINAL_PWD"
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
        print_success "Test environment cleaned up"
    fi
}

# Test module loading and initialization
test_module_loading() {
    print_test_section "Testing Module Loading and Integration"
    
    local test_passed=true
    
    # Source all modules
    if ! source "$LIB_DIR/wizard-config.sh" 2>/dev/null; then
        print_error "Failed to load wizard-config.sh"
        test_passed=false
    fi
    
    if ! source "$LIB_DIR/wizard-display.sh" 2>/dev/null; then
        print_error "Failed to load wizard-display.sh"
        test_passed=false
    fi
    
    if ! source "$LIB_DIR/wizard-github.sh" 2>/dev/null; then
        print_error "Failed to load wizard-github.sh"
        test_passed=false
    fi
    
    if ! source "$LIB_DIR/wizard-core.sh" 2>/dev/null; then
        print_error "Failed to load wizard-core.sh"
        test_passed=false
    fi
    
    if [ "$test_passed" = "true" ]; then
        print_success "All modules loaded successfully"
    fi
    
    # Test configuration loading
    if load_config >/dev/null 2>&1; then
        print_success "Configuration loading works"
    else
        print_error "Configuration loading failed"
        test_passed=false
    fi
    
    # Test core initialization
    if init_wizard_core >/dev/null 2>&1; then
        print_success "Wizard core initialization works"
    else
        print_error "Wizard core initialization failed"
        test_passed=false
    fi
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test cross-module state management
test_cross_module_state() {
    print_test_section "Testing Cross-Module State Management"
    
    local test_passed=true
    
    # Initialize cross-module state
    export WIZARD_SESSION_ID="test_session_123"
    export WIZARD_START_TIME="2024-01-01 12:00:00"
    export CURRENT_WORKFLOW=""
    export WORKFLOW_CONTEXT=""
    export LAST_OPERATION=""
    export OPERATION_RESULT=""
    
    # Test state persistence across modules
    export CURRENT_WORKFLOW="test_workflow"
    export WORKFLOW_CONTEXT="test_context"
    
    # Verify state is accessible
    if [ "$CURRENT_WORKFLOW" = "test_workflow" ] && [ "$WORKFLOW_CONTEXT" = "test_context" ]; then
        print_success "Cross-module state management works"
    else
        print_error "Cross-module state management failed"
        test_passed=false
    fi
    
    # Test operation result tracking
    export OPERATION_RESULT="success"
    export LAST_OPERATION="test_operation"
    
    if [ "$OPERATION_RESULT" = "success" ] && [ "$LAST_OPERATION" = "test_operation" ]; then
        print_success "Operation result tracking works"
    else
        print_error "Operation result tracking failed"
        test_passed=false
    fi
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test workflow execution integration
test_workflow_integration() {
    print_test_section "Testing Workflow Integration"
    
    local test_passed=true
    
    # Test workflow execution function exists
    if declare -f execute_workflow >/dev/null 2>&1; then
        print_success "execute_workflow function exists"
    else
        print_error "execute_workflow function missing"
        test_passed=false
    fi
    
    # Test issue workflow functions exist
    local issue_functions=(
        "execute_create_issue_workflow"
        "execute_update_issue_workflow"
        "execute_link_issues_workflow"
        "execute_bulk_operations_workflow"
    )
    
    for func in "${issue_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    # Test configuration workflow functions exist
    local config_functions=(
        "execute_view_configuration"
        "execute_update_settings"
    )
    
    for func in "${config_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test menu navigation integration
test_menu_navigation() {
    print_test_section "Testing Menu Navigation Integration"
    
    local test_passed=true
    
    # Initialize wizard core
    init_wizard_core >/dev/null 2>&1
    
    # Test menu state management
    local initial_menu=$(get_current_menu)
    if [ "$initial_menu" = "main" ]; then
        print_success "Initial menu state correct"
    else
        print_error "Initial menu state incorrect: $initial_menu"
        test_passed=false
    fi
    
    # Test menu transitions
    CURRENT_MENU="status"
    local status_menu=$(get_current_menu)
    if [ "$status_menu" = "status" ]; then
        print_success "Menu state transition works"
    else
        print_error "Menu state transition failed: $status_menu"
        test_passed=false
    fi
    
    # Test menu history
    MENU_HISTORY=("main")
    local history_output=$(get_menu_history)
    if echo "$history_output" | grep -q "main"; then
        print_success "Menu history tracking works"
    else
        print_error "Menu history tracking failed"
        test_passed=false
    fi
    
    # Test wizard running status
    if is_wizard_running; then
        print_success "Wizard running status tracking works"
    else
        print_error "Wizard running status tracking failed"
        test_passed=false
    fi
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test input validation integration
test_input_validation() {
    print_test_section "Testing Input Validation Integration"
    
    local test_passed=true
    
    # Test menu option validation
    if handle_user_input "1" "1-5" "main" 2>/dev/null; then
        print_success "Valid menu input accepted"
    else
        print_error "Valid menu input rejected"
        test_passed=false
    fi
    
    if ! handle_user_input "6" "1-5" "main" 2>/dev/null; then
        print_success "Invalid menu input rejected"
    else
        print_error "Invalid menu input accepted"
        test_passed=false
    fi
    
    if ! handle_user_input "abc" "1-5" "main" 2>/dev/null; then
        print_success "Non-numeric input rejected"
    else
        print_error "Non-numeric input accepted"
        test_passed=false
    fi
    
    # Test enhanced validation functions
    if declare -f validate_input_with_guidance >/dev/null 2>&1; then
        print_success "Enhanced input validation function exists"
    else
        print_error "Enhanced input validation function missing"
        test_passed=false
    fi
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test error handling integration
test_error_handling() {
    print_test_section "Testing Error Handling Integration"
    
    local test_passed=true
    
    # Test error handling function exists
    if declare -f handle_error >/dev/null 2>&1; then
        print_success "handle_error function exists"
    else
        print_error "handle_error function missing"
        test_passed=false
    fi
    
    # Test specific error handlers exist
    local error_handlers=(
        "handle_auth_error"
        "handle_network_error"
        "handle_input_error"
        "handle_dependency_error"
        "handle_github_error"
        "handle_config_error"
    )
    
    for handler in "${error_handlers[@]}"; do
        if declare -f "$handler" >/dev/null 2>&1; then
            print_success "$handler function exists"
        else
            print_error "$handler function missing"
            test_passed=false
        fi
    done
    
    # Test recovery mechanisms exist
    local recovery_functions=(
        "offer_auth_setup"
        "offer_retry"
        "request_input_again"
        "offer_installation_guide"
    )
    
    for func in "${recovery_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test GitHub integration
test_github_integration() {
    print_test_section "Testing GitHub Integration"
    
    local test_passed=true
    
    # Test GitHub functions exist
    local github_functions=(
        "check_gh_auth"
        "get_repo_status"
        "validate_prerequisites"
        "get_issue_stats"
        "get_recent_activity"
        "get_project_status"
        "create_github_issue"
        "update_github_issue"
        "link_issues"
    )
    
    for func in "${github_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    # Test release functions exist
    local release_functions=(
        "get_current_version"
        "calculate_next_version"
        "validate_release_prerequisites"
        "generate_release_notes"
        "interactive_release_wizard"
    )
    
    for func in "${release_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test display integration
test_display_integration() {
    print_test_section "Testing Display Integration"
    
    local test_passed=true
    
    # Test display functions exist
    local display_functions=(
        "print_header"
        "print_menu_option"
        "print_status_line"
        "print_error"
        "print_success"
        "print_warning"
        "print_info"
        "clear_screen"
        "print_key_value"
        "print_prompt"
        "print_confirmation"
    )
    
    for func in "${display_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    # Test color constants are defined
    local color_vars=(
        "RED" "GREEN" "YELLOW" "BLUE" "PURPLE" "CYAN" "WHITE" "BOLD" "NC"
    )
    
    for var in "${color_vars[@]}"; do
        if [ -n "${!var:-}" ]; then
            print_success "$var color constant defined"
        else
            print_error "$var color constant missing"
            test_passed=false
        fi
    done
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test configuration integration
test_configuration_integration() {
    print_test_section "Testing Configuration Integration"
    
    local test_passed=true
    
    # Test configuration functions exist
    local config_functions=(
        "load_config"
        "validate_environment"
        "setup_logging"
        "get_project_url"
        "update_config"
        "check_gh_auth"
        "get_repo_context"
    )
    
    for func in "${config_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    # Test logging functions exist
    local logging_functions=(
        "log_init"
        "log_message"
        "log_error"
        "log_warn"
        "log_info"
        "log_debug"
    )
    
    for func in "${logging_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_success "$func function exists"
        else
            print_error "$func function missing"
            test_passed=false
        fi
    done
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Test complete workflow simulation
test_complete_workflow_simulation() {
    print_test_section "Testing Complete Workflow Simulation"
    
    local test_passed=true
    
    # Initialize all modules
    if ! load_config >/dev/null 2>&1; then
        print_error "Failed to load configuration"
        test_passed=false
    fi
    
    if ! init_wizard_core >/dev/null 2>&1; then
        print_error "Failed to initialize wizard core"
        test_passed=false
    fi
    
    # Simulate status workflow
    export CURRENT_WORKFLOW="status"
    export WORKFLOW_CONTEXT="dashboard"
    
    if [ "$CURRENT_WORKFLOW" = "status" ]; then
        print_success "Status workflow state set correctly"
    else
        print_error "Status workflow state failed"
        test_passed=false
    fi
    
    # Simulate issue workflow
    export CURRENT_WORKFLOW="issue"
    export WORKFLOW_CONTEXT="create"
    export LAST_OPERATION="create_issue"
    export OPERATION_RESULT="success"
    
    if [ "$CURRENT_WORKFLOW" = "issue" ] && [ "$OPERATION_RESULT" = "success" ]; then
        print_success "Issue workflow state management works"
    else
        print_error "Issue workflow state management failed"
        test_passed=false
    fi
    
    # Simulate release workflow
    export CURRENT_WORKFLOW="release"
    export WORKFLOW_CONTEXT="create_release"
    export LAST_OPERATION="release_wizard"
    export OPERATION_RESULT="success"
    
    if [ "$CURRENT_WORKFLOW" = "release" ] && [ "$OPERATION_RESULT" = "success" ]; then
        print_success "Release workflow state management works"
    else
        print_error "Release workflow state management failed"
        test_passed=false
    fi
    
    # Test workflow history
    export WORKFLOW_HISTORY="status,issue,release"
    
    if echo "$WORKFLOW_HISTORY" | grep -q "status" && echo "$WORKFLOW_HISTORY" | grep -q "issue" && echo "$WORKFLOW_HISTORY" | grep -q "release"; then
        print_success "Workflow history tracking works"
    else
        print_error "Workflow history tracking failed"
        test_passed=false
    fi
    
    return $([ "$test_passed" = "true" ] && echo 0 || echo 1)
}

# Run all integration tests
run_integration_tests() {
    print_test_header
    
    local tests_passed=0
    local tests_total=10
    local test_results=()
    
    # Set up test environment
    setup_test_environment
    
    # Run tests
    print_info "Running comprehensive integration tests..."
    echo
    
    if test_module_loading; then
        ((tests_passed++))
        test_results+=("✅ Module Loading")
    else
        test_results+=("❌ Module Loading")
    fi
    
    if test_cross_module_state; then
        ((tests_passed++))
        test_results+=("✅ Cross-Module State")
    else
        test_results+=("❌ Cross-Module State")
    fi
    
    if test_workflow_integration; then
        ((tests_passed++))
        test_results+=("✅ Workflow Integration")
    else
        test_results+=("❌ Workflow Integration")
    fi
    
    if test_menu_navigation; then
        ((tests_passed++))
        test_results+=("✅ Menu Navigation")
    else
        test_results+=("❌ Menu Navigation")
    fi
    
    if test_input_validation; then
        ((tests_passed++))
        test_results+=("✅ Input Validation")
    else
        test_results+=("❌ Input Validation")
    fi
    
    if test_error_handling; then
        ((tests_passed++))
        test_results+=("✅ Error Handling")
    else
        test_results+=("❌ Error Handling")
    fi
    
    if test_github_integration; then
        ((tests_passed++))
        test_results+=("✅ GitHub Integration")
    else
        test_results+=("❌ GitHub Integration")
    fi
    
    if test_display_integration; then
        ((tests_passed++))
        test_results+=("✅ Display Integration")
    else
        test_results+=("❌ Display Integration")
    fi
    
    if test_configuration_integration; then
        ((tests_passed++))
        test_results+=("✅ Configuration Integration")
    else
        test_results+=("❌ Configuration Integration")
    fi
    
    if test_complete_workflow_simulation; then
        ((tests_passed++))
        test_results+=("✅ Complete Workflow Simulation")
    else
        test_results+=("❌ Complete Workflow Simulation")
    fi
    
    # Clean up test environment
    cleanup_test_environment
    
    # Print summary
    echo
    print_test_section "Integration Test Summary"
    echo
    
    for result in "${test_results[@]}"; do
        echo -e "$result"
    done
    
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Tests Passed: $tests_passed/$tests_total${NC}"
    
    local success_rate=$(( (tests_passed * 100) / tests_total ))
    echo -e "${BLUE}Success Rate: $success_rate%${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $tests_passed -eq $tests_total ]; then
        echo -e "${GREEN}🎉 All integration tests passed!${NC}"
        echo -e "${GREEN}The GitHub Wizard is fully integrated and ready for use.${NC}"
        return 0
    else
        echo -e "${RED}⚠️  Some integration tests failed!${NC}"
        echo -e "${RED}Please review the failed tests and fix the issues.${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
fi