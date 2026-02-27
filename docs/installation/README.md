# Installation

You can use SPM Extended in three ways: as a **package dependency** (recommended), via **Mint**, or from a **local build** (for development or contributing). Commands that create or modify files require write permission (`--disable-sandbox` when using the plugin, or approval when prompted).

## Option 1: Add to your package (recommended)

Add the plugin to your `Package.swift` so it’s available whenever you work on that package.

1. Add the dependency:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourPackage",
    dependencies: [
        .package(url: "https://github.com/wgr1984/spm-extended.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "YourPackage")
    ]
)
```

2. Resolve dependencies:

```bash
swift package resolve
```

3. Run commands from the package directory (see [Getting started](../getting-started/README.md)):

```bash
cd YourPackage
swift package --disable-sandbox registry publish myscope.YourPackage 1.0.0 --url https://registry.example.com
```

**Why `--disable-sandbox`?** The plugin writes `Package.json` and `package-metadata.json` in your package directory. Swift’s plugin sandbox blocks that unless you pass `--disable-sandbox` or approve the permission when prompted. See [Troubleshooting](../troubleshooting/README.md) for the interactive prompt.

---

## Option 2: Standalone CLI with Mint

Install and run the CLI without adding the plugin to your package using [Mint](https://github.com/yonaskolb/Mint).

**Install (optional; adds `spm-extended` to PATH if `~/.mint/bin` is on PATH):**

```bash
mint install wgr1984/spm-extended
```

**Run without installing (one-off):**

```bash
mint run wgr1984/spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

**From any Swift package directory after install:**

```bash
spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
spm-extended registry metadata create
spm-extended registry create-signing --create-leaf-cert
spm-extended registry clean-cache --local
spm-extended outdated
```

**Global options (CLI only):**

- `--package-path <path>` — Package directory (default: current directory).
- `--package-name <name>` — Package name (default: from `Package.swift` via `swift package dump-package`).

Example:

```bash
spm-extended --package-path /path/to/MyPackage registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

---

## Option 3: Local development build

For contributing or testing changes, you can build and run the CLI from source:

```bash
git clone https://github.com/wgr1984/spm-extended.git
cd spm-extended
swift build
.build/debug/spm-extended --help
```

Use `.build/debug/spm-extended` like the Mint-installed CLI (e.g. from a package directory: `.build/debug/spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com`).

---

## Summary

| Method              | Invocation example |
|---------------------|--------------------|
| Package dependency  | `swift package --disable-sandbox registry publish ...` |
| Mint                | `spm-extended registry publish ...` or `mint run wgr1984/spm-extended ...` |
| Local build (dev)   | `.build/debug/spm-extended registry publish ...` |

**Next:** [Getting started](../getting-started/README.md) — configure registry and run your first publish.
