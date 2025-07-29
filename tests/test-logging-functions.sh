#!/bin/bash
set -euo pipefail

# Tests for logging functions in gh-issue-manager.sh
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
assert_success() {
  local test_name="$1"
  shift
  
  if "$@" >/dev/null 2>&1; then
    echo "✅ $test_name: PASSED"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_file_contains() {
  local test_name="$1"
  local file="$2"
  local expected="$3"
  
  if [ -f "$file" ] && grep -q "$expected" "$file"; then
    echo "✅ $test_name: PASSED"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED"
    ((TESTS_FAILED++))
    return 1
  fi
}

test_logging_functions() {
  echo -e "\n=== Logging Functions Tests ==="
  
  # Source the script to access functions
  source "$MAIN_SCRIPT"
  
  # Create temporary directory for log testing
  local temp_dir
  temp_dir=$(mktemp -d)
  local test_log="$temp_dir/test.log"
  
  # Set up logging environment
  export ENABLE_LOGGING=true
  export LOG_LEVEL=DEBUG
  export LOG_FILE="$test_log"
  
  # Initialize logging
  assert_success "log_init function" log_init
  
  # Test log_message function
  assert_success "log_message function" log_message "INFO" "test_function" "Test message"
  assert_file_contains "log_message writes to file" "$test_log" "Test message"
  
  # Test log_error function
  assert_success "log_error function" log_error "test_function" "Error message"
  assert_file_contains "log_error writes to file" "$test_log" "Error message"
  
  # Test log_debug function
  assert_success "log_debug function" log_debug "test_function" "Debug message"
  assert_file_contains "log_debug writes to file" "$test_log" "Debug message"
  
  # Test log_timing function
  local start_time
  start_time=$(date +%s.%N)
  sleep 0.1  # Small delay to ensure measurable time
  assert_success "log_timing function" log_timing "test_function" "$start_time"
  assert_file_contains "log_timing writes to file" "$test_log" "Execution time:"
  
  # Test different log levels
  export LOG_LEVEL=ERROR
  log_init
  
  # Clear log file
  > "$test_log"
  
  # These should not appear in log with ERROR level
  log_debug "test_function" "Debug message - should not appear"
  log_info "test_function" "Info message - should not appear"
  
  # This should appear
  log_error "test_function" "Error message - should appear"
  
  if [ -s "$test_log" ] && grep -q "Error message - should appear" "$test_log" && ! grep -q "Debug message - should not appear" "$test_log"; then
    echo "✅ Log level filtering: PASSED"
    ((TESTS_PASSED++))
  else
    echo "❌ Log level filtering: FAILED"
    ((TESTS_FAILED++))
  fi
  
  # Clean up
  rm -rf "$temp_dir"
  
  # Reset logging environment
  export ENABLE_LOGGING=false
  unset LOG_FILE
}

test_show_usage_function() {
  echo -e "\n=== show_usage Function Tests ==="
  
  source "$MAIN_SCRIPT"
  
  # Test that show_usage produces output
  local usage_output
  usage_output=$(show_usage 2>&1)
  
  if [[ "$usage_output" == *"Usage:"* ]]; then
    echo "✅ show_usage produces usage text: PASSED"
    ((TESTS_PASSED++))
  else
    echo "❌ show_usage produces usage text: FAILED"
    ((TESTS_FAILED++))
  fi
  
  if [[ "$usage_output" == *"Options:"* ]]; then
    echo "✅ show_usage includes options: PASSED"
    ((TESTS_PASSED++))
  else
    echo "❌ show_usage includes options: FAILED"
    ((TESTS_FAILED++))
  fi
  
  if [[ "$usage_output" == *"Examples:"* ]]; then
    echo "✅ show_usage includes examples: PASSED"
    ((TESTS_PASSED++))
  else
    echo "❌ show_usage includes examples: FAILED"
    ((TESTS_FAILED++))
  fi
}

test_update_issue_function() {
  echo -e "\n=== update_issue Function Tests ==="
  
  source "$MAIN_SCRIPT"
  
  # Create mock gh command for testing
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "issue")
    case "$2" in
      "edit")
        echo "Issue updated successfully"
        exit 0
        ;;
    esac
    ;;
esac
exit 1
EOF
  
  chmod +x "$temp_dir/gh"
  
  local original_path="$PATH"
  export PATH="$temp_dir:$PATH"
  
  # Test update_issue with mocked gh
  assert_success "update_issue with title" update_issue "123" --title "New Title"
  assert_success "update_issue with body" update_issue "123" --body "New Body"
  assert_success "update_issue with state" update_issue "123" --state "closed"
  assert_success "update_issue with label" update_issue "123" --add-label "bug"
  
  # Test update_issue with no arguments (should succeed but do nothing)
  assert_success "update_issue with no update args" update_issue "123"
  
  export PATH="$original_path"
  rm -rf "$temp_dir"
}

test_process_files_function() {
  echo -e "\n=== process_files_to_create_in_issue Function Tests ==="
  
  source "$MAIN_SCRIPT"
  
  # Create mock gh command for testing
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "issue")
    case "$2" in
      "view")
        echo '{"body": "Files to Create:\n- test.txt\n- another.txt"}'
        ;;
      "edit")
        echo "Issue updated successfully"
        ;;
    esac
    ;;
esac
EOF
  
  chmod +x "$temp_dir/gh"
  
  local original_path="$PATH"
  export PATH="$temp_dir:$PATH"
  
  # Test process_files_to_create_in_issue
  assert_success "process_files_to_create_in_issue function" process_files_to_create_in_issue "123"
  
  export PATH="$original_path"
  rm -rf "$temp_dir"
}

# Main test runner
run_logging_tests() {
  echo "🧪 Starting logging and utility function tests"
  echo "=============================================="
  
  test_logging_functions
  test_show_usage_function
  test_update_issue_function
  test_process_files_function
  
  # Test summary
  echo -e "\n=============================================="
  echo "📊 Logging Function Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All logging function tests passed!"
    return 0
  else
    echo "💥 Some logging function tests failed!"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if run_logging_tests; then
    exit 0
  else
    exit 1
  fi
fi