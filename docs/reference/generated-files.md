# Generated files

SPM Extended creates two files in your package directory when you run [registry metadata create](../commands/metadata.md) or [registry publish](../commands/publish.md) (publish generates them if missing). The registry includes both in the source archive when you publish. This page describes what they are and how they’re produced.

## Package.json

**What it is:** Your package manifest in JSON form — the same content as `swift package dump-package`.

**How it’s created:** The plugin runs `swift package dump-package` and writes the result to `Package.json` in the package root.

**Why it matters:** Registries use this file when building the source archive. [Package Collections](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md) (SE-0291) rely on it for discovery and presentation. Without `Package.json` in the archive:

- Publishing can still succeed
- But the package **won’t appear** in package collections
- Discoverability in Xcode and SPM is reduced

**Typical contents:**

- Package name
- Products and targets
- Platform requirements
- Swift tools version
- Dependencies

Example (structure only):

```json
{
  "name": "YourPackage",
  "platforms": [...],
  "products": [...],
  "targets": [...],
  "toolsVersion": {...}
}
```

You don’t edit `Package.json` by hand; it’s derived from `Package.swift`. Regenerate it with `registry metadata create` (or by running publish again).

---

## package-metadata.json

**What it is:** Extra metadata for the registry: author, description, license, repository and readme URLs. Used for display and collection metadata.

**How it’s created:** If the file doesn’t exist (or you run [registry metadata create](../commands/metadata.md)), the plugin generates it by extracting:

| Field / source | Used for |
|----------------|----------|
| Git config (`user.name`, `user.email`) | Author name and email |
| README.md (first paragraph) | Description |
| LICENSE file | License type and URL |
| Git remote (e.g. `origin`) | Repository URL (and often readme URL) |

**Typical contents:**

```json
{
  "author": {
    "name": "John Doe",
    "email": "john@example.com"
  },
  "description": "A Swift package for...",
  "licenseType": "MIT",
  "licenseURL": "https://github.com/org/repo/blob/main/LICENSE",
  "repositoryURL": "https://github.com/org/repo",
  "readmeURL": "https://github.com/org/repo/blob/main/README.md"
}
```

You can **edit** `package-metadata.json` after generation (e.g. to refine the description or add organization). The next publish will use the existing file unless you pass `--metadata-path` to point at another file or delete it so it’s regenerated.

**When to regenerate:** After changing README, LICENSE, or git config, run `registry metadata create --overwrite` so the generated metadata stays in sync. See [Daily development](../workflows/daily-development.md).

---

## Where they live and when they’re used

- **Location:** Both files are created in the **package root** (the directory that contains `Package.swift`).
- **Publish:** When you run `registry publish`, the registry client builds the source archive and includes these files. You don’t need to ship them elsewhere; the plugin and registry handle that.
- **Metadata-only:** Use [registry metadata create](../commands/metadata.md) when you want the files without publishing (e.g. to preview, edit, or use in CI before a later publish step).

## See also

- [Commands: metadata create](../commands/metadata.md) — Create or overwrite the files.
- [Commands: publish](../commands/publish.md) — How publish uses or generates them.
- [Release and publish workflow](../workflows/release-and-publish.md) — Where they fit in a release.
