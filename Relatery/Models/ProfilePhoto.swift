import UIKit
import ImageIO

enum ProfilePhoto {
    /// Profile photos are only shown small, so keep the stored image light.
    /// ImageIO makes the small copy without first decoding the full picture,
    /// which matters for a 48-megapixel original.
    static func downscaled(_ data: Data, maxDimension: CGFloat = 600) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.8)
    }
}
