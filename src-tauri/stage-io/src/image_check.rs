// Reading real dimensions off an imported backdrop.
//
// This used to be a stub that always answered `NoImage`, which meant the
// import screen could never report a usable image and the Continue button was
// permanently disabled. It now does a header-only read — cheap enough to run
// on every file pick, and enough for every derivation in `stage_core`, which
// only ever needs width and height. Full decoding waits for the exporter.

use stage_core::geometry::Localcoord;
use stage_core::stage::{assess_fit, ImportFit};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ImageDimensions {
    pub width: u32,
    pub height: u32,
}

/// Read an image's dimensions without decoding its pixels.
pub fn read_dimensions(image_path: &str) -> Result<ImageDimensions, String> {
    image::image_dimensions(image_path)
        .map(|(width, height)| ImageDimensions { width, height })
        .map_err(|e| format!("Could not read {image_path}: {e}"))
}

/// Dimensions plus the fit verdict, in one call.
pub fn inspect(
    image_path: &str,
    localcoord: Localcoord,
    zoomout: f64,
) -> Result<(ImageDimensions, ImportFit), String> {
    let dims = read_dimensions(image_path)?;
    let fit = assess_fit(dims.width, dims.height, localcoord, zoomout);
    Ok((dims, fit))
}
