# SPM Extended — Documentation

SPM Extended adds registry publishing, metadata generation, signing, cache cleaning, and dependency checks to Swift Package Manager. You can run it as a **Swift PM plugin** (`swift package registry ...`) or as a **standalone CLI** (`spm-extended registry ...` via Mint or a local build).

## Start here

1. **[Install](docs/installation/README.md)** — Add the plugin to your package, use Mint, or run from a local build.
2. **[Configure registry](docs/getting-started/README.md)** — One-time: `swift package-registry set <url>` and `swift package-registry login`.
3. **[First publish](docs/getting-started/README.md)** — From your package directory: `swift package --disable-sandbox registry publish <scope>.<PackageName> <version> --url <registry-url>`, then verify with the suggested `curl` command.

Commands that create or modify files require `--disable-sandbox` (plugin) or run with write permission; see [Installation](docs/installation/README.md) and [Troubleshooting](docs/troubleshooting/README.md).

---

## Table of contents

### Setup and first use


| Section                                           | Description                                                                     |
| ------------------------------------------------- | ------------------------------------------------------------------------------- |
| [Installation](docs/installation/README.md)       | Add to Package.swift, use by path, Mint, or local build; write permission note. |
| [Getting started](docs/getting-started/README.md) | Configure registry, first publish, verify.                                      |


### Commands


| Section                                                    | Description                                                       |
| ---------------------------------------------------------- | ----------------------------------------------------------------- |
| [registry metadata create](docs/commands/metadata.md)      | Create Package.json and package-metadata.json without publishing. |
| [registry publish](docs/commands/publish.md)               | Publish to registry (with optional dry-run and signing).          |
| [registry create-signing](docs/commands/create-signing.md) | Create CA and leaf certs for package signing.                     |
| [registry clean-cache](docs/commands/clean-cache.md)       | Clean local or global SPM registry caches.                        |
| [outdated](docs/commands/outdated.md)                      | List current vs available dependency versions (registry and Git). |


### Workflows (real-life integration)


| Section                                                      | Description                                              |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| [Workflows overview](docs/workflows/README.md)               | When to use which command; links to each workflow.       |
| [Release and publish](docs/workflows/release-and-publish.md) | Full flow: test → metadata → dry-run → publish → verify. |
| [CI/CD](docs/workflows/ci-cd.md)                             | GitHub Actions and GitLab CI (tag-based publish).        |
| [Multi-package / monorepo](docs/workflows/multi-package.md)  | Publish order, scripts, dependency ordering.             |
| [Daily development](docs/workflows/daily-development.md)     | When to run outdated, metadata create, clean-cache.      |


### Reference


| Section                                              | Description                                                                  |
| ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| [Generated files](docs/reference/generated-files.md) | Package.json and package-metadata.json (what they are, how they’re created). |
| [Quick reference](docs/reference/quick-reference.md) | Command summary and main options.                                            |


### Help


| Section                                           | Description                                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------- |
| [Troubleshooting](docs/troubleshooting/README.md) | Permission prompt, command not found, invalid manifest, publish failures, Mint. |
| [Release process](docs/release-process.md)       | How we tag versions (changelog, Mint “latest”, GitHub Release).           |


---

## More

- [README](README.md) — Project overview and features.
- [Examples/USAGE.md](Examples/USAGE.md) — Extra usage examples.
- [CONTRIBUTING](CONTRIBUTING.md) — How to contribute.

