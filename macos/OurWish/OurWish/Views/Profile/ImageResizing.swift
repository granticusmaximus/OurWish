import AppKit

/// Downscales and JPEG-compresses a picked profile photo before it's stored as a BLOB
/// in the `users.profile_image_data` column — keeps the database small regardless of
/// how large the source image file was.
enum ImageResizing {
    static func resizedJPEGData(
        from url: URL,
        maxDimension: CGFloat = 256,
        compressionQuality: CGFloat = 0.85
    ) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return resizedJPEGData(from: image, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }

    static func resizedJPEGData(
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
