import Cocoa

protocol CanvasViewDelegate: AnyObject {
    func canvasView(_ view: CanvasView, didDragGroundLineTo y: CGFloat)
    func canvasView(_ view: CanvasView, didDragCameraBoundsTo bounds: CGRect)
    func canvasView(_ view: CanvasView, didDragPlayer1To x: CGFloat)
    func canvasView(_ view: CanvasView, didDragPlayer2To x: CGFloat)
    func canvasView(_ view: CanvasView, didReceiveDroppedImage image: NSImage, filename: String)
}

class CanvasView: NSView {
    
    // MARK: - Types
    
    private enum DragHandle {
        case none
        case groundLine
        case boundsLeft
        case boundsRight
        case boundsTop
        case boundsTopLeft
        case boundsTopRight
        case player1
        case player2
    }
    
    // MARK: - Properties
    
    weak var delegate: CanvasViewDelegate?
    
    private let document: StageDocument
    private var activeDragHandle: DragHandle = .none
    private var dragStartPoint: NSPoint = .zero
    private var dragStartValue: CGFloat = 0
    private var dragStartRect: CGRect = .zero
    
    private var isPreviewMode = false
    private var previewOffset: CGFloat = 0
    
    // Visual constants
    private let handleSize: CGFloat = 10
    private let groundLineColor = NSColor.systemGreen
    private let cameraBoundsColor = NSColor.systemBlue
    private let player1Color = NSColor.systemRed
    private let player2Color = NSColor.systemCyan
    private let screenFrameColor = NSColor.systemYellow
    
    // Padding around image
    private let canvasPadding: CGFloat = 100
    
    // MARK: - Initialization
    
    init(document: StageDocument) {
        self.document = document
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1.0).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Background
        context.setFillColor(NSColor(calibratedWhite: 0.15, alpha: 1.0).cgColor)
        context.fill(bounds)
        
        if document.layers.isEmpty {
            drawEmptyState(in: context)
            return
        }
        
        // Draw background layers
        drawBackgroundLayers(in: context)
        
        if !isPreviewMode {
            // Draw overlays (edit mode only)
            drawScreenFrame(in: context)
            drawCameraBounds(in: context)
            drawGroundLine(in: context)
            drawPlayerMarkers(in: context)
        } else {
            // Preview mode - just show the screen frame at current offset
            drawPreviewFrame(in: context)
        }
    }
    
    private func drawEmptyState(in context: CGContext) {
        // Get the visible rect from the scroll view
        let visibleRect = self.visibleRect
        
        let message = "Drop an image here to start"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let size = attributedString.size()
        let point = NSPoint(
            x: visibleRect.midX - size.width / 2,
            y: visibleRect.midY - size.height / 2
        )
        
        attributedString.draw(at: point)
        
        // Draw drop zone indicator centered in visible area
        let dropSize = CGSize(width: min(500, visibleRect.width - 100), height: min(400, visibleRect.height - 100))
        let dropRect = CGRect(
            x: visibleRect.midX - dropSize.width / 2,
            y: visibleRect.midY - dropSize.height / 2,
            width: dropSize.width,
            height: dropSize.height
        )
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineDash(phase: 0, lengths: [10, 5])
        context.setLineWidth(2)
        context.stroke(dropRect)
    }
    
    private func drawBackgroundLayers(in context: CGContext) {
        for layer in document.layers where layer.visible {
            let imageRect = imageRectForLayer(layer)
            layer.image.draw(in: imageRect)
        }
    }
    
    private func drawScreenFrame(in context: CGContext) {
        let screenRect = screenFrameRect()
        
        // Draw solid yellow border for screen frame (what player sees at rest)
        context.setStrokeColor(screenFrameColor.cgColor)
        context.setLineWidth(3)
        context.setLineDash(phase: 0, lengths: [])
        context.stroke(screenRect)
        
        // Draw corner brackets for emphasis
        let bracketLength: CGFloat = 25
        let corners = [
            (screenRect.minX, screenRect.minY, 1, 1),   // Bottom-left
            (screenRect.maxX, screenRect.minY, -1, 1),  // Bottom-right
            (screenRect.minX, screenRect.maxY, 1, -1),  // Top-left
            (screenRect.maxX, screenRect.maxY, -1, -1)  // Top-right
        ]
        
        context.setLineWidth(5)
        for (x, y, dx, dy) in corners {
            context.move(to: CGPoint(x: x, y: y + CGFloat(dy) * bracketLength))
            context.addLine(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + CGFloat(dx) * bracketLength, y: y))
            context.strokePath()
        }
        
        // Label at top - fixed export size
        let label = "Export Area (1280×720)"
        drawLabel(label, at: NSPoint(x: screenRect.minX + 5, y: screenRect.maxY + 8), color: screenFrameColor)
        
        // Note: Drag the green Ground line to move screen up/down
    }
    
    private func drawCameraBounds(in context: CGContext) {
        let boundsRect = cameraBoundsRect()
        let screenRect = screenFrameRect()
        
        // Draw thick, bright blue border for camera bounds
        context.saveGState()
        
        // Fill the entire bounds area with semi-transparent blue
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.15).cgColor)
        context.fill(boundsRect)
        
        // Draw thick dashed border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(4)
        context.setLineDash(phase: 0, lengths: [12, 6])
        context.stroke(boundsRect)
        
        // Draw handles for resizing bounds
        context.setLineDash(phase: 0, lengths: [])  // Reset to solid
        drawHandle(at: NSPoint(x: boundsRect.minX, y: boundsRect.midY), color: .systemBlue, in: context) // Left
        drawHandle(at: NSPoint(x: boundsRect.maxX, y: boundsRect.midY), color: .systemBlue, in: context) // Right
        drawHandle(at: NSPoint(x: boundsRect.midX, y: boundsRect.maxY), color: .systemBlue, in: context) // Top
        
        // Label showing bounds values
        let boundsLabel = "Camera Bounds (L:\(document.camera.boundLeft) R:\(document.camera.boundRight) H:\(document.camera.boundHigh))"
        drawLabel(boundsLabel, at: NSPoint(x: boundsRect.minX + 5, y: boundsRect.maxY + 10), color: .systemBlue)
        
        context.restoreGState()
    }
    
    private func drawGroundLine(in context: CGContext) {
        let y = groundLineY()
        let startX = canvasPadding - 20
        let endX = bounds.width - canvasPadding + 20
        
        context.setStrokeColor(groundLineColor.cgColor)
        context.setLineWidth(3)
        context.setLineDash(phase: 0, lengths: [])
        context.move(to: CGPoint(x: startX, y: y))
        context.addLine(to: CGPoint(x: endX, y: y))
        context.strokePath()
        
        // Draw handle
        drawHandle(at: NSPoint(x: bounds.width / 2, y: y), color: groundLineColor, in: context)
        
        // Label
        drawLabel("Ground (zoffset: \(document.groundLineY))", at: NSPoint(x: endX + 5, y: y - 8), color: groundLineColor)
    }
    
    private func drawPlayerMarkers(in context: CGContext) {
        let groundY = groundLineY()
        
        // Player 1
        let p1X = playerXInCanvas(document.players.p1X)
        drawPlayerMarker(at: NSPoint(x: p1X, y: groundY), label: "P1", color: player1Color, in: context)
        
        // Player 2
        let p2X = playerXInCanvas(document.players.p2X)
        drawPlayerMarker(at: NSPoint(x: p2X, y: groundY), label: "P2", color: player2Color, in: context)
    }
    
    private func drawPlayerMarker(at point: NSPoint, label: String, color: NSColor, in context: CGContext) {
        // Draw character silhouette - typical fighting game character is ~350px tall
        let characterHeight: CGFloat = 350
        let characterWidth: CGFloat = 120
        
        // Main body rectangle
        let bodyRect = NSRect(
            x: point.x - characterWidth / 2,
            y: point.y,
            width: characterWidth,
            height: characterHeight
        )
        
        context.setFillColor(color.withAlphaComponent(0.25).cgColor)
        context.fill(bodyRect)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.stroke(bodyRect)
        
        // Draw a simple head circle on top
        let headSize: CGFloat = 60
        let headRect = NSRect(
            x: point.x - headSize / 2,
            y: point.y + characterHeight - 20,
            width: headSize,
            height: headSize
        )
        context.fillEllipse(in: headRect)
        context.strokeEllipse(in: headRect)
        
        // Draw drag handle at feet
        drawHandle(at: point, color: color, in: context)
        
        // Label above head
        let labelPoint = NSPoint(x: point.x - 12, y: point.y + characterHeight + headSize - 10)
        drawLabel(label, at: labelPoint, color: color)
    }
    
    private func drawHandle(at point: NSPoint, color: NSColor, in context: CGContext) {
        // Freeform-style handles: filled circle with white border
        let size: CGFloat = 12  // Slightly larger for better visibility
        let rect = NSRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        
        // Drop shadow for depth
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        
        // White border (drawn first, larger)
        let borderRect = rect.insetBy(dx: -1.5, dy: -1.5)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: borderRect)
        
        context.restoreGState()
        
        // Filled center with the accent color (light blue like Freeform)
        let fillColor = NSColor(calibratedRed: 0.35, green: 0.68, blue: 0.94, alpha: 1.0)  // Freeform blue
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: rect)
    }
    
    private func drawLabel(_ text: String, at point: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)
    }
    
    private func drawPreviewFrame(in context: CGContext) {
        let screenSize = document.resolution.size
        let centerX = bounds.width / 2 + previewOffset
        let groundY = groundLineY()
        
        // Screen frame at current preview position
        let screenRect = NSRect(
            x: centerX - screenSize.width / 2,
            y: groundY - screenSize.height + CGFloat(document.resolution.height - document.groundLineY),
            width: screenSize.width,
            height: screenSize.height
        )
        
        // Dim areas outside screen
        context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        
        // Left dim
        context.fill(NSRect(x: 0, y: 0, width: screenRect.minX, height: bounds.height))
        // Right dim
        context.fill(NSRect(x: screenRect.maxX, y: 0, width: bounds.width - screenRect.maxX, height: bounds.height))
        // Top dim
        context.fill(NSRect(x: screenRect.minX, y: screenRect.maxY, width: screenRect.width, height: bounds.height - screenRect.maxY))
        // Bottom dim
        context.fill(NSRect(x: screenRect.minX, y: 0, width: screenRect.width, height: screenRect.minY))
        
        // Screen border
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(screenRect)
    }
    
    // MARK: - Coordinate Conversion
    
    private func imageRectForLayer(_ layer: BackgroundLayer) -> NSRect {
        let imageSize = layer.image.size
        return NSRect(
            x: canvasPadding,
            y: canvasPadding,
            width: imageSize.width,
            height: imageSize.height
        )
    }
    
    private func screenFrameRect() -> NSRect {
        guard let imageSize = document.imageSize else {
            return NSRect(x: canvasPadding, y: canvasPadding, width: 1280, height: 720)
        }
        
        // Fixed export size: 1280x720
        let targetWidth: CGFloat = 1280
        let targetHeight: CGFloat = 720
        let targetAspect = targetWidth / targetHeight
        
        // Calculate the crop rect that matches export behavior
        let imageAspect = imageSize.width / imageSize.height
        
        var cropRect: NSRect
        if imageAspect > targetAspect {
            // Image is wider - crop sides (center horizontally)
            let newWidth = imageSize.height * targetAspect
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = NSRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller - crop top/bottom, bias toward top (30% from top)
            let newHeight = imageSize.width / targetAspect
            let yOffset = (imageSize.height - newHeight) * 0.3
            cropRect = NSRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }
        
        // Convert to canvas coordinates (add padding)
        return NSRect(
            x: canvasPadding + cropRect.origin.x,
            y: canvasPadding + cropRect.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )
    }
    
    private func cameraBoundsRect() -> NSRect {
        guard let imageSize = document.imageSize else {
            return screenFrameRect()
        }
        
        let screenRect = screenFrameRect()
        let camera = document.camera
        let imageRect = NSRect(x: canvasPadding, y: canvasPadding, width: imageSize.width, height: imageSize.height)
        
        // Camera bounds show the full panning area across the stage
        // boundLeft/boundRight are negative/positive offsets from screen edges
        // boundHigh is negative (how far UP the camera can pan)
        // Bottom aligns with image bottom (camera can see full stage height)
        let totalWidth = screenRect.width + CGFloat(camera.boundRight - camera.boundLeft)
        
        // Height from image bottom to screen top + boundHigh extension
        let imageBottom = canvasPadding
        let boundsTop = screenRect.maxY + CGFloat(-camera.boundHigh)
        let totalHeight = boundsTop - imageBottom
        
        var boundsRect = NSRect(
            x: screenRect.minX + CGFloat(camera.boundLeft),
            y: imageBottom,  // Align with image bottom
            width: totalWidth,
            height: totalHeight
        )
        
        // Clamp bounds to image rectangle
        boundsRect.origin.x = max(boundsRect.origin.x, imageRect.minX)
        let rightEdge = min(boundsRect.maxX, imageRect.maxX)
        boundsRect.size.width = max(rightEdge - boundsRect.origin.x, screenRect.width)
        
        let topEdge = min(boundsRect.maxY, imageRect.maxY)
        boundsRect.size.height = max(topEdge - boundsRect.origin.y, screenRect.height)
        
        return boundsRect
    }
    
    private func groundLineY() -> CGFloat {
        guard let imageSize = document.imageSize else {
            return canvasPadding + 200
        }
        // Ground line Y in canvas coordinates (flipped from image coordinates)
        return canvasPadding + imageSize.height - CGFloat(document.groundLineY)
    }
    
    private func playerXInCanvas(_ playerX: Int) -> CGFloat {
        guard let imageSize = document.imageSize else {
            return bounds.width / 2 + CGFloat(playerX)
        }
        // Player X is relative to center, convert to canvas coordinates
        return canvasPadding + imageSize.width / 2 + CGFloat(playerX)
    }
    
    private func canvasXToPlayerX(_ canvasX: CGFloat) -> CGFloat {
        guard let imageSize = document.imageSize else {
            return canvasX - bounds.width / 2
        }
        return canvasX - canvasPadding - imageSize.width / 2
    }
    
    private func canvasYToGroundLineY(_ canvasY: CGFloat) -> CGFloat {
        guard let imageSize = document.imageSize else {
            return 200
        }
        return imageSize.height - (canvasY - canvasPadding)
    }
    
    // MARK: - Hit Testing
    
    private func hitTestHandle(at point: NSPoint) -> DragHandle {
        let hitRadius = handleSize
        
        // Ground line handle
        let groundY = groundLineY()
        if abs(point.y - groundY) < hitRadius && abs(point.x - bounds.width / 2) < hitRadius * 2 {
            return .groundLine
        }
        
        // Camera bounds handles
        let boundsRect = cameraBoundsRect()
        
        // Top-left corner
        if abs(point.x - boundsRect.minX) < hitRadius && abs(point.y - boundsRect.maxY) < hitRadius {
            return .boundsTopLeft
        }
        
        // Top-right corner
        if abs(point.x - boundsRect.maxX) < hitRadius && abs(point.y - boundsRect.maxY) < hitRadius {
            return .boundsTopRight
        }
        
        // Left edge
        if abs(point.x - boundsRect.minX) < hitRadius && point.y > boundsRect.minY && point.y < boundsRect.maxY {
            return .boundsLeft
        }
        
        // Right edge
        if abs(point.x - boundsRect.maxX) < hitRadius && point.y > boundsRect.minY && point.y < boundsRect.maxY {
            return .boundsRight
        }
        
        // Top edge
        if abs(point.y - boundsRect.maxY) < hitRadius && point.x > boundsRect.minX && point.x < boundsRect.maxX {
            return .boundsTop
        }
        
        // Player markers
        let p1X = playerXInCanvas(document.players.p1X)
        if abs(point.x - p1X) < hitRadius && abs(point.y - groundY) < hitRadius {
            return .player1
        }
        
        let p2X = playerXInCanvas(document.players.p2X)
        if abs(point.x - p2X) < hitRadius && abs(point.y - groundY) < hitRadius {
            return .player2
        }
        
        return .none
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        guard !isPreviewMode else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        activeDragHandle = hitTestHandle(at: point)
        dragStartPoint = point
        
        switch activeDragHandle {
        case .groundLine:
            dragStartValue = CGFloat(document.groundLineY)
        case .boundsLeft, .boundsRight, .boundsTop, .boundsTopLeft, .boundsTopRight:
            // Store the CANVAS coordinates of the bounds rect at drag start
            dragStartRect = cameraBoundsRect()
        case .player1:
            dragStartValue = CGFloat(document.players.p1X)
        case .player2:
            dragStartValue = CGFloat(document.players.p2X)
        case .none:
            break
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard activeDragHandle != .none else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartPoint.x
        let deltaY = point.y - dragStartPoint.y
        
        switch activeDragHandle {
        case .groundLine:
            let newGroundY = canvasYToGroundLineY(point.y)
            delegate?.canvasView(self, didDragGroundLineTo: newGroundY)
            
        case .boundsLeft:
            var newBounds = dragStartRect
            newBounds.origin.x = dragStartRect.minX + deltaX
            newBounds.size.width = dragStartRect.maxX - newBounds.origin.x
            updateCameraBoundsFromCanvasRect(newBounds)
            
        case .boundsRight:
            var newBounds = dragStartRect
            newBounds.size.width = dragStartRect.width + deltaX
            updateCameraBoundsFromCanvasRect(newBounds)
            
        case .boundsTop:
            var newBounds = dragStartRect
            newBounds.size.height = dragStartRect.height + deltaY
            updateCameraBoundsFromCanvasRect(newBounds)
            
        case .boundsTopLeft:
            var newBounds = dragStartRect
            newBounds.origin.x = dragStartRect.minX + deltaX
            newBounds.size.width = dragStartRect.maxX - newBounds.origin.x
            newBounds.size.height = dragStartRect.height + deltaY
            updateCameraBoundsFromCanvasRect(newBounds)
            
        case .boundsTopRight:
            var newBounds = dragStartRect
            newBounds.size.width = dragStartRect.width + deltaX
            newBounds.size.height = dragStartRect.height + deltaY
            updateCameraBoundsFromCanvasRect(newBounds)
            
        case .player1:
            let newX = canvasXToPlayerX(point.x)
            delegate?.canvasView(self, didDragPlayer1To: newX)
            
        case .player2:
            let newX = canvasXToPlayerX(point.x)
            delegate?.canvasView(self, didDragPlayer2To: newX)
            
        case .none:
            break
        }
        
        needsDisplay = true
    }
    
    /// Convert canvas rect to camera-relative bounds and update via delegate
    /// Also clamps to image boundaries
    private func updateCameraBoundsFromCanvasRect(_ canvasRect: CGRect) {
        guard let imageSize = document.imageSize else { return }
        
        let screenRect = screenFrameRect()
        let imageRect = NSRect(x: canvasPadding, y: canvasPadding, width: imageSize.width, height: imageSize.height)
        
        // Clamp bounds to image rectangle
        var clampedRect = canvasRect
        
        // Left edge can't go past image left
        clampedRect.origin.x = max(clampedRect.origin.x, imageRect.minX)
        
        // Right edge can't go past image right
        let rightEdge = min(clampedRect.maxX, imageRect.maxX)
        clampedRect.size.width = rightEdge - clampedRect.origin.x
        
        // Top edge can't go past image top
        let topEdge = min(clampedRect.maxY, imageRect.maxY)
        clampedRect.size.height = topEdge - clampedRect.origin.y
        
        // Bottom always stays at image bottom (canvasPadding)
        clampedRect.origin.y = canvasPadding
        
        // Minimum size - at least as big as screen frame
        clampedRect.size.width = max(clampedRect.size.width, screenRect.width)
        clampedRect.size.height = max(clampedRect.size.height, screenRect.height)
        
        // Convert canvas rect to camera-relative bounds
        // boundLeft = how far left of screenRect.minX the bounds extend (negative)
        // boundRight = how far right of screenRect.maxX the bounds extend (positive)
        // boundHigh = how far above screenRect.maxY the bounds extend (negative)
        
        let boundLeft = Int(clampedRect.minX - screenRect.minX)  // Negative if extending left
        let boundRight = Int(clampedRect.maxX - screenRect.maxX)  // Positive if extending right
        let boundHigh = Int(screenRect.maxY - clampedRect.maxY)  // Negative if extending up
        
        // Create the camera bounds rect (x=boundLeft, y=boundHigh, width includes both extensions)
        let cameraBounds = CGRect(
            x: CGFloat(boundLeft),
            y: CGFloat(boundHigh),
            width: CGFloat(boundRight - boundLeft),
            height: 0  // Not used directly, we only care about boundHigh
        )
        
        delegate?.canvasView(self, didDragCameraBoundsTo: cameraBounds)
    }
    
    override func mouseUp(with event: NSEvent) {
        activeDragHandle = .none
    }
    
    // MARK: - Cursor
    
    override func resetCursorRects() {
        // TODO: Add cursor rects for handles
    }
    
    // MARK: - Preview Mode
    
    func setPreviewMode(_ enabled: Bool) {
        isPreviewMode = enabled
        needsDisplay = true
    }
    
    func setPreviewOffset(_ offset: CGFloat) {
        previewOffset = offset
        needsDisplay = true
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
              let url = URL(string: pasteboard) else {
            return false
        }
        
        guard let image = NSImage(contentsOf: url) else {
            return false
        }
        
        let filename = url.deletingPathExtension().lastPathComponent
        delegate?.canvasView(self, didReceiveDroppedImage: image, filename: filename)
        
        return true
    }
}
