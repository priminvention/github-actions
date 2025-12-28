# Reusable GitHub Actions

A collection of reusable GitHub Actions (Composite Actions) for GitOps workflows.

## Available Actions

| Action | Description |
|--------|-------------|
| [helm-version-check](./helm-version-check/) | Check for Helm chart updates and create PRs |

## Usage

Reference actions from this repository in your workflows:

```yaml
- uses: priminvention/github-actions/helm-version-check@main
  with:
    versions-file: 'versions.yaml'
    create-pr: 'true'
```

## Why Composite Actions?

Unlike Reusable Workflows, Composite Actions:
- Run in the caller's context (same job)
- Share environment and secrets naturally
- Are more flexible for complex logic
- Can be combined with other steps

## Contributing

1. Create a new directory for your action
2. Add `action.yaml` with inputs/outputs
3. Add scripts in a `scripts/` subdirectory
4. Add a `README.md` with usage examples

## License

MIT
