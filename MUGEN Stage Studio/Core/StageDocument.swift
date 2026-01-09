import Foundation
import Cocoa

// MARK: - Stage Document

/// Main data model representing a stage being edited
class StageDocument: ObservableObject {
    
    @Published var name: String = ""
    @Published var resolution: Resolution = .hd_1280x720
    @Published var targetEngine: Engine = .ikemenGo
    @Published var camera: CameraSettings = CameraSettings()
    @Published var players: PlayerSettings = PlayerSettings()
    @Published var shadow: ShadowSettings = ShadowSettings()
    @Published var layers: [BackgroundLayer] = []
    
    /// The Y position of the ground line (converts to zoffset)
    @Published var groundLineY: Int = 645
    
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
        let screenWidth = resolution.size.width
        let screenHeight = resolution.size.height
        
        // Ground line: image height - 75 (from learnings)
        groundLineY = Int(imageSize.height) - 75
        
        // Camera bounds: how far camera can pan
        let cameraPanX = max(0, (imageSize.width - screenWidth) / 2)
        let cameraPanY = max(0, imageSize.height - screenHeight - 25)
        
        camera.boundsRect = CGRect(
            x: -cameraPanX,
            y: -cameraPanY,
            width: cameraPanX * 2,
            height: cameraPanY
        )
        
        // Background layer position (centered, bottom-aligned)
        if var layer = layers.first {
            layer.position = CGPoint(
                x: -imageSize.width / 2,
                y: -(imageSize.height - screenHeight)
            )
            layers[0] = layer
        }
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
    
    var id: String { rawValue }
    
    var size: CGSize {
        switch self {
        case .hd_1280x720: return CGSize(width: 1280, height: 720)
        case .fullhd_1920x1080: return CGSize(width: 1920, height: 1080)
        case .classic_320x240: return CGSize(width: 320, height: 240)
        case .sd_640x480: return CGSize(width: 640, height: 480)
        }
    }
    
    var displayName: String {
        switch self {
        case .hd_1280x720: return "HD (1280×720)"
        case .fullhd_1920x1080: return "Full HD (1920×1080)"
        case .classic_320x240: return "Classic (320×240)"
        case .sd_640x480: return "SD (640×480)"
        }
    }
    
    var width: Int { Int(size.width) }
    var height: Int { Int(size.height) }
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
