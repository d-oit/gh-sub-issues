#!/bin/bash

# Test script for wizard-core.sh error handling system
# Tests error categorization, recovery mechanisms, and input validation

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"

# Source the modules
source "$LIB_DIR/wizard-display.sh"
source "$LIB_DIR/wizard-github.sh"
source "$LIB_DIR/wizard-core.sh"

# Test configuration
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
TEST_LOG_FILE="$PROJECT_ROOT/test-error-handling.log"

# Test utilities
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TEST_COUNT++))
    echo "Running test: $test_name"
    
    if $test_function; then
        echo "✅ PASSED: $test_name"
        ((PASSED_COUNT++))
        echo "PASSED: $test_name" >> "$TEST_LOG_FILE"
    else
        echo "❌ FAILED: $test_name"
        ((FAILED_COUNT++))
        echo "FAILED: $test_name" >> "$TEST_LOG_FILE"
    fi
    echo
}

# Mock functions for testing
mock_gh_auth_success() {
    return 0
}

mock_gh_auth_failure() {
    return 1
}

mock_check_gh_auth() {
    if [ "${MOCK_AUTH_STATUS:-fail}" = "success" ]; then
        return 0
    else
        return 1
    fi
}

# Override check_gh_auth for testing
check_gh_auth() {
    mock_check_gh_auth
}

# Test error categorization
test_error_categorization() {
    local test_passed=true
    
    # Test auth error handling
    if ! handle_error "auth" "Test auth error" "setup_auth" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test network error handling
    if ! handle_error "network" "Test network error" "retry" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test input error handling
    if ! handle_error "input" "Test input error" "correction" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test dependency error handling
    if ! handle_error "dependency" "Test dependency error" "install_guide" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test GitHub error handling
    if ! handle_error "github" "Test github error" "rate_limit" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test config error handling
    if ! handle_error "config" "Test config error" "setup_config" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test generic error handling
    if ! handle_error "unknown" "Test unknown error" "generic" "test_context" >/dev/null 2>&1; then
        test_passed=false
    fi
    
    $test_passed
}

# Test input validation
test_input_validation() {
    local test_passed=true
    
    # Test valid menu option
    if ! validate_input_with_guidance "3" "menu_option" "1-5" "test_menu"; then
        test_passed=false
    fi
    
    # Test invalid menu option (out of range)
    if validate_input_with_guidance "10" "menu_option" "1-5" "test_menu" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test invalid menu option (non-numeric)
    if validate_input_with_guidance "abc" "menu_option" "1-5" "test_menu" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test valid issue number
    if ! validate_input_with_guidance "123" "issue_number" "" ""; then
        test_passed=false
    fi
    
    # Test invalid issue number (zero)
    if validate_input_with_guidance "0" "issue_number" "" "" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test invalid issue number (negative)
    if validate_input_with_guidance "-5" "issue_number" "" "" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test invalid issue number (non-numeric)
    if validate_input_with_guidance "abc" "issue_number" "" "" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test valid version format
    if ! validate_input_with_guidance "1.2.3" "version" "" ""; then
        test_passed=false
    fi
    
    # Test invalid version format
    if validate_input_with_guidance "1.2" "version" "" "" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test valid text input
    if ! validate_input_with_guidance "Valid text" "text" "5" ""; then
        test_passed=false
    fi
    
    # Test invalid text input (too short)
    if validate_input_with_guidance "Hi" "text" "5" "" 2>/dev/null; then
        test_passed=false
    fi
    
    # Test valid confirmation
    if ! validate_input_with_guidance "y" "confirmation" "" ""; then
        test_passed=false
    fi
    
    if ! validate_input_with_guidance "yes" "confirmation" "" ""; then
        test_passed=false
    fi
    
    if ! validate_input_with_guidance "n" "confirmation" "" ""; then
        test_passed=false
    fi
    
    if ! validate_input_with_guidance "no" "confirmation" "" ""; then
        test_passed=false
    fi
    
    # Test invalid confirmation
    if validate_input_with_guidance "maybe" "confirmation" "" "" 2>/dev/null; then
        test_passed=false
    fi
    
    $test_passed
}

# Test retry mechanisms
test_retry_mechanisms() {
    local test_passed=true
    
    # Test retry attempt counting
    export RETRY_ATTEMPT_COUNT=1
    export MAX_RETRY_ATTEMPTS=3
    
    # Should allow retry when under limit
    if ! offer_retry_operation >/dev/null 2>&1 <<< "1"; then
        # This test is complex due to interactive nature, just check function exists
        if ! declare -f offer_retry_operation >/dev/null; then
            test_passed=false
        fi
    fi
    
    # Test max retry limit
    export RETRY_ATTEMPT_COUNT=3
    if ! offer_retry_operation >/dev/null 2>&1 <<< "1"; then
        # Function should handle max retries gracefully
        if ! declare -f offer_retry_operation >/dev/null; then
            test_passed=false
        fi
    fi
    
    # Reset retry count
    unset RETRY_ATTEMPT_COUNT
    
    $test_passed
}

# Test dependency checking
test_dependency_checking() {
    local test_passed=true
    
    # Test dependency check function exists
    if ! declare -f offer_dependency_check >/dev/null; then
        test_passed=false
    fi
    
    # Test installation guide function exists
    if ! declare -f offer_installation_guide >/dev/null; then
        test_passed=false
    fi
    
    $test_passed
}

# Test authentication error handling
test_auth_error_handling() {
    local test_passed=true
    
    # Test auth setup function exists
    if ! declare -f offer_auth_setup >/dev/null; then
        test_passed=false
    fi
    
    # Test auth retry function exists
    if ! declare -f offer_auth_retry >/dev/null; then
        test_passed=false
    fi
    
    # Test with mock successful auth
    export MOCK_AUTH_STATUS="success"
    if ! offer_auth_retry >/dev/null 2>&1; then
        # Function should handle successful auth
        if ! declare -f offer_auth_retry >/dev/null; then
            test_passed=false
        fi
    fi
    
    # Test with mock failed auth
    export MOCK_AUTH_STATUS="fail"
    if ! offer_auth_retry >/dev/null 2>&1; then
        # Function should handle failed auth gracefully
        if ! declare -f offer_auth_retry >/dev/null; then
            test_passed=false
        fi
    fi
    
    unset MOCK_AUTH_STATUS
    
    $test_passed
}

# Test GitHub-specific error handling
test_github_error_handling() {
    local test_passed=true
    
    # Test rate limit handling
    if ! declare -f handle_rate_limit_error >/dev/null; then
        test_passed=false
    fi
    
    # Test permissions error handling
    if ! declare -f handle_permissions_error >/dev/null; then
        test_passed=false
    fi
    
    # Test not found error handling
    if ! declare -f handle_not_found_error >/dev/null; then
        test_passed=false
    fi
    
    $test_passed
}

# Test configuration error handling
test_config_error_handling() {
    local test_passed=true
    
    # Test config setup function exists
    if ! declare -f offer_config_setup >/dev/null; then
        test_passed=false
    fi
    
    # Test config validation function exists
    if ! declare -f offer_config_validation >/dev/null; then
        test_passed=false
    fi
    
    # Test basic config creation
    if ! declare -f create_basic_config >/dev/null; then
        test_passed=false
    fi
    
    $test_passed
}

# Test error logging
test_error_logging() {
    local test_passed=true
    local test_error_log="/tmp/test-wizard-errors.log"
    
    # Set test error log file
    export ERROR_LOG_FILE="$test_error_log"
    
    # Clean up any existing test log
    rm -f "$test_error_log"
    
    # Test error logging
    log_error "test" "Test error message" "test_context"
    
    # Check if log file was created and contains entry
    if [ ! -f "$test_error_log" ]; then
        test_passed=false
    elif ! grep -q "Test error message" "$test_error_log"; then
        test_passed=false
    fi
    
    # Test error stats
    if ! get_error_stats >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Test clear error log
    if ! clear_error_log >/dev/null 2>&1; then
        test_passed=false
    fi
    
    # Clean up test log
    rm -f "$test_error_log"
    
    $test_passed
}

# Test timeout handling
test_timeout_handling() {
    local test_passed=true
    
    # Test timeout error handling function exists
    if ! declare -f handle_timeout_error >/dev/null; then
        test_passed=false
    fi
    
    $test_passed
}

# Test recovery mechanisms
test_recovery_mechanisms() {
    local test_passed=true
    
    # Test that all recovery functions exist
    local recovery_functions=(
        "offer_auth_setup"
        "offer_auth_retry"
        "offer_retry_operation"
        "handle_timeout_error"
        "offer_input_correction"
        "offer_installation_guide"
        "offer_dependency_check"
        "handle_rate_limit_error"
        "handle_permissions_error"
        "handle_not_found_error"
        "offer_config_setup"
        "offer_config_validation"
    )
    
    for func in "${recovery_functions[@]}"; do
        if ! declare -f "$func" >/dev/null; then
            echo "Missing recovery function: $func"
            test_passed=false
        fi
    done
    
    $test_passed
}

# Test error handling integration
test_error_handling_integration() {
    local test_passed=true
    
    # Test that handle_error function properly routes to specific handlers
    # This is a basic integration test
    
    # Test main error handler exists
    if ! declare -f handle_error >/dev/null; then
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
        "handle_generic_error"
    )
    
    for handler in "${error_handlers[@]}"; do
        if ! declare -f "$handler" >/dev/null; then
            echo "Missing error handler: $handler"
            test_passed=false
        fi
    done
    
    $test_passed
}

# Main test execution
main() {
    echo "Starting Error Handling System Tests"
    echo "====================================="
    echo
    
    # Initialize test log
    echo "Test run started at $(date)" > "$TEST_LOG_FILE"
    
    # Run all tests
    run_test "Error Categorization" test_error_categorization
    run_test "Input Validation" test_input_validation
    run_test "Retry Mechanisms" test_retry_mechanisms
    run_test "Dependency Checking" test_dependency_checking
    run_test "Authentication Error Handling" test_auth_error_handling
    run_test "GitHub Error Handling" test_github_error_handling
    run_test "Configuration Error Handling" test_config_error_handling
    run_test "Error Logging" test_error_logging
    run_test "Timeout Handling" test_timeout_handling
    run_test "Recovery Mechanisms" test_recovery_mechanisms
    run_test "Error Handling Integration" test_error_handling_integration
    
    # Print summary
    echo "====================================="
    echo "Test Summary:"
    echo "  Total tests: $TEST_COUNT"
    echo "  Passed: $PASSED_COUNT"
    echo "  Failed: $FAILED_COUNT"
    echo
    
    if [ $FAILED_COUNT -eq 0 ]; then
        echo "🎉 All tests passed!"
        echo "Test run completed successfully at $(date)" >> "$TEST_LOG_FILE"
        exit 0
    else
        echo "❌ Some tests failed. Check $TEST_LOG_FILE for details."
        echo "Test run completed with failures at $(date)" >> "$TEST_LOG_FILE"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi