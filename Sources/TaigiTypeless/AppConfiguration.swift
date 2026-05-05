import Foundation

struct AppConfiguration {
    let pythonPath: String
    let modelPath: String
    let workingDirectory: String

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        if let pythonPath = environment["TAIGI_TYPELESS_PYTHON"],
           let modelPath = environment["TAIGI_TYPELESS_MODEL"] {
            return AppConfiguration(
                pythonPath: pythonPath,
                modelPath: modelPath,
                workingDirectory: environment["TAIGI_TYPELESS_WORKDIR"] ?? "\(NSTemporaryDirectory())TaigiTypeless"
            )
        }

        if let bundled = loadBundledConfiguration() {
            return bundled
        }

        let cwd = FileManager.default.currentDirectoryPath
        return AppConfiguration(
            pythonPath: "\(cwd)/../.venv/bin/python",
            modelPath: "\(cwd)/../Breeze-ASR-26-mlx-4bit",
            workingDirectory: environment["TAIGI_TYPELESS_WORKDIR"] ?? "\(NSTemporaryDirectory())TaigiTypeless"
        )
    }

    private static func loadBundledConfiguration() -> AppConfiguration? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let configURL = resourceURL.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfigurationFile.self, from: data) else {
            return nil
        }
        return AppConfiguration(
            pythonPath: config.pythonPath,
            modelPath: config.modelPath,
            workingDirectory: config.workingDirectory ?? "\(NSTemporaryDirectory())TaigiTypeless"
        )
    }
}

private struct AppConfigurationFile: Decodable {
    let pythonPath: String
    let modelPath: String
    let workingDirectory: String?
}
