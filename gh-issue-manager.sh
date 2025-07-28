#!/bin/bash
set -euo pipefail
IFS=

# --- MCP Validation Header ---
# [MCP:REQUIRED] shellcheck validation
# [MCP:REQUIRED] POSIX compliance check
# [MCP:RECOMMENDED] Error handling coverage

validate_input() {
  if [ $# -ne 4 ]; then
    echo "Usage: $0 \"parent title\" \"parent body\" \"child title\" \"child body\"" >&2
    return 1
  fi

  for var in "$@"; do
    # Check if variable is empty or contains only whitespace
    if [ -z "$var" ] || [[ "$var" =~ ^[[:space:]]*$ ]]; then
      echo "Error: All arguments must be non-empty and contain non-whitespace characters" >&2
      return 1
    fi
  done
}

check_dependencies() {
  local missing_deps=()
  
  if ! command -v gh >/dev/null 2>&1; then
    missing_deps+=("gh (GitHub CLI)")
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    missing_deps+=("jq")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies:" >&2
    printf ' - %s\n' "${missing_deps[@]}" >&2
    return 1
  fi
}

load_environment() {
  if [ -f ".env" ]; then
    set -o allexport
    # shellcheck disable=SC1091
    source .env
    set +o allexport
    echo "Loaded configuration from .env file"
  else
    echo "No .env file found, using current repo context"
  fi
}

get_repo_context() {
  if ! REPO_OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null); then
    echo "Error: Failed to get repository owner. Are you in a git repository with GitHub remote?" >&2
    return 1
  fi
  
  if ! REPO_NAME=$(gh repo view --json name -q .name 2>/dev/null); then
    echo "Error: Failed to get repository name. Are you in a git repository with GitHub remote?" >&2
    return 1
  fi
  
  echo "Repository context: $REPO_OWNER/$REPO_NAME"
}

create_issues() {
  local parent_title="$1"
  local parent_body="$2"
  local child_title="$3"
  local child_body="$4"
  
  # Create parent issue with full output capture
  if ! PARENT_OUTPUT=$(gh issue create --title "$parent_title" --body "$parent_body" --json number,id 2>/dev/null); then
    echo "Error: Failed to create parent issue" >&2
    return 1
  fi
  
  PARENT_ISSUE=$(echo "$PARENT_OUTPUT" | jq -r .number)
  PARENT_ID=$(echo "$PARENT_OUTPUT" | jq -r .id)
  
  # Create child issue with full output capture
  if ! CHILD_OUTPUT=$(gh issue create --title "$child_title" --body "$child_body" --json number,id 2>/dev/null); then
    echo "Error: Failed to create child issue" >&2
    return 1
  fi
  
  CHILD_ISSUE=$(echo "$CHILD_OUTPUT" | jq -r .number)
  CHILD_ID=$(echo "$CHILD_OUTPUT" | jq -r .id)
  
  echo "Created issues: Parent #$PARENT_ISSUE, Child #$CHILD_ISSUE"
}

link_sub_issue() {
  # Link child to parent using GraphQL
  if ! gh api graphql \
    -H "GraphQL-Features: sub_issues" \
    -f query="
mutation {
  addSubIssue(input: {issueId: \"$PARENT_ID\", subIssueId: \"$CHILD_ID\"}) {
    clientMutationId
  }
}" >/dev/null 2>&1; then
    echo "Warning: Failed to create sub-issue relationship. Feature may not be available."
  else
    echo "Linked child issue #$CHILD_ISSUE to parent #$PARENT_ISSUE"
  fi
}

add_to_project() {
  if [ -n "${PROJECT_URL:-}" ]; then
    echo "Adding issues to project: $PROJECT_URL"
    
    if ! gh project item-add "$PROJECT_URL" --owner "$REPO_OWNER" --repo "$REPO_NAME" --issue "$PARENT_ISSUE" 2>/dev/null; then
      echo "Warning: Failed to add parent issue to project board"
    fi
    
    if ! gh project item-add "$PROJECT_URL" --owner "$REPO_OWNER" --repo "$REPO_NAME" --issue "$CHILD_ISSUE" 2>/dev/null; then
      echo "Warning: Failed to add child issue to project board"
    fi
  else
    echo "No PROJECT_URL configured, skipping project board assignment"
  fi
}

main() {
  validate_input "$@" || exit 1
  check_dependencies || exit 1
  load_environment
  get_repo_context || exit 1
  create_issues "$@" || exit 1
  link_sub_issue
  add_to_project
  
  echo "✅ Successfully created parent issue #$PARENT_ISSUE ($PARENT_ID) and child issue #$CHILD_ISSUE ($CHILD_ID)"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi