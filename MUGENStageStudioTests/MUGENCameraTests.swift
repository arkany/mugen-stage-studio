import XCTest
import CoreGraphics
@testable import MUGEN_Stage_Studio

final class MUGENCameraTests: XCTestCase {

    private let localcoord = CGSize(width: 1280, height: 720)
    private let zoffset: CGFloat = 660

    // MARK: - screenPosition — horizontal axis

    func testDeltaOneMovesFullyCameraX() {
        // With delta.x = 1 and camera.x = 100, screenX should shift by -100 from rest
        let restPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        let pannedPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: CGPoint(x: 100, y: 0), localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pannedPos.x, restPos.x - 100, accuracy: 0.001,
            "delta=1: element moves 1:1 with camera")
    }

    func testDeltaZeroIsFixedToScreen() {
        // delta.x = 0 means element doesn't move with camera (skybox / static element)
        let restPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 0, y: 0),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        let pannedPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 0, y: 0),
            camera: CGPoint(x: 500, y: 0), localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pannedPos.x, restPos.x, accuracy: 0.001,
            "delta=0: element is fixed relative to screen")
    }

    func testHalfDeltaParallax() {
        // delta.x = 0.5 means element moves at half camera speed (mid-ground layer)
        let restPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 0.5, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        let pannedPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 0.5, y: 1),
            camera: CGPoint(x: 200, y: 0), localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pannedPos.x, restPos.x - 100, accuracy: 0.001,
            "delta=0.5: element moves at half camera speed")
    }

    // MARK: - screenPosition — vertical axis

    func testDeltaOneMovesFullyCameraY() {
        let restPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        let pannedPos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: CGPoint(x: 0, y: -25), localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pannedPos.y, restPos.y + 25, accuracy: 0.001,
            "delta.y=1: camera up (negative y) shifts element down (positive screen Y)")
    }

    // MARK: - screenPosition — start offset

    func testStartOffsetAdded() {
        let pos = MUGENRenderer.screenPosition(
            start: CGPoint(x: 50, y: -30),
            delta: CGPoint(x: 1, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pos.x, (localcoord.width / 2) + 50, accuracy: 0.001)
        XCTAssertEqual(pos.y, zoffset - 30, accuracy: 0.001)
    }

    func testAtRestCameraXIsLocalcoordCenter() {
        // camera.x = 0, start.x = 0, delta = 1 → screenX = localcoord.width / 2
        let pos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pos.x, localcoord.width / 2, accuracy: 0.001,
            "At rest, axis point should be at horizontal screen center")
    }

    func testAtRestCameraYIsZoffset() {
        // camera.y = 0, start.y = 0, delta = 1 → screenY = zoffset
        let pos = MUGENRenderer.screenPosition(
            start: .zero, delta: CGPoint(x: 1, y: 1),
            camera: .zero, localcoord: localcoord, zoffset: zoffset
        )
        XCTAssertEqual(pos.y, zoffset, accuracy: 0.001,
            "At rest, axis Y should be at zoffset (floor line)")
    }

    // MARK: - Camera clamping

    func testCameraClampedToLeft() {
        let clamped = MUGENRenderer.clampCamera(
            CGPoint(x: -9999, y: 0),
            boundLeft: -500, boundRight: 500, boundHigh: -25, boundLow: 0
        )
        XCTAssertEqual(clamped.x, -500)
    }

    func testCameraClampedToRight() {
        let clamped = MUGENRenderer.clampCamera(
            CGPoint(x: 9999, y: 0),
            boundLeft: -500, boundRight: 500, boundHigh: -25, boundLow: 0
        )
        XCTAssertEqual(clamped.x, 500)
    }

    func testCameraClampedToHigh() {
        let clamped = MUGENRenderer.clampCamera(
            CGPoint(x: 0, y: -9999),
            boundLeft: -500, boundRight: 500, boundHigh: -25, boundLow: 0
        )
        XCTAssertEqual(clamped.y, -25)
    }

    func testCameraClampedToLow() {
        let clamped = MUGENRenderer.clampCamera(
            CGPoint(x: 0, y: 9999),
            boundLeft: -500, boundRight: 500, boundHigh: -25, boundLow: 0
        )
        XCTAssertEqual(clamped.y, 0)
    }

    func testCameraInRangeUnchanged() {
        let input = CGPoint(x: 100, y: -10)
        let clamped = MUGENRenderer.clampCamera(
            input, boundLeft: -500, boundRight: 500, boundHigh: -25, boundLow: 0
        )
        XCTAssertEqual(clamped.x, 100)
        XCTAssertEqual(clamped.y, -10)
    }

    // MARK: - spriteRect

    func testSpriteRectOrigin() {
        let screenPos = CGPoint(x: 640, y: 660)
        let size = CGSize(width: 1280, height: 720)
        let axis = CGPoint(x: 640, y: 0)  // center-top axis (typical stage BG)
        let rect = MUGENRenderer.spriteRect(screenPosition: screenPos, spriteSize: size, axisOffset: axis)
        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 660, accuracy: 0.001)
    }

    func testSpriteRectSize() {
        let size = CGSize(width: 1280, height: 720)
        let rect = MUGENRenderer.spriteRect(
            screenPosition: .zero, spriteSize: size, axisOffset: .zero
        )
        XCTAssertEqual(rect.width, 1280)
        XCTAssertEqual(rect.height, 720)
    }

    // MARK: - canvasRect coordinate conversion

    func testCanvasRectYFlip() {
        // localcoord Y=0 (top) should map to top of the canvas viewport
        let canvasViewport = CGRect(x: 100, y: 50, width: 1280, height: 720)
        let localRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = MUGENRenderer.canvasRect(
            from: localRect,
            canvasScreenRect: canvasViewport,
            localcoord: localcoord
        )
        // Y=0 in localcoord → top of viewport in canvas (AppKit Y-up: canvasViewport.maxY - scaledH)
        XCTAssertEqual(result.maxY, canvasViewport.maxY, accuracy: 0.001,
            "localcoord Y=0 (top of screen) should map to top of canvas viewport")
    }

    func testCanvasRectScaling() {
        // A 1x1 scale: localcoord == canvasViewport size
        let canvasViewport = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let localRect = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let result = MUGENRenderer.canvasRect(
            from: localRect,
            canvasScreenRect: canvasViewport,
            localcoord: CGSize(width: 1280, height: 720)
        )
        XCTAssertEqual(result.width, 1280, accuracy: 0.001)
        XCTAssertEqual(result.height, 720, accuracy: 0.001)
    }

    func testCanvasRectHalfScale() {
        // Canvas viewport is half the localcoord size
        let canvasViewport = CGRect(x: 0, y: 0, width: 640, height: 360)
        let localRect = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let result = MUGENRenderer.canvasRect(
            from: localRect,
            canvasScreenRect: canvasViewport,
            localcoord: CGSize(width: 1280, height: 720)
        )
        XCTAssertEqual(result.width, 640, accuracy: 0.001)
        XCTAssertEqual(result.height, 360, accuracy: 0.001)
    }
}
