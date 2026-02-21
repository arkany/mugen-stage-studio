import CoreGraphics

/// Pure MUGEN/IKEMEN GO rendering math — no UI dependencies.
///
/// All formulas are derived from the MUGEN 1.1 / IKEMEN GO stage specification.
/// This struct is intentionally stateless so every function is trivially testable.
enum MUGENRenderer {

    // MARK: - BG Element Position

    /// Compute the screen-space position of a BG element's axis point.
    ///
    /// MUGEN renders a BG element by placing its sprite axis at:
    /// ```
    /// screenX = (localcoord.width / 2) + start.x - (camera.x * delta.x)
    /// screenY = zoffset               + start.y - (camera.y * delta.y)
    /// ```
    /// - Parameters:
    ///   - start:      The element's `start` parameter (x, y) in localcoord units.
    ///   - delta:      The element's `delta` parameter (parallax factor per axis).
    ///                 1.0 = moves with camera; 0.0 = fixed; 0.5 = half-speed parallax.
    ///   - camera:     Current camera position in localcoord units.
    ///                 Ranges from (boundleft, boundhigh) to (boundright, boundlow).
    ///   - localcoord: The stage coordinate space size (e.g. 1280 × 720).
    ///   - zoffset:    The `zoffset` value from [StageInfo] — floor Y in localcoord.
    /// - Returns: The axis point in localcoord screen space (origin top-left).
    static func screenPosition(
        start: CGPoint,
        delta: CGPoint,
        camera: CGPoint,
        localcoord: CGSize,
        zoffset: CGFloat
    ) -> CGPoint {
        let x = (localcoord.width / 2) + start.x - (camera.x * delta.x)
        let y = zoffset + start.y - (camera.y * delta.y)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Sprite Draw Rect

    /// Compute the draw rect for a BG sprite in localcoord screen space.
    ///
    /// The sprite's axis point lands at `screenPosition`. The axis offsets
    /// (stored in the SFF sprite node as axisX/axisY) shift the sprite so
    /// the correct point aligns with the computed screen position.
    ///
    /// - Parameters:
    ///   - screenPosition: Result of `screenPosition(start:delta:camera:localcoord:zoffset:)`.
    ///   - spriteSize:     The sprite's pixel dimensions (width × height).
    ///   - axisOffset:     The sprite's axis point within its own coordinate space (axisX, axisY).
    ///                     For stages: typically (spriteWidth/2, 0) — center-top aligned.
    /// - Returns: The rect in localcoord screen space where the sprite should be drawn.
    static func spriteRect(
        screenPosition: CGPoint,
        spriteSize: CGSize,
        axisOffset: CGPoint
    ) -> CGRect {
        let originX = screenPosition.x - axisOffset.x
        let originY = screenPosition.y - axisOffset.y
        return CGRect(origin: CGPoint(x: originX, y: originY), size: spriteSize)
    }

    // MARK: - Canvas Coordinate Conversion

    /// Convert a localcoord screen-space rect to canvas (view) coordinates.
    ///
    /// The canvas uses AppKit's default coordinate system (origin bottom-left, Y up).
    /// The localcoord space has origin top-left, Y down. This function:
    ///   1. Scales localcoord units → canvas pixels using `scale`.
    ///   2. Flips Y so that localcoord Y=0 (top of screen) maps to the top of
    ///      `canvasScreenRect` in view coordinates.
    ///
    /// - Parameters:
    ///   - rect:             A rect in localcoord space.
    ///   - canvasScreenRect: The rect in canvas/view coordinates that represents
    ///                       the localcoord viewport (the yellow "Export Area" frame).
    ///   - localcoord:       The stage coordinate space size.
    /// - Returns: The equivalent rect in canvas/view coordinates.
    static func canvasRect(
        from rect: CGRect,
        canvasScreenRect: CGRect,
        localcoord: CGSize
    ) -> CGRect {
        guard localcoord.width > 0, localcoord.height > 0 else { return .zero }

        let scaleX = canvasScreenRect.width / localcoord.width
        let scaleY = canvasScreenRect.height / localcoord.height

        // Scale from localcoord pixels to canvas pixels
        let scaledX = rect.origin.x * scaleX
        let scaledY = rect.origin.y * scaleY
        let scaledW = rect.width * scaleX
        let scaledH = rect.height * scaleY

        // Flip Y: localcoord Y=0 is the top of the viewport.
        // In AppKit, the top of canvasScreenRect is canvasScreenRect.maxY.
        let canvasX = canvasScreenRect.minX + scaledX
        let canvasY = canvasScreenRect.maxY - scaledY - scaledH

        return CGRect(x: canvasX, y: canvasY, width: scaledW, height: scaledH)
    }

    // MARK: - Camera Clamping

    /// Clamp a camera position to the stage's valid camera range.
    ///
    /// - Parameters:
    ///   - camera:     Desired camera position.
    ///   - boundLeft:  `boundleft` value (negative, e.g. -500).
    ///   - boundRight: `boundright` value (positive, e.g. 500).
    ///   - boundHigh:  `boundhigh` value (negative, e.g. -25).
    ///   - boundLow:   `boundlow` value (0 in practice).
    /// - Returns: The camera position clamped to valid bounds.
    static func clampCamera(
        _ camera: CGPoint,
        boundLeft: CGFloat,
        boundRight: CGFloat,
        boundHigh: CGFloat,
        boundLow: CGFloat
    ) -> CGPoint {
        let x = max(boundLeft, min(boundRight, camera.x))
        let y = max(boundHigh, min(boundLow, camera.y))
        return CGPoint(x: x, y: y)
    }
}
