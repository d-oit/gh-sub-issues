#!/bin/bash

# Test script for wizard debug mode functionality
# Tests debug mode activation and logging without external dependencies

set -euo pipefail

# Test configuration
TEST_NAME="Wizard Debug Mode"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="$SCRIPT_DIR/test-logs"
TEST_LOG_FILE="$TEST_LOG_DIR/debug-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_test_header() {
    echo -e "${BLUE}=== $TEST_NAME Tests ===${NC}"
    echo "Testing debug mode functionality"
    echo
}

# Setup test environment
setup_test_environment() {
    mkdir -p "$TEST_LOG_DIR"
    rm -f "$TEST_LOG_DIR"/*.log* 2>/dev/null || true
    
    export ENABLE_LOGGING="true"
    export LOG_LEVEL="DEBUG"
    export LOG_FILE="$TEST_LOG_FILE"
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    export PERFORMANCE_MONITORING="false"
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

test_debug_mode_activation() {
    echo -e "${YELLOW}Testing Debug Mode Activation...${NC}"
    
    # Reset debug mode
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    
    # Enable debug mode
    enable_debug_mode
    
    if [ "$DEBUG_MODE" = "true" ] && [ "$VERBOSE_MODE" = "true" ] && [ "$ENABLE_LOGGING" = "true" ] && [ "$LOG_LEVEL" = "DEBUG" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Debug mode activated correctly"
    else
        echo -e "${RED}❌ FAIL${NC}: Debug mode not activated correctly"
        echo "  DEBUG_MODE: $DEBUG_MODE (expected: true)"
        echo "  VERBOSE_MODE: $VERBOSE_MODE (expected: true)"
        echo "  ENABLE_LOGGING: $ENABLE_LOGGING (expected: true)"
        echo "  LOG_LEVEL: $LOG_LEVEL (expected: DEBUG)"
        return 1
    fi
}

test_verbose_mode_activation() {
    echo -e "${YELLOW}Testing Verbose Mode Activation...${NC}"
    
    # Reset verbose mode
    export VERBOSE_MODE="false"
    
    # Enable verbose mode
    enable_verbose_mode
    
    if [ "$VERBOSE_MODE" = "true" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Verbose mode activated correctly"
    else
        echo -e "${RED}❌ FAIL${NC}: Verbose mode not activated correctly"
        return 1
    fi
}

test_performance_monitoring_activation() {
    echo -e "${YELLOW}Testing Performance Monitoring Activation...${NC}"
    
    # Reset performance monitoring
    export PERFORMANCE_MONITORING="false"
    
    # Enable performance monitoring
    enable_performance_monitoring
    
    if [ "$PERFORMANCE_MONITORING" = "true" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Performance monitoring activated correctly"
    else
        echo -e "${RED}❌ FAIL${NC}: Performance monitoring not activated correctly"
        return 1
    fi
}

test_debug_config_dump() {
    echo -e "${YELLOW}Testing Debug Configuration Dump...${NC}"
    
    # Enable debug mode
    export DEBUG_MODE="true"
    
    # Capture config dump output
    local output
    output=$(dump_debug_config 2>&1)
    
    if echo "$output" | grep -q "DEBUG CONFIGURATION DUMP" && echo "$output" | grep -q "DEBUG_MODE: true"; then
        echo -e "${GREEN}✅ PASS${NC}: Debug configuration dump working"
    else
        echo -e "${RED}❌ FAIL${NC}: Debug configuration dump not working"
        echo "Output: $output"
        return 1
    fi
}

test_argument_parsing() {
    echo -e "${YELLOW}Testing Command Line Argument Parsing...${NC}"
    
    # Reset modes
    export DEBUG_MODE="false"
    export VERBOSE_MODE="false"
    export PERFORMANCE_MONITORING="false"
    
    # Test parsing debug arguments
    parse_debug_args --debug --verbose --performance
    
    if [ "$DEBUG_MODE" = "true" ] && [ "$VERBOSE_MODE" = "true" ] && [ "$PERFORMANCE_MONITORING" = "true" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Command line arguments parsed correctly"
    else
        echo -e "${RED}❌ FAIL${NC}: Command line arguments not parsed correctly"
        echo "  DEBUG_MODE: $DEBUG_MODE (expected: true)"
        echo "  VERBOSE_MODE: $VERBOSE_MODE (expected: true)"
        echo "  PERFORMANCE_MONITORING: $PERFORMANCE_MONITORING (expected: true)"
        return 1
    fi
}

test_log_level_argument() {
    echo -e "${YELLOW}Testing Log Level Argument...${NC}"
    
    # Test log level argument
    export LOG_LEVEL="INFO"
    
    if parse_debug_args --log-level DEBUG; then
        if [ "$LOG_LEVEL" = "DEBUG" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Log level argument processed correctly"
        else
            echo -e "${RED}❌ FAIL${NC}: Log level not updated (got: $LOG_LEVEL, expected: DEBUG)"
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Log level argument parsing failed"
        return 1
    fi
}

test_log_file_argument() {
    echo -e "${YELLOW}Testing Log File Argument...${NC}"
    
    # Test log file argument
    local test_log_path="/tmp/test-wizard.log"
    export LOG_FILE="$TEST_LOG_FILE"
    
    if parse_debug_args --log-file "$test_log_path"; then
        if [ "$LOG_FILE" = "$test_log_path" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Log file argument processed correctly"
        else
            echo -e "${RED}❌ FAIL${NC}: Log file not updated (got: $LOG_FILE, expected: $test_log_path)"
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Log file argument parsing failed"
        return 1
    fi
}

# Cleanup test environment
cleanup_test_environment() {
    rm -rf "$TEST_LOG_DIR" 2>/dev/null || true
    unset ENABLE_LOGGING LOG_LEVEL LOG_FILE DEBUG_MODE VERBOSE_MODE PERFORMANCE_MONITORING
}

main() {
    print_test_header
    
    # Setup test environment
    setup_test_environment
    
    # Load wizard configuration module
    if ! load_wizard_config; then
        echo "Failed to load wizard configuration module"
        exit 1
    fi
    
    # Run tests
    local failed_tests=0
    
    test_debug_mode_activation || failed_tests=$((failed_tests + 1))
    test_verbose_mode_activation || failed_tests=$((failed_tests + 1))
    test_performance_monitoring_activation || failed_tests=$((failed_tests + 1))
    test_debug_config_dump || failed_tests=$((failed_tests + 1))
    test_argument_parsing || failed_tests=$((failed_tests + 1))
    test_log_level_argument || failed_tests=$((failed_tests + 1))
    test_log_file_argument || failed_tests=$((failed_tests + 1))
    
    # Cleanup test environment
    cleanup_test_environment
    
    # Print summary
    echo
    if [ $failed_tests -eq 0 ]; then
        echo -e "${GREEN}All debug mode tests passed!${NC}"
        return 0
    else
        echo -e "${RED}$failed_tests test(s) failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi