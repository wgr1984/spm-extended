# SPM Extended Plugin

A Swift Package Manager plugin that provides extended functionality for package publishing workflows, with built-in support for [SE-0291 Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md).

## Features

- 🚀 **Simplified Publishing Workflow**: Automatically generates Package.json and publishes to registry
- 📦 **Package.json Generation**: Automatically creates Package.json from your manifest
- 🤖 **Auto-Metadata Generation**: Automatically creates package-metadata.json from git, README, and LICENSE
- 📝 **Metadata-Only Mode**: Create Package.json and package-metadata.json without publishing
- 🎯 **Collection Support**: Ensures your packages appear in package collections (SE-0291)
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

This creates:
- `Package.json` from your Package.swift manifest
- `package-metadata.json` with auto-extracted metadata

You can then review and edit these files before publishing.

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

> **Note**: If `--metadata-path` is not specified and `package-metadata.json` doesn't exist, the plugin will automatically generate it by extracting information from:
> - Git config (author name and email)
> - README.md (package description)
> - LICENSE file (license type and URL)
> - Git remote (repository URL)

## Command Reference

### `registry publish`

Complete publishing workflow with Package.json generation and registry publishing.

**Usage:**
```bash
swift package registry publish <package-id> <package-version> [options]
```

**Permission**: Requires `--disable-sandbox` flag.

**Arguments:**

| Argument | Description |
|----------|-------------|
| `<package-id>` | Package identifier in format `scope.name` (required) |
| `<package-version>` | Package version to publish (required) |

**Registry Options:**

| Option | Description |
|--------|-------------|
| `--url <url>` | Registry URL |
| `--metadata-path <path>` | Path to package metadata JSON file (default: auto-generated `package-metadata.json`) |
| `--scratch-directory <dir>` | Directory for working files |
| ~~`--allow-insecure-http`~~ | ~~Allow non-HTTPS registry URLs~~ *(Does not work, especially with authentication)* |

**Signing Options:**

| Option | Description |
|--------|-------------|
| `--signing-identity <id>` | Signing identity from system store |
| `--private-key-path <path>` | Path to PKCS#8 private key (DER) |
| `--cert-chain-paths <paths...>` | Paths to signing certificates (DER) |

**Other Options:**

| Option | Description |
|--------|-------------|
| `--disable-sandbox` | **REQUIRED** Disable sandbox for file system access |
| `--dry-run` | Prepare only, do not publish |
| `--vv` | Enable verbose output |
| `-h, --help` | Show help message |

### `registry metadata create`

Create Package.json and package-metadata.json files without publishing.

**Usage:**
```bash
swift package --disable-sandbox registry metadata create [options]
```

**Permission**: Requires `--disable-sandbox` flag.

**Description:**

This command creates the metadata files required for publishing packages to a registry:

1. **Package.json** - Generated from your Package.swift manifest
2. **package-metadata.json** - Auto-generated from:
   - Git config (author name/email)
   - README.md (description)
   - LICENSE file (license type/URL)
   - Git remote (repository URL)

**Options:**

| Option | Description |
|--------|-------------|
| `--scratch-directory <dir>` | Directory for working files |
| `--disable-sandbox` | **REQUIRED** Disable sandbox for file system access |
| `--overwrite` | Overwrite existing metadata files |
| `--vv, --verbose` | Enable verbose output |
| `-h, --help` | Show help message |

**Examples:**

```bash
# Create metadata files
swift package --disable-sandbox registry metadata create

# Create with verbose output
swift package --disable-sandbox registry metadata create --vv

# Overwrite existing files
swift package --disable-sandbox registry metadata create --overwrite
```

**Use Cases:**

- Preview metadata before publishing
- Customize metadata by editing generated files
- Create metadata for manual publishing workflows
- Prepare metadata in CI/CD pipelines

### `registry create-signing`

Create a package-signing Certificate Authority (CA) and optionally a leaf certificate for use with `registry publish`.

**Usage:**
```bash
swift package --disable-sandbox registry create-signing [options]
```

**Permission**: Requires `--disable-sandbox` (writes files and runs OpenSSL).

**Description:**

Generates an EC P-256 CA (key + self-signed certificate) and, with `--create-leaf-cert`, a leaf certificate and key. You can add the CA to global or local Swift PM registry settings so it is trusted for verification. Certificates are signed with SHA-256 (required by Swift PM).

**Options:**

| Option | Description |
|--------|-------------|
| `--output-dir <path>` | Directory for CA and certs (default: `.swiftpm/signing`) |
| `--create-leaf-cert` | Also create a leaf cert and key for publishing |
| `--global` | Add CA to global registry settings (`~/.swiftpm/security`) |
| `--local` | Add CA to local project settings (`.swiftpm/security`) |
| `--overwrite` | Replace existing CA/certs in output directory |
| `--on-unsigned <policy>` | Unsigned packages: `error`, `prompt`, `warn`, `silentAllow` (with `--global`/`--local`) |
| `--on-untrusted-cert <policy>` | Untrusted certificate: `error`, `prompt`, `warn`, `silentAllow` (with `--global`/`--local`) |
| `--cert-expiration <check>` | Certificate expiration check: `enabled`, `disabled` (with `--global`/`--local`) |
| `--cert-revocation <check>` | Revocation check: `strict`, `allowSoftFail`, `disabled` (with `--global`/`--local`) |
| `--vv`, `--verbose` | Verbose output |
| `-h, --help` | Show help message |

**Examples:**

```bash
# Create CA only
swift package --disable-sandbox registry create-signing

# Create CA and leaf cert, then publish
swift package --disable-sandbox registry create-signing --create-leaf-cert
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com \
  --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \
  --private-key-path .swiftpm/signing/leaf.key.der

# Create and add CA to global trust
swift package --disable-sandbox registry create-signing --global
```

**Prerequisite**: OpenSSL must be installed (e.g. `brew install openssl`) and on `PATH`.

### `registry outdated`

List available versions of all dependencies (from registries and Git), independent of version restrictions in `Package.swift`.

**Usage:**
```bash
swift package --disable-sandbox registry outdated [options]
```

**Permission**: Requires `--disable-sandbox` (network access to registries and Git remotes).

**Description:**

Reads `Package.resolved` and, for each dependency, fetches available versions from the registry API or via `git ls-remote --tags`. Shows current vs available versions regardless of constraints in your manifest.

**Options:**

| Option | Description |
|--------|-------------|
| `--disable-sandbox` | **REQUIRED** Disable sandbox for network access |
| `--json` | Output machine-readable JSON |
| `--verbose`, `--vv` | Show all available versions per package (default: latest only) |
| `-h, --help` | Show help message |

**Examples:**

```bash
# List current and available versions
swift package --disable-sandbox registry outdated

# JSON output
swift package --disable-sandbox registry outdated --json

# All versions per package
swift package --disable-sandbox registry outdated --verbose
```

**Note:** Run `swift package resolve` first so that `Package.resolved` exists.

## Complete Publishing Example

Here's a complete workflow from package creation to registry publishing:

```bash
# 1. Navigate to your package
cd MyAwesomePackage

# 2. Configure registry (one-time setup)
swift package-registry set https://registry.example.com
swift package-registry login

# 3. Publish with the plugin
swift package --disable-sandbox registry publish myorg.MyAwesomePackage 1.0.0 --url https://registry.example.com

# Output:
# 🚀 SPM Extended Plugin - Registry Publish
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package: MyAwesomePackage
# Directory: /path/to/MyAwesomePackage
# 
# 📝 Step 1: Generating Package.json...
#    ✓ Package.json created
# 
# 📝 Step 2: Generating package-metadata.json...
#    ✓ Extracted author from git config
#    ✓ Extracted description from README.md
#    ✓ Extracted license information
#    ✓ Extracted repository URL from git
#    ✓ package-metadata.json created
# 
# 🚀 Step 3: Publishing to registry...
#    ✓ Published successfully!
# 
# ✅ Package published to registry!
# 
# Verify publication:
#   curl -H "Accept: application/vnd.swift.registry.v1+json" https://registry.example.com/myorg/MyAwesomePackage

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

2. **Auto-Generate package-metadata.json** (if not present)
   
   Extracts metadata from:
   - Git config → author name and email
   - README.md → package description (first paragraph)
   - LICENSE file → license type and URL
   - Git remote → repository URL
   
   Creates `package-metadata.json`:
   ```json
   {
     "author": {
       "name": "John Doe",
       "email": "john@example.com"
     },
     "description": "A Swift package for...",
     "licenseType": "MIT",
     "licenseURL": "https://github.com/org/repo/blob/main/LICENSE",
     "repositoryURL": "https://github.com/org/repo"
   }
   ```
   
3. **Publish to Registry** (unless `--dry-run`)
   ```bash
   swift package-registry publish <scope>.<name> <version> [options]
   ```

The registry publish command automatically creates the archive and includes both `Package.json` and `package-metadata.json`, ensuring your package appears in Package Collections with rich metadata.

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
