#!/bin/bash

# Simple test for error handling functions
echo "Testing Error Handling Functions"
echo "=================================="

# Source the modules
source lib/wizard-display.sh
source lib/wizard-github.sh  
source lib/wizard-core.sh

# Test 1: Check if main error handling function exists
echo -n "Testing handle_error function exists... "
if declare -f handle_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 2: Check if input validation function exists
echo -n "Testing validate_input_with_guidance function exists... "
if declare -f validate_input_with_guidance >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 3: Check if retry function exists
echo -n "Testing offer_retry_operation function exists... "
if declare -f offer_retry_operation >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 4: Check if auth error handler exists
echo -n "Testing handle_auth_error function exists... "
if declare -f handle_auth_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 5: Check if network error handler exists
echo -n "Testing handle_network_error function exists... "
if declare -f handle_network_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 6: Check if input error handler exists
echo -n "Testing handle_input_error function exists... "
if declare -f handle_input_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 7: Check if dependency error handler exists
echo -n "Testing handle_dependency_error function exists... "
if declare -f handle_dependency_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 8: Check if GitHub error handler exists
echo -n "Testing handle_github_error function exists... "
if declare -f handle_github_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 9: Check if config error handler exists
echo -n "Testing handle_config_error function exists... "
if declare -f handle_config_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 10: Check if error logging function exists
echo -n "Testing log_error function exists... "
if declare -f log_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 11: Test input validation with valid menu option
echo -n "Testing input validation with valid menu option... "
if validate_input_with_guidance "3" "menu_option" "1-5" "test_menu" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 12: Test input validation with invalid menu option
echo -n "Testing input validation with invalid menu option... "
if ! validate_input_with_guidance "10" "menu_option" "1-5" "test_menu" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 13: Test issue number validation
echo -n "Testing issue number validation... "
if validate_input_with_guidance "123" "issue_number" "" "" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 14: Test invalid issue number validation
echo -n "Testing invalid issue number validation... "
if ! validate_input_with_guidance "0" "issue_number" "" "" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 15: Test error logging
echo -n "Testing error logging... "
export ERROR_LOG_FILE="/tmp/test-wizard-errors.log"
rm -f "$ERROR_LOG_FILE"
log_error "test" "Test error message" "test_context"
if [ -f "$ERROR_LOG_FILE" ] && grep -q "Test error message" "$ERROR_LOG_FILE"; then
    echo "✅ PASS"
    rm -f "$ERROR_LOG_FILE"
else
    echo "❌ FAIL"
    exit 1
fi

echo
echo "=================================="
echo "🎉 All error handling tests passed!"
echo "Error handling system is working correctly."