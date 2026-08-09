import Foundation

/// Thin Swift wrapper around the `rhwp-ffi` C functions declared in BridgingHeader.h.
///
/// The underlying FFI is stateless, so every function here is safe to call
/// from any thread (including background queues used by the app, previewer,
/// and thumbnailer to keep AppKit/QuickLook callbacks responsive).
enum HWPLibrary {
    /// Version of the `rhwp` crate currently vendored into `libhwp_ffi.a`
    /// (see rhwp-ffi/Cargo.lock). Shown in the app's About/Info window.
    static let rhwpVersion = "0.8.2"

    /// Parses raw `.hwp`/`.hwpx` file bytes into an HTML rendering of the document.
    static func parseToHTML(_ data: Data) throws -> String {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String in
            guard let base = buffer.baseAddress else {
                throw HWPLibraryError.invalidData
            }

            var outHtml: UnsafeMutablePointer<CChar>?
            var outLen: UInt = 0
            let result = hwp_parse_to_html(
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                &outHtml,
                &outLen
            )

            guard result == HWP_OK, let htmlPtr = outHtml else {
                throw HWPLibraryError(code: result)
            }
            defer { hwp_free_string(htmlPtr) }
            return String(cString: htmlPtr)
        }
    }

    /// Renders raw `.hwp`/`.hwpx` file bytes to PDF.
    /// - Parameter pageNum: `-1` (default) renders the whole document; `0`-based
    ///   page indices render a single page.
    static func renderPDF(_ data: Data, pageNum: Int32 = -1) throws -> Data {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
            guard let base = buffer.baseAddress else {
                throw HWPLibraryError.invalidData
            }

            var outData: UnsafeMutablePointer<UInt8>?
            var outLen: UInt = 0
            let result = hwp_render_pdf(
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                pageNum,
                &outData,
                &outLen
            )

            guard result == HWP_OK, let dataPtr = outData else {
                throw HWPLibraryError(code: result)
            }
            defer { hwp_free_bytes(dataPtr, outLen) }
            return Data(bytes: dataPtr, count: Int(outLen))
        }
    }

    /// Extracts the embedded preview image (PrvImage) from raw `.hwp`/`.hwpx`
    /// file bytes, along with its image format (e.g. "png", "bmp").
    static func previewImage(_ data: Data) throws -> (data: Data, format: String) {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> (Data, String) in
            guard let base = buffer.baseAddress else {
                throw HWPLibraryError.invalidData
            }

            var outData: UnsafeMutablePointer<UInt8>?
            var outLen: UInt = 0
            var outFormat: UnsafeMutablePointer<CChar>?
            let result = hwp_get_preview_image(
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                &outData,
                &outLen,
                &outFormat
            )

            guard result == HWP_OK, let dataPtr = outData, let formatPtr = outFormat else {
                throw HWPLibraryError(code: result)
            }
            defer {
                hwp_free_bytes(dataPtr, outLen)
                hwp_free_string(formatPtr)
            }
            let imageData = Data(bytes: dataPtr, count: Int(outLen))
            let format = String(cString: formatPtr)
            return (imageData, format)
        }
    }
}

/// Errors surfaced by `HWPLibrary`, mapped from `rhwp-ffi` error codes to
/// human-readable messages.
enum HWPLibraryError: Error, LocalizedError {
    /// The input `Data` buffer had no bytes to hand to the FFI layer.
    case invalidData
    /// One of the `HWP_ERROR_*` codes from BridgingHeader.h.
    case ffi(code: Int32, message: String)

    init(code: Int32) {
        let message: String
        switch code {
        case HWP_ERROR_NULL_POINTER:
            message = "The document could not be read (internal null pointer error)."
        case HWP_ERROR_PARSE_FAILED:
            message = "The document could not be parsed (unsupported format or corrupted file)."
        case HWP_ERROR_PANIC:
            message = "The document parser crashed while processing this file."
        case HWP_ERROR_NO_PREVIEW_IMAGE:
            message = "This document does not contain an embedded preview image."
        case HWP_ERROR_RENDER_FAILED:
            message = "The document could not be rendered to PDF."
        default:
            message = "An unknown error occurred while processing the document."
        }
        self = .ffi(code: code, message: message)
    }

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The document data is empty or invalid."
        case .ffi(let code, let message):
            return "\(message) (code: \(code))"
        }
    }
}
