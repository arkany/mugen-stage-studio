import Foundation
import Cocoa

// MARK: - Stage Document

/// Main data model representing a stage being edited
class StageDocument: ObservableObject {
    
    // MARK: - Undo Manager
    
    /// The undo manager for this document. Set by the window controller.
    weak var undoManager: UndoManager?
    
    // MARK: - Published Properties
    
    @Published var name: String = "" {
        didSet {
            if oldValue != name {
                registerUndo(oldValue: oldValue, newValue: name, keyPath: \.name, actionName: "Change Name")
            }
        }
    }
    
    @Published var resolution: Resolution = .hd_1280x720 {
        didSet {
            if oldValue != resolution {
                registerUndo(oldValue: oldValue, newValue: resolution, keyPath: \.resolution, actionName: "Change Resolution")
            }
        }
    }
    
    @Published var targetEngine: Engine = .ikemenGo {
        didSet {
            if oldValue != targetEngine {
                registerUndo(oldValue: oldValue, newValue: targetEngine, keyPath: \.targetEngine, actionName: "Change Engine")
            }
        }
    }
    
    @Published var camera: CameraSettings = CameraSettings()
    @Published var players: PlayerSettings = PlayerSettings()
    @Published var shadow: ShadowSettings = ShadowSettings()
    @Published var layers: [BackgroundLayer] = []
    
    /// The Y position of the ground line (converts to zoffset)
    @Published var groundLineY: Int = 645 {
        didSet {
            if oldValue != groundLineY {
                registerUndo(oldValue: oldValue, newValue: groundLineY, keyPath: \.groundLineY, actionName: "Move Ground Line")
            }
        }
    }
    
    // MARK: - Undo Support
    
    /// Register an undo action for a simple value change
    private func registerUndo<T>(oldValue: T, newValue: T, keyPath: ReferenceWritableKeyPath<StageDocument, T>, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            target[keyPath: keyPath] = oldValue
        }
        undoManager?.setActionName(actionName)
    }
    
    /// Set a property without triggering undo registration (for programmatic changes)
    func setWithoutUndo<T>(_ keyPath: ReferenceWritableKeyPath<StageDocument, T>, to value: T) {
        undoManager?.disableUndoRegistration()
        self[keyPath: keyPath] = value
        undoManager?.enableUndoRegistration()
    }
    
    // MARK: - Layer Management with Undo
    
    func addLayer(_ layer: BackgroundLayer, actionName: String = "Add Layer") {
        let index = layers.count
        layers.append(layer)
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.removeLayer(at: index, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    func removeLayer(at index: Int, actionName: String = "Remove Layer") {
        guard index < layers.count else { return }
        let removedLayer = layers[index]
        layers.remove(at: index)
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.insertLayer(removedLayer, at: index, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    func insertLayer(_ layer: BackgroundLayer, at index: Int, actionName: String = "Insert Layer") {
        layers.insert(layer, at: min(index, layers.count))
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.removeLayer(at: index, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    func updateLayer(at index: Int, with layer: BackgroundLayer, actionName: String = "Edit Layer") {
        guard index < layers.count else { return }
        let oldLayer = layers[index]
        layers[index] = layer
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.updateLayer(at: index, with: oldLayer, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    // MARK: - Player Position with Undo
    
    func setPlayer1X(_ x: Int, actionName: String = "Move Player 1") {
        let oldValue = players.p1X
        players.p1X = x
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.setPlayer1X(oldValue, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    func setPlayer2X(_ x: Int, actionName: String = "Move Player 2") {
        let oldValue = players.p2X
        players.p2X = x
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.setPlayer2X(oldValue, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    // MARK: - Camera Bounds with Undo
    
    func setCameraBounds(_ bounds: CGRect, actionName: String = "Resize Camera Bounds") {
        let oldBounds = camera.boundsRect
        camera.boundsRect = bounds
        
        undoManager?.registerUndo(withTarget: self) { [weak self] target in
            self?.setCameraBounds(oldBounds, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
    
    /// Sanitized name for file/folder naming (spaces → underscores, safe characters only)
    var safeName: String {
        name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }
    
    /// Computed image dimensions from first layer
    var imageSize: CGSize? {
        layers.first?.image.size
    }
    
    /// Apply smart defaults based on image size
    func applyDefaults(for imageSize: CGSize) {
        // Use fixed resolution size, or 1280x720 as localcoord for custom
        let screenWidth = resolution.size?.width ?? 1280
        let screenHeight = resolution.size?.height ?? 720
        
        // Ground line (zoffset): position from top of screen where floor is
        // For custom/scrolling stages: position relative to image, ground near bottom
        // For fixed resolution: position within the viewport (720 - 60 = 660)
        if resolution == .custom {
            // Ground should be near the bottom of the image
            // ~60px from the bottom of the actual image
            groundLineY = Int(imageSize.height) - 60
        } else {
            // For fixed resolution, ground at bottom of viewport
            groundLineY = Int(screenHeight) - 60
        }
        
        // Camera bounds: how far camera can pan based on image vs screen size
        let cameraPanX = max(0, (imageSize.width - screenWidth) / 2)
        let cameraPanY = max(0, imageSize.height - screenHeight)
        
        camera.boundsRect = CGRect(
            x: -cameraPanX,
            y: -cameraPanY,
            width: cameraPanX * 2,
            height: cameraPanY
        )
        
        // Background layer position for canvas display (centered, bottom-aligned)
        if var layer = layers.first {
            layer.position = CGPoint(
                x: -imageSize.width / 2,
                y: -(imageSize.height - screenHeight)
            )
            layers[0] = layer
        }
        
        // Player positions: use reasonable spacing (within half screen width)
        let playerSpacing = min(200, Int(screenWidth / 4))
        players.p1X = -playerSpacing
        players.p2X = playerSpacing
    }
}

// MARK: - Camera Settings

struct CameraSettings {
    /// Visual bounds rectangle (converts to boundleft/right/high/low)
    var boundsRect: CGRect = CGRect(x: -160, y: -25, width: 320, height: 25)
    
    /// Horizontal tension (distance before camera follows)
    var tension: Int = 50
    
    /// Vertical tracking closeness (0.0–1.0)
    var verticalFollow: Float = 0.2
    
    /// Vertical distance from floor before tracking
    var floorTension: Int = 160
    
    /// Zoom settings (MUGEN 1.1+ / IKEMEN only)
    var zoomEnabled: Bool = true
    var zoomStart: Float = 1.0
    var zoomMin: Float = 0.5   // zoomout - how far camera can zoom out
    var zoomMax: Float = 1.5   // zoomin - how far camera can zoom in
    
    // Computed DEF values
    var boundLeft: Int { Int(boundsRect.minX) }
    var boundRight: Int { Int(boundsRect.maxX) }
    var boundHigh: Int { Int(boundsRect.minY) }
    var boundLow: Int { 0 } // Always 0
}

// MARK: - Player Settings

struct PlayerSettings {
    var p1X: Int = -70
    var p2X: Int = 70
    // Y always 0, facing always 1/-1 (auto-calculated)
    
    var p1Facing: Int { 1 }   // Always faces right
    var p2Facing: Int { -1 }  // Always faces left
}

// MARK: - Shadow Settings

struct ShadowSettings {
    var enabled: Bool = true
    var intensity: Int = 128   // 0-256
    var yscale: Float = 0.4
}

// MARK: - Background Layer

struct BackgroundLayer: Identifiable {
    let id: UUID
    var name: String
    var image: NSImage
    var position: CGPoint
    var delta: CGPoint          // Parallax factor
    var tiling: TileMode
    var layerIndex: Int         // 0 = behind characters, 1 = in front
    var visible: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        image: NSImage,
        position: CGPoint = .zero,
        delta: CGPoint = CGPoint(x: 1, y: 1),
        tiling: TileMode = .none,
        layerIndex: Int = 0,
        visible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.position = position
        self.delta = delta
        self.tiling = tiling
        self.layerIndex = layerIndex
        self.visible = visible
    }
}

// MARK: - Enums

enum Resolution: String, CaseIterable, Identifiable {
    case hd_1280x720 = "1280×720"
    case fullhd_1920x1080 = "1920×1080"
    case classic_320x240 = "320×240"
    case sd_640x480 = "640×480"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    /// Returns the fixed size for this resolution, or nil for custom
    var size: CGSize? {
        switch self {
        case .hd_1280x720: return CGSize(width: 1280, height: 720)
        case .fullhd_1920x1080: return CGSize(width: 1920, height: 1080)
        case .classic_320x240: return CGSize(width: 320, height: 240)
        case .sd_640x480: return CGSize(width: 640, height: 480)
        case .custom: return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .hd_1280x720: return "HD (1280×720)"
        case .fullhd_1920x1080: return "Full HD (1920×1080)"
        case .classic_320x240: return "Classic (320×240)"
        case .sd_640x480: return "SD (640×480)"
        case .custom: return "Custom (Original Size)"
        }
    }
    
    var width: Int? { size.map { Int($0.width) } }
    var height: Int? { size.map { Int($0.height) } }
    
    /// Whether this resolution allows scrolling (custom always does, fixed resolutions don't)
    var allowsScrolling: Bool {
        self == .custom
    }
}

enum Engine: String, CaseIterable, Identifiable {
    case ikemenGo = "IKEMEN GO"
    case mugen11 = "MUGEN 1.1"
    case mugen10 = "MUGEN 1.0"
    
    var id: String { rawValue }
    
    var mugenVersion: String {
        switch self {
        case .ikemenGo: return "1.1"
        case .mugen11: return "1.1"
        case .mugen10: return "1.0"
        }
    }
    
    var supportsZoom: Bool {
        self != .mugen10
    }
}

enum TileMode: String, CaseIterable, Identifiable {
    case none = "None"
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case both = "Both"
    
    var id: String { rawValue }
    
    /// Returns the tile value for DEF file (x, y format)
    var defValue: String {
        switch self {
        case .none: return "0, 0"
        case .horizontal: return "1, 0"
        case .vertical: return "0, 1"
        case .both: return "1, 1"
        }
    }
}
