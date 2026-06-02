// Canonical stage templates.
//
// Every value in this file traces to `mugen-stage-skill.md` Section 2 and
// `template-candidates.md`. Do not edit numeric values without re-deriving
// from those source documents.
//
// The new app always writes center-bottom axis (axisX = bg_width / 2,
// axisY = bg_height). Sprite axis is never user-configurable; the new app
// enforces this convention regardless of what the source stages used.
//
// Confidence levels:
//   Empirical      — values come from a real third-party reference stage
//                    that passed Phase 2 validation.
//   FormulaDerived — no usable real source existed; values computed from
//                    the bounds/camera formulas in the skill file.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StageTemplate {
    pub id: &'static str,
    pub display_name: &'static str,
    pub confidence: TemplateConfidence,
    pub localcoord_w: u32,
    pub localcoord_h: u32,
    pub bg_width: u32,
    pub bg_height: u32,
    pub axis_x: u32,
    pub axis_y: u32,
    pub bound_left: i32,
    pub bound_right: i32,
    pub bound_high: i32,
    pub bound_low: i32,
    pub zoffset: i32,
    pub tension: i32,
    pub floor_tension: Option<i32>,
    pub vertical_follow: f32,
    pub screen_left: i32,
    pub screen_right: i32,
    pub source_stage: &'static str,
    pub source_author: &'static str,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TemplateConfidence {
    Empirical,
    FormulaDerived,
}

// T1 — 320×240 Classic (WinMUGEN / lo-res)
// Source: `Japan` (author absent in DEF [Info] block).
// Image, axis, bounds (formula), zoffset, screenleft/right are from source.
// `tension`, `floor_tension`, `vertical_follow` use the documented MUGEN 1.0
// convention rather than Japan's atypical values (60/75/1.0) — see skill
// file Section 2, T1 inferred-fields note.
pub const T1: StageTemplate = StageTemplate {
    id: "T1",
    display_name: "320×240 Classic (WinMUGEN / lo-res)",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 320,
    localcoord_h: 240,
    bg_width: 624,
    bg_height: 483,
    axis_x: 312, // 624 / 2
    axis_y: 483, // bg_height
    bound_left: -152,  // -((624 - 320) / 2)
    bound_right: 152,  //  ((624 - 320) / 2)
    bound_high: -243,  // -(483 - 240)
    bound_low: 0,
    zoffset: 217,
    tension: 60,
    floor_tension: Some(90),
    vertical_follow: 0.2,
    screen_left: 25,
    screen_right: 25,
    source_stage: "Japan",
    source_author: "unknown",
};

// T2 — 640×480 MUGEN 1.0 hi-res
// Source: Phantom.of.the.Server cluster (GenbuTempleNight + HaHaciendaIsland
// + KeepersImmortalDreams). All three sources share identical camera config.
// GenbuTempleNight chosen as the canonical representative (modal image
// width = 1280; recommended height defaults to localcoord height for the
// canonical flat-aspect template — empirical heights vary 279/853/1280).
// floor_tension is `None` because the source DEFs omit it; the engine
// applies its default. Do not synthesize a value here — see skill file
// Section 3 floortension discussion.
pub const T2: StageTemplate = StageTemplate {
    id: "T2",
    display_name: "640×480 MUGEN 1.0 hi-res",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 640,
    localcoord_h: 480,
    bg_width: 1280,
    bg_height: 480,
    axis_x: 640, // 1280 / 2
    axis_y: 480, // bg_height
    bound_left: -320,  // -((1280 - 640) / 2)
    bound_right: 320,
    bound_high: 0,     // -(480 - 480), clamped to 0
    bound_low: 0,
    zoffset: 432,      // exactly 0.9 × localcoord_h
    tension: 120,
    floor_tension: None,  // omitted in all three source DEFs
    vertical_follow: 1.0, // single-author bias, see skill file caveat
    screen_left: 30,
    screen_right: 30,
    source_stage: "GenbuTempleNight",
    source_author: "Phantom.of.the.Server",
};

// T3_STANDARD — 1280×720 IKEMEN GO Standard
// Source: `CF3GRAVE` by JoeStar — the only third-party 1280×720 bounds-match
// stage in the dataset. Source uses top-anchored axis (900, 0); template
// rewrites to center-bottom (900, 1050) per Stage Studio convention.
// boundhigh is formula-derived (-330); source used -326 (within rounding).
// See `mugen-stage-skill.md` Section 2 "Template T3_STANDARD" for the full
// derivation and the cross-check against T3_WIDE's `stage0-720` source.
pub const T3_STANDARD: StageTemplate = StageTemplate {
    id: "T3_STANDARD",
    display_name: "1280×720 IKEMEN GO Standard",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 1280,
    localcoord_h: 720,
    bg_width: 1800,
    bg_height: 1050,
    axis_x: 900,  // 1800 / 2
    axis_y: 1050, // bg_height (rewritten from source's top-anchored (900, 0))
    bound_left: -260,  // -((1800 - 1280) / 2)
    bound_right: 260,
    bound_high: -330,  // -(1050 - 720)
    bound_low: 0,
    zoffset: 594,
    tension: 200,
    floor_tension: Some(400),
    vertical_follow: 0.75,
    screen_left: 60,
    screen_right: 60,
    source_stage: "CF3GRAVE",
    source_author: "JoeStar",
};

// T3_WIDE — 1280×720 IKEMEN GO Wide
// Source: `stage0-720` by Elecbyte. The wider variant of the 1280×720
// template for stages where the backdrop is designed to scroll
// significantly (cinematic stages, large arenas) — backdrop ~2.5× viewport
// width vs T3_STANDARD's ~1.4×.
//
// Bounds are formula-derived from the 3200×1072 image. zoffset and camera
// params come from stage0-720 directly. floortension diverges from
// T3_STANDARD (200 vs 400); both values are documented in the skill file.
//
// CONFIDENCE: Empirical — Elecbyte first-party source. Note the source is
// parallax-only (every BG layer has `delta < 1`); see `mugen-stage-skill.md`
// Section 2 "Template T3_WIDE" parallax flag and Section 5 for what
// parallax-only implies for the formula. The template's boundhigh is
// formula-derived rather than copied from the source's `-450`.
pub const T3_WIDE: StageTemplate = StageTemplate {
    id: "T3_WIDE",
    display_name: "1280×720 IKEMEN GO Wide",
    confidence: TemplateConfidence::Empirical,
    localcoord_w: 1280,
    localcoord_h: 720,
    bg_width: 3200,
    bg_height: 1072,
    axis_x: 1600, // 3200 / 2
    axis_y: 1072, // bg_height (rewritten from source's (1600, 460))
    bound_left: -960,  // -((3200 - 1280) / 2)
    bound_right: 960,
    bound_high: -352,  // -(1072 - 720)
    bound_low: 0,
    zoffset: 660,
    tension: 200,
    floor_tension: Some(200),
    vertical_follow: 0.85,
    screen_left: 60,
    screen_right: 60,
    source_stage: "stage0-720",
    source_author: "Elecbyte",
};

// T4 — 1920×1080 IKEMEN GO 1080p
// FORMULA-DERIVED: no source stages at this resolution.
// Image dimensions scaled from CF3GRAVE's 1280×720 ratio (1.41 × 1.46).
// Camera params from skill file Section 3 scaling rule. Re-validate the
// moment a clean third-party 1920×1080 reference stage surfaces — see
// Community Validation Loop in VALIDATOR-CONCEPT.md.
pub const T4: StageTemplate = StageTemplate {
    id: "T4",
    display_name: "1920×1080 IKEMEN GO 1080p",
    confidence: TemplateConfidence::FormulaDerived,
    localcoord_w: 1920,
    localcoord_h: 1080,
    bg_width: 2700,
    bg_height: 1577,
    axis_x: 1350, // 2700 / 2
    axis_y: 1577, // bg_height
    bound_left: -390,  // -((2700 - 1920) / 2)
    bound_right: 390,
    bound_high: -497,  // -(1577 - 1080)
    bound_low: 0,
    zoffset: 920,      // ≈ 0.85 × 1080
    tension: 300,
    floor_tension: Some(600),
    vertical_follow: 0.75,
    screen_left: 90,
    screen_right: 90,
    source_stage: "(formula-derived)",
    source_author: "(none — no source at this resolution)",
};

pub const ALL_TEMPLATES: &[StageTemplate] = &[T1, T2, T3_STANDARD, T3_WIDE, T4];

pub fn by_id(id: &str) -> Option<&'static StageTemplate> {
    ALL_TEMPLATES.iter().find(|t| t.id == id)
}
