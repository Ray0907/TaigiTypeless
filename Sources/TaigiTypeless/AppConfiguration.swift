import Foundation

struct AppConfiguration {
    let pythonPath: String
    let modelPath: String
    let workingDirectory: String
    let workerScriptPath: String?
    let language: String
    let maxTokens: Int

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        let cwd = FileManager.default.currentDirectoryPath

        if let pythonPath = environment["TAIGI_TYPELESS_PYTHON"],
           let modelPath = environment["TAIGI_TYPELESS_MODEL"] {
            return AppConfiguration(
                pythonPath: pythonPath,
                modelPath: modelPath,
                workingDirectory: environment["TAIGI_TYPELESS_WORKDIR"] ?? "\(NSTemporaryDirectory())TaigiTypeless",
                workerScriptPath: workerScriptPath(environment: environment, currentDirectory: cwd),
                language: environment["TAIGI_TYPELESS_LANGUAGE"] ?? "zh",
                maxTokens: Int(environment["TAIGI_TYPELESS_MAX_TOKENS"] ?? "") ?? 512
            )
        }

        if let bundled = loadBundledConfiguration() {
            return bundled
        }

        return AppConfiguration(
            pythonPath: "\(cwd)/../.venv/bin/python",
            modelPath: "\(cwd)/../Breeze-ASR-26-mlx-4bit",
            workingDirectory: environment["TAIGI_TYPELESS_WORKDIR"] ?? "\(NSTemporaryDirectory())TaigiTypeless",
            workerScriptPath: workerScriptPath(environment: environment, currentDirectory: cwd),
            language: environment["TAIGI_TYPELESS_LANGUAGE"] ?? "zh",
            maxTokens: Int(environment["TAIGI_TYPELESS_MAX_TOKENS"] ?? "") ?? 512
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
            workingDirectory: config.workingDirectory ?? "\(NSTemporaryDirectory())TaigiTypeless",
            workerScriptPath: bundledWorkerScriptPath() ?? config.workerScriptPath,
            language: config.language ?? "zh",
            maxTokens: config.maxTokens ?? 512
        )
    }

    private static func workerScriptPath(environment: [String: String], currentDirectory: String) -> String? {
        environment["TAIGI_TYPELESS_WORKER"]
            ?? bundledWorkerScriptPath()
            ?? "\(currentDirectory)/scripts/stt_worker.py"
    }

    private static func bundledWorkerScriptPath() -> String? {
        guard let path = Bundle.main.resourceURL?
            .appendingPathComponent("stt_worker.py")
            .path else {
            return nil
        }
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

private struct AppConfigurationFile: Decodable {
    let pythonPath: String
    let modelPath: String
    let workingDirectory: String?
    let workerScriptPath: String?
    let language: String?
    let maxTokens: Int?
}
