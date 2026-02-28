# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-02-28

### Added
- `registry list` command: list available versions for a package from a Swift package registry
- `registry verify` command: verify release metadata, source-archive resource, optional manifest fetch, and Swift tools versions for a package version

### Changed
- README updated regarding package collection

### Fixed
- Bug fixes and minor improvements

## [0.1.1] - 2025-02-28

### Fixed
- Bug fixes and minor improvements

## [0.1.0] - 2025-02-28

### Added
- Initial release of SPM Extended Plugin
- `publish-extended` command for automating package publishing workflow
- Automatic Package.json generation from Package.swift manifest
- Source archive creation with Package.json inclusion
- Support for SE-0291 Package Collections
- Command-line options for scope, version, output path, and verbose mode
- Comprehensive help documentation
- Permission handling for package directory writes

### Features
- One-command workflow to prepare packages for registry publishing
- Smart archive naming based on package name and version
- Helpful next-steps guidance after preparation
- Skip-archive mode for Package.json-only generation
- Verbose output mode for debugging
