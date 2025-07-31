#!/bin/bash

# Test script for wizard logging functionality
# Tests logging system, debug mode, verbose mode, and performance monitoring

set -euo pipefail

# Test configuration
TEST_NAME="Wizard Logging System"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="$SCRIPT_DIR/test-logs"
TEST_LOG_FILE="$TEST_LOG_DIR/test-wizard.log"

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
    echo "Testing logging functionality, debug mode, and performance monitoring"
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
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    export PERFORMANCE_MONITORING="false"
    export LOG_ROTATION_SIZE="1024"  # Small size for testing rotation
    export LOG_ROTATION_COUNT="3"
}

# Cleanup test environment
cleanup_test_environment() {
    # Clean up test logs
    rm -rf "$TEST_LOG_DIR" 2>/dev/null || true
    
    # Reset environment variables
    unset ENABLE_LOGGING LOG_LEVEL LOG_FILE DEBUG_MODE VERBOSE_MODE
    unset PERFORMANCE_MONITORING LOG_ROTATION_SIZE LOG_ROTATION_COUNT
}

# Load wizard configuration module
load_wizard_config() {
    local config_path="$PROJECT_ROOT/lib/wizard-config.sh"
    if [ -f "$config_path" ]; then
        # shellcheck source=../lib/wizard-config.sh
        source "$config_path"
        return 0
    else
        echo "Error: Cannot find wizard-config.sh at $config_path"
        return 1
    fi
}

# === LOGGING SYSTEM TESTS ===

test_log_initialization() {
    local test_name="Log Initialization"
    
    # Initialize logging
    if log_init; then
        # Check if log file was created
        if [ -f "$TEST_LOG_FILE" ]; then
            print_test_result "$test_name" "PASS"
        else
            print_test_result "$test_name" "FAIL" "Log file not created"
        fi
    else
        print_test_result "$test_name" "FAIL" "log_init failed"
    fi
}

test_log_levels() {
    local test_name="Log Level Filtering"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Set log level to WARN
    export LOG_LEVEL="WARN"
    log_init
    
    # Write messages at different levels
    log_debug "test" "Debug message"
    log_info "test" "Info message"
    log_warn "test" "Warning message"
    log_error "test" "Error message"
    
    # Check log contents
    local debug_count=0 info_count=0 warn_count=0 error_count=0
    
    if grep -q "\[DEBUG\]" "$TEST_LOG_FILE" 2>/dev/null; then
        debug_count=$(grep -c "\[DEBUG\]" "$TEST_LOG_FILE" 2>/dev/null)
    fi
    
    if grep -q "\[INFO\]" "$TEST_LOG_FILE" 2>/dev/null; then
        info_count=$(grep -c "\[INFO\]" "$TEST_LOG_FILE" 2>/dev/null)
    fi
    
    if grep -q "\[WARN\]" "$TEST_LOG_FILE" 2>/dev/null; then
        warn_count=$(grep -c "\[WARN\]" "$TEST_LOG_FILE" 2>/dev/null)
    fi
    
    if grep -q "\[ERROR\]" "$TEST_LOG_FILE" 2>/dev/null; then
        error_count=$(grep -c "\[ERROR\]" "$TEST_LOG_FILE" 2>/dev/null)
    fi
    
    if [ "$debug_count" -eq 0 ] && [ "$info_count" -eq 0 ] && [ "$warn_count" -eq 1 ] && [ "$error_count" -eq 1 ]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Expected 0 DEBUG, 0 INFO, 1 WARN, 1 ERROR. Got $debug_count, $info_count, $warn_count, $error_count"
    fi
    
    # Reset log level
    export LOG_LEVEL="DEBUG"
}

test_log_rotation() {
    local test_name="Log Rotation"
    
    # Set small rotation size for testing
    export LOG_ROTATION_SIZE="100"
    export LOG_ROTATION_COUNT="2"
    
    # Clear existing logs
    rm -f "$TEST_LOG_FILE"* 2>/dev/null || true
    
    # Initialize logging
    log_init
    
    # Write enough data to trigger rotation
    for i in {1..20}; do
        log_info "test_rotation" "This is a test message number $i to fill up the log file for rotation testing"
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

test_performance_timing() {
    local test_name="Performance Timing"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Test timing function
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    sleep 0.1  # Small delay for testing
    log_timing "test_function" "$start_time"
    
    # Check if timing was logged
    if grep -q "Execution time:" "$TEST_LOG_FILE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Timing information not logged"
    fi
}

# === DEBUG MODE TESTS ===

test_debug_mode_activation() {
    local test_name="Debug Mode Activation"
    
    # Reset debug mode
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    
    # Enable debug mode
    enable_debug_mode
    
    if [ "$DEBUG_MODE" = "true" ] && [ "$VERBOSE_MODE" = "true" ] && [ "$ENABLE_LOGGING" = "true" ] && [ "$LOG_LEVEL" = "DEBUG" ]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Debug mode not properly activated"
    fi
}

test_verbose_output() {
    local test_name="Verbose Output"
    
    # Enable verbose mode
    export VERBOSE_MODE="true"
    
    # Capture verbose output
    local output
    output=$(log_verbose "test_function" "Test verbose message" 2>&1)
    
    if echo "$output" | grep -q "VERBOSE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Verbose output not generated"
    fi
}

test_debug_config_dump() {
    local test_name="Debug Configuration Dump"
    
    # Enable debug mode
    export DEBUG_MODE="true"
    
    # Capture config dump output
    local output
    output=$(dump_debug_config 2>&1)
    
    if echo "$output" | grep -q "DEBUG CONFIGURATION DUMP" && echo "$output" | grep -q "DEBUG_MODE: true"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Debug configuration dump not working"
    fi
}

# === PERFORMANCE MONITORING TESTS ===

test_performance_monitoring() {
    local test_name="Performance Monitoring"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Enable performance monitoring
    export PERFORMANCE_MONITORING="true"
    
    # Simulate slow operation (using a very low threshold for testing)
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    sleep 0.1
    log_timing "slow_test_function" "$start_time" "github_api"
    
    # Check if slow operation was detected (with 2 second threshold for API calls)
    # Since we only slept 0.1 seconds, it shouldn't be flagged as slow
    if ! grep -q "SLOW OPERATION" "$TEST_LOG_FILE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "False positive for slow operation detection"
    fi
}

test_github_api_wrapper() {
    local test_name="GitHub API Wrapper"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Mock GitHub CLI command (this will fail, but we're testing the wrapper)
    local output
    output=$(gh_api_call "user" "test_function" 2>&1 || true)
    
    # Check if the API call was logged
    if grep -q "GitHub API call: user" "$TEST_LOG_FILE"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "GitHub API call not logged"
    fi
}

# === CONFIGURATION TESTS ===

test_config_update() {
    local test_name="Configuration Update"
    
    # Test updating log level
    if update_config "LOG_LEVEL" "ERROR"; then
        if [ "$LOG_LEVEL" = "ERROR" ]; then
            print_test_result "$test_name" "PASS"
        else
            print_test_result "$test_name" "FAIL" "Log level not updated"
        fi
    else
        print_test_result "$test_name" "FAIL" "update_config failed"
    fi
    
    # Reset log level
    export LOG_LEVEL="DEBUG"
}

test_invalid_config_update() {
    local test_name="Invalid Configuration Handling"
    
    # Test invalid log level
    if ! update_config "LOG_LEVEL" "INVALID"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Invalid configuration was accepted"
    fi
}

test_argument_parsing() {
    local test_name="Command Line Argument Parsing"
    
    # Reset modes
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    export PERFORMANCE_MONITORING="false"
    
    # Test parsing debug arguments
    parse_debug_args --debug --verbose --performance
    
    if [ "$DEBUG_MODE" = "true" ] && [ "$VERBOSE_MODE" = "true" ] && [ "$PERFORMANCE_MONITORING" = "true" ]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Arguments not parsed correctly"
    fi
}

# === INTEGRATION TESTS ===

test_logging_integration() {
    local test_name="Logging Integration"
    
    # Clear log file
    > "$TEST_LOG_FILE"
    
    # Test full logging workflow
    log_init
    log_info "integration_test" "Starting integration test"
    
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    log_debug "integration_test" "Debug message during integration test"
    log_timing "integration_test" "$start_time"
    
    log_info "integration_test" "Integration test completed"
    
    # Check log contents
    local log_lines
    log_lines=$(wc -l < "$TEST_LOG_FILE" 2>/dev/null || echo 0)
    
    if [ "$log_lines" -ge 3 ]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Expected at least 3 log lines, got $log_lines"
    fi
}

# === MAIN TEST EXECUTION ===

main() {
    print_test_header
    
    # Setup test environment
    setup_test_environment
    
    # Load wizard configuration module
    if ! load_wizard_config; then
        echo "Failed to load wizard configuration module"
        exit 1
    fi
    
    # Run logging system tests
    echo -e "${YELLOW}Testing Logging System...${NC}"
    test_log_initialization
    test_log_levels
    test_log_rotation
    test_performance_timing
    
    echo
    echo -e "${YELLOW}Testing Debug Mode...${NC}"
    test_debug_mode_activation
    test_verbose_output
    test_debug_config_dump
    
    echo
    echo -e "${YELLOW}Testing Performance Monitoring...${NC}"
    test_performance_monitoring
    test_github_api_wrapper
    
    echo
    echo -e "${YELLOW}Testing Configuration...${NC}"
    test_config_update
    test_invalid_config_update
    test_argument_parsing
    
    echo
    echo -e "${YELLOW}Testing Integration...${NC}"
    test_logging_integration
    
    # Cleanup test environment
    cleanup_test_environment
    
    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi