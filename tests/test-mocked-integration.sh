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
# Mock jq to handle various queries
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
  
  # Verify the commands are executable
  if [ ! -x "$temp_dir/gh" ] || [ ! -x "$temp_dir/jq" ]; then
    echo "Error: Failed to create executable mock commands"
    return 1
  fi
  
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
  
  # Set PATH to include mock commands
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  # Verify mock commands are available
  if ! command -v gh >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "❌ Mock commands not available in PATH"
    export PATH="$original_path"
    cleanup_mock_environment "$mock_dir"
    ((TESTS_FAILED++))
    return 1
  fi
  
  # Create temporary git repository
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test full workflow with mocked commands
  echo "Testing full workflow with mocked commands..."
  if "$MAIN_SCRIPT" "Test Parent" "Parent body" "Test Child" "Child body" >/dev/null 2>&1; then
    echo "✅ Mocked full workflow: PASSED"
    ((TESTS_PASSED++))
  else
    echo "❌ Mocked full workflow: FAILED"
    echo "Debug: PATH=$PATH"
    echo "Debug: gh location: $(which gh 2>/dev/null || echo 'not found')"
    echo "Debug: jq location: $(which jq 2>/dev/null || echo 'not found')"
    ((TESTS_FAILED++))
  fi
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  
  # Restore original PATH
  export PATH="$original_path"
  cleanup_mock_environment "$mock_dir"
}

test_error_conditions_mocked() {
  echo -e "\n=== Mocked Error Condition Tests ==="
  
  local mock_dir
  mock_dir=$(mktemp -d)
  
  # Create failing gh command
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "repo")
    exit 1  # Simulate repository access failure
    ;;
  "--version")
    echo "gh version 2.40.0"
    ;;
  *)
    exit 1
    ;;
esac
EOF
  
  # Create working jq command for dependency check
  cat > "$mock_dir/jq" << 'EOF'
#!/bin/bash
case "$*" in
  "--version")
    echo "jq-1.6"
    ;;
  *)
    echo "test-output"
    ;;
esac
EOF
  
  chmod +x "$mock_dir/gh" "$mock_dir/jq"
  
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
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
  
  export PATH="$original_path"
  rm -rf "$mock_dir"
}

test_individual_functions_mocked() {
  echo -e "\n=== Individual Function Tests (Mocked) ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  local original_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
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
  PARENT_ISSUE="123"
  CHILD_ISSUE="124"
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
  
  export PATH="$original_path"
  cleanup_mock_environment "$mock_dir"
}

# Main test runner
run_mocked_tests() {
  echo "🧪 Starting mocked integration tests for gh-issue-manager.sh"
  echo "============================================================"
  
  test_mocked_full_workflow
  echo "Completed test_mocked_full_workflow"
  test_error_conditions_mocked
  echo "Completed test_error_conditions_mocked"
  test_individual_functions_mocked
  echo "Completed test_individual_functions_mocked"
  
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
  if run_mocked_tests; then
    exit 0
  else
    exit 1
  fi
fi
fi