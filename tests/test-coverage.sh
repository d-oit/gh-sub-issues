#!/bin/bash
set -euo pipefail

# Test coverage analysis and reporting
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

analyze_coverage() {
  echo "🔍 Analyzing test coverage for gh-issue-manager.sh"
  echo "=================================================="
  
  # Extract function names from main script
  local functions
  functions=$(grep -n "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$MAIN_SCRIPT" | cut -d: -f2 | cut -d'(' -f1)
  
  echo "📋 Functions found in main script:"
  echo "$functions" | sed 's/^/  - /'
  
  echo -e "\n🧪 Test coverage analysis:"
  
  # Check which functions are tested
  local test_files=("$SCRIPT_DIR/test-gh-issue-manager.sh" "$SCRIPT_DIR/test-unit.sh" "$SCRIPT_DIR/test-enhanced-coverage.sh" "$SCRIPT_DIR/test-function-coverage.sh" "$SCRIPT_DIR/test-mocked-integration.sh" "$SCRIPT_DIR/test-logging-functions.sh")
  local covered_functions=()
  local uncovered_functions=()
  
  while IFS= read -r func; do
    local is_covered=false
    
    for test_file in "${test_files[@]}"; do
      if [ -f "$test_file" ] && grep -q "$func" "$test_file"; then
        is_covered=true
        break
      fi
    done
    
    if [ "$is_covered" = true ]; then
      covered_functions+=("$func")
      echo "  ✅ $func - COVERED"
    else
      uncovered_functions+=("$func")
      echo "  ❌ $func - NOT COVERED"
    fi
  done <<< "$functions"
  
  # Calculate coverage percentage
  local total_functions=${#covered_functions[@]}
  local covered_count=${#covered_functions[@]}
  local total_count=$((covered_count + ${#uncovered_functions[@]}))
  local coverage_percent=0
  
  if [ $total_count -gt 0 ]; then
    coverage_percent=$((covered_count * 100 / total_count))
  fi
  
  echo -e "\n📊 Coverage Summary:"
  echo "  Functions covered: $covered_count"
  echo "  Functions total: $total_count"
  echo "  Coverage: $coverage_percent%"
  
  # Analyze code paths
  echo -e "\n🛤️  Code Path Analysis:"
  
  # Check error handling coverage
  local error_patterns=("exit 1" "return 1" "|| true" "2>/dev/null")
  echo "  Error handling patterns:"
  for pattern in "${error_patterns[@]}"; do
    local count
    count=$(grep -c "$pattern" "$MAIN_SCRIPT" || echo "0")
    echo "    - '$pattern': $count occurrences"
  done
  
  # Check conditional coverage
  local conditional_patterns=("if " "elif " "case " "while " "for ")
  echo "  Conditional statements:"
  for pattern in "${conditional_patterns[@]}"; do
    local count
    count=$(grep -c "$pattern" "$MAIN_SCRIPT" || echo "0")
    echo "    - '$pattern': $count occurrences"
  done
  
  # Check external command usage
  echo "  External commands used:"
  local commands=("gh " "jq " "git " "echo " "printf ")
  for cmd in "${commands[@]}"; do
    local count
    count=$(grep -c "$cmd" "$MAIN_SCRIPT" || echo "0")
    echo "    - '$cmd': $count occurrences"
  done
  
  # Recommendations
  echo -e "\n💡 Coverage Improvement Recommendations:"
  
  if [ ${#uncovered_functions[@]} -gt 0 ]; then
    echo "  1. Add tests for uncovered functions:"
    printf '     - %s\n' "${uncovered_functions[@]}"
  fi
  
  if [ $coverage_percent -lt 80 ]; then
    echo "  2. Current coverage ($coverage_percent%) is below recommended 80%"
  fi
  
  # Check for missing test scenarios
  echo "  3. Consider adding tests for:"
  echo "     - Network failures (GitHub API down)"
  echo "     - Permission errors (insufficient GitHub permissions)"
  echo "     - Rate limiting scenarios"
  echo "     - Invalid repository contexts"
  echo "     - Malformed JSON responses"
  
  # Check test file quality
  echo -e "\n📝 Test File Quality Analysis:"
  for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
      local test_count
      test_count=$(grep -c "assert_\|TEST\|test_" "$test_file" || echo "0")
      local line_count
      line_count=$(wc -l < "$test_file")
      echo "  $(basename "$test_file"):"
      echo "    - Lines: $line_count"
      echo "    - Test assertions: $test_count"
      echo "    - Test density: $((test_count * 100 / line_count))% (assertions per line)"
    fi
  done
  
  return 0
}

generate_coverage_report() {
  local report_file="$SCRIPT_DIR/coverage-report.md"
  
  echo "📄 Generating coverage report: $report_file"
  
  cat > "$report_file" << EOF
# Test Coverage Report

Generated on: $(date)

## Summary

This report analyzes the test coverage for \`gh-issue-manager.sh\`.

## Function Coverage

$(analyze_coverage | grep -A 20 "🧪 Test coverage analysis:" | tail -n +2)

## Recommendations

1. **Increase Unit Test Coverage**: Focus on testing individual functions in isolation
2. **Add Integration Tests**: Test end-to-end workflows with mocked GitHub API
3. **Error Scenario Testing**: Test failure modes and error handling
4. **Edge Case Testing**: Test boundary conditions and unusual inputs

## Test Files

- \`test-gh-issue-manager.sh\`: Main integration tests
- \`test-unit.sh\`: Unit tests for individual functions
- \`test-coverage.sh\`: Coverage analysis (this file)

## Next Steps

1. Run all tests: \`./tests/test-gh-issue-manager.sh\`
2. Run unit tests: \`./tests/test-unit.sh\`
3. Review coverage: \`./tests/test-coverage.sh\`
4. Add missing tests based on recommendations above

EOF

  echo "✅ Coverage report generated successfully"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  analyze_coverage
  echo ""
  generate_coverage_report
fi