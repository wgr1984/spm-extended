# Release process (this repository)

This document describes how to cut a new version of **SPM Extended** so that package users and Mint get a stable “latest” version.

## Why tags matter

- **Mint:** When users run `mint run wgr1984/spm-extended` (no version), Mint uses the **newest git tag** as the version. If there are no tags, Mint falls back to the `master` branch. This repo uses `main`, so without tags you get: `fatal: Remote branch master not found`. Creating a semver tag (e.g. `1.0.0`) fixes that.
- **Package dependency:** Users depend on `from: "1.0.0"` (or similar). They need a tag that matches that version.
- **Changelog:** Keeps users informed of what changed between versions.

## How Mint picks “latest version”

Mint resolves the package reference as follows:

1. If you specify a version (e.g. `mint run wgr1984/spm-extended@1.0.0` or `@main`), that ref is used.
2. If you omit the version, Mint uses the **newest tag** (by semver) from the remote. If there are **no tags**, it falls back to the **master** branch.

So for `mint run wgr1984/spm-extended` to work without `@main`, the repo must have at least one tag (e.g. `1.0.0`).

## Release steps

1. **Update CHANGELOG.md**
   - Move entries from `[Unreleased]` into a new section `[X.Y.Z] - YYYY-MM-DD`.
   - Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

2. **Update the version constant**
   - In `Sources/SPMExtendedCore/Version.swift`, set `AppVersion.current` to the new version string (e.g. `"1.0.0"`). This is what `spm-extended --version` and `swift package registry --version` display.

3. **Commit the changelog and version**
   ```bash
   git add CHANGELOG.md Sources/SPMExtendedCore/Version.swift
   git commit -m "Release X.Y.Z"
   ```

4. **Create and push an annotated tag**
   ```bash
   git tag -a 1.0.0 -m "Release 1.0.0"
   git push origin 1.0.0
   ```
   Use the same version number as in CHANGELOG (e.g. `1.0.0`).

5. **(Optional) Create a GitHub Release**
   - On GitHub: **Releases → Draft a new release**.
   - Choose the tag you just pushed.
   - Copy the relevant section from CHANGELOG into the release notes.
   - Publish.

After the tag is pushed:

- `mint run wgr1984/spm-extended` will use that tag (and future tags for “latest”).
- Users can depend on `.package(url: "...", from: "1.0.0")` (or exact version) and get that tag.

## Using the main branch

To run or install from the `main` branch explicitly (e.g. when there are no tags yet, or to get the latest unreleased changes), use `@main`:

```bash
mint run wgr1984/spm-extended@main ...
mint install wgr1984/spm-extended@main
```

See [Installation](installation/README.md) and [Troubleshooting](troubleshooting/README.md#mint-remote-branch-master-not-found).
