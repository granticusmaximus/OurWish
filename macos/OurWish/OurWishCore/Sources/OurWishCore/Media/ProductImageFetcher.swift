import AppKit
import Foundation
import LinkPresentation

/// Fetches a product photo from a pasted product URL, using the system's
/// `LinkPresentation` framework (the same link-preview machinery Messages/Safari use)
/// rather than hand-rolling HTML/Open Graph parsing — it already knows how to find a
/// page's preview image across essentially every major retailer. Shared by the SwiftUI
/// app's `AddItemSheet` and the embedded HTTP server (so the web PWA gets the same
/// auto-fetch behavior without re-implementing it client-side).
public enum ProductImageFetcher {
    /// Returns downscaled, JPEG-compressed image data suitable for storing in the
    /// database, or `nil` if the URL is invalid, unreachable, or has no preview image.
    public static func fetchImageData(for urlString: String) async -> Data? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        let provider = LPMetadataProvider()
        let metadata: LPLinkMetadata
        do {
            metadata = try await provider.startFetchingMetadata(for: url)
        } catch {
            return nil
        }

        guard let imageProvider = metadata.imageProvider else { return nil }

        let nsImage: NSImage? = await withCheckedContinuation { continuation in
            imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                continuation.resume(returning: object as? NSImage)
            }
        }

        guard let nsImage else { return nil }
        return ImageResizing.resizedJPEGData(from: nsImage, maxDimension: 512, compressionQuality: 0.8)
    }
}
