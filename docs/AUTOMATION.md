# Automation Guide

This document describes the automated workflows and processes set up for the GitHub Issue Manager project.

## Overview

The project uses GitHub Actions to automate:
- **Release management** - Version bumping, changelog updates, and GitHub releases
- **Continuous integration** - Testing, validation, and quality checks
- **Issue management** - Auto-labeling, stale issue cleanup, and project board updates
- **Pull request automation** - Auto-merging and validation
- **Scheduled maintenance** - Regular cleanup and reporting

## Workflows

### 1. Release Automation (`.github/workflows/release.yml`)

**Trigger:** Manual workflow dispatch

**Purpose:** Automate the entire release process

**Features:**
- Version bump selection (patch/minor/major)
- Pre-release support (alpha/beta)
- Comprehensive testing before release
- Automatic changelog generation
- Issue closure for "fixed-in-next-release" items
- Project board updates

**Usage:**
```bash
# Via GitHub UI:
# 1. Go to Actions → Automated Release
# 2. Click "Run workflow"
# 3. Select options and run

# Via CLI:
gh workflow run release.yml \
  --field version_bump=patch \
  --field pre_release=false
```

### 2. Continuous Integration (`.github/workflows/ci.yml`)

**Trigger:** Push to main/develop, Pull requests to main

**Purpose:** Validate code quality and functionality

**Checks:**
- Shellcheck validation
- Unit and integration tests
- Security scanning
- Dry-run release testing

### 3. Issue Automation (`.github/workflows/issue-automation.yml`)

**Trigger:** Issue events (opened, closed, labeled, commented)

**Purpose:** Automate issue management tasks

**Features:**
- **Auto-labeling:** Based on title/content keywords
  - "bug", "error", "fail" → `bug` label
  - "feature", "enhancement" → `enhancement` label
  - "doc", "readme" → `documentation` label
  - "test", "spec" → `testing` label
  - "release", "version" → `release` label

- **Release tracking:** Issues with `release` label get added to milestones
- **Sub-issue creation:** Comment `/create-sub-issues` to trigger automation
- **Project board updates:** Automatic status updates

### 4. Scheduled Maintenance (`.github/workflows/scheduled-maintenance.yml`)

**Trigger:** Weekly (Sundays at 2 AM UTC) or manual

**Purpose:** Keep the repository clean and up-to-date

**Tasks:**
- **Stale issue management:**
  - Mark issues inactive for 60+ days as "stale"
  - Close issues inactive for 67+ days
- **Dependency checking:** Verify tool versions
- **Maintenance reporting:** Generate activity summaries

### 5. Auto-merge (`.github/workflows/auto-merge.yml`)

**Trigger:** Pull request events with "auto-merge" label

**Purpose:** Automatically merge approved PRs

**Process:**
1. Wait for CI checks to pass
2. Auto-merge if all checks succeed
3. Comment if merge fails

## Configuration

### Environment Variables

Key configuration is stored in `.github/workflows/config.yml`:

```yaml
env:
  GH_CLI_MIN_VERSION: '2.40.0'
  TEST_TIMEOUT: '600'
  DEFAULT_BRANCH: 'main'
  STALE_DAYS: '60'
  CLOSE_STALE_DAYS: '67'
  AUTO_MERGE_LABEL: 'auto-merge'
```

### Labels

The automation system uses these labels:

- `bug` - Bug reports
- `enhancement` - Feature requests
- `documentation` - Documentation updates
- `testing` - Test-related issues
- `release` - Release-related issues
- `fixed-in-next-release` - Issues resolved, pending release
- `stale` - Inactive issues
- `auto-merge` - PRs eligible for auto-merge
- `triage` - Issues needing review

### Issue Templates

Structured issue templates in `.github/ISSUE_TEMPLATE/`:

- `bug_report.yml` - Bug report form
- `feature_request.yml` - Feature request form

### Pull Request Template

Standard PR template in `.github/PULL_REQUEST_TEMPLATE.md` ensures:
- Proper description and categorization
- Testing checklist
- Documentation updates
- Code quality verification

## Usage Examples

### Creating a Release

1. **Prepare issues:** Label resolved issues with `fixed-in-next-release`
2. **Run workflow:** Go to Actions → Automated Release
3. **Select options:**
   - Version bump: patch/minor/major
   - Pre-release: true/false
   - Pre-release tag: alpha.1, beta.2, etc.
4. **Monitor:** Watch the workflow complete all steps

### Managing Issues

1. **Auto-labeling:** Issues are automatically labeled based on content
2. **Sub-issues:** Comment `/create-sub-issues "Title 1" "Body 1" "Title 2" "Body 2"`
3. **Release tracking:** Add `release` label to include in milestone
4. **Stale cleanup:** Happens automatically weekly

### Pull Request Workflow

1. **Create PR:** Use the template for consistent format
2. **Auto-merge:** Add `auto-merge` label for automatic merging
3. **CI validation:** All checks must pass before merge
4. **Review:** Manual review still recommended for complex changes

## Monitoring and Troubleshooting

### Workflow Status

Monitor workflow status in the Actions tab:
- ✅ Green: Successful
- ❌ Red: Failed (check logs)
- 🟡 Yellow: In progress
- ⚪ Gray: Skipped/canceled

### Common Issues

1. **Release workflow fails:**
   - Check GitHub token permissions
   - Verify all tests pass
   - Ensure no uncommitted changes

2. **Auto-merge doesn't work:**
   - Verify `auto-merge` label is applied
   - Check that all required CI checks pass
   - Ensure PR is not in draft mode

3. **Issue automation not working:**
   - Check webhook delivery in repository settings
   - Verify workflow permissions
   - Review workflow logs for errors

### Logs and Debugging

Access workflow logs:
1. Go to Actions tab
2. Click on workflow run
3. Click on job name
4. Expand step to see detailed logs

## Security Considerations

- **Token permissions:** Workflows use minimal required permissions
- **Secret scanning:** Automated checks for hardcoded secrets
- **Dependency validation:** Regular security updates
- **Code review:** Manual review for sensitive changes

## Customization

### Adding New Workflows

1. Create `.github/workflows/new-workflow.yml`
2. Define triggers and jobs
3. Test with workflow dispatch first
4. Document in this guide

### Modifying Automation

1. Update workflow files
2. Test changes in a fork first
3. Update documentation
4. Consider backward compatibility

### Custom Labels

Add new labels in repository settings:
1. Go to Issues → Labels
2. Create new label
3. Update workflow files to use new label
4. Document label purpose

## Best Practices

1. **Test workflows:** Use workflow_dispatch for testing
2. **Monitor regularly:** Check workflow status weekly
3. **Keep updated:** Update dependencies and actions regularly
4. **Document changes:** Update this guide when modifying workflows
5. **Review permissions:** Regularly audit workflow permissions
6. **Backup important data:** Workflows can modify repository content

## Support

For issues with automation:
1. Check workflow logs first
2. Review this documentation
3. Create an issue with `automation` label
4. Include workflow run URL and error details