#!/bin/bash
set -euo pipefail

# Comprehensive test runner for gh-issue-manager
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 GitHub Issue Manager - Comprehensive Test Suite"
echo "=================================================="

# Track overall results
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITES_RUN=0

run_test_suite() {
  local suite_name="$1"
  local test_script="$2"
  
  echo -e "\n🔍 Running $suite_name..."
  echo "----------------------------------------"
  
  if [ ! -f "$test_script" ]; then
    echo "❌ Test script not found: $test_script"
    ((TOTAL_FAILED++))
    return 1
  fi
  
  if ! chmod +x "$test_script"; then
    echo "❌ Failed to make test script executable: $test_script"
    ((TOTAL_FAILED++))
    return 1
  fi
  
  if "$test_script"; then
    echo "✅ $suite_name: PASSED"
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
  else
    echo "❌ $suite_name: FAILED"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi
  
  SUITES_RUN=$((SUITES_RUN + 1))
}

# Run static analysis first
echo -e "\n🔧 Static Analysis"
echo "----------------------------------------"
echo "⚠️  Skipping shellcheck for now."

# Run test suites
run_test_suite "Windows-Compatible Tests" "$SCRIPT_DIR/test-windows-compatible.sh"
run_test_suite "Unit Tests" "$SCRIPT_DIR/test-unit.sh"
run_test_suite "Enhanced Coverage Tests" "$SCRIPT_DIR/test-enhanced-coverage.sh"
run_test_suite "Integration Tests" "$SCRIPT_DIR/test-gh-issue-manager.sh"
run_test_suite "Mocked Integration Tests" "$SCRIPT_DIR/test-mocked-integration.sh"
run_test_suite "Logging Function Tests" "$SCRIPT_DIR/test-logging-functions.sh"
run_test_suite "Crash Prevention Tests" "$SCRIPT_DIR/test-crash-prevention.sh"
run_test_suite "Performance Tests" "$SCRIPT_DIR/test-performance.sh"
run_test_suite "Coverage Analysis" "$SCRIPT_DIR/test-coverage.sh"

# Generate final report
echo -e "\n📊 Final Test Results"
echo "=================================================="
echo "Test suites run: $SUITES_RUN"
echo "Suites passed: $TOTAL_PASSED"
echo "Suites failed: $TOTAL_FAILED"

if [ $TOTAL_FAILED -eq 0 ]; then
  echo -e "\n🎉 All test suites completed successfully!"
  echo "✅ Code quality: GOOD"
  exit 0
else
  echo -e "\n💥 Some test suites failed!"
  echo "❌ Code quality: NEEDS IMPROVEMENT"
  exit 1
fi