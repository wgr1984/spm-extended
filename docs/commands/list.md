# registry list

List available versions for a package from a Swift package registry. Uses the registry API (GET /{scope}/{name}) per the [Swift Package Registry spec](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md).

## Usage

**Plugin:**

```bash
swift package --disable-sandbox registry list <package-id> [options]
```

**CLI:**

```bash
spm-extended registry list <package-id> [options]
```

Requires network access; use `--disable-sandbox` when using the plugin.

## Arguments

| Argument       | Description                                      |
|----------------|--------------------------------------------------|
| `<package-id>` | Package identifier in `scope.name` format (e.g. `mona.LinkedList`) |

## Options

| Option                    | Description                                                                 |
|---------------------------|-----------------------------------------------------------------------------|
| `--url`, `--registry-url` | Registry base URL (default: `https://packages.swift.org`)                   |
| `--json`                  | Output machine-readable JSON                                                |
| `--include-unavailable`   | Include releases that have a problem (e.g. removed); default is available only |
| `-h`, `--help`            | Show help                                                                   |

## When to use it

- **See what versions exist** — Before adding or updating a dependency, list versions for a package.
- **Scripts or CI** — Use `--json` to parse versions programmatically.
- **Debugging** — Use `--include-unavailable` to see removed or problematic releases.

## Examples

**List versions (default registry):**

```bash
swift package --disable-sandbox registry list mona.LinkedList
```

**List with custom registry and JSON:**

```bash
swift package --disable-sandbox registry list myorg.MyPackage --url https://registry.example.com --json
```

**Include unavailable releases:**

```bash
swift package --disable-sandbox registry list myorg.MyPackage --include-unavailable
```

## See also

- [registry verify](verify.md) — Verify a specific release (metadata, signing, manifest).
- [outdated](outdated.md) — List current vs available versions for all dependencies in Package.resolved.
