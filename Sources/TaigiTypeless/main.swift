import AppKit

private let retainedDelegate = AppDelegate()

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.delegate = retainedDelegate
app.run()
