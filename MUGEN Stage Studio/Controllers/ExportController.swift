import Foundation
import Cocoa

/// Orchestrates the complete stage export process
class ExportController {
    
    enum ExportError: LocalizedError {
        case noLayers
        case thumbnailGenerationFailed
        case directoryCreationFailed
        case spriteCreationFailed(String)
        case sffWriteFailed(String)
        case defWriteFailed(String)
        case invalidExportLocation
        
        var errorDescription: String? {
            switch self {
            case .noLayers:
                return "No background layers to export"
            case .thumbnailGenerationFailed:
                return "Failed to generate stage thumbnail"
            case .directoryCreationFailed:
                return "Failed to create output directory"
            case .spriteCreationFailed(let detail):
                return "Failed to create sprite: \(detail)"
            case .sffWriteFailed(let detail):
                return "Failed to write SFF file: \(detail)"
            case .defWriteFailed(let detail):
                return "Failed to write DEF file: \(detail)"
            case .invalidExportLocation:
                return "Please export to a 'stages' folder inside your IKEMEN GO installation"
            }
        }
    }
    
    /// Export a stage document to the stages folder
    /// - Parameters:
    ///   - document: The stage document to export
    ///   - stagesFolder: The 'stages' folder URL inside IKEMEN GO
    ///   - stageName: The name for the stage folder (will be sanitized)
    static func export(_ document: StageDocument, toStagesFolder stagesFolder: URL) throws {
        let stageName = document.safeName
        
        // Create stage subfolder: [stagesFolder]/[stageName]/
        let stageFolder = stagesFolder.appendingPathComponent(stageName)
        
        do {
            try FileManager.default.createDirectory(
                at: stageFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ExportError.directoryCreationFailed
        }
        
        // Generate and write SFF file
        let sffURL = stageFolder.appendingPathComponent("\(stageName).sff")
        try writeSFF(for: document, to: sffURL)
        
        // Generate and write DEF file
        let defURL = stageFolder.appendingPathComponent("\(stageName).def")
        try writeDEF(for: document, to: defURL)
    }
    
    // MARK: - Private Methods
    
    private static func writeSFF(for document: StageDocument, to url: URL) throws {
        guard let firstLayer = document.layers.first else {
            throw ExportError.noLayers
        }
        
        var sprites: [SFFWriter.Sprite] = []
        
        // Add background layer sprites
        for (index, layer) in document.layers.enumerated() where layer.visible {
            do {
                let sprite = try SFFWriter.sprite(
                    from: layer.image,
                    group: 0,
                    index: UInt16(index),
                    axisX: Int16(layer.image.size.width / 2),
                    axisY: Int16(layer.image.size.height)
                )
                sprites.append(sprite)
            } catch {
                throw ExportError.spriteCreationFailed(error.localizedDescription)
            }
        }
        
        // Generate and add thumbnail (group 9000, index 1)
        guard let thumbnail = ThumbnailGenerator.generate(from: firstLayer.image) else {
            throw ExportError.thumbnailGenerationFailed
        }
        
        do {
            let thumbnailSprite = try SFFWriter.sprite(
                from: thumbnail,
                group: 9000,
                index: 1,
                axisX: Int16(thumbnail.size.width / 2),
                axisY: Int16(thumbnail.size.height / 2)
            )
            sprites.append(thumbnailSprite)
        } catch {
            throw ExportError.spriteCreationFailed("thumbnail: \(error.localizedDescription)")
        }
        
        // Write SFF file
        do {
            try SFFWriter.write(sprites: sprites, to: url)
        } catch {
            throw ExportError.sffWriteFailed(error.localizedDescription)
        }
    }
    
    private static func writeDEF(for document: StageDocument, to url: URL) throws {
        let content = DEFGenerator.generate(from: document)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.defWriteFailed(error.localizedDescription)
        }
    }
}
