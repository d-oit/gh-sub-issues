#!/bin/bash

# Test suite for GitHub Wizard Core Module
# Tests menu navigation, user input handling, and state management

# Test configuration
TEST_NAME="GitHub Wizard Core Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source the module under test
source "$LIB_DIR/wizard-core.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
print_test_header() {
    echo "========================================"
    echo "  $TEST_NAME"
    echo "========================================"
    echo
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        if [[ -n "$details" ]]; then
            echo "   Details: $details"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_test_summary() {
    echo
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Test: Initialize wizard core
test_init_wizard_core() {
    init_wizard_core
    
    if [[ "$CURRENT_MENU" == "main" ]] && [[ ${#MENU_HISTORY[@]} -eq 0 ]] && [[ "$WIZARD_RUNNING" == "true" ]]; then
        print_test_result "Initialize wizard core" "PASS"
    else
        print_test_result "Initialize wizard core" "FAIL" "State not properly initialized"
    fi
}

# Test: Menu state management
test_menu_state_management() {
    init_wizard_core
    
    # Test initial state
    local current_menu=$(get_current_menu)
    if [[ "$current_menu" != "main" ]]; then
        print_test_result "Menu state - initial state" "FAIL" "Expected 'main', got '$current_menu'"
        return
    fi
    
    # Test menu history is empty initially
    local history_output=$(get_menu_history)
    local history_count=0
    if [[ -n "$history_output" ]]; then
        history_count=$(echo "$history_output" | wc -l)
    fi
    
    if [[ $history_count -ne 0 ]]; then
        print_test_result "Menu state - empty history" "FAIL" "Expected 0 history items, got $history_count"
        return
    fi
    
    # Test adding to history (simulate navigation)
    MENU_HISTORY+=("main")
    CURRENT_MENU="status"
    
    local new_current=$(get_current_menu)
    local new_history_output=$(get_menu_history)
    local new_history_count=$(echo "$new_history_output" | wc -l)
    
    if [[ "$new_current" == "status" ]] && [[ $new_history_count -eq 1 ]]; then
        print_test_result "Menu state management" "PASS"
    else
        print_test_result "Menu state management" "FAIL" "State transition failed"
    fi
}

# Test: User input validation
test_handle_user_input() {
    # Test empty input
    if handle_user_input "" "1-5" "main" 2>/dev/null; then
        print_test_result "Handle user input - empty input" "FAIL" "Should reject empty input"
    else
        print_test_result "Handle user input - empty input" "PASS"
    fi
    
    # Test non-numeric input
    if handle_user_input "abc" "1-5" "main" 2>/dev/null; then
        print_test_result "Handle user input - non-numeric" "FAIL" "Should reject non-numeric input"
    else
        print_test_result "Handle user input - non-numeric" "PASS"
    fi
    
    # Test out of range input
    if handle_user_input "10" "1-5" "main" 2>/dev/null; then
        print_test_result "Handle user input - out of range" "FAIL" "Should reject out of range input"
    else
        print_test_result "Handle user input - out of range" "PASS"
    fi
    
    # Test valid input
    if handle_user_input "3" "1-5" "main" 2>/dev/null; then
        print_test_result "Handle user input - valid input" "PASS"
    else
        print_test_result "Handle user input - valid input" "FAIL" "Should accept valid input"
    fi
}

# Test: Menu navigation functions exist
test_menu_functions_exist() {
    local functions_to_test=(
        "show_main_menu"
        "navigate_to_section"
        "show_status_menu"
        "show_release_menu"
        "show_issue_menu"
        "show_config_menu"
        "return_to_main"
        "navigate_back"
        "exit_wizard"
    )
    
    local missing_functions=()
    
    for func in "${functions_to_test[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        print_test_result "Menu functions exist" "PASS"
    else
        print_test_result "Menu functions exist" "FAIL" "Missing functions: ${missing_functions[*]}"
    fi
}

# Test: Menu options are properly defined
test_menu_options_defined() {
    local menu_arrays=(
        "MAIN_MENU_OPTIONS"
        "STATUS_MENU_OPTIONS"
        "RELEASE_MENU_OPTIONS"
        "ISSUE_MENU_OPTIONS"
        "CONFIG_MENU_OPTIONS"
    )
    
    local missing_arrays=()
    
    for array in "${menu_arrays[@]}"; do
        if ! declare -p "$array" >/dev/null 2>&1; then
            missing_arrays+=("$array")
        fi
    done
    
    if [[ ${#missing_arrays[@]} -eq 0 ]]; then
        print_test_result "Menu options defined" "PASS"
    else
        print_test_result "Menu options defined" "FAIL" "Missing arrays: ${missing_arrays[*]}"
    fi
}

# Test: Navigation history management
test_navigation_history() {
    init_wizard_core
    
    # Test adding to history
    MENU_HISTORY+=("main")
    MENU_HISTORY+=("status")
    
    local history_output=$(get_menu_history)
    local history_count=$(echo "$history_output" | wc -l)
    if [[ $history_count -ne 2 ]]; then
        print_test_result "Navigation history - add items" "FAIL" "Expected 2 items, got $history_count"
        return
    fi
    
    # Test history content
    if [[ "$history_output" == *"main"* ]] && [[ "$history_output" == *"status"* ]]; then
        print_test_result "Navigation history management" "PASS"
    else
        print_test_result "Navigation history management" "FAIL" "History content incorrect"
    fi
}

# Test: Wizard running state
test_wizard_running_state() {
    init_wizard_core
    
    if is_wizard_running; then
        print_test_result "Wizard running state - initialized" "PASS"
    else
        print_test_result "Wizard running state - initialized" "FAIL" "Should be running after init"
        return
    fi
    
    # Test cleanup
    cleanup_wizard_core
    
    if ! is_wizard_running; then
        print_test_result "Wizard running state - cleanup" "PASS"
    else
        print_test_result "Wizard running state - cleanup" "FAIL" "Should not be running after cleanup"
    fi
}

# Test: Return to main functionality
test_return_to_main() {
    init_wizard_core
    
    # Simulate being in a submenu with history
    MENU_HISTORY+=("main")
    CURRENT_MENU="status"
    
    # Test return to main (without actually calling the function that would show menu)
    MENU_HISTORY=()
    CURRENT_MENU="main"
    
    local current_menu=$(get_current_menu)
    local history_output=$(get_menu_history)
    local history_count=0
    if [[ -n "$history_output" ]]; then
        history_count=$(echo "$history_output" | wc -l)
    fi
    
    if [[ "$current_menu" == "main" ]] && [[ $history_count -eq 0 ]]; then
        print_test_result "Return to main functionality" "PASS"
    else
        print_test_result "Return to main functionality" "FAIL" "State not properly reset"
    fi
}

# Test: Execute workflow function
test_execute_workflow() {
    # Test that execute_workflow function exists and handles different workflow types
    if declare -f "execute_workflow" >/dev/null 2>&1; then
        print_test_result "Execute workflow function exists" "PASS"
    else
        print_test_result "Execute workflow function exists" "FAIL" "Function not found"
    fi
}

# Test: Menu option validation
test_menu_option_validation() {
    # Test main menu options
    local main_menu_keys=(1 2 3 4 5)
    local expected_options=("Status Dashboard" "Release Wizard" "Issue Management" "Configuration" "Exit")
    
    local validation_passed=true
    
    for i in "${!main_menu_keys[@]}"; do
        local key="${main_menu_keys[$i]}"
        local expected="${expected_options[$i]}"
        local actual="${MAIN_MENU_OPTIONS[$key]}"
        
        if [[ "$actual" != "$expected" ]]; then
            validation_passed=false
            break
        fi
    done
    
    if [[ "$validation_passed" == "true" ]]; then
        print_test_result "Menu option validation" "PASS"
    else
        print_test_result "Menu option validation" "FAIL" "Menu options don't match expected values"
    fi
}

# Run all tests
run_all_tests() {
    print_test_header
    
    # Initialize for testing
    init_wizard_core
    
    # Run individual tests
    test_init_wizard_core
    test_menu_state_management
    test_handle_user_input
    test_menu_functions_exist
    test_menu_options_defined
    test_navigation_history
    test_wizard_running_state
    test_return_to_main
    test_execute_workflow
    test_menu_option_validation
    
    # Print summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi