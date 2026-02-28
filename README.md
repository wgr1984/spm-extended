# SPM Extended Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="assets/logo.svg" alt="SPM Extended logo" width="520">
</p>

<sub>Run `spm-extended --help` to see the logo in your terminal (orange + cyan).</sub>

A Swift Package Manager plugin that provides extended functionality for package publishing workflows, with built-in support for [SE-0291 Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md).

**Full documentation:** [DOCS.md](DOCS.md) — installation, commands, workflows, and troubleshooting.

## Quick start

**Option 1 — Standalone (Mint, no dependency):** From any Swift package directory, run once without adding the plugin to your package:

```bash
mint run wgr1984/spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

Or install globally: `mint install wgr1984/spm-extended`, then `spm-extended registry publish ...`. See [Installation](docs/installation/README.md).

**Option 2 — Plugin as dependency:** Add the package to your `Package.swift`, then from your package directory:

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

Both generate `Package.json` and `package-metadata.json` and publish to the registry. See [Usage](#usage) and [DOCS.md](DOCS.md) for more.

## Features

- 🚀 **Simplified Publishing Workflow**: Automatically generates Package.json and publishes to registry
- 📦 **Package.json Generation**: Automatically creates Package.json from your manifest
- 🤖 **Auto-Metadata Generation**: Automatically creates package-metadata.json from your repo (see [How it works](#how-it-works))
- 📝 **Metadata-Only Mode**: Create Package.json and package-metadata.json without publishing
- 🎯 **Collection Support**: Ensures your packages appear in package collections (SE-0291); requires a registry that supports collections (e.g. [OpenSPMRegistry](https://github.com/wgr1984/OpenSPMRegistry) v0.1.0 or newer)
- ⚡ **Registry Options**: Supports all swift package-registry publish options
- 🔍 **Dry Run Mode**: Use `--dry-run` to prepare without publishing
- 🔐 **Signing Support**: Full support for package signing with certificates
- 📝 **Same Syntax**: Drop-in replacement for `swift package-registry publish`
- 📋 **Check for Updates**: List available versions of all dependencies (registry and Git), independent of Package.swift restrictions

## Installation

### As a Dependency

Add this plugin to your package's dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wgr1984/spm-extended.git", from: "1.0.0")
]
```

### Standalone CLI (Mint)

You can install and run the CLI without adding the plugin as a package dependency using [Mint](https://github.com/yonaskolb/Mint). Mint uses the newest git tag when you omit a version; to use the `main` branch use `@main` (see [Troubleshooting](docs/troubleshooting/README.md#mint-remote-branch-master-not-found)).

```bash
# Install globally (optional; adds spm-extended to PATH when ~/.mint/bin is in PATH)
mint install wgr1984/spm-extended

# Run without installing (one-off)
mint run wgr1984/spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

From any Swift package directory:

```bash
spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
spm-extended registry metadata create
spm-extended registry create-signing --create-leaf-cert
spm-extended registry clean-cache --local
spm-extended outdated
```

Global options when using the CLI:

- `--package-path <path>` — Package directory (default: current directory)
- `--package-name <name>` — Package name (default: read from `Package.swift` via `swift package dump-package`)

### Local Development

```bash
# Clone the repository
git clone https://github.com/wgr1984/spm-extended.git
cd spm-extended

# Build the plugin and CLI
swift build

# Run the CLI
.build/debug/spm-extended --help

# Test standalone CLI (direct run + mint if available)
swift test --filter StandaloneMintTests
```

For development setup and source layout, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

> **Note:** Commands that create files or use the network require `--disable-sandbox` when using the plugin, or the appropriate write/network permission when using the CLI. Add `--disable-sandbox` to the command (e.g. `swift package --disable-sandbox registry publish ...`).

### Basic Usage

Navigate to your Swift package directory and run:

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

This will:
1. Generate `Package.json` from your `Package.swift` manifest
2. Auto-generate `package-metadata.json` from git config, README, and LICENSE (if not present)
3. Publish the package to the registry (registry handles archive creation with Package.json included)

### Create Metadata Only

To create metadata files without publishing:

```bash
swift package --disable-sandbox registry metadata create
```

This creates `Package.json` and `package-metadata.json` (auto-generated; see [How it works](#how-it-works)). You can then review and edit before publishing.

### Dry Run (Prepare Only)

To prepare the files without publishing:

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --dry-run
```

This creates `Package.json` and `package-metadata.json` but doesn't publish to the registry.

### With Signing

Create a package-signing CA and leaf certificate, then publish:

```bash
# Create CA and leaf cert (run once)
swift package --disable-sandbox registry create-signing --create-leaf-cert

# Publish with the generated certs (chain: leaf then CA)
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \
  --private-key-path .swiftpm/signing/leaf.key.der
```

Alternatively use a system signing identity:

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --signing-identity "My Developer Certificate" \
  --cert-chain-paths cert.der
```

### Advanced Options

```bash
# Create metadata first, edit it, then publish
swift package --disable-sandbox registry metadata create
# Edit package-metadata.json
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com

# With custom metadata (overrides auto-generation)
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com --metadata-path custom-metadata.json

# Show help
swift package registry --help
swift package registry publish --help
swift package registry metadata create --help
swift package registry create-signing --help
swift package registry outdated --help
```

### Check for dependency updates

List available versions of all dependencies (from registries and Git), regardless of version constraints in `Package.swift`:

```bash
swift package --disable-sandbox registry outdated
```

Requires `Package.resolved` (run `swift package resolve` first). Use `--verbose` to see all available versions per package, or `--json` for machine-readable output.

## Command Reference

Main commands (all require `--disable-sandbox` when using the plugin):

| Command | Description |
|---------|-------------|
| `swift package registry publish <id> <version> [options]` | Publish to registry (generates Package.json and metadata). Options: `--url`, `--dry-run`, `--metadata-path`, signing options. |
| `swift package registry metadata create [options]` | Create Package.json and package-metadata.json only. Options: `--overwrite`, `--vv`. |
| `swift package registry create-signing [options]` | Create CA and optional leaf cert for signing. Use `--create-leaf-cert` for publishing. |
| `swift package registry clean-cache (--local \| --global \| --all)` | Clean registry caches; use `--disable-sandbox` for `--global`/`--all`. |
| `swift package registry outdated [options]` | List current vs available dependency versions. Options: `--json`, `--verbose`. |

For full option tables and examples, see [DOCS.md](DOCS.md) and run `swift package registry <command> --help`.

## Complete Publishing Example

```bash
cd MyAwesomePackage
swift package-registry set https://registry.example.com
swift package-registry login
swift package --disable-sandbox registry publish myorg.MyAwesomePackage 1.0.0 --url https://registry.example.com
```

The plugin generates Package.json and package-metadata.json, then publishes. Example output: *"Package.json created" → "package-metadata.json created" → "Published successfully!"* Full workflow and verification: [DOCS.md](DOCS.md).

## Why Package.json?

`Package.json` is required for packages to appear in [Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md). It contains:

- Package name and version
- Products and targets
- Platform requirements
- Swift tools version
- Dependencies

Without `Package.json`:
- Your package publishes successfully
- But it **won't appear** in package collections
- Discoverability is reduced

With `Package.json`:
- Your package appears in collections
- Users can discover it through Xcode and SPM
- Better metadata presentation
- Improved package ecosystem integration

## Requirements

- Swift 5.9 or later
- macOS 12 or later
- Swift Package Manager with plugin support

## Use Cases

### Individual Package Publishers

```bash
# One-time setup: Add as dependency to your package
# Then use for every release:
cd MyPackage
swift package --disable-sandbox registry publish myorg.MyPackage 2.0.0 --url https://registry.example.com
```

### Registry Administrators

Share this plugin with your registry users to simplify the publishing workflow and ensure proper Package.json inclusion.

### CI/CD Pipelines

```bash
# In your GitHub Actions / GitLab CI:
- name: Publish to Registry
  run: |
    swift package --disable-sandbox registry publish \
      my-scope.MyPackage ${{ github.ref_name }} \
      --url https://registry.example.com
```

## How It Works

1. **Generate Package.json** from your manifest (`swift package dump-package`).
2. **Auto-generate package-metadata.json** (if not present) from git config (author), README (description), LICENSE (type/URL), and git remote (repository URL). See [DOCS.md](DOCS.md) for the generated structure.
3. **Publish to registry** (unless `--dry-run`) — the registry creates the archive and includes both files so your package appears in Package Collections.

**Why this plugin:** Drop-in replacement for `swift package-registry publish` with the same syntax; no manual `dump-package` step; ensures Package.json is always included for collection support; full signing and registry options.

## Troubleshooting

### "swift package dump-package" fails

**Cause**: Invalid Package.swift manifest

**Solution**: Fix your Package.swift syntax errors first:
```bash
swift build  # Check for errors
```

### Archive not created

**Cause**: `swift package archive-source` command not available

**Solution**: Update to Swift 5.6 or later, which includes the `archive-source` command

### Permission denied

**Cause**: Plugin needs write or network access (e.g. to create metadata files or publish).

**Solutions**:

1. **Add `--disable-sandbox`** (required for plugin commands that write files or use the network):
   ```bash
   swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
   swift package --disable-sandbox registry metadata create
   ```

2. **Approve interactively** when Swift PM prompts for permission to write to the package directory; type `yes` to grant.

## See also

- [DOCS.md](DOCS.md) — Full documentation
- [Swift Package Manager](https://github.com/apple/swift-package-manager) · [Package Registry](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md) · [SPM Documentation](https://github.com/apple/swift-package-manager/tree/main/Documentation)
- [SE-0291 Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)
- [OpenSPMRegistry](https://github.com/wgr1984/OpenSPMRegistry) — Swift Package Registry implementation with collection support

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and how to get started.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
