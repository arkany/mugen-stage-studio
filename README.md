# MUGEN Stage Studio

A native macOS application for creating and exporting custom stages for **M.U.G.E.N**, **IKEMEN GO**, and other compatible fighting game engines.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

**Keywords:** MUGEN, M.U.G.E.N, IKEMEN GO, Ikemen, stage creator, stage maker, SFF editor, DEF generator, hi-res stages, 720p, custom stages, fighting game, screenpack compatible

## Overview

MUGEN Stage Studio simplifies the process of creating custom fighting game stages by providing a visual editor and handling the complex SFF/DEF file format generation automatically. No more manual hex editing or command-line tools — just import your background images, arrange layers, and export ready-to-use stage packages compatible with MUGEN 1.0, MUGEN 1.1, and IKEMEN GO.

Perfect for creators making custom content, full games, or expanding their roster's stage selection.

## Features

- **Visual Stage Editor** - Drag and drop background images onto a canvas
- **Layer Management** - Support for multiple background layers with z-ordering (BG elements)
- **Live Preview** - See your stage with proper localcoord scaling as it will appear in-game
- **One-Click Export** - Generates complete stage packages (SFF + DEF files) ready for your stages folder
- **IKEMEN GO & MUGEN 1.1 Compatible** - Exports in SFF v2.01 format with PNG compression (no palette limitations!)
- **Automatic Thumbnails** - Generates 240×100 stage select screen thumbnails (sprite 9000,1)
- **Hi-Res Support** - Native 1280×720 (720p) output for modern screenpacks

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building from source)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/mugen-stage-studio.git
   cd mugen-stage-studio
   ```

2. Open the project in Xcode:
   ```bash
   open "MUGEN Stage Studio.xcodeproj"
   ```

3. Build and run (⌘R)

## Usage

### Creating a Stage

1. **Launch the app** and create a new document (⌘N)
2. **Import a background image** - Drag an image onto the canvas or use File → Import (supports PNG, JPG, BMP)
3. **Adjust positioning** - Use the inspector panel to fine-tune layer properties and delta values
4. **Export** - File → Export Stage (⌘E) to generate a ready-to-use stage package

### Export Format

The exported ZIP contains a complete stage folder:
- `stagename.sff` - Sprite file containing BG elements and stage select thumbnail
- `stagename.def` - Stage definition file with camera settings, bounds, zoffset, player start positions, shadow settings, and BGdef

### Installing in IKEMEN GO / MUGEN

1. Extract the exported ZIP
2. Copy the stage folder to your `stages/` directory
3. Add the stage to your `select.def` file under ExtraStages:
   ```ini
   [ExtraStages]
   stages/yourstagename/yourstagename.def
   ```
4. The stage will appear in your stage select screen with its thumbnail!

For MUGEN 1.0/1.1, follow the same process with your MUGEN installation's stages folder.

## Technical Details

### Current Limitations

- **Fixed Resolution**: Exports at 1280×720 localcoord (training room style, non-scrolling)
- **Single BG Layer**: Currently exports only the primary background element (spriteno = 0,0)
- **No Animation**: Static backgrounds only (no animated BG elements or [Begin Action] support yet)
- **No Parallax**: Single-layer stages without delta-based scrolling

### File Formats

- **SFF v2.01**: ElecbyteSpr format with PNG-compressed sprites (no 256-color palette restrictions)
- **DEF**: INI-style stage definition files compatible with MUGEN 1.0, 1.1, and IKEMEN GO

### Stage Parameters (Default Values)

| Parameter | Value | Description |
|-----------|-------|-------------|
| localcoord | 1280×720 | Stage coordinate space (hi-res) |
| zoffset | 660 | Ground level (floor line) |
| boundleft/right | -500 / +500 | Camera horizontal bounds |
| boundhigh/low | -25 / 0 | Camera vertical bounds |
| p1startx/p2startx | -200 / +200 | Player starting positions |
| autoturn | 1 | Players face each other |
| floortension | 160 | Camera vertical follow threshold |

## Roadmap

- [ ] Support for scrolling/panning stages (wider backgrounds with proper boundleft/boundright)
- [ ] Multiple BG layers with parallax (delta values for depth effect)
- [ ] Foreground layer support (layerno = 1)
- [ ] Animated BG elements ([Begin Action] support)
- [ ] Custom stage parameters editor (bounds, player positions, zoffset)
- [ ] Floor/reflection layer support
- [ ] BGM music configuration
- [ ] Lo-res 320×240 export option for WinMUGEN compatibility
- [ ] Import existing SFF/DEF for editing

## Contributing

Contributions are welcome! Whether you're a MUGEN veteran or new to the community, feel free to submit issues, pull requests, or suggestions.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Elecbyte](http://www.elecbyte.com/) - Creators of M.U.G.E.N, the legendary fighting game engine
- [IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO) - The open source successor keeping the community alive
- The amazing MUGEN community - Decades of creators, chars, stages, screenpacks, and full games
- [The Mugen Fighters Guild](https://mugenfreeforall.com/) - Community resources and documentation
- [Mugen Free For All](https://mugenfreeforall.com/) - Hosting and sharing custom content

## Related Resources

- [IKEMEN GO Wiki](https://github.com/ikemen-engine/Ikemen-GO/wiki) - Official documentation
- [Elecbyte MUGEN Docs](http://www.elecbyte.com/mugendocs/) - Original format specifications
- [SFF v2 Format Spec](http://www.dvdvilla.com/mugen/) - Technical SFF documentation

---

*Not affiliated with Elecbyte. M.U.G.E.N is a trademark of Elecbyte.*
