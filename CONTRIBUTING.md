# Contributing Guidelines

## Getting Started
1. Fork the repository
2. Clone your fork: `git clone https://github.com/d-oit/gh-sub-issues.git`
3. Create a feature branch: `git checkout -b feature/your-feature`

## Development Setup
```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Test script
./tests/test-gh-issue-manager.sh
```

## Pull Request Process
1. Ensure all tests pass
2. Update documentation if needed
3. Use descriptive commit messages
4. Reference related issues in PR description

## Coding Standards
- Follow shellcheck guidelines
- Use 2-space indentation
- Include comments for complex logic
- Add tests for new functionality