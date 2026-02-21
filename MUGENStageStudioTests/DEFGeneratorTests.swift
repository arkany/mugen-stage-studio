import XCTest
@testable import MUGEN_Stage_Studio

final class DEFGeneratorTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal valid document from known inputs.
    private func makeDocument(
        name: String = "TestStage",
        engine: Engine = .ikemenGo,
        resolution: Resolution = .hd_1280x720,
        groundLineY: Int = 600,
        boundLeft: Int = -400,
        boundRight: Int = 400,
        boundHigh: Int = -50,
        tension: Int = 75,
        verticalFollow: Float = 0.3,
        floorTension: Int = 180,
        p1X: Int = -150,
        p2X: Int = 150,
        shadowEnabled: Bool = true,
        shadowIntensity: Int = 200,
        shadowYscale: Float = 0.5,
        zoomEnabled: Bool = false
    ) -> StageDocument {
        let doc = StageDocument()
        doc.name = name
        doc.targetEngine = engine
        doc.resolution = resolution
        doc.groundLineY = groundLineY
        doc.camera.boundsRect = CGRect(
            x: CGFloat(boundLeft),
            y: CGFloat(boundHigh),
            width: CGFloat(boundRight - boundLeft),
            height: CGFloat(-boundHigh)
        )
        doc.camera.tension = tension
        doc.camera.verticalFollow = verticalFollow
        doc.camera.floorTension = floorTension
        doc.camera.zoomEnabled = zoomEnabled
        doc.players.p1X = p1X
        doc.players.p2X = p2X
        doc.shadow.enabled = shadowEnabled
        doc.shadow.intensity = shadowIntensity
        doc.shadow.yscale = shadowYscale
        return doc
    }

    /// Parse the generated DEF into a dictionary of section → key → value.
    private func parse(_ def: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection = ""
        for line in def.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(";") { continue }
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = trimmed
                if result[currentSection] == nil { result[currentSection] = [:] }
                continue
            }
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                result[currentSection]?[key] = value
            }
        }
        return result
    }

    // MARK: - [Info] section

    func testInfoName() {
        let def = DEFGenerator.generate(from: makeDocument(name: "My Stage"))
        let sections = parse(def)
        XCTAssertEqual(sections["[Info]"]?["name"], "\"My Stage\"")
    }

    func testInfoMugenVersionIKEMEN() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .ikemenGo))
        let sections = parse(def)
        XCTAssertEqual(sections["[Info]"]?["mugenversion"], "1.1")
    }

    func testInfoMugenVersion10() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .mugen10))
        let sections = parse(def)
        XCTAssertEqual(sections["[Info]"]?["mugenversion"], "1.0")
    }

    func testIkemenversionPresentForIKEMEN() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .ikemenGo))
        let sections = parse(def)
        XCTAssertEqual(sections["[Info]"]?["ikemenversion"], "1.0")
    }

    func testIkemenversionAbsentForMUGEN11() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .mugen11))
        let sections = parse(def)
        XCTAssertNil(sections["[Info]"]?["ikemenversion"])
    }

    func testIkemenversionAbsentForMUGEN10() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .mugen10))
        let sections = parse(def)
        XCTAssertNil(sections["[Info]"]?["ikemenversion"])
    }

    // MARK: - [Camera] section

    func testCameraBoundLeftFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(boundLeft: -333))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["boundleft"], "-333")
    }

    func testCameraBoundRightFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(boundRight: 222))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["boundright"], "222")
    }

    func testCameraBoundHighFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(boundHigh: -99))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["boundhigh"], "-99")
    }

    func testCameraTensionFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(tension: 75))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["tension"], "75")
    }

    func testCameraVerticalFollowFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(verticalFollow: 0.5))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["verticalfollow"], "0.5")
    }

    func testCameraFloorTensionFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(floorTension: 180))
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["floortension"], "180")
    }

    func testZoomFieldsAbsentWhenDisabled() {
        let def = DEFGenerator.generate(from: makeDocument(zoomEnabled: false))
        let sections = parse(def)
        XCTAssertNil(sections["[Camera]"]?["startzoom"])
        XCTAssertNil(sections["[Camera]"]?["zoomin"])
        XCTAssertNil(sections["[Camera]"]?["zoomout"])
    }

    func testZoomFieldsPresentForIKEMENWhenEnabled() {
        let doc = makeDocument(engine: .ikemenGo, zoomEnabled: true)
        doc.camera.zoomStart = 1.0
        doc.camera.zoomMax = 1.5
        doc.camera.zoomMin = 0.75
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertEqual(sections["[Camera]"]?["startzoom"], "1")
        XCTAssertEqual(sections["[Camera]"]?["zoomin"], "1.5")
        XCTAssertEqual(sections["[Camera]"]?["zoomout"], "0.75")
    }

    func testZoomFieldsAbsentForMUGEN10EvenWhenEnabled() {
        let doc = makeDocument(engine: .mugen10, zoomEnabled: true)
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertNil(sections["[Camera]"]?["startzoom"])
    }

    // MARK: - [PlayerInfo] section

    func testP1StartXFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(p1X: -123))
        let sections = parse(def)
        XCTAssertEqual(sections["[PlayerInfo]"]?["p1startx"], "-123")
    }

    func testP2StartXFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(p2X: 456))
        let sections = parse(def)
        XCTAssertEqual(sections["[PlayerInfo]"]?["p2startx"], "456")
    }

    func testP1FacingIsAlways1() {
        let def = DEFGenerator.generate(from: makeDocument())
        let sections = parse(def)
        XCTAssertEqual(sections["[PlayerInfo]"]?["p1facing"], "1")
    }

    func testP2FacingIsAlwaysMinus1() {
        let def = DEFGenerator.generate(from: makeDocument())
        let sections = parse(def)
        XCTAssertEqual(sections["[PlayerInfo]"]?["p2facing"], "-1")
    }

    // MARK: - [StageInfo] section

    func testZoffsetFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(groundLineY: 555))
        let sections = parse(def)
        XCTAssertEqual(sections["[StageInfo]"]?["zoffset"], "555")
    }

    func testLocalcoordHD() {
        let def = DEFGenerator.generate(from: makeDocument(resolution: .hd_1280x720))
        let sections = parse(def)
        XCTAssertEqual(sections["[StageInfo]"]?["localcoord"], "1280, 720")
    }

    func testLocalcoordFullHD() {
        let def = DEFGenerator.generate(from: makeDocument(resolution: .fullhd_1920x1080))
        let sections = parse(def)
        XCTAssertEqual(sections["[StageInfo]"]?["localcoord"], "1920, 1080")
    }

    func testLocalcoordClassic() {
        let def = DEFGenerator.generate(from: makeDocument(resolution: .classic_320x240))
        let sections = parse(def)
        XCTAssertEqual(sections["[StageInfo]"]?["localcoord"], "320, 240")
    }

    // MARK: - [Shadow] section

    func testShadowIntensityFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(shadowIntensity: 200))
        let sections = parse(def)
        XCTAssertEqual(sections["[Shadow]"]?["intensity"], "200")
    }

    func testShadowIntensityZeroWhenDisabled() {
        let def = DEFGenerator.generate(from: makeDocument(shadowEnabled: false, shadowIntensity: 200))
        let sections = parse(def)
        XCTAssertEqual(sections["[Shadow]"]?["intensity"], "0")
    }

    func testShadowYscaleFromModel() {
        let def = DEFGenerator.generate(from: makeDocument(shadowYscale: 0.5))
        let sections = parse(def)
        XCTAssertEqual(sections["[Shadow]"]?["yscale"], "0.5")
    }

    func testShadowFadeRangePresentForIKEMEN() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .ikemenGo))
        let sections = parse(def)
        XCTAssertNotNil(sections["[Shadow]"]?["fade.range"])
    }

    func testShadowFadeRangeAbsentForMUGEN11() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .mugen11))
        let sections = parse(def)
        XCTAssertNil(sections["[Shadow]"]?["fade.range"])
    }

    // MARK: - [BGDef] section

    func testBGDefSprPath() {
        let def = DEFGenerator.generate(from: makeDocument(name: "My Stage"))
        let sections = parse(def)
        XCTAssertEqual(sections["[BGDef]"]?["spr"], "My_Stage.sff")
    }

    func testBGDefSprPathSanitized() {
        let def = DEFGenerator.generate(from: makeDocument(name: "My Stage"))
        XCTAssertTrue(def.contains("My_Stage.sff"), "Spaces in name should become underscores in spr path")
    }

    // MARK: - [BG 0] section

    func testBGElementStartFromModel() {
        let doc = makeDocument()
        let layer = BackgroundLayer(
            name: "bg",
            image: NSImage(),
            position: CGPoint(x: -640, y: -360),
            delta: CGPoint(x: 1, y: 1)
        )
        doc.addLayer(layer)
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertEqual(sections["[BG 0]"]?["start"], "-640, -360")
    }

    func testBGElementDeltaFromModel() {
        let doc = makeDocument()
        let layer = BackgroundLayer(
            name: "bg",
            image: NSImage(),
            position: .zero,
            delta: CGPoint(x: 0.5, y: 0.75)
        )
        doc.addLayer(layer)
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertEqual(sections["[BG 0]"]?["delta"], "0.5, 0.75")
    }

    func testBGElementTileFromModel() {
        let doc = makeDocument()
        let layer = BackgroundLayer(
            name: "bg",
            image: NSImage(),
            position: .zero,
            delta: CGPoint(x: 1, y: 1),
            tiling: .horizontal
        )
        doc.addLayer(layer)
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertEqual(sections["[BG 0]"]?["tile"], "1, 0")
    }

    func testBGElementLayernoFromModel() {
        let doc = makeDocument()
        let layer = BackgroundLayer(
            name: "fg",
            image: NSImage(),
            position: .zero,
            delta: CGPoint(x: 1, y: 1),
            layerIndex: 1
        )
        doc.addLayer(layer)
        let def = DEFGenerator.generate(from: doc)
        let sections = parse(def)
        XCTAssertEqual(sections["[BG 0]"]?["layerno"], "1")
    }

    func testMultipleBGElementsGenerated() {
        let doc = makeDocument()
        doc.addLayer(BackgroundLayer(name: "bg0", image: NSImage(), position: .zero, delta: CGPoint(x: 1, y: 1)))
        doc.addLayer(BackgroundLayer(name: "bg1", image: NSImage(), position: .zero, delta: CGPoint(x: 0.5, y: 0.5)))
        let def = DEFGenerator.generate(from: doc)
        XCTAssertTrue(def.contains("[BG 0]"))
        XCTAssertTrue(def.contains("[BG 1]"))
    }

    func testHiddenLayerNotExported() {
        let doc = makeDocument()
        var layer = BackgroundLayer(name: "hidden", image: NSImage(), position: .zero, delta: CGPoint(x: 1, y: 1))
        layer.visible = false
        doc.addLayer(layer)
        let def = DEFGenerator.generate(from: doc)
        XCTAssertFalse(def.contains("[BG 0]"), "Hidden layers should not be exported")
    }

    // MARK: - [Music] section

    func testMusicSectionPresentForIKEMEN() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .ikemenGo))
        XCTAssertTrue(def.contains("[Music]"))
    }

    func testMusicSectionAbsentForMUGEN() {
        let def = DEFGenerator.generate(from: makeDocument(engine: .mugen11))
        XCTAssertFalse(def.contains("[Music]"))
    }

    // MARK: - Thumbnail action

    func testThumbnailActionPresent() {
        let def = DEFGenerator.generate(from: makeDocument())
        XCTAssertTrue(def.contains("[Begin Action 9000]"))
        XCTAssertTrue(def.contains("9000,1, 0,0, -1"))
    }

    // MARK: - Float formatting helper

    func testFormatFloatWholeNumber() {
        XCTAssertEqual(DEFGenerator.formatFloat(1.0), "1")
        XCTAssertEqual(DEFGenerator.formatFloat(0.0), "0")
        XCTAssertEqual(DEFGenerator.formatFloat(2.0), "2")
    }

    func testFormatFloatDecimal() {
        XCTAssertEqual(DEFGenerator.formatFloat(0.5), "0.5")
        XCTAssertEqual(DEFGenerator.formatFloat(0.75), "0.75")
        XCTAssertEqual(DEFGenerator.formatFloat(0.2), "0.2")
    }
}
