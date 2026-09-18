//! The stage coordinate model, and every camera value derived from it.
//!
//! # Screen space
//!
//! All `[BG ]` element positions live in a single 2D space measured in
//! `localcoord` units:
//!
//! ```text
//!   x = 0                    horizontal centre of the viewport
//!   y = 0                    TOP edge of the viewport, camera at rest
//!   y = localcoord_h         BOTTOM edge of the viewport, camera at rest
//! ```
//!
//! A `[BG ]` element's `start = sx, sy` places the sprite's **axis point**
//! at `(sx, sy)` in that space. So for a sprite `w × h` with axis
//! `(ax, ay)`:
//!
//! ```text
//!   left   = sx - ax          top    = sy - ay
//!   right  = left + w         bottom = top + h
//! ```
//!
//! # Why this matters
//!
//! `start` is measured from the **top of the viewport**, not from the floor
//! line. Earlier revisions of `mugen-stage-skill.md` claimed `start = 0, 0`
//! puts the bottom of the image on the `zoffset` line. It does not — it puts
//! the axis point on the *top edge of the screen*, which with a
//! center-bottom axis drops the whole backdrop above the viewport and leaves
//! characters standing in empty space.
//!
//! Both clean `delta = 1,1` reference stages in `stage-analysis.json` confirm
//! the top-of-viewport origin:
//!
//! | Stage     | axis       | start     | image     | `boundhigh` | `sy - ay` |
//! |-----------|------------|-----------|-----------|-------------|-----------|
//! | Japan     | (312, 483) | `0,240`   | 624×483   | -200        | -243      |
//! | CF3GRAVE  | (900, 0)   | `0,-326`  | 1800×1050 | -326        | -326      |
//!
//! In both, `sy - ay` is the top edge of the artwork in screen space, and
//! `boundhigh` tracks it (Japan holds 43 units of margin back; CF3GRAVE
//! holds 4). Under a floor-relative origin neither stage would render on
//! screen at all.
//!
//! # The axis / start pair
//!
//! Axis and `start` are a **coupled pair**. Rewriting one without the other
//! translates the artwork by the difference. Stage Studio always writes a
//! center-bottom axis, so it must always write the matching `start`.

use serde::{Deserialize, Serialize};

/// Fraction of the available vertical scroll held back so the camera never
/// parks exactly on the top edge of the artwork.
///
/// Reference stages are not consistent here — `CF3GRAVE` keeps 1.2% and
/// `Japan` keeps 17.7% — so this is a judgement call rather than a
/// reproduction of a convention. 2% is enough to absorb rounding and the
/// engine's own sub-unit camera drift without visibly shortening the scroll.
pub const VERTICAL_EDGE_MARGIN: f64 = 0.02;

/// Share of the viewport height occupied by the lifebars along the top edge.
/// Used only to warn that characters will be drawn behind them.
pub const LIFEBAR_ZONE_RATIO: f64 = 0.15;

/// Height of a typical character as a share of viewport height, used for the
/// same warning. Kung Fu Man stands roughly 90 units tall in a 240-unit
/// viewport.
pub const CHARACTER_HEIGHT_RATIO: f64 = 0.375;

/// The coordinate space a stage is authored in — the `[StageInfo] localcoord`
/// pair. Every other value in this module is measured in these units.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Localcoord {
    pub w: u32,
    pub h: u32,
}

impl Localcoord {
    pub const fn new(w: u32, h: u32) -> Self {
        Self { w, h }
    }
}

/// A sprite's anchor point inside the SFF.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Axis {
    pub x: i32,
    pub y: i32,
}

/// A `[BG ]` element's `start = x, y`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Start {
    pub x: i32,
    pub y: i32,
}

/// Where a sprite's four edges land in screen space, given its size, axis and
/// `start`. This is the single place the axis/start coupling is expressed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Placement {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

impl Placement {
    pub fn resolve(width: u32, height: u32, axis: Axis, start: Start) -> Self {
        let left = start.x - axis.x;
        let top = start.y - axis.y;
        Self {
            left,
            top,
            right: left + width as i32,
            bottom: top + height as i32,
        }
    }
}

/// The center-bottom axis Stage Studio always writes: `(w / 2, h)`.
pub fn canonical_axis(width: u32, height: u32) -> Axis {
    Axis {
        x: (width / 2) as i32,
        y: height as i32,
    }
}

/// The `start` that pairs with [`canonical_axis`] to put the artwork's bottom
/// edge at `bottom_y` in screen space.
///
/// For the default flush-bottom layout, `bottom_y` is `localcoord.h` — **not
/// zero**. `start = 0, 0` with a center-bottom axis is the specific mistake
/// that puts the backdrop above the viewport.
pub fn canonical_start(bottom_y: i32) -> Start {
    Start { x: 0, y: bottom_y }
}

/// Everything the DEF's `[Camera]` block needs, derived from one backdrop.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CameraBounds {
    pub bound_left: i32,
    pub bound_right: i32,
    pub bound_high: i32,
    pub bound_low: i32,
}

/// Horizontal scroll limit for a single background layer.
///
/// A layer with horizontal `delta = d` moves `d` units for every unit the
/// camera moves, so a camera offset of `c` shifts the layer by `c * d`. The
/// layer's edge becomes visible once `|c| * d` exceeds the slack between the
/// layer and the viewport:
///
/// ```text
///   |c| <= (layer_width - visible_width) / (2 * d)
/// ```
///
/// With `delta = 1` this reduces to the familiar
/// `±(image_width - localcoord_w) / 2`. With `delta < 1` the layer scrolls
/// *slower* than the camera, so it tolerates more camera travel — which is
/// why bounds copied from a parallax stage onto a flat single-image stage are
/// meaningless in either direction.
///
/// For a stage with several layers the usable bound is the **minimum** across
/// all of them; see [`horizontal_bound_multi`].
pub fn horizontal_bound(layer_width: u32, visible_width: f64, delta: f64) -> i32 {
    if delta <= 0.0 {
        // delta = 0 pins the layer to the camera; it can never expose an edge.
        return i32::MAX;
    }
    let slack = layer_width as f64 - visible_width;
    if slack <= 0.0 {
        return 0;
    }
    (slack / (2.0 * delta)).floor() as i32
}

/// The binding horizontal bound across every layer in a stage.
pub fn horizontal_bound_multi(layers: &[(u32, f64)], visible_width: f64) -> i32 {
    layers
        .iter()
        .map(|&(w, d)| horizontal_bound(w, visible_width, d))
        .min()
        .unwrap_or(0)
        .max(0)
}

/// The full `[Camera]` bound set for the common case: one flat backdrop at
/// `delta = 1,1`, bottom edge flush with the bottom of the viewport.
///
/// `zoomout` is the `[Camera] zoomout` value — the smallest scale the camera
/// may reach. It is a divisor on the viewport: at `zoomout = 0.75` the camera
/// shows `1 / 0.75 = 1.333x` the normal area, so every bound shrinks. Passing
/// `1.0` means "no zoom" and reproduces the classic formulas.
pub fn derive_bounds(
    image_width: u32,
    image_height: u32,
    localcoord: Localcoord,
    zoomout: f64,
) -> CameraBounds {
    let placement = Placement::resolve(
        image_width,
        image_height,
        canonical_axis(image_width, image_height),
        canonical_start(localcoord.h as i32),
    );
    derive_bounds_for_placement(placement, localcoord, zoomout)
}

/// [`derive_bounds`] for an arbitrary placement, so a backdrop that hangs
/// below the floor or sits off-centre still gets correct numbers.
pub fn derive_bounds_for_placement(
    placement: Placement,
    localcoord: Localcoord,
    zoomout: f64,
) -> CameraBounds {
    let zoomout = if zoomout > 0.0 { zoomout } else { 1.0 };
    let visible_w = localcoord.w as f64 / zoomout;
    let visible_h = localcoord.h as f64 / zoomout;

    // Horizontal: the artwork is centred, so the usable travel each way is
    // the smaller of the two side slacks.
    let slack_left = -placement.left as f64 - visible_w / 2.0;
    let slack_right = placement.right as f64 - visible_w / 2.0;
    let horizontal = slack_left.min(slack_right).max(0.0).floor() as i32;

    // Vertical: zooming out grows the viewport around the camera, so half the
    // extra height eats into the headroom above.
    let extra_h = (visible_h - localcoord.h as f64).max(0.0);
    let headroom = (-placement.top as f64) - extra_h / 2.0;
    let usable = (headroom.max(0.0) * (1.0 - VERTICAL_EDGE_MARGIN)).floor();

    CameraBounds {
        bound_left: -horizontal,
        bound_right: horizontal,
        bound_high: -(usable as i32),
        bound_low: 0,
    }
}

/// Where the floor line sits on screen, given where it sits in the artwork.
///
/// `floor_y_in_image` is measured in pixels down from the top of the
/// (already-scaled) artwork. This is the value a user sets by dragging the
/// floor line in the import screen; it cannot be a template constant because
/// it depends entirely on where the horizon landed in the source image.
pub fn derive_zoffset(placement: Placement, floor_y_in_image: u32) -> i32 {
    placement.top + floor_y_in_image as i32
}

/// The inverse: the floor line in artwork pixels that produces a given
/// `zoffset`. Used to seed the floor-line handle from a template default.
pub fn floor_y_for_zoffset(placement: Placement, zoffset: i32) -> u32 {
    (zoffset - placement.top).max(0) as u32
}

/// Smallest backdrop that still fills the viewport at maximum zoom-out.
///
/// Anything smaller shows past the artwork the moment the camera pulls back,
/// which is the single most common cause of "the background has edges" in a
/// zoom-enabled stage.
pub fn minimum_image_size(localcoord: Localcoord, zoomout: f64) -> (u32, u32) {
    let zoomout = if zoomout > 0.0 { zoomout } else { 1.0 };
    (
        (localcoord.w as f64 / zoomout).ceil() as u32,
        (localcoord.h as f64 / zoomout).ceil() as u32,
    )
}

/// Uniform scale factor that makes `(width, height)` cover `(min_w, min_h)`.
///
/// Returns `1.0` when the artwork is already large enough — a bigger backdrop
/// is never a problem, it just buys more scroll. Never returns a non-uniform
/// pair: stretching a backdrop to fit is the one transform that is always
/// wrong.
pub fn cover_scale(width: u32, height: u32, min_w: u32, min_h: u32) -> f64 {
    if width == 0 || height == 0 {
        return 1.0;
    }
    let sx = min_w as f64 / width as f64;
    let sy = min_h as f64 / height as f64;
    sx.max(sy).max(1.0)
}

/// Apply a uniform scale, rounding away from zero so a scaled backdrop never
/// lands a pixel short of the viewport.
pub fn scaled_size(width: u32, height: u32, scale: f64) -> (u32, u32) {
    (
        (width as f64 * scale).ceil() as u32,
        (height as f64 * scale).ceil() as u32,
    )
}

/// True when a character standing on `zoffset` would have their head drawn
/// behind the lifebars.
pub fn head_behind_lifebars(zoffset: i32, localcoord: Localcoord) -> bool {
    let character_top = zoffset as f64 - localcoord.h as f64 * CHARACTER_HEIGHT_RATIO;
    character_top < localcoord.h as f64 * LIFEBAR_ZONE_RATIO
}

#[cfg(test)]
mod tests {
    use super::*;

    const LC_320: Localcoord = Localcoord::new(320, 240);
    const LC_1280: Localcoord = Localcoord::new(1280, 720);

    /// `Japan` — the one reference stage that already uses the canonical
    /// center-bottom axis. Its `start = 0,240` equals `localcoord.h`, which is
    /// exactly what `canonical_start` produces.
    #[test]
    fn japan_reference_placement() {
        let axis = canonical_axis(624, 483);
        assert_eq!(axis, Axis { x: 312, y: 483 });

        let start = canonical_start(LC_320.h as i32);
        assert_eq!(start, Start { x: 0, y: 240 });

        let p = Placement::resolve(624, 483, axis, start);
        assert_eq!(p.top, -243, "top edge of the artwork in screen space");
        assert_eq!(p.bottom, 240, "bottom edge flush with the viewport");
        assert_eq!(p.left, -312);
        assert_eq!(p.right, 312);
    }

    /// The same stage, read back from the DEF the other way round: Japan's
    /// shipped `boundleft/right` of ±152 is the zero-margin horizontal
    /// formula, and its `boundhigh` of -200 sits inside our -243 ceiling.
    #[test]
    fn japan_reference_bounds() {
        let b = derive_bounds(624, 483, LC_320, 1.0);
        assert_eq!(b.bound_left, -152);
        assert_eq!(b.bound_right, 152);
        assert!(
            b.bound_high >= -243 && b.bound_high < 0,
            "must not exceed the artwork's top edge, got {}",
            b.bound_high
        );
        assert!(
            b.bound_high <= -200,
            "should not be more conservative than the shipped stage, got {}",
            b.bound_high
        );
    }

    /// `CF3GRAVE` uses a top-anchored axis `(900, 0)` with `start = 0,-326`.
    /// Rewriting the axis to center-bottom without recomputing `start` is the
    /// bug this module exists to prevent — check both describe the same
    /// artwork position.
    #[test]
    fn rewriting_axis_requires_rewriting_start() {
        let source = Placement::resolve(
            1800,
            1050,
            Axis { x: 900, y: 0 },
            Start { x: 0, y: -326 },
        );
        assert_eq!(source.top, -326);
        assert_eq!(source.bottom, 724);

        // Naive rewrite: new axis, old start. The artwork jumps 1050 units up.
        let broken = Placement::resolve(
            1800,
            1050,
            canonical_axis(1800, 1050),
            Start { x: 0, y: -326 },
        );
        assert_eq!(broken.bottom, -326);
        assert!(
            broken.bottom < 0,
            "the whole backdrop ends up above the viewport"
        );

        // Correct rewrite: recompute start from the placement we want to keep.
        let fixed = Placement::resolve(
            1800,
            1050,
            canonical_axis(1800, 1050),
            canonical_start(source.bottom),
        );
        assert_eq!(fixed, source, "same artwork position, canonical axis");
    }

    #[test]
    fn horizontal_bound_matches_classic_formula_at_delta_one() {
        // (1800 - 1280) / 2 = 260, which is CF3GRAVE's shipped boundright.
        assert_eq!(horizontal_bound(1800, 1280.0, 1.0), 260);
    }

    /// A parallax layer tolerates more camera travel than a flat one, which is
    /// why `stage0-720`'s numbers cannot be reused for a single flat image.
    #[test]
    fn parallax_layers_change_the_bound() {
        let flat = horizontal_bound(3200, 1280.0, 1.0);
        let parallax = horizontal_bound(3200, 1280.0, 0.75);
        assert_eq!(flat, 960);
        assert_eq!(parallax, 1280);
        assert!(parallax > flat);

        // stage0-720's real bound is set by its narrowest layer, not its widest.
        let binding = horizontal_bound_multi(&[(3200, 0.75), (1600, 0.78)], 1280.0);
        assert!(
            binding < flat,
            "the narrow layer binds first: {binding} should be under {flat}"
        );
    }

    #[test]
    fn zoom_out_shrinks_every_bound() {
        let none = derive_bounds(1800, 1050, LC_1280, 1.0);
        let zoomed = derive_bounds(1800, 1050, LC_1280, 0.75);

        assert_eq!(none.bound_right, 260);
        // Visible width becomes 1280 / 0.75 = 1706.67, leaving (1800-1706.67)/2.
        assert_eq!(zoomed.bound_right, 46);
        assert!(zoomed.bound_high > none.bound_high, "less headroom when zoomed out");
    }

    #[test]
    fn bounds_never_go_positive_when_the_image_is_too_small() {
        let b = derive_bounds(1000, 500, LC_1280, 1.0);
        assert_eq!(b.bound_left, 0);
        assert_eq!(b.bound_right, 0);
        assert_eq!(b.bound_high, 0);
    }

    #[test]
    fn zoffset_follows_the_floor_line() {
        // 1050-tall artwork, flush bottom in a 720 viewport: top sits at -330.
        let p = Placement::resolve(
            1800,
            1050,
            canonical_axis(1800, 1050),
            canonical_start(720),
        );
        assert_eq!(p.top, -330);

        // A horizon 924px down the artwork puts the floor at 594 on screen,
        // which is CF3GRAVE's shipped zoffset.
        assert_eq!(derive_zoffset(p, 924), 594);
        // And the inverse round-trips.
        assert_eq!(floor_y_for_zoffset(p, 594), 924);
    }

    #[test]
    fn minimum_size_accounts_for_zoom() {
        assert_eq!(minimum_image_size(LC_1280, 1.0), (1280, 720));
        assert_eq!(minimum_image_size(LC_1280, 0.75), (1707, 960));
    }

    #[test]
    fn cover_scale_is_uniform_and_never_shrinks() {
        // A 1536x1024 generation against a 1280x720 viewport is already big
        // enough in both axes.
        assert_eq!(cover_scale(1536, 1024, 1280, 720), 1.0);

        // Same generation against the zoomed-out minimum needs a slight bump,
        // driven by the width shortfall.
        let s = cover_scale(1536, 1024, 1707, 960);
        assert!((s - 1707.0 / 1536.0).abs() < 1e-9);

        let (w, h) = scaled_size(1536, 1024, s);
        assert!(w >= 1707 && h >= 960, "covers in both axes: {w}x{h}");

        // Aspect ratio is preserved.
        let before = 1536.0 / 1024.0;
        let after = w as f64 / h as f64;
        assert!((before - after).abs() < 0.01, "no stretch");
    }

    #[test]
    fn lifebar_warning_fires_only_when_the_floor_is_high() {
        // Floor near the bottom of the viewport: plenty of clearance.
        assert!(!head_behind_lifebars(594, LC_1280));
        // Floor dragged most of the way up: the character's head is in the bars.
        assert!(head_behind_lifebars(300, LC_1280));
    }
}
