import Foundation
import Cocoa

/// Generates SFF v2 sprite files for MUGEN/IKEMEN GO stages
/// Ported from IKEMEN Lab implementation with learnings applied
class SFFWriter {
    
    // MARK: - Constants
    
    /// SFF v2 file signature
    private static let signature = "ElecbyteSpr\0"
    
    /// SFF version 2.01
    private static let version: [UInt8] = [0x00, 0x01, 0x00, 0x02]
    
    /// Header size (68 bytes)
    private static let headerSize: UInt32 = 68
    
    /// Sprite node size (28 bytes each)
    private static let spriteNodeSize: UInt32 = 28
    
    /// Palette node size (16 bytes each)
    private static let paletteNodeSize: UInt32 = 16
    
    // MARK: - Sprite Definition
    
    struct Sprite {
        let group: UInt16
        let index: UInt16
        let width: UInt16
        let height: UInt16
        let axisX: Int16
        let axisY: Int16
        let pngData: Data
        let hasAlpha: Bool
        
        /// Format byte: 11 = PNG24, 12 = PNG32
        var format: UInt8 {
            hasAlpha ? 12 : 11
        }
        
        /// Color depth
        var colorDepth: UInt8 {
            hasAlpha ? 32 : 24
        }
    }
    
    // MARK: - Errors
    
    enum SFFWriteError: LocalizedError {
        case pngEncodingFailed
        case fileWriteFailed(String)
        case invalidImageSize
        
        var errorDescription: String? {
            switch self {
            case .pngEncodingFailed:
                return "Failed to encode image as PNG"
            case .fileWriteFailed(let reason):
                return "Failed to write SFF file: \(reason)"
            case .invalidImageSize:
                return "Invalid image dimensions"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Write sprites to an SFF v2 file
    /// - Parameters:
    ///   - sprites: Array of sprites to include
    ///   - url: Destination file URL
    static func write(sprites: [Sprite], to url: URL) throws {
        var data = Data()
        
        let spriteCount = UInt32(sprites.count)
        let paletteCount: UInt32 = 1  // Mandatory dummy palette
        
        // Calculate offsets
        let spriteListOffset = headerSize
        let paletteListOffset = spriteListOffset + (spriteCount * spriteNodeSize)
        let ldataOffset = paletteListOffset + (paletteCount * paletteNodeSize)
        
        // Build ldata (literal data) section containing all PNG data
        var ldata = Data()
        var spriteDataOffsets: [UInt32] = []
        var spriteDataLengths: [UInt32] = []
        
        for sprite in sprites {
            spriteDataOffsets.append(UInt32(ldata.count))
            
            // Each PNG sprite needs a 4-byte uncompressed size prefix
            // (Critical learning: required for format compatibility)
            let uncompressedSize = UInt32(sprite.width) * UInt32(sprite.height) * 4
            ldata.append(littleEndian: uncompressedSize)
            ldata.append(sprite.pngData)
            
            spriteDataLengths.append(UInt32(sprite.pngData.count) + 4) // +4 for size prefix
        }
        
        let ldataLength = UInt32(ldata.count)
        
        // tdata section (translated data) - not used for PNG sprites
        let tdataOffset = ldataOffset + ldataLength
        let tdataLength: UInt32 = 0
        
        // Write header (68 bytes)
        data.append(contentsOf: signature.utf8.prefix(12))
        // Pad signature to 12 bytes if needed
        while data.count < 12 {
            data.append(0)
        }
        
        data.append(contentsOf: version)                    // 12-15: Version
        data.append(Data(count: 20))                        // 16-35: Reserved/unused (zeros)
        data.append(littleEndian: spriteListOffset)         // 36-39: Sprite list offset
        data.append(littleEndian: spriteCount)              // 40-43: Sprite count
        data.append(littleEndian: paletteListOffset)        // 44-47: Palette list offset
        data.append(littleEndian: paletteCount)             // 48-51: Palette count
        data.append(littleEndian: ldataOffset)              // 52-55: Ldata offset
        data.append(littleEndian: ldataLength)              // 56-59: Ldata length
        data.append(littleEndian: tdataOffset)              // 60-63: Tdata offset
        data.append(littleEndian: tdataLength)              // 64-67: Tdata length
        
        assert(data.count == 68, "Header must be exactly 68 bytes")
        
        // Write sprite nodes (28 bytes each)
        for (index, sprite) in sprites.enumerated() {
            data.append(littleEndian: sprite.group)             // 0-1: Group
            data.append(littleEndian: sprite.index)             // 2-3: Index
            data.append(littleEndian: sprite.width)             // 4-5: Width
            data.append(littleEndian: sprite.height)            // 6-7: Height
            data.append(littleEndian: sprite.axisX)             // 8-9: X axis
            data.append(littleEndian: sprite.axisY)             // 10-11: Y axis
            data.append(littleEndian: UInt16(0xFFFF))           // 12-13: Linked index (none)
            data.append(sprite.format)                          // 14: Format (11/12)
            data.append(sprite.colorDepth)                      // 15: Color depth
            data.append(littleEndian: spriteDataOffsets[index]) // 16-19: Data offset
            data.append(littleEndian: spriteDataLengths[index]) // 20-23: Data length
            data.append(littleEndian: UInt16(0))                // 24-25: Palette index
            data.append(littleEndian: UInt16(0))                // 26-27: Flags (0 = ldata)
        }
        
        // Write palette nodes (16 bytes each)
        // Critical learning: At least one dummy palette is REQUIRED even for PNG-only files
        data.append(littleEndian: UInt16(0))     // 0-1: Group
        data.append(littleEndian: UInt16(0))     // 2-3: Index
        data.append(littleEndian: UInt16(1))     // 4-5: Num colors
        data.append(littleEndian: UInt16(0))     // 6-7: Linked index
        data.append(littleEndian: UInt32(0))     // 8-11: Data offset
        data.append(littleEndian: UInt32(4))     // 12-15: Data length (1 color = 4 bytes)
        
        // Write ldata section (all PNG data)
        data.append(ldata)
        
        // Write file
        do {
            try data.write(to: url)
        } catch {
            throw SFFWriteError.fileWriteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Conversion
    
    /// Convert NSImage to SFF Sprite
    /// - Parameters:
    ///   - image: Source image
    ///   - group: Sprite group number
    ///   - index: Sprite index within group
    ///   - axisX: X axis offset (typically center of image)
    ///   - axisY: Y axis offset (typically bottom of image for stages)
    /// - Returns: Sprite ready for SFF file
    static func sprite(
        from image: NSImage,
        group: UInt16,
        index: UInt16,
        axisX: Int16? = nil,
        axisY: Int16? = nil
    ) throws -> Sprite {
        
        // Get PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SFFWriteError.pngEncodingFailed
        }
        
        let width = UInt16(image.size.width)
        let height = UInt16(image.size.height)
        
        guard width > 0 && height > 0 else {
            throw SFFWriteError.invalidImageSize
        }
        
        // Determine if image has alpha channel
        let hasAlpha = bitmap.hasAlpha
        
        // Default axis: center X, bottom Y (typical for stage backgrounds)
        let finalAxisX = axisX ?? Int16(width / 2)
        let finalAxisY = axisY ?? Int16(height)
        
        return Sprite(
            group: group,
            index: index,
            width: width,
            height: height,
            axisX: finalAxisX,
            axisY: finalAxisY,
            pngData: pngData,
            hasAlpha: hasAlpha
        )
    }
}

// MARK: - Data Extensions

private extension Data {
    
    mutating func append(littleEndian value: UInt16) {
        var le = value.littleEndian
        append(Data(bytes: &le, count: 2))
    }
    
    mutating func append(littleEndian value: Int16) {
        var le = value.littleEndian
        append(Data(bytes: &le, count: 2))
    }
    
    mutating func append(littleEndian value: UInt32) {
        var le = value.littleEndian
        append(Data(bytes: &le, count: 4))
    }
}
