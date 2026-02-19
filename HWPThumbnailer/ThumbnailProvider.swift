import QuickLookThumbnailing
import AppKit

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL

        guard let fileData = try? Data(contentsOf: fileURL) else {
            handler(nil, ThumbnailError.invalidData)
            return
        }

        fileData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else {
                handler(nil, ThumbnailError.invalidData)
                return
            }

            var outData: UnsafeMutablePointer<UInt8>?
            var outLen: UInt = 0
            var outFormat: UnsafeMutablePointer<CChar>?

            let result = hwp_get_preview_image(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                UInt(fileData.count),
                &outData,
                &outLen,
                &outFormat
            )

            guard result == HWP_OK,
                  let imagePtr = outData,
                  let formatPtr = outFormat else {
                handler(nil, ThumbnailError.noPreviewImage)
                return
            }

            let imageData = Data(bytes: imagePtr, count: Int(outLen))
            hwp_free_bytes(imagePtr, outLen)
            hwp_free_string(formatPtr)

            guard let nsImage = NSImage(data: imageData) else {
                handler(nil, ThumbnailError.invalidImage)
                return
            }

            let maxSize = request.maximumSize
            let reply = QLThumbnailReply(contextSize: maxSize) { context -> Bool in
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

            handler(reply, nil)
        }
    }
}

enum ThumbnailError: Error {
    case invalidData
    case noPreviewImage
    case invalidImage
}
