import Foundation
import Testing
@testable import TaigiTypeless

@Test func transcriptionCommandUsesLocalModelAndJsonOutput() {
    let command = TranscriptionCommand(
        pythonPath: "/app/.venv/bin/python",
        modelPath: "/models/Breeze-ASR-26-mlx-4bit",
        audioPath: "/tmp/input.wav",
        outputDirectory: "/tmp/out",
        language: "zh",
        maxTokens: 512
    )

    #expect(command.executable == "/app/.venv/bin/python")
    #expect(command.arguments == [
        "-m", "mlx_audio.stt.generate",
        "--model", "/models/Breeze-ASR-26-mlx-4bit",
        "--audio", "/tmp/input.wav",
        "--output-path", "/tmp/out/transcript",
        "--format", "json",
        "--language", "zh",
        "--max-tokens", "512"
    ])
}

@Test func appConfigurationKeepsPersistentWorkerInEnvironmentLaunches() {
    let cwd = FileManager.default.currentDirectoryPath
    let configuration = AppConfiguration.load(environment: [
        "TAIGI_TYPELESS_PYTHON": "/app/.venv/bin/python",
        "TAIGI_TYPELESS_MODEL": "/models/Breeze-ASR-26-mlx-4bit"
    ])

    #expect(configuration.workerScriptPath == "\(cwd)/scripts/stt_worker.py")
}

@Test func appConfigurationRespectsExplicitWorkerOverride() {
    let configuration = AppConfiguration.load(environment: [
        "TAIGI_TYPELESS_PYTHON": "/app/.venv/bin/python",
        "TAIGI_TYPELESS_MODEL": "/models/Breeze-ASR-26-mlx-4bit",
        "TAIGI_TYPELESS_WORKER": "/custom/stt_worker.py",
        "TAIGI_TYPELESS_MAX_TOKENS": "256"
    ])

    #expect(configuration.workerScriptPath == "/custom/stt_worker.py")
    #expect(configuration.maxTokens == 256)
}
