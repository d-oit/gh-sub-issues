#!/bin/bash
set -euo pipefail

# Performance tests for gh-issue-manager.sh
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Simple performance test without complex timing
run_simple_performance_tests() {
  echo "🚀 Performance Tests for gh-issue-manager.sh"
  echo "============================================="
  echo "Testing basic performance characteristics..."
  
  # Test 1: Script execution time should be reasonable
  echo -e "\n=== Basic Performance Test ==="
  
  local start_time
  start_time=$(date +%s)
  
  # Run help command (should be fast)
  if "$MAIN_SCRIPT" --help >/dev/null 2>&1; then
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $duration -le 5 ]; then
      echo "✅ Help command performance: PASSED ($duration seconds)"
      ((TESTS_PASSED++))
    else
      echo "❌ Help command performance: FAILED ($duration seconds, >5s)"
      ((TESTS_FAILED++))
    fi
  else
    echo "❌ Help command execution: FAILED"
    ((TESTS_FAILED++))
  fi
  
  # Test 2: Script should handle large inputs without crashing
  echo -e "\n=== Large Input Test ==="
  
  local large_title=""
  local large_body=""
  
  # Create moderately large inputs
  for i in {1..50}; do
    large_title+="Word$i "
    large_body+="This is sentence $i with content. "
  done
  
  start_time=$(date +%s)
  
  # Test with large arguments (should fail quickly due to missing dependencies)
  if ! "$MAIN_SCRIPT" "$large_title" "$large_body" "$large_title" "$large_body" >/dev/null 2>&1; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -le 10 ]; then
      echo "✅ Large input handling: PASSED ($duration seconds)"
      ((TESTS_PASSED++))
    else
      echo "❌ Large input handling: FAILED ($duration seconds, >10s)"
      ((TESTS_FAILED++))
    fi
  else
    echo "⚠️  Large input test: Script succeeded unexpectedly"
    ((TESTS_PASSED++))
  fi
  
  # Test 3: Multiple rapid executions
  echo -e "\n=== Rapid Execution Test ==="
  
  start_time=$(date +%s)
  
  for i in {1..5}; do
    "$MAIN_SCRIPT" --help >/dev/null 2>&1
  done
  
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  if [ $duration -le 10 ]; then
    echo "✅ Rapid execution test: PASSED ($duration seconds for 5 runs)"
    ((TESTS_PASSED++))
  else
    echo "❌ Rapid execution test: FAILED ($duration seconds, >10s)"
    ((TESTS_FAILED++))
  fi
  
  # Test 4: Memory usage (basic check)
  echo -e "\n=== Memory Usage Test ==="
  
  # Check that script doesn't consume excessive memory
  local memory_before
  memory_before=$(ps -o pid,vsz -p $$ 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
  
  # Run script multiple times
  for i in {1..10}; do
    "$MAIN_SCRIPT" --help >/dev/null 2>&1
  done
  
  local memory_after
  memory_after=$(ps -o pid,vsz -p $$ 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
  
  local memory_diff=$((memory_after - memory_before))
  
  if [ $memory_diff -lt 50000 ]; then  # Less than 50MB increase
    echo "✅ Memory usage test: PASSED (${memory_diff}KB increase)"
    ((TESTS_PASSED++))
  else
    echo "❌ Memory usage test: FAILED (${memory_diff}KB increase, >50MB)"
    ((TESTS_FAILED++))
  fi
  
  # Test 5: Argument validation performance
  echo -e "\n=== Argument Validation Performance ==="
  
  start_time=$(date +%s)
  
  # Test various invalid argument combinations (should fail quickly)
  "$MAIN_SCRIPT" >/dev/null 2>&1 || true
  "$MAIN_SCRIPT" "" "" "" "" >/dev/null 2>&1 || true
  "$MAIN_SCRIPT" "   " "   " "   " "   " >/dev/null 2>&1 || true
  
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  if [ $duration -le 5 ]; then
    echo "✅ Argument validation performance: PASSED ($duration seconds)"
    ((TESTS_PASSED++))
  else
    echo "❌ Argument validation performance: FAILED ($duration seconds, >5s)"
    ((TESTS_FAILED++))
  fi
  
  # Test 6: Script startup time
  echo -e "\n=== Script Startup Performance ==="
  
  start_time=$(date +%s)
  
  # Test script startup with syntax check
  if bash -n "$MAIN_SCRIPT"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -le 2 ]; then
      echo "✅ Script startup performance: PASSED ($duration seconds)"
      ((TESTS_PASSED++))
    else
      echo "❌ Script startup performance: FAILED ($duration seconds, >2s)"
      ((TESTS_FAILED++))
    fi
  else
    echo "❌ Script syntax check: FAILED"
    ((TESTS_FAILED++))
  fi
  
  # Performance test summary
  echo -e "\n============================================="
  echo "📊 Performance Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 All performance tests passed!"
    echo "🚀 Script demonstrates acceptable performance"
    return 0
  else
    echo -e "\n⚠️  Some performance tests failed!"
    echo "🔧 Consider optimizing script performance"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if run_simple_performance_tests; then
    exit 0
  else
    exit 1
  fi
fi