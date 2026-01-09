import Foundation
import Cocoa

/// Generates thumbnail images for stage select screen
class ThumbnailGenerator {
    
    /// Target thumbnail size (from learnings: 240×100 = 2.4:1 aspect ratio)
    static let thumbnailSize = CGSize(width: 240, height: 100)
    
    /// Target aspect ratio
    static let targetAspectRatio: CGFloat = 2.4
    
    /// Generate a thumbnail from a stage background image
    /// - Parameter image: Source background image
    /// - Returns: Thumbnail scaled and cropped to 240×100
    static func generate(from image: NSImage) -> NSImage? {
        let originalSize = image.size
        
        guard originalSize.width > 0 && originalSize.height > 0 else {
            return nil
        }
        
        // Calculate crop rect to match target aspect ratio
        let originalAspect = originalSize.width / originalSize.height
        
        var cropRect: CGRect
        
        if originalAspect > targetAspectRatio {
            // Image is wider than target - crop sides
            let newWidth = originalSize.height * targetAspectRatio
            let xOffset = (originalSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: originalSize.height)
        } else {
            // Image is taller than target - crop top/bottom
            // Bias toward top of image where interesting content usually is (from learnings)
            let newHeight = originalSize.width / targetAspectRatio
            let yOffset = originalSize.height - newHeight - (originalSize.height * 0.1)
            cropRect = CGRect(x: 0, y: max(0, yOffset), width: originalSize.width, height: newHeight)
        }
        
        // Create cropped and scaled thumbnail
        let thumbnail = NSImage(size: thumbnailSize)
        
        thumbnail.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        
        image.draw(
            in: NSRect(origin: .zero, size: thumbnailSize),
            from: cropRect,
            operation: .copy,
            fraction: 1.0
        )
        
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}
