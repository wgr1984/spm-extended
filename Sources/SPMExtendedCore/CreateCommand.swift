import Foundation

struct CreateCommand {
    let environment: RunEnvironment

    private var metadataGenerator: MetadataGenerator {
        MetadataGenerator(environment: environment)
    }

    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Metadata Create")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(environment.packageName)")
        print("Directory: \(environment.packageDirectory)")
        print()

        var scratchDirectory: String?
        var verbose = false
        var overwrite = false

        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--scratch-directory":
                i += 1
                if i < arguments.count { scratchDirectory = arguments[i] }
            case "--vv", "--verbose":
                verbose = true
            case "--overwrite":
                overwrite = true
            case "--help", "-h":
                printCreateHelp()
                return
            default:
                print("⚠️  Warning: Unknown option '\(arg)'")
            }
            i += 1
        }

        let effectiveScratchDirectory = scratchDirectory ?? "/tmp/spm-plugin-metadata-\(UUID().uuidString)"
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: effectiveScratchDirectory) {
            try fileManager.createDirectory(atPath: effectiveScratchDirectory, withIntermediateDirectories: true, attributes: nil)
            if verbose { print("   Created scratch directory: \(effectiveScratchDirectory)") }
        }

        do {
            print("📝 Step 1: Generating Package.json if needed...")
            let packageJsonCreated = try metadataGenerator.generatePackageJson(scratchDirectory: effectiveScratchDirectory, verbose: verbose, overwrite: overwrite)
            if packageJsonCreated {
                print("   ✓ Package.json created")
            }
            print()

            print("📝 Step 2: Generating package-metadata.json if needed...")
            let (_, metadataCreated) = try metadataGenerator.generatePackageMetadata(verbose: verbose, overwrite: overwrite)
            if metadataCreated {
                print("   ✓ package-metadata.json created")
            }
            print()

            if scratchDirectory == nil {
                try? FileManager.default.removeItem(atPath: effectiveScratchDirectory)
            }

            print("✅ Metadata files created successfully!")
            print()
            var createdFiles: [String] = []
            if packageJsonCreated { createdFiles.append("Package.json") }
            if metadataCreated { createdFiles.append("package-metadata.json") }
            if !createdFiles.isEmpty {
                print("📁 Created files:")
                for name in createdFiles {
                    print("   • \(name)")
                }
                print()
            }
            print("💡 Next steps:")
            print("   1. Review the generated files")
            print("   2. Edit package-metadata.json to customize metadata if needed")
            print("   3. Publish your package with: swift package --disable-sandbox registry publish <package-id> <version> --url <registry-url>")
        } catch {
            let errorDescription = String(describing: error)
            if SandboxErrorHelper.isSandboxError(errorDescription) {
                print()
                throw SPMExtendedError.sandboxRequired(SandboxErrorHelper.createSandboxErrorMessage())
            }
            throw error
        }
    }

    private func printCreateHelp() {
        print("""
        OVERVIEW: Create Package.json and package-metadata.json files

        USAGE: swift package --disable-sandbox registry metadata create [options]

        DESCRIPTION:
          This command creates the metadata files required for publishing packages
          to a registry:
          1. Package.json - Generated from your Package.swift manifest
          2. package-metadata.json - Auto-generated from git, README, LICENSE, remote

        OPTIONS:
          --scratch-directory <dir> Directory for working files
          --overwrite             Overwrite existing metadata files
          --vv, --verbose         Enable verbose output
          -h, --help              Show this help message

        IMPORTANT:
          swift package --disable-sandbox registry metadata create

        EXAMPLES:
          swift package --disable-sandbox registry metadata create
          swift package --disable-sandbox registry metadata create --vv
          swift package --disable-sandbox registry metadata create --overwrite
        """)
    }
}
