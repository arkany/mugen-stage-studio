import Cocoa

extension NSImage {
    
    /// Get PNG data representation
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }
    
    /// Check if image has alpha channel
    var hasAlpha: Bool {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        return bitmap.hasAlpha
    }
    
    /// Create a resized copy of the image
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
    
    /// Create a cropped copy of the image
    func cropped(to rect: NSRect) -> NSImage {
        let croppedImage = NSImage(size: rect.size)
        croppedImage.lockFocus()
        
        draw(in: NSRect(origin: .zero, size: rect.size),
             from: rect,
             operation: .copy,
             fraction: 1.0)
        
        croppedImage.unlockFocus()
        return croppedImage
    }
    
    /// Get pixel dimensions (not points)
    var pixelSize: NSSize {
        guard let rep = representations.first else {
            return size
        }
        return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}
