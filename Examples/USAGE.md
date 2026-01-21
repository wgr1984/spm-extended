# Usage Examples

This document provides real-world examples of using the SPM Extended Plugin.

## Table of Contents

- [Basic Package Preparation](#basic-package-preparation)
- [Publishing to OpenSPMRegistry](#publishing-to-openspmregistry)
- [CI/CD Integration](#cicd-integration)
- [Multiple Packages Workflow](#multiple-packages-workflow)
- [Troubleshooting](#troubleshooting)

## Basic Package Preparation

### Example 1: Simple Library Package

```bash
# Navigate to your package
cd MyAwesomeLibrary

# Prepare for publishing
swift package publish-extended --version 1.0.0

# Expected output:
# 🚀 SPM Extended Plugin - Publish Prepare
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package: MyAwesomeLibrary
# 
# 📝 Step 1: Generating Package.json...
#    ✓ Package.json created
# 
# 📦 Step 2: Creating source archive...
#    ✓ Archive created: MyAwesomeLibrary-1.0.0.zip
# 
# ✅ Package prepared for publishing!

# Verify what was created
ls -la | grep -E "Package.json|\.zip"
# -rw-r--r--  1 user  staff   1234 Jan 19 10:00 Package.json
# -rw-r--r--  1 user  staff  12345 Jan 19 10:00 MyAwesomeLibrary-1.0.0.zip

# Inspect Package.json
cat Package.json | jq .
```

### Example 2: Package with Custom Archive Name

```bash
cd MyPackage

# Use custom output name
swift package publish-extended \
  --version 2.0.0 \
  --output release-2.0.0.zip \
  --verbose

# This creates: release-2.0.0.zip
```

### Example 3: Generate Package.json Only

```bash
cd MyPackage

# Only create Package.json (no archive)
swift package publish-extended --skip-archive

# Use case: When you want to inspect Package.json before archiving
cat Package.json | jq .

# Then manually archive if satisfied
zip -r MyPackage.zip . -x ".*" -x "*.build" -x "Package.resolved"
```

## Publishing to OpenSPMRegistry

### Example 4: Complete Publishing Workflow

```bash
# Setup registry (one-time)
swift package-registry set https://registry.example.com
swift package-registry login

# Prepare package
cd MyPackage
swift package publish-extended \
  --scope mycompany \
  --version 1.0.0

# Output shows the exact command to use:
# Next steps:
#   swift package-registry publish mycompany MyPackage 1.0.0 MyPackage-1.0.0.zip

# Execute the publish command
swift package-registry publish mycompany MyPackage 1.0.0 MyPackage-1.0.0.zip

# Verify publication
curl -H "Accept: application/vnd.swift.registry.v1+json" https://registry.example.com/mycompany/MyPackage | jq .
```

### Example 5: Publishing New Version

```bash
cd MyPackage

# Update your code...
# Update version in README, etc.

# Prepare new version
swift package publish-extended --scope mycompany --version 1.1.0

# Publish
swift package-registry publish mycompany MyPackage 1.1.0 MyPackage-1.1.0.zip

# Both versions now appear in registry
curl -H "Accept: application/vnd.swift.registry.v1+json" \
  https://registry.example.com/mycompany/MyPackage | jq '.releases | keys'
# Output: ["1.0.0", "1.1.0"]
```

## CI/CD Integration

### Example 6: GitHub Actions Workflow

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
          # Add plugin as dependency or use via URL
          swift package resolve
      
      - name: Prepare Package
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          swift package publish-extended \
            --scope mycompany \
            --version $VERSION \
            --verbose
      
      - name: Publish to Registry
        env:
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          swift package-registry login --token $REGISTRY_TOKEN
          swift package-registry publish \
            mycompany \
            ${{ github.event.repository.name }} \
            $VERSION \
            ${{ github.event.repository.name }}-$VERSION.zip
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: package-archive
          path: '*.zip'
```

### Example 7: GitLab CI Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - prepare
  - publish

variables:
  SWIFT_VERSION: "5.9"

prepare:
  stage: prepare
  image: swift:${SWIFT_VERSION}
  script:
    - swift package publish-extended --version $CI_COMMIT_TAG --verbose
  artifacts:
    paths:
      - "*.zip"
      - Package.json
  only:
    - tags

publish:
  stage: publish
  image: swift:${SWIFT_VERSION}
  script:
    - swift package-registry login --token $REGISTRY_TOKEN
    - |
      swift package-registry publish \
        mycompany \
        $CI_PROJECT_NAME \
        $CI_COMMIT_TAG \
        $CI_PROJECT_NAME-$CI_COMMIT_TAG.zip
  dependencies:
    - prepare
  only:
    - tags
```

## Multiple Packages Workflow

### Example 8: Monorepo with Multiple Packages

```bash
#!/bin/bash
# publish-all.sh - Script to prepare and publish multiple packages

PACKAGES=("PackageA" "PackageB" "PackageC")
SCOPE="mycompany"
VERSION="1.0.0"

for package in "${PACKAGES[@]}"; do
  echo "📦 Processing $package..."
  
  cd $package
  
  # Prepare
  swift package publish-extended \
    --scope $SCOPE \
    --version $VERSION \
    --verbose
  
  # Publish
  swift package-registry publish \
    $SCOPE \
    $package \
    $VERSION \
    $package-$VERSION.zip
  
  cd ..
  
  echo "✅ $package published"
  echo ""
done

echo "🎉 All packages published!"
```

### Example 9: Workspace with Shared Dependencies

```bash
# Workspace structure:
# workspace/
#   ├── SharedUtilities/
#   ├── NetworkLayer/
#   └── AppCore/

# Publish in dependency order
cd workspace

# 1. First, publish shared utilities (no dependencies)
cd SharedUtilities
swift package publish-extended --scope mycompany --version 1.0.0
swift package-registry publish mycompany SharedUtilities 1.0.0 SharedUtilities-1.0.0.zip
cd ..

# 2. Then network layer (depends on SharedUtilities)
cd NetworkLayer
swift package publish-extended --scope mycompany --version 1.0.0
swift package-registry publish mycompany NetworkLayer 1.0.0 NetworkLayer-1.0.0.zip
cd ..

# 3. Finally app core (depends on both)
cd AppCore
swift package publish-extended --scope mycompany --version 1.0.0
swift package-registry publish mycompany AppCore 1.0.0 AppCore-1.0.0.zip
cd ..
```

## Troubleshooting

### Example 10: Debugging Failed Preparation

```bash
cd MyPackage

# Use verbose mode to see what's happening
swift package publish-extended --verbose

# If dump-package fails, test it directly
swift package dump-package

# Common issues:
# 1. Invalid Package.swift syntax
swift build  # This will show syntax errors

# 2. Missing swift-tools-version
# Add to top of Package.swift:
# // swift-tools-version: 5.9

# 3. Unsupported platform
# Ensure Package.swift has platforms:
# platforms: [.macOS(.v12)]
```

### Example 11: Archive Inspection

```bash
# After creating archive, inspect contents
swift package publish-extended --version 1.0.0

# Unzip to temporary directory to inspect
mkdir temp-inspect
unzip MyPackage-1.0.0.zip -d temp-inspect

# Verify Package.json is present
ls temp-inspect/
# Expected: Package.swift, Package.json, Sources/, Tests/, etc.

# Check Package.json content
cat temp-inspect/Package.json | jq .

# Cleanup
rm -rf temp-inspect
```

### Example 12: Dry Run Workflow

```bash
# Test without creating archive
swift package publish-extended --skip-archive --verbose

# Inspect Package.json
cat Package.json | jq .

# Verify it's valid JSON and contains expected fields
cat Package.json | jq -r '.name, .products[].name, .targets[].name'

# If satisfied, create archive
swift package publish-extended --version 1.0.0
```

## Advanced Usage

### Example 13: Custom Pre-publish Script

```bash
#!/bin/bash
# prepare-and-validate.sh

set -e

SCOPE=$1
VERSION=$2

if [ -z "$SCOPE" ] || [ -z "$VERSION" ]; then
  echo "Usage: $0 <scope> <version>"
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

# 4. Prepare package
echo "📦 Preparing package..."
swift package publish-extended \
  --scope $SCOPE \
  --version $VERSION \
  --verbose

# 5. Validate archive
echo "🔍 Validating archive..."
ARCHIVE="$(basename $(pwd))-$VERSION.zip"
if [ ! -f "$ARCHIVE" ]; then
  echo "❌ Archive not found: $ARCHIVE"
  exit 1
fi

# 6. Check archive contents
unzip -l "$ARCHIVE" | grep -q "Package.json" || {
  echo "❌ Package.json not found in archive"
  exit 1
}

echo "✅ Package ready for publishing"
echo "Run: swift package-registry publish $SCOPE $(basename $(pwd)) $VERSION $ARCHIVE"
```

Usage:
```bash
chmod +x prepare-and-validate.sh
./prepare-and-validate.sh mycompany 1.0.0
```

## Tips and Best Practices

1. **Always use version flags**: Makes archive names consistent
   ```bash
   swift package publish-extended --version $(git describe --tags)
   ```

2. **Store archives**: Keep archives for auditing
   ```bash
   mkdir -p releases
   swift package publish-extended --version 1.0.0
   mv *.zip releases/
   ```

3. **Automate with Make**: Use Makefile for consistency
   ```makefile
   VERSION := $(shell git describe --tags --abbrev=0)
   SCOPE := mycompany
   PACKAGE := $(shell basename $(PWD))

   prepare:
   	swift package publish-extended --scope $(SCOPE) --version $(VERSION)

   publish: prepare
   	swift package-registry publish $(SCOPE) $(PACKAGE) $(VERSION) $(PACKAGE)-$(VERSION).zip

   .PHONY: prepare publish
   ```

4. **Validate before publishing**: Always inspect Package.json first
   ```bash
   swift package publish-extended --skip-archive
   cat Package.json | jq .
   # If OK, then:
   swift package archive-source
   ```

## Related Resources

- [Swift Package Manager Documentation](https://github.com/apple/swift-package-manager)
- [Package Collections (SE-0291)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md)
- [Swift Package Registry Specification](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageRegistry/Registry.md)
