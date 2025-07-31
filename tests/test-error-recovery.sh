#!/bin/bash

# Test error recovery scenarios
echo "Testing Error Recovery Scenarios"
echo "================================"

# Source the modules
source lib/wizard-display.sh
source lib/wizard-github.sh  
source lib/wizard-core.sh

# Test recovery functions exist
echo -n "Testing offer_auth_setup function exists... "
if declare -f offer_auth_setup >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing offer_installation_guide function exists... "
if declare -f offer_installation_guide >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing handle_rate_limit_error function exists... "
if declare -f handle_rate_limit_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing handle_permissions_error function exists... "
if declare -f handle_permissions_error >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing offer_config_setup function exists... "
if declare -f offer_config_setup >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing create_basic_config function exists... "
if declare -f create_basic_config >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing get_error_stats function exists... "
if declare -f get_error_stats >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing clear_error_log function exists... "
if declare -f clear_error_log >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test validation functions for different input types
echo -n "Testing validate_menu_option function exists... "
if declare -f validate_menu_option >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing validate_issue_number function exists... "
if declare -f validate_issue_number >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing validate_version_format function exists... "
if declare -f validate_version_format >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing validate_confirmation function exists... "
if declare -f validate_confirmation >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test version validation
echo -n "Testing valid version format (1.2.3)... "
if validate_version_format "1.2.3" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing invalid version format (1.2)... "
if ! validate_version_format "1.2" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test confirmation validation
echo -n "Testing valid confirmation (y)... "
if validate_confirmation "y" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing valid confirmation (yes)... "
if validate_confirmation "yes" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing valid confirmation (n)... "
if validate_confirmation "n" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing invalid confirmation (maybe)... "
if ! validate_confirmation "maybe" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test error statistics and logging
echo -n "Testing error statistics with empty log... "
export ERROR_LOG_FILE="/tmp/test-wizard-errors-stats.log"
rm -f "$ERROR_LOG_FILE"
if get_error_stats >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing error statistics with entries... "
log_error "test1" "First test error" "test_context"
log_error "test2" "Second test error" "test_context"
if get_error_stats | grep -q "Total errors logged: 2"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing clear error log... "
clear_error_log >/dev/null 2>&1
if [ ! -s "$ERROR_LOG_FILE" ]; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

rm -f "$ERROR_LOG_FILE"

echo
echo "================================"
echo "🎉 All error recovery tests passed!"
echo "Error recovery system is working correctly."