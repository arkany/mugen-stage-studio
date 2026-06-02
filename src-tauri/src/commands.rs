// Tauri command handlers.
//
// All three commands compile and return sensible stub responses so the
// frontend can be wired up before Phase 4b lands real implementations.

use crate::image_check;
use crate::stage_config::StageConfig;
use crate::templates::{self, StageTemplate};

#[tauri::command]
pub fn get_templates() -> Vec<StageTemplate> {
    templates::ALL_TEMPLATES.to_vec()
}

/// STUB: returns a `StageConfig` whose `conformance_state` is always
/// `NoImage` until Phase 4b implements `image_check::check_image_conformance`
/// with real dimension reading.
///
/// The stub does record the inputs (path + template_id) on the returned
/// config so the frontend can confirm round-trip serialization works.
#[tauri::command]
pub fn load_image(image_path: String, template_id: String) -> StageConfig {
    let mut config = StageConfig::empty_for_template(&template_id);
    config.bg_image_path = Some(image_path.clone());

    // When Phase 4b lands, this stub call will be replaced with real
    // image dimension reading + conformance classification.
    if let Some(template) = templates::by_id(&template_id) {
        config.conformance_state = image_check::check_image_conformance(&image_path, template);
    }

    config
}

/// STUB: always returns an error message until Phase 4b implements SFF
/// binary generation, DEF serialization, and zip packaging.
#[tauri::command]
pub fn export_stage(_config: StageConfig) -> Result<String, String> {
    Err("Export not yet implemented — Phase 4b".to_string())
}
