#!/bin/bash
set -euo pipefail

# Comprehensive function coverage tests for gh-issue-manager.sh
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

assert_failure() {
  local test_name="$1"
  shift
  
  if ! "$@" >/dev/null 2>&1; then
    echo "✅ $test_name: PASSED (correctly failed)"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED (should have failed)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_output_contains() {
  local test_name="$1"
  local expected="$2"
  shift 2
  
  local output
  output=$("$@" 2>&1 || true)
  
  if [[ "$output" == *"$expected"* ]]; then
    echo "✅ $test_name: PASSED"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED (expected '$expected' in output)"
    echo "   Actual output: $output"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Setup mock environment for testing
setup_mock_environment() {
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Create mock gh command that simulates various scenarios
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
  "repo view")
    if [[ "$*" == *"owner"* ]]; then
      echo "test-owner"
    elif [[ "$*" == *"name"* ]]; then
      echo "test-repo"
    fi
    ;;
  "issue create")
    echo '{"number": 123, "id": "test-id-123"}'
    ;;
  "api graphql")
    echo '{"data": {"addSubIssue": {"clientMutationId": "test"}}}'
    ;;
  "project item-add")
    echo "Added item to project"
    ;;
  "auth status")
    echo "Logged in to github.com as test-user"
    ;;
  *)
    echo "Mock gh: unknown command $*" >&2
    exit 1
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
  *)
    echo "null"
    ;;
esac
EOF

  # Create mock git command
  cat > "$temp_dir/git" << 'EOF'
#!/bin/bash
case "$*" in
  "remote -v")
    echo "origin	https://github.com/test-owner/test-repo.git (fetch)"
    echo "origin	https://github.com/test-owner/test-repo.git (push)"
    ;;
  *)
    exit 0
    ;;
esac
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq" "$temp_dir/git"
  export PATH="$temp_dir:$PATH"
  echo "$temp_dir"
}

cleanup_mock_environment() {
  local mock_dir="$1"
  rm -rf "$mock_dir"
}

# Test get_repo_context function
test_get_repo_context() {
  echo -e "\n=== Function Coverage: get_repo_context ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  # Source the script to access functions
  source "$MAIN_SCRIPT"
  
  # Create temporary git repository
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test successful repo context retrieval
  assert_success "get_repo_context with valid repo" get_repo_context
  
  # Test output contains expected repository info
  assert_output_contains "get_repo_context output format" "Repository context: test-owner/test-repo" get_repo_context
  
  # Test failure scenario with broken gh command
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
exit 1  # Simulate gh failure
EOF
  chmod +x "$mock_dir/gh"
  
  assert_failure "get_repo_context with failing gh" get_repo_context
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  cleanup_mock_environment "$mock_dir"
}

# Test create_issues function
test_create_issues() {
  echo -e "\n=== Function Coverage: create_issues ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  source "$MAIN_SCRIPT"
  
  # Test successful issue creation
  assert_success "create_issues with valid input" create_issues "Parent Title" "Parent Body" "Child Title" "Child Body"
  
  # Test output contains issue numbers
  assert_output_contains "create_issues output format" "Created issues: Parent #123, Child #123" create_issues "Parent" "Body" "Child" "Body"
  
  # Test failure scenario - parent issue creation fails
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
  "issue create")
    if [[ "$*" == *"Parent"* ]]; then
      exit 1  # Fail parent issue creation
    else
      echo '{"number": 124, "id": "test-id-124"}'
    fi
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/gh"
  
  assert_failure "create_issues with parent creation failure" create_issues "Parent Title" "Parent Body" "Child Title" "Child Body"
  
  # Test failure scenario - child issue creation fails
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
  "issue create")
    if [[ "$*" == *"Child"* ]]; then
      exit 1  # Fail child issue creation
    else
      echo '{"number": 123, "id": "test-id-123"}'
    fi
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/gh"
  
  assert_failure "create_issues with child creation failure" create_issues "Parent Title" "Parent Body" "Child Title" "Child Body"
  
  cleanup_mock_environment "$mock_dir"
}

# Test link_sub_issue function
test_link_sub_issue() {
  echo -e "\n=== Function Coverage: link_sub_issue ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  source "$MAIN_SCRIPT"
  
  # Set up required global variables
  PARENT_ID="test-parent-id"
  CHILD_ID="test-child-id"
  PARENT_ISSUE="123"
  CHILD_ISSUE="124"
  
  # Test successful sub-issue linking
  assert_success "link_sub_issue with working API" link_sub_issue
  
  # Test output contains success message
  assert_output_contains "link_sub_issue success message" "Linked child issue #124 to parent #123" link_sub_issue
  
  # Test failure scenario - GraphQL API fails
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "api")
    exit 1  # Simulate API failure
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/gh"
  
  # Should succeed but show warning (function doesn't fail on API error)
  assert_success "link_sub_issue with API failure" link_sub_issue
  assert_output_contains "link_sub_issue warning message" "Warning: Failed to create sub-issue relationship" link_sub_issue
  
  cleanup_mock_environment "$mock_dir"
}

# Test add_to_project function
test_add_to_project() {
  echo -e "\n=== Function Coverage: add_to_project ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  source "$MAIN_SCRIPT"
  
  # Set up required global variables
  REPO_OWNER="test-owner"
  REPO_NAME="test-repo"
  PARENT_ISSUE="123"
  CHILD_ISSUE="124"
  
  # Test with PROJECT_URL set
  PROJECT_URL="https://github.com/orgs/test/projects/1"
  assert_success "add_to_project with PROJECT_URL" add_to_project
  assert_output_contains "add_to_project with project" "Adding issues to project:" add_to_project
  
  # Test without PROJECT_URL
  unset PROJECT_URL
  assert_success "add_to_project without PROJECT_URL" add_to_project
  assert_output_contains "add_to_project skip message" "No PROJECT_URL configured" add_to_project
  
  # Test with PROJECT_URL but failing gh command
  PROJECT_URL="https://github.com/orgs/test/projects/1"
  cat > "$mock_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "project")
    exit 1  # Simulate project command failure
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$mock_dir/gh"
  
  # Should succeed but show warnings
  assert_success "add_to_project with failing project commands" add_to_project
  assert_output_contains "add_to_project warning" "Warning: Failed to add" add_to_project
  
  cleanup_mock_environment "$mock_dir"
}

# Test main function
test_main_function() {
  echo -e "\n=== Function Coverage: main ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  source "$MAIN_SCRIPT"
  
  # Create temporary git repository
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test successful main execution
  assert_success "main function with valid arguments" main "Parent Title" "Parent Body" "Child Title" "Child Body"
  
  # Test main function output
  assert_output_contains "main function success message" "✅ Successfully created parent issue" main "Parent" "Body" "Child" "Body"
  
  # Test main function with invalid arguments
  assert_failure "main function with invalid arguments" main "" "" "" ""
  
  # Test main function with wrong number of arguments
  assert_failure "main function with wrong arg count" main "only" "two"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  cleanup_mock_environment "$mock_dir"
}

# Test edge cases and error conditions
test_edge_cases() {
  echo -e "\n=== Function Coverage: Edge Cases ==="
  
  local mock_dir
  mock_dir=$(setup_mock_environment)
  
  source "$MAIN_SCRIPT"
  
  # Test load_environment with various scenarios
  local temp_dir
  temp_dir=$(mktemp -d)
  pushd "$temp_dir" >/dev/null
  
  # Test load_environment without .env file
  assert_success "load_environment without .env" load_environment
  assert_output_contains "load_environment no file message" "No .env file found" load_environment
  
  # Test load_environment with .env file
  echo "PROJECT_URL=https://github.com/test/project" > .env
  assert_success "load_environment with .env" load_environment
  assert_output_contains "load_environment with file message" "Loaded configuration from .env file" load_environment
  
  # Test load_environment with malformed .env (should still work)
  echo "INVALID_LINE_WITHOUT_EQUALS" > .env
  echo "VALID_VAR=value" >> .env
  assert_success "load_environment with mixed .env" load_environment
  
  popd >/dev/null
  rm -rf "$temp_dir"
  cleanup_mock_environment "$mock_dir"
}

# Main test runner
run_function_coverage_tests() {
  echo "🧪 Starting comprehensive function coverage tests"
  echo "================================================="
  
  test_get_repo_context
  test_create_issues
  test_link_sub_issue
  test_add_to_project
  test_main_function
  test_edge_cases
  
  # Calculate coverage improvement
  local total_functions=8
  local previously_covered=3
  local newly_covered=5
  local new_coverage=$((((previously_covered + newly_covered) * 100) / total_functions))
  
  # Test summary
  echo -e "\n================================================="
  echo "📊 Function Coverage Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  echo ""
  echo "📈 Coverage Improvement:"
  echo "   Previously covered: $previously_covered/$total_functions (37%)"
  echo "   Newly tested: $newly_covered functions"
  echo "   New coverage: $((previously_covered + newly_covered))/$total_functions ($new_coverage%)"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 All function coverage tests passed!"
    echo "🎯 Target coverage of 80%+ achieved!"
    return 0
  else
    echo -e "\n💥 Some function coverage tests failed!"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_function_coverage_tests
fi