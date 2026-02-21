import XCTest
@testable import MUGEN_Stage_Studio

final class ValidationEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeValidDocument() -> StageDocument {
        let doc = StageDocument()
        doc.name = "ValidStage"
        // Add a layer with a minimum-size image
        let image = NSImage(size: NSSize(width: 1280, height: 720))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 1280, height: 720).fill()
        image.unlockFocus()
        doc.addLayer(BackgroundLayer(
            name: "bg",
            image: image,
            position: CGPoint(x: -640, y: -360),
            delta: CGPoint(x: 1, y: 1)
        ))
        doc.camera.boundsRect = CGRect(x: -160, y: -25, width: 320, height: 25)
        doc.groundLineY = 660
        doc.players.p1X = -200
        doc.players.p2X = 200
        return doc
    }

    // MARK: - Valid document

    func testValidDocumentPassesWithNoErrors() {
        let doc = makeValidDocument()
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.isValid, "A fully valid document should have no errors: \(result.errors.map(\.message))")
    }

    // MARK: - Name

    func testMissingNameIsError() {
        let doc = makeValidDocument()
        doc.name = ""
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .missingName }))
    }

    func testNameWithSlashIsError() {
        let doc = makeValidDocument()
        doc.name = "stage/name"
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .invalidName }))
    }

    func testNameWithUnderscoreAndHyphenIsValid() {
        let doc = makeValidDocument()
        doc.name = "my_stage-v2"
        let result = ValidationEngine.validate(doc)
        XCTAssertFalse(result.errors.contains(where: { $0.code == .missingName || $0.code == .invalidName }))
    }

    // MARK: - Layers

    func testNoLayersIsError() {
        let doc = makeValidDocument()
        while !doc.layers.isEmpty { doc.removeLayer(at: 0) }
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .noLayers }))
    }

    // MARK: - Image size

    func testImageTooSmallIsError() {
        let doc = StageDocument()
        doc.name = "ValidName"
        let tinyImage = NSImage(size: NSSize(width: 100, height: 100))
        tinyImage.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        tinyImage.unlockFocus()
        doc.addLayer(BackgroundLayer(name: "bg", image: tinyImage, position: .zero, delta: CGPoint(x: 1, y: 1)))
        doc.camera.boundsRect = CGRect(x: -50, y: -25, width: 100, height: 25)
        doc.groundLineY = 90
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .imageTooSmall }))
    }

    func testMinimumValidImageSizePassesCheck() {
        let doc = makeValidDocument()
        let result = ValidationEngine.validate(doc)
        XCTAssertFalse(result.errors.contains(where: { $0.code == .imageTooSmall }))
    }

    // MARK: - Ground line

    func testGroundLineBelowZeroIsError() {
        let doc = makeValidDocument()
        doc.groundLineY = -1
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .invalidGroundLine }))
    }

    // MARK: - Camera bounds

    func testBoundLeftMustBeNegative() {
        let doc = makeValidDocument()
        doc.camera.boundsRect = CGRect(x: 10, y: -25, width: 490, height: 25) // boundLeft = 10
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .invalidBounds }))
    }

    func testBoundRightMustBePositive() {
        let doc = makeValidDocument()
        doc.camera.boundsRect = CGRect(x: -160, y: -25, width: 150, height: 25) // boundRight = -10
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.errors.contains(where: { $0.code == .invalidBounds }))
    }

    // MARK: - Warnings (not errors)

    func testCameraBoundsExceedImageIsWarning() {
        let doc = makeValidDocument()
        // Bounds extend well beyond image edges (image is 1280 wide, bounds > 640 on each side)
        doc.camera.boundsRect = CGRect(x: -9999, y: -25, width: 19998, height: 25)
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.warnings.contains(where: { $0.code == .boundsExceedImage }))
        XCTAssertTrue(result.isValid, "Exceeding image bounds is a warning, not an error")
    }

    func testPlayerOutsideBoundsIsWarning() {
        let doc = makeValidDocument()
        doc.players.p1X = -9999
        let result = ValidationEngine.validate(doc)
        XCTAssertTrue(result.warnings.contains(where: { $0.code == .playerOutOfBounds }))
        XCTAssertTrue(result.isValid, "Player out of bounds is a warning, not an error")
    }
}
