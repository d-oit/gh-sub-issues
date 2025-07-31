#!/bin/bash

# Integration test for wizard logging functionality
# Tests the complete logging system integration across all modules

set -euo pipefail

# Test configuration
TEST_NAME="Wizard Logging Integration"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="$SCRIPT_DIR/test-logs"
TEST_LOG_FILE="$TEST_LOG_DIR/integration-test.log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === TEST UTILITIES ===

print_test_header() {
    echo -e "${BLUE}=== $TEST_NAME Tests ===${NC}"
    echo "Testing complete logging system integration"
    echo
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        if [ -n "$message" ]; then
            echo -e "   ${RED}Error${NC}: $message"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_test_summary() {
    echo
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Setup test environment
setup_test_environment() {
    # Create test log directory
    mkdir -p "$TEST_LOG_DIR"
    
    # Clean up any existing test logs
    rm -f "$TEST_LOG_DIR"/*.log* 2>/dev/null || true
    
    # Set test environment variables
    export ENABLE_LOGGING="true"
    export LOG_LEVEL="DEBUG"
    export LOG_FILE="$TEST_LOG_FILE"
    export DEBUG_MODE="true"
    export VERBOSE_MODE="true"
    export PERFORMANCE_MONITORING="true"
}

# Cleanup test environment
cleanup_test_environment() {
    # Clean up test logs
    rm -rf "$TEST_LOG_DIR" 2>/dev/null || true
    
    # Reset environment variables
    unset ENABLE_LOGGING LOG_LEVEL LOG_FILE DEBUG_MODE VERBOSE_MODE PERFORMANCE_MONITORING
}

# === INTEGRATION TESTS ===

test_wizard_config_loading() {
    local test_name="Wizard Configuration Module Loading"
    
    # Load wizard configuration module
    local config_path="$PROJECT_ROOT/lib/wizard-config.sh"
    if [ -f "$config_path" ]; then
        # shellcheck source=../lib/wizard-config.sh
        if source "$config_path"; then
            # Test if logging functions are available
            if command -v log_init >/dev/null 2>&1 && command -v log_info >/dev/null 2>&1; then
                print_test_result "$test_name" "PASS"
            else
                print_test_result "$test_name" "FAIL" "Logging functions not available after loading config module"
            fi
        else
            print_test_result "$test_name" "FAIL" "Failed to source wizard-config.sh"
        fi
    else
        print_test_result "$test_name" "FAIL" "wizard-config.sh not found at $config_path"
    fi
}

test_cross_module_logging() {
    local test_name="Cross-Module Logging Integration"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Initialize logging
    if log_init; then
        # Test logging from different modules
        log_info "wizard_config" "Configuration module logging test"
        
        # Load display module if available
        local display_path="$PROJECT_ROOT/lib/wizard-display.sh"
        if [ -f "$display_path" ]; then
            # shellcheck source=../lib/wizard-display.sh
            source "$display_path" 2>/dev/null || true
        fi
        
        # Load core module if available
        local core_path="$PROJECT_ROOT/lib/wizard-core.sh"
        if [ -f "$core_path" ]; then
            # shellcheck source=../lib/wizard-core.sh
            source "$core_path" 2>/dev/null || true
            
            # Test core module logging if available
            if command -v init_core_logging >/dev/null 2>&1; then
                init_core_logging
            fi
        fi
        
        # Check if logs were written
        local log_lines
        log_lines=$(wc -l < "$TEST_LOG_FILE" 2>/dev/null || echo 0)
        
        if [ "$log_lines" -gt 0 ]; then
            print_test_result "$test_name" "PASS"
        else
            print_test_result "$test_name" "FAIL" "No log entries found"
        fi
    else
        print_test_result "$test_name" "FAIL" "Failed to initialize logging"
    fi
}

test_debug_mode_integration() {
    local test_name="Debug Mode Integration"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Enable debug mode
    enable_debug_mode
    
    # Initialize logging
    log_init
    
    # Test debug logging
    log_debug "integration_test" "Debug mode integration test"
    log_info "integration_test" "Info level message"
    
    # Check if debug messages were logged
    if grep -q "\[DEBUG\]" "$TEST_LOG_FILE" && grep -q "Debug mode integration test" "$TEST_LOG_FILE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Debug messages not found in log"
    fi
}

test_performance_monitoring_integration() {
    local test_name="Performance Monitoring Integration"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Enable performance monitoring
    enable_performance_monitoring
    log_init
    
    # Test performance timing
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    sleep 0.1
    log_timing "integration_test" "$start_time" "test_operation"
    
    # Check if timing was logged
    if grep -q "test_operation execution time" "$TEST_LOG_FILE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Performance timing not logged"
    fi
}

test_github_api_wrapper_integration() {
    local test_name="GitHub API Wrapper Integration"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    log_init
    
    # Test GitHub API wrapper (this will fail but should log the attempt)
    # Only test if gh command is available
    if command -v gh >/dev/null 2>&1; then
        gh_api_call "user" "integration_test" 2>/dev/null || true
        
        # Check if API call was logged
        if grep -q "GitHub API call: user" "$TEST_LOG_FILE"; then
            print_test_result "$test_name" "PASS"
        else
            print_test_result "$test_name" "FAIL" "GitHub API call not logged"
        fi
    else
        # Skip test if gh is not available
        log_info "integration_test" "GitHub CLI not available, skipping API wrapper test"
        print_test_result "$test_name" "PASS" "Skipped - GitHub CLI not available"
    fi
}

test_log_rotation_integration() {
    local test_name="Log Rotation Integration"
    
    # Set small rotation size for testing
    export LOG_ROTATION_SIZE="200"
    export LOG_ROTATION_COUNT="2"
    
    # Clear existing logs
    rm -f "$TEST_LOG_FILE"* 2>/dev/null || true
    
    # Initialize logging
    log_init
    
    # Write enough data to trigger rotation
    for i in {1..10}; do
        log_info "rotation_test" "This is a test message number $i to fill up the log file for rotation testing purposes"
    done
    
    # Trigger rotation check
    rotate_logs_if_needed
    
    # Check if rotation occurred
    if [ -f "${TEST_LOG_FILE}.1" ]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Log rotation did not occur"
    fi
    
    # Reset rotation settings
    export LOG_ROTATION_SIZE="10485760"
    export LOG_ROTATION_COUNT="5"
}

test_verbose_output_integration() {
    local test_name="Verbose Output Integration"
    
    # Enable verbose mode
    export VERBOSE_MODE="true"
    log_init
    
    # Capture verbose output
    local output
    output=$(log_verbose "integration_test" "Verbose integration test message" 2>&1)
    
    if echo "$output" | grep -q "VERBOSE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Verbose output not generated"
    fi
}

test_configuration_update_integration() {
    local test_name="Configuration Update Integration"
    
    # Test updating configuration
    if update_config "LOG_LEVEL" "WARN"; then
        if [ "$LOG_LEVEL" = "WARN" ]; then
            print_test_result "$test_name" "PASS"
        else
            print_test_result "$test_name" "FAIL" "Configuration not updated"
        fi
    else
        print_test_result "$test_name" "FAIL" "Configuration update failed"
    fi
    
    # Reset log level
    export LOG_LEVEL="DEBUG"
}

# === MAIN TEST EXECUTION ===

main() {
    print_test_header
    
    # Setup test environment
    setup_test_environment
    
    # Run integration tests
    echo -e "${YELLOW}Testing Module Loading...${NC}"
    test_wizard_config_loading
    
    echo
    echo -e "${YELLOW}Testing Cross-Module Integration...${NC}"
    test_cross_module_logging
    test_debug_mode_integration
    test_performance_monitoring_integration
    test_github_api_wrapper_integration
    
    echo
    echo -e "${YELLOW}Testing Advanced Features...${NC}"
    test_log_rotation_integration
    test_verbose_output_integration
    test_configuration_update_integration
    
    # Cleanup test environment
    cleanup_test_environment
    
    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi