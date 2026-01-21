import Foundation
import PackagePlugin

struct CreateCommand {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String
    
    private var metadataGenerator: MetadataGenerator {
        MetadataGenerator(context: context, packageDirectory: packageDirectory, packageName: packageName)
    }
    
    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Metadata Create")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(packageName)")
        print("Directory: \(packageDirectory)")
        print()
        
        // Parse options
        var scratchDirectory: String?
        var verbose = false
        var overwrite = false
        
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            
            switch arg {
            case "--scratch-directory":
                i += 1
                if i < arguments.count {
                    scratchDirectory = arguments[i]
                }
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
        
        // Use user-provided scratch directory, or create a temporary one
        let effectiveScratchDirectory = scratchDirectory ?? "/tmp/spm-plugin-metadata-\(UUID().uuidString)"
        
        // Create the scratch directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: effectiveScratchDirectory) {
            try fileManager.createDirectory(atPath: effectiveScratchDirectory, withIntermediateDirectories: true, attributes: nil)
            if verbose {
                print("   Created scratch directory: \(effectiveScratchDirectory)")
            }
        }
        
        do {
            // Step 1: Generate Package.json
            print("📝 Step 1: Generating Package.json...")
            try metadataGenerator.generatePackageJson(scratchDirectory: effectiveScratchDirectory, verbose: verbose, overwrite: overwrite)
            print("   ✓ Package.json created")
            print()
            
            // Step 2: Generate package-metadata.json
            print("📝 Step 2: Generating package-metadata.json...")
            _ = try metadataGenerator.generatePackageMetadata(verbose: verbose, overwrite: overwrite)
            print("   ✓ package-metadata.json created")
            print()
            
            // Clean up temporary scratch directory if we created one
            if scratchDirectory == nil {
                try? FileManager.default.removeItem(atPath: effectiveScratchDirectory)
            }
            
            print("✅ Metadata files created successfully!")
            print()
            print("📁 Created files:")
            print("   • Package.json")
            print("   • package-metadata.json")
            print()
            print("💡 Next steps:")
            print("   1. Review the generated files")
            print("   2. Edit package-metadata.json to customize metadata if needed")
            print("   3. Publish your package with: swift package --disable-sandbox registry publish <package-id> <version> --url <registry-url>")
        } catch {
            // Check if the error is permission-related (sandbox issue)
            let errorDescription = String(describing: error)
            if SandboxErrorHelper.isSandboxError(errorDescription) {
                print()
                throw PluginError.sandboxRequired(SandboxErrorHelper.createSandboxErrorMessage())
            }
            // Re-throw other errors
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
          2. package-metadata.json - Auto-generated from:
             - Git config (author name/email)
             - README.md (description)
             - LICENSE file (license type/URL)
             - Git remote (repository URL)
          
          The workflow ensures packages appear in Package Collections (SE-0291).
        
        OPTIONS:
          --scratch-directory <dir>
                                  Directory for working files
          --overwrite             Overwrite existing metadata files
          --vv, --verbose         Enable verbose output
          -h, --help              Show this help message
        
        IMPORTANT:
          The --disable-sandbox flag must be passed to Swift Package Manager:
          
            swift package --disable-sandbox registry metadata create
          
          This is required because the plugin needs to write files and access
          git configuration, which are blocked by the sandbox.
        
        EXAMPLES:
          # Create metadata files
          swift package --disable-sandbox registry metadata create
          
          # Create with verbose output
          swift package --disable-sandbox registry metadata create --vv
          
          # Overwrite existing files
          swift package --disable-sandbox registry metadata create --overwrite
        
        WORKFLOW:
          1. Generates Package.json from Package.swift manifest
          2. Auto-generates package-metadata.json from repository information
          3. Displays extracted metadata for review
        
        NOTE:
          The command will automatically extract metadata from your repository.
          After generation, you can edit package-metadata.json to customize the metadata.
        
        SEE ALSO:
          - SE-0291 Package Collections
          - swift package registry publish --help
        """)
    }
}
