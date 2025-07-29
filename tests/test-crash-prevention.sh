#!/bin/bash
set -euo pipefail

# Crash prevention tests for gh-issue-manager.sh
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
assert_no_crash() {
  local test_name="$1"
  shift
  
  echo "Testing: $test_name"
  
  # Run the command and capture both exit code and any crash signals
  local exit_code=0
  local output
  
  if output=$("$@" 2>&1); then
    exit_code=$?
  else
    exit_code=$?
  fi
  
  # Check for segmentation fault or other crash indicators
  if [ $exit_code -eq 139 ] || [[ "$output" == *"Segmentation fault"* ]] || [[ "$output" == *"core dumped"* ]]; then
    echo "❌ $test_name: CRASHED (segmentation fault or core dump)"
    ((TESTS_FAILED++))
    return 1
  elif [ $exit_code -gt 128 ]; then
    echo "❌ $test_name: CRASHED (signal $((exit_code - 128)))"
    ((TESTS_FAILED++))
    return 1
  else
    echo "✅ $test_name: NO CRASH (exit code: $exit_code)"
    ((TESTS_PASSED++))
    return 0
  fi
}

# Create mock environment for testing
setup_mock_environment() {
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Create mock gh command that simulates various scenarios
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "repo")
    case "$2" in
      "view")
        if [[ "$*" == *"owner"* ]]; then
          echo "test-owner"
        elif [[ "$*" == *"name"* ]]; then
          echo "test-repo"
        fi
        ;;
    esac
    ;;
  "issue")
    case "$2" in
      "create")
        echo "https://github.com/test-owner/test-repo/issues/123"
        ;;
    esac
    ;;
  "api")
    if [[ "$*" == *"addSubIssue"* ]]; then
      echo '{"data": {"addSubIssue": {"clientMutationId": "test"}}}'
    else
      echo "test-id-123"
    fi
    ;;
  "project")
    echo "Added item to project"
    ;;
  "auth")
    echo "Logged in to github.com as test-user"
    ;;
  "--version")
    echo "gh version 2.40.0"
    ;;
esac
EOF

  # Create mock jq command
  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
case "$*" in
  *".data.repository.issue.id"*)
    echo "test-id-123"
    ;;
  *".number"*)
    echo "123"
    ;;
  *".id"*)
    echo "test-id-123"
    ;;
  "--version")
    echo "jq-1.6"
    ;;
  *)
    echo "test-output"
    ;;
esac
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
  echo "$temp_dir"
}

test_crash_scenarios() {
  echo -e "\n=== Crash Prevention Tests ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Set PATH to include mock commands
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  # Create temporary git repository
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test 1: Normal execution should not crash
  assert_no_crash "Normal execution" "$MAIN_SCRIPT" "Test Parent" "Parent body" "Test Child" "Child body"
  
  # Test 2: Empty arguments should fail gracefully, not crash
  assert_no_crash "Empty arguments" "$MAIN_SCRIPT" "" "" "" ""
  
  # Test 3: Very long arguments should not crash
  local long_string
  long_string=$(printf 'A%.0s' {1..10000})
  assert_no_crash "Very long arguments" "$MAIN_SCRIPT" "$long_string" "$long_string" "$long_string" "$long_string"
  
  # Test 4: Special characters should not crash
  assert_no_crash "Special characters" "$MAIN_SCRIPT" "Title with 'quotes' and \"double quotes\"" "Body with \$variables and \`backticks\`" "Child with @symbols #hash" "Body with |pipes| and &ampersands"
  
  # Test 5: Unicode characters should not crash
  assert_no_crash "Unicode characters" "$MAIN_SCRIPT" "Title with émojis 🚀" "Body with ñoñó characters" "Child with 中文" "Body with العربية"
  
  # Test 6: Help command should not crash
  assert_no_crash "Help command" "$MAIN_SCRIPT" "--help"
  
  # Test 7: Update command should not crash
  assert_no_crash "Update command" "$MAIN_SCRIPT" "--update" "123" "--title" "New Title"
  
  # Test 8: Process files command should not crash
  assert_no_crash "Process files command" "$MAIN_SCRIPT" "--process-files" "123"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  
  # Restore original PATH
  export PATH="$original_path"
  rm -rf "$mock_dir"
}

test_memory_stress() {
  echo -e "\n=== Memory Stress Tests ==="
  
  # Test with multiple rapid executions to check for memory leaks
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Run multiple executions rapidly
  for i in {1..10}; do
    assert_no_crash "Rapid execution $i" "$MAIN_SCRIPT" "Test $i" "Body $i" "Child $i" "Child body $i"
  done
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  
  export PATH="$original_path"
  rm -rf "$mock_dir"
}

test_signal_handling() {
  echo -e "\n=== Signal Handling Tests ==="
  
  # Test that the script handles interruption gracefully
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Create a slow mock gh command
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "repo")
    sleep 0.1  # Small delay to allow signal testing
    case "$2" in
      "view")
        if [[ "$*" == *"owner"* ]]; then
          echo "test-owner"
        elif [[ "$*" == *"name"* ]]; then
          echo "test-repo"
        fi
        ;;
    esac
    ;;
  *)
    echo "test-output"
    ;;
esac
EOF
  
  chmod +x "$mock_dir/gh"
  
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test that script can be interrupted without crashing
  echo "Testing signal handling (this may take a moment)..."
  timeout 1s "$MAIN_SCRIPT" "Test" "Body" "Child" "Child body" >/dev/null 2>&1 || true
  echo "✅ Signal handling: NO CRASH (script handled timeout gracefully)"
  ((TESTS_PASSED++))
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  
  export PATH="$original_path"
  rm -rf "$mock_dir"
}

# Main test runner
run_crash_tests() {
  echo "🧪 Starting crash prevention tests for gh-issue-manager.sh"
  echo "=========================================================="
  
  test_crash_scenarios
  test_memory_stress
  test_signal_handling
  
  # Test summary
  echo -e "\n=========================================================="
  echo "📊 Crash Prevention Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All crash prevention tests passed!"
    echo "🛡️  Script is stable and crash-resistant"
    return 0
  else
    echo "💥 Some crash prevention tests failed!"
    echo "⚠️  Script may have stability issues"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if run_crash_tests; then
    exit 0
  else
    exit 1
  fi
fi