#!/bin/bash
set -euo pipefail

# Windows-compatible test suite for gh-issue-manager.sh
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
test_pass() {
  local test_name="$1"
  echo "✅ $test_name: PASSED"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
  local test_name="$1"
  echo "❌ $test_name: FAILED"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Test that the script exists and is readable
test_script_exists() {
  echo "=== Basic Script Tests ==="
  
  if [ -f "$MAIN_SCRIPT" ]; then
    test_pass "Script file exists"
  else
    test_fail "Script file exists"
    return 1
  fi
  
  if [ -r "$MAIN_SCRIPT" ]; then
    test_pass "Script file is readable"
  else
    test_fail "Script file is readable"
  fi
}

# Test script syntax
test_script_syntax() {
  echo -e "\n=== Syntax Tests ==="
  
  if bash -n "$MAIN_SCRIPT" 2>/dev/null; then
    test_pass "Script syntax is valid"
  else
    test_fail "Script syntax is valid"
  fi
}

# Test help functionality
test_help_command() {
  echo -e "\n=== Help Command Tests ==="
  
  if bash "$MAIN_SCRIPT" --help >/dev/null 2>&1; then
    test_pass "Help command works"
  else
    test_fail "Help command works"
  fi
  
  # Test that help output contains expected content
  local help_output
  help_output=$(bash "$MAIN_SCRIPT" --help 2>&1 || true)
  
  if [[ "$help_output" == *"Usage:"* ]]; then
    test_pass "Help output contains usage information"
  else
    test_fail "Help output contains usage information"
  fi
  
  if [[ "$help_output" == *"PARENT_TITLE"* ]]; then
    test_pass "Help output contains parameter information"
  else
    test_fail "Help output contains parameter information"
  fi
}

# Test argument validation without external dependencies
test_argument_validation() {
  echo -e "\n=== Argument Validation Tests ==="
  
  # Test with no arguments (should show usage and fail)
  if ! bash "$MAIN_SCRIPT" >/dev/null 2>&1; then
    test_pass "Script fails with no arguments"
  else
    test_fail "Script fails with no arguments"
  fi
  
  # Test with insufficient arguments (should fail)
  if ! bash "$MAIN_SCRIPT" "title1" "body1" >/dev/null 2>&1; then
    test_pass "Script fails with insufficient arguments"
  else
    test_fail "Script fails with insufficient arguments"
  fi
  
  # Test with empty arguments (should fail)
  if ! bash "$MAIN_SCRIPT" "" "" "" "" >/dev/null 2>&1; then
    test_pass "Script fails with empty arguments"
  else
    test_fail "Script fails with empty arguments"
  fi
}

# Test function sourcing
test_function_sourcing() {
  echo -e "\n=== Function Sourcing Tests ==="
  
  # Create a test script that sources the main script
  local test_script
  test_script=$(mktemp)
  
  cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Initialize logging to prevent errors
ENABLE_LOGGING=false
LOG_LEVEL=INFO
LOG_FILE=/tmp/test.log

# Source the main script
source "$1"

# Test that key functions exist
if declare -f validate_input >/dev/null 2>&1; then
  echo "validate_input function exists"
fi

if declare -f check_dependencies >/dev/null 2>&1; then
  echo "check_dependencies function exists"
fi

if declare -f load_environment >/dev/null 2>&1; then
  echo "load_environment function exists"
fi
EOF
  
  chmod +x "$test_script"
  
  local output
  output=$("$test_script" "$MAIN_SCRIPT" 2>&1 || true)
  
  if [[ "$output" == *"validate_input function exists"* ]]; then
    test_pass "validate_input function can be sourced"
  else
    test_fail "validate_input function can be sourced"
  fi
  
  if [[ "$output" == *"check_dependencies function exists"* ]]; then
    test_pass "check_dependencies function can be sourced"
  else
    test_fail "check_dependencies function can be sourced"
  fi
  
  if [[ "$output" == *"load_environment function exists"* ]]; then
    test_pass "load_environment function can be sourced"
  else
    test_fail "load_environment function can be sourced"
  fi
  
  rm -f "$test_script"
}

# Test logging system initialization
test_logging_system() {
  echo -e "\n=== Logging System Tests ==="
  
  # Create a test script that tests logging
  local test_script
  test_script=$(mktemp)
  
  cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Source the main script
source "$1"

# Test logging initialization
ENABLE_LOGGING=true
LOG_LEVEL=DEBUG
LOG_FILE=/tmp/test_logging.log

log_init

# Test logging functions
log_info "test" "Test message"

if [ -f "$LOG_FILE" ]; then
  echo "Log file created successfully"
  if grep -q "Test message" "$LOG_FILE"; then
    echo "Log message written successfully"
  fi
  rm -f "$LOG_FILE"
fi
EOF
  
  chmod +x "$test_script"
  
  local output
  output=$("$test_script" "$MAIN_SCRIPT" 2>&1 || true)
  
  if [[ "$output" == *"Log file created successfully"* ]]; then
    test_pass "Logging system creates log file"
  else
    test_fail "Logging system creates log file"
  fi
  
  if [[ "$output" == *"Log message written successfully"* ]]; then
    test_pass "Logging system writes messages"
  else
    test_fail "Logging system writes messages"
  fi
  
  rm -f "$test_script"
}

# Test environment loading
test_environment_loading() {
  echo -e "\n=== Environment Loading Tests ==="
  
  # Create a temporary directory with .env file
  local temp_dir
  temp_dir=$(mktemp -d)
  pushd "$temp_dir" >/dev/null
  
  # Create .env file
  echo "PROJECT_URL=https://github.com/test/project" > .env
  echo "ENABLE_LOGGING=true" >> .env
  
  # Create test script
  local test_script
  test_script=$(mktemp)
  
  cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Initialize logging variables to prevent errors
ENABLE_LOGGING=false
LOG_LEVEL=INFO
LOG_FILE=/tmp/test.log

# Source the main script
source "$1"

# Test environment loading
load_environment

# Check if variables were loaded
if [ "${PROJECT_URL:-}" = "https://github.com/test/project" ]; then
  echo "PROJECT_URL loaded correctly"
fi

if [ "${ENABLE_LOGGING:-}" = "true" ]; then
  echo "ENABLE_LOGGING loaded correctly"
fi
EOF
  
  chmod +x "$test_script"
  
  local output
  output=$("$test_script" "$MAIN_SCRIPT" 2>&1 || true)
  
  if [[ "$output" == *"PROJECT_URL loaded correctly"* ]]; then
    test_pass "Environment loading works for PROJECT_URL"
  else
    test_fail "Environment loading works for PROJECT_URL"
  fi
  
  if [[ "$output" == *"ENABLE_LOGGING loaded correctly"* ]]; then
    test_pass "Environment loading works for ENABLE_LOGGING"
  else
    test_fail "Environment loading works for ENABLE_LOGGING"
  fi
  
  popd >/dev/null
  rm -rf "$temp_dir"
  rm -f "$test_script"
}

# Main test runner
run_windows_compatible_tests() {
  echo "🧪 Windows-Compatible Test Suite for gh-issue-manager.sh"
  echo "========================================================"
  
  test_script_exists
  test_script_syntax
  test_help_command
  test_argument_validation
  test_function_sourcing
  test_logging_system
  test_environment_loading
  
  # Final summary
  echo -e "\n========================================================"
  echo "📊 Test Results Summary:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 All Windows-compatible tests passed!"
    echo "✅ Core functionality verified without external dependencies"
    return 0
  else
    echo -e "\n💥 Some tests failed!"
    echo "❌ Core functionality issues detected"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_windows_compatible_tests
fi