# GitHub Issue Manager

A robust tool for managing hierarchical issues with GitHub Projects using the official CLI.

## Features

- ✅ **Parent/child issue relationships** using GitHub's sub-issues API
- ✅ **Automatic project board linking** with configurable project URLs
- ✅ **Environment-based configuration** via `.env` files
- ✅ **CLI-based workflow** with comprehensive error handling
- ✅ **Input validation** with whitespace and empty argument checking
- ✅ **Dependency verification** for required tools (gh, jq)
- ✅ **Graceful error handling** with detailed error messages

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

## Configuration

### Environment Variables (.env)
```bash
# Optional: Project board URL for automatic issue assignment
PROJECT_URL=https://github.com/orgs/your-org/projects/1

# Optional: GitHub token (usually not needed if gh CLI is authenticated)
GITHUB_TOKEN=your_personal_access_token
```

### Project Board Setup
1. Create a GitHub Project board
2. Set up columns: **Backlog** → **In Progress** → **Done**
3. Copy the project URL to your `.env` file
4. Issues will be automatically added to the project

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

Run with verbose output:
```bash
set -x  # Enable debug mode
./gh-issue-manager.sh "Parent" "Body" "Child" "Body"
set +x  # Disable debug mode
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

![GitHub Sub-Issue Relationship](https://docs.github.com/assets/cb-138303/images/help/issues/sub-issues.png)