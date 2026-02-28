# registry verify

Verify a package release: fetch release metadata, report signing info, and optionally the package manifest (Package.swift) and its alternate Swift tools versions. Uses the [Swift Package Registry spec](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md) (sections 4.2 and 4.3). Does **not** perform cryptographic signature verification; that is done by SwiftPM when resolving with configured trust.

## Usage

**Plugin:**

```bash
swift package --disable-sandbox registry verify <package-id> <version> [options]
```

**CLI:**

```bash
spm-extended registry verify <package-id> <version> [options]
```

Requires network access; use `--disable-sandbox` when using the plugin.

## Arguments

| Argument       | Description                                  |
|----------------|----------------------------------------------|
| `<package-id>` | Package identifier in `scope.name` format    |
| `<version>`    | Version to verify                            |

## Options

| Option                    | Description                                                                 |
|---------------------------|-----------------------------------------------------------------------------|
| `--url`, `--registry-url` | Registry base URL (default: `https://packages.swift.org`)                   |
| `--json`                  | Output machine-readable JSON                                                |
| `--no-manifest`           | Skip fetching Package.swift and Link header alternates                     |
| `--verbose`, `--vv`       | Include metadata object dump                                               |
| `-h`, `--help`            | Show help                                                                   |

## What it checks

1. **Release metadata** — GET /{scope}/{name}/{version}: `id`, `version`, `resources` (source-archive with checksum).
2. **Signing** — If the source-archive resource has `signing`, reports `signatureFormat` (e.g. `cms-1.0.0`) and that the release is signed. No crypto verification here; SwiftPM does that on resolution.
3. **Metadata** — Reports presence of `metadata` and `publishedAt`.
4. **Manifest** — Unless `--no-manifest`: GET Package.swift; parses `Link` header for alternate manifests (Package@swift-X.swift and swift-tools-version).

Exit code is non-zero if the release is not found or required fields are missing.

## When to use it

- **After publishing** — Confirm the release appears and metadata/signing look correct (see [Release and publish](../workflows/release-and-publish.md)).
- **Before depending** — Check that a specific version exists and has expected metadata or signing.
- **CI** — Use `--json` to assert release availability and signing format.

## Examples

**Verify a release (default registry):**

```bash
swift package --disable-sandbox registry verify mona.LinkedList 1.1.1
```

**Verify with custom registry and JSON:**

```bash
swift package --disable-sandbox registry verify myorg.MyPackage 1.0.0 --url https://registry.example.com --json
```

**Verify metadata only (skip manifest fetch):**

```bash
swift package --disable-sandbox registry verify myorg.MyPackage 1.0.0 --no-manifest
```

## See also

- [registry list](list.md) — List available versions for a package.
- [Release and publish](../workflows/release-and-publish.md) — Flow that includes verify after publish.
