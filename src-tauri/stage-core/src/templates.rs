//! Canonical stage templates.
//!
//! # What a template is, and is not
//!
//! A template carries only values that are genuinely properties of a
//! *coordinate space*: the `localcoord` pair, how responsive the camera
//! feels, how far characters may walk toward the screen edge, and the zoom
//! range. Those are the same whatever backdrop you drop in.
//!
//! It deliberately does **not** carry `boundleft`, `boundright`, `boundhigh`,
//! `start` or `zoffset`. Every one of those is a function of the actual
//! artwork — its real pixel dimensions, and where the horizon happens to sit
//! in it. Earlier revisions hardcoded them, which is why a backdrop that
//! wasn't exactly the expected size produced a camera that scrolled past the
//! edge, and why characters floated or sank on anything but the one source
//! image the numbers were copied from.
//!
//! Those values are derived per-image in [`crate::geometry`]. There is no
//! longer anywhere to put a wrong one.
//!
//! # Confidence
//!
//! - `Empirical` — the camera feel comes from a real reference stage that
//!   passed Phase 2 validation.
//! - `FormulaDerived` — no usable source existed at this resolution; values
//!   are scaled from the nearest one.

use serde::{Deserialize, Serialize};

use crate::geometry::Localcoord;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StageTemplate {
    pub id: &'static str,
    pub display_name: &'static str,
    pub confidence: TemplateConfidence,

    /// The coordinate space this template authors in.
    pub localcoord_w: u32,
    pub localcoord_h: u32,

    /// Suggested backdrop size — guidance for the image generator, not a
    /// requirement. Any image at or above [`crate::geometry::minimum_image_size`]
    /// works; a larger one simply buys more scroll.
    pub recommended_bg_width: u32,
    pub recommended_bg_height: u32,

    /// Where the horizon usually falls, as a share of artwork height. Seeds
    /// the floor-line handle on import; the user drags it from there.
    pub default_floor_ratio: f32,

    // --- Camera feel. Genuinely template-level. ---
    pub tension: i32,
    pub floor_tension: Option<i32>,
    pub vertical_follow: f32,
    pub screen_left: i32,
    pub screen_right: i32,

    /// `[Camera] zoomin` / `zoomout`. `zoomout` is a divisor on the viewport:
    /// at `0.75` the camera can pull back to show `1 / 0.75` of the normal
    /// area, and every bound shrinks to match. Both default to `1.0` — no
    /// zoom — so a stage exported without touching them is provably correct.
    pub zoomin: f32,
    pub zoomout: f32,

    pub source_stage: &'static str,
    pub source_author: &'static str,
    pub notes: &'static str,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TemplateConfidence {
    Empirical,
    FormulaDerived,
}

impl StageTemplate {
    pub fn localcoord(&self) -> Localcoord {
        Localcoord::new(self.localcoord_w, self.localcoord_h)
    }
}

// T1 — 320x240 Classic (WinMUGEN / lo-res)
// Camera feel from `Japan`, the only reference stage already using the
// canonical center-bottom axis. Its shipped bounds (±152, -200) are
// reproduced by the derivation for a 624x483 backdrop, which is the
// regression test in geometry.rs.
pub const T1: StageTemplate = StageTemplate {
    id: "T1",
    display_name: "320x240 Classic (WinMUGEN / lo-res)",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 320,
    localcoord_h: 240,
    recommended_bg_width: 640,
    recommended_bg_height: 480,
    default_floor_ratio: 0.88,
    tension: 60,
    floor_tension: Some(90),
    vertical_follow: 0.2,
    screen_left: 25,
    screen_right: 25,
    zoomin: 1.0,
    zoomout: 1.0,
    source_stage: "Japan",
    source_author: "unknown",
    notes: "Camera values follow the MUGEN 1.0 convention rather than Japan's \
            atypical 60/75/1.0.",
};

// T2 — 640x480 MUGEN 1.0 hi-res
// Camera feel from the Phantom.of.the.Server cluster (GenbuTempleNight,
// HaHaciendaIsland, KeepersImmortalDreams), which share an identical
// [Camera] block. floor_tension is None because all three omit it and the
// engine default is better than a number we invented.
pub const T2: StageTemplate = StageTemplate {
    id: "T2",
    display_name: "640x480 MUGEN 1.0 hi-res",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 640,
    localcoord_h: 480,
    recommended_bg_width: 1280,
    recommended_bg_height: 720,
    default_floor_ratio: 0.88,
    tension: 120,
    floor_tension: None,
    // The source cluster uses 1.0, but all three come from one author and all
    // three ship a backdrop with no vertical headroom, so the value was never
    // exercised. 0.5 is the middle of the range seen across the wider dataset.
    vertical_follow: 0.5,
    screen_left: 30,
    screen_right: 30,
    zoomin: 1.0,
    zoomout: 1.0,
    source_stage: "GenbuTempleNight",
    source_author: "Phantom.of.the.Server",
    notes: "floortension omitted deliberately - all three source DEFs omit it. \
            Camera feel only: sprite 0,0 in these stages is 1280x279, too short \
            to be the backdrop, so their bounds were never verifiable.",
};

// T3 — 1280x720 IKEMEN GO
// Camera feel from `CF3GRAVE` by JoeStar, the only third-party 1280x720
// stage in the dataset whose shipped bounds match the derivation.
pub const T3: StageTemplate = StageTemplate {
    id: "T3",
    display_name: "1280x720 IKEMEN GO",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 1280,
    localcoord_h: 720,
    recommended_bg_width: 1800,
    recommended_bg_height: 1050,
    default_floor_ratio: 0.88,
    tension: 200,
    floor_tension: Some(400),
    vertical_follow: 0.75,
    screen_left: 60,
    screen_right: 60,
    zoomin: 1.0,
    zoomout: 1.0,
    source_stage: "CF3GRAVE",
    source_author: "JoeStar",
    notes: "Source uses a top-anchored axis (900, 0) with start = 0,-326. \
            Stage Studio writes the equivalent center-bottom placement.",
};

// T4 — 1920x1080 IKEMEN GO 1080p
// FORMULA-DERIVED: no source stage at this resolution. Camera feel scaled
// 1.5x from T3. Re-derive the moment a clean 1920x1080 reference surfaces.
pub const T4: StageTemplate = StageTemplate {
    id: "T4",
    display_name: "1920x1080 IKEMEN GO 1080p",
    confidence: TemplateConfidence::FormulaDerived,
    localcoord_w: 1920,
    localcoord_h: 1080,
    recommended_bg_width: 2688,
    recommended_bg_height: 1568,
    default_floor_ratio: 0.88,
    tension: 300,
    floor_tension: Some(600),
    vertical_follow: 0.75,
    screen_left: 90,
    screen_right: 90,
    zoomin: 1.0,
    zoomout: 1.0,
    source_stage: "(none)",
    source_author: "(formula-derived from T3)",
    notes: "No 1920x1080 reference stage exists in the dataset. Camera feel is \
            T3 scaled by 1.5; treat as a starting point, not ground truth.",
};

// The four sizes the tool targets. T3_WIDE was removed: its numbers came from
// Elecbyte's `stage0-720`, which is parallax-only (every layer has delta < 1),
// so its shipped bounds of +/-500 cannot be reproduced by any single flat
// backdrop. The old template paired that provenance with a delta = 1 formula
// result of +/-960, giving the camera nearly twice the legal scroll. Wide
// backdrops are now handled by importing a wider image into T3, which derives
// the correct bounds for whatever width you actually supply.
pub const ALL_TEMPLATES: &[StageTemplate] = &[T1, T2, T3, T4];

pub fn by_id(id: &str) -> Option<&'static StageTemplate> {
    ALL_TEMPLATES.iter().find(|t| t.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::{derive_bounds, minimum_image_size};

    #[test]
    fn every_template_has_a_usable_recommended_backdrop() {
        for t in ALL_TEMPLATES {
            let (min_w, min_h) = minimum_image_size(t.localcoord(), t.zoomout as f64);
            assert!(
                t.recommended_bg_width >= min_w && t.recommended_bg_height >= min_h,
                "{}: recommended {}x{} is under the {}x{} minimum",
                t.id,
                t.recommended_bg_width,
                t.recommended_bg_height,
                min_w,
                min_h
            );
        }
    }

    /// The recommended backdrop must leave the camera somewhere to go in both
    /// axes, otherwise the template ships a stage that cannot scroll.
    #[test]
    fn recommended_backdrop_yields_real_scroll_room() {
        for t in ALL_TEMPLATES {
            let b = derive_bounds(
                t.recommended_bg_width,
                t.recommended_bg_height,
                t.localcoord(),
                t.zoomout as f64,
            );
            assert!(b.bound_right > 0, "{}: no horizontal scroll", t.id);
            assert!(b.bound_high < 0, "{}: no vertical headroom", t.id);
            assert_eq!(b.bound_left, -b.bound_right, "{}: asymmetric", t.id);
            assert_eq!(b.bound_low, 0, "{}: boundlow should stay at 0", t.id);
        }
    }

    #[test]
    fn ids_are_unique_and_resolvable() {
        for t in ALL_TEMPLATES {
            assert!(by_id(t.id).is_some(), "{} not resolvable", t.id);
        }
        let mut ids: Vec<_> = ALL_TEMPLATES.iter().map(|t| t.id).collect();
        ids.sort_unstable();
        let before = ids.len();
        ids.dedup();
        assert_eq!(before, ids.len(), "duplicate template id");
    }

    #[test]
    fn four_sizes_no_duplicate_localcoord() {
        assert_eq!(ALL_TEMPLATES.len(), 4);
        let mut lcs: Vec<_> = ALL_TEMPLATES
            .iter()
            .map(|t| (t.localcoord_w, t.localcoord_h))
            .collect();
        lcs.sort_unstable();
        let before = lcs.len();
        lcs.dedup();
        assert_eq!(before, lcs.len(), "two templates share a localcoord");
    }

    #[test]
    fn zoom_range_is_sane() {
        for t in ALL_TEMPLATES {
            assert!(t.zoomout > 0.0 && t.zoomout <= 1.0, "{}: zoomout", t.id);
            assert!(t.zoomin >= 1.0, "{}: zoomin", t.id);
        }
    }
}
