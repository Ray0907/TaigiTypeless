import ApplicationServices
import Foundation

@MainActor
enum Permissions {
    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
