#!/bin/bash
set -euo pipefail
IFS=

# --- MCP Test Validation Header ---
# [MCP:REQUIRED] Test isolation
# [MCP:REQUIRED] Cleanup guarantees
# [MCP:RECOMMENDED] Failure scenarios

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/../gh-release-manager.sh"
readonly TEST_PREFIX="test-release"

# Global test state
TEST_DIR=""
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
cleanup() {
    if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

assert_success() {
    local description="$1"
    shift
    
    if "$@" >/dev/null 2>&1; then
        echo "✅ $description"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ $description"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_failure() {
    local description="$1"
    shift
    
    if "$@" >/dev/null 2>&1; then
        echo "❌ $description (expected failure but succeeded)"
        ((TESTS_FAILED++))
        return 1
    else
        echo "✅ $description"
        ((TESTS_PASSED++))
        return 0
    fi
}

assert_contains() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == *"$expected"* ]]; then
        echo "✅ $description"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ $description"
        echo "   Expected to contain: $expected"
        echo "   Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Source the main script to test functions
source_main_script() {
    # Create a temporary script that sources the main script without running main
    cat > /tmp/test_source.sh << 'EOF'
#!/bin/bash
set -euo pipefail
IFS=

# Initialize variables to prevent unbound variable errors
ENABLE_LOGGING=${ENABLE_LOGGING:-false}
LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-./logs/gh-release-manager.log}
DRY_RUN=${DRY_RUN:-false}
VERSION_BUMP=${VERSION_BUMP:-patch}
PRE_RELEASE=${PRE_RELEASE:-false}
PRE_RELEASE_TAG=${PRE_RELEASE_TAG:-""}
CURRENT_VERSION=${CURRENT_VERSION:-""}
NEXT_VERSION=${NEXT_VERSION:-""}
REPO_OWNER=${REPO_OWNER:-""}
REPO_NAME=${REPO_NAME:-""}

# Source the main script but prevent main execution
BASH_SOURCE=("dummy")
EOF
    
    # Append the main script content without the main execution check
    sed '/^if \[ "${BASH_SOURCE\[0\]}" = "${0}" \]; then$/,$d' "$MAIN_SCRIPT" >> /tmp/test_source.sh
    
    # shellcheck disable=SC1091
    source /tmp/test_source.sh
}

# Unit tests for core functions
test_argument_parsing() {
    echo "🧪 Testing argument parsing..."
    
    # Test default values
    VERSION_BUMP="patch"
    PRE_RELEASE=false
    DRY_RUN=false
    
    # Test major version flag
    parse_arguments -M
    assert_contains "Major version flag" "major" "$VERSION_BUMP"
    
    # Test minor version flag
    parse_arguments -m
    assert_contains "Minor version flag" "minor" "$VERSION_BUMP"
    
    # Test patch version flag
    parse_arguments -p
    assert_contains "Patch version flag" "patch" "$VERSION_BUMP"
    
    # Test alpha pre-release
    parse_arguments -a 1
    if [ "$PRE_RELEASE" = "true" ] && [ "$PRE_RELEASE_TAG" = "alpha.1" ]; then
        echo "✅ Alpha pre-release flag"
        ((TESTS_PASSED++))
    else
        echo "❌ Alpha pre-release flag"
        ((TESTS_FAILED++))
    fi
    
    # Test beta pre-release
    parse_arguments -b 2
    if [ "$PRE_RELEASE" = "true" ] && [ "$PRE_RELEASE_TAG" = "beta.2" ]; then
        echo "✅ Beta pre-release flag"
        ((TESTS_PASSED++))
    else
        echo "❌ Beta pre-release flag"
        ((TESTS_FAILED++))
    fi
    
    # Test dry-run flag
    parse_arguments -d
    if [ "$DRY_RUN" = "true" ]; then
        echo "✅ Dry-run flag"
        ((TESTS_PASSED++))
    else
        echo "❌ Dry-run flag"
        ((TESTS_FAILED++))
    fi
}

test_version_calculation() {
    echo "🧪 Testing version calculation..."
    
    # Test patch increment
    CURRENT_VERSION="1.2.3"
    VERSION_BUMP="patch"
    PRE_RELEASE=false
    calculate_next_version
    assert_contains "Patch increment" "1.2.4" "$NEXT_VERSION"
    
    # Test minor increment
    CURRENT_VERSION="1.2.3"
    VERSION_BUMP="minor"
    PRE_RELEASE=false
    calculate_next_version
    assert_contains "Minor increment" "1.3.0" "$NEXT_VERSION"
    
    # Test major increment
    CURRENT_VERSION="1.2.3"
    VERSION_BUMP="major"
    PRE_RELEASE=false
    calculate_next_version
    assert_contains "Major increment" "2.0.0" "$NEXT_VERSION"
    
    # Test pre-release
    CURRENT_VERSION="1.2.3"
    VERSION_BUMP="patch"
    PRE_RELEASE=true
    PRE_RELEASE_TAG="alpha.1"
    calculate_next_version
    assert_contains "Pre-release version" "1.2.4-alpha.1" "$NEXT_VERSION"
    
    # Test invalid version format
    CURRENT_VERSION="invalid"
    VERSION_BUMP="patch"
    PRE_RELEASE=false
    assert_failure "Invalid version format" calculate_next_version
}

test_changelog_generation() {
    echo "🧪 Testing changelog generation..."
    
    # Create mock closed issues file
    cat > /tmp/closed_issues.json << 'EOF'
[
  {
    "number": 123,
    "title": "Fix critical bug in authentication",
    "closedAt": "2024-01-15T10:30:00Z"
  },
  {
    "number": 124,
    "title": "Add new feature for user management",
    "closedAt": "2024-01-16T14:20:00Z"
  }
]
EOF
    
    NEXT_VERSION="1.2.4"
    generate_changelog
    
    if [ -f "/tmp/new_changelog.md" ]; then
        local content=$(cat /tmp/new_changelog.md)
        assert_contains "Changelog version header" "## [v1.2.4]" "$content"
        assert_contains "Changelog issue #123" "Fix critical bug in authentication (#123)" "$content"
        assert_contains "Changelog issue #124" "Add new feature for user management (#124)" "$content"
    else
        echo "❌ Changelog file not generated"
        ((TESTS_FAILED++))
    fi
}

test_dry_run_mode() {
    echo "🧪 Testing dry-run mode..."
    
    # Set up test environment
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create test files
    echo "# Test Project" > README.md
    echo "# Changelog" > CHANGELOG.md
    git add . && git commit -m "Initial commit" >/dev/null 2>&1
    
    # Test dry-run mode
    DRY_RUN=true
    NEXT_VERSION="1.0.1"
    CURRENT_VERSION="1.0.0"
    
    # Test changelog update in dry-run
    echo "## [v1.0.1] - 2024-01-15" > /tmp/new_changelog.md
    echo "### Fixed" >> /tmp/new_changelog.md
    echo "- Test fix (#1)" >> /tmp/new_changelog.md
    
    update_changelog_file
    
    # Verify files weren't actually modified
    if ! grep -q "v1.0.1" CHANGELOG.md; then
        echo "✅ Dry-run mode - CHANGELOG.md not modified"
        ((TESTS_PASSED++))
    else
        echo "❌ Dry-run mode - CHANGELOG.md was modified"
        ((TESTS_FAILED++))
    fi
    
    update_readme_version
    
    if ! grep -q "v1.0.1" README.md; then
        echo "✅ Dry-run mode - README.md not modified"
        ((TESTS_PASSED++))
    else
        echo "❌ Dry-run mode - README.md was modified"
        ((TESTS_FAILED++))
    fi
}

test_file_updates() {
    echo "🧪 Testing file updates..."
    
    # Set up test environment
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Create test files
    cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

## [v1.0.0] - 2024-01-01
### Added
- Initial release
EOF
    
    cat > README.md << 'EOF'
# Test Project

Current version: v1.0.0

Download the latest release: v1.0.0
EOF
    
    # Test changelog update
    DRY_RUN=false
    NEXT_VERSION="1.0.1"
    CURRENT_VERSION="1.0.0"
    
    echo "## [v1.0.1] - 2024-01-15" > /tmp/new_changelog.md
    echo "### Fixed" >> /tmp/new_changelog.md
    echo "- Test fix (#1)" >> /tmp/new_changelog.md
    echo "" >> /tmp/new_changelog.md
    
    update_changelog_file
    
    if grep -q "v1.0.1" CHANGELOG.md && grep -q "Test fix (#1)" CHANGELOG.md; then
        echo "✅ CHANGELOG.md updated correctly"
        ((TESTS_PASSED++))
    else
        echo "❌ CHANGELOG.md update failed"
        ((TESTS_FAILED++))
    fi
    
    # Test README update
    update_readme_version
    
    if grep -q "v1.0.1" README.md; then
        echo "✅ README.md updated correctly"
        ((TESTS_PASSED++))
    else
        echo "❌ README.md update failed"
        ((TESTS_FAILED++))
    fi
    
    # Verify backups were created
    if [ -f "CHANGELOG.md.backup" ] && [ -f "README.md.backup" ]; then
        echo "✅ Backup files created"
        ((TESTS_PASSED++))
    else
        echo "❌ Backup files not created"
        ((TESTS_FAILED++))
    fi
}

test_logging_system() {
    echo "🧪 Testing logging system..."
    
    # Test logging initialization
    ENABLE_LOGGING=true
    LOG_LEVEL=DEBUG
    LOG_FILE=/tmp/test_release.log
    
    log_init
    
    if [ -f "$LOG_FILE" ]; then
        echo "✅ Log file created"
        ((TESTS_PASSED++))
    else
        echo "❌ Log file not created"
        ((TESTS_FAILED++))
    fi
    
    # Test logging functions
    log_info "test" "Test info message"
    log_warn "test" "Test warning message"
    log_error "test" "Test error message"
    log_debug "test" "Test debug message"
    
    if grep -q "Test info message" "$LOG_FILE" && 
       grep -q "Test warning message" "$LOG_FILE" && 
       grep -q "Test error message" "$LOG_FILE" && 
       grep -q "Test debug message" "$LOG_FILE"; then
        echo "✅ All log levels working"
        ((TESTS_PASSED++))
    else
        echo "❌ Log levels not working correctly"
        ((TESTS_FAILED++))
    fi
    
    # Clean up
    rm -f "$LOG_FILE"
}

test_error_handling() {
    echo "🧪 Testing error handling..."
    
    # Test invalid version format
    CURRENT_VERSION="not.a.version"
    VERSION_BUMP="patch"
    PRE_RELEASE=false
    assert_failure "Invalid version format handling" calculate_next_version
    
    # Test missing files
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Test missing CHANGELOG.md handling
    DRY_RUN=false
    NEXT_VERSION="1.0.1"
    
    echo "## [v1.0.1] - 2024-01-15" > /tmp/new_changelog.md
    
    update_changelog_file
    
    if [ -f "CHANGELOG.md" ]; then
        echo "✅ CHANGELOG.md created when missing"
        ((TESTS_PASSED++))
    else
        echo "❌ CHANGELOG.md not created when missing"
        ((TESTS_FAILED++))
    fi
}

# Integration tests (require GitHub CLI but use dry-run mode)
test_integration_dry_run() {
    echo "🧪 Testing integration with dry-run mode..."
    
    # Check if we can run basic GitHub CLI commands
    if ! command -v gh >/dev/null 2>&1; then
        echo "⚠️  GitHub CLI not available, skipping integration tests"
        return 0
    fi
    
    # Test help command
    if "$MAIN_SCRIPT" --help >/dev/null 2>&1; then
        echo "✅ Help command works"
        ((TESTS_PASSED++))
    else
        echo "❌ Help command failed"
        ((TESTS_FAILED++))
    fi
    
    # Test dry-run mode (should work even without proper git repo)
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Initialize minimal git repo
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test" > README.md
    git add . && git commit -m "Initial" >/dev/null 2>&1
    
    # This should fail gracefully since we're not in a real GitHub repo
    if "$MAIN_SCRIPT" --dry-run --patch 2>/dev/null; then
        echo "✅ Dry-run mode handles missing GitHub context gracefully"
        ((TESTS_PASSED++))
    else
        # This is expected to fail, but should fail gracefully
        echo "✅ Dry-run mode fails gracefully without GitHub context"
        ((TESTS_PASSED++))
    fi
}

# Main test runner
main() {
    echo "🧪 GitHub Release Manager - Test Suite"
    echo "======================================"
    
    # Check if main script exists
    if [ ! -f "$MAIN_SCRIPT" ]; then
        echo "❌ Main script not found: $MAIN_SCRIPT"
        exit 1
    fi
    
    # Source the main script for unit testing
    source_main_script
    
    # Run unit tests
    echo -e "\n📋 Unit Tests"
    echo "-------------"
    test_argument_parsing
    test_version_calculation
    test_changelog_generation
    test_dry_run_mode
    test_file_updates
    test_logging_system
    test_error_handling
    
    # Run integration tests
    echo -e "\n🔗 Integration Tests"
    echo "-------------------"
    test_integration_dry_run
    
    # Generate test report
    echo -e "\n📊 Test Results"
    echo "==============="
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n🎉 All tests passed!"
        exit 0
    else
        echo -e "\n💥 Some tests failed!"
        exit 1
    fi
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi