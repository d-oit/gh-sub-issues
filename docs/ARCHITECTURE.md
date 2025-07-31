# Architecture Documentation

## Overview

The GitHub Issue Manager is a bash-based automation tool designed to streamline GitHub issue management and release processes. The system consists of two main components working together to provide comprehensive project management capabilities.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Issue Manager                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ gh-wizard.sh    │  │ gh-issue-       │  │ gh-release- │  │
│  │                 │  │ manager.sh      │  │ manager.sh  │  │
│  │ • Interactive   │  │                 │  │             │  │
│  │   Interface     │  │ • Issue Creation│  │ • Version   │  │
│  │ • Menu System   │  │ • Sub-issue     │  │   Management│  │
│  │ • Debug Mode    │  │   Linking       │  │ • Changelog │  │
│  │ • Verbose Mode  │  │ • Project Board │  │   Generation│  │
│  │ • Performance   │  │   Integration   │  │ • Release   │  │
│  │   Monitoring    │  │                 │  │   Creation  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
│           │                     │                   │       │
│           └─────────────────────┼───────────────────┘       │
│                                 │                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Enhanced Shared Components                 │ │
│  │                                                         │ │
│  │ • Advanced Logging System  • Input Validation          │ │
│  │ • Debug & Verbose Modes    • Environment Loading       │ │
│  │ • Performance Monitoring   • GitHub API Wrappers       │ │
│  │ • Log Rotation Management  • Cross-Module State        │ │
│  │ • Error Handling           • Configuration Management   │ │
│  │ • Dependency Checking      • Command-Line Parsing      │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Dependencies                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GitHub CLI  │  │ jq (JSON    │  │ GitHub API          │  │
│  │ (gh)        │  │ processor)  │  │                     │  │
│  │             │  │             │  │ • REST API          │  │
│  │ • Issue API │  │ • Data      │  │ • GraphQL API       │  │
│  │ • Release   │  │   parsing   │  │ • Sub-issues        │  │
│  │   API       │  │ • Response  │  │ • Projects API      │  │
│  │ • Project   │  │   filtering │  │ • Performance       │  │
│  │   API       │  │             │  │   Monitoring        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### Core Scripts

#### gh-wizard.sh

**Purpose:** Interactive command-line interface for GitHub project management

**Key Responsibilities:**

- Provide interactive menu-driven interface
- Handle command-line argument parsing for debug options
- Coordinate between different management modules
- Implement debug mode, verbose mode, and performance monitoring
- Manage cross-module state and navigation
- Provide comprehensive help and usage information

**Architecture Pattern:** Interactive CLI with modular component loading

#### gh-issue-manager.sh

**Purpose:** Primary issue management and sub-issue creation tool

**Key Responsibilities:**

- Create parent and child issues with automatic linking
- Update existing issues with new content
- Process "Files to Create" sections in issue bodies
- Integrate with GitHub project boards
- Provide comprehensive logging and error handling
- Support performance monitoring for GitHub API calls

**Architecture Pattern:** Command-line interface with mode-based operation

#### gh-release-manager.sh

**Purpose:** Automated release management and version control

**Key Responsibilities:**

- Semantic version calculation and bumping
- Changelog generation from closed issues
- GitHub release creation with automated notes
- Issue closure for resolved items
- Pre-release and beta version support

**Architecture Pattern:** Pipeline-based processing with rollback capabilities

### Shared Infrastructure

#### Logging and Debugging System

**Design Pattern:** Centralized logging with configurable levels and advanced debugging capabilities

```bash
# Enhanced Logging Architecture
┌─────────────────────────────────────────────────────────┐
│                    Logging System                       │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────────────────────┐ │
│ │ Core Functions  │  │ Debug & Verbose Features        │ │
│ │                 │  │                                 │ │
│ │ log_message()   │  │ enable_debug_mode()             │ │
│ │ log_error()     │  │ enable_verbose_mode()           │ │
│ │ log_warn()      │  │ enable_performance_monitoring() │ │
│ │ log_info()      │  │ dump_debug_config()             │ │
│ │ log_debug()     │  │ log_verbose()                   │ │
│ └─────────────────┘  └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────────────────────┐ │
│ │ Performance     │  │ Log Management                  │ │
│ │ Monitoring      │  │                                 │ │
│ │                 │  │ log_init()                      │ │
│ │ log_timing()    │  │ rotate_logs_if_needed()         │ │
│ │ gh_api_call()   │  │ rotate_log_files()              │ │
│ │ gh_issue_call() │  │ parse_debug_args()              │ │
│ │ gh_project_call()│  │                                 │ │
│ └─────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Enhanced Features:**

- **Multi-level logging** (DEBUG, INFO, WARN, ERROR) with filtering
- **Debug mode** with comprehensive diagnostic output
- **Verbose mode** for detailed console feedback
- **Performance monitoring** with GitHub API call timing
- **Automatic log rotation** with configurable size and retention
- **Cross-platform compatibility** (Windows, Linux, macOS)
- **GitHub API wrappers** with performance tracking
- **Configuration dumping** for troubleshooting
- **Command-line argument parsing** for debug options

#### Input Validation

**Design Pattern:** Fail-fast validation with detailed error reporting

```bash
# Validation Flow
Input → validate_input() → Process or Fail
  │                           │
  ├─ Empty check             ├─ Success: Continue
  ├─ Whitespace check        └─ Failure: Error + Exit
  └─ Type validation
```

#### Error Handling

**Design Pattern:** Defensive programming with graceful degradation

**Error Categories:**

1. **Fatal Errors:** Missing dependencies, authentication failures
2. **Recoverable Errors:** API timeouts, temporary network issues
3. **Warnings:** Optional features unavailable, non-critical failures

## Data Flow

### Issue Creation Workflow

```
User Input
    │
    ▼
┌─────────────────┐
│ Input Validation│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Dependency Check│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Environment Load│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Create Parent   │
│ Issue           │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Create Child    │
│ Issue           │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Link Sub-issue  │
│ (GraphQL)       │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Add to Project  │
│ Board           │
└─────────────────┘
```

### Release Management Workflow

```
Release Trigger
    │
    ▼
┌─────────────────┐
│ Get Current     │
│ Version         │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Calculate Next  │
│ Version         │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Collect Closed  │
│ Issues          │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Update          │
│ CHANGELOG.md    │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Create GitHub   │
│ Release         │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Close Fixed     │
│ Issues          │
└─────────────────┘
```

## Integration Points

### GitHub API Integration

**REST API Usage:**

- Issue creation and updates
- Release management
- Project board operations
- Repository information

**GraphQL API Usage:**

- Sub-issue relationship creation
- Complex queries for issue relationships
- Bulk operations

**Authentication:**

- GitHub CLI token management
- Optional personal access token support
- Scope requirements: repo, project, issues

### CI/CD Integration

**GitHub Actions Workflows:**

- Automated testing on push/PR
- Release automation with manual triggers
- Issue management automation
- Scheduled maintenance tasks

**Integration Points:**

```yaml
# Example workflow integration
- name: Create release issues
  run: ./gh-issue-manager.sh "Release $VERSION" "..." "Task" "..."
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Security Model

### Authentication & Authorization

**GitHub CLI Authentication:**

- OAuth-based authentication flow
- Token storage in system keychain
- Automatic token refresh

**Permission Requirements:**

- Repository: read/write access
- Issues: create, update, close
- Projects: read/write access
- Releases: create, publish

### Input Sanitization

**Validation Layers:**

1. **Syntax Validation:** Non-empty, non-whitespace
2. **Content Validation:** Special character handling
3. **API Validation:** GitHub API format requirements

**Security Measures:**

- No eval() or dynamic code execution
- Proper shell escaping for all variables
- Input length limits
- Special character sanitization

### Secrets Management

**Environment Variables:**

- `.env` file support (gitignored)
- System environment variables
- GitHub Actions secrets integration

**Token Security:**

- No hardcoded tokens in scripts
- Automatic token detection via GitHub CLI
- Optional custom token support

## Performance Considerations

### API Rate Limiting

**GitHub API Limits:**

- 5,000 requests/hour (authenticated)
- 60 requests/hour (unauthenticated)
- GraphQL: 5,000 points/hour

**Optimization Strategies:**

- Batch operations where possible
- Efficient GraphQL queries
- Caching of repository information
- Rate limit monitoring

### Script Performance

**Optimization Techniques:**

- Minimal external command calls
- Efficient JSON parsing with jq
- Parallel operations where safe
- Early exit on validation failures

**Performance Monitoring:**

- Function execution timing
- API response time tracking
- Resource usage logging

## Extensibility

### Plugin Architecture

**Extension Points:**

- Custom logging handlers
- Additional validation rules
- Custom project board integrations
- Extended release note generation

**Hook System:**

- Pre/post operation hooks
- Custom notification handlers
- External system integrations

### Configuration Management

**Configuration Hierarchy:**

1. Command-line arguments (highest priority)
2. Environment variables
3. `.env` file
4. Default values (lowest priority)

**Debug and Logging Configuration:**

- `--debug` / `-d` - Enable debug mode with comprehensive logging
- `--verbose` / `-v` - Enable verbose console output
- `--performance` / `-p` - Enable performance monitoring
- `--log-level LEVEL` - Set log level (DEBUG, INFO, WARN, ERROR)
- `--log-file PATH` - Set custom log file path
- `DEBUG_MODE` - Environment variable for debug mode
- `VERBOSE_MODE` - Environment variable for verbose mode
- `PERFORMANCE_MONITORING` - Environment variable for performance monitoring
- `LOG_ROTATION_SIZE` - Log rotation size in bytes
- `LOG_ROTATION_COUNT` - Number of old logs to retain

**Extensible Settings:**

- Custom log formats and rotation policies
- API endpoint overrides and timeout configurations
- Performance monitoring thresholds
- Debug output customization
- Verbose mode formatting options

## Deployment Architecture

### Local Development

```
Developer Machine
├── gh-issue-manager.sh
├── gh-release-manager.sh
├── .env (local config)
├── logs/ (local logs)
└── tests/ (test suite)
```

### CI/CD Environment

```
GitHub Actions Runner
├── Checkout code
├── Install dependencies
├── Run tests
├── Execute scripts
└── Cleanup
```

### Production Usage

```
Production Environment
├── Scheduled releases
├── Automated issue management
├── Integration with project boards
└── Monitoring and alerting
```

## Monitoring and Observability

### Enhanced Logging Strategy

**Log Levels:**

- **DEBUG:** Detailed execution flow, API calls, internal state, configuration dumps
- **INFO:** Normal operations, successful completions, workflow progress
- **WARN:** Non-critical issues, performance warnings, slow operations
- **ERROR:** Critical failures, authentication issues, API failures

**Advanced Logging Features:**

- **Debug Mode:** Comprehensive diagnostic output with configuration dumps
- **Verbose Mode:** Detailed console feedback for user operations
- **Performance Monitoring:** GitHub API call timing with slow operation detection
- **Log Rotation:** Automatic size-based rotation with configurable retention
- **Cross-Platform Support:** Compatible with Windows, Linux, and macOS

**Log Rotation:**

- Configurable size-based rotation (default: 10MB)
- Configurable retention count (default: 5 old logs)
- Automatic cleanup of old log files
- Cross-platform file handling

### Enhanced Metrics Collection

**Performance Metrics:**

- Function execution times with microsecond precision
- GitHub API response times with threshold monitoring
- Slow operation detection (>2s for API calls, >5s for general operations)
- Success/failure rates with detailed error categorization
- Resource utilization tracking

**Debug and Troubleshooting Metrics:**

- Menu navigation patterns (wizard mode)
- User input validation failures
- Configuration loading success/failure
- Module loading and initialization timing
- Cross-module state transitions

**Business Metrics:**

- Issues created per day with sub-issue relationships
- Release frequency and automation success
- Sub-issue relationship success rate
- Project board integration success
- User workflow completion rates (wizard mode)

## Disaster Recovery

### Backup Strategy

**Data Protection:**

- Configuration backup
- Log file preservation
- State recovery mechanisms

**Recovery Procedures:**

- Failed operation rollback
- Partial completion recovery
- Manual intervention procedures

### Error Recovery

**Automatic Recovery:**

- Retry mechanisms for transient failures
- Graceful degradation for optional features
- State preservation during failures

**Manual Recovery:**

- Detailed error reporting
- Recovery procedure documentation
- Support for manual intervention

## Future Architecture Considerations

### Scalability

**Horizontal Scaling:**

- Multi-repository support
- Parallel processing capabilities
- Distributed execution

**Vertical Scaling:**

- Performance optimizations
- Memory usage improvements
- CPU efficiency enhancements

### Technology Evolution

**Potential Migrations:**

- GitHub CLI v3+ compatibility
- New GitHub API features
- Alternative authentication methods
- Enhanced GraphQL capabilities

### Integration Expansion

**Future Integrations:**

- Slack/Teams notifications
- Jira synchronization
- Custom webhook support
- Third-party project management tools
