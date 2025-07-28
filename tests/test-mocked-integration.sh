#!/bin/bash
set -euo pipefail

# Mocked integration tests that don't require GitHub API
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Create mock environment
setup_mock_environment() {
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Create mock gh command
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
        echo '{"number": 123, "id": "test-id-123"}'
        ;;
    esac
    ;;
  "api")
    echo '{"data": {"addSubIssue": {"clientMutationId": "test"}}}'
    ;;
  "project")
    echo "Added item to project"
    ;;
  "auth")
    echo "Logged in to github.com as test-user"
    ;;
esac
EOF

  # Create mock jq command
  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
case "$*" in
  *".number"*)
    echo "123"
    ;;
  *".id"*)
    echo "test-id-123"
    ;;
esac
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
  export PATH="$temp_dir:$PATH"
  echo "$temp_dir"
}

cleanup_mock_environment() {
  local mock_dir="$1"
  rm -rf "$mock_dir"
}

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

test_mocked_full_workflow() {
  echo -e "\n=== Mocked Integration Tests ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Create temporary git repository
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test full workflow with mocked commands
  assert_success "Mocked full workflow" "$MAIN_SCRIPT" "Test Parent" "Parent body" "Test Child" "Child body"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  cleanup_mock_environment "$mock_dir"
}

test_error_conditions_mocked() {
  echo -e "\n=== Mocked Error Condition Tests ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Create failing gh command
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "repo")
    exit 1  # Simulate repository access failure
    ;;
  *)
    exit 1
    ;;
esac
EOF
  
  chmod +x "$mock_dir/gh"
  
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  # Test should fail gracefully
  if ! "$MAIN_SCRIPT" "Test Parent" "Parent body" "Test Child" "Child body" >/dev/null 2>&1; then
    echo "✅ Error handling: PASSED (correctly failed)"
    ((TESTS_PASSED++))
  else
    echo "❌ Error handling: FAILED (should have failed)"
    ((TESTS_FAILED++))
  fi
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  cleanup_mock_environment "$mock_dir"
}

test_individual_functions_mocked() {
  echo -e "\n=== Individual Function Tests (Mocked) ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Source the script to test individual functions
  source "$MAIN_SCRIPT"
  
  # Test get_repo_context
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  assert_success "get_repo_context with mocked gh" get_repo_context
  
  # Test create_issues
  assert_success "create_issues with mocked gh" create_issues "Parent Title" "Parent Body" "Child Title" "Child Body"
  
  # Test link_sub_issue (should work with mocked API)
  PARENT_ID="test-parent-id"
  CHILD_ID="test-child-id"
  assert_success "link_sub_issue with mocked API" link_sub_issue
  
  # Test add_to_project
  PROJECT_URL="https://github.com/orgs/test/projects/1"
  REPO_OWNER="test-owner"
  REPO_NAME="test-repo"
  PARENT_ISSUE="123"
  CHILD_ISSUE="124"
  assert_success "add_to_project with mocked gh" add_to_project
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  cleanup_mock_environment "$mock_dir"
}

# Main test runner
run_mocked_tests() {
  echo "🧪 Starting mocked integration tests for gh-issue-manager.sh"
  echo "============================================================"
  
  test_mocked_full_workflow
  test_error_conditions_mocked
  test_individual_functions_mocked
  
  # Test summary
  echo -e "\n=================================================="
  echo "📊 Mocked Integration Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All mocked integration tests passed!"
    return 0
  else
    echo "💥 Some mocked integration tests failed!"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_mocked_tests
fi