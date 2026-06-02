// Typed representation of a stage in progress.
//
// Crosses the Tauri command boundary in both directions. Serialization uses
// camelCase so the TypeScript side reads naturally.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StageConfig {
    pub name: String,
    pub author: String,
    pub music: Option<String>,
    pub template_id: String,
    pub bg_image_path: Option<String>,
    pub bg_image_width: Option<u32>,
    pub bg_image_height: Option<u32>,
    pub conformance_state: ConformanceState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "PascalCase")]
pub enum ConformanceState {
    NoImage,
    Correct,
    #[serde(rename_all = "camelCase")]
    FixableWithCrop { crop_x: u32, crop_y: u32 },
    #[serde(rename_all = "camelCase")]
    FixableWithExtend { pad_x: u32, pad_y: u32 },
    TooSmall,
}

impl StageConfig {
    pub fn empty_for_template(template_id: impl Into<String>) -> Self {
        Self {
            name: String::new(),
            author: String::new(),
            music: None,
            template_id: template_id.into(),
            bg_image_path: None,
            bg_image_width: None,
            bg_image_height: None,
            conformance_state: ConformanceState::NoImage,
        }
    }
}
