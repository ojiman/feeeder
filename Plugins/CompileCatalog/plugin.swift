import Foundation
import PackagePlugin

// Native SwiftPM copies xcstrings without compiling them (the CI toolchain). Keep the catalog as the only source.
@main struct CompileCatalog: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let catalog = URL(fileURLWithPath: target.directory.string).appending(path: "Resources/Localizable.xcstrings")
        let output = context.pluginWorkDirectoryURL.appending(path: "CompiledCatalog")
        return [.prebuildCommand(displayName: "Compile UI translations", executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "set -eu\nrm -rf \"$2\"\nmkdir -p \"$2\"\nexec /usr/bin/xcrun xcstringstool compile \"$1\" --output-directory \"$2\"", "compile-catalog", catalog.path, output.path],
            outputFilesDirectory: output)]
    }
}
