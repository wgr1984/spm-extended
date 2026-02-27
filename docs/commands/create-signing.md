# registry create-signing

Create a package-signing Certificate Authority (CA) and optionally a leaf certificate and key for use with [registry publish](publish.md). You can add the CA to Swift PM’s global or local registry settings so packages signed with it are trusted. Certificate generation uses pure Swift (CryptoKit); no external tools are required.

## Usage

**Plugin:**

```bash
swift package --disable-sandbox registry create-signing [options]
```

**CLI:**

```bash
spm-extended registry create-signing [options]
```

Requires `--disable-sandbox` when using the plugin (writes key and certificate files).

## Options

| Option | Description |
|--------|-------------|
| `--output-dir <path>` | Where to write files (default: `.swiftpm/signing`) |
| `--ca-dir <path>` | Use existing CA from path (`ca.key`, `ca.der`); requires `--create-leaf-cert` |
| `--ca-cn <name>` | CA subject common name (default: `Swift Package Signing CA`) |
| `--leaf-cn <name>` | Leaf cert subject common name (default: `Swift Package Signing`) |
| `--create-leaf-cert` | Also create leaf cert and key (signed by new or `--ca-dir` CA) |
| `--validity-years <n>` | Validity in years (default: 10, range: 1–30) |
| `--global` | Add CA to global registry settings (`~/.swiftpm/security`) |
| `--local` | Add CA to local project (`.swiftpm/security`) |
| `--overwrite` | Replace existing files in output directory |
| `--on-unsigned <policy>` | For unsigned packages: `error`, `prompt`, `warn`, `silentAllow` (with `--global`/`--local`) |
| `--on-untrusted-cert <policy>` | For untrusted cert: `error`, `prompt`, `warn`, `silentAllow` (with `--global`/`--local`) |
| `--cert-expiration <check>` | `enabled` or `disabled` (with `--global`/`--local`) |
| `--cert-revocation <check>` | `strict`, `allowSoftFail`, `disabled` (with `--global`/`--local`) |
| `--vv`, `--verbose` | Verbose output |
| `-h`, `--help` | Show help |

## Typical flow

**1. Create CA and leaf cert (once per package or shared CA):**

```bash
cd MyPackage
swift package --disable-sandbox registry create-signing --create-leaf-cert
```

This creates under `.swiftpm/signing/` (or `--output-dir`):

- `ca.key`, `ca.der` — CA key and certificate
- `leaf.key.der`, `leaf.der` — Leaf key and certificate (for publishing)

**2. Publish with the leaf cert and key:**

```bash
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com \
  --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \
  --private-key-path .swiftpm/signing/leaf.key.der
```

**3. (Optional) Trust the CA for verification:**

So that consumers trust packages signed with this CA:

```bash
swift package --disable-sandbox registry create-signing --global
# or --local for this package only
```

Or create certs first, then add CA to trust:

```bash
swift package --disable-sandbox registry create-signing --create-leaf-cert
swift package --disable-sandbox registry create-signing --global
```

## Examples

**CA only (e.g. for a shared org CA):**

```bash
swift package --disable-sandbox registry create-signing
```

**CA + leaf, then add CA to global trust:**

```bash
swift package --disable-sandbox registry create-signing --create-leaf-cert --global
```

**Use existing CA to issue a new leaf:**

```bash
swift package --disable-sandbox registry create-signing --ca-dir /path/to/ca --create-leaf-cert
```

## See also

- [registry publish](publish.md) — Signing options and how to pass cert chain and key.
- [Troubleshooting](../troubleshooting/README.md) — If signing or verification fails.
