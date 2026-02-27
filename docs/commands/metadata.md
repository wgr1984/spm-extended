# registry metadata create

Create `Package.json` and `package-metadata.json` in your package directory **without publishing**. **Note:** `registry publish` creates these files automatically when they are missing, so you only need this command to preview, edit, or refresh (e.g. with `--overwrite`) metadata separately.

## Usage

**Plugin:**

```bash
swift package --disable-sandbox registry metadata create [options]
```

**CLI:**

```bash
spm-extended registry metadata create [options]
```

Requires `--disable-sandbox` when using the plugin (writes files in the package directory). See [Installation](../installation/README.md).

## What it does

1. **Package.json** — Generated from your `Package.swift` (equivalent to `swift package dump-package`).
2. **package-metadata.json** — Generated from:
   - Git config → author name and email
   - README.md → package description (first paragraph)
   - LICENSE file → license type and URL
   - Git remote → repository URL

Details: [Generated files](../reference/generated-files.md).

## Options

| Option | Description |
|--------|-------------|
| `--scratch-directory <dir>` | Directory for working files |
| `--overwrite` | Overwrite existing metadata files |
| `--vv`, `--verbose` | Verbose output |
| `-h`, `--help` | Show help |

## When to use it

- **Preview before publishing** — Generate files and inspect or edit before running publish (publish would create them anyway, but this lets you review first).
- **Edit metadata** — Change description, author, or URLs in `package-metadata.json`, then run [registry publish](publish.md) (it will use the existing files).
- **Refresh after README/LICENSE changes** — Run with `--overwrite` so generated fields are up to date; or skip and let publish regenerate when you next publish.
- **Manual workflows** — Produce the files once and use your own script or `swift package-registry publish` later.

You do **not** need to run this before every publish or in CI; publish creates the files automatically when missing.

## Examples

**Create metadata (no overwrite):**

```bash
cd MyPackage
swift package --disable-sandbox registry metadata create
```

**Verbose (see extraction steps):**

```bash
swift package --disable-sandbox registry metadata create --vv
```

**Overwrite after changing README or LICENSE:**

```bash
swift package --disable-sandbox registry metadata create --overwrite
```

**Two-step: create → edit → publish:**

```bash
swift package --disable-sandbox registry metadata create
# Edit package-metadata.json in your editor
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

## See also

- [registry publish](publish.md) — Publishes and can generate metadata if files are missing.
- [Generated files](../reference/generated-files.md) — Contents of Package.json and package-metadata.json.
- [Release and publish workflow](../workflows/release-and-publish.md) — Optional use of metadata create when you want to edit before publishing.
