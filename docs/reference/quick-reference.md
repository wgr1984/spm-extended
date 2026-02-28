# Quick reference

Short summary of commands and common options. For full details and examples, use the linked command docs.

## Commands

| Command | Description |
|--------|--------------|
| `swift package --disable-sandbox registry metadata create` | Create Package.json and package-metadata.json (no publish). [Details](../commands/metadata.md) |
| `swift package --disable-sandbox registry publish <id> <ver>` | Publish package to registry. [Details](../commands/publish.md) |
| `swift package --disable-sandbox registry create-signing` | Create CA and optionally leaf cert for signing. [Details](../commands/create-signing.md) |
| `swift package registry clean-cache (--local \| --global \| --all)` | Clean registry caches/fingerprints. [Details](../commands/clean-cache.md) |
| `swift package --disable-sandbox registry list <id>` | List available versions for a package. [Details](../commands/list.md) |
| `swift package --disable-sandbox registry verify <id> <ver>` | Verify release metadata, signing, manifest. [Details](../commands/verify.md) |
| `swift package --disable-sandbox outdated` | List current vs available dependency versions. [Details](../commands/outdated.md) |

**CLI (Mint / local build):** Replace `swift package --disable-sandbox registry ...` with `spm-extended registry ...`, and `swift package --disable-sandbox outdated` with `spm-extended outdated`.

## Arguments (publish)

| Argument | Description |
|----------|-------------|
| `<package-id>` | Registry package identifier: `scope.name` (e.g. `myorg.MyPackage`) |
| `<version>` | Version to publish (e.g. `1.0.0`) |

## Common options

| Option | Where | Description |
|--------|--------|-------------|
| `--disable-sandbox` | Plugin only | **Required** for commands that write files or use network (metadata create, publish, create-signing, clean-cache --global, list, verify, outdated) |
| `--url <url>` | publish | Registry base URL |
| `--dry-run` | publish | Prepare metadata only; do not publish |
| `--overwrite` | metadata create, create-signing | Overwrite existing files |
| `--vv`, `--verbose` | metadata create, publish, create-signing, verify, outdated | Verbose output |
| `--json` | list, verify, outdated | Machine-readable output |
| `--metadata-path <path>` | publish | Use this file instead of package-metadata.json |
| `--local` / `--global` / `--all` | clean-cache | Scope of cache to clean (exactly one required) |

## Signing (publish)

| Option | Description |
|--------|-------------|
| `--signing-identity <id>` | System signing identity |
| `--private-key-path <path>` | Private key (DER) |
| `--cert-chain-paths <paths...>` | Certificate chain (e.g. leaf then CA) |

See [create-signing](../commands/create-signing.md) to generate certs.

## Help

```bash
swift package registry --help
swift package registry publish --help
swift package registry metadata create --help
swift package registry create-signing --help
swift package registry clean-cache --help
swift package registry list --help
swift package registry verify --help
swift package outdated --help
```

With CLI: `spm-extended --help`, `spm-extended registry --help`, etc.
