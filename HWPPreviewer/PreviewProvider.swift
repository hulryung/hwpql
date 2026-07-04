import QuickLookUI
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.hwpql.HWPPreviewer", category: "preview")

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        logger.info("providePreview called for: \(request.fileURL.path)")

        do {
            let fileData = try Data(contentsOf: request.fileURL)
            logger.info("File loaded: \(fileData.count) bytes")

            let htmlString = try HWPLibrary.parseToHTML(fileData)
            logger.info("HTML generated, length: \(htmlString.utf8.count)")

            let htmlData = Data(htmlString.utf8)

            let reply = QLPreviewReply(
                dataOfContentType: UTType.html,
                contentSize: CGSize(width: 800, height: 1200)
            ) { _ in
                return htmlData
            }
            reply.stringEncoding = .utf8
            reply.title = request.fileURL.deletingPathExtension().lastPathComponent

            logger.info("Returning QLPreviewReply successfully")
            handler(reply, nil)
        } catch {
            logger.error("Preview error: \(error.localizedDescription)")
            handler(nil, error)
        }
    }
}
