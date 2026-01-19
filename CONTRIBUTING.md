# Contributing to SPM Extended Plugin

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Getting Started

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/wgr1984/swift-package-manager-extended-plugin.git
   cd swift-package-manager-extended-plugin
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
swift-package-manager-extended-plugin/
├── Package.swift                          # Package manifest
├── Plugins/
│   └── PublishExtendedPlugin/
│       └── PublishExtendedPlugin.swift   # Main plugin implementation
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

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
# Then test the plugin
swift package publish-extended --verbose
```

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
