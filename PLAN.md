# MUGEN Stage Studio — Project Plan

> **Vision:** Create a usable fighting game stage in under 2 minutes.

A native macOS app that transforms MUGEN/IKEMEN GO stage creation from a 30-minute manual process into a visual, drag-and-drop workflow.

---

## Table of Contents

1. [Product Overview](#product-overview)
2. [Target Users](#target-users)
3. [Competitive Analysis](#competitive-analysis)
4. [Technical Domain](#technical-domain)
5. [Simplification Strategy](#simplification-strategy)
6. [Product Requirements](#product-requirements)
7. [UX & UI Structure](#ux--ui-structure)
8. [Data Models](#data-models)
9. [Export Pipeline](#export-pipeline)
10. [Tech Stack](#tech-stack)
11. [Implementation Steps](#implementation-steps)
12. [File Structure](#file-structure)

---

## Product Overview

### What It Does

- Drop in one background image
- Visually adjust camera bounds, ground level, and player placement
- Preview the fight framing live
- Export a working, validated stage for IKEMEN GO (primary) / MUGEN (secondary)

### Core Insight

80% of stages use only 10% of MUGEN's stage parameters. Hide complexity, surface what matters visually.

### Primary Target Engine

**IKEMEN GO** — Cross-platform, open-source, actively developed, runs natively on Mac.

Secondary support for MUGEN 1.1 and 1.0 export compatibility.

---

## Target Users

| User Type | Pain Point |
|-----------|------------|
| Indie creators | Want to make stages, not edit config files |
| Designers | Hate .def file syntax |
| Mac users | No native visual tools exist |
| Fighter Factory refugees | Tool is complex, Windows-centric |

**Assumption:** Zero tolerance for arcane configuration.

---

## Competitive Analysis

### Current Landscape

| Tool | Platform | Visual Editor | Real-time Preview | Mac Native |
|------|----------|--------------|-------------------|------------|
| Fighter Factory Studio | Win/Linux/macOS | ❌ Sprite-only | ❌ | ⚠️ Limited |
| Sprmake2 | Windows CLI | ❌ | ❌ | ❌ |
| Manual workflow | Any | ❌ | ❌ | N/A |

### Key Finding

**No visual stage layout editor exists.** Fighter Factory is a sprite/file manager, not a stage designer. All tools require manual DEF file editing and trial-and-error testing.

### How Mac Users Cope Today

1. Fighter Factory (limited macOS support)
2. Wine/CrossOver for Windows tools
3. Parallels/VMware for full Windows VM
4. Manual text editing + repeated IKEMEN GO launches

---

## Technical Domain

### Minimum Viable Stage Files

| File | Purpose | Required |
|------|---------|----------|
| `[name].def` | Stage definition (INI format) | ✅ |
| `[name].sff` | Sprite container (SFF v2) | ✅ |

### DEF File Sections (Generate-Only Schema)

```ini
[Info]        → name, mugenversion, ikemenversion
[Camera]      → startx, starty, boundleft, boundright, boundhigh, boundlow, 
                tension, verticalfollow, floortension
[PlayerInfo]  → p1startx, p2startx, p1facing, p2facing, leftbound, rightbound
[Bound]       → screenleft, screenright
[StageInfo]   → zoffset, autoturn, resetBG, localcoord
[Shadow]      → intensity, yscale (optional)
[BGDef]       → spr path
[BG x]        → type, spriteno, start, delta, tile, layerno (per element)
```

### SFF v2 File Format (from prior implementation)

#### Header Structure (68 bytes)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 12 | Signature: `ElecbyteSpr\0` |
| 12 | 4 | Version (v2.01 = `0x00, 0x01, 0x00, 0x02`) |
| 36 | 4 | Sprite list offset |
| 40 | 4 | Sprite count |
| 44 | 4 | Palette list offset |
| 48 | 4 | Palette count |
| 52 | 4 | Ldata offset |
| 56 | 4 | Ldata length |
| 60 | 4 | Tdata offset |
| 64 | 4 | Tdata length |

#### Sprite Node (28 bytes each)

```
[0-1]   Group number (UInt16)
[2-3]   Image number (UInt16)
[4-5]   Width (UInt16)
[6-7]   Height (UInt16)
[8-9]   X axis offset (Int16)
[10-11] Y axis offset (Int16)
[12-13] Linked index (0xFFFF = not linked)
[14]    Format (11 = PNG24, 12 = PNG32)
[15]    Color depth (32 for PNG32)
[16-19] Data offset in ldata
[20-23] Data length
[24-25] Palette index (0 for PNG)
[26-27] Flags (0 = uses ldata)
```

#### Critical SFF Learnings

1. **Dummy palette is mandatory** — Even PNG-only files need one palette entry
2. **PNG data needs 4-byte length prefix** — Uncompressed pixel size header
3. **Sprite list starts at offset 68** — After full header, not earlier

### Engine Compatibility

| Feature | IKEMEN GO | MUGEN 1.1 | MUGEN 1.0 |
|---------|-----------|-----------|-----------|
| Basic camera | ✅ | ✅ | ✅ |
| Zoom settings | ✅ | ✅ | ❌ Omit |
| `ikemenversion` | ✅ | ❌ Omit | ❌ Omit |
| HD `localcoord` | ✅ | ✅ | ⚠️ Warn |
| Video backgrounds | ✅ Future | ❌ | ❌ |

### Common Failure Modes to Prevent

| Error | Cause | App Prevention |
|-------|-------|----------------|
| Characters floating | Wrong `zoffset` | Visual ground line editor |
| Hall of mirrors | Background gaps | Coverage validation |
| Stage scrolls into void | Bad bounds | Auto-calculate from image |
| Black screen | No BG elements | Require at least one layer |

---

## Simplification Strategy

### Parameter Translation: Config → Visual

| MUGEN Parameter | User-Facing Affordance |
|-----------------|------------------------|
| `zoffset` | Draggable **ground line** overlay |
| `boundleft/boundright` | Resizable **camera bounds box** |
| `boundhigh/boundlow` | Top/bottom **camera limit handles** |
| `p1startx/p2startx` | Draggable **player position markers** |
| `localcoord` | Dropdown preset (1280×720 default) |
| `delta` (parallax) | **Layer depth slider** (Near ↔ Far) — v1.1 |
| `tension` | "Camera Tightness" slider (Advanced) |

### Smart Defaults

| Parameter | Default | Rationale |
|-----------|---------|-----------|
| `localcoord` | 1280×720 | Modern HD standard |
| `tension` | 50 | Standard fighting game feel |
| `verticalfollow` | 0.2 | Smooth vertical tracking |
| `p1startx/p2startx` | ±70 | Standard spacing |
| `autoturn` | 1 | Always on |
| `screenleft/screenright` | 15 | Prevent edge-clipping |
| `floortension` | 160 | Standard value |

### Proven Calculation Formulas

From prior IKEMEN Lab implementation:

```swift
// Ground level (user-adjustable via drag, this is the default)
let zoffset = imgHeight - 75

// Camera horizontal bounds
let cameraPanX = max(0, (imgWidth - screenWidth) / 2)
let boundLeft = -cameraPanX
let boundRight = cameraPanX

// Player movement limits
let leftbound = -imgWidth / 2 + 50
let rightbound = imgWidth / 2 - 50

// Background positioning (center, bottom-aligned)
let bgStartX = -imgWidth / 2
let bgStartY = -(imgHeight - screenHeight)
```

### Parameter Visibility Tiers

| Tier | Parameters | Visibility |
|------|------------|------------|
| **Always Visible** | Ground line, camera bounds, player positions | Canvas handles |
| **Inspector Panel** | Shadow intensity, layer order | Sidebar controls |
| **Advanced Toggle** | Exact numeric values, tension, zoom | Expandable section |
| **Hidden (Auto)** | `startx/y`, `autoturn`, `resetBG`, facing | Never shown |

### Presets

**Resolution Presets:**
- HD (1280×720, 16:9) — Default
- Full HD (1920×1080, 16:9)
- Classic (320×240, 4:3)
- SD (640×480, 4:3)

**Style Presets (Future):**
- "Street Fighter" — Tight camera, minimal vertical follow
- "Marvel vs Capcom" — Wide bounds, fast tracking

---

## Product Requirements

### MVP Features (v1.0)

#### Core User Flow

1. **Launch** → Empty canvas with "Drop image here" prompt
2. **Import** → Drag PNG/JPG → Auto-sized canvas, image becomes BG layer 0
3. **Adjust Ground** → Drag horizontal ground line to set `zoffset`
4. **Adjust Camera** → Drag camera bounds rectangle corners/edges
5. **Position Players** → Drag P1/P2 markers (facing auto-calculated)
6. **Preview** → Toggle "Fight Preview" mode with simulated camera pan
7. **Export** → Click Export → Select folder → Generates `.def` + `.sff`

#### Required UI Surfaces

| Surface | Purpose |
|---------|---------|
| **Canvas** | Main editing area with background + overlays |
| **Toolbar** | Mode toggles (Edit/Preview), zoom, undo/redo |
| **Inspector** | Stage name, resolution, engine target, advanced settings |
| **Layer List** | Background layers (MVP: single layer) |
| **Export Panel** | Folder selection, validation status |

#### Editing Tools

- Pan canvas (scroll/trackpad)
- Zoom canvas (pinch/⌘+scroll)
- Select/drag handles (ground, bounds, players)
- Layer visibility toggle

#### Preview Behavior

- **Static:** Shows final framing at rest position
- **Animated:** Camera pans left↔right across full bounds range (looping)

#### Export Behavior

- Validates all required parameters
- Generates DEF file with all sections
- Embeds image + thumbnail into SFF v2
- Creates folder: `stages/[name]/[name].def`, `stages/[name]/[name].sff`

### Post-MVP Features (v1.1+)

| Feature | Priority | Notes |
|---------|----------|-------|
| Multiple BG layers | High | Add/import additional sprites |
| Parallax wizard | High | Visual depth configuration per layer |
| IKEMEN-specific export options | Medium | Zoom settings, per-round music |
| Stage templates | Medium | Pre-configured starting points |
| Live validation warnings | Medium | Real-time error indicators |
| Animated backgrounds | Low | Frame sequence import |
| Fighter Factory import | Low | Open existing .def/.sff |

### Validation Rules

| Rule | Severity | Message |
|------|----------|---------|
| No background layers | 🔴 Error | "Add at least one background image" |
| Camera bounds exceed image | 🟡 Warning | "Camera may scroll beyond background" |
| Ground line outside image | 🔴 Error | "Ground line must be within image" |
| Players outside bounds | 🟡 Warning | "Players start outside camera view" |
| Missing stage name | 🔴 Error | "Enter a stage name" |
| Image too small | 🔴 Error | "Image must be at least 320×240" |
| Image too large | 🟡 Warning | "Images over 4096px may cause issues" |

---

## UX & UI Structure

### App Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ MUGEN Stage Studio                                [Edit] [Preview]  │
├──────────────┬──────────────────────────────────────┬───────────────┤
│              │                                      │  INSPECTOR    │
│   LAYERS     │                                      │               │
│   ─────      │         C A N V A S                  │  Stage        │
│   ☑ Layer 0  │                                      │  ├ Name: ___  │
│              │    ┌──────────────────────┐          │  ├ Resolution │
│              │    │   Camera Bounds      │          │  │  [1280×720]│
│   [+ Add]    │    │   ┌──────────────┐   │          │  └ Engine     │
│              │    │   │              │   │          │    [IKEMEN ▼] │
│              │    │   │  P1      P2  │   │          │               │
│              │    │   │   ●      ●   │   │          │  Background   │
│              │    │───┼──────────────┼───│← Ground  │  ├ Position   │
│              │    │   └──────────────┘   │          │  └ Tiling     │
│              │    └──────────────────────┘          │               │
│              │                                      │  [Advanced ▼] │
│              │                                      │               │
├──────────────┴──────────────────────────────────────┴───────────────┤
│ [Export]                    ◀ ● ▶ Preview Controls      Zoom: 100%  │
└─────────────────────────────────────────────────────────────────────┘
```

### Interaction Specifications

| Element | Click | Drag | Scroll |
|---------|-------|------|--------|
| Canvas background | Deselect all | Pan canvas | Zoom |
| Ground line | Select | Move Y position | — |
| Camera bounds corner | Select | Resize proportionally | — |
| Camera bounds edge | Select | Resize single axis | — |
| Player marker | Select | Move X position | — |
| Layer row | Select layer | Reorder (future) | — |

### Preview Modes

1. **Edit Mode** — All handles visible, interactive
2. **Static Preview** — Handles hidden, shows centered view
3. **Animated Preview** — Camera pans across bounds (2-second loop)

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Import image |
| ⌘E | Export stage |
| ⌘Z | Undo |
| ⇧⌘Z | Redo |
| Space | Toggle Edit/Preview |
| ⌘1 | Zoom to fit |
| ⌘0 | Zoom 100% |
| ⌘+ | Zoom in |
| ⌘- | Zoom out |

---

## Data Models

### Internal Model

```swift
struct StageDocument {
    var name: String
    var resolution: Resolution
    var targetEngine: Engine
    var camera: CameraSettings
    var players: PlayerSettings
    var shadow: ShadowSettings
    var layers: [BackgroundLayer]
}

struct CameraSettings {
    var boundsRect: CGRect           // Visual bounds (converts to boundleft/right/high/low)
    var tension: Int = 50
    var verticalFollow: Float = 0.2
    var floorTension: Int = 160
    var zoom: ZoomSettings?          // MUGEN 1.1+ / IKEMEN only
}

struct ZoomSettings {
    var start: Float = 1.0
    var min: Float = 1.0             // zoomout
    var max: Float = 1.0             // zoomin
}

struct PlayerSettings {
    var p1X: Int = -70
    var p2X: Int = 70
    // Y always 0, facing always 1/-1 (auto)
}

struct ShadowSettings {
    var enabled: Bool = true
    var intensity: Int = 128
    var yscale: Float = 0.4
}

struct BackgroundLayer {
    var id: UUID
    var name: String
    var image: NSImage
    var position: CGPoint            // start x, y
    var delta: CGPoint = CGPoint(x: 1, y: 1)  // parallax
    var tiling: TileMode = .none
    var layerIndex: Int = 0          // 0 = behind, 1 = front
    var visible: Bool = true
}

enum Resolution: String, CaseIterable {
    case hd_1280x720 = "1280×720"
    case fullhd_1920x1080 = "1920×1080"
    case classic_320x240 = "320×240"
    case sd_640x480 = "640×480"
    
    var size: CGSize { ... }
}

enum Engine: String, CaseIterable {
    case ikemenGo = "IKEMEN GO"
    case mugen11 = "MUGEN 1.1"
    case mugen10 = "MUGEN 1.0"
}

enum TileMode {
    case none
    case horizontal
    case vertical
    case both
}
```

### UI → Model → Export Mapping

| UI Action | Model Change | DEF Output |
|-----------|--------------|------------|
| Drag ground line to Y=180 | `groundLineY = 180` | `zoffset = 180` |
| Resize bounds wider | `camera.boundsRect.width += Δ` | `boundleft/right` recalc |
| Move P1 marker left | `players.p1X -= Δ` | `p1startx = [value]` |
| Change resolution | `resolution = .fullhd` | `localcoord = 1920, 1080` |

---

## Export Pipeline

### Generated Folder Structure

```
[selected_folder]/
└── [stage_name]/
    ├── [stage_name].def
    └── [stage_name].sff
```

### DEF Generation Template

```ini
; Generated by MUGEN Stage Studio
; https://github.com/[repo]

[Info]
name = "{stage.name}"
displayname = "{stage.name}"
mugenversion = {engine.mugenVersion}
{if engine == .ikemenGo}ikemenversion = 1.0{/if}
author = "MUGEN Stage Studio"

[Camera]
startx = 0
starty = 0
boundleft = {camera.boundLeft}
boundright = {camera.boundRight}
boundhigh = {camera.boundHigh}
boundlow = 0
tension = {camera.tension}
verticalfollow = {camera.verticalFollow}
floortension = {camera.floorTension}
{if engine >= .mugen11 && camera.zoom}
startzoom = {zoom.start}
zoomin = {zoom.max}
zoomout = {zoom.min}
{/if}

[PlayerInfo]
p1startx = {players.p1X}
p1starty = 0
p1facing = 1
p2startx = {players.p2X}
p2starty = 0
p2facing = -1
leftbound = {calculated.leftbound}
rightbound = {calculated.rightbound}

[Bound]
screenleft = 15
screenright = 15

[StageInfo]
zoffset = {groundLineY}
autoturn = 1
resetBG = 1
localcoord = {resolution.width}, {resolution.height}

[Shadow]
intensity = {shadow.intensity}
yscale = {shadow.yscale}

[BGDef]
spr = stages/{stage.name}/{stage.name}.sff
debugbg = 0

[BG 0]
type = normal
spriteno = 0, 0
start = {layer0.position.x}, {layer0.position.y}
delta = {layer0.delta.x}, {layer0.delta.y}
tile = {layer0.tileValue}
layerno = 0

; Thumbnail for stage select
[Begin Action 9000]
9000,1, 0,0, -1
```

### SFF Generation

Sprites to embed:

| Group | Index | Content | Size |
|-------|-------|---------|------|
| 0 | 0 | Background image | Original |
| 9000 | 1 | Thumbnail | 240×100 |

Plus one dummy palette (group 0, item 0).

### Export Sanity Checklist

- [ ] Stage name is valid filename (alphanumeric, underscore, hyphen)
- [ ] At least one background layer exists
- [ ] All images successfully encoded to PNG
- [ ] Camera bounds are valid (left < 0 < right)
- [ ] Ground level within image height
- [ ] Player positions within playable bounds
- [ ] Target folder is writable
- [ ] No file overwrite without confirmation

---

## Tech Stack

### Framework Decisions

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Language** | Swift 5.9+ | Native macOS, modern features |
| **UI Framework** | AppKit (main) + SwiftUI (inspector) | Per guidelines: better input, fullscreen |
| **Canvas** | NSView + Core Graphics | Direct drawing, simple coordinates |
| **SFF Writer** | Port from IKEMEN Lab | Already battle-tested |
| **Window** | NSWindowController + NSViewController | Standard pattern |
| **File Dialogs** | NSOpenPanel / NSSavePanel | Sandbox-compliant |
| **State** | @Observable or Combine | Reactive UI updates |
| **Target OS** | macOS 11.0+ (Big Sur) | Balance modern APIs with reach |

### Why AppKit Over SwiftUI (Per Guidelines)

| Consideration | AppKit | SwiftUI |
|---------------|--------|---------|
| Fullscreen handling | Mature | Inconsistent |
| Direct input events | Yes | Extra abstraction |
| Drag-and-drop | Native, proven | Requires workarounds |
| macOS version support | 10.13+ | 11.0+ for full features |

### Sandboxing

Required entitlements:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

Use security-scoped bookmarks to remember export folder across launches.

### Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Large images (4K+) | Display thumbnail, full-res on export only |
| Memory with layers | Lazy-load non-visible layers |
| Canvas responsiveness | Render on main thread, optimize redraws |

---

## Implementation Steps

### Phase 1: Foundation

1. **Create Xcode project** — macOS App, AppKit lifecycle, Swift
2. **Set up main window** — NSWindowController with split view layout
3. **Port SFFWriter.swift** — From IKEMEN Lab, adapt for standalone
4. **Port thumbnail generation** — 240×100, bias toward top crop

### Phase 2: Canvas

5. **Create CanvasView (NSView)** — Core Graphics rendering
6. **Implement image loading** — Drag-and-drop, NSOpenPanel
7. **Draw background layer** — Scaled to fit, maintain aspect
8. **Add overlay rendering** — Ground line, camera bounds, player markers

### Phase 3: Interaction

9. **Implement hit testing** — Detect clicks on handles
10. **Add drag handling** — Ground line Y, bounds resize, player X
11. **Connect to model** — Update StageDocument on drag
12. **Add undo/redo** — NSUndoManager integration

### Phase 4: Inspector

13. **Create SwiftUI inspector** — Stage name, resolution, engine picker
14. **Host in NSHostingController** — Embed in right sidebar
15. **Bind to model** — Two-way sync with StageDocument
16. **Add advanced section** — Collapsible, shows numeric values

### Phase 5: Preview

17. **Implement static preview** — Hide handles, show centered
18. **Add animated preview** — TimelineView or CADisplayLink camera pan
19. **Toggle button** — Edit ↔ Preview modes

### Phase 6: Export

20. **Create ValidationEngine** — Check all rules, return errors/warnings
21. **Implement DEF generator** — Template-based string building
22. **Wire up NSSavePanel** — Folder selection with bookmark
23. **Full export pipeline** — Validate → Generate → Write files

### Phase 7: Polish

24. **Add menu bar items** — File, Edit, View menus
25. **Implement keyboard shortcuts** — Per specification
26. **Add empty state** — "Drop image here" prompt
27. **Error handling** — User-friendly alerts
28. **App icon and branding** — Design and add assets

---

## File Structure

```
MUGEN Stage Studio/
├── MUGEN Stage Studio.xcodeproj
├── MUGEN Stage Studio/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── MainWindowController.swift
│   │   ├── MainViewController.swift
│   │   ├── MainMenu.xib
│   │   └── Info.plist
│   ├── Core/
│   │   ├── StageDocument.swift          # Main data model
│   │   ├── SFFWriter.swift              # SFF v2 binary writer (ported)
│   │   ├── DEFGenerator.swift           # .def file string builder
│   │   ├── ThumbnailGenerator.swift     # Stage select thumbnail
│   │   └── ValidationEngine.swift       # Pre-export validation
│   ├── Views/
│   │   ├── CanvasView.swift             # NSView with Core Graphics
│   │   ├── CanvasOverlayRenderer.swift  # Draws handles/guides
│   │   ├── LayerSidebarView.swift       # NSOutlineView wrapper
│   │   └── InspectorView.swift          # SwiftUI inspector panel
│   ├── Controllers/
│   │   ├── CanvasViewController.swift   # Manages canvas + input
│   │   ├── ExportController.swift       # Export flow orchestration
│   │   └── PreviewController.swift      # Preview mode logic
│   ├── Utilities/
│   │   ├── CGExtensions.swift           # Geometry helpers
│   │   ├── NSImageExtensions.swift      # Image processing
│   │   └── FileBookmarkManager.swift    # Security-scoped bookmarks
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Localizable.strings
│   └── Entitlements/
│       └── MUGEN Stage Studio.entitlements
├── MUGEN Stage StudioTests/
│   ├── SFFWriterTests.swift
│   ├── DEFGeneratorTests.swift
│   └── ValidationEngineTests.swift
├── PLAN.md                              # This file
├── macos-native-guidelines.md           # Platform guidelines
└── png-stage-creator-learnings.md       # Prior implementation learnings
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Time to first stage | < 2 minutes |
| Export success rate | > 95% (valid stages) |
| Learning curve | Zero documentation needed |
| App launch time | < 1 second |
| Export time | < 3 seconds for 4K image |

---

## Open Questions

1. **Document-based app?** Should we use NSDocument architecture for save/open of `.mss` project files, or keep it simple with direct export only?

2. **Undo granularity?** Undo each drag increment, or only on mouse-up?

3. **Multi-window?** Allow multiple stage documents open simultaneously?

4. **App Store?** Target Mac App Store distribution (stricter sandbox) or direct download?

---

## References

- [png-stage-creator-learnings.md](png-stage-creator-learnings.md) — Prior SFF/DEF implementation
- [macos-native-guidelines.md](macos-native-guidelines.md) — Platform development guidelines
- [IKEMEN GO Documentation](https://github.com/ikemen-engine/Ikemen-GO/wiki)
- [MUGEN Docs Archive](https://mugen.fandom.com/wiki/Stage)
