import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestMicrophoneAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    func startRecording() throws -> URL {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TaigiTypeless", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("recording-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw AudioRecorderError.recordingDidNotStart
        }
        self.recorder = recorder
        return url
    }

    func stopRecording() throws -> URL? {
        guard let recorder else { return nil }
        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil

        guard duration >= 0.5 else {
            throw AudioRecorderError.recordingTooShort
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > 4_096 else {
            throw AudioRecorderError.emptyRecording
        }

        return url
    }
}

enum AudioRecorderError: Error, LocalizedError {
    case microphonePermissionDenied
    case recordingDidNotStart
    case recordingTooShort
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required. Enable Taigi Typeless in System Settings > Privacy & Security > Microphone."
        case .recordingDidNotStart:
            return "Recording did not start. Check Microphone permission and input device settings."
        case .recordingTooShort:
            return "Recording was too short. Hold Option-Space once to start, speak for at least one second, then press Option-Space again to stop."
        case .emptyRecording:
            return "Recording was empty. Check your microphone input device and make sure Taigi Typeless has Microphone permission."
        }
    }
}
