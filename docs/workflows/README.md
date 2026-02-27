# Workflows

This section describes how to integrate SPM Extended commands into real development and release flows: when to run which command, in what order, and in which environment (local vs CI).

| Workflow | When to use it | Doc |
|----------|----------------|-----|
| **Release and publish** | Cutting a release: test, optional metadata edit, dry-run, publish, verify. | [release-and-publish.md](release-and-publish.md) |
| **CI/CD** | Publish automatically on tag push (GitHub Actions, GitLab CI). | [ci-cd.md](ci-cd.md) |
| **Multi-package / monorepo** | Publish several packages in dependency order or with a script. | [multi-package.md](multi-package.md) |
| **Daily development** | When to run `outdated`, `metadata create`, and `clean-cache` during normal dev. | [daily-development.md](daily-development.md) |

**Commands reference:** [metadata](../commands/metadata.md), [publish](../commands/publish.md), [create-signing](../commands/create-signing.md), [clean-cache](../commands/clean-cache.md), [outdated](../commands/outdated.md).
