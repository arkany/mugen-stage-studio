import Foundation
import Cocoa
import os.log

/// Orchestrates the complete stage export process
/// Supports dynamic image dimensions for scrolling stages with localcoord 1280x720
class ExportController {
    
    private static let logger = Logger(subsystem: "com.mugen-stage-studio", category: "Export")
    
    // Fixed stage dimensions for compatibility
    static let stageWidth: Int = 1280
    static let stageHeight: Int = 720
    static let stageSize = CGSize(width: stageWidth, height: stageHeight)
    
    // Axis positioning ratio for MUGEN stages
    // 0.43 (~43% from top) matches working stages and provides proper vertical alignment
    private static let verticalAxisRatio: Double = 0.43
    
    // Maximum image dimension supported by Int16 in SFF format
    private static let maxImageDimension: Int = 32767
    
    enum ExportError: LocalizedError {
        case noLayers
        case thumbnailGenerationFailed
        case directoryCreationFailed
        case spriteCreationFailed(String)
        case sffWriteFailed(String)
        case defWriteFailed(String)
        case zipCreationFailed(String)
        case cleanupFailed
        
        var errorDescription: String? {
            switch self {
            case .noLayers:
                return "No background layers to export"
            case .thumbnailGenerationFailed:
                return "Failed to generate stage thumbnail"
            case .directoryCreationFailed:
                return "Failed to create temporary directory"
            case .spriteCreationFailed(let detail):
                return "Failed to create sprite: \(detail)"
            case .sffWriteFailed(let detail):
                return "Failed to write SFF file: \(detail)"
            case .defWriteFailed(let detail):
                return "Failed to write DEF file: \(detail)"
            case .zipCreationFailed(let detail):
                return "Failed to create ZIP file: \(detail)"
            case .cleanupFailed:
                return "Failed to clean up temporary files"
            }
        }
    }
    
    /// Export a stage document as a ZIP file
    /// - Parameters:
    ///   - document: The stage document to export
    ///   - destinationURL: The destination URL for the ZIP file
    static func exportAsZip(_ document: StageDocument, to destinationURL: URL) throws {
        let stageName = document.safeName
        let fileManager = FileManager.default
        
        // Create temporary directory for stage files
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageFolder = tempDir.appendingPathComponent(stageName)
        
        do {
            try fileManager.createDirectory(
                at: stageFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ExportError.directoryCreationFailed
        }
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Generate and write SFF file (returns actual image dimensions)
        let sffURL = stageFolder.appendingPathComponent("\(stageName).sff")
        let imageSize = try writeSFF(for: document, to: sffURL)
        
        // Generate and write DEF file with image dimensions for bounds calculation
        let defURL = stageFolder.appendingPathComponent("\(stageName).def")
        try writeDEF(for: document, imageSize: imageSize, to: defURL)
        
        // Create ZIP file
        try createZip(from: stageFolder, to: destinationURL)
    }
    
    // MARK: - Private Methods
    
    /// Resize/crop image to exactly 1280x720 for stage compatibility
    private static func resizeImageToStageSize(_ image: NSImage) -> NSImage? {
        let targetSize = stageSize
        
        // Create bitmap with exact pixel dimensions
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: stageWidth,
            pixelsHigh: stageHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: stageWidth * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }
        
        bitmapRep.size = targetSize
        
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        
        // Calculate source rect to crop/fit maintaining aspect ratio
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = targetSize.width / targetSize.height
        
        var sourceRect: NSRect
        if imageAspect > targetAspect {
            // Image is wider - crop sides
            let newWidth = imageSize.height * targetAspect
            let xOffset = (imageSize.width - newWidth) / 2
            sourceRect = NSRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller - crop top/bottom, bias toward top
            let newHeight = imageSize.width / targetAspect
            let yOffset = (imageSize.height - newHeight) * 0.3  // Bias toward top
            sourceRect = NSRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }
        
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: sourceRect,
            operation: .copy,
            fraction: 1.0
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        let result = NSImage(size: targetSize)
        result.addRepresentation(bitmapRep)
        return result
    }
    
    private static func writeSFF(for document: StageDocument, to url: URL) throws -> CGSize {
        guard let firstLayer = document.layers.first else {
            throw ExportError.noLayers
        }
        
        // Use original image (no resizing) to support larger scrolling backgrounds
        let stageImage = firstLayer.image
        
        // Get actual pixel dimensions from the image
        guard let tiffData = stageImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.spriteCreationFailed("Failed to read image dimensions")
        }
        
        let imageWidth = bitmap.pixelsWide
        let imageHeight = bitmap.pixelsHigh
        
        // Validate image dimensions fit within Int16 range for SFF format
        guard imageWidth > 0 && imageHeight > 0 else {
            throw ExportError.spriteCreationFailed("Image dimensions must be positive")
        }
        guard imageWidth <= maxImageDimension && imageHeight <= maxImageDimension else {
            throw ExportError.spriteCreationFailed("Image dimensions exceed maximum supported size (\(maxImageDimension)x\(maxImageDimension))")
        }
        
        logger.info("=== Starting SFF Export with Original Dimensions ===")
        logger.info("Image size: \(imageWidth)x\(imageHeight)")
        
        var sprites: [SFFWriter.Sprite] = []
        
        // Calculate axis dynamically based on image dimensions
        // axisX = center horizontally (imageWidth / 2)
        // axisY = verticalAxisRatio from top (matches working stages)
        let axisX = Int16(imageWidth / 2)
        let axisY = Int16(Double(imageHeight) * verticalAxisRatio)
        
        logger.info("Calculated axis: (\(axisX), \(axisY))")
        
        do {
            let bgSprite = try SFFWriter.sprite(
                from: stageImage,
                group: 0,
                index: 0,
                axisX: axisX,
                axisY: axisY
            )
            logger.info("Background sprite: \(bgSprite.width)x\(bgSprite.height), axis=(\(bgSprite.axisX), \(bgSprite.axisY))")
            sprites.append(bgSprite)
        } catch {
            throw ExportError.spriteCreationFailed(error.localizedDescription)
        }
        
        // Thumbnail sprite: 240x100, axis at 0,0
        guard let thumbnail = ThumbnailGenerator.generate(from: stageImage) else {
            throw ExportError.thumbnailGenerationFailed
        }
        
        do {
            let thumbSprite = try SFFWriter.sprite(
                from: thumbnail,
                group: 9000,
                index: 1,
                axisX: 0,
                axisY: 0
            )
            logger.info("Thumbnail sprite: \(thumbSprite.width)x\(thumbSprite.height)")
            sprites.append(thumbSprite)
        } catch {
            throw ExportError.spriteCreationFailed("thumbnail: \(error.localizedDescription)")
        }
        
        // Write SFF file
        do {
            try SFFWriter.write(sprites: sprites, to: url)
            logger.info("SFF written successfully: \(sprites.count) sprites")
        } catch {
            throw ExportError.sffWriteFailed(error.localizedDescription)
        }
        
        // Return the actual image dimensions for DEF generation
        return CGSize(width: imageWidth, height: imageHeight)
    }
    
    private static func writeDEF(for document: StageDocument, imageSize: CGSize, to url: URL) throws {
        let content = DEFGenerator.generate(from: document, imageSize: imageSize)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.defWriteFailed(error.localizedDescription)
        }
    }
    
    /// Create a ZIP file from a directory
    private static func createZip(from sourceFolder: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Use NSFileCoordinator for safe file access
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var zipError: Error?
        
        coordinator.coordinate(
            readingItemAt: sourceFolder,
            options: .forUploading,
            error: &coordinatorError
        ) { zipURL in
            do {
                try fileManager.copyItem(at: zipURL, to: destinationURL)
            } catch {
                zipError = error
            }
        }
        
        if let error = coordinatorError {
            throw ExportError.zipCreationFailed(error.localizedDescription)
        }
        
        if let error = zipError {
            throw ExportError.zipCreationFailed(error.localizedDescription)
        }
    }
}
