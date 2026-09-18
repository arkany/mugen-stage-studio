//! Format-independent core for MUGEN / IKEMEN GO stage creation.
//!
//! Split out of the Tauri crate so the arithmetic that actually decides
//! whether a stage works can be unit-tested without a windowing toolkit, and
//! so the web validator in `VALIDATOR-CONCEPT.md` can share it.
//!
//! Start with [`geometry`] — it documents the screen-space coordinate model
//! everything else depends on.

pub mod def;
pub mod geometry;
pub mod sff;
pub mod stage;
pub mod templates;

pub use geometry::{
    canonical_axis, canonical_start, derive_bounds, derive_bounds_for_placement, derive_zoffset,
    floor_y_for_zoffset, minimum_image_size, Axis, CameraBounds, Localcoord, Placement, Start,
};
pub use def::write_def;
pub use sff::{write_sff, SpriteEntry};
pub use stage::{assess_fit, derive, DerivedStage, ImportFit, StageConfig, Warning, WarningCode};
pub use templates::{by_id, StageTemplate, TemplateConfidence, ALL_TEMPLATES};
