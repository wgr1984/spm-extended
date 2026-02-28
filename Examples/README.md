# Examples

This directory contains a sample Swift package and a local [OpenSPMRegistry](https://github.com/wgr1984/OpenSPMRegistry) setup so you can test the SPM Extended Plugin commands without a remote registry.

## Prerequisites

- **Swift** (for the sample package and plugin)
- **Go** (to run OpenSPMRegistry with `go run`)

## Quick start

1. **Initialize the OpenSPMRegistry submodule** (first time or after clone):
   ```bash
   make submodule
   ```
   Or from the repo root: `make -C Examples submodule`

2. **Start the local registry** (listens on http://localhost:12345):
   ```bash
   make registry-start
   ```
   The Makefile runs the registry over HTTP so no TLS or certificate setup is needed.

3. **Run plugin tests** (from `Examples/` or `make -C Examples <target>` from repo root):
   - `make test-metadata` – create `Package.json` and `package-metadata.json` in SamplePackage
   - `make test-create-signing` – create a package-signing CA in SamplePackage (`.swiftpm/signing`)
   - `make test-publish-signing` – create signing certs and publish SamplePackage with signing (registry must be running)
   - `make test-dry-run` – prepare publish without uploading
   - `make test-publish` – publish SamplePackage to the local registry (registry must be running)
   - `make test-outdated` – list dependency updates: starts the registry, publishes **DemoLib** 1.0.0 and 1.1.0, resolves (SamplePackage uses 1.0.0), then runs `swift package outdated --registry-url http://localhost:12345` so you see **Current** vs **Available** (e.g. `sample.DemoLib` 1.0.0 → 1.1.0, `swift-numerics` 1.0.0 → 1.1.1). Use `--registry-url` when your registry pins have no URL in Package.resolved (e.g. local registry).
   - `make test-list` – list available versions for a package: starts the registry, publishes **DemoLib** 1.0.0 and 1.1.0, then runs `registry list sample.DemoLib --url http://localhost:12345`.
   - `make test-verify` – verify releases: **DemoLib** 1.0.0/1.1.0 (unsigned), 1.2.0 (signed), then 1.3.0 (with manifest alternates: `Package@swift-5.5.swift`). Run with registry + publish-demo; 1.3.0 shows manifest alternates in verify output.

4. **Stop the registry** when finished:
   ```bash
   make registry-stop
   ```

## Layout

- **SamplePackage/** – Minimal Swift package that depends on the plugin via `path: "../.."`, on **sample.DemoLib** from the local registry (for the outdated demo), and on **swift-numerics** from Git (pinned to 1.0.0 so outdated shows 1.1.1 available). Use it to try `registry metadata create`, `registry create-signing`, `registry publish`, and `swift package outdated`.
- **DemoLib/** – Minimal Swift package published to the local registry at 1.0.0 and 1.1.0 so `make test-outdated` can show an update (1.0.0 → 1.1.0).
- **OpenSPMRegistry/** – Git submodule; run with `go run main.go -v` from that directory (or use `make registry-start`). The Makefile uses port 12345 and HTTP via `config.local.yml`.
- **Makefile** – Targets for submodule init, starting/stopping the registry, publishing DemoLib, and running the plugin commands above.

## All Makefile targets

Run `make help` (or `make -C Examples help` from repo root) to list targets and usage.
