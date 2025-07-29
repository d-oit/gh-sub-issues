# Create GitHub Release

Develop a GitHub release manager script (`gh-release-manager.sh`) that integrates with our existing issue management system. The script must:

1. **Version Management**
   - Automatically detect the latest release version from GitHub using `gh release view`
   - Implement semver parsing with patch version increment as default (e.g., 1.2.3 → 1.2.4)
   - Allow optional major/minor version override via flags (`-M` for major, `-m` for minor)

2. **Release Preparation**
   - Generate changelog entries from closed issues since last release using `gh issue list`
   - Update CHANGELOG.md with new version section and date
   - Update version reference in README.md (search/replace pattern)

3. **Release Creation**
   - Create draft release with `gh release create` using generated notes
   - Tag format: vX.Y.Z
   - Pre-release flag support for alpha/beta versions

4. **Issue Management**
   - Close issues marked "fixed-in-next-release"
   - Link release to related parent/child issues using existing `gh-issue-manager.sh` patterns

5. **Integration Requirements**
   - Reuse existing logging system from `gh-issue-manager.sh`
   - Maintain POSIX compliance and pass shellcheck validation
   - Include MCP validation headers
   - Implement dry-run mode for testing
   - Add automated tests in `tests/release-tests.sh`

**Example Workflow:**
1. Detect current version (v1.2.3)
2. Calculate next version (v1.2.4)
3. Collect issues closed since v1.2.3
4. Update CHANGELOG.md and README.md with the detected version
5. Create release draft with generated notes
6. Close resolved issues

**Error Handling:**
- Validate GitHub API responses
- Handle merge conflicts in versioned files
- Implement rollback for failed releases
- Check for uncommitted changes before proceeding

**MCP Validation Steps:**
1. Shellcheck compliance
2. POSIX compatibility tests
3. Dry-run validation
4. Automated test execution
5. Documentation cross-check