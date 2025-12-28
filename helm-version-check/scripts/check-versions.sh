#!/bin/bash
# Check Helm chart versions against registries
# Parses versions.yaml with renovate-style comments

set -euo pipefail

VERSIONS_FILE="${VERSIONS_FILE:-versions.yaml}"
UPDATE_TYPE="${UPDATE_TYPE:-all}"

if [[ ! -f "$VERSIONS_FILE" ]]; then
  echo "::error::Versions file not found: $VERSIONS_FILE"
  exit 1
fi

echo "Checking Helm chart versions from: $VERSIONS_FILE"
echo "Update type filter: $UPDATE_TYPE"
echo ""

# Arrays to store results
declare -a UPDATES=()
SUMMARY=""

# Parse versions.yaml and check each chart
# Format expected:
#   # renovate: registryUrl=https://charts.example.io
#   chart-name: "1.2.3"

CURRENT_REGISTRY=""
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Check for registry URL comment
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*renovate:[[:space:]]*registryUrl=(.+)$ ]]; then
    CURRENT_REGISTRY="${BASH_REMATCH[1]}"
    continue
  fi

  # Check for chart version line (key: "version" or key: version)
  if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*[\"\']*v?([0-9]+\.[0-9]+\.[0-9]+)[\"\']*$ ]]; then
    CHART_NAME="${BASH_REMATCH[1]}"
    CURRENT_VERSION="${BASH_REMATCH[2]}"

    if [[ -z "$CURRENT_REGISTRY" ]]; then
      echo "::warning::No registry URL found for chart: $CHART_NAME"
      continue
    fi

    echo "Checking $CHART_NAME..."
    echo "  Registry: $CURRENT_REGISTRY"
    echo "  Current:  $CURRENT_VERSION"

    # Add Helm repo temporarily
    REPO_NAME="temp-${CHART_NAME}-$$"
    if ! helm repo add "$REPO_NAME" "$CURRENT_REGISTRY" --force-update &>/dev/null; then
      echo "::warning::Failed to add Helm repo for $CHART_NAME"
      continue
    fi

    # Get latest version
    LATEST_VERSION=$(helm search repo "$REPO_NAME/$CHART_NAME" --output json 2>/dev/null | \
      jq -r '.[0].version // empty' 2>/dev/null || echo "")

    # Clean up repo
    helm repo remove "$REPO_NAME" &>/dev/null || true

    if [[ -z "$LATEST_VERSION" ]]; then
      echo "::warning::Could not find chart $CHART_NAME in registry"
      continue
    fi

    # Remove 'v' prefix for comparison if present
    LATEST_VERSION_CLEAN="${LATEST_VERSION#v}"
    CURRENT_VERSION_CLEAN="${CURRENT_VERSION#v}"

    echo "  Latest:   $LATEST_VERSION_CLEAN"

    if [[ "$LATEST_VERSION_CLEAN" != "$CURRENT_VERSION_CLEAN" ]]; then
      # Determine update type
      IFS='.' read -r CUR_MAJOR CUR_MINOR CUR_PATCH <<< "$CURRENT_VERSION_CLEAN"
      IFS='.' read -r LAT_MAJOR LAT_MINOR LAT_PATCH <<< "$LATEST_VERSION_CLEAN"

      if [[ "$LAT_MAJOR" -gt "$CUR_MAJOR" ]]; then
        TYPE="major"
      elif [[ "$LAT_MINOR" -gt "$CUR_MINOR" ]]; then
        TYPE="minor"
      else
        TYPE="patch"
      fi

      # Filter by update type
      INCLUDE=false
      case "$UPDATE_TYPE" in
        all) INCLUDE=true ;;
        major) [[ "$TYPE" == "major" ]] && INCLUDE=true ;;
        minor) [[ "$TYPE" == "minor" || "$TYPE" == "major" ]] && INCLUDE=true ;;
        patch) INCLUDE=true ;;
      esac

      if $INCLUDE; then
        echo "  ⬆️  Update available ($TYPE): $CURRENT_VERSION_CLEAN -> $LATEST_VERSION_CLEAN"

        UPDATE_ENTRY=$(jq -nc \
          --arg name "$CHART_NAME" \
          --arg registry "$CURRENT_REGISTRY" \
          --arg current "$CURRENT_VERSION_CLEAN" \
          --arg latest "$LATEST_VERSION_CLEAN" \
          --arg type "$TYPE" \
          '{name: $name, registry: $registry, current: $current, latest: $latest, type: $type}')

        UPDATES+=("$UPDATE_ENTRY")
        SUMMARY+="- **$CHART_NAME**: $CURRENT_VERSION_CLEAN → $LATEST_VERSION_CLEAN ($TYPE)\n"
      fi
    else
      echo "  ✅ Up to date"
    fi

    echo ""
  fi
done < "$VERSIONS_FILE"

# Generate outputs
if [[ ${#UPDATES[@]} -gt 0 ]]; then
  echo "updates-available=true" >> "$GITHUB_OUTPUT"

  # Combine updates into JSON array
  UPDATES_JSON=$(printf '%s\n' "${UPDATES[@]}" | jq -s '.')

  # Handle multiline output
  {
    echo "updates-json<<EOF"
    echo "$UPDATES_JSON"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  {
    echo "updates-summary<<EOF"
    echo -e "$SUMMARY"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  echo ""
  echo "================================"
  echo "📦 ${#UPDATES[@]} update(s) available"
  echo "================================"
  echo -e "$SUMMARY"
else
  echo "updates-available=false" >> "$GITHUB_OUTPUT"
  echo "updates-json=[]" >> "$GITHUB_OUTPUT"
  echo "updates-summary=No updates available" >> "$GITHUB_OUTPUT"

  echo ""
  echo "================================"
  echo "✅ All charts are up to date"
  echo "================================"
fi
