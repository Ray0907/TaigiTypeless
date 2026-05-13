import Foundation

struct TranscriptionCommand {
    let pythonPath: String
    let modelPath: String
    let audioPath: String
    let outputDirectory: String
    let language: String
    let maxTokens: Int

    var executable: String {
        pythonPath
    }

    var outputPath: String {
        URL(fileURLWithPath: outputDirectory, isDirectory: true)
            .appendingPathComponent("transcript")
            .path
    }

    var arguments: [String] {
        [
            "-m", "mlx_audio.stt.generate",
            "--model", modelPath,
            "--audio", audioPath,
            "--output-path", outputPath,
            "--format", "json",
            "--language", language,
            "--max-tokens", String(maxTokens)
        ]
    }
}
