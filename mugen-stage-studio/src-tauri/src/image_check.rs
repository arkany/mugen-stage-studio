// Image conformance — STUB ONLY.
//
// Phase 4b will implement real image dimension reading (via the `image`
// crate) and the crop / extend / too-small classification against the
// selected StageTemplate. This file exists so commands.rs can compile and
// the IPC boundary is wired end-to-end.

use crate::stage_config::ConformanceState;
use crate::templates::StageTemplate;

#[derive(Debug, Clone, Copy)]
#[allow(dead_code)] // Phase 4b will populate this from real image reads.
pub struct ImageDimensions {
    pub width: u32,
    pub height: u32,
}

/// STUB: returns `ConformanceState::NoImage` regardless of input.
///
/// Phase 4b will:
///   1. Read the image at `image_path` using the `image` crate.
///   2. Compare dimensions to `template.bg_width` × `template.bg_height`.
///   3. Return `Correct` if exact match.
///   4. Return `FixableWithCrop { ... }` if source is larger and matching
///      aspect — trim equal pixels from both edges.
///   5. Return `FixableWithExtend { ... }` if source is within ~10% smaller
///      and matching aspect — pad with solid color / blurred border.
///   6. Return `TooSmall` if outside both fix windows — caller must ask the
///      user to choose a different image.
///
/// See `mugen-stage-skill.md` Section 7 for the per-template conformance
/// windows the real implementation must enforce.
pub fn check_image_conformance(
    _image_path: &str,
    _template: &StageTemplate,
) -> ConformanceState {
    ConformanceState::NoImage
}
