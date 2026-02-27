# Troubleshooting

Common issues and fixes when using SPM Extended. For installation and first-time setup, see [Installation](../installation/README.md) and [Getting started](../getting-started/README.md).

## Permission prompt

When you run a plugin command that writes to the package directory (e.g. metadata create or publish), Swift may prompt:

```
Plugin '...' wants permission to write to the package directory.
Stated reason: Generate Package.json and create source archive.
Allow this plugin to write to the package directory? (yes/no)
```

> **Important:** Even after approving, some operations may still fail due to Swift plugin sandbox restrictions (e.g. network access, certain file or directory access). We recommend **disabling the sandbox** (`--disable-sandbox`) for reliable use, or using the **standalone CLI** (`spm-extended` via Mint or a local build), which is not sandboxed.

**Fix:** Type `yes` and press Enter to allow. To avoid the prompt in scripts or CI, pass `--disable-sandbox`:

```bash
swift package --disable-sandbox registry metadata create
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
```

See [Installation](../installation/README.md) for why `--disable-sandbox` is needed.

---

## Command not found

**Symptom:** Swift doesn’t recognize `registry` or the plugin commands (e.g. “unknown command”).

**Causes and fixes:**

1. **Plugin not resolved** — If the plugin is added as a dependency, ensure resolution has run:
  ```bash
   swift package resolve
  ```
2. **Wrong directory** — Run from the **package root** (the directory that contains `Package.swift`).
3. **Using CLI** — If you use the standalone CLI (Mint or local build), run `spm-extended registry ...` from the package directory, and ensure `spm-extended` is on your PATH or use the full path to the binary.

---

## Invalid manifest

**Symptom:** Metadata create or publish fails with errors about the manifest or “dump-package”.

**Cause:** `Package.swift` has syntax errors or isn’t valid.

**Fix:**

```bash
swift build
```

Fix any reported errors in `Package.swift`. Then rerun the plugin command. Ensure the first line of `Package.swift` specifies a valid tools version, e.g. `// swift-tools-version: 5.9`.

---

## Publishing failed

**Symptom:** `swift package-registry publish` (invoked by the plugin) fails — e.g. auth error, 4xx/5xx, or “could not publish”.

**Fixes:**

1. **Configure and log in to the registry:**
  ```bash
   swift package-registry set https://registry.example.com
   swift package-registry login
  ```
   Use the same registry URL as in your publish command (`--url`).
2. **Check credentials** — Ensure the token or credentials used by `swift package-registry login` are valid and have permission to publish to the given scope/package.
3. **Verify registry URL** — Publish must use the same base URL as the one set with `swift package-registry set`.
4. **Dry run first** — See whether metadata generation and the command line are correct without uploading:
  ```bash
   swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com --dry-run --vv
  ```

See [Getting started](../getting-started/README.md) for a minimal publish flow and [Commands: publish](../commands/publish.md) for options.

---

## dump-package or archive failures

**Symptom:** Errors about “dump-package” or creating an archive.

- **dump-package fails** — Usually an invalid `Package.swift`. Run `swift build` and fix manifest errors.
- **Archive / archive-source** — Requires a Swift toolchain that supports the registry publish flow (Swift 5.6+ for archive-source). Update the toolchain if needed.

---

## Resolution or cache issues after registry changes

**Symptom:** After changing registry URL or signing setup, resolution or verification behaves oddly.

**Fix:** Clean caches, then resolve again. See [Commands: clean-cache](../commands/clean-cache.md).

```bash
# This package only
swift package registry clean-cache --local

# User-level (plugin: add --disable-sandbox)
swift package --disable-sandbox registry clean-cache --global

swift package resolve
```

---

## See also

- [Installation](../installation/README.md) — Setup and `--disable-sandbox`.
- [Getting started](../getting-started/README.md) — First publish and verify.
- [Quick reference](../reference/quick-reference.md) — Command and option summary.

