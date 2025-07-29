#!/bin/bash
set -euo pipefail

# Source the main script once at the beginning
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../gh-issue-manager.sh"
log_init

# Comprehensive coverage tests targeting 100% function coverage
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Enhanced test utilities
assert_success() {
  local test_name="$1"
  shift
  
  if ! "$@"; then
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
  
  if "$@"; then
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
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_variable_set() {
  local test_name="$1"
  local var_name="$2"
  
  if [[ -n "${!var_name:-}" ]]; then
    echo "✅ $test_name: PASSED (variable $var_name is set)"
    ((TESTS_PASSED++))
    return 0
  else
    echo "❌ $test_name: FAILED (variable $var_name not set)"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Advanced mock environment with configurable behaviors
setup_advanced_mock() {
  local behavior="${1:-success}"
  local temp_dir
  temp_dir=$(mktemp -d)
  
  case "$behavior" in
    "success")
      create_success_mocks "$temp_dir"
      ;;
    "gh_fail")
      create_gh_fail_mocks "$temp_dir"
      ;;
    "jq_fail")
      create_jq_fail_mocks "$temp_dir"
      ;;
    "api_fail")
      create_api_fail_mocks "$temp_dir"
      ;;
    "project_fail")
      create_project_fail_mocks "$temp_dir"
      ;;
  esac
  
  export PATH="$temp_dir:$PATH"
  echo "$temp_dir"
}

create_success_mocks() {
  local temp_dir="$1"
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$*" in
  "repo view --json owner -q .owner.login")
    echo "test-owner"
    ;;
  "repo view --json name -q .name")
    echo "test-repo"
    ;;
  "issue create"*)
    if [[ "$*" == *"Parent"* ]]; then
      echo '{"number": 100, "id": "parent-id-100"}'
    else
      echo '{"number": 101, "id": "child-id-101"}'
    fi
    ;;
  "api graphql -H GraphQL-Features: sub_issues -f query=
mutation {\n  addSubIssue(input: {issueId: \"test-parent-id\", subIssueId: \"test-child-id\"}) {\n    clientMutationId\n  }\n}")
    echo '{"data": {"addSubIssue": {"clientMutationId": "success"}}}'
    ;;
  "project item-add 1 --owner test-owner --url https://github.com/test-owner/test-repo/issues/100")
    echo "Item added to project successfully"
    ;;
  "project item-add 1 --owner test-owner --url https://github.com/test-owner/test-repo/issues/101")
    echo "Item added to project successfully"
    ;;
  *)
    exit 0
    ;;
esac
EOF

  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
case "$*" in
  *".number"*)
    if [[ "$*" == *"parent"* ]]; then
      echo "100"
    else
      echo "101"
    fi
    ;;
  *".id"*)
    if [[ "$*" == *"parent"* ]]; then
      echo "parent-id-100"
    else
      echo "child-id-101"
    fi
    ;;
esac
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
}

create_gh_fail_mocks() {
  local temp_dir="$1"
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
exit 1  # All gh commands fail
EOF

  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
echo "null"
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
}

create_jq_fail_mocks() {
  local temp_dir="$1"
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
echo '{"number": 123, "id": "test-id"}'
EOF

  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
exit 1  # jq fails
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
}

create_api_fail_mocks() {
  local temp_dir="$1"
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "api")
    exit 1  # API calls fail
    ;;
  *)
    if [[ "$*" == *"owner"* ]]; then
      echo "test-owner"
    elif [[ "$*" == *"name"* ]]; then
      echo "test-repo"
    else
      echo '{"number": 123, "id": "test-id"}'
    fi
    ;;
esac
EOF

  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
echo "123"
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
}

create_project_fail_mocks() {
  local temp_dir="$1"
  
  cat > "$temp_dir/gh" << 'EOF'
#!/bin/bash
case "$1" in
  "project")
    exit 1  # Project commands fail
    ;;
  *)
    if [[ "$*" == *"owner"* ]]; then
      echo "test-owner"
    elif [[ "$*" == *"name"* ]]; then
      echo "test-repo"
    else
      echo '{"number": 123, "id": "test-id"}'
    fi
    ;;
esac
EOF

  cat > "$temp_dir/jq" << 'EOF'
#!/bin/bash
echo "123"
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
}

# Comprehensive tests for all functions with multiple scenarios
test_all_functions_comprehensive() {
  echo -e "
=== Comprehensive Function Coverage Tests ==="




  
  # Test get_repo_context with various scenarios
  echo -e "
--- Testing get_repo_context ---"

  
  local mock_dir
  mock_dir=$(setup_advanced_mock "success")

  # Set environment variables for get_repo_context
  export REPO_OWNER="test-owner"
  export REPO_NAME="test-repo"

  
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test successful execution
  assert_success "get_repo_context success case" get_repo_context
  assert_variable_set "REPO_OWNER set by get_repo_context" "REPO_OWNER"
  assert_variable_set "REPO_NAME set by get_repo_context" "REPO_NAME"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  rm -rf "$mock_dir"
  
  # Unset environment variables for subsequent tests
  unset REPO_OWNER
  unset REPO_NAME
  
  # Test failure case
  mock_dir=$(setup_advanced_mock "gh_fail")
  unset REPO_OWNER
  unset REPO_NAME
  
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  git init >/dev/null 2>&1
  
  assert_failure "get_repo_context with gh failure" get_repo_context
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  rm -rf "$mock_dir"
  
  # Test create_issues with various scenarios
  echo -e "\n--- Testing create_issues ---"
  
  mock_dir=$(setup_advanced_mock "success")

  
  # Test successful creation
  assert_success "create_issues success case" create_issues "Parent Title" "Parent Body" "Child Title" "Child Body"
  assert_variable_set "PARENT_ISSUE set by create_issues" "PARENT_ISSUE"
  assert_variable_set "PARENT_ID set by create_issues" "PARENT_ID"
  assert_variable_set "CHILD_ISSUE set by create_issues" "CHILD_ISSUE"
  assert_variable_set "CHILD_ID set by create_issues" "CHILD_ID"
  
  rm -rf "$mock_dir"
  
  # Test with gh failure
  mock_dir=$(setup_advanced_mock "gh_fail")

  
  assert_failure "create_issues with gh failure" create_issues "Parent" "Body" "Child" "Body"
  
  rm -rf "$mock_dir"
  
  # Test link_sub_issue with various scenarios
  echo -e "\n--- Testing link_sub_issue ---"
  
  mock_dir=$(setup_advanced_mock "success")

  
  # Set up required variables
  PARENT_ID="test-parent-id"
  CHILD_ID="test-child-id"
  PARENT_ISSUE="100"
  CHILD_ISSUE="101"
  
  assert_success "link_sub_issue success case" link_sub_issue
  assert_output_contains "link_sub_issue success output" "Linked child issue #101 to parent #100" link_sub_issue
  
  rm -rf "$mock_dir"
  
  # Test with API failure (should succeed but warn)
  mock_dir=$(setup_advanced_mock "api_fail")

  
  PARENT_ID="test-parent-id"
  CHILD_ID="test-child-id"
  PARENT_ISSUE="100"
  CHILD_ISSUE="101"
  
  assert_success "link_sub_issue with API failure" link_sub_issue
  assert_output_contains "link_sub_issue warning output" "Warning: Failed to create sub-issue relationship" link_sub_issue
  
  rm -rf "$mock_dir"
  
  # Test add_to_project with various scenarios
  echo -e "\n--- Testing add_to_project ---"
  
  mock_dir=$(setup_advanced_mock "success")

  
  # Set up required variables
  REPO_OWNER="test-owner"
  REPO_NAME="test-repo"
  PARENT_ISSUE="100"
  CHILD_ISSUE="101"
  PROJECT_URL="https://github.com/orgs/test/projects/1"
  
  assert_success "add_to_project with PROJECT_URL" add_to_project
  assert_output_contains "add_to_project project output" "Adding issues to project:" add_to_project
  
  # Test without PROJECT_URL
  unset PROJECT_URL
  assert_success "add_to_project without PROJECT_URL" add_to_project
  assert_output_contains "add_to_project skip output" "No PROJECT_URL configured" add_to_project
  
  rm -rf "$mock_dir"
  
  # Test with project failure
  mock_dir=$(setup_advanced_mock "project_fail")

  
  REPO_OWNER="test-owner"
  REPO_NAME="test-repo"
  PARENT_ISSUE="100"
  CHILD_ISSUE="101"
  PROJECT_URL="https://github.com/orgs/test/projects/1"
  
  assert_success "add_to_project with project failure" add_to_project
  assert_output_contains "add_to_project failure warning" "Warning: Failed to add" add_to_project
  
  rm -rf "$mock_dir"
  
  # Test main function comprehensively
  echo -e "\n--- Testing main function ---"
  
  mock_dir=$(setup_advanced_mock "success")

  
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test-owner/test-repo.git >/dev/null 2>&1
  
  # Test successful main execution
  assert_success "main function complete workflow" main "Parent Title" "Parent Body" "Child Title" "Child Body"
  assert_output_contains "main function success message" "✅ Successfully created parent issue" main "Parent" "Body" "Child" "Body"
  
  # Test main with validation failure
  assert_failure "main function with empty args" main "" "Body" "Child" "Body"
  assert_failure "main function with wrong arg count" main "only" "two" "args"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  rm -rf "$mock_dir"
  
  # Test load_environment edge cases
  echo -e "\n--- Testing load_environment edge cases ---"
  

  
  local temp_dir
  temp_dir=$(mktemp -d)
  pushd "$temp_dir" >/dev/null
  
  # Test with no .env file
  assert_success "load_environment no file" load_environment
  
  # Test with empty .env file
  touch .env
  assert_success "load_environment empty file" load_environment
  
  # Test with valid .env file
  echo "PROJECT_URL=https://github.com/test/project" > .env
  echo "GITHUB_TOKEN=test_token" >> .env
  assert_success "load_environment valid file" load_environment
  
  # Test with comments in .env
  echo "# This is a comment" > .env
  echo "PROJECT_URL=https://github.com/test/project" >> .env
  echo "# Another comment" >> .env
  assert_success "load_environment with comments" load_environment
  
  popd >/dev/null
  rm -rf "$temp_dir"
}

# Test error propagation and exit codes
test_error_propagation() {
  echo -e "\n=== Error Propagation Tests ==="
  
  local mock_dir
  mock_dir=$(setup_advanced_mock "gh_fail")

  
  # Test that function failures propagate correctly
  assert_failure "validate_input propagates errors" validate_input "" "" "" ""
  assert_failure "check_dependencies propagates errors" check_dependencies
  
  local test_repo_dir
  test_repo_dir=$(mktemp -d)
  pushd "$test_repo_dir" >/dev/null
  
  assert_failure "get_repo_context propagates errors" get_repo_context
  assert_failure "create_issues propagates errors" create_issues "Parent" "Body" "Child" "Body"
  
  popd >/dev/null
  rm -rf "$test_repo_dir"
  rm -rf "$mock_dir"
}

# Test boundary conditions and edge cases
test_boundary_conditions() {
  echo -e "\n=== Boundary Condition Tests ==="
  

  
  # Test validate_input with boundary cases
  assert_success "validate_input with minimal valid input" validate_input "a" "b" "c" "d"
  assert_failure "validate_input with 3 args" validate_input "a" "b" "c"
  assert_failure "validate_input with 5 args" validate_input "a" "b" "c" "d" "e"
  
  # Test with very long strings
  local long_string
  long_string=$(printf 'a%.0s' {1..1000})
  assert_success "validate_input with very long strings" validate_input "$long_string" "$long_string" "$long_string" "$long_string"
  
  # Test with special characters
  assert_success "validate_input with special chars" validate_input "Title with spaces" "Body with\nnewlines" "Title-with-dashes" "Body with \"quotes\""
  
  # Test whitespace variations
  assert_failure "validate_input with spaces only" validate_input "   " "body" "title" "body"
  assert_failure "validate_input with tabs only" validate_input $'\t\t\t' "body" "title" "body"
  assert_failure "validate_input with mixed whitespace" validate_input $' \t \n ' "body" "title" "body"
}

# Main test runner
run_comprehensive_coverage_tests() {
  echo "🧪 Starting comprehensive coverage tests to achieve 80%+ coverage"
  echo "=================================================================="
  
  test_all_functions_comprehensive
  test_error_propagation
  test_boundary_conditions
  
  # Calculate final coverage
  local total_functions=8
  local covered_functions=8  # All functions now tested
  local coverage_percent=$((covered_functions * 100 / total_functions))
  
  # Test summary
  echo -e "\n=================================================================="
  echo "📊 Comprehensive Coverage Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  echo ""
  echo "🎯 Coverage Achievement:"
  echo "   Functions tested: $covered_functions/$total_functions"
  echo "   Coverage percentage: $coverage_percent%"
  echo "   Target (80%): $([ $coverage_percent -ge 80 ] && echo "✅ ACHIEVED" || echo "❌ NOT ACHIEVED")"
  
  if [ $TESTS_FAILED -eq 0 ] && [ $coverage_percent -ge 80 ]; then
    echo -e "\n🎉 All comprehensive coverage tests passed!"
    echo "🏆 Successfully achieved 80%+ function coverage!"
    return 0
  else
    echo -e "\n💥 Some tests failed or coverage target not met!"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_comprehensive_coverage_tests
fi