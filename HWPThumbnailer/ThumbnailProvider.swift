import QuickLookThumbnailing
import AppKit
import CoreGraphics

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL

        guard let fileData = try? Data(contentsOf: fileURL) else {
            handler(nil, ThumbnailError.invalidData)
            return
        }

        if let nsImage = try? previewNSImage(from: fileData) {
            handler(makeReply(for: nsImage, maxSize: request.maximumSize), nil)
            return
        }

        if let pdfPage = try? firstPDFPage(from: fileData) {
            handler(makeReply(for: pdfPage, maxSize: request.maximumSize), nil)
            return
        }

        handler(nil, ThumbnailError.noPreviewImage)
    }

    /// Extracts the embedded PrvImage and decodes it into an `NSImage`.
    private func previewNSImage(from fileData: Data) throws -> NSImage {
        let (imageData, _) = try HWPLibrary.previewImage(fileData)
        guard let nsImage = NSImage(data: imageData) else {
            throw ThumbnailError.invalidImage
        }
        return nsImage
    }

    /// Renders the document's first page to PDF and returns the `CGPDFPage`,
    /// used when the document has no embedded preview image.
    private func firstPDFPage(from fileData: Data) throws -> CGPDFPage {
        let pdfData = try HWPLibrary.renderPDF(fileData, pageNum: 0)
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdfDocument = CGPDFDocument(provider),
              let page = pdfDocument.page(at: 1) else {
            throw ThumbnailError.invalidImage
        }
        return page
    }

    private func makeReply(for nsImage: NSImage, maxSize: CGSize) -> QLThumbnailReply {
        QLThumbnailReply(contextSize: maxSize) { context -> Bool in
            let imageSize = nsImage.size
            let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let drawOrigin = CGPoint(
                x: (maxSize.width - drawSize.width) / 2,
                y: (maxSize.height - drawSize.height) / 2
            )

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            nsImage.draw(in: CGRect(origin: drawOrigin, size: drawSize))
            NSGraphicsContext.restoreGraphicsState()

            return true
        }
    }

    private func makeReply(for pdfPage: CGPDFPage, maxSize: CGSize) -> QLThumbnailReply {
        QLThumbnailReply(contextSize: maxSize) { context -> Bool in
            let mediaBox = pdfPage.getBoxRect(.mediaBox)
            guard mediaBox.width > 0, mediaBox.height > 0 else { return false }

            let scale = min(maxSize.width / mediaBox.width, maxSize.height / mediaBox.height)
            let drawSize = CGSize(width: mediaBox.width * scale, height: mediaBox.height * scale)
            let drawOrigin = CGPoint(
                x: (maxSize.width - drawSize.width) / 2,
                y: (maxSize.height - drawSize.height) / 2
            )

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: maxSize))

            context.saveGState()
            // QLThumbnailReply's context has a bottom-left origin; translate to the
            // page's centered draw position, then scale before drawing so the PDF's
            // own coordinate space (also bottom-left) lines up correctly.
            context.translateBy(x: drawOrigin.x, y: drawOrigin.y)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
            context.drawPDFPage(pdfPage)
            context.restoreGState()

            return true
        }
    }
}

enum ThumbnailError: Error {
    case invalidData
    case noPreviewImage
    case invalidImage
}
