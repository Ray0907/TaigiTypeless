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
    private var activityTitle = "Ready"
    private var loadingTimer: Timer?
    private var loadingFrameIndex = 0
    private let loadingFrames = ["◐", "◓", "◑", "◒"]
    private var statusLabels: [NSTextField] = []
    private var accessibilityLabels: [NSTextField] = []
    private var resultTextViews: [NSTextView] = []
    private var statusWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        updateStatus("Taigi", tooltip: "Taigi Typeless: Option-Space to record")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showStatusWindow()
        }
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

        if let launchAudioURL = launchTranscriptionAudioURL() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.transcribeAndPaste(audioURL: launchAudioURL)
            }
        }
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 88)
        self.statusItem = statusItem
        statusItem.isVisible = true
        statusItem.button?.font = .systemFont(ofSize: 13, weight: .semibold)

        let menu = NSMenu()
        let panelItem = NSMenuItem()
        panelItem.view = makeStatusPanelView()
        menu.addItem(panelItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Start / Stop Recording (Option-Space)", action: #selector(toggleRecordingFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Status Window", action: #selector(showStatusWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Last Result", action: #selector(copyLastResult), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste Last Result", action: #selector(pasteLastResult), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func makeStatusPanelView() -> NSView {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 210))

        let title = NSTextField(labelWithString: "Taigi Typeless")
        title.font = .boldSystemFont(ofSize: 14)
        title.frame = NSRect(x: 14, y: 178, width: 310, height: 18)
        panel.addSubview(title)

        let statusLabel = NSTextField(labelWithString: activityStatusTitle())
        statusLabel.frame = NSRect(x: 14, y: 154, width: 310, height: 18)
        panel.addSubview(statusLabel)
        statusLabels.append(statusLabel)

        let accessibilityLabel = NSTextField(labelWithString: accessibilityStatusTitle())
        accessibilityLabel.frame = NSRect(x: 14, y: 132, width: 310, height: 18)
        panel.addSubview(accessibilityLabel)
        accessibilityLabels.append(accessibilityLabel)

        let resultLabel = NSTextField(labelWithString: "Last result")
        resultLabel.font = .systemFont(ofSize: 11, weight: .medium)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.frame = NSRect(x: 14, y: 110, width: 310, height: 16)
        panel.addSubview(resultLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 14, y: 14, width: 312, height: 92))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 13)
        textView.string = "No transcription yet."
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scrollView.documentView = textView
        panel.addSubview(scrollView)
        resultTextViews.append(textView)

        return panel
    }

    @objc private func showStatusWindow() {
        if let statusWindow {
            statusWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 250),
            styleMask: [.titled, .closable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Taigi Typeless"
        window.center()
        window.contentView = makeStatusWindowView()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        statusWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeStatusWindowView() -> NSView {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 250))

        let title = NSTextField(labelWithString: "Taigi Typeless")
        title.font = .boldSystemFont(ofSize: 18)
        title.frame = NSRect(x: 18, y: 212, width: 340, height: 24)
        panel.addSubview(title)

        let statusLabel = NSTextField(labelWithString: activityStatusTitle())
        statusLabel.frame = NSRect(x: 18, y: 184, width: 340, height: 18)
        panel.addSubview(statusLabel)
        statusLabels.append(statusLabel)

        let accessibilityLabel = NSTextField(labelWithString: accessibilityStatusTitle())
        accessibilityLabel.frame = NSRect(x: 18, y: 160, width: 340, height: 18)
        panel.addSubview(accessibilityLabel)
        accessibilityLabels.append(accessibilityLabel)

        let resultLabel = NSTextField(labelWithString: "Last result")
        resultLabel.font = .systemFont(ofSize: 11, weight: .medium)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.frame = NSRect(x: 18, y: 135, width: 340, height: 16)
        panel.addSubview(resultLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 18, y: 18, width: 344, height: 112))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 14)
        textView.string = lastText.isEmpty ? "No transcription yet." : lastText
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scrollView.documentView = textView
        panel.addSubview(scrollView)
        resultTextViews.append(textView)

        return panel
    }

    @objc private func refreshStatusMenu() {
        refreshStatusMenuItems()
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
            setActivity("Recording")
            updateStatus("Taigi ●", tooltip: "Recording Taigi. Press Option-Space to stop.")
        } catch {
            showError("Could not start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndTranscribe() {
        do {
            guard let audioURL = try recorder.stopRecording() ?? currentRecordingURL else { return }
            currentRecordingURL = nil
            transcribeAndPaste(audioURL: audioURL)
        } catch {
            currentRecordingURL = nil
            stopLoadingStatus()
            updateStatus("Taigi", tooltip: "Taigi Typeless: Option-Space to record")
            showError("Could not finish recording: \(error.localizedDescription)")
        }
    }

    private func transcribeAndPaste(audioURL: URL) {
        startLoadingStatus()

        let runner = TranscriptionRunner(configuration: configuration, polisher: polisher)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let text = try runner.transcribe(audioPath: audioURL.path)
                DispatchQueue.main.async {
                    self?.handleTranscription(text)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.stopLoadingStatus()
                    self?.showError("Transcription failed: \(error.localizedDescription)")
                    self?.updateStatus("Taigi", tooltip: "Taigi Typeless: Option-Space to record")
                }
            }
        }
    }

    private func launchTranscriptionAudioURL() -> URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--transcribe-on-launch"),
              arguments.indices.contains(index + 1) else {
            return nil
        }

        return URL(fileURLWithPath: arguments[index + 1])
    }

    private func handleTranscription(_ text: String) {
        guard !text.isEmpty else {
            updateStatus("Taigi", tooltip: "No speech detected")
            return
        }

        lastText = text
        updateResultText(text)
        do {
            try typer.paste(text)
            stopLoadingStatus()
            setActivity("Pasted")
            updateStatus("Taigi ✓", tooltip: "Pasted transcription")
        } catch {
            stopLoadingStatus()
            setActivity("Copied to clipboard")
            showError("Transcription succeeded, but paste failed: \(error.localizedDescription)")
            updateStatus("Taigi C", tooltip: "Transcription copied to clipboard. Press Command-V manually.")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.updateStatus("Taigi", tooltip: "Taigi Typeless: Option-Space to record")
        }
    }

    @objc private func copyLastResult() {
        guard !lastText.isEmpty else { return }
        typer.setClipboard(lastText)
        setActivity("Copied to clipboard")
        updateStatus("Taigi C", tooltip: "Transcription copied to clipboard.")
    }

    @objc private func pasteLastResult() {
        guard !lastText.isEmpty else { return }
        do {
            try typer.paste(lastText)
        } catch {
            showError("Could not paste last result: \(error.localizedDescription)")
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() {
        loadingTimer?.invalidate()
        PersistentTranscriptionWorker.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    private func updateStatus(_ title: String, tooltip: String) {
        statusItem?.button?.title = title
        statusItem?.button?.toolTip = tooltip
        refreshStatusMenuItems()
    }

    private func setActivity(_ title: String) {
        activityTitle = title
        refreshStatusMenuItems()
    }

    private func startLoadingStatus() {
        loadingTimer?.invalidate()
        loadingFrameIndex = 0
        setActivity("Recognizing with MLX")
        advanceLoadingStatus()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceLoadingStatus()
            }
        }
    }

    private func stopLoadingStatus() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }

    private func advanceLoadingStatus() {
        let frame = loadingFrames[loadingFrameIndex % loadingFrames.count]
        loadingFrameIndex += 1
        statusItem?.button?.title = "Taigi \(frame)"
        statusItem?.button?.toolTip = "Recognizing locally with MLX"
        refreshStatusMenuItems(prefix: frame)
    }

    private func refreshStatusMenuItems(prefix: String? = nil) {
        statusLabels.forEach { $0.stringValue = activityStatusTitle(prefix: prefix) }
        accessibilityLabels.forEach { $0.stringValue = accessibilityStatusTitle() }
    }

    private func updateResultText(_ text: String) {
        resultTextViews.forEach { $0.string = text.isEmpty ? "No transcription yet." : text }
    }

    private func activityStatusTitle(prefix: String? = nil) -> String {
        if let prefix {
            return "Status: \(prefix) \(activityTitle)"
        }
        return "Status: \(activityTitle)"
    }

    private func accessibilityStatusTitle() -> String {
        let status = Permissions.accessibilityTrusted(prompt: false) ? "on" : "off"
        return "Accessibility: \(status)"
    }

    private func showError(_ message: String) {
        updateStatus("Taigi !", tooltip: message)
        let alert = NSAlert()
        alert.messageText = "Taigi Typeless"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
