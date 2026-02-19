import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "HWP Quick Look"
        window?.center()

        let textField = NSTextField(labelWithString: "HWP Quick Look plugin is installed.\nYou can now preview .hwp files in Finder.")
        textField.alignment = .center
        textField.frame = NSRect(x: 40, y: 100, width: 400, height: 100)
        window?.contentView?.addSubview(textField)

        window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
