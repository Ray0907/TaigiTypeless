import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configuration = AppConfiguration.load()
    private let recorder = AudioRecorder()
    private let hotKeyManager = HotKeyManager()
    private let typer = ClipboardTyper()
    private let polisher = TextPolisher()
    private var statusItem: NSStatusItem?
    private var currentRecordingURL: URL?
    private var lastText = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        updateStatus("台", tooltip: "Taigi Typeless: Option-Space to record")
        requestPermissions()

        do {
            try hotKeyManager.registerOptionSpace { [weak self] in
                Task { @MainActor in
                    self?.toggleRecording()
                }
            }
        } catch {
            showError("Could not register Option-Space hotkey: \(error)")
        }
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start / Stop Recording (Option-Space)", action: #selector(toggleRecordingFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste Last Result", action: #selector(pasteLastResult), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func requestPermissions() {
        _ = Permissions.accessibilityTrusted(prompt: true)
        recorder.requestMicrophoneAccess { [weak self] granted in
            if !granted {
                DispatchQueue.main.async {
                    self?.showError("Microphone permission is required for Taigi Typeless.")
                }
            }
        }
    }

    @objc private func toggleRecordingFromMenu() {
        toggleRecording()
    }

    private func toggleRecording() {
        if recorder.isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        do {
            currentRecordingURL = try recorder.startRecording()
            updateStatus("●", tooltip: "Recording Taigi. Press Option-Space to stop.")
        } catch {
            showError("Could not start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndTranscribe() {
        guard let audioURL = recorder.stopRecording() ?? currentRecordingURL else { return }
        currentRecordingURL = nil
        updateStatus("…", tooltip: "Transcribing locally with MLX")

        let runner = TranscriptionRunner(configuration: configuration, polisher: polisher)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let text = try runner.transcribe(audioPath: audioURL.path)
                DispatchQueue.main.async {
                    self?.handleTranscription(text)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showError("Transcription failed: \(error.localizedDescription)")
                    self?.updateStatus("台", tooltip: "Taigi Typeless: Option-Space to record")
                }
            }
        }
    }

    private func handleTranscription(_ text: String) {
        guard !text.isEmpty else {
            updateStatus("台", tooltip: "No speech detected")
            return
        }

        lastText = text
        typer.paste(text)
        updateStatus("✓", tooltip: "Pasted transcription")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.updateStatus("台", tooltip: "Taigi Typeless: Option-Space to record")
        }
    }

    @objc private func pasteLastResult() {
        guard !lastText.isEmpty else { return }
        typer.paste(lastText)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatus(_ title: String, tooltip: String) {
        statusItem?.button?.title = title
        statusItem?.button?.toolTip = tooltip
    }

    private func showError(_ message: String) {
        updateStatus("!", tooltip: message)
        let alert = NSAlert()
        alert.messageText = "Taigi Typeless"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
