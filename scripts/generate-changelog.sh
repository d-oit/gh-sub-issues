#!/bin/bash

# generate-changelog.sh - Standalone changelog generator
# Generates CHANGELOG.md following Keep a Changelog format
# Usage: ./scripts/generate-changelog.sh [version] [since-tag]

set -euo pipefail

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "unreleased")}"
SINCE_TAG="${2:-$(git describe --tags --abbrev=0 2>/dev/null || echo "")}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_usage() {
    echo "Changelog Generator"
    echo "Generates CHANGELOG.md following Keep a Changelog format"
    echo ""
    echo "Usage: $0 [version] [since-tag]"
    echo ""
    echo "Arguments:"
    echo "  version     Version to generate changelog for (default: latest tag or 'unreleased')"
    echo "  since-tag   Generate changelog since this tag (default: previous tag)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Generate for latest version since previous tag"
    echo "  $0 1.2.0              # Generate for version 1.2.0 since previous tag"
    echo "  $0 1.2.0 v1.1.0       # Generate for version 1.2.0 since v1.1.0"
    echo ""
    echo "Environment Variables:"
    echo "  CHANGELOG_FILE        Output file path (default: CHANGELOG.md)"
    echo "  INCLUDE_LINKS         Include version comparison links (default: true)"
}

# Handle help option
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Configuration
CHANGELOG_FILE="${CHANGELOG_FILE:-$PROJECT_ROOT/CHANGELOG.md}"
INCLUDE_LINKS="${INCLUDE_LINKS:-true}"

print_info "Generating changelog for version $VERSION"

# Determine the range for git log
if [ -n "$SINCE_TAG" ]; then
    print_info "Getting commits since $SINCE_TAG"
    COMMIT_RANGE="${SINCE_TAG}..HEAD"
else
    print_info "Getting all commits"
    COMMIT_RANGE=""
fi

# Create temporary files for categorizing commits
TEMP_DIR=$(mktemp -d)
added_file="$TEMP_DIR/added"
changed_file="$TEMP_DIR/changed"
fixed_file="$TEMP_DIR/fixed"
security_file="$TEMP_DIR/security"
deprecated_file="$TEMP_DIR/deprecated"
removed_file="$TEMP_DIR/removed"
other_file="$TEMP_DIR/other"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Get commits in the specified range
if [ -n "$COMMIT_RANGE" ]; then
    commits=$(git log --pretty=format:"%s" "$COMMIT_RANGE" 2>/dev/null || echo "")
else
    commits=$(git log --pretty=format:"%s" 2>/dev/null || echo "")
fi

if [ -z "$commits" ]; then
    print_warning "No commits found in the specified range"
    commits=""
fi

# Process each commit and categorize based on conventional commits
commit_count=0
while IFS= read -r commit; do
    if [ -z "$commit" ]; then
        continue
    fi
    
    commit_count=$((commit_count + 1))
    
    case "$commit" in
        feat\(*|feat:*)
            echo "- ${commit#feat*: }" >> "$added_file"
            ;;
        fix\(*|fix:*)
            echo "- ${commit#fix*: }" >> "$fixed_file"
            ;;
        security\(*|security:*)
            echo "- ${commit#security*: }" >> "$security_file"
            ;;
        deprecate\(*|deprecate:*|deprecated\(*|deprecated:*)
            echo "- ${commit#deprecat*: }" >> "$deprecated_file"
            ;;
        remove\(*|remove:*|removed\(*|removed:*)
            echo "- ${commit#remov*: }" >> "$removed_file"
            ;;
        docs\(*|docs:*|chore\(*|chore:*|refactor\(*|refactor:*|perf\(*|perf:*|style\(*|style:*|test\(*|test:*)
            echo "- ${commit}" >> "$changed_file"
            ;;
        *)
            echo "- ${commit}" >> "$other_file"
            ;;
    esac
done <<< "$commits"

print_info "Processed $commit_count commits"

# Create the new changelog entry
new_entry_file="$TEMP_DIR/new_entry.md"
{
    if [ "$VERSION" = "unreleased" ]; then
        echo "## [Unreleased]"
    else
        echo "## [$VERSION] - $(date +%Y-%m-%d)"
    fi
    echo ""
} > "$new_entry_file"

# Add categorized changes following Keep a Changelog format
sections_added=0
for category in "Added:$added_file" "Changed:$changed_file" "Deprecated:$deprecated_file" "Removed:$removed_file" "Fixed:$fixed_file" "Security:$security_file"; do
    category_name="${category%:*}"
    file_path="${category#*:}"
    
    if [ -s "$file_path" ]; then
        echo "### $category_name" >> "$new_entry_file"
        echo "" >> "$new_entry_file"
        cat "$file_path" >> "$new_entry_file"
        echo "" >> "$new_entry_file"
        sections_added=$((sections_added + 1))
        print_info "Added $category_name section ($(wc -l < "$file_path") items)"
    fi
done

# Add other changes if any
if [ -s "$other_file" ]; then
    echo "### Other Changes" >> "$new_entry_file"
    echo "" >> "$new_entry_file"
    cat "$other_file" >> "$new_entry_file"
    echo "" >> "$new_entry_file"
    sections_added=$((sections_added + 1))
    print_info "Added Other Changes section ($(wc -l < "$other_file") items)"
fi

if [ $sections_added -eq 0 ]; then
    print_warning "No changes found to add to changelog"
    echo "### Changed" >> "$new_entry_file"
    echo "" >> "$new_entry_file"
    echo "- No significant changes in this release" >> "$new_entry_file"
    echo "" >> "$new_entry_file"
fi

# Create or update the complete changelog
{
    echo "# Changelog"
    echo ""
    echo "All notable changes to this project will be documented in this file."
    echo ""
    echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),"
    echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
    echo ""
} > "$CHANGELOG_FILE"

# Add the new entry
cat "$new_entry_file" >> "$CHANGELOG_FILE"

# Preserve existing changelog entries if they exist
if [ -f "$CHANGELOG_FILE.bak" ] || git show HEAD:CHANGELOG.md >/dev/null 2>&1; then
    print_info "Preserving existing changelog entries"
    
    # Try to get existing changelog from git first, then backup file
    if git show HEAD:CHANGELOG.md >/dev/null 2>&1; then
        existing_entries=$(git show HEAD:CHANGELOG.md | sed -n '/^## \[/,$p' | grep -v "^## \[$VERSION\]" || true)
    elif [ -f "$CHANGELOG_FILE.bak" ]; then
        existing_entries=$(sed -n '/^## \[/,$p' "$CHANGELOG_FILE.bak" | grep -v "^## \[$VERSION\]" || true)
    else
        existing_entries=""
    fi
    
    if [ -n "$existing_entries" ]; then
        echo "$existing_entries" >> "$CHANGELOG_FILE"
        print_info "Preserved existing changelog entries"
    fi
fi

# Add version links at the bottom if enabled
if [ "$INCLUDE_LINKS" = "true" ]; then
    print_info "Adding version comparison links"
    echo "" >> "$CHANGELOG_FILE"
    
    # Get repository URL from git remote
    repo_url=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github.com\//' || echo "")
    
    if [ -n "$repo_url" ]; then
        # Get all tags for version links
        all_tags=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null || true)
        
        if [ -n "$all_tags" ]; then
            prev_tag=""
            echo "$all_tags" | while IFS= read -r tag; do
                version_num="${tag#v}"
                if [ -z "$prev_tag" ]; then
                    # First tag (latest) - compare with HEAD
                    echo "[$version_num]: $repo_url/compare/$tag...HEAD" >> "$CHANGELOG_FILE"
                else
                    # Compare with previous tag
                    echo "[$version_num]: $repo_url/compare/$tag...$prev_tag" >> "$CHANGELOG_FILE"
                fi
                prev_tag="$tag"
            done
            
            # Add link for the oldest version
            if [ -n "$prev_tag" ]; then
                oldest_version="${prev_tag#v}"
                echo "[$oldest_version]: $repo_url/releases/tag/$prev_tag" >> "$CHANGELOG_FILE"
            fi
            
            # Add unreleased link if version is unreleased
            if [ "$VERSION" = "unreleased" ]; then
                latest_tag=$(echo "$all_tags" | head -1)
                if [ -n "$latest_tag" ]; then
                    echo "[Unreleased]: $repo_url/compare/$latest_tag...HEAD" >> "$CHANGELOG_FILE"
                fi
            fi
        fi
    fi
fi

print_success "Changelog generated successfully: $CHANGELOG_FILE"

# Show summary
total_lines=$(wc -l < "$CHANGELOG_FILE")
print_info "Generated changelog with $total_lines lines"

if [ $commit_count -gt 0 ]; then
    print_info "Processed $commit_count commits into $sections_added sections"
else
    print_warning "No commits found - generated placeholder changelog"
fi