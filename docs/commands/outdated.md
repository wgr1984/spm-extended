# outdated

List the **current** (resolved) version and **available** versions for each dependency. Works for packages coming from a **registry** or from **Git**; it ignores version constraints in `Package.swift` and shows what versions exist. Useful for deciding when to upgrade dependencies.

## Usage

**Plugin:**

```bash
swift package resolve   # ensure Package.resolved exists
swift package --disable-sandbox outdated [options]
```

**CLI:**

```bash
swift package resolve
spm-extended outdated [options]
```

Requires `--disable-sandbox` when using the plugin (network access to registries and Git). `Package.resolved` must exist — run `swift package resolve` first if needed.

## Options

| Option | Description |
|--------|-------------|
| `--json` | Machine-readable JSON output |
| `--verbose`, `--vv` | Show all available versions per package (default: latest only) |
| `-h`, `--help` | Show help |

## What it does

- Reads `Package.resolved`.
- For each dependency: asks the registry API or runs `git ls-remote --tags` to get available versions.
- Prints current vs available (e.g. “1.0.0 → 1.1.1”) regardless of the version range in `Package.swift`.

## When to use it

- **Weekly or before upgrading** — See which dependencies have newer versions. See [Daily development](../workflows/daily-development.md).
- **CI or scripts** — Use `--json` for automated checks or reports.

## Examples

**List current and available versions (default: latest available per package):**

```bash
cd MyPackage
swift package resolve
swift package --disable-sandbox outdated
```

**All versions per package:**

```bash
swift package --disable-sandbox outdated --verbose
```

**JSON (for scripts or CI):**

```bash
swift package --disable-sandbox outdated --json
```

**CLI from another directory:**

```bash
spm-extended --package-path /path/to/MyPackage outdated
```

## See also

- [Daily development workflow](../workflows/daily-development.md) — When to run outdated in your dev flow.
- [Quick reference](../reference/quick-reference.md) — Command summary.
