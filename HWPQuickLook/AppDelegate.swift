import SwiftUI
import UniformTypeIdentifiers
import WebKit
import PDFKit

@main
struct HWPQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            HWPCommands(
                state: appDelegate.state,
                openFile: { appDelegate.openFileAction(nil) },
                openURL: { appDelegate.openHWPFile($0) },
                exportPDF: { appDelegate.exportPDFAction(nil) },
                printCurrent: { appDelegate.printAction(nil) },
                zoomIn: { appDelegate.zoomIn(nil) },
                zoomOut: { appDelegate.zoomOut(nil) },
                actualSize: { appDelegate.actualSize(nil) }
            )
        }
    }
}

// MARK: - App state (SwiftUI-observable)

final class AppState: ObservableObject {
    @Published private(set) var recentDocuments: [URL] = []

    private let storageKey = "RecentDocuments"
    private let maxEntries = 10

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        self.recentDocuments = paths.map { URL(fileURLWithPath: $0) }
    }

    func add(_ url: URL) {
        var list = recentDocuments
        list.removeAll { $0.path == url.path }
        list.insert(url, at: 0)
        if list.count > maxEntries {
            list = Array(list.prefix(maxEntries))
        }
        recentDocuments = list
        persist()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func removeMissing(_ url: URL) {
        recentDocuments.removeAll { $0.path == url.path }
        persist()
    }

    func clear() {
        recentDocuments = []
        persist()
        NSDocumentController.shared.clearRecentDocuments(nil)
    }

    private func persist() {
        UserDefaults.standard.set(recentDocuments.map(\.path), forKey: storageKey)
    }
}

// MARK: - Commands (SwiftUI menus)

struct HWPCommands: Commands {
    @ObservedObject var state: AppState
    let openFile: () -> Void
    let openURL: (URL) -> Void
    let exportPDF: () -> Void
    let printCurrent: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let actualSize: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { openFile() }
                .keyboardShortcut("o", modifiers: [.command])

            Menu("Open Recent") {
                if state.recentDocuments.isEmpty {
                    Text("No Recent Documents")
                } else {
                    ForEach(state.recentDocuments, id: \.self) { url in
                        Button(url.lastPathComponent) { openURL(url) }
                    }
                    Divider()
                    Button("Clear Menu") { state.clear() }
                }
            }
        }
        CommandGroup(replacing: .printItem) {
            Button("Export as PDF…") { exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Print…") { printCurrent() }
                .keyboardShortcut("p", modifiers: [.command])
        }
        CommandMenu("View") {
            Button("Zoom In") { zoomIn() }
                .keyboardShortcut("=", modifiers: [.command])
            Button("Zoom Out") { zoomOut() }
                .keyboardShortcut("-", modifiers: [.command])
            Button("Actual Size") { actualSize() }
                .keyboardShortcut("0", modifiers: [.command])
        }
    }
}

// MARK: - Info window content

struct InfoView: View {
    var onDrop: ([URL]) -> Void = { _ in }

    @State private var isTargeted = false

    private var versionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(shortVersion) · rhwp \(HWPLibrary.rhwpVersion)"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("HWP Quick Look")
                .font(.title)
                .fontWeight(.semibold)
            Text("Preview .hwp and .hwpx files in Finder.\nSelect a file and press Space, or drop a file here to open.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: isTargeted ? 3 : 0)
                .padding(12)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { urls.append(url) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                onDrop(urls)
            }
            return true
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let supportedExtensions: Set<String> = ["hwp", "hwpx"]

    let state = AppState()

    private var viewerWindows: [NSWindow] = []
    private var infoWindow: NSWindow?
    private var pinchMonitor: Any?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        installPinchMonitor()
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: File opening entry points

    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls { openHWPFile(url) }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openHWPFile(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for f in filenames { openHWPFile(URL(fileURLWithPath: f)) }
        sender.reply(toOpenOrPrint: .success)
    }

    // MARK: Menu actions

    @objc func openFileAction(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = Self.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { openHWPFile(url) }
    }

    @objc func exportPDFAction(_ sender: Any?) {
        guard let window = NSApp.keyWindow as? DocumentWindow, let fileURL = window.fileURL else {
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".pdf"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let fileData = try Data(contentsOf: fileURL)
                let pdfData = try HWPLibrary.renderPDF(fileData)
                try pdfData.write(to: destinationURL)
            } catch {
                DispatchQueue.main.async {
                    self?.showError("Failed to export PDF: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func printAction(_ sender: Any?) {
        guard let window = NSApp.keyWindow,
              let webView = window.contentView?.subviews.compactMap({ $0 as? WKWebView }).first else {
            NSSound.beep()
            return
        }

        guard let fileURL = (window as? DocumentWindow)?.fileURL else {
            printWithWebView(webView, window: window)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak window, weak webView] in
            let pdfDocument: PDFDocument? = {
                guard let fileData = try? Data(contentsOf: fileURL),
                      let pdfData = try? HWPLibrary.renderPDF(fileData) else { return nil }
                return PDFDocument(data: pdfData)
            }()

            DispatchQueue.main.async {
                guard let window else { return }
                if let pdfDocument,
                   let op = pdfDocument.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: true) {
                    op.showsPrintPanel = true
                    op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
                } else if let webView {
                    self?.printWithWebView(webView, window: window)
                }
            }
        }
    }

    private func printWithWebView(_ webView: WKWebView, window: NSWindow) {
        let op = webView.printOperation(with: NSPrintInfo.shared)
        op.showsPrintPanel = true
        op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    @objc func zoomIn(_ sender: Any?) {
        guard let webView = currentWebView() else { NSSound.beep(); return }
        let next = min(webView.magnification + 0.1, ZoomableWebView.maxZoom)
        webView.magnification = next
    }

    @objc func zoomOut(_ sender: Any?) {
        guard let webView = currentWebView() else { NSSound.beep(); return }
        let next = max(webView.magnification - 0.1, ZoomableWebView.minZoom)
        webView.magnification = next
    }

    @objc func actualSize(_ sender: Any?) {
        guard let webView = currentWebView() else { NSSound.beep(); return }
        webView.magnification = 1.0
    }

    private func currentWebView() -> WKWebView? {
        NSApp.keyWindow?.contentView?.subviews.compactMap { $0 as? WKWebView }.first
    }

    private func installPinchMonitor() {
        pinchMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let webView = self?.currentWebView(),
                  let window = webView.window,
                  event.window === window else { return event }
            let viewPoint = webView.convert(event.locationInWindow, from: nil)
            let next = webView.magnification + event.magnification
            let clamped = min(max(next, ZoomableWebView.minZoom), ZoomableWebView.maxZoom)
            webView.setMagnification(clamped, centeredAt: viewPoint)
            return nil
        }
    }

    // MARK: Windows

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
        window.contentView = NSHostingView(rootView: InfoView(onDrop: { [weak self] urls in
            self?.openDroppedURLs(urls)
        }))

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        infoWindow = window
    }

    private func openDroppedURLs(_ urls: [URL]) {
        for url in urls where Self.supportedExtensions.contains(url.pathExtension.lowercased()) {
            openHWPFile(url)
        }
    }

    func openHWPFile(_ url: URL) {
        // Missing file path from the Open Recent menu: prune and notify.
        guard FileManager.default.fileExists(atPath: url.path) else {
            state.removeMissing(url)
            showError("File no longer exists:\n\(url.path)")
            return
        }

        let window = DocumentWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 1100),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.deletingPathExtension().lastPathComponent
        window.fileURL = url
        window.center()
        window.isReleasedWhenClosed = false

        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.isIndeterminate = true
        progress.sizeToFit()
        if let contentBounds = window.contentView?.bounds {
            progress.frame.origin = CGPoint(
                x: (contentBounds.width - progress.frame.width) / 2,
                y: (contentBounds.height - progress.frame.height) / 2
            )
        }
        progress.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        window.contentView?.addSubview(progress)
        progress.startAnimation(nil)

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

        state.add(url)

        infoWindow?.close()
        infoWindow = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak window] in
            do {
                let fileData = try Data(contentsOf: url)
                let htmlString = try HWPLibrary.parseToHTML(fileData)
                DispatchQueue.main.async {
                    guard let window else { return }
                    progress.stopAnimation(nil)
                    progress.removeFromSuperview()

                    let webView = ZoomableWebView(frame: window.contentView!.bounds)
                    webView.autoresizingMask = [.width, .height]
                    webView.allowsMagnification = true
                    webView.loadHTMLString(htmlString, baseURL: nil)
                    window.contentView?.addSubview(webView)
                    window.contentView?.registerForDraggedTypes([.fileURL])
                }
            } catch {
                DispatchQueue.main.async {
                    window?.close()
                    self?.showError("Failed to open file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - Document window (remembers its source file for print/export)

final class DocumentWindow: NSWindow {
    var fileURL: URL!
}

// MARK: - WKWebView with trackpad pinch zoom

final class ZoomableWebView: WKWebView {
    static let minZoom: CGFloat = 0.25
    static let maxZoom: CGFloat = 3.0
}
