import AppKit
import Foundation

@MainActor
final class ClipboardTyper {
    func paste(_ text: String) throws {
        guard Permissions.accessibilityTrusted(prompt: true) else {
            setClipboard(text)
            throw ClipboardTyperError.accessibilityPermissionMissing
        }

        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendCommandV()

        usleep(350_000)
        pasteboard.clearContents()
        if let originalString {
            pasteboard.setString(originalString, forType: .string)
        }
    }

    func setClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum ClipboardTyperError: Error, LocalizedError {
    case accessibilityPermissionMissing

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required to paste into the focused app. The transcription was copied to the clipboard, so you can press Command-V manually. To enable automatic paste, restart Taigi Typeless after enabling it in System Settings > Privacy & Security > Accessibility."
        }
    }
}
