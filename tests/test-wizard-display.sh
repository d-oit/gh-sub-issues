#!/bin/bash

# Unit tests for wizard-display.sh module

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
DISPLAY_MODULE="$PROJECT_ROOT/lib/wizard-display.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo -e "   Expected: $expected"
        echo -e "   Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local substring="$1"
    local text="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$text" == *"$substring"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo -e "   Expected substring: $substring"
        echo -e "   In text: $text"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo -e "   Expected non-empty value"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Setup test environment
setup_tests() {
    echo -e "${BLUE}Setting up wizard-display.sh tests...${NC}"
    
    # Check if display module exists
    if [[ ! -f "$DISPLAY_MODULE" ]]; then
        echo -e "${RED}Error: Display module not found at $DISPLAY_MODULE${NC}"
        exit 1
    fi
    
    # Source the display module
    source "$DISPLAY_MODULE"
    
    echo -e "${GREEN}Setup complete!${NC}"
    echo
}

# Test print_header function
test_print_header() {
    echo -e "${YELLOW}Testing print_header function...${NC}"
    
    # Test basic header
    local output
    output=$(print_header "Test Header" 2>&1)
    assert_contains "Test Header" "$output" "print_header includes title"
    assert_contains "=" "$output" "print_header includes separator"
    
    # Test header with custom width
    output=$(print_header "Short" 10 2>&1)
    assert_contains "Short" "$output" "print_header with custom width includes title"
}

# Test print_menu_option function
test_print_menu_option() {
    echo -e "${YELLOW}Testing print_menu_option function...${NC}"
    
    # Test normal menu option
    local output
    output=$(print_menu_option "1" "Test Option" 2>&1)
    assert_contains "1." "$output" "print_menu_option includes number"
    assert_contains "Test Option" "$output" "print_menu_option includes text"
    
    # Test selected menu option
    output=$(print_menu_option "2" "Selected Option" "true" 2>&1)
    assert_contains "2." "$output" "print_menu_option selected includes number"
    assert_contains "Selected Option" "$output" "print_menu_option selected includes text"
    assert_contains "➤" "$output" "print_menu_option selected includes arrow"
}

# Test print_status_line function
test_print_status_line() {
    echo -e "${YELLOW}Testing print_status_line function...${NC}"
    
    # Test success status
    local output
    output=$(print_status_line "success" "Operation completed" 2>&1)
    assert_contains "✅" "$output" "print_status_line success includes icon"
    assert_contains "Operation completed" "$output" "print_status_line success includes message"
    
    # Test error status
    output=$(print_status_line "error" "Operation failed" 2>&1)
    assert_contains "❌" "$output" "print_status_line error includes icon"
    assert_contains "Operation failed" "$output" "print_status_line error includes message"
    
    # Test warning status
    output=$(print_status_line "warning" "Warning message" 2>&1)
    assert_contains "⚠️" "$output" "print_status_line warning includes icon"
    assert_contains "Warning message" "$output" "print_status_line warning includes message"
    
    # Test info status
    output=$(print_status_line "info" "Info message" 2>&1)
    assert_contains "ℹ️" "$output" "print_status_line info includes icon"
    assert_contains "Info message" "$output" "print_status_line info includes message"
    
    # Test progress status
    output=$(print_status_line "progress" "Processing..." 2>&1)
    assert_contains "⏳" "$output" "print_status_line progress includes icon"
    assert_contains "Processing..." "$output" "print_status_line progress includes message"
    
    # Test with details
    output=$(print_status_line "success" "Main message" "Additional details" 2>&1)
    assert_contains "Main message" "$output" "print_status_line with details includes main message"
    assert_contains "Additional details" "$output" "print_status_line with details includes details"
}

# Test print_error function
test_print_error() {
    echo -e "${YELLOW}Testing print_error function...${NC}"
    
    # Test basic error
    local output
    output=$(print_error "Test error message" 2>&1)
    assert_contains "❌" "$output" "print_error includes icon"
    assert_contains "ERROR:" "$output" "print_error includes ERROR label"
    assert_contains "Test error message" "$output" "print_error includes message"
    
    # Test error with details
    output=$(print_error "Main error" "Error details" 2>&1)
    assert_contains "Main error" "$output" "print_error with details includes main message"
    assert_contains "Error details" "$output" "print_error with details includes details"
}

# Test print_success function
test_print_success() {
    echo -e "${YELLOW}Testing print_success function...${NC}"
    
    # Test basic success
    local output
    output=$(print_success "Operation successful" 2>&1)
    assert_contains "✅" "$output" "print_success includes icon"
    assert_contains "SUCCESS:" "$output" "print_success includes SUCCESS label"
    assert_contains "Operation successful" "$output" "print_success includes message"
    
    # Test success with details
    output=$(print_success "Main success" "Success details" 2>&1)
    assert_contains "Main success" "$output" "print_success with details includes main message"
    assert_contains "Success details" "$output" "print_success with details includes details"
}

# Test show_progress function
test_show_progress() {
    echo -e "${YELLOW}Testing show_progress function...${NC}"
    
    # Test progress display
    local output
    output=$(show_progress 5 10 "Testing" 20 2>&1)
    assert_contains "⏳" "$output" "show_progress includes icon"
    assert_contains "Testing" "$output" "show_progress includes message"
    assert_contains "50%" "$output" "show_progress includes percentage"
    assert_contains "[" "$output" "show_progress includes progress bar"
    
    # Test completed progress
    output=$(show_progress 10 10 "Complete" 20 2>&1)
    assert_contains "100%" "$output" "show_progress complete shows 100%"
}

# Test visual indicator constants
test_visual_indicators() {
    echo -e "${YELLOW}Testing visual indicator constants...${NC}"
    
    assert_equals "✅" "$SUCCESS_ICON" "SUCCESS_ICON constant"
    assert_equals "❌" "$ERROR_ICON" "ERROR_ICON constant"
    assert_equals "⚠️" "$WARNING_ICON" "WARNING_ICON constant"
    assert_equals "ℹ️" "$INFO_ICON" "INFO_ICON constant"
    assert_equals "⏳" "$PROGRESS_ICON" "PROGRESS_ICON constant"
    assert_equals "➤" "$ARROW_ICON" "ARROW_ICON constant"
}

# Test color constants
test_color_constants() {
    echo -e "${YELLOW}Testing color constants...${NC}"
    
    assert_not_empty "$RED" "RED color constant"
    assert_not_empty "$GREEN" "GREEN color constant"
    assert_not_empty "$YELLOW" "YELLOW color constant"
    assert_not_empty "$BLUE" "BLUE color constant"
    assert_not_empty "$NC" "NC (No Color) constant"
}

# Test utility functions
test_utility_functions() {
    echo -e "${YELLOW}Testing utility functions...${NC}"
    
    # Test print_separator
    local output
    output=$(print_separator 10 "-" 2>&1)
    assert_contains "----------" "$output" "print_separator creates correct separator"
    
    # Test print_key_value
    output=$(print_key_value "Key" "Value" 10 2>&1)
    assert_contains "Key" "$output" "print_key_value includes key"
    assert_contains "Value" "$output" "print_key_value includes value"
    
    # Test print_prompt
    output=$(print_prompt "Enter value" "default" 2>&1)
    assert_contains "Enter value" "$output" "print_prompt includes message"
    assert_contains "default" "$output" "print_prompt includes default"
    assert_contains "➤" "$output" "print_prompt includes arrow"
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}Running wizard-display.sh unit tests...${NC}"
    echo
    
    setup_tests
    
    test_print_header
    echo
    
    test_print_menu_option
    echo
    
    test_print_status_line
    echo
    
    test_print_error
    echo
    
    test_print_success
    echo
    
    test_show_progress
    echo
    
    test_visual_indicators
    echo
    
    test_color_constants
    echo
    
    test_utility_functions
    echo
    
    # Print test summary
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  Total tests: $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! ✅${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed! ❌${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi