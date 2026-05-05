import Foundation

struct TranscriptionCommand {
    let pythonPath: String
    let modelPath: String
    let audioPath: String
    let outputDirectory: String

    var executable: String {
        pythonPath
    }

    var arguments: [String] {
        [
            "-m", "mlx_audio.stt.generate",
            "--model", modelPath,
            "--audio", audioPath,
            "--output-path", outputDirectory,
            "--format", "json",
            "--language", "zh"
        ]
    }
}
