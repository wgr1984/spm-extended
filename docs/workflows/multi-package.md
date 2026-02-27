# Multi-package / monorepo workflow

When you have multiple Swift packages (e.g. in a monorepo or workspace), publish them in **dependency order**: packages that others depend on first, then the rest. You can do this manually or with a script or Makefile.

## When to use it

- You maintain several packages (e.g. `SharedLib`, `NetworkLib`, `App`) where later ones depend on earlier ones.
- You want to publish all of them to the same registry, often with the same version (e.g. `1.0.0`).

## Dependency order

Publish **leaf** packages first (no internal dependencies), then packages that depend on them. Otherwise the registry may not yet have the dependency when you publish a package that declares it.

Example order for:

- `SharedUtilities` (no internal deps)
- `NetworkLayer` (depends on SharedUtilities)
- `AppCore` (depends on SharedUtilities, NetworkLayer)

Publish in that order: SharedUtilities → NetworkLayer → AppCore.

**Note:** `registry publish` creates `Package.json` and `package-metadata.json` automatically when missing, so a separate `registry metadata create` step is not needed unless you want to pre-generate with `--overwrite` or edit metadata before publishing.

## Script: publish multiple packages

Example script that publishes a list of packages in order. Run from the **parent directory** that contains each package as a subdirectory.

```bash
#!/bin/bash
# publish-all.sh

set -e

PACKAGES=(PackageA PackageB PackageC)
SCOPE="mycompany"
VERSION="${1:-1.0.0}"
REGISTRY_URL="${2:-https://registry.example.com}"

for pkg in "${PACKAGES[@]}"; do
  echo "Publishing $pkg..."
  cd "$pkg"
  swift package --disable-sandbox registry publish "${SCOPE}.${pkg}" "$VERSION" --url "$REGISTRY_URL"
  cd ..
  echo "Done: $pkg"
done
echo "All packages published."
```

Usage:

```bash
chmod +x publish-all.sh
./publish-all.sh 1.0.0 https://registry.example.com
```

## Manual: workspace with shared dependencies

If packages live in subdirectories of a workspace and depend on each other, publish one by one in dependency order.

```bash
SCOPE="mycompany"
VERSION="1.0.0"
REGISTRY_URL="https://registry.example.com"

# 1. Shared utilities (no internal deps)
cd SharedUtilities
swift package --disable-sandbox registry publish ${SCOPE}.SharedUtilities $VERSION --url $REGISTRY_URL
cd ..

# 2. Network layer (depends on SharedUtilities)
cd NetworkLayer
swift package --disable-sandbox registry publish ${SCOPE}.NetworkLayer $VERSION --url $REGISTRY_URL
cd ..

# 3. App core (depends on both)
cd AppCore
swift package --disable-sandbox registry publish ${SCOPE}.AppCore $VERSION --url $REGISTRY_URL
cd ..
```

Configure the registry and log in once before the first publish (see [Getting started](../getting-started/README.md)).

## Makefile example

You can drive the same flow from a Makefile at the repo root.

```makefile
VERSION := $(shell git describe --tags --abbrev=0)
SCOPE := mycompany
REGISTRY_URL := https://registry.example.com
PACKAGES := SharedUtilities NetworkLayer AppCore

.PHONY: publish-all publish-% test

publish-all: test
	@for pkg in $(PACKAGES); do $(MAKE) publish-$$pkg; done

publish-%:
	cd $* && swift package --disable-sandbox registry publish $(SCOPE).$* $(VERSION) --url $(REGISTRY_URL)

test:
	@for pkg in $(PACKAGES); do (cd $$pkg && swift test); done
```

Run from the directory that contains the package subdirs:

```bash
make publish-all
```

## See also

- [Commands: publish](../commands/publish.md) — Publish options.
- [Commands: metadata](../commands/metadata.md) — Create or edit metadata separately when needed (e.g. `--overwrite`).
- [Release and publish](release-and-publish.md) — Single-package release flow.
