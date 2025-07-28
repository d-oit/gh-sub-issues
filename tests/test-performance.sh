#!/bin/bash
set -euo pipefail

# Performance tests for gh-issue-manager.sh
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-issue-manager.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
test_pass() {
  local test_name="$1"
  echo "✅ $test_name: PASSED"
  ((TESTS_PASSED++))
}

test_fail() {
  local test_name="$1"
  local details="${2:-}"
  echo "❌ $test_name: FAILED${details:+ - $details}"
  ((TESTS_FAILED++))
}

# Timing utility
time_execution() {
  local start_time
  start_time=$(date +%s.%N)
  "$@"
  local end_time
  end_time=$(date +%s.%N)
  echo "scale=3; $end_time - $start_time" | bc -l
}

# Setup mock environment for performance testing
setup_performance_mock() {
  local delay="${1:-0}"
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Create gh mock with configurable delay
  cat > "$temp_dir/gh" << EOF
#!/bin/bash
sleep $delay  # Simulate network latency
case "\$1 \$2" in
  "repo view")
    if [[ "\$*" == *"owner"* ]]; then
      echo "perf-test-owner"
    elif [[ "\$*" == *"name"* ]]; then
      echo "perf-test-repo"
    fi
    ;;
  "issue create")
    echo '{"number": 999, "id": "perf-test-id-999"}'
    ;;
  "api graphql")
    echo '{"data": {"addSubIssue": {"clientMutationId": "perf-test"}}}'
    ;;
  "project item-add")
    echo "Added to project (performance test)"
    ;;
esac
EOF

  # Create jq mock with delay
  cat > "$temp_dir/jq" << EOF
#!/bin/bash
sleep $delay
case "\$*" in
  *".number"*)
    echo "999"
    ;;
  *".id"*)
    echo "perf-test-id-999"
    ;;
esac
EOF

  chmod +x "$temp_dir/gh" "$temp_dir/jq"
  export PATH="$temp_dir:$PATH"
  echo "$temp_dir"
}

# Test script execution time with various input sizes
test_input_size_performance() {
  echo -e "\n=== Performance Test: Input Size Scaling ==="
  
  local mock_dir
  mock_dir=$(setup_performance_mock "0.01")  # 10ms delay per command
  
  source "$MAIN_SCRIPT"
  
  # Create test repository
  local test_repo
  test_repo=$(mktemp -d)
  pushd "$test_repo" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
  
  # Test with small inputs
  local small_title="Short Title"
  local small_body="Short body text"
  
  local time_small
  time_small=$(time_execution main "$small_title" "$small_body" "$small_title" "$small_body" 2>/dev/null)
  
  if (( $(echo "$time_small < 5.0" | bc -l) )); then
    test_pass "Small input performance ($time_small seconds)"
  else
    test_fail "Small input performance" "took $time_small seconds (>5s)"
  fi
  
  # Test with medium inputs
  local medium_title="Medium Length Title with More Words and Details"
  local medium_body="This is a medium length body with multiple sentences. It contains more detailed information about the issue. It might include technical details, requirements, and acceptance criteria that would be typical in a real-world scenario."
  
  local time_medium
  time_medium=$(time_execution main "$medium_title" "$medium_body" "$medium_title" "$medium_body" 2>/dev/null)
  
  if (( $(echo "$time_medium < 10.0" | bc -l) )); then
    test_pass "Medium input performance ($time_medium seconds)"
  else
    test_fail "Medium input performance" "took $time_medium seconds (>10s)"
  fi
  
  # Test with large inputs
  local large_title="Very Long Title with Many Words and Extensive Details About the Feature or Bug Being Described"
  local large_body=""
  for i in {1..50}; do
    large_body+="This is line $i of a very long issue description. It contains detailed technical information, requirements, acceptance criteria, implementation notes, testing considerations, and other relevant details that might be found in a comprehensive issue description. "
  done
  
  local time_large
  time_large=$(time_execution main "$large_title" "$large_body" "$large_title" "$large_body" 2>/dev/null)
  
  if (( $(echo "$time_large < 15.0" | bc -l) )); then
    test_pass "Large input performance ($time_large seconds)"
  else
    test_fail "Large input performance" "took $time_large seconds (>15s)"
  fi
  
  # Performance scaling analysis
  local scaling_factor
  scaling_factor=$(echo "scale=2; $time_large / $time_small" | bc -l)
  
  if (( $(echo "$scaling_factor < 5.0" | bc -l) )); then
    test_pass "Performance scaling factor ($scaling_factor x)"
  else
    test_fail "Performance scaling factor" "$scaling_factor x (should be <5x)"
  fi
  
  popd >/dev/null
  rm -rf "$test_repo"
  rm -rf "$mock_dir"
}

# Test network latency simulation
test_network_latency_tolerance() {
  echo -e "\n=== Performance Test: Network Latency Tolerance ==="
  
  # Test with low latency (fast network)
  local mock_dir_fast
  mock_dir_fast=$(setup_performance_mock "0.05")  # 50ms delay
  
  source "$MAIN_SCRIPT"
  
  local test_repo
  test_repo=$(mktemp -d)
  pushd "$test_repo" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
  
  local time_fast
  time_fast=$(time_execution main "Fast Test" "Fast network test" "Child Fast" "Child body" 2>/dev/null)
  
  if (( $(echo "$time_fast < 3.0" | bc -l) )); then
    test_pass "Fast network performance ($time_fast seconds)"
  else
    test_fail "Fast network performance" "took $time_fast seconds (>3s)"
  fi
  
  popd >/dev/null
  rm -rf "$test_repo"
  rm -rf "$mock_dir_fast"
  
  # Test with high latency (slow network)
  local mock_dir_slow
  mock_dir_slow=$(setup_performance_mock "0.5")  # 500ms delay per command
  
  source "$MAIN_SCRIPT"
  
  test_repo=$(mktemp -d)
  pushd "$test_repo" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
  
  local time_slow
  time_slow=$(time_execution main "Slow Test" "Slow network test" "Child Slow" "Child body" 2>/dev/null)
  
  if (( $(echo "$time_slow < 30.0" | bc -l) )); then
    test_pass "Slow network tolerance ($time_slow seconds)"
  else
    test_fail "Slow network tolerance" "took $time_slow seconds (>30s)"
  fi
  
  popd >/dev/null
  rm -rf "$test_repo"
  rm -rf "$mock_dir_slow"
}

# Test memory usage with large inputs
test_memory_usage() {
  echo -e "\n=== Performance Test: Memory Usage ==="
  
  local mock_dir
  mock_dir=$(setup_performance_mock "0.01")
  
  source "$MAIN_SCRIPT"
  
  # Create very large input to test memory handling
  local huge_title=""
  local huge_body=""
  
  # Generate large strings (but not excessive for testing)
  for i in {1..100}; do
    huge_title+="Word$i "
  done
  
  for i in {1..500}; do
    huge_body+="This is sentence $i with some content to test memory usage. "
  done
  
  local test_repo
  test_repo=$(mktemp -d)
  pushd "$test_repo" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
  
  # Monitor memory usage (simplified check)
  local memory_before
  memory_before=$(ps -o pid,vsz,rss,comm -p $$ | tail -1 | awk '{print $2}')
  
  main "$huge_title" "$huge_body" "$huge_title" "$huge_body" >/dev/null 2>&1
  
  local memory_after
  memory_after=$(ps -o pid,vsz,rss,comm -p $$ | tail -1 | awk '{print $2}')
  
  local memory_diff
  memory_diff=$((memory_after - memory_before))
  
  # Check if memory usage is reasonable (less than 100MB increase)
  if [ $memory_diff -lt 100000 ]; then
    test_pass "Memory usage reasonable (${memory_diff}KB increase)"
  else
    test_fail "Memory usage excessive" "${memory_diff}KB increase (>100MB)"
  fi
  
  popd >/dev/null
  rm -rf "$test_repo"
  rm -rf "$mock_dir"
}

# Test concurrent execution simulation
test_concurrent_execution() {
  echo -e "\n=== Performance Test: Concurrent Execution Simulation ==="
  
  local mock_dir
  mock_dir=$(setup_performance_mock "0.1")
  
  source "$MAIN_SCRIPT"
  
  local test_repo
  test_repo=$(mktemp -d)
  pushd "$test_repo" >/dev/null
  git init >/dev/null 2>&1
  git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
  
  # Simulate multiple rapid executions
  local start_time
  start_time=$(date +%s.%N)
  
  for i in {1..5}; do
    main "Concurrent Test $i" "Body $i" "Child $i" "Child body $i" >/dev/null 2>&1 &
  done
  
  wait  # Wait for all background processes
  
  local end_time
  end_time=$(date +%s.%N)
  local total_time
  total_time=$(echo "scale=3; $end_time - $start_time" | bc -l)
  
  # Should complete all 5 executions in reasonable time
  if (( $(echo "$total_time < 10.0" | bc -l) )); then
    test_pass "Concurrent execution performance ($total_time seconds for 5 processes)"
  else
    test_fail "Concurrent execution performance" "took $total_time seconds (>10s)"
  fi
  
  popd >/dev/null
  rm -rf "$test_repo"
  rm -rf "$mock_dir"
}

# Test function call overhead
test_function_call_overhead() {
  echo -e "\n=== Performance Test: Function Call Overhead ==="
  
  source "$MAIN_SCRIPT"
  
  # Test individual function performance
  local iterations=1000
  
  # Test validate_input performance
  local start_time
  start_time=$(date +%s.%N)
  
  for i in $(seq 1 $iterations); do
    validate_input "test$i" "body$i" "child$i" "childbody$i" >/dev/null 2>&1
  done
  
  local end_time
  end_time=$(date +%s.%N)
  local validate_time
  validate_time=$(echo "scale=6; ($end_time - $start_time) / $iterations" | bc -l)
  
  if (( $(echo "$validate_time < 0.001" | bc -l) )); then
    test_pass "validate_input overhead (${validate_time}s per call)"
  else
    test_fail "validate_input overhead" "${validate_time}s per call (>1ms)"
  fi
  
  # Test check_dependencies performance
  start_time=$(date +%s.%N)
  
  for i in $(seq 1 100); do  # Fewer iterations for this test
    check_dependencies >/dev/null 2>&1
  done
  
  end_time=$(date +%s.%N)
  local deps_time
  deps_time=$(echo "scale=6; ($end_time - $start_time) / 100" | bc -l)
  
  if (( $(echo "$deps_time < 0.01" | bc -l) )); then
    test_pass "check_dependencies overhead (${deps_time}s per call)"
  else
    test_fail "check_dependencies overhead" "${deps_time}s per call (>10ms)"
  fi
}

# Test resource cleanup performance
test_resource_cleanup() {
  echo -e "\n=== Performance Test: Resource Cleanup ==="
  
  # Test that temporary files and processes are cleaned up efficiently
  local temp_files_before
  temp_files_before=$(find /tmp -name "*gh-issue*" -o -name "*test-subissues*" 2>/dev/null | wc -l)
  
  local mock_dir
  mock_dir=$(setup_performance_mock "0.01")
  
  source "$MAIN_SCRIPT"
  
  # Create and clean up multiple test environments
  for i in {1..10}; do
    local test_repo
    test_repo=$(mktemp -d)
    pushd "$test_repo" >/dev/null
    git init >/dev/null 2>&1
    git remote add origin https://github.com/test/repo.git >/dev/null 2>&1
    
    main "Cleanup Test $i" "Body $i" "Child $i" "Child body $i" >/dev/null 2>&1
    
    popd >/dev/null
    rm -rf "$test_repo"
  done
  
  # Check for resource leaks
  local temp_files_after
  temp_files_after=$(find /tmp -name "*gh-issue*" -o -name "*test-subissues*" 2>/dev/null | wc -l)
  
  local file_leak
  file_leak=$((temp_files_after - temp_files_before))
  
  if [ $file_leak -le 1 ]; then  # Allow for 1 file difference due to timing
    test_pass "Resource cleanup ($file_leak temporary files leaked)"
  else
    test_fail "Resource cleanup" "$file_leak temporary files leaked"
  fi
  
  rm -rf "$mock_dir"
}

# Main performance test runner
run_performance_tests() {
  echo "🚀 Performance Tests for gh-issue-manager.sh"
  echo "============================================="
  echo "Testing script performance under various conditions..."
  
  # Check if bc is available for calculations
  if ! command -v bc >/dev/null 2>&1; then
    echo "⚠️  bc (calculator) not available, skipping precise timing tests"
    echo "   Install bc with: sudo apt install bc"
    return 1
  fi
  
  test_input_size_performance
  test_network_latency_tolerance
  test_memory_usage
  test_concurrent_execution
  test_function_call_overhead
  test_resource_cleanup
  
  # Performance test summary
  echo -e "\n============================================="
  echo "📊 Performance Test Results:"
  echo "✅ Passed: $TESTS_PASSED"
  echo "❌ Failed: $TESTS_FAILED"
  echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 All performance tests passed!"
    echo "🚀 Script demonstrates good performance characteristics"
    return 0
  else
    echo -e "\n⚠️  Some performance tests failed!"
    echo "🔧 Consider optimizing script for better performance"
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_performance_tests
fi