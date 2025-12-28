#!/bin/bash
# Create PRs for Helm chart updates
# Uses GitHub CLI (gh) to create pull requests

set -euo pipefail

VERSIONS_FILE="${VERSIONS_FILE:-versions.yaml}"
UPDATES_JSON="${UPDATES_JSON:-[]}"
PR_LABELS="${PR_LABELS:-dependencies,helm}"

if [[ "$UPDATES_JSON" == "[]" ]]; then
  echo "No updates to process"
  exit 0
fi

# Configure git identity for GitHub Actions
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Get current branch
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Process each update
echo "$UPDATES_JSON" | jq -c '.[]' | while read -r update; do
  CHART_NAME=$(echo "$update" | jq -r '.name')
  CURRENT_VERSION=$(echo "$update" | jq -r '.current')
  LATEST_VERSION=$(echo "$update" | jq -r '.latest')
  UPDATE_TYPE=$(echo "$update" | jq -r '.type')

  echo "Processing update for $CHART_NAME..."

  # Create branch name
  BRANCH_NAME="deps/helm-${CHART_NAME}-${LATEST_VERSION}"

  # Check if branch already exists on remote
  if git ls-remote --heads origin "$BRANCH_NAME" 2>/dev/null | grep -q "$BRANCH_NAME"; then
    echo "Branch $BRANCH_NAME already exists on remote, skipping..."
    continue
  fi

  # Check if PR already exists (open or closed) to avoid duplicate PRs
  EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --state all --json number,state --jq '.[0] | "\(.number) (\(.state))"' 2>/dev/null || echo "")
  if [[ -n "$EXISTING_PR" ]]; then
    echo "PR $EXISTING_PR already exists for $BRANCH_NAME, skipping..."
    continue
  fi

  # Create new branch
  git checkout -b "$BRANCH_NAME"

  # Update version in file
  # Handle both quoted and unquoted versions, with or without 'v' prefix
  if grep -q "^[[:space:]]*${CHART_NAME}:[[:space:]]*[\"']v" "$VERSIONS_FILE"; then
    # Version has 'v' prefix and quotes
    sed -i "s/^\([[:space:]]*${CHART_NAME}:[[:space:]]*[\"']\)v[0-9.]*\([\"']\)/\1v${LATEST_VERSION}\2/" "$VERSIONS_FILE"
  elif grep -q "^[[:space:]]*${CHART_NAME}:[[:space:]]*[\"']" "$VERSIONS_FILE"; then
    # Version has quotes but no 'v' prefix
    sed -i "s/^\([[:space:]]*${CHART_NAME}:[[:space:]]*[\"']\)[0-9.]*\([\"']\)/\1${LATEST_VERSION}\2/" "$VERSIONS_FILE"
  else
    # Version has no quotes
    sed -i "s/^\([[:space:]]*${CHART_NAME}:[[:space:]]*\)v\?[0-9.]*/\1${LATEST_VERSION}/" "$VERSIONS_FILE"
  fi

  # Commit changes
  git add "$VERSIONS_FILE"
  git commit -m "chore(deps): update $CHART_NAME to $LATEST_VERSION

Update $CHART_NAME Helm chart from $CURRENT_VERSION to $LATEST_VERSION ($UPDATE_TYPE update)"

  # Push branch
  git push -u origin "$BRANCH_NAME"

  # Create PR using heredoc to avoid escaping issues
  gh pr create \
    --title "chore(deps): update $CHART_NAME to $LATEST_VERSION" \
    --body "## Summary
Updates **$CHART_NAME** Helm chart from $CURRENT_VERSION to $LATEST_VERSION ($UPDATE_TYPE update).

## Checklist
- [ ] Review changelog for breaking changes
- [ ] Verify in dev/staging environment
- [ ] Update any custom values if needed

---
*This PR was automatically created by [helm-version-check](https://github.com/priminvention/github-actions)*" \
    --base "$BASE_BRANCH" \
    --head "$BRANCH_NAME" || {
      echo "Warning: Failed to create PR, but branch was pushed successfully"
    }

  echo "Created PR for $CHART_NAME update"

  # Return to base branch
  git checkout "$BASE_BRANCH"
done

echo "Done processing updates"
