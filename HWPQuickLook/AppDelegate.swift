import SwiftUI
import UniformTypeIdentifiers
import WebKit

@main
struct HWPQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    appDelegate.openFileAction(nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                // Placeholder; AppDelegate replaces this with a live Open Recent menu
                // after launch via NSApp.mainMenu manipulation, since SwiftUI does
                // not natively support dynamic menu contents driven by NSDocumentController.
            }
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let supportedExtensions: Set<String> = ["hwp", "hwpx"]

    private var viewerWindows: [NSWindow] = []
    private var infoWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI builds its own menu bar asynchronously; inject the Open Recent
        // submenu after it finishes. NSMenuDelegate repopulates on each open.
        DispatchQueue.main.async { [weak self] in
            self?.installOpenRecentMenu()
        }

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

    // MARK: - Menu bar

    private func installOpenRecentMenu() {
        guard let fileMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "File" })?.submenu else {
            return
        }
        // Avoid double-inserting if this runs more than once.
        if fileMenu.items.contains(where: { $0.title == "Open Recent" }) {
            return
        }

        let openRecentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.delegate = self
        openRecentItem.submenu = openRecentMenu

        // Insert right after the Open… item if present, otherwise at top.
        let openIndex = fileMenu.items.firstIndex { $0.title.hasPrefix("Open") } ?? -1
        fileMenu.insertItem(openRecentItem, at: openIndex + 1)
    }

    @objc func openFileAction(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = Self.supportedExtensions.compactMap { ext in
            UTType(filenameExtension: ext)
        }
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            openHWPFile(url)
        }
    }

    @objc private func openRecentDocumentAction(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            openHWPFile(url)
        } else {
            showError("File no longer exists:\n\(url.path)")
        }
    }

    @objc private func clearRecentDocumentsAction(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
    }

    // NSMenuDelegate: populate Open Recent just before display
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Open Recent" else { return }
        menu.removeAllItems()

        let recents = NSDocumentController.shared.recentDocumentURLs
        if recents.isEmpty {
            let empty = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for url in recents {
            let item = NSMenuItem(title: url.lastPathComponent,
                                  action: #selector(openRecentDocumentAction(_:)),
                                  keyEquivalent: "")
            item.representedObject = url
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear Menu",
                               action: #selector(clearRecentDocumentsAction(_:)),
                               keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
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

        NSDocumentController.shared.noteNewRecentDocumentURL(url)

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
