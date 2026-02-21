import XCTest
@testable import MUGEN_Stage_Studio

final class SFFWriterTests: XCTestCase {

    // MARK: - Helpers

    /// Write a minimal 1-sprite SFF to a temp file and return its Data.
    private func writeMinimalSFF(width: UInt16 = 4, height: UInt16 = 4) throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sff")
        defer { try? FileManager.default.removeItem(at: url) }

        let pngData = makePNG(width: Int(width), height: Int(height))
        let sprite = SFFWriter.Sprite(
            group: 0, index: 0,
            width: width, height: height,
            axisX: Int16(width / 2), axisY: 0,
            pngData: pngData, hasAlpha: true
        )
        try SFFWriter.write(sprites: [sprite], to: url)
        return try Data(contentsOf: url)
    }

    /// Generate a minimal valid PNG for a solid-color image.
    private func makePNG(width: Int, height: Int) -> Data {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { ptr in
            var value: UInt32 = 0
            withUnsafeMutableBytes(of: &value) { dest in
                dest.copyMemory(from: UnsafeRawBufferPointer(start: ptr.baseAddress!.advanced(by: offset), count: 4))
            }
            return UInt32(littleEndian: value)
        }
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        data.withUnsafeBytes { ptr in
            var value: UInt16 = 0
            withUnsafeMutableBytes(of: &value) { dest in
                dest.copyMemory(from: UnsafeRawBufferPointer(start: ptr.baseAddress!.advanced(by: offset), count: 2))
            }
            return UInt16(littleEndian: value)
        }
    }

    // MARK: - Header magic

    func testMagicBytes() throws {
        let data = try writeMinimalSFF()
        let magic = String(bytes: data.prefix(11), encoding: .ascii)
        XCTAssertEqual(magic, "ElecbyteSpr", "First 11 bytes must be 'ElecbyteSpr'")
        XCTAssertEqual(data[11], 0x00, "12th byte must be null terminator")
    }

    // MARK: - Header version

    func testVersionBytesAtOffset12() throws {
        let data = try writeMinimalSFF()
        // SFF v2.01 = [0x00, 0x01, 0x00, 0x02]
        XCTAssertEqual(data[12], 0x00)
        XCTAssertEqual(data[13], 0x01)
        XCTAssertEqual(data[14], 0x00)
        XCTAssertEqual(data[15], 0x02)
    }

    // MARK: - Header offsets

    func testSpriteListOffsetIs68() throws {
        let data = try writeMinimalSFF()
        let spriteListOffset = readUInt32LE(data, at: 36)
        XCTAssertEqual(spriteListOffset, 68, "Sprite list must start immediately after the 68-byte header")
    }

    func testSpriteCountIsCorrect() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sff")
        defer { try? FileManager.default.removeItem(at: url) }

        let png = makePNG(width: 4, height: 4)
        let sprites = [
            SFFWriter.Sprite(group: 0, index: 0, width: 4, height: 4, axisX: 2, axisY: 0, pngData: png, hasAlpha: true),
            SFFWriter.Sprite(group: 9000, index: 1, width: 4, height: 4, axisX: 0, axisY: 0, pngData: png, hasAlpha: true)
        ]
        try SFFWriter.write(sprites: sprites, to: url)
        let data = try Data(contentsOf: url)
        let spriteCount = readUInt32LE(data, at: 40)
        XCTAssertEqual(spriteCount, 2)
    }

    func testPaletteCountIsAtLeastOne() throws {
        let data = try writeMinimalSFF()
        let paletteCount = readUInt32LE(data, at: 48)
        XCTAssertGreaterThanOrEqual(paletteCount, 1, "At least one dummy palette is required for IKEMEN GO")
    }

    func testLdataOffsetIsAfterPaletteList() throws {
        let data = try writeMinimalSFF()
        let paletteListOffset = readUInt32LE(data, at: 44)
        let paletteCount = readUInt32LE(data, at: 48)
        let ldataOffset = readUInt32LE(data, at: 52)
        // Each palette node is 16 bytes
        let expectedLdataOffset = paletteListOffset + (paletteCount * 16)
        XCTAssertEqual(ldataOffset, expectedLdataOffset)
    }

    func testTdataLengthIsZero() throws {
        let data = try writeMinimalSFF()
        let tdataLength = readUInt32LE(data, at: 64)
        XCTAssertEqual(tdataLength, 0, "PNG-only SFF files should not use tdata")
    }

    // MARK: - Sprite node

    func testSpriteNodeGroupAndIndex() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sff")
        defer { try? FileManager.default.removeItem(at: url) }

        let png = makePNG(width: 4, height: 4)
        let sprite = SFFWriter.Sprite(group: 9, index: 3, width: 4, height: 4, axisX: 0, axisY: 0, pngData: png, hasAlpha: false)
        try SFFWriter.write(sprites: [sprite], to: url)
        let data = try Data(contentsOf: url)

        // First sprite node starts at offset 68
        let nodeBase = 68
        let group = readUInt16LE(data, at: nodeBase + 0)
        let index = readUInt16LE(data, at: nodeBase + 2)
        XCTAssertEqual(group, 9)
        XCTAssertEqual(index, 3)
    }

    func testSpriteNodeDimensions() throws {
        let data = try writeMinimalSFF(width: 16, height: 8)
        let nodeBase = 68
        let width = readUInt16LE(data, at: nodeBase + 4)
        let height = readUInt16LE(data, at: nodeBase + 6)
        XCTAssertEqual(width, 16)
        XCTAssertEqual(height, 8)
    }

    func testSpriteNodeFormatBytePNG32() throws {
        let data = try writeMinimalSFF()  // hasAlpha: true → format 12
        let nodeBase = 68
        let format = data[nodeBase + 14]
        XCTAssertEqual(format, 12, "PNG32 format byte should be 12")
    }

    func testSpriteNodeFormatBytePNG24() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sff")
        defer { try? FileManager.default.removeItem(at: url) }

        let png = makePNG(width: 4, height: 4)
        let sprite = SFFWriter.Sprite(group: 0, index: 0, width: 4, height: 4, axisX: 0, axisY: 0, pngData: png, hasAlpha: false)
        try SFFWriter.write(sprites: [sprite], to: url)
        let data = try Data(contentsOf: url)
        let format = data[68 + 14]
        XCTAssertEqual(format, 11, "PNG24 format byte should be 11")
    }

    func testSpriteNodeLinkedIndexIsFFFF() throws {
        let data = try writeMinimalSFF()
        let nodeBase = 68
        let linkedIndex = readUInt16LE(data, at: nodeBase + 12)
        XCTAssertEqual(linkedIndex, 0xFFFF, "Linked index should be 0xFFFF (not linked)")
    }

    func testSpriteNodeFlagsIsZero() throws {
        let data = try writeMinimalSFF()
        let nodeBase = 68
        let flags = readUInt16LE(data, at: nodeBase + 26)
        XCTAssertEqual(flags, 0, "Flags = 0 means data is in ldata section")
    }

    // MARK: - PNG length prefix in ldata

    func testPNGDataHasFourByteLengthPrefix() throws {
        let data = try writeMinimalSFF(width: 4, height: 4)

        let ldataOffset = readUInt32LE(data, at: 52)
        let paletteCount = readUInt32LE(data, at: 48)
        // Dummy palette data is 4 bytes at start of ldata
        let dummyPaletteSize: UInt32 = 4
        // Sprite data starts after the dummy palette
        let spriteDataStart = Int(ldataOffset) + Int(dummyPaletteSize)

        // Read the 4-byte uncompressed size prefix
        let prefixedSize = readUInt32LE(data, at: spriteDataStart)
        // Expected: width * height * 4 bytes per pixel
        let expectedUncompressedSize: UInt32 = 4 * 4 * 4
        XCTAssertEqual(prefixedSize, expectedUncompressedSize,
            "Each PNG entry in ldata must be preceded by its uncompressed pixel data size")
    }

    // MARK: - Round-trip image dimensions via sprite() helper

    func testSpriteHelperPreservesPixelDimensions() throws {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 50).fill()
        image.unlockFocus()

        let sprite = try SFFWriter.sprite(from: image, group: 0, index: 0)
        XCTAssertEqual(sprite.width, 100)
        XCTAssertEqual(sprite.height, 50)
    }

    func testSpriteHelperDefaultAxisX() throws {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 50).fill()
        image.unlockFocus()

        let sprite = try SFFWriter.sprite(from: image, group: 0, index: 0)
        XCTAssertEqual(sprite.axisX, 50, "Default axisX should be width/2 = 50")
    }

    func testSpriteHelperCustomAxis() throws {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 50).fill()
        image.unlockFocus()

        let sprite = try SFFWriter.sprite(from: image, group: 0, index: 0, axisX: 10, axisY: 20)
        XCTAssertEqual(sprite.axisX, 10)
        XCTAssertEqual(sprite.axisY, 20)
    }

    // MARK: - File size sanity

    func testOutputFileSizeIsReasonable() throws {
        let data = try writeMinimalSFF()
        // Minimum: 68 (header) + 28 (sprite node) + 16 (palette node) + 4 (dummy palette) + 4 (prefix) + some PNG data
        XCTAssertGreaterThan(data.count, 68 + 28 + 16 + 8)
    }
}
