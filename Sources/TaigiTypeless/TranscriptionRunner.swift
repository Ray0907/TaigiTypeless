import Foundation

enum TranscriptionError: Error, LocalizedError {
    case commandFailed(String)
    case missingOutput

    var errorDescription: String? {
        switch self {
        case .commandFailed(let detail):
            return detail
        case .missingOutput:
            return "No transcription output was produced."
        }
    }
}

struct TranscriptionRunner {
    let configuration: AppConfiguration
    let polisher: TextPolisher

    func transcribe(audioPath: String) throws -> String {
        let outputDirectory = "\(configuration.workingDirectory)/output-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        let command = TranscriptionCommand(
            pythonPath: configuration.pythonPath,
            modelPath: configuration.modelPath,
            audioPath: audioPath,
            outputDirectory: outputDirectory
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        let stderr = Pipe()
        let stdout = Pipe()
        process.standardError = stderr
        process.standardOutput = stdout

        try process.run()
        process.waitUntilExit()

        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw TranscriptionError.commandFailed(stderrText.isEmpty ? stdoutText : stderrText)
        }

        let rawText = try readTranscriptionText(from: outputDirectory, stdout: stdoutText)
        return polisher.polish(rawText)
    }

    private func readTranscriptionText(from outputDirectory: String, stdout: String) throws -> String {
        let outputURL = URL(fileURLWithPath: outputDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: outputURL,
            includingPropertiesForKeys: nil
        )) ?? []

        if let jsonURL = files.first(where: { $0.pathExtension == "json" }),
           let data = try? Data(contentsOf: jsonURL),
           let payload = try? JSONDecoder().decode(STTOutput.self, from: data),
           !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return payload.text
        }

        if let textURL = files.first(where: { $0.pathExtension == "txt" }),
           let text = try? String(contentsOf: textURL),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        if !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stdout
        }

        throw TranscriptionError.missingOutput
    }
}

private struct STTOutput: Decodable {
    let text: String
}
