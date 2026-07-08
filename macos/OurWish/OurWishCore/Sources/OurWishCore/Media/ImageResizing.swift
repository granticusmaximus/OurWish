import AppKit
import Foundation

/// Downscales and JPEG-compresses an image before it's stored as a BLOB (profile
/// photos on `users`, product photos on items) — keeps the database small regardless
/// of how large the source image was. Shared by the SwiftUI app (photo picker) and the
/// embedded HTTP server (photo uploads from the web PWA), so it lives in the plain
/// `OurWishCore` package rather than the app target.
public enum ImageResizing {
    public static func resizedJPEGData(
        from url: URL,
        maxDimension: CGFloat = 256,
        compressionQuality: CGFloat = 0.85
    ) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return resizedJPEGData(from: image, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }

    public static func resizedJPEGData(
        from data: Data,
        maxDimension: CGFloat = 256,
        compressionQuality: CGFloat = 0.85
    ) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        return resizedJPEGData(from: image, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }

    public static func resizedJPEGData(
        from image: NSImage,
        maxDimension: CGFloat = 256,
        compressionQuality: CGFloat = 0.85
    ) -> Data? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(originalSize.width, originalSize.height))
        let targetSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
