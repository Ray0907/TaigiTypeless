import Foundation

final class PersistentTranscriptionWorker: @unchecked Sendable {
    static let shared = PersistentTranscriptionWorker()

    private let lock = NSLock()
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutReader: LineReader?
    private var stderrPipe: Pipe?

    private init() {}

    func transcribe(audioPath: String, configuration: AppConfiguration) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        try ensureStarted(configuration: configuration)
        guard let stdinPipe, let stdoutReader else {
            throw TranscriptionError.commandFailed("Persistent transcription worker is not available.")
        }

        let request = WorkerRequest(
            id: UUID().uuidString,
            audio: audioPath,
            outputDirectory: configuration.workingDirectory,
            language: configuration.language,
            maxTokens: configuration.maxTokens
        )
        let requestData = try JSONEncoder().encode(request)
        guard let requestLine = String(data: requestData, encoding: .utf8) else {
            throw TranscriptionError.commandFailed("Could not encode transcription request.")
        }

        try stdinPipe.fileHandleForWriting.write(contentsOf: Data((requestLine + "\n").utf8))

        guard let responseLine = stdoutReader.readLine() else {
            restartAfterFailure()
            throw TranscriptionError.commandFailed("Persistent transcription worker exited before returning a response.")
        }

        let response: WorkerResponse
        do {
            let responseData = Data(responseLine.utf8)
            response = try JSONDecoder().decode(WorkerResponse.self, from: responseData)
        } catch {
            restartAfterFailure()
            throw TranscriptionError.commandFailed("Persistent transcription worker returned invalid JSON: \(responseLine)")
        }

        guard response.id == request.id else {
            restartAfterFailure()
            throw TranscriptionError.commandFailed("Persistent transcription worker response id did not match request id.")
        }

        guard response.ok else {
            throw TranscriptionError.commandFailed(response.error ?? "Persistent transcription worker failed.")
        }

        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.noSpeechDetected }
        return text
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        restartAfterFailure()
    }

    private func ensureStarted(configuration: AppConfiguration) throws {
        if process?.isRunning == true { return }

        guard let workerScriptPath = configuration.workerScriptPath else {
            throw TranscriptionError.commandFailed("Missing persistent transcription worker script.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: configuration.pythonPath)
        process.arguments = [
            "-u", workerScriptPath,
            "--model", configuration.modelPath,
            "--language", configuration.language,
            "--max-tokens", String(configuration.maxTokens)
        ]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        try process.run()

        let reader = LineReader(fileHandle: stdoutPipe.fileHandleForReading)
        do {
            guard let readyLine = reader.readLine() else {
                throw TranscriptionError.commandFailed("Persistent transcription worker exited during startup.")
            }

            let readyData = Data(readyLine.utf8)
            let ready = try JSONDecoder().decode(WorkerReady.self, from: readyData)
            guard ready.event == "ready" else {
                throw TranscriptionError.commandFailed("Persistent transcription worker returned unexpected startup output: \(readyLine)")
            }
        } catch let error as TranscriptionError {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            process.terminate()
            throw error
        } catch {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            process.terminate()
            throw TranscriptionError.commandFailed("Persistent transcription worker returned invalid startup output: \(error.localizedDescription)")
        }

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutReader = reader
        self.stderrPipe = stderrPipe
    }

    private func restartAfterFailure() {
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        try? stdinPipe?.fileHandleForWriting.close()
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutReader = nil
        stderrPipe = nil
    }
}

private struct WorkerReady: Decodable {
    let event: String
}

private struct WorkerRequest: Encodable {
    let id: String
    let audio: String
    let outputDirectory: String
    let language: String
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case id
        case audio
        case outputDirectory = "output_dir"
        case language
        case maxTokens = "max_tokens"
    }
}

private struct WorkerResponse: Decodable {
    let id: String?
    let ok: Bool
    let text: String
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ok
        case text
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        ok = try container.decode(Bool.self, forKey: .ok)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

private final class LineReader {
    private let fileHandle: FileHandle
    private var buffer = Data()

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func readLine() -> String? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newlineIndex]
                buffer.removeSubrange(...newlineIndex)
                return String(data: lineData, encoding: .utf8)
            }

            let chunk = fileHandle.readData(ofLength: 1024)
            if chunk.isEmpty {
                guard !buffer.isEmpty else { return nil }
                let line = String(data: buffer, encoding: .utf8)
                buffer.removeAll()
                return line
            }
            buffer.append(chunk)
        }
    }
}
