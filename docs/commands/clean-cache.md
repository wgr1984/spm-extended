# registry clean-cache

Clean Swift Package Manager’s registry-related caches and fingerprint data. After cleaning, the next `swift package resolve` will re-fetch and re-verify packages from the registry. Use this when you see stale or inconsistent resolution, or after changing registry or signing configuration.

## Usage

**Plugin:**

```bash
swift package registry clean-cache (--local | --global | --all)
```

For `--global` (or if you get permission errors), use `--disable-sandbox`:

```bash
swift package --disable-sandbox registry clean-cache --global
```

**CLI:**

```bash
spm-extended registry clean-cache (--local | --global | --all)
```

You must pass exactly one of `--local`, `--global`, or `--all`.

## Options

| Option | Description |
|--------|-------------|
| `--local` | Clean only this package: `.build` and `.swiftpm` cache/fingerprints in the package directory |
| `--global` | Clean user-level: `~/.swiftpm/cache` and `~/.swiftpm/security/fingerprints` |
| `--all` | Clean both global and local (current package) |
| `-h`, `--help` | Show help |

## When to use it

- **Stale or wrong resolution** — After a registry or package update, clean so the next resolve uses fresh data.
- **Fingerprint / verification issues** — Cleaning global fingerprints can resolve trust or checksum errors.
- **CI or clean slate** — Use `--local` or `--all` in a job to avoid carrying over cache from a previous run.

## Examples

**Clean only this package (no sandbox needed for --local):**

```bash
cd MyPackage
swift package registry clean-cache --local
```

**Clean global caches and fingerprints:**

```bash
swift package --disable-sandbox registry clean-cache --global
```

**Clean everything (current package + user cache):**

```bash
swift package --disable-sandbox registry clean-cache --all
```

Then resolve again:

```bash
swift package resolve
```

## See also

- [Daily development workflow](../workflows/daily-development.md) — When to run clean-cache in day-to-day dev.
- [Troubleshooting](../troubleshooting/README.md) — Resolution and publish failures.
