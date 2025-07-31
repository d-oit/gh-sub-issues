#!/bin/bash

# Integration test for GitHub Wizard Core Module
# Tests the core module in isolation without dependencies

# Test configuration
TEST_NAME="GitHub Wizard Core Integration Test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source the module under test
source "$LIB_DIR/wizard-core.sh"

# Test utilities
print_test_header() {
    echo "========================================"
    echo "  $TEST_NAME"
    echo "========================================"
    echo
}

# Test: Core module can be loaded and initialized
test_core_module_loading() {
    echo "Testing core module loading and initialization..."
    
    # Initialize the core
    init_wizard_core
    
    # Check if all required functions are available
    local required_functions=(
        "show_main_menu"
        "navigate_to_section"
        "handle_user_input"
        "return_to_main"
        "exit_wizard"
        "get_current_menu"
        "is_wizard_running"
    )
    
    local missing_functions=()
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        echo "✅ All required functions are available"
    else
        echo "❌ Missing functions: ${missing_functions[*]}"
        return 1
    fi
    
    # Check if menu options are properly defined
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
        echo "✅ All menu option arrays are defined"
    else
        echo "❌ Missing menu arrays: ${missing_arrays[*]}"
        return 1
    fi
    
    echo "✅ Core module loaded and initialized successfully"
    return 0
}

# Test: Menu state transitions
test_menu_state_transitions() {
    echo "Testing menu state transitions..."
    
    init_wizard_core
    
    # Test initial state
    local initial_menu=$(get_current_menu)
    if [[ "$initial_menu" != "main" ]]; then
        echo "❌ Initial menu state incorrect: expected 'main', got '$initial_menu'"
        return 1
    fi
    
    # Test state changes
    CURRENT_MENU="status"
    local new_menu=$(get_current_menu)
    if [[ "$new_menu" != "status" ]]; then
        echo "❌ Menu state change failed: expected 'status', got '$new_menu'"
        return 1
    fi
    
    # Test history management
    MENU_HISTORY+=("main")
    MENU_HISTORY+=("status")
    
    local history_output=$(get_menu_history)
    if [[ "$history_output" != *"main"* ]] || [[ "$history_output" != *"status"* ]]; then
        echo "❌ Menu history not working correctly"
        return 1
    fi
    
    echo "✅ Menu state transitions working correctly"
    return 0
}

# Test: Input validation
test_input_validation() {
    echo "Testing input validation..."
    
    # Test valid inputs
    local test_cases=(
        "1:1-5:valid"
        "3:1-5:valid"
        "5:1-5:valid"
        "0:1-5:invalid"
        "6:1-5:invalid"
        "abc:1-5:invalid"
        "":1-5:invalid"
        " ":1-5:invalid"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r input range expected <<< "$test_case"
        
        if handle_user_input "$input" "$range" "main" 2>/dev/null; then
            result="valid"
        else
            result="invalid"
        fi
        
        if [[ "$result" != "$expected" ]]; then
            echo "❌ Input validation failed for '$input' (range: $range): expected $expected, got $result"
            return 1
        fi
    done
    
    echo "✅ Input validation working correctly"
    return 0
}

# Test: Wizard lifecycle
test_wizard_lifecycle() {
    echo "Testing wizard lifecycle..."
    
    # Test initialization
    init_wizard_core
    if ! is_wizard_running; then
        echo "❌ Wizard should be running after initialization"
        return 1
    fi
    
    # Test cleanup
    cleanup_wizard_core
    if is_wizard_running; then
        echo "❌ Wizard should not be running after cleanup"
        return 1
    fi
    
    echo "✅ Wizard lifecycle working correctly"
    return 0
}

# Run integration tests
run_integration_tests() {
    print_test_header
    
    local tests_passed=0
    local tests_total=4
    
    # Run tests
    if test_core_module_loading; then
        ((tests_passed++))
    fi
    echo
    
    if test_menu_state_transitions; then
        ((tests_passed++))
    fi
    echo
    
    if test_input_validation; then
        ((tests_passed++))
    fi
    echo
    
    if test_wizard_lifecycle; then
        ((tests_passed++))
    fi
    echo
    
    # Print summary
    echo "========================================"
    echo "  Integration Test Summary"
    echo "========================================"
    echo "Tests Passed: $tests_passed/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        echo "✅ All integration tests passed!"
        return 0
    else
        echo "❌ Some integration tests failed!"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
fi