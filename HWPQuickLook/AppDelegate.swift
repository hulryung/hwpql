import SwiftUI
import WebKit

@main
struct HWPQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

struct InfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("HWP Quick Look")
                .font(.title)
                .fontWeight(.semibold)
            Text("Preview .hwp and .hwpx files in Finder.\nSelect a file and press Space, or double-click to open.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let supportedExtensions: Set<String> = ["hwp", "hwpx"]

    private var viewerWindows: [NSWindow] = []
    private var infoWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch Services routes files via application(_:open:) which fires
        // BEFORE this method; the CLI-arg loop only covers direct binary invocation.
        for arg in ProcessInfo.processInfo.arguments.dropFirst() {
            let url = URL(fileURLWithPath: arg)
            if Self.supportedExtensions.contains(url.pathExtension.lowercased()) {
                openHWPFile(url)
            }
        }

        if viewerWindows.isEmpty {
            showInfoWindow()
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls {
            openHWPFile(url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openHWPFile(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for f in filenames {
            openHWPFile(URL(fileURLWithPath: f))
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func showInfoWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HWP Quick Look"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: InfoView())

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        infoWindow = window
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
            htmlString = try fileData.withUnsafeBytes { buffer -> String in
                guard let base = buffer.baseAddress else {
                    throw HWPError.invalidData
                }
                var outHtml: UnsafeMutablePointer<CChar>?
                var outLen: UInt = 0
                let result = hwp_parse_to_html(
                    base.assumingMemoryBound(to: UInt8.self),
                    UInt(fileData.count),
                    &outHtml,
                    &outLen
                )
                guard result == HWP_OK, let htmlPtr = outHtml else {
                    throw HWPError.parseFailed(code: result)
                }
                defer { hwp_free_string(htmlPtr) }
                return String(cString: htmlPtr)
            }
        } catch {
            showError("Failed to parse HWP file: \(error.localizedDescription)")
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 1100),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.deletingPathExtension().lastPathComponent
        window.center()
        window.isReleasedWhenClosed = false

        let webView = WKWebView(frame: window.contentView!.bounds)
        webView.autoresizingMask = [.width, .height]
        webView.loadHTMLString(htmlString, baseURL: nil)
        window.contentView?.addSubview(webView)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewerWindows.append(window)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.viewerWindows.removeAll { $0 === window }
        }

        infoWindow?.close()
        infoWindow = nil
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
