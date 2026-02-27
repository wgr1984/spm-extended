# Daily development workflow

During normal development you don’t publish every day. This page suggests **when** to run `outdated`, `metadata create`, and `clean-cache` so they fit into your flow without duplicating the full release process.

## outdated — check for dependency updates

**What it does:** Shows current vs available versions for each dependency (registry and Git), ignoring `Package.swift` version constraints. See [outdated](../commands/outdated.md).

**When to run:**

- **Periodically** (e.g. weekly) to see which dependencies have newer versions.
- **Before upgrading** a dependency — run `outdated` to see the latest available, then update `Package.swift` and run `swift package update` if desired.
- **In CI** (optional) — e.g. `outdated --json` to produce a report or fail if something is too far behind.

**Example:**

```bash
cd MyPackage
swift package resolve
swift package --disable-sandbox outdated
# Or: spm-extended outdated
```

Use `--verbose` to see all versions per package, or `--json` for scripts.

---

## metadata create — when to create or refresh metadata

**What it does:** Creates or overwrites `Package.json` and `package-metadata.json` without publishing. See [metadata](../commands/metadata.md).

**When to run:**

- **Before your first publish (optional)** — Run once to preview or edit `package-metadata.json` (description, author, URLs) before publishing. Not required: `registry publish` creates metadata automatically when missing.
- **After changing README or LICENSE** — Run with `--overwrite` to refresh the generated description and license info in `package-metadata.json` before the next publish (or just publish—it will regenerate if needed).

You don’t need to run this in CI; `registry publish` creates the files automatically. See [CI/CD](ci-cd.md).

**Example:**

```bash
# First time or after editing README/LICENSE
swift package --disable-sandbox registry metadata create --overwrite
```

---

## clean-cache — when to clear caches

**What it does:** Cleans SPM registry caches and fingerprints so the next resolve re-fetches from the registry. See [clean-cache](../commands/clean-cache.md).

**When to run:**

- **Resolution or fingerprint issues** — After changing registry URL, switching registries, or seeing odd resolution/verification errors, clean then run `swift package resolve` again.
- **CI / clean slate** — In a job that should not rely on a previous run’s cache, use `--local` or `--all` before resolve.

You don’t need to run this routinely; only when something seems stuck or you’ve changed registry/signing setup.

**Example:**

```bash
# This package only (needs --disable-sandbox with plugin)
swift package --disable-sandbox registry clean-cache --local

# User-level cache (needs --disable-sandbox with plugin)
swift package --disable-sandbox registry clean-cache --global
```

---

## Summary

| Command | Typical use in daily dev |
|--------|---------------------------|
| **outdated** | Weekly or before upgrading deps; optional in CI. |
| **metadata create** | Optional: preview/edit before first publish, or refresh with `--overwrite` after README/LICENSE changes. Not required—publish creates metadata automatically. |
| **clean-cache** | When resolve/registry/signing behaves oddly or in CI for a clean run. |

For the full release sequence (test → optional metadata edit → dry-run → publish → verify), see [Release and publish](release-and-publish.md).
