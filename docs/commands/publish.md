# registry publish

Publish your package to a Swift package registry. The command generates `Package.json` and `package-metadata.json` if they are missing, then runs the underlying registry publish. Supports dry-run, custom metadata, and signing.

## Usage

**Plugin:**

```bash
swift package --disable-sandbox registry publish <package-id> <package-version> [options]
```

**CLI:**

```bash
spm-extended registry publish <package-id> <package-version> [options]
```

- **package-id** — Registry package identifier in the form `scope.name` (e.g. `myorg.MyPackage`).
- **package-version** — Version to publish (e.g. `1.0.0`).

Requires `--disable-sandbox` when using the plugin. See [Getting started](../getting-started/README.md) for a minimal example.

## Options

**Registry:**

| Option | Description |
|--------|-------------|
| `--url <url>` | Registry base URL (required for publish) |
| `--metadata-path <path>` | Use this file instead of auto-generated `package-metadata.json` |
| `--allow-insecure-http` | Allow non-HTTPS registry URLs *(Swift tools 6.x+ only)* |

**Signing:** See [create-signing](create-signing.md) for generating certs.

| Option | Description |
|--------|-------------|
| `--signing-identity <id>` | System signing identity name |
| `--private-key-path <path>` | Path to private key (DER) |
| `--cert-chain-paths <paths...>` | Certificate chain (e.g. leaf then CA) |

**Other:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Generate metadata only; do not publish |
| `--vv` | Verbose output |
| `-h`, `--help` | Show help |

## Examples

**Basic publish (metadata generated if missing):**

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

**Dry run (prepare only, no upload):**

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com --dry-run
```

**Two-step: create metadata, edit, then publish:**

```bash
swift package --disable-sandbox registry metadata create
# Edit package-metadata.json
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

**Publish with custom metadata file:**

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com --metadata-path custom-metadata.json
```

**Publish with signing (after [create-signing](create-signing.md)):**

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com \
  --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \
  --private-key-path .swiftpm/signing/leaf.key.der
```

Or with a system identity:

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com \
  --signing-identity "My Developer Certificate" \
  --cert-chain-paths cert.der
```

## See also

- [Getting started](../getting-started/README.md) — First publish and verify.
- [registry metadata create](metadata.md) — Create metadata without publishing.
- [registry create-signing](create-signing.md) — Create CA and leaf certs for signing.
- [Release and publish workflow](../workflows/release-and-publish.md) — Full release flow.
