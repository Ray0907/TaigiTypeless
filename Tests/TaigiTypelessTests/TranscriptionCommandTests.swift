import Testing
@testable import TaigiTypeless

@Test func transcriptionCommandUsesLocalModelAndJsonOutput() {
    let command = TranscriptionCommand(
        pythonPath: "/app/.venv/bin/python",
        modelPath: "/models/Breeze-ASR-26-mlx-4bit",
        audioPath: "/tmp/input.wav",
        outputDirectory: "/tmp/out"
    )

    #expect(command.executable == "/app/.venv/bin/python")
    #expect(command.arguments == [
        "-m", "mlx_audio.stt.generate",
        "--model", "/models/Breeze-ASR-26-mlx-4bit",
        "--audio", "/tmp/input.wav",
        "--output-path", "/tmp/out",
        "--format", "json",
        "--language", "zh"
    ])
}
