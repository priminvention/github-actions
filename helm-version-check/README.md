# Helm Version Check Action

A composite GitHub Action that checks for Helm chart version updates and optionally creates PRs.

## Features

- 📦 Parses `versions.yaml` files with Renovate-style registry comments
- 🔍 Checks each chart against its Helm registry for updates
- 📊 Outputs update information as JSON for further processing
- 🔀 Optionally creates PRs for each available update
- 🎯 Filter updates by type (major, minor, patch)

## Usage

### Basic Usage (Check Only)

```yaml
name: Check Helm Versions
on:
  schedule:
    - cron: '0 6 * * 1'  # Every Monday at 6am
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check Helm Versions
        id: versions
        uses: priminvention/github-actions/helm-version-check@main
        with:
          versions-file: 'versions.yaml'

      - name: Print Summary
        run: |
          echo "Updates available: ${{ steps.versions.outputs.updates-available }}"
          echo "${{ steps.versions.outputs.updates-summary }}"
```

### Create PRs for Updates

```yaml
name: Update Helm Charts
on:
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check and Update Helm Versions
        uses: priminvention/github-actions/helm-version-check@main
        with:
          versions-file: 'versions.yaml'
          create-pr: 'true'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-labels: 'dependencies,helm,automated'
```

### Filter by Update Type

```yaml
- uses: priminvention/github-actions/helm-version-check@main
  with:
    versions-file: 'versions.yaml'
    update-type: 'patch'  # Only patch updates
    create-pr: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `versions-file` | Path to versions.yaml file | No | `versions.yaml` |
| `create-pr` | Create PRs for updates | No | `false` |
| `update-type` | Filter: all, major, minor, patch | No | `all` |
| `github-token` | GitHub token for PR creation | No | `${{ github.token }}` |
| `pr-labels` | Comma-separated PR labels | No | `dependencies,helm` |
| `dry-run` | Check only, don't create PRs | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `updates-available` | `true` if updates found |
| `updates-json` | JSON array of available updates |
| `updates-summary` | Human-readable summary |

### Updates JSON Format

```json
[
  {
    "name": "cert-manager",
    "registry": "https://charts.jetstack.io",
    "current": "1.14.0",
    "latest": "1.14.5",
    "type": "patch"
  }
]
```

## versions.yaml Format

The action expects a `versions.yaml` file with Renovate-style comments:

```yaml
# Platform Component Versions
components:
  # renovate: registryUrl=https://charts.jetstack.io
  cert-manager: "v1.14.0"

  # renovate: registryUrl=https://kubernetes-sigs.github.io/external-dns/
  external-dns: "1.14.0"

  # renovate: registryUrl=https://charts.external-secrets.io
  external-secrets: "0.9.0"
```

**Key points:**
- Each chart needs a `# renovate: registryUrl=...` comment above it
- Version can be quoted or unquoted
- Version can have optional `v` prefix

## Integration with ArgoCD GitOps

This action is designed to work with ArgoCD GitOps workflows where chart versions are centrally managed in a `versions.yaml` file.

Typical workflow:
1. Action detects new chart version
2. Creates PR with version update
3. PR triggers CI/CD pipeline
4. After merge, ArgoCD syncs the new version

## License

MIT
