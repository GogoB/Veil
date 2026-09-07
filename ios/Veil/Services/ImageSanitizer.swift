import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageSanitizerError: LocalizedError {
    case unreadable
    case tooLarge
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: return "That image could not be opened."
        case .tooLarge: return "Choose an image under 24 megapixels and 8,000 pixels per side."
        case .encodingFailed: return "That image could not be prepared for upload."
        }
    }
}

enum ImageSanitizer {
    static func sanitizedUploadData(from sourceData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ImageSanitizerError.unreadable
        }

        guard width <= 8_000, height <= 8_000, width * height <= 24_000_000 else {
            throw ImageSanitizerError.tooLarge
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_400,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ImageSanitizerError.unreadable
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageSanitizerError.encodingFailed
        }
        let outputOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.88,
            kCGImagePropertyOrientation: 1
        ]
        CGImageDestinationAddImage(destination, image, outputOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageSanitizerError.encodingFailed }
        return output as Data
    }
}
