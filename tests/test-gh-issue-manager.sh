#!/bin/bash
set -euo pipefail
IFS=

# --- MCP Test Validation Header ---
# [MCP:REQUIRED] Test isolation
# [MCP:REQUIRED] Cleanup guarantees
# [MCP:RECOMMENDED] Failure scenarios

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"
readonly TEST_PREFIX="test-subissues"

# Global test state
TEST_REPO=""
TEST_DIR=""
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
  if [ -n "${TEST_REPO:-}" ]; then
    echo "🧹 Cleaning up test repository: $TEST_REPO"
    gh repo delete "$TEST_REPO" --confirm 2>/dev/null || true
  fi
  
  if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
    echo "🧹 Cleaning up test directory: $TEST_DIR"
    rm -rf "$TEST_DIR" || true
  fi
}

trap cleanup EXIT ERR

# Test utilities
assert_success() {
  local test_name="$1"
  shift
  
  if "$@"; then
    echo "✅ $test_name: PASSED"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_failure() {
  local test_name="$1"
  shift
  
  if ! "$@"; then
    echo "✅ $test_name: PASSED (correctly failed)"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED (should have failed)"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Unit tests (can run without GitHub API)
test_validate_input() {
  echo -e "\n=== Unit Tests: Input Validation ==="
  
  # Source the script to access functions
  source "$MAIN_SCRIPT"
  
  # Test valid input
  assert_success "Valid 4 arguments" validate_input "title1" "body1" "title2" "body2"
  
  # Test invalid argument count
  assert_failure "Too few arguments" validate_input "title1" "body1" "title2"
  assert_failure "Too many arguments" validate_input "title1" "body1" "title2" "body2" "extra"
  assert_failure "No arguments" validate_input
  
  # Test empty arguments
  assert_failure "Empty first argument" validate_input "" "body1" "title2" "body2"
  assert_failure "Empty second argument" validate_input "title1" "" "title2" "body2"
  assert_failure "Empty third argument" validate_input "title1" "body1" "" "body2"
  assert_failure "Empty fourth argument" validate_input "title1" "body1" "title2" ""
  assert_failure "All empty arguments" validate_input "" "" "" ""
}

test_check_dependencies() {
  echo -e "\n=== Unit Tests: Dependency Checking ==="
  
  source "$MAIN_SCRIPT"
  
  # This should pass if gh and jq are available
  assert_success "Dependencies available" check_dependencies
}

test_load_environment() {
  echo -e "\n=== Unit Tests: Environment Loading ==="
  
  source "$MAIN_SCRIPT"
  
  # Test without .env file
  local temp_dir
  temp_dir=$(mktemp -d)
  pushd "$temp_dir" >/dev/null
  
  assert_success "Load environment without .env" load_environment
  
  # Test with .env file
  echo "PROJECT_URL=https://github.com/orgs/test/projects/1" > .env
  assert_success "Load environment with .env" load_environment
  
  popd >/dev/null
  rm -rf "$temp_dir"
}

# Integration tests (require GitHub API)
setup_integration_test() {
  echo "🔧 Setting up integration test environment..."
  
  # Verify prerequisites
  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI not available, skipping integration tests"
    return 1
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq not available, skipping integration tests"
    return 1
  fi
  
  # Check GitHub authentication
  if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated, skipping integration tests"
    return 1
  fi
  
  # Create test environment
  TEST_DIR=$(mktemp -d)
  pushd "$TEST_DIR" >/dev/null
  
  TEST_REPO="$TEST_PREFIX-$(date +%s)-$$"
  
  if ! gh repo create "$TEST_REPO" --public --confirm >/dev/null 2>&1; then
    echo "❌ Failed to create test repository, skipping integration tests"
    popd >/dev/null
    return 1
  fi
  
  if ! gh repo clone "$TEST_REPO" >/dev/null 2>&1; then
    echo "❌ Failed to clone test repository"
    return 1
  fi
  
  cd "$TEST_REPO"
  git commit --allow-empty -m "Initial commit" >/dev/null 2>&1
  
  echo "✅ Integration test environment ready: $TEST_REPO"
  return 0
}

test_integration_valid_execution() {
  echo -e "\n=== Integration Test: Valid Execution ==="
  
  if ! setup_integration_test; then
    echo "⚠️  Skipping integration tests due to setup failure"
    return 0
  fi
  
  local parent_title="Test Parent Issue $(date +%s)"
  local parent_body="Parent issue for testing"
  local child_title="Test Child Issue $(date +%s)"
  local child_body="Child issue for testing"
  
  # Test script execution
  chmod +x "$MAIN_SCRIPT"
  if "$MAIN_SCRIPT" "$parent_title" "$parent_body" "$child_title" "$child_body"; then
    echo "✅ Script execution: PASSED"
    ((TESTS_PASSED++))
    
    # Verify issues were created
    sleep 2  # Allow time for GitHub API
    local parent_issue
    local child_issue
    
    parent_issue=$(gh issue list --search "$parent_title" --json number -q '.[0].number' 2>/dev/null || echo "")
    child_issue=$(gh issue list --search "$child_title" --json number -q '.[0].number' 2>/dev/null || echo "")
    
    if [ -n "$parent_issue" ] && [ -n "$child_issue" ]; then
      echo "✅ Issue creation verification: PASSED"
      ((TESTS_PASSED++))
    else
      echo "❌ Issue creation verification: FAILED"
      ((TESTS_FAILED++))
    fi
  else
    echo "❌ Script execution: FAILED"
    ((TESTS_FAILED++))
  fi
  
  popd >/dev/null
}

test_integration_error_conditions() {
  echo -e "\n=== Integration Test: Error Conditions ==="
  
  if ! setup_integration_test; then
    echo "⚠️  Skipping integration tests due to setup failure"
    return 0
  fi
  
  chmod +x "$MAIN_SCRIPT"
  
  # Test invalid arguments
  assert_failure "Empty arguments" "$MAIN_SCRIPT" "" "" "" ""
  assert_failure "Missing arguments" "$MAIN_SCRIPT" "title1" "body1"
  assert_failure "Too many arguments" "$MAIN_SCRIPT" "t1" "b1" "t2" "b2" "extra"
  
  popd >/dev/null
}

# Main test runner
run_all_tests() {
  echo "🧪 Starting comprehensive test suite for gh-issue-manager.sh"
  echo "=================================================="
  
  # Unit tests (always run)
  test_validate_input
  test_check_dependencies
  test_load_environment
  
  # Integration tests (conditional)
  test_integration_valid_execution
  test_integration_error_conditions
  
  # Test summary
  echo -e "\n=================================================="
  echo "📊 Test Results Summary:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
  else
    echo "💥 Some tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_all_tests
fi