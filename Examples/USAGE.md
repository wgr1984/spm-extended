# Usage Examples

This document provides real-world examples of using the SPM Extended Plugin.

## Table of Contents

- [Metadata Creation](#metadata-creation)
- [Basic Package Publishing](#basic-package-publishing)
- [Publishing to OpenSPMRegistry](#publishing-to-openspmregistry)
- [CI/CD Integration](#cicd-integration)
- [Multiple Packages Workflow](#multiple-packages-workflow)
- [Troubleshooting](#troubleshooting)

## Metadata Creation

### Example 1: Create Metadata Files Only

```bash
# Navigate to your package
cd MyAwesomeLibrary

# Create Package.json and package-metadata.json
swift package --disable-sandbox registry metadata create

# Expected output:
# 🚀 SPM Extended Plugin - Registry Metadata Create
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package: MyAwesomeLibrary
# 
# 📝 Step 1: Generating Package.json...
#    ✓ Package.json created
# 
# 📝 Step 2: Generating package-metadata.json...
#    ✓ Extracted author from git config
#    ✓ Extracted description from README.md
#    ✓ Extracted license information
#    ✓ Extracted repository URL from git
#    ✓ package-metadata.json created
# 
# ✅ Metadata files created successfully!

# Verify what was created
ls -la | grep -E "Package.json|package-metadata.json"
# -rw-r--r--  1 user  staff   1234 Jan 21 10:00 Package.json
# -rw-r--r--  1 user  staff    456 Jan 21 10:00 package-metadata.json

# Inspect the files
cat Package.json | jq .
cat package-metadata.json | jq .
```

### Example 2: Create Metadata with Verbose Output

```bash
cd MyPackage

# Use verbose mode to see detailed extraction process
swift package --disable-sandbox registry metadata create --vv

# Shows detailed information about:
# - Git config extraction
# - README parsing
# - LICENSE detection
# - Repository URL resolution
```

### Example 3: Overwrite Existing Metadata

```bash
cd MyPackage

# If you've updated your README or LICENSE, regenerate metadata
swift package --disable-sandbox registry metadata create --overwrite

# This will replace existing Package.json and package-metadata.json files
```

### Example 4: Edit Metadata Before Publishing

```bash
cd MyPackage

# 1. Create initial metadata files
swift package --disable-sandbox registry metadata create

# 2. Edit package-metadata.json to customize
vim package-metadata.json

# Example customizations:
# - Add more detailed description
# - Add organization information
# - Add additional URLs
# {
#   "author": {
#     "name": "John Doe",
#     "email": "john@example.com",
#     "organization": {
#       "name": "My Company",
#       "url": "https://mycompany.com"
#     }
#   },
#   "description": "A comprehensive Swift package for...",
#   "licenseType": "MIT",
#   "licenseURL": "https://github.com/org/repo/blob/main/LICENSE",
#   "repositoryURL": "https://github.com/org/repo",
#   "readmeURL": "https://github.com/org/repo/blob/main/README.md"
# }

# 3. Publish with customized metadata
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com
```

## Basic Package Publishing

### Example 5: Simple Publishing Workflow

```bash
# Navigate to your package
cd MyAwesomeLibrary

# Publish directly (auto-generates metadata)
swift package --disable-sandbox registry publish myorg.MyAwesomeLibrary 1.0.0 \
  --url https://registry.example.com

# Expected output:
# 🚀 SPM Extended Plugin - Registry Publish
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package: MyAwesomeLibrary
# Directory: /path/to/MyAwesomeLibrary
# 
# 📝 Step 1: Generating Package.json...
#    ✓ Package.json created
# 
# 📝 Step 2: Generating package-metadata.json...
#    ✓ package-metadata.json created
# 
# 🚀 Step 3: Publishing to registry...
#    ✓ Published successfully!
# 
# ✅ Package published to registry!
```

### Example 6: Dry Run (Preview Without Publishing)

```bash
cd MyPackage

# Prepare files without publishing
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --dry-run

# This creates Package.json and package-metadata.json but doesn't publish
# Review the files, then publish without --dry-run
```

### Example 7: Publishing with Custom Metadata

```bash
cd MyPackage

# Create and customize metadata first
swift package --disable-sandbox registry metadata create
vim package-metadata.json

# Publish with the customized metadata
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com
```

### Example 8: Publishing with Signing

```bash
cd MyPackage

# Publish with package signing
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --signing-identity "My Developer Certificate" \
  --cert-chain-paths cert.der
```

## Publishing to OpenSPMRegistry

### Example 9: Complete Publishing Workflow

```bash
# Setup registry (one-time)
swift package-registry set https://registry.example.com
swift package-registry login

# Navigate to package
cd MyPackage

# Publish
swift package --disable-sandbox registry publish mycompany.MyPackage 1.0.0 \
  --url https://registry.example.com

# Verify publication
curl -H "Accept: application/vnd.swift.registry.v1+json" \
  https://registry.example.com/mycompany/MyPackage | jq .
```

### Example 10: Publishing New Version

```bash
cd MyPackage

# Update your code...
# Update version in README, etc.

# Publish new version (regenerates metadata)
swift package --disable-sandbox registry publish mycompany.MyPackage 1.1.0 \
  --url https://registry.example.com --overwrite

# Both versions now appear in registry
curl -H "Accept: application/vnd.swift.registry.v1+json" \
  https://registry.example.com/mycompany/MyPackage | jq '.releases | keys'
# Output: ["1.0.0", "1.1.0"]
```

## CI/CD Integration

### Example 11: GitHub Actions Workflow

```yaml
# .github/workflows/publish.yml
name: Publish Package

on:
  push:
    tags:
      - '*'

jobs:
  publish:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: '5.9'
      
      - name: Install Plugin
        run: |
          swift package resolve
      
      - name: Create Metadata
        run: |
          swift package --disable-sandbox registry metadata create --vv
      
      - name: Publish to Registry
        env:
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          swift package-registry set ${{ secrets.REGISTRY_URL }}
          swift package-registry login --token $REGISTRY_TOKEN
          swift package --disable-sandbox registry publish \
            mycompany.${{ github.event.repository.name }} \
            $VERSION \
            --url ${{ secrets.REGISTRY_URL }}
      
      - name: Upload Metadata Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: package-metadata
          path: |
            Package.json
            package-metadata.json
```

### Example 12: GitLab CI Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - prepare
  - publish

variables:
  SWIFT_VERSION: "5.9"
  SCOPE: "mycompany"

prepare-metadata:
  stage: prepare
  image: swift:${SWIFT_VERSION}
  script:
    - swift package --disable-sandbox registry metadata create --vv
  artifacts:
    paths:
      - Package.json
      - package-metadata.json
  only:
    - tags

publish-package:
  stage: publish
  image: swift:${SWIFT_VERSION}
  script:
    - swift package-registry set $REGISTRY_URL
    - swift package-registry login --token $REGISTRY_TOKEN
    - |
      swift package --disable-sandbox registry publish \
        ${SCOPE}.${CI_PROJECT_NAME} \
        $CI_COMMIT_TAG \
        --url $REGISTRY_URL
  dependencies:
    - prepare-metadata
  only:
    - tags
```

## Multiple Packages Workflow

### Example 13: Monorepo with Multiple Packages

```bash
#!/bin/bash
# publish-all.sh - Script to publish multiple packages

PACKAGES=("PackageA" "PackageB" "PackageC")
SCOPE="mycompany"
VERSION="1.0.0"
REGISTRY_URL="https://registry.example.com"

for package in "${PACKAGES[@]}"; do
  echo "📦 Processing $package..."
  
  cd $package
  
  # Create metadata first
  swift package --disable-sandbox registry metadata create --vv
  
  # Publish
  swift package --disable-sandbox registry publish \
    ${SCOPE}.${package} \
    $VERSION \
    --url $REGISTRY_URL
  
  cd ..
  
  echo "✅ $package published"
  echo ""
done

echo "🎉 All packages published!"
```

### Example 14: Workspace with Shared Dependencies

```bash
# Workspace structure:
# workspace/
#   ├── SharedUtilities/
#   ├── NetworkLayer/
#   └── AppCore/

# Publish in dependency order
cd workspace
SCOPE="mycompany"
VERSION="1.0.0"
REGISTRY_URL="https://registry.example.com"

# 1. First, publish shared utilities (no dependencies)
cd SharedUtilities
swift package --disable-sandbox registry publish ${SCOPE}.SharedUtilities $VERSION \
  --url $REGISTRY_URL
cd ..

# 2. Then network layer (depends on SharedUtilities)
cd NetworkLayer
swift package --disable-sandbox registry publish ${SCOPE}.NetworkLayer $VERSION \
  --url $REGISTRY_URL
cd ..

# 3. Finally app core (depends on both)
cd AppCore
swift package --disable-sandbox registry publish ${SCOPE}.AppCore $VERSION \
  --url $REGISTRY_URL
cd ..
```

## Troubleshooting

### Example 15: Debugging Metadata Generation

```bash
cd MyPackage

# Use verbose mode to see what's happening
swift package --disable-sandbox registry metadata create --vv

# Check git configuration
git config user.name
git config user.email
git config --get remote.origin.url

# Verify README.md exists and has content
cat README.md | head -20

# Verify LICENSE file exists
ls -la LICENSE*
```

### Example 16: Metadata Inspection

```bash
# After creating metadata, inspect contents
swift package --disable-sandbox registry metadata create

# Check Package.json is valid
cat Package.json | jq .

# Verify it contains expected fields
cat Package.json | jq -r '.name, .products[].name, .targets[].name'

# Check package-metadata.json
cat package-metadata.json | jq .

# Verify metadata fields
cat package-metadata.json | jq -r '.author.name, .description, .licenseType'
```

### Example 17: Fixing Invalid Manifest

```bash
cd MyPackage

# If metadata creation fails, test manifest directly
swift package dump-package

# Common issues:
# 1. Invalid Package.swift syntax
swift build  # This will show syntax errors

# 2. Missing swift-tools-version
# Add to top of Package.swift:
# // swift-tools-version: 5.9

# 3. After fixing, regenerate metadata
swift package --disable-sandbox registry metadata create --overwrite
```

### Example 18: Publishing Troubleshooting

```bash
# Test registry connection first
curl -H "Accept: application/vnd.swift.registry.v1+json" \
  https://registry.example.com/identifiers

# Verify credentials
swift package-registry login --token YOUR_TOKEN

# Try dry run first
swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 \
  --url https://registry.example.com \
  --dry-run \
  --vv

# If dry run succeeds, remove --dry-run to actually publish
```

## Advanced Usage

### Example 19: Custom Pre-publish Script

```bash
#!/bin/bash
# prepare-and-validate.sh

set -e

SCOPE=$1
PACKAGE=$2
VERSION=$3
REGISTRY_URL=$4

if [ -z "$SCOPE" ] || [ -z "$PACKAGE" ] || [ -z "$VERSION" ] || [ -z "$REGISTRY_URL" ]; then
  echo "Usage: $0 <scope> <package> <version> <registry-url>"
  exit 1
fi

echo "🔍 Pre-publish checks..."

# 1. Run tests
echo "Running tests..."
swift test

# 2. Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
  echo "⚠️  Warning: Uncommitted changes detected"
  git status -s
fi

# 3. Verify version tag exists
if ! git tag | grep -q "^$VERSION$"; then
  echo "⚠️  Warning: Git tag $VERSION not found"
fi

# 4. Create metadata
echo "📝 Creating metadata..."
swift package --disable-sandbox registry metadata create --vv

# 5. Validate metadata files exist
if [ ! -f "Package.json" ]; then
  echo "❌ Package.json not found"
  exit 1
fi

if [ ! -f "package-metadata.json" ]; then
  echo "❌ package-metadata.json not found"
  exit 1
fi

# 6. Validate JSON
cat Package.json | jq . > /dev/null || {
  echo "❌ Package.json is not valid JSON"
  exit 1
}

cat package-metadata.json | jq . > /dev/null || {
  echo "❌ package-metadata.json is not valid JSON"
  exit 1
}

echo "✅ Package ready for publishing"
echo ""
echo "To publish, run:"
echo "  swift package --disable-sandbox registry publish ${SCOPE}.${PACKAGE} $VERSION --url $REGISTRY_URL"
```

Usage:
```bash
chmod +x prepare-and-validate.sh
./prepare-and-validate.sh mycompany MyPackage 1.0.0 https://registry.example.com
```

### Example 20: Makefile Automation

```makefile
VERSION := $(shell git describe --tags --abbrev=0)
SCOPE := mycompany
PACKAGE := $(shell basename $(PWD))
REGISTRY_URL := https://registry.example.com

.PHONY: metadata publish clean test help

metadata:
	swift package --disable-sandbox registry metadata create --vv

publish: metadata test
	swift package --disable-sandbox registry publish \
		$(SCOPE).$(PACKAGE) \
		$(VERSION) \
		--url $(REGISTRY_URL)

dry-run: metadata
	swift package --disable-sandbox registry publish \
		$(SCOPE).$(PACKAGE) \
		$(VERSION) \
		--url $(REGISTRY_URL) \
		--dry-run

test:
	swift test

clean:
	rm -f Package.json package-metadata.json

help:
	@echo "Available targets:"
	@echo "  metadata  - Create Package.json and package-metadata.json"
	@echo "  publish   - Create metadata and publish to registry"
	@echo "  dry-run   - Test publish without actually publishing"
	@echo "  test      - Run tests"
	@echo "  clean     - Remove generated metadata files"
```

Usage:
```bash
# Create metadata only
make metadata

# Test without publishing
make dry-run

# Publish package
make publish
```

## Tips and Best Practices

1. **Always review metadata before first publish**
   ```bash
   swift package --disable-sandbox registry metadata create
   cat package-metadata.json | jq .
   # Edit if needed, then publish
   ```

2. **Use verbose mode when debugging**
   ```bash
   swift package --disable-sandbox registry metadata create --vv
   ```

3. **Store metadata in version control** (optional)
   ```bash
   git add Package.json package-metadata.json
   git commit -m "Add package metadata"
   ```

4. **Use --overwrite when updating**
   ```bash
   # After updating README or LICENSE
   swift package --disable-sandbox registry metadata create --overwrite
   ```

5. **Automate with CI/CD**
   - Create metadata in CI pipeline
   - Review artifacts before publishing
   - Publish automatically on tags

6. **Test with dry-run first**
   ```bash
   swift package --disable-sandbox registry publish myorg.Package 1.0.0 \
     --url https://registry.example.com --dry-run
   ```

## Related Resources

- [Swift Package Manager Documentation](https://github.com/apple/swift-package-manager)
- [Package Collections (SE-0291)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)
- [Swift Package Registry Specification](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md)
- [OpenSPMRegistry](https://github.com/wgr1984/OpenSPMRegistry)
