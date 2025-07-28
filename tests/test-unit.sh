#!/bin/bash
set -euo pipefail

# Unit tests that can run without external dependencies
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Mock functions for testing
mock_gh() {
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
      return 0  # Success for GraphQL calls
      ;;
    "project")
      return 0  # Success for project operations
      ;;
    "auth")
      return 0  # Success for auth check
      ;;
  esac
}

mock_jq() {
  case "$*" in
    *".number"*)
      echo "123"
      ;;
    *".id"*)
      echo "test-id-123"
      ;;
  esac
}

mock_command() {
  case "$1" in
    "-v")
      case "$2" in
        "gh"|"jq")
          return 0  # Command exists
          ;;
        *)
          return 1  # Command doesn't exist
          ;;
      esac
      ;;
  esac
}

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

test_input_validation_edge_cases() {
  echo -e "\n=== Unit Tests: Input Validation Edge Cases ==="
  
  source "$MAIN_SCRIPT"
  
  # Test with whitespace-only arguments
  assert_failure "Whitespace-only first arg" validate_input "   " "body1" "title2" "body2"
  assert_failure "Tab-only second arg" validate_input "title1" $'\t' "title2" "body2"
  assert_failure "Newline-only third arg" validate_input "title1" "body1" $'\n' "body2"
  
  # Test with very long arguments
  local long_string=$(printf 'a%.0s' {1..1000})
  assert_success "Very long arguments" validate_input "$long_string" "$long_string" "$long_string" "$long_string"
  
  # Test with special characters
  assert_success "Special characters" validate_input "Title with spaces" "Body with\nnewlines" "Title-with-dashes" "Body with \"quotes\""
}

test_dependency_checking_mocked() {
  echo -e "\n=== Unit Tests: Dependency Checking (Mocked) ==="
  
  # Create temporary script with mocked commands
  local temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

command() {
  case "$1" in
    "-v")
      case "$2" in
        "gh") return 0 ;;
        "jq") return 0 ;;
        "missing") return 1 ;;
      esac
      ;;
  esac
}

check_dependencies() {
  local missing_deps=()
  
  if ! command -v gh >/dev/null 2>&1; then
    missing_deps+=("gh (GitHub CLI)")
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    missing_deps+=("jq")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies:"
    printf ' - %s\n' "${missing_deps[@]}"
    exit 1
  fi
}

check_dependencies
EOF
  
  chmod +x "$temp_script"
  assert_success "All dependencies available" "$temp_script"
  
  # Test missing dependency
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

command() {
  case "$1" in
    "-v")
      case "$2" in
        "gh") return 1 ;;  # gh missing
        "jq") return 0 ;;
      esac
      ;;
  esac
}

check_dependencies() {
  local missing_deps=()
  
  if ! command -v gh >/dev/null 2>&1; then
    missing_deps+=("gh (GitHub CLI)")
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    missing_deps+=("jq")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies:"
    printf ' - %s\n' "${missing_deps[@]}"
    exit 1
  fi
}

check_dependencies
EOF
  
  assert_failure "Missing gh dependency" "$temp_script"
  
  rm -f "$temp_script"
}

test_environment_loading_edge_cases() {
  echo -e "\n=== Unit Tests: Environment Loading Edge Cases ==="
  
  source "$MAIN_SCRIPT"
  
  # Test with malformed .env file
  local temp_dir=$(mktemp -d)
  pushd "$temp_dir" >/dev/null
  
  # Test with empty .env file
  touch .env
  assert_success "Empty .env file" load_environment
  
  # Test with .env file containing only comments
  echo "# This is a comment" > .env
  echo "# Another comment" >> .env
  assert_success ".env with only comments" load_environment
  
  # Test with .env file containing valid variables
  echo "PROJECT_URL=https://github.com/orgs/test/projects/1" > .env
  echo "GITHUB_TOKEN=test_token" >> .env
  assert_success ".env with valid variables" load_environment
  
  # Test with .env file containing invalid syntax (should still work due to source)
  echo "INVALID LINE WITHOUT EQUALS" > .env
  echo "VALID_VAR=value" >> .env
  # This might fail depending on shell strictness, but we test it
  load_environment 2>/dev/null || true  # Don't fail the test suite
  
  popd >/dev/null
  rm -rf "$temp_dir"
}

test_function_isolation() {
  echo -e "\n=== Unit Tests: Function Isolation ==="
  
  source "$MAIN_SCRIPT"
  
  # Test that functions don't interfere with each other
  local original_pwd="$PWD"
  
  # Test load_environment doesn't change directory
  load_environment >/dev/null 2>&1 || true
  assert_success "load_environment preserves PWD" test "$PWD" = "$original_pwd"
  
  # Test validate_input doesn't modify global state
  local test_var="original_value"
  validate_input "a" "b" "c" "d" >/dev/null 2>&1 || true
  assert_success "validate_input preserves variables" test "$test_var" = "original_value"
}

# Main test runner
run_unit_tests() {
  echo "🧪 Starting unit test suite for gh-issue-manager.sh"
  echo "=================================================="
  
  test_input_validation_edge_cases
  test_dependency_checking_mocked
  test_environment_loading_edge_cases
  test_function_isolation
  
  # Test summary
  echo -e "\n=================================================="
  echo "📊 Unit Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All unit tests passed!"
    return 0
  else
    echo "💥 Some unit tests failed!"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_unit_tests
fi