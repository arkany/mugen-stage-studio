//! SFF v2.01 writing.
//!
//! Ported from `SFFWriter.swift` in IKEMEN Lab, which is the implementation
//! whose output is known to import into IKEMEN GO. The byte layout here is
//! deliberately identical to it; the one thing that changes is what goes in
//! the axis fields.
//!
//! Lab writes `(0, 0)` for every sprite and compensates in the DEF's
//! `[BG ] start`. That is a valid convention — see [`crate::geometry`] — but
//! Stage Studio writes the center-bottom axis and the `start` that pairs with
//! it, so the axis fields are filled from [`crate::stage::DerivedStage`]
//! rather than hardcoded.
//!
//! This module is pure byte assembly: it takes sprites whose pixels are
//! already PNG-encoded and returns the file contents. Image decoding,
//! resizing and PNG encoding live in the desktop crate, which keeps
//! `stage-core` free of an image dependency.
//!
//! # Layout
//!
//! ```text
//!  0..12   "ElecbyteSpr\0"
//! 12..16   version: verlo3, verlo2, verlo1, verhi = 0, 1, 0, 2  (v2.01)
//! 16..36   reserved (five u32 of zero)
//! 36..40   sprite list offset          40..44   sprite count
//! 44..48   palette list offset         48..52   palette count
//! 52..56   ldata offset                56..60   ldata length
//! 60..64   tdata offset                64..68   tdata length (0)
//! ```
//!
//! Then `sprite_count` × 28-byte sprite nodes, one 16-byte palette node, and
//! the ldata block: four bytes of dummy palette, then for each sprite a u32
//! uncompressed-size field followed by the raw PNG.

use serde::{Deserialize, Serialize};

/// Bytes in the SFF v2 header, up to the start of the sprite list.
const HEADER_SIZE: u32 = 68;
const SPRITE_NODE_SIZE: u32 = 28;
const PALETTE_NODE_SIZE: u32 = 16;
/// One dummy palette entry (RGBA of colour 0), which PNG sprites never read
/// but the format still expects to exist.
const PALETTE_DATA_SIZE: u32 = 4;

/// Sprite format byte: PNG with a full alpha channel.
const FMT_PNG32: u8 = 12;
const COLOR_DEPTH_32: u8 = 32;
/// Linked-index sentinel meaning "this sprite carries its own data".
const NOT_LINKED: u16 = 0xFFFF;

/// The sprite group/image the engine reads as a stage's backdrop.
pub const BACKDROP_GROUP: u16 = 0;
pub const BACKDROP_IMAGE: u16 = 0;
/// The group/image IKEMEN GO reads as the stage-select preview
/// (`stage.portrait.spr = 9000,1`).
pub const THUMBNAIL_GROUP: u16 = 9000;
pub const THUMBNAIL_IMAGE: u16 = 1;
/// Thumbnail size, matching Elecbyte's own `stage0-720`.
pub const THUMBNAIL_WIDTH: u32 = 240;
pub const THUMBNAIL_HEIGHT: u32 = 100;

/// One sprite, with its pixels already encoded as a PNG.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SpriteEntry {
    pub group: u16,
    pub image: u16,
    pub axis_x: i16,
    pub axis_y: i16,
    pub width: u16,
    pub height: u16,
    pub png: Vec<u8>,
}

impl SpriteEntry {
    pub fn new(group: u16, image: u16, axis: (i32, i32), size: (u32, u32), png: Vec<u8>) -> Self {
        Self {
            group,
            image,
            // An axis is a position inside the sprite, so for any sprite small
            // enough to exist it fits an i16; saturate rather than wrap, since
            // a wrapped axis would silently misplace the artwork.
            axis_x: axis.0.clamp(i16::MIN as i32, i16::MAX as i32) as i16,
            axis_y: axis.1.clamp(i16::MIN as i32, i16::MAX as i32) as i16,
            width: size.0.min(u16::MAX as u32) as u16,
            height: size.1.min(u16::MAX as u32) as u16,
            png,
        }
    }
}

/// Assemble an SFF v2.01 file.
///
/// Sprites are written in the order given. The caller is expected to put the
/// thumbnail first, matching what Lab produces.
pub fn write_sff(sprites: &[SpriteEntry]) -> Vec<u8> {
    let sprite_count = sprites.len() as u32;
    let palette_count: u32 = 1;

    let sprite_list_offset = HEADER_SIZE;
    let palette_list_offset = sprite_list_offset + sprite_count * SPRITE_NODE_SIZE;
    let ldata_offset = palette_list_offset + palette_count * PALETTE_NODE_SIZE;

    // Each sprite contributes its PNG plus the four-byte size field ahead of it.
    let ldata_len: u32 = PALETTE_DATA_SIZE
        + sprites
            .iter()
            .map(|s| s.png.len() as u32 + 4)
            .sum::<u32>();

    let mut out = Vec::with_capacity((ldata_offset + ldata_len) as usize);

    out.extend_from_slice(b"ElecbyteSpr\0");
    out.extend_from_slice(&[0, 1, 0, 2]); // v2.01
    out.extend_from_slice(&[0u8; 20]); // reserved through byte 36

    out.extend_from_slice(&sprite_list_offset.to_le_bytes());
    out.extend_from_slice(&sprite_count.to_le_bytes());
    out.extend_from_slice(&palette_list_offset.to_le_bytes());
    out.extend_from_slice(&palette_count.to_le_bytes());
    out.extend_from_slice(&ldata_offset.to_le_bytes());
    out.extend_from_slice(&ldata_len.to_le_bytes());
    out.extend_from_slice(&(ldata_offset + ldata_len).to_le_bytes()); // tdata offset
    out.extend_from_slice(&0u32.to_le_bytes()); // tdata length: unused

    debug_assert_eq!(out.len(), HEADER_SIZE as usize);

    // Sprite nodes. Data offsets are relative to the start of ldata, and the
    // dummy palette sits at the front of it.
    let mut data_offset = PALETTE_DATA_SIZE;
    for s in sprites {
        let data_len = s.png.len() as u32 + 4;
        out.extend_from_slice(&s.group.to_le_bytes());
        out.extend_from_slice(&s.image.to_le_bytes());
        out.extend_from_slice(&s.width.to_le_bytes());
        out.extend_from_slice(&s.height.to_le_bytes());
        out.extend_from_slice(&s.axis_x.to_le_bytes());
        out.extend_from_slice(&s.axis_y.to_le_bytes());
        out.extend_from_slice(&NOT_LINKED.to_le_bytes());
        out.push(FMT_PNG32);
        out.push(COLOR_DEPTH_32);
        out.extend_from_slice(&data_offset.to_le_bytes());
        out.extend_from_slice(&data_len.to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // palette index
        out.extend_from_slice(&0u16.to_le_bytes()); // flags: data lives in ldata
        data_offset += data_len;
    }

    // One dummy palette node.
    out.extend_from_slice(&0u16.to_le_bytes()); // group
    out.extend_from_slice(&0u16.to_le_bytes()); // item
    out.extend_from_slice(&1u16.to_le_bytes()); // colour count
    out.extend_from_slice(&0u16.to_le_bytes()); // linked index
    out.extend_from_slice(&0u32.to_le_bytes()); // data offset
    out.extend_from_slice(&PALETTE_DATA_SIZE.to_le_bytes());

    debug_assert_eq!(out.len(), ldata_offset as usize);

    // ldata: the dummy palette, then each PNG behind its size field.
    out.extend_from_slice(&[0u8; PALETTE_DATA_SIZE as usize]);
    for s in sprites {
        let uncompressed = s.width as u32 * s.height as u32 * 4;
        out.extend_from_slice(&uncompressed.to_le_bytes());
        out.extend_from_slice(&s.png);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Minimal reader mirroring `tools/parse_stage.py`, so the tests check the
    /// bytes the way the validator will actually read them.
    struct ReadSprite {
        group: u16,
        image: u16,
        width: u16,
        height: u16,
        axis_x: i16,
        axis_y: i16,
        fmt: u8,
        data_offset: u32,
        data_len: u32,
    }

    fn u16at(d: &[u8], o: usize) -> u16 {
        u16::from_le_bytes([d[o], d[o + 1]])
    }
    fn i16at(d: &[u8], o: usize) -> i16 {
        i16::from_le_bytes([d[o], d[o + 1]])
    }
    fn u32at(d: &[u8], o: usize) -> u32 {
        u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
    }

    fn read_back(d: &[u8]) -> (Vec<ReadSprite>, u32) {
        assert_eq!(&d[0..12], b"ElecbyteSpr\0", "signature");
        assert_eq!(&d[12..16], &[0, 1, 0, 2], "version v2.01");

        let list_off = u32at(d, 36);
        let count = u32at(d, 40);
        let ldata_off = u32at(d, 52);

        let mut out = Vec::new();
        for i in 0..count {
            let o = (list_off + i * SPRITE_NODE_SIZE) as usize;
            out.push(ReadSprite {
                group: u16at(d, o),
                image: u16at(d, o + 2),
                width: u16at(d, o + 4),
                height: u16at(d, o + 6),
                axis_x: i16at(d, o + 8),
                axis_y: i16at(d, o + 10),
                fmt: d[o + 14],
                data_offset: u32at(d, o + 16),
                data_len: u32at(d, o + 20),
            });
        }
        (out, ldata_off)
    }

    fn fake_png(tag: u8) -> Vec<u8> {
        // Not a real PNG - the writer never inspects the bytes, and using a
        // recognisable pattern makes it obvious if they land at a wrong offset.
        let mut v = b"\x89PNG\r\n\x1a\n".to_vec();
        v.extend_from_slice(&[tag; 40]);
        v
    }

    fn sample() -> Vec<SpriteEntry> {
        vec![
            SpriteEntry::new(
                THUMBNAIL_GROUP,
                THUMBNAIL_IMAGE,
                (0, 0),
                (THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT),
                fake_png(0xAA),
            ),
            SpriteEntry::new(
                BACKDROP_GROUP,
                BACKDROP_IMAGE,
                (768, 1024),
                (1536, 1024),
                fake_png(0xBB),
            ),
        ]
    }

    #[test]
    fn header_and_nodes_round_trip() {
        let sprites = sample();
        let bytes = write_sff(&sprites);
        let (read, _) = read_back(&bytes);

        assert_eq!(read.len(), 2);
        assert_eq!(read[0].group, 9000);
        assert_eq!(read[0].image, 1);
        assert_eq!((read[0].width, read[0].height), (240, 100));

        assert_eq!(read[1].group, 0);
        assert_eq!(read[1].image, 0);
        assert_eq!((read[1].width, read[1].height), (1536, 1024));
        assert_eq!(read[1].fmt, FMT_PNG32);
    }

    /// The whole point of the port: the backdrop's axis must survive into the
    /// binary as center-bottom, because that is what the DEF's `start` is
    /// written to pair with.
    #[test]
    fn backdrop_axis_is_preserved_as_center_bottom() {
        let bytes = write_sff(&sample());
        let (read, _) = read_back(&bytes);
        let bg = read.iter().find(|s| s.group == 0).unwrap();

        assert_eq!(bg.axis_x, 768, "axisX must be width / 2");
        assert_eq!(bg.axis_y, 1024, "axisY must be height");
        // This is the condition tools/parse_stage.py calls `axisIsCorrect`.
        assert_eq!(bg.axis_x as u16, bg.width / 2);
        assert_eq!(bg.axis_y as u16, bg.height);
    }

    #[test]
    fn png_payloads_land_at_their_declared_offsets() {
        let sprites = sample();
        let bytes = write_sff(&sprites);
        let (read, ldata_off) = read_back(&bytes);

        for (node, original) in read.iter().zip(sprites.iter()) {
            let start = (ldata_off + node.data_offset) as usize;
            // Four bytes of uncompressed size, then the PNG itself.
            let declared = u32at(&bytes, start);
            assert_eq!(
                declared,
                original.width as u32 * original.height as u32 * 4,
                "uncompressed size field"
            );
            let png = &bytes[start + 4..start + node.data_len as usize];
            assert_eq!(png, original.png.as_slice(), "PNG payload");
        }
    }

    #[test]
    fn declared_lengths_match_the_file() {
        let bytes = write_sff(&sample());
        let ldata_off = u32at(&bytes, 52);
        let ldata_len = u32at(&bytes, 56);
        let tdata_off = u32at(&bytes, 60);

        assert_eq!(
            (ldata_off + ldata_len) as usize,
            bytes.len(),
            "ldata must run to the end of the file"
        );
        assert_eq!(tdata_off as usize, bytes.len(), "tdata is empty");
        assert_eq!(u32at(&bytes, 64), 0, "tdata length");
    }

    #[test]
    fn a_single_sprite_file_is_well_formed() {
        let bytes = write_sff(&[SpriteEntry::new(0, 0, (320, 480), (640, 480), fake_png(1))]);
        let (read, _) = read_back(&bytes);
        assert_eq!(read.len(), 1);
        assert_eq!(read[0].axis_x, 320);
        assert_eq!(read[0].axis_y, 480);
    }

    #[test]
    fn an_oversized_axis_saturates_rather_than_wrapping() {
        // A wrapped axis would put the artwork somewhere absurd instead of
        // merely at the edge, and the failure would be silent.
        let s = SpriteEntry::new(0, 0, (40_000, 40_000), (80_000, 80_000), fake_png(2));
        assert_eq!(s.axis_x, i16::MAX);
        assert_eq!(s.axis_y, i16::MAX);
    }
}
