# GitHub Issue Manager

A robust tool for managing hierarchical issues with GitHub Projects using the official CLI.

## Features

- ✅ **Automates sub-issue creation** - Handles GitHub's complex GraphQL API requirements since sub-issues aren't directly supported in the CLI
- ✅ **Simplifies hierarchical workflows** - Single command creates both parent and child issues with proper linking
- ✅ **Automatic project board linking** with configurable project URLs
- ✅ **Optional comprehensive logging** - Track operations, debug issues, and monitor performance
- ✅ **Environment-based configuration** via `.env` files
- ✅ **CLI-based workflow** with comprehensive error handling
- ✅ **Input validation** with whitespace and empty argument checking
- ✅ **Dependency verification** for required tools (gh, jq)
- ✅ **Graceful error handling** with detailed error messages
- ✅ **Automated release management** - Version bumping, changelog generation, and GitHub releases
- ✅ **GitHub Actions workflows** - Automated CI/CD, issue management, and maintenance
- ✅ **Comprehensive testing suite** - Unit tests, integration tests, and release validation

## Prerequisites

- **GitHub CLI v2.40+** with sub-issues feature support
- **jq** for JSON processing
- **Git repository** with GitHub remote configured
- **GitHub authentication** (`gh auth login`)

## Setup

1. **Install dependencies:**
   ```bash
   # Install GitHub CLI
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update && sudo apt install gh jq
   ```

2. **Configure authentication:**
   ```bash
   gh auth login
   ```

3. **Optional: Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env to set PROJECT_URL if using project boards
   ```

## Usage

### Basic Usage
```bash
./gh-issue-manager.sh "Parent Title" "Parent Description" "Child Title" "Child Description"
```

### Example
```bash
./gh-issue-manager.sh \
  "Implement User Authentication" \
  "Add OAuth2 authentication system with JWT tokens" \
  "Create Login API Endpoint" \
  "Implement POST /api/auth/login endpoint with validation"
```

### With Logging Enabled
```bash
# Enable logging with INFO level
ENABLE_LOGGING=true LOG_LEVEL=INFO ./gh-issue-manager.sh \
  "Implement User Authentication" \
  "Add OAuth2 authentication system with JWT tokens" \
  "Create Login API Endpoint" \
  "Implement POST /api/auth/login endpoint with validation"

# Enable debug logging for troubleshooting
ENABLE_LOGGING=true LOG_LEVEL=DEBUG ./gh-issue-manager.sh \
  "Debug Issue Creation" \
  "Test issue for debugging purposes" \
  "Debug Child Issue" \
  "Child issue for testing"
```

## Configuration

### Environment Variables (.env)
```bash
# Optional: Project board URL for automatic issue assignment
PROJECT_URL=https://github.com/orgs/your-org/projects/1

# Optional: GitHub token (usually not needed if gh CLI is authenticated)
GITHUB_TOKEN=your_personal_access_token

# Optional: Logging configuration
ENABLE_LOGGING=true                    # Enable/disable logging (default: false)
LOG_LEVEL=INFO                         # Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
LOG_FILE=./logs/gh-issue-manager.log   # Log file path (default: ./logs/gh-issue-manager.log)
```

### Project Board Setup
1. Create a GitHub Project board
2. Set up columns: **Backlog** → **In Progress** → **Done**
3. Copy the project URL to your `.env` file
4. Issues will be automatically added to the project

## Logging

The GitHub Issue Manager includes optional comprehensive logging to help with debugging, monitoring, and audit trails.

### Logging Configuration

Configure logging through environment variables:

```bash
# Enable logging (default: false)
ENABLE_LOGGING=true

# Set log level (default: INFO)
LOG_LEVEL=DEBUG    # Most verbose: DEBUG, INFO, WARN, ERROR
LOG_LEVEL=INFO     # Standard: INFO, WARN, ERROR  
LOG_LEVEL=WARN     # Warnings and errors only: WARN, ERROR
LOG_LEVEL=ERROR    # Errors only: ERROR

# Set log file path (default: ./logs/gh-issue-manager.log)
LOG_FILE=./logs/gh-issue-manager.log
```

### Log Levels

- **DEBUG** - Detailed debugging information including API calls, timing, and internal operations
- **INFO** - General operational information about successful operations and progress
- **WARN** - Warning messages for non-critical issues (also output to console)
- **ERROR** - Critical failures and errors (also output to console)

### Log Format

```
[TIMESTAMP] [LEVEL] [FUNCTION] MESSAGE
[2025-01-15 10:30:45] [INFO] [create_issues] Creating parent issue: 'Feature Implementation'
[2025-01-15 10:30:46] [DEBUG] [create_issues] GitHub API call: gh issue create --title...
[2025-01-15 10:30:47] [INFO] [create_issues] Parent issue created: #123
[2025-01-15 10:30:48] [INFO] [create_issues] Execution time: 2.145s
```

### Usage Examples

```bash
# Basic logging - INFO level
ENABLE_LOGGING=true ./gh-issue-manager.sh "Title" "Body" "Child" "Body"

# Debug logging for troubleshooting
ENABLE_LOGGING=true LOG_LEVEL=DEBUG ./gh-issue-manager.sh "Title" "Body" "Child" "Body"

# Custom log file location
ENABLE_LOGGING=true LOG_FILE=/var/log/github-issues.log ./gh-issue-manager.sh "Title" "Body" "Child" "Body"

# Set in .env file for persistent configuration
echo "ENABLE_LOGGING=true" >> .env
echo "LOG_LEVEL=INFO" >> .env
./gh-issue-manager.sh "Title" "Body" "Child" "Body"
```

### What Gets Logged

- **Function execution** - Entry, exit, and timing for all major functions
- **GitHub API operations** - Issue creation, sub-issue linking, project assignments
- **Performance metrics** - Execution time for each operation and total runtime
- **Error details** - Comprehensive error information with context
- **Configuration loading** - Environment and .env file processing
- **Validation results** - Input validation and dependency checks

### Log File Management

- **Automatic directory creation** - Log directory created if it doesn't exist
- **Append mode** - New executions append to existing log file
- **Manual rotation** - Rotate logs manually when needed:

```bash
# Rotate log file
mv logs/gh-issue-manager.log logs/gh-issue-manager-$(date +%Y%m%d).log
```

## Error Handling

The script includes comprehensive error handling for common scenarios:

- ❌ **Missing dependencies**: Checks for `gh` and `jq`
- ❌ **Invalid arguments**: Validates all 4 required arguments
- ❌ **Empty/whitespace arguments**: Rejects blank or whitespace-only inputs
- ❌ **Repository context**: Ensures you're in a valid Git repository
- ❌ **GitHub API failures**: Handles authentication and permission issues
- ❌ **Project board errors**: Gracefully handles project assignment failures

## Testing

Run the comprehensive test suite:

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suites
./tests/test-unit.sh              # Unit tests
./tests/test-mocked-integration.sh # Mocked integration tests
./tests/test-coverage.sh          # Coverage analysis
```

## Best Practices

1. **Issue Hierarchy**: Uses official GitHub sub-issue relationships via GraphQL API
2. **Project Organization**: 
   - Columns: Backlog → In Progress → Done
   - Use metadata labels for filtering and automation
3. **Automation Requirements**:
   - GitHub CLI v2.40+ with `sub_issues` feature flag
   - Personal access token needs `public_repo` or `repo` scope
4. **Error Prevention**:
   - Always run from within a Git repository
   - Ensure GitHub CLI is authenticated
   - Verify project URLs before use

## Why This Script?

GitHub's CLI (`gh`) doesn't natively support sub-issue creation. Without this script, you would need to manually:

1. Create parent issue
2. Create child issue
3. Use GraphQL API directly to link them
4. Handle API authentication and error checking
5. Manage project board assignments separately

This script automates all these steps in a single command while ensuring:

- ✅ Proper error handling at each stage
- ✅ Input validation and sanitization
- ✅ Environment configuration management
- ✅ Project board integration

## Technical Implementation

Uses GitHub's GraphQL API with `sub_issues` feature flag:
```graphql
mutation {
  addSubIssue(input: {issueId: "PARENT_ID", subIssueId: "CHILD_ID"}) {
    clientMutationId
  }
}
```

### Script Architecture

The script is modularized into testable functions:

- `validate_input()` - Input validation and sanitization
- `check_dependencies()` - Verify required tools are available
- `load_environment()` - Load configuration from .env file
- `get_repo_context()` - Extract repository information
- `create_issues()` - Create parent and child issues
- `link_sub_issue()` - Establish parent-child relationship
- `add_to_project()` - Add issues to project board
- `main()` - Orchestrate the complete workflow

### API Requirements

- **GitHub CLI v2.40+** with sub-issues feature support
- **Personal access token** with `repo` scope (handled by gh CLI)
- **GraphQL Features header**: `sub_issues` flag enabled automatically

## Troubleshooting

### Common Issues

1. **"Failed to get repository owner"**
   ```bash
   # Ensure you're in a Git repository with GitHub remote
   git remote -v
   gh repo view  # Should show repository info
   ```

2. **"Missing required dependencies"**
   ```bash
   # Install missing tools
   sudo apt install gh jq  # Ubuntu/Debian
   brew install gh jq      # macOS
   ```

3. **"Failed to create sub-issue relationship"**
   - Sub-issues feature may not be available for your repository
   - Check GitHub CLI version: `gh --version`
   - Ensure you have write permissions to the repository

4. **"Failed to add to project board"**
   - Verify PROJECT_URL in .env file
   - Ensure you have admin access to the project
   - Check project visibility settings

### Debug Mode

Multiple debugging approaches available:

```bash
# Method 1: Enable logging with DEBUG level
ENABLE_LOGGING=true LOG_LEVEL=DEBUG ./gh-issue-manager.sh "Parent" "Body" "Child" "Body"

# Method 2: Shell debug mode
set -x  # Enable debug mode
./gh-issue-manager.sh "Parent" "Body" "Child" "Body"
set +x  # Disable debug mode

# Method 3: Combined logging and shell debug
set -x
ENABLE_LOGGING=true LOG_LEVEL=DEBUG ./gh-issue-manager.sh "Parent" "Body" "Child" "Body"
set +x

# Check log file for detailed execution trace
cat logs/gh-issue-manager.log
```

## Contributing

1. **Run tests before submitting PRs:**
   ```bash
   ./tests/run-all-tests.sh
   ```

2. **Follow the existing code style:**
   - Use shellcheck for validation
   - Add tests for new functionality
   - Update documentation

3. **Test coverage goals:**
   - Maintain >80% function coverage
   - Add both unit and integration tests
   - Include error scenario testing
