# Contributing to SPM Extended Plugin

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Getting Started

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/wgr1984/spm-extended.git
   cd spm-extended
   ```

2. **Build and test**
   ```bash
   swift build
   ```

3. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Requirements

- Swift 5.9 or later
- macOS 12 or later
- Xcode 14+ (optional, for IDE support)

### Project Structure

```
├── Package.swift                    # Package manifest (products: RegistryPlugin, OutdatedPlugin, spm-extended CLI)
├── Sources/
│   ├── SPMExtendedCore/             # Shared command logic (edit here)
│   └── SPMExtendedCLI/              # Standalone CLI (main.swift, depends on SPMExtendedCore)
├── Plugins/
│   ├── RegistryPlugin/              # Plugin: swift package registry ...
│   │   ├── RegistryPlugin.swift
│   │   └── Shared -> ../../Sources/SPMExtendedCore
│   └── OutdatedPlugin/              # Plugin: swift package outdated
│       ├── OutdatedPlugin.swift
│       └── Shared -> ../../Sources/SPMExtendedCore
├── Tests/                           # Tests
├── docs/                            # DOCS.md content (installation, commands, workflows)
├── Examples/                        # Demo packages and OpenSPMRegistry
├── README.md, DOCS.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE
└── ...
```

### Source layout

Command logic lives in `Sources/SPMExtendedCore/`. The CLI depends on this target. Plugins cannot depend on library targets in the same package, so `Plugins/RegistryPlugin/Shared` and `Plugins/OutdatedPlugin/Shared` are symlinks to `Sources/SPMExtendedCore`; each plugin compiles that shared source as part of its target. **Edit core code only in `Sources/SPMExtendedCore/`.**

## Making Changes

### Code Style

- Follow Swift API Design Guidelines
- Use clear, descriptive variable and function names
- Add comments for complex logic
- Keep functions focused and single-purpose

### Plugin Development

When working on the plugin:

1. **Test locally**: Create a test package and use the plugin on it
2. **Error handling**: Ensure proper error messages for users
3. **Documentation**: Update README.md and inline help
4. **Permissions**: Be mindful of file system operations

### Testing Your Changes

Create a test Swift package to verify the plugin:

```bash
# Create a test package
mkdir ../TestPackage
cd ../TestPackage
swift package init --type library

# Add the plugin as a local dependency in Package.swift
# Then test the plugin (e.g. metadata create or publish --dry-run)
swift package --disable-sandbox registry metadata create
# or: swift package --disable-sandbox registry publish scope.MyPackage 1.0.0 --dry-run
```

## Releasing

To cut a new version (so Mint and package users get a stable “latest”): update [CHANGELOG.md](CHANGELOG.md), create an annotated tag (e.g. `1.0.0`), and push it. Optionally create a GitHub Release with notes from the changelog. See **[Release process](docs/release-process.md)** for the full steps and why tags are required for Mint.

## Submitting Changes

### Pull Request Process

1. **Update documentation**
   - Update README.md if adding features
   - Update CHANGELOG.md under `[Unreleased]`
   - Update inline help text if changing commands

2. **Test thoroughly**
   - Test on a real Swift package
   - Verify error handling
   - Check verbose output

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of changes"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Open a Pull Request**
   - Provide a clear description of changes
   - Reference any related issues
   - Include testing steps

### Commit Message Format

Use clear, descriptive commit messages:

- `Add: New feature description`
- `Fix: Bug fix description`
- `Update: Modification description`
- `Docs: Documentation changes`
- `Refactor: Code restructuring`

## Feature Ideas

Here are some potential features to contribute:

### High Priority

- [ ] Add `publish` command that combines prepare + publish
- [ ] Support for registry configuration file
- [ ] Validation of Package.json before archiving
- [ ] Archive verification (test extraction)

### Medium Priority

- [ ] Support for metadata.json generation
- [ ] Archive compression options
- [ ] Multi-registry support
- [ ] Dry-run mode

### Nice to Have

- [ ] Interactive mode for missing parameters
- [ ] Package validation before preparation
- [ ] Integration tests
- [ ] CI/CD examples for common platforms

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Accept criticism gracefully

### Unacceptable Behavior

- Harassment or discriminatory language
- Personal attacks
- Trolling or inflammatory comments
- Publishing others' private information

## Questions?

- Open an issue for feature requests or bugs
- Start a discussion for general questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes for significant contributions
- README.md acknowledgments section (for major features)

Thank you for contributing to SPM Extended Plugin! 🚀
