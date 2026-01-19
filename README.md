# SPM Extended Plugin

A Swift Package Manager plugin that provides extended functionality for package publishing workflows, with built-in support for [SE-0291 Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md).

## Features

- 🚀 **Simplified Publishing Workflow**: Automatically generates Package.json and publishes to registry
- 📦 **Package.json Generation**: Automatically creates Package.json from your manifest
- 🎯 **Collection Support**: Ensures your packages appear in package collections (SE-0291)
- ⚡ **Registry Options**: Supports all swift package-registry publish options
- 🔍 **Dry Run Mode**: Use `--dry-run` to prepare without publishing
- 🔐 **Signing Support**: Full support for package signing with certificates
- 📝 **Same Syntax**: Drop-in replacement for `swift package-registry publish`

## Installation

### As a Dependency

Add this plugin to your package's dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wgr1984/swift-package-manager-extended-plugin.git", from: "1.0.0")
]
```

### Local Development

```bash
# Clone the repository
git clone https://github.com/wgr1984/swift-package-manager-extended-plugin.git
cd swift-package-manager-extended-plugin

# Build the plugin
swift build
```

## Usage

> **Note**: The plugin requires write permission to create files in your package directory. Add `--allow-writing-to-package-directory` to the command, or approve the permission when prompted interactively.

### Basic Usage

Navigate to your Swift package directory and run:

```bash
swift package registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

This will:
1. Generate `Package.json` from your `Package.swift` manifest
2. Publish the package to the registry (registry handles archive creation with Package.json included)

### Dry Run (Prepare Only)

To prepare the archive without publishing:

```bash
swift package registry publish myorg.MyPackage 1.0.0 --dry-run
```

This creates `Package.json` and the archive but doesn't publish to the registry.

### With Signing

```bash
swift package registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --signing-identity "My Developer Certificate" \
  --cert-chain-paths cert.der
```

### Advanced Options

```bash
# With custom metadata
swift package registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com --metadata-path metadata.json

# Allow insecure HTTP (for local testing)
swift package registry publish myorg.MyPackage 1.0.0 --url http://localhost:8080 --allow-insecure-http

# Show help
swift package registry publish --help
```

## Command Reference

### `registry publish`

Complete publishing workflow with Package.json generation and registry publishing.

**Usage:**
```bash
swift package registry publish <package-id> <package-version> [options]
```

**Permission**: Requires `--allow-writing-to-package-directory` flag or interactive approval.

**Arguments:**

| Argument | Description |
|----------|-------------|
| `<package-id>` | Package identifier in format `scope.name` (required) |
| `<package-version>` | Package version to publish (required) |

**Registry Options:**

| Option | Description |
|--------|-------------|
| `--url <url>` | Registry URL |
| `--metadata-path <path>` | Path to package metadata JSON file |
| `--scratch-directory <dir>` | Directory for working files |
| `--allow-insecure-http` | Allow non-HTTPS registry URLs |

**Signing Options:**

| Option | Description |
|--------|-------------|
| `--signing-identity <id>` | Signing identity from system store |
| `--private-key-path <path>` | Path to PKCS#8 private key (DER) |
| `--cert-chain-paths <paths...>` | Paths to signing certificates (DER) |

**Other Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Prepare only, do not publish |
| `-h, --help` | Show help message |

## Complete Publishing Example

Here's a complete workflow from package creation to registry publishing:

```bash
# 1. Navigate to your package
cd MyAwesomePackage

# 2. Configure registry (one-time setup)
swift package-registry set https://registry.example.com
swift package-registry login

# 3. Publish with the plugin
swift package registry publish myorg.MyAwesomePackage 1.0.0 --url https://registry.example.com

# Output:
# 🚀 SPM Extended Plugin - Registry Publish
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package: MyAwesomePackage
# Directory: /path/to/MyAwesomePackage
# 
# 📝 Step 1: Generating Package.json...
#    ✓ Package.json created
# 
# 🚀 Step 2: Publishing to registry...
#    ✓ Published successfully!
# 
# ✅ Package published to registry!
# 
# Verify in collection:
#   curl -H "Accept: application/json" https://registry.example.com/collection/myorg

# 4. Your package now appears in collections!
```

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
swift package publish-extended --version 2.0.0
# ... publish to registry
```

### Registry Administrators

Share this plugin with your registry users to simplify the publishing workflow and ensure proper Package.json inclusion.

### CI/CD Pipelines

```bash
# In your GitHub Actions / GitLab CI:
- name: Publish to Registry
  run: |
    swift package --allow-writing-to-package-directory registry publish \
      my-scope.MyPackage ${{ github.ref_name }} \
      --url https://registry.example.com
```

## How It Works

The plugin executes a simplified publishing workflow:

1. **Generate Package.json**
   ```bash
   swift package dump-package > Package.json
   ```
   
2. **Publish to Registry** (unless `--dry-run`)
   ```bash
   swift package-registry publish <scope>.<name> <version> [options]
   ```

The registry publish command automatically creates the archive and includes `Package.json`, ensuring your package appears in Package Collections.

### Why This Plugin?

- **Drop-in Replacement**: Same syntax as `swift package-registry publish` (just use `swift package registry publish`)
- **Simplification**: No need to manually run `swift package dump-package` before publishing
- **Automation**: Perfect for CI/CD pipelines
- **Consistency**: Ensures Package.json is always generated and included
- **Collection Support**: Guarantees packages appear in Package Collections (SE-0291)
- **All Registry Options**: Full support for signing, metadata, and custom configurations

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

**Cause**: Plugin needs write permissions

**Solutions**:

1. **Add flag to command** (recommended for scripts/CI):
   ```bash
   swift package --allow-writing-to-package-directory publish-prepare
   ```

2. **Approve interactively** when prompted:
   ```
   Plugin 'publish-prepare' wants permission to write to the package directory.
   Stated reason: Generate Package.json and create source archive.
   Allow this plugin to write to the package directory? (yes/no)
   ```
   Type `yes` to grant permission.

## Related Tools

- [Swift Package Manager](https://github.com/apple/swift-package-manager)
- [Swift Package Registry](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md)
- [Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## See Also

- [OpenSPMRegistry](https://github.com/wgr1984/OpenSPMRegistry) - A Swift Package Registry implementation with collection support
- [SE-0291 Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)
- [Swift Package Manager Documentation](https://github.com/apple/swift-package-manager/tree/main/Documentation)
