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

            let htmlString = try fileData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String in
                guard let baseAddress = buffer.baseAddress else {
                    throw PreviewError.invalidData
                }

                var outHtml: UnsafeMutablePointer<CChar>?
                var outLen: UInt = 0

                let result = hwp_parse_to_html(
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    UInt(fileData.count),
                    &outHtml,
                    &outLen
                )

                logger.info("hwp_parse_to_html result: \(result), html_len: \(outLen)")

                guard result == HWP_OK, let htmlPtr = outHtml else {
                    throw PreviewError.parseFailed(code: result)
                }

                let html = String(cString: htmlPtr)
                hwp_free_string(htmlPtr)
                return html
            }

            let htmlData = Data(htmlString.utf8)
            logger.info("HTML generated: \(htmlData.count) bytes")

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

enum PreviewError: Error, LocalizedError {
    case invalidData
    case parseFailed(code: Int32)

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid HWP data"
        case .parseFailed(let code): return "HWP parse failed with code: \(code)"
        }
    }
}
