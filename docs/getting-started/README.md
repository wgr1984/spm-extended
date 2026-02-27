# Getting started

This page walks through configuring the registry once and publishing your package for the first time. For installation options, see [Installation](../installation/README.md).

## Step 1: Open your package

Navigate to the root of your Swift package (the directory that contains `Package.swift`):

```bash
cd /path/to/YourAwesomePackage
```

Ensure the package builds and tests pass:

```bash
swift build
swift test
```

## Step 2: Configure the registry (one-time)

Point Swift at your registry and log in so publish can upload. Replace `https://registry.example.com` with your registry URL.

```bash
swift package-registry set https://registry.example.com
swift package-registry login
```

Follow the prompts (e.g. token or credentials) as required by your registry. You only need to do this once per machine (or per CI environment).

## Step 3: Publish with the plugin

Publish using the **package identifier** (`scope.PackageName`) and the **version** you are releasing. The plugin will generate `Package.json` and `package-metadata.json` if needed, then call the registry publish command.

**Plugin (from package directory):**

```bash
swift package --disable-sandbox registry publish myscope.YourAwesomePackage 1.0.0 --url https://registry.example.com
```

**CLI (Mint or local build):**

```bash
spm-extended registry publish myscope.YourAwesomePackage 1.0.0 --url https://registry.example.com
```

Replace:

- `myscope` — your registry scope (e.g. GitHub org or company name).
- `YourAwesomePackage` — your package name (must match the `name` in `Package.swift`).
- `1.0.0` — the version to publish (often a git tag).
- `https://registry.example.com` — your registry base URL.

**Example output:**

```
🚀 SPM Extended Plugin - Registry Publish
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Package: YourAwesomePackage
Directory: /path/to/YourAwesomePackage

📝 Step 1: Generating Package.json...
   ✓ Package.json created

📝 Step 2: Generating package-metadata.json...
   ✓ package-metadata.json created

🚀 Step 3: Publishing to registry...
   ✓ Published successfully!

✅ Package published to registry!
```

The plugin creates `Package.json` and `package-metadata.json` in your package directory; the registry includes them in the source archive. See [Generated files](../reference/generated-files.md) for details.

## What’s next?

- **[Release and publish workflow](../workflows/release-and-publish.md)** — Full flow: test, optional metadata edit, dry-run, publish.
- **[Commands: Publish](../commands/publish.md)** — All publish options (dry-run, signing, custom metadata).
- **[Commands: Metadata](../commands/metadata.md)** — Create or overwrite metadata without publishing.
- **[Generated files](../reference/generated-files.md)** — What `Package.json` and `package-metadata.json` contain and how they’re created.

If something fails, see [Troubleshooting](../troubleshooting/README.md).
