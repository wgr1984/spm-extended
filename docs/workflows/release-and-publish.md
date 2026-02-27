# Release and publish workflow

Full flow from “ready to release” to “published and verified”: run tests, optionally create or edit metadata, dry-run publish, then publish and verify. Use this when cutting a new version (e.g. after tagging).

## When to use it

- You’ve merged changes and tagged a version (e.g. `1.2.0`).
- You want to publish that version to your Swift package registry.
- You run this **locally** (or in CI; see [CI/CD](ci-cd.md)).

## Flow overview

1. **Test** — Ensure the package builds and tests pass.
2. **(Optional) Create or refresh metadata** — Only if you want to preview or edit `package-metadata.json` before publishing. Publish creates metadata automatically when missing, so you can skip this.
3. **Dry-run publish** — Generate metadata (if needed) and confirm the publish command would succeed, without uploading.
4. **Publish** — Run the real publish to the registry.
5. **Verify** — Confirm the package and version appear at the registry.

## Step-by-step (copy-paste)

Replace `myorg`, `MyPackage`, `1.2.0`, and `https://registry.example.com` with your values. Run from the **package root** (where `Package.swift` lives).

```bash
# 1. Ensure you're on the right tag/commit and tests pass
cd /path/to/MyPackage
git status
swift test

# 2. (Optional) Create or overwrite metadata, then edit if needed
swift package --disable-sandbox registry metadata create --overwrite
# Edit package-metadata.json if you want to change description, author, URLs

# 3. Dry run: prepare metadata and validate without publishing
swift package --disable-sandbox registry publish myorg.MyPackage 1.2.0 \
  --url https://registry.example.com \
  --dry-run

# 4. Publish
swift package --disable-sandbox registry publish myorg.MyPackage 1.2.0 \
  --url https://registry.example.com
```

If you use the **CLI** (Mint or local build), replace the `swift package --disable-sandbox registry ...` lines with `spm-extended registry ...` (same arguments).

## With a version tag

If you release by pushing a tag (e.g. `1.2.0`), you can derive the version in scripts:

```bash
VERSION=$(git describe --tags --abbrev=0)
swift package --disable-sandbox registry publish myorg.MyPackage "$VERSION" \
  --url https://registry.example.com
```

## With signing

If you publish with [create-signing](../commands/create-signing.md), create the certs once, then in the release flow use the same publish command with cert options:

```bash
# One-time: create CA and leaf cert
swift package --disable-sandbox registry create-signing --create-leaf-cert

# In your release flow (after tests, optional dry-run):
swift package --disable-sandbox registry publish myorg.MyPackage 1.2.0 \
  --url https://registry.example.com \
  --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \
  --private-key-path .swiftpm/signing/leaf.key.der
```

## See also

- [Getting started](../getting-started/README.md) — First-time registry config and first publish.
- [Commands: publish](../commands/publish.md) — All publish options.
- [Commands: metadata](../commands/metadata.md) — When to create or overwrite metadata.
- [CI/CD](ci-cd.md) — Automate this flow on tag push.
