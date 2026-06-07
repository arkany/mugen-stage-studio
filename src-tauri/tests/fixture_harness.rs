use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[test]
fn t1_fixture_outputs_are_reusable() {
    let fixture = FixtureOutput::t1();

    assert!(fixture.def_path().exists(), "missing {:?}", fixture.def_path());
    assert!(fixture.sff_path().exists(), "missing {:?}", fixture.sff_path());
    assert!(fixture.def_text().contains("[Camera]"));
    assert!(fixture.sff_bytes().starts_with(b"ElecbyteSpr\0"));
}

#[test]
fn t1_def_blocks_match_snapshots() {
    let blocks = DefBlocks::parse(FixtureOutput::t1().def_text());

    assert_eq!(
        blocks.snapshot("Info"),
        r#"[Info]
name = "T1 Fixture"
displayname = "T1 Fixture"
mugenversion = 1.0
author = "MUGEN Stage Studio""#
    );
    assert_eq!(
        blocks.snapshot("Camera"),
        r#"[Camera]
startx = 0
starty = 0
boundleft = -152
boundright = 152
boundhigh = -243
boundlow = 0
tension = 60
verticalfollow = 0.2
floortension = 90"#
    );
    assert_eq!(
        blocks.snapshot("StageInfo"),
        r#"[StageInfo]
zoffset = 217
autoturn = 1
resetBG = 1
localcoord = 320, 240"#
    );
    assert_eq!(
        blocks.snapshot("BGDef"),
        r#"[BGDef]
spr = t1_fixture.sff
debugbg = 0"#
    );
    assert_eq!(
        blocks.snapshot("BG 0"),
        r#"[BG 0]
type = normal
spriteno = 0, 0
start = 0, 0
delta = 1, 1
tile = 0, 0
layerno = 0
mask = 0"#
    );
    assert_eq!(
        blocks.snapshot("Begin Action 9000"),
        r#"[Begin Action 9000]
9000,1, 0,0, -1"#
    );
}

#[test]
fn t1_sff_sprites_are_asserted_structurally() {
    let sff = SffFile::parse(FixtureOutput::t1().sff_bytes()).expect("valid T1 fixture SFF");

    assert_eq!(sff.version, (2, 0, 1, 0));
    assert_eq!(sff.sprites.len(), 2);
    assert_sprite(
        sff.sprite(0, 0).expect("main background sprite"),
        ExpectedSprite {
            group: 0,
            index: 0,
            width: 624,
            height: 483,
            axis_x: 312,
            axis_y: 483,
            format: 12,
            color_depth: 32,
        },
    );
    assert_sprite(
        sff.sprite(9000, 1).expect("stage select thumbnail sprite"),
        ExpectedSprite {
            group: 9000,
            index: 1,
            width: 240,
            height: 100,
            axis_x: 0,
            axis_y: 0,
            format: 12,
            color_depth: 32,
        },
    );
}

struct FixtureOutput {
    root: PathBuf,
}

impl FixtureOutput {
    fn t1() -> Self {
        Self {
            root: Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("tests")
                .join("fixtures")
                .join("t1"),
        }
    }

    fn def_path(&self) -> PathBuf {
        self.root.join("t1.def")
    }

    fn sff_path(&self) -> PathBuf {
        self.root.join("t1.sff")
    }

    fn def_text(&self) -> String {
        std::fs::read_to_string(self.def_path()).expect("read DEF fixture")
    }

    fn sff_bytes(&self) -> Vec<u8> {
        std::fs::read(self.sff_path()).expect("read SFF fixture")
    }
}

struct DefBlocks {
    blocks: BTreeMap<String, String>,
}

impl DefBlocks {
    fn parse(input: String) -> Self {
        let mut blocks = BTreeMap::new();
        let mut current_name: Option<String> = None;
        let mut current_lines: Vec<String> = Vec::new();

        for raw_line in input.lines() {
            let line = raw_line.trim_end();
            if line.trim_start().starts_with(';') || line.trim().is_empty() {
                continue;
            }

            if let Some(name) = line.strip_prefix('[').and_then(|v| v.strip_suffix(']')) {
                if let Some(previous_name) = current_name.replace(name.to_string()) {
                    blocks.insert(previous_name, current_lines.join("\n"));
                    current_lines.clear();
                }
            }

            current_lines.push(line.to_string());
        }

        if let Some(previous_name) = current_name {
            blocks.insert(previous_name, current_lines.join("\n"));
        }

        Self { blocks }
    }

    fn snapshot(&self, name: &str) -> &str {
        self.blocks
            .get(name)
            .unwrap_or_else(|| panic!("missing DEF block [{name}]"))
    }
}

#[derive(Debug)]
struct SffFile {
    version: (u8, u8, u8, u8),
    sprites: Vec<SffSprite>,
}

impl SffFile {
    fn parse(bytes: Vec<u8>) -> Result<Self, String> {
        if bytes.len() < 68 {
            return Err(format!("SFF is too short: {} bytes", bytes.len()));
        }
        if &bytes[0..12] != b"ElecbyteSpr\0" {
            return Err("invalid SFF signature".to_string());
        }

        let sprite_list_offset = read_u32(&bytes, 36)? as usize;
        let sprite_count = read_u32(&bytes, 40)? as usize;
        let sprite_list_len = sprite_count
            .checked_mul(28)
            .ok_or_else(|| "sprite list length overflow".to_string())?;
        if sprite_list_offset + sprite_list_len > bytes.len() {
            return Err("sprite list extends past end of file".to_string());
        }

        let mut sprites = Vec::with_capacity(sprite_count);
        for sprite_index in 0..sprite_count {
            let offset = sprite_list_offset + sprite_index * 28;
            sprites.push(SffSprite {
                group: read_u16(&bytes, offset)?,
                index: read_u16(&bytes, offset + 2)?,
                width: read_u16(&bytes, offset + 4)?,
                height: read_u16(&bytes, offset + 6)?,
                axis_x: read_i16(&bytes, offset + 8)?,
                axis_y: read_i16(&bytes, offset + 10)?,
                linked_index: read_u16(&bytes, offset + 12)?,
                format: bytes[offset + 14],
                color_depth: bytes[offset + 15],
                _data_offset: read_u32(&bytes, offset + 16)?,
                data_length: read_u32(&bytes, offset + 20)?,
                palette_index: read_u16(&bytes, offset + 24)?,
                flags: read_u16(&bytes, offset + 26)?,
            });
        }

        Ok(Self {
            version: (bytes[15], bytes[14], bytes[13], bytes[12]),
            sprites,
        })
    }

    fn sprite(&self, group: u16, index: u16) -> Option<&SffSprite> {
        self.sprites
            .iter()
            .find(|sprite| sprite.group == group && sprite.index == index)
    }
}

#[derive(Debug)]
struct SffSprite {
    group: u16,
    index: u16,
    width: u16,
    height: u16,
    axis_x: i16,
    axis_y: i16,
    linked_index: u16,
    format: u8,
    color_depth: u8,
    _data_offset: u32,
    data_length: u32,
    palette_index: u16,
    flags: u16,
}

#[derive(Clone, Copy)]
struct ExpectedSprite {
    group: u16,
    index: u16,
    width: u16,
    height: u16,
    axis_x: i16,
    axis_y: i16,
    format: u8,
    color_depth: u8,
}

fn assert_sprite(actual: &SffSprite, expected: ExpectedSprite) {
    assert_eq!(actual.group, expected.group);
    assert_eq!(actual.index, expected.index);
    assert_eq!(actual.width, expected.width);
    assert_eq!(actual.height, expected.height);
    assert_eq!(actual.axis_x, expected.axis_x);
    assert_eq!(actual.axis_y, expected.axis_y);
    assert_eq!(actual.linked_index, 0xffff);
    assert_eq!(actual.format, expected.format);
    assert_eq!(actual.color_depth, expected.color_depth);
    assert!(actual.data_length >= 4);
    assert_eq!(actual.palette_index, 0);
    assert_eq!(actual.flags, 0);
}

fn read_u16(bytes: &[u8], offset: usize) -> Result<u16, String> {
    bytes
        .get(offset..offset + 2)
        .map(|value| u16::from_le_bytes(value.try_into().expect("2-byte slice")))
        .ok_or_else(|| format!("expected u16 at offset {offset}"))
}

fn read_i16(bytes: &[u8], offset: usize) -> Result<i16, String> {
    bytes
        .get(offset..offset + 2)
        .map(|value| i16::from_le_bytes(value.try_into().expect("2-byte slice")))
        .ok_or_else(|| format!("expected i16 at offset {offset}"))
}

fn read_u32(bytes: &[u8], offset: usize) -> Result<u32, String> {
    bytes
        .get(offset..offset + 4)
        .map(|value| u32::from_le_bytes(value.try_into().expect("4-byte slice")))
        .ok_or_else(|| format!("expected u32 at offset {offset}"))
}
