// Tauri command handlers.
//
// Every command is a thin shell over `stage_core`: read a file's dimensions,
// hand the numbers to the core, return what it derived. No geometry lives
// here, so there is no second place for the camera maths to drift.

use serde::Serialize;

use stage_core::stage::{self, DerivedStage, ImportFit, StageConfig};
use stage_core::templates::{self, StageTemplate};

use crate::export::{self, ExportResult};
use crate::image_check;

#[tauri::command]
pub fn get_templates() -> Vec<StageTemplate> {
    templates::ALL_TEMPLATES.to_vec()
}

/// What the import screen needs after a file pick: the config with real
/// dimensions filled in, the fit verdict, and — when the image is usable —
/// the fully derived parameter set to preview.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportResult {
    pub config: StageConfig,
    pub fit: ImportFit,
    pub derived: Option<DerivedStage>,
}

/// Load a backdrop and derive everything that follows from it.
///
/// Unlike the previous version this reads the file for real, so the returned
/// `fit` reflects the actual image rather than a hardcoded `NoImage`.
#[tauri::command]
pub fn load_image(image_path: String, template_id: String) -> Result<ImportResult, String> {
    let template = templates::by_id(&template_id)
        .ok_or_else(|| format!("Unknown template: {template_id}"))?;

    let mut config = StageConfig::empty_for_template(&template_id);
    config.bg_image_path = Some(image_path.clone());

    let zoomout = config.zoomout(template);
    let (dims, fit) = image_check::inspect(&image_path, template.localcoord(), zoomout)?;

    config.bg_image_width = Some(dims.width);
    config.bg_image_height = Some(dims.height);

    // Seed the floor-line handle from the template so the preview has
    // something sensible before the user drags it.
    config.floor_y = Some(
        (dims.height as f64 * template.default_floor_ratio as f64).round() as u32,
    );

    let derived = stage::derive(&config, template);
    Ok(ImportResult {
        config,
        fit,
        derived,
    })
}

/// Re-derive after the user moves the floor line or changes the zoom.
///
/// The frontend never computes a camera value itself; it edits the config and
/// asks for a fresh derivation.
#[tauri::command]
pub fn derive_stage(config: StageConfig) -> Result<Option<DerivedStage>, String> {
    let template = templates::by_id(&config.template_id)
        .ok_or_else(|| format!("Unknown template: {}", config.template_id))?;
    Ok(stage::derive(&config, template))
}

/// Serialize the derived stage to a DEF file body.
///
/// This is the half of export that depends on the geometry being right, so it
/// ships now; SFF binary generation follows. Emitting the DEF alone is already
/// useful — it can be dropped next to a hand-built SFF.
#[tauri::command]
pub fn preview_def(config: StageConfig) -> Result<String, String> {
    let template = templates::by_id(&config.template_id)
        .ok_or_else(|| format!("Unknown template: {}", config.template_id))?;
    let derived = stage::derive(&config, template)
        .ok_or_else(|| "Load a usable background image first".to_string())?;
    Ok(stage_core::def::write_def(&config, template, &derived))
}

/// A sensible place to put the exported stage when the user hasn't chosen one.
#[tauri::command]
pub fn default_output_dir() -> String {
    let base = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_else(|_| ".".to_string());
    std::path::Path::new(&base)
        .join("MugenStageStudio")
        .display()
        .to_string()
}

/// Write the stage's `.def` and `.sff` into `output_dir`.
///
/// The sprite axis written into the SFF is `derived.axis`, and the `[BG ]
/// start` written into the DEF is `derived.start`. They come from one
/// derivation and are written in one call, which is the point — they are only
/// meaningful as a pair.
#[tauri::command]
pub fn export_stage(config: StageConfig, output_dir: String) -> Result<ExportResult, String> {
    let template = templates::by_id(&config.template_id)
        .ok_or_else(|| format!("Unknown template: {}", config.template_id))?;
    let derived = stage::derive(&config, template)
        .ok_or_else(|| "Load a usable background image first".to_string())?;

    export::export_stage(
        &config,
        template,
        &derived,
        std::path::Path::new(&output_dir),
    )
}
