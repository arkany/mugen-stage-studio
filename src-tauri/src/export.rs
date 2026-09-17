// Turning a derived stage into files on disk.
//
// `stage-core` decides every number; this module only moves pixels around and
// writes bytes. It is the half that needs an image codec, which is why it
// lives here rather than in the core crate.

use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

use image::imageops::FilterType;
use image::{DynamicImage, ImageFormat};

use stage_core::sff::{
    self, SpriteEntry, BACKDROP_GROUP, BACKDROP_IMAGE, THUMBNAIL_GROUP, THUMBNAIL_HEIGHT,
    THUMBNAIL_IMAGE, THUMBNAIL_WIDTH,
};
use stage_core::stage::{DerivedStage, StageConfig};
use stage_core::templates::StageTemplate;

/// What `export_stage` produced.
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportResult {
    pub directory: String,
    pub def_path: String,
    pub sff_path: String,
    pub backdrop_width: u32,
    pub backdrop_height: u32,
    pub resampled: bool,
}

/// Filesystem-safe stem for the stage's files.
pub fn file_stem(name: &str) -> String {
    let cleaned: String = name
        .trim()
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if cleaned.is_empty() {
        "stage".to_string()
    } else {
        cleaned
    }
}

/// Crop to the thumbnail's aspect ratio, biased toward the upper part of the
/// artwork where the interesting scenery usually is, then scale to 240x100.
///
/// Mirrors what IKEMEN Lab does, including the 10% downward nudge: cropping
/// dead centre on a tall backdrop tends to land on empty sky.
fn build_thumbnail(source: &DynamicImage) -> DynamicImage {
    let (w, h) = (source.width(), source.height());
    let target_aspect = THUMBNAIL_WIDTH as f64 / THUMBNAIL_HEIGHT as f64;
    let source_aspect = w as f64 / h as f64;

    let cropped = if source_aspect > target_aspect {
        // Wider than the thumbnail: take a full-height slice from the centre.
        let crop_w = (h as f64 * target_aspect).round().min(w as f64) as u32;
        let x = (w.saturating_sub(crop_w)) / 2;
        source.crop_imm(x, 0, crop_w.max(1), h)
    } else {
        // Taller than the thumbnail: take a band above centre.
        let crop_h = (w as f64 / target_aspect).round().min(h as f64) as u32;
        let slack = h.saturating_sub(crop_h);
        let y = (slack as f64 * 0.4).round() as u32;
        source.crop_imm(0, y.min(slack), w, crop_h.max(1))
    };

    cropped.resize_exact(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, FilterType::Lanczos3)
}

/// Encode as RGBA PNG.
///
/// The sprite nodes declare format 12 (PNG32, 32-bit colour depth), so the
/// payload has to actually carry an alpha channel — a JPEG or a palette PNG
/// would otherwise be described as something it is not. Converting here means
/// the declared format is always truthful, whatever the user imported.
fn encode_png(img: &DynamicImage) -> Result<Vec<u8>, String> {
    let rgba = DynamicImage::ImageRgba8(img.to_rgba8());
    let mut buf = Vec::new();
    rgba.write_to(&mut Cursor::new(&mut buf), ImageFormat::Png)
        .map_err(|e| format!("Could not encode PNG: {e}"))?;
    Ok(buf)
}

/// Write the stage's `.def` and `.sff` into `output_dir`.
///
/// The backdrop is resampled only when `derived` says it had to be enlarged to
/// cover the viewport; otherwise the user's pixels are written through
/// untouched. Scaling is always uniform — a stretched backdrop is never
/// correct, so there is no code path that can produce one.
pub fn export_stage(
    config: &StageConfig,
    template: &StageTemplate,
    derived: &DerivedStage,
    output_dir: &Path,
) -> Result<ExportResult, String> {
    let image_path = config
        .bg_image_path
        .as_deref()
        .ok_or("No background image loaded")?;

    let source = image::open(image_path).map_err(|e| format!("Could not read {image_path}: {e}"))?;

    // `derived.bg_width/height` are the dimensions every camera value was
    // computed against, so the file written must match them exactly.
    let resampled = source.width() != derived.bg_width || source.height() != derived.bg_height;
    let backdrop = if resampled {
        source.resize_exact(derived.bg_width, derived.bg_height, FilterType::Lanczos3)
    } else {
        source.clone()
    };

    let thumbnail = build_thumbnail(&source);

    // Thumbnail first, matching the ordering IKEMEN GO is known to accept.
    let sprites = vec![
        SpriteEntry::new(
            THUMBNAIL_GROUP,
            THUMBNAIL_IMAGE,
            (0, 0),
            (THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT),
            encode_png(&thumbnail)?,
        ),
        SpriteEntry::new(
            BACKDROP_GROUP,
            BACKDROP_IMAGE,
            (derived.axis.x, derived.axis.y),
            (derived.bg_width, derived.bg_height),
            encode_png(&backdrop)?,
        ),
    ];

    fs::create_dir_all(output_dir)
        .map_err(|e| format!("Could not create {}: {e}", output_dir.display()))?;

    let stem = file_stem(&config.name);
    let def_path: PathBuf = output_dir.join(format!("{stem}.def"));
    let sff_path: PathBuf = output_dir.join(format!("{stem}.sff"));

    fs::write(&sff_path, sff::write_sff(&sprites))
        .map_err(|e| format!("Could not write {}: {e}", sff_path.display()))?;
    fs::write(&def_path, stage_core::def::write_def(config, template, derived))
        .map_err(|e| format!("Could not write {}: {e}", def_path.display()))?;

    Ok(ExportResult {
        directory: output_dir.display().to_string(),
        def_path: def_path.display().to_string(),
        sff_path: sff_path.display().to_string(),
        backdrop_width: derived.bg_width,
        backdrop_height: derived.bg_height,
        resampled,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_stem_is_safe_and_never_empty() {
        assert_eq!(file_stem("Neon Rooftop"), "Neon_Rooftop");
        assert_eq!(file_stem("  "), "stage");
        // Path separators and dots are flattened, so a name can never escape
        // the chosen output directory.
        assert_eq!(file_stem("../../etc/passwd"), "______etc_passwd");
        assert_eq!(file_stem("ok-name_1"), "ok-name_1");
    }

    #[test]
    fn thumbnail_is_always_the_expected_size() {
        for (w, h) in [(1536u32, 1024u32), (3200, 1072), (640, 480), (1080, 1920)] {
            let src = DynamicImage::new_rgba8(w, h);
            let t = build_thumbnail(&src);
            assert_eq!(
                (t.width(), t.height()),
                (THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT),
                "for a {w}x{h} source"
            );
        }
    }

    // --- Full export, read back the way the engine would ---

    fn u16at(d: &[u8], o: usize) -> u16 {
        u16::from_le_bytes([d[o], d[o + 1]])
    }
    fn i16at(d: &[u8], o: usize) -> i16 {
        i16::from_le_bytes([d[o], d[o + 1]])
    }
    fn u32at(d: &[u8], o: usize) -> u32 {
        u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
    }

    /// Writes a real PNG, exports a real stage, then re-reads the SFF and
    /// decodes the sprites out of it. This is the end-to-end check that the
    /// axis written into the binary is the one the geometry derived, and that
    /// the payload is a PNG the engine can actually open.
    #[test]
    fn exported_sff_round_trips_through_a_reader() {
        let dir = std::env::temp_dir().join(format!(
            "mss-export-test-{}-{:?}",
            std::process::id(),
            std::thread::current().id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();

        // A backdrop at a size an image model would actually emit.
        let src_path = dir.join("bg.png");
        DynamicImage::new_rgb8(1536, 1024).save(&src_path).unwrap();

        let template = stage_core::templates::by_id("T3").unwrap();
        let mut config = StageConfig::empty_for_template("T3");
        config.name = "Round Trip".into();
        config.bg_image_path = Some(src_path.display().to_string());
        config.bg_image_width = Some(1536);
        config.bg_image_height = Some(1024);
        config.floor_y = Some(880);

        let derived = stage_core::stage::derive(&config, template).unwrap();
        let out = dir.join("out");
        let result = export_stage(&config, template, &derived, &out).unwrap();

        assert!(!result.resampled, "1536x1024 already covers a 1280x720 viewport");
        assert!(Path::new(&result.def_path).exists());
        assert!(Path::new(&result.sff_path).exists());

        let sff = fs::read(&result.sff_path).unwrap();
        assert_eq!(&sff[0..12], b"ElecbyteSpr\0");

        let list_off = u32at(&sff, 36);
        let count = u32at(&sff, 40);
        let ldata_off = u32at(&sff, 52);
        assert_eq!(count, 2, "backdrop plus thumbnail");

        let mut saw_backdrop = false;
        let mut saw_thumbnail = false;
        for i in 0..count {
            let o = (list_off + i * 28) as usize;
            let (group, image) = (u16at(&sff, o), u16at(&sff, o + 2));
            let (w, h) = (u16at(&sff, o + 4), u16at(&sff, o + 6));
            let (ax, ay) = (i16at(&sff, o + 8), i16at(&sff, o + 10));
            let fmt = sff[o + 14];
            let start = (ldata_off + u32at(&sff, o + 16)) as usize;
            let len = u32at(&sff, o + 20) as usize;

            // The declared format is PNG32, so the payload must carry alpha.
            assert_eq!(fmt, 12, "sprite {group},{image} format");
            let decoded = image::load_from_memory(&sff[start + 4..start + len])
                .unwrap_or_else(|e| panic!("sprite {group},{image} is not a readable PNG: {e}"));
            assert_eq!(
                (decoded.width(), decoded.height()),
                (w as u32, h as u32),
                "sprite {group},{image} node size vs payload"
            );
            assert!(
                decoded.color().has_alpha(),
                "sprite {group},{image} declares PNG32 but has no alpha channel"
            );

            if group == 0 && image == 0 {
                saw_backdrop = true;
                assert_eq!((w, h), (1536, 1024));
                assert_eq!(ax, derived.axis.x as i16, "axisX must be what was derived");
                assert_eq!(ay, derived.axis.y as i16, "axisY must be what was derived");
                assert_eq!(ax as u16, w / 2, "center-bottom: axisX");
                assert_eq!(ay as u16, h, "center-bottom: axisY");
            } else if group == 9000 && image == 1 {
                saw_thumbnail = true;
                assert_eq!((w as u32, h as u32), (THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT));
            }
        }
        assert!(saw_backdrop && saw_thumbnail);

        // The DEF's start must pair with the axis the SFF carries.
        let def = fs::read_to_string(&result.def_path).unwrap();
        assert!(
            def.contains(&format!("start = {}, {}", derived.start.x, derived.start.y)),
            "DEF start must match the derivation:\n{def}"
        );
        assert!(def.contains("start = 0, 720"), "flush-bottom mount");

        let _ = fs::remove_dir_all(&dir);
    }

    /// A backdrop smaller than the viewport is enlarged on the way out, and the
    /// file written must match the dimensions the camera values assumed.
    #[test]
    fn an_upscaled_backdrop_is_written_at_its_derived_size() {
        let dir = std::env::temp_dir().join(format!("mss-upscale-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();

        let src_path = dir.join("small.png");
        DynamicImage::new_rgb8(1024, 576).save(&src_path).unwrap();

        let template = stage_core::templates::by_id("T3").unwrap();
        let mut config = StageConfig::empty_for_template("T3");
        config.name = "Upscaled".into();
        config.bg_image_path = Some(src_path.display().to_string());
        config.bg_image_width = Some(1024);
        config.bg_image_height = Some(576);

        let derived = stage_core::stage::derive(&config, template).unwrap();
        let result = export_stage(&config, template, &derived, &dir.join("out")).unwrap();

        assert!(result.resampled);
        assert_eq!(result.backdrop_width, derived.bg_width);
        assert_eq!(result.backdrop_height, derived.bg_height);
        assert!(result.backdrop_width >= 1280 && result.backdrop_height >= 720);

        let sff = fs::read(&result.sff_path).unwrap();
        let list_off = u32at(&sff, 36);
        let count = u32at(&sff, 40);
        let bg = (0..count)
            .map(|i| (list_off + i * 28) as usize)
            .find(|&o| u16at(&sff, o) == 0)
            .unwrap();
        assert_eq!(u16at(&sff, bg + 4) as u32, derived.bg_width);
        assert_eq!(u16at(&sff, bg + 6) as u32, derived.bg_height);

        let _ = fs::remove_dir_all(&dir);
    }
}
