import Cocoa
import WebKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    private var launchedWithFiles = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If no files were opened, show the info window
        DispatchQueue.main.async {
            if !self.launchedWithFiles {
                self.showInfoWindow()
            }
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        launchedWithFiles = true
        for url in urls {
            openHWPFile(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func showInfoWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HWP Quick Look"
        window.center()

        let textField = NSTextField(labelWithString: "HWP Quick Look plugin is installed.\nYou can now preview .hwp files in Finder.")
        textField.alignment = .center
        textField.frame = NSRect(x: 40, y: 100, width: 400, height: 100)
        window.contentView?.addSubview(textField)

        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    private func openHWPFile(_ url: URL) {
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            showError("Failed to read file: \(error.localizedDescription)")
            return
        }

        let htmlString: String
        do {
            htmlString = try fileData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String in
                guard let baseAddress = buffer.baseAddress else {
                    throw HWPError.invalidData
                }

                var outHtml: UnsafeMutablePointer<CChar>?
                var outLen: UInt = 0

                let result = hwp_parse_to_html(
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    UInt(fileData.count),
                    &outHtml,
                    &outLen
                )

                guard result == HWP_OK, let htmlPtr = outHtml else {
                    throw HWPError.parseFailed(code: result)
                }

                let html = String(cString: htmlPtr)
                hwp_free_string(htmlPtr)
                return html
            }
        } catch {
            showError("Failed to parse HWP file: \(error.localizedDescription)")
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.deletingPathExtension().lastPathComponent
        window.center()
        window.setFrameAutosaveName("HWPViewer-\(url.lastPathComponent)")

        let webView = WKWebView(frame: window.contentView!.bounds)
        webView.autoresizingMask = [.width, .height]
        webView.loadHTMLString(htmlString, baseURL: nil)
        window.contentView?.addSubview(webView)

        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private enum HWPError: Error, LocalizedError {
    case invalidData
    case parseFailed(code: Int32)

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid HWP data"
        case .parseFailed(let code): return "HWP parse failed with code: \(code)"
        }
    }
}
