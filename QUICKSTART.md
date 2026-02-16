# Quick Start Guide

Get started with SPM Extended Plugin in 5 minutes.

> **Important**: The plugin requires write permission. Either add `--allow-writing-to-package-directory` to commands, or approve when prompted interactively.

## Installation

### Option 1: Add to Your Package (Recommended)

Add the plugin to your `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourPackage",
    dependencies: [
        // Add the plugin
        .package(url: "https://github.com/wgr1984/swift-package-manager-extended-plugin.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "YourPackage")
    ]
)
```

Then resolve dependencies:
```bash
swift package resolve
```

### Option 2: Use Directly (Without Adding to Package)

Clone the plugin repository and reference it:

```bash
# Clone plugin
git clone https://github.com/wgr1984/swift-package-manager-extended-plugin.git

# Use from your package directory
cd YourPackage
swift package --package-path /path/to/swift-package-manager-extended-plugin publish-prepare
```

## First Use

### Step 1: Prepare Your Package

Navigate to your Swift package:

```bash
cd YourAwesomePackage
```

### Step 2: Configure Registry (One-time)

```bash
swift package-registry set https://registry.example.com
swift package-registry login
```

### Step 3: Publish with the Plugin

```bash
swift package --disable-sandbox registry publish myscope.YourAwesomePackage 1.0.0 --url https://registry.example.com
```

**Output:**
```
🚀 SPM Extended Plugin - Registry Publish
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Package: YourAwesomePackage
Directory: /path/to/YourAwesomePackage

📝 Step 1: Generating Package.json...
   ✓ Package.json created

🚀 Step 2: Publishing to registry...

   Executing: swift package-registry publish myscope.YourAwesomePackage 1.0.0 --url "https://registry.example.com"

   ✓ Published successfully!

✅ Package published to registry!

Verify publication:
  curl -H "Accept: application/vnd.swift.registry.v1+json" https://registry.example.com/myscope/YourAwesomePackage
```

### Step 4: Verify

Your package is now published! Verify it:

```bash
curl -H "Accept: application/vnd.swift.registry.v1+json" https://registry.example.com/myscope/YourAwesomePackage
```

The plugin automatically creates `Package.json` in your package directory for the registry to include in the archive.

## Common Commands

### Create Metadata Only
```bash
swift package --disable-sandbox registry metadata create
```

This creates Package.json and package-metadata.json without publishing. Perfect for:
- Previewing metadata before publishing
- Editing metadata manually
- Preparing files for manual workflows

### Basic Publishing
```bash
swift package --disable-sandbox registry publish myscope.MyPackage 1.0.0 --url https://registry.example.com
```

### Dry Run (Prepare Only)
```bash
swift package --disable-sandbox registry publish myscope.MyPackage 1.0.0 --dry-run
```

### With Signing
```bash
swift package --disable-sandbox registry publish myscope.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --signing-identity "My Developer Certificate"
```

### Two-Step Publishing (Create + Edit + Publish)
```bash
# 1. Create metadata files
swift package --disable-sandbox registry metadata create

# 2. Edit package-metadata.json to customize
# (Edit the file in your editor)

# 3. Publish with customized metadata
swift package --disable-sandbox registry publish myscope.MyPackage 1.0.0 --url https://registry.example.com
```

### Check for dependency updates
```bash
swift package resolve   # ensure Package.resolved exists
swift package --disable-sandbox registry outdated
```

Lists available versions of all dependencies (registry and Git), ignoring Package.swift version restrictions. Use `--verbose` for all versions per package, or `--json` for machine-readable output.

### Get Help
```bash
swift package registry --help
swift package registry publish --help
swift package registry metadata create --help
swift package registry outdated --help
```

### Manual Commands (Without Plugin)
```bash
swift package dump-package > Package.json
swift package-registry publish myscope.MyPackage 1.0.0 --url https://registry.example.com
```

## Example Workflow

Here's a complete workflow from creation to publishing:

```bash
# 1. Create a new package
mkdir MyLibrary
cd MyLibrary
swift package init --type library

# 2. Add the plugin to Package.swift
# (Edit Package.swift to add dependency)

# 3. Implement your library
# (Add your code to Sources/)

# 4. Test your package
swift test

# 5. Configure registry (one-time)
swift package-registry set https://registry.example.com
swift package-registry login

# 6. Publish with the plugin
swift package --disable-sandbox registry publish mycompany.MyLibrary 1.0.0 --url https://registry.example.com

# 7. Verify publication
curl -H "Accept: application/vnd.swift.registry.v1+json" https://registry.example.com/mycompany/MyLibrary
```

## What Gets Created?

### Package.json

The plugin generates `Package.json` in your package directory, containing your package manifest in JSON format:

```json
{
  "name": "YourPackage",
  "platforms": [...],
  "products": [...],
  "targets": [...],
  "toolsVersion": {...}
}
```

This file is automatically included by the registry when creating the source archive during the publish process.

## Troubleshooting

### Permission Prompt

When you first run the plugin, you'll see:

```
Plugin 'publish-prepare' wants permission to write to the package directory.
Stated reason: Generate Package.json and create source archive.
Allow this plugin to write to the package directory? (yes/no)
```

Type `yes` and press Enter.

### "Command not found" Error

**Problem:** Swift can't find the plugin command.

**Solution:** Ensure you've added the plugin as a dependency and run:
```bash
swift package resolve
```

### "Invalid manifest" Error

**Problem:** Your `Package.swift` has syntax errors.

**Solution:** Fix syntax errors:
```bash
swift build  # Check for errors
```

### Publishing Failed

**Problem:** The `swift package-registry publish` command failed.

**Solution:** Check registry configuration and credentials:
```bash
swift package-registry set https://registry.example.com
swift package-registry login
```

## Next Steps

- Read the [full documentation](README.md)
- Check out [usage examples](Examples/USAGE.md)
- Learn about [Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)
- Contribute! See [CONTRIBUTING.md](CONTRIBUTING.md)

## Quick Reference

| Command | Description |
|---------|-------------|
| `swift package registry metadata create` | Create metadata files only (no publishing) |
| `swift package registry publish <id> <ver>` | Publish package to registry |
| `<package-id>` | Package identifier (scope.name) |
| `<version>` | Package version to publish |
| `--url <url>` | Registry URL |
| `--dry-run` | Prepare only, don't publish |
| `--disable-sandbox` | **REQUIRED** flag for file system access |
| `--overwrite` | Overwrite existing metadata files |
| `--vv` | Enable verbose output |
| `--help` | Show help message |

**Note**: The `--disable-sandbox` flag is required for all commands that create or modify files.

## Support

- 📖 [Documentation](README.md)
- 💡 [Examples](Examples/USAGE.md)
- 🐛 [Report Issues](https://github.com/wgr1984/swift-package-manager-extended-plugin/issues)
- 💬 [Discussions](https://github.com/wgr1984/swift-package-manager-extended-plugin/discussions)

---

Ready to publish? Start with:
```bash
# Create metadata files first (optional)
swift package --disable-sandbox registry metadata create

# Or publish directly
swift package --disable-sandbox registry publish myscope.MyPackage 1.0.0 --url https://registry.example.com
```
