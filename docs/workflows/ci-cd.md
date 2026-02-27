# CI/CD workflow

Automate publishing to your Swift package registry when you push a tag (e.g. `1.0.0`). The pipeline: checkout, resolve dependencies, configure registry and login, then publish. The **publish** command creates `Package.json` and `package-metadata.json` automatically if they are missing, so a separate metadata step is not required.

## When to use it

- You release by pushing a git tag.
- You want every tag to be published to the registry without manual steps.
- You run this in **GitHub Actions** or **GitLab CI** (or similar).

## Prerequisites

- Repository has the plugin as a dependency (so `swift package resolve` makes the plugin available), or you use a CLI install (e.g. Mint) in the job.
- Registry URL and a token (or credentials) stored as **secrets** (e.g. `REGISTRY_URL`, `REGISTRY_TOKEN`).

## GitHub Actions

Example: run on push of any tag; publish using the tag as the version.

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

      - name: Resolve dependencies (plugin available)
        run: swift package resolve

      - name: Publish to registry
        env:
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          swift package-registry set ${{ secrets.REGISTRY_URL }}
          swift package-registry login --token "$REGISTRY_TOKEN"
          swift package --disable-sandbox registry publish \
            mycompany.${{ github.event.repository.name }} \
            "$VERSION" \
            --url ${{ secrets.REGISTRY_URL }}
```

**Secrets to configure in the repo:**

- `REGISTRY_URL` — Registry base URL (e.g. `https://registry.example.com`).
- `REGISTRY_TOKEN` — Token for `swift package-registry login --token ...`.

Replace `mycompany` with your scope. The example uses `github.event.repository.name` as the package name (often matches the repo name); if your package name differs, use a fixed value or another variable.

## GitLab CI

Example: run on tag push; publish creates metadata automatically.

```yaml
# .gitlab-ci.yml
publish-package:
  image: swift:5.9
  script:
    - swift package resolve
    - swift package-registry set $REGISTRY_URL
    - swift package-registry login --token $REGISTRY_TOKEN
    - |
      swift package --disable-sandbox registry publish \
        mycompany.${CI_PROJECT_NAME} \
        $CI_COMMIT_TAG \
        --url $REGISTRY_URL
  only:
    - tags
```

**Variables (secrets or CI/CD variables):** `REGISTRY_URL`, `REGISTRY_TOKEN`. Replace `mycompany` with your scope; `CI_PROJECT_NAME` and `CI_COMMIT_TAG` are provided by GitLab.

## Notes

- **Metadata:** `registry publish` generates `Package.json` and `package-metadata.json` if they are missing, so you don't need a separate `registry metadata create` step. Use [metadata create](../commands/metadata.md) only if you want to generate or edit metadata before publishing (e.g. in a manual workflow).
- **Sandbox:** Use `--disable-sandbox` so the plugin can write metadata and the registry client can run.
- **Version:** In both examples the published version is the tag name (e.g. `1.0.0`). Ensure tags match your desired version format.

## See also

- [Release and publish](release-and-publish.md) — Manual version of this flow.
- [Commands: publish](../commands/publish.md) — Publish options (e.g. signing).
- [Commands: metadata](../commands/metadata.md) — Metadata create options.
