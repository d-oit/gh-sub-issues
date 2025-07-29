# API Reference

This document provides detailed reference information for the GitHub Issue Manager scripts and their functions.

## Table of Contents

- [gh-issue-manager.sh](#gh-issue-managersh)
- [gh-release-manager.sh](#gh-release-managersh)
- [Environment Variables](#environment-variables)
- [Exit Codes](#exit-codes)
- [Error Handling](#error-handling)

## gh-issue-manager.sh

### Synopsis

```bash
./gh-issue-manager.sh [MODE] [OPTIONS] [ARGUMENTS]
```

### Modes

#### CREATE Mode (Default)
Creates a parent issue and a child sub-issue with automatic linking.

```bash
./gh-issue-manager.sh "Parent Title" "Parent Body" "Child Title" "Child Body"
```

**Parameters:**
- `Parent Title` (string): Title for the parent issue
- `Parent Body` (string): Body content for the parent issue
- `Child Title` (string): Title for the child sub-issue
- `Child Body` (string): Body content for the child sub-issue

**Example:**
```bash
./gh-issue-manager.sh \
  "Epic: User Authentication System" \
  "Implement comprehensive user authentication with OAuth2 support" \
  "Task: Setup OAuth2 Provider" \
  "Configure OAuth2 provider integration with GitHub"
```

#### UPDATE Mode
Updates an existing issue with new information.

```bash
./gh-issue-manager.sh UPDATE <issue_number> [--title "New Title"] [--body "New Body"] [--state open|closed]
```

**Parameters:**
- `issue_number` (integer): GitHub issue number to update
- `--title` (string, optional): New title for the issue
- `--body` (string, optional): New body content for the issue
- `--state` (string, optional): New state (open/closed)

**Example:**
```bash
./gh-issue-manager.sh UPDATE 123 --title "Updated: User Authentication" --state closed
```

#### PROCESS_FILES Mode
Processes "Files to Create" sections in issue bodies and creates corresponding GitHub issues.

```bash
./gh-issue-manager.sh PROCESS_FILES <issue_number>
```

**Parameters:**
- `issue_number` (integer): Issue number containing "Files to Create" section

### Core Functions

#### validate_input()
Validates that all provided arguments are non-empty and contain non-whitespace characters.

**Parameters:**
- `$@` (strings): Variable number of arguments to validate

**Returns:**
- `0`: All arguments are valid
- `1`: One or more arguments are invalid

**Example:**
```bash
validate_input "title" "body" "child_title" "child_body"
```

#### check_dependencies()
Verifies that required system dependencies are available.

**Dependencies Checked:**
- GitHub CLI (`gh`)
- JSON processor (`jq`)

**Returns:**
- `0`: All dependencies available
- `1`: One or more dependencies missing

#### create_issues()
Creates both parent and child issues on GitHub.

**Parameters:**
- `$1` (string): Parent issue title
- `$2` (string): Parent issue body
- `$3` (string): Child issue title
- `$4` (string): Child issue body

**Global Variables Set:**
- `PARENT_ISSUE`: Parent issue number
- `CHILD_ISSUE`: Child issue number
- `PARENT_ID`: Parent issue GraphQL ID
- `CHILD_ID`: Child issue GraphQL ID

#### link_sub_issue()
Creates a sub-issue relationship between parent and child issues using GitHub's GraphQL API.

**Prerequisites:**
- `PARENT_ID` and `CHILD_ID` must be set
- GitHub CLI must be authenticated
- Repository must support sub-issues feature

#### add_to_project()
Adds created issues to a GitHub project board if `PROJECT_URL` is configured.

**Environment Variables:**
- `PROJECT_URL`: URL of the GitHub project (e.g., `https://github.com/orgs/myorg/projects/1`)

## gh-release-manager.sh

### Synopsis

```bash
./gh-release-manager.sh [OPTIONS]
```

### Options

- `-M, --major`: Increment major version (X.y.z → X+1.0.0)
- `-m, --minor`: Increment minor version (x.Y.z → x.Y+1.0)
- `-p, --patch`: Increment patch version (x.y.Z → x.y.Z+1) [default]
- `-a, --alpha TAG`: Create alpha pre-release (x.y.z-alpha.TAG)
- `-b, --beta TAG`: Create beta pre-release (x.y.z-beta.TAG)
- `-d, --dry-run`: Show what would be done without making changes
- `-h, --help`: Show help message

### Core Functions

#### get_latest_release_version()
Retrieves the latest release version from GitHub.

**Returns:**
- Latest version string (e.g., "v1.2.3")
- "v0.0.0" if no releases exist

#### calculate_next_version()
Calculates the next version based on current version and bump type.

**Parameters:**
- `$1` (string): Current version
- `$2` (string): Version bump type (major|minor|patch)
- `$3` (boolean): Pre-release flag
- `$4` (string): Pre-release tag

**Returns:**
- Next version string

#### get_closed_issues_since_date()
Retrieves closed issues since a specific date.

**Parameters:**
- `$1` (string): ISO 8601 date string

**Returns:**
- JSON array of closed issues

#### update_changelog()
Updates CHANGELOG.md with new version information and closed issues.

**Parameters:**
- `$1` (string): Next version
- `$2` (array): Closed issues

#### create_github_release()
Creates a GitHub release with generated changelog.

**Parameters:**
- `$1` (string): Version tag
- `$2` (string): Release notes

## Environment Variables

### Logging Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_LOGGING` | `false` | Enable/disable logging system |
| `LOG_LEVEL` | `INFO` | Log level (DEBUG, INFO, WARN, ERROR) |
| `LOG_FILE` | `./logs/gh-issue-manager.log` | Log file path |

### GitHub Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | - | GitHub Personal Access Token (optional) |
| `PROJECT_URL` | - | GitHub project URL for issue assignment |

### Example .env Configuration

```bash
# Enable comprehensive logging
ENABLE_LOGGING=true
LOG_LEVEL=DEBUG
LOG_FILE=./logs/debug.log

# GitHub project integration
PROJECT_URL=https://github.com/orgs/myorg/projects/1

# Optional: Custom GitHub token for cross-repo operations
# GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

## Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | General error (validation, dependency, or execution failure) |
| `2` | Authentication error |
| `3` | Network/API error |

## Error Handling

### Common Error Scenarios

#### Authentication Issues
```bash
Error: GitHub CLI not authenticated
Solution: Run 'gh auth login'
```

#### Missing Dependencies
```bash
Error: Missing required dependencies:
 - gh (GitHub CLI)
 - jq
Solution: Install missing dependencies
```

#### Invalid Arguments
```bash
Error: All arguments must be non-empty and contain non-whitespace characters
Solution: Provide valid, non-empty arguments
```

#### API Rate Limiting
```bash
Warning: GitHub API rate limit approaching
Solution: Wait for rate limit reset or use authenticated requests
```

### Debugging

#### Enable Debug Logging
```bash
export ENABLE_LOGGING=true
export LOG_LEVEL=DEBUG
./gh-issue-manager.sh "Test" "Test body" "Child" "Child body"
```

#### Check Log Files
```bash
tail -f ./logs/gh-issue-manager.log
```

#### Verbose Shell Execution
```bash
bash -x ./gh-issue-manager.sh "Test" "Test body" "Child" "Child body"
```

## Integration Examples

### CI/CD Pipeline Integration

```yaml
# GitHub Actions example
- name: Create release issues
  run: |
    ./gh-issue-manager.sh \
      "Release v${{ github.event.inputs.version }}" \
      "Prepare release v${{ github.event.inputs.version }}" \
      "Update documentation" \
      "Update docs for v${{ github.event.inputs.version }}"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    ENABLE_LOGGING: true
```

### Automated Release Workflow

```bash
#!/bin/bash
# Automated release script

# Create release
./gh-release-manager.sh --minor

# Create follow-up issues
./gh-issue-manager.sh \
  "Post-release tasks" \
  "Tasks to complete after release" \
  "Update documentation" \
  "Update docs with new features"
```

## Performance Considerations

### API Rate Limits
- GitHub API allows 5,000 requests per hour for authenticated users
- Each script execution typically uses 3-5 API calls
- Use `GITHUB_TOKEN` for higher rate limits

### Logging Performance
- Debug logging can impact performance
- Use `INFO` level for production
- Rotate log files regularly

### Network Timeouts
- GitHub CLI has built-in retry logic
- Network issues may cause temporary failures
- Scripts are designed to be re-runnable

## Security Considerations

### Token Management
- Never commit `GITHUB_TOKEN` to version control
- Use environment variables or `.env` files
- Rotate tokens regularly

### Input Validation
- All user inputs are validated
- Special characters are properly escaped
- SQL injection protection (not applicable, but good practice)

### Logging Security
- Log files may contain sensitive information
- Ensure proper file permissions (600)
- Consider log rotation and cleanup

## Troubleshooting

### Common Issues

1. **Sub-issue linking fails**
   - Ensure repository has sub-issues feature enabled
   - Check GitHub CLI version (requires v2.40+)
   - Verify authentication scope includes repository access

2. **Project board assignment fails**
   - Verify `PROJECT_URL` format
   - Ensure user has project write permissions
   - Check project visibility settings

3. **Release creation fails**
   - Verify repository write permissions
   - Check for existing tags with same version
   - Ensure clean working directory

### Getting Help

1. Check log files for detailed error information
2. Run with debug logging enabled
3. Verify all prerequisites are met
4. Check GitHub CLI authentication status
5. Review GitHub API status page for service issues