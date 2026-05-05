import AppKit
import Foundation

@MainActor
final class ClipboardTyper {
    func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems?.compactMap { $0.copy() as? NSPasteboardItem } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendCommandV()

        usleep(350_000)
        pasteboard.clearContents()
        if !originalItems.isEmpty {
            pasteboard.writeObjects(originalItems)
        }
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
