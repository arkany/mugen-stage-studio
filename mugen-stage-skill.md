---
name: mugen-stage
description: Reasoning kit for MUGEN / IKEMEN GO stage configuration. Encodes the parameter model, canonical templates, axis conventions, parallax behavior, multi-layer handling, image conformance, and validator decisions discovered during Phase 2 of the MUGEN Stage Studio rebuild. Read this before changing template values, writing validator rules, or adjusting SFF/DEF generation.
---

# MUGEN Stage Skill

This is a self-contained reasoning kit for working on MUGEN Stage Studio (the desktop creator) and the MUGEN Stage Validator (the companion website). It encodes the empirical findings from Phase 2 — a parser run over 47 real third-party stages — so that future Claude sessions don't have to re-derive them.

The reader is assumed to know SFF/DEF formats in general but not the specific values, formulas, or in-the-wild conventions documented here.

**Authoritative source data:**
- `parse_stage.py` — the parser implementation
- `stage-analysis.json` — raw per-stage data
- `template-candidates.md` — curated representative selection per `localcoord` group

When this skill conflicts with the data, the data wins. Re-run `analyze_results.py` and update this file.

---

## Section 1 — The Five Interdependent Parameters

A working MUGEN stage requires five values that must all be mathematically consistent with each other and with the background image dimensions. Setting any one of them wrong produces a specific, visible defect at runtime.

### 1.1 `localcoord` — the coordinate space ruler

`localcoord = width, height` (in `[StageInfo]`) defines the virtual coordinate system the stage's other numeric values are measured in. It is the *ruler*, not the *image size*. Every other camera and bound value is interpreted relative to `localcoord`.

- `localcoord = 320, 240` — classic WinMUGEN coordinate space.
- `localcoord = 640, 480` — pre-1.0 hi-res stages (also expressed via the legacy `hires = 1` flag in `[StageInfo]`).
- `localcoord = 1280, 720` — IKEMEN GO standard.
- `localcoord = 1920, 1080` — IKEMEN GO 1080p.

If `localcoord` is omitted, MUGEN treats it as `320, 240`. If `hires = 1` is present without `localcoord`, treat it as `640, 480`.

### 1.2 `boundleft` / `boundright` — horizontal camera limits

Where the camera is allowed to scroll horizontally, in `localcoord` units.

```
boundleft  = -((imageWidth - localcoordWidth) / 2)
boundright =  ((imageWidth - localcoordWidth) / 2)
```

When `imageWidth ≤ localcoordWidth`, both values clamp to `0` (no horizontal scroll possible).

This formula assumes the main background layer scrolls 1:1 with the camera (`delta = 1, 1`). For slow-parallax layers (`delta < 1`) the formula is conservative — see Section 5.

### 1.3 `boundhigh` — upward camera limit

How far the camera is allowed to rise above the floor, in `localcoord` units.

```
boundhigh = imageTopInScreenSpace = start.y - axis.y
```

For the canonical mount (center-bottom axis, `start = 0, localcoordHeight`)
that reduces to the familiar `-(imageHeight - localcoordHeight)` — but only
for that mount. Derive it from the placement, not from the image height, or it
will be wrong for every stage that anchors its artwork anywhere else. With
zoom enabled, subtract half the extra visible height as well (Section 7b).

Clamped to `0` when the artwork does not extend above the viewport. `boundhigh` is *informational*: real stages frequently use a smaller (less-negative) value to limit the camera's upward travel for artistic reasons. That is a creative choice, not an error. Templates record both the formula maximum and the source's actual choice.

### 1.4 `boundlow` — downward camera limit

In Phase 2 every working stage used `boundlow = 0`. Treat `0` as the canonical default; non-zero values are unusual and should be carried over from the source unchanged.

### 1.5 `zoffset` — floor position in coordinate space

`zoffset = N` (in `[StageInfo]`) places the floor (where character feet rest) at y=N in the `localcoord` system. Higher numbers push the floor lower on screen.

There is no formula for `zoffset`. It is an artistic choice constrained by the image: the floor in the artwork has to land where `zoffset` says it does. Phase 2 values:

| localcoord | source stage | zoffset | zoffset / localcoord height |
|---|---|---|---|
| 320, 240 | Japan | 217 | 0.904× |
| 640, 480 | Phantom.of.the.Server cluster (3 stages) | 432 | 0.900× |
| 1280, 720 | CF3GRAVE | 594 | 0.825× |

**Community convention:** Empirical data across T1 and T2 reference stages shows `zoffset` consistently placed at **≈0.9× `localcoord` height** (217/240 = 0.904 for Japan; 432/480 = 0.900 for the Phantom cluster — exactly 0.9×). T3_STANDARD's `CF3GRAVE` source uses 594/720 = 0.825×, slightly below the pattern but in the same neighborhood. This is not documented in the Elecbyte spec; it is emergent community practice — for a 640×480 stage a value around `0.9 × 480 = 432` should look natural, for 1280×720 something in the `594–648` range. Deviation beyond ±15% of the 0.9× value (i.e. outside `0.765×` to `1.035×`) is a soft signal worth flagging in the validator. T1 (Japan at 217 ≈ 0.9 × 240 = 216) confirms the heuristic at 320×240; T3_STANDARD is the partial outlier and may indicate either drift at hi-res or one-author bias — re-evaluate when a second 1280×720 source stage with bounds-match tier surfaces.

### 1.6 Sprite axis — center-bottom convention

Inside the SFF binary, every sprite has an axis `(axisX, axisY)` that defines the anchor point of the image. For a stage's main background sprite, the canonical axis is **center-bottom**:

```
axisX = imageWidth / 2
axisY = imageHeight
```

This is the documented Elecbyte convention. It is only half the story: the axis is meaningless without the `[BG ] start` that pairs with it. With a center-bottom axis the matching value is **`start = 0, localcoordHeight`** — `start = 0, 0` mounts the bottom edge of the image on the *top* of the screen and puts the entire backdrop out of view. See Section 4.

Phase 2 found three other axis conventions in the wild — `(w/2, 0)` top-anchored, `(w/2, zoffset)` floor-anchored, and `(0, 0)` corner-anchored. All can produce a working stage because the `[BG ] start` compensates for the offset — **not** `zoffset`, which only places characters. Only 2 of the 48 readable stages use center-bottom, so treat the alternates as the norm. See Section 4 for the full handling rule.

**Stage Studio always writes center-bottom axis.** Never expose this to the user as configurable.

### 1.7 Symptom → parameter diagnosis

| Visible symptom | Likely wrong parameter | Correction |
|---|---|---|
| Background drifts left or right as the camera scrolls | Sprite axisX off-center | Set `axisX = imageWidth / 2` |
| Background drifts up or down between rounds | Sprite axisY wrong relative to convention | Set `axisY = imageHeight` (center-bottom) |
| Entire background missing / characters in empty space | `[BG ] start` not paired with the axis — usually `start = 0, 0` with a center-bottom axis | Set `start = 0, localcoordHeight` (Section 4) |
| Characters float above the visible ground | `zoffset` too small (floor placed too high in coord space) | Increase `zoffset` — or place the floor line on the ground in the artwork and let it derive |
| Characters sink below the visible ground / feet disappear | `zoffset` too large (floor placed too low) | Decrease `zoffset` |
| Camera scrolls past the edge of the image (black gap or repeated edge) | `boundleft` / `boundright` magnitude exceeds formula | Recompute `±(imageWidth − localcoordWidth) / 2` |
| Edge visible only when the camera zooms out | Bounds computed without `zoomout` | Recompute against `localcoordWidth / zoomout` (Section 7b) |
| Characters' heads hidden behind the lifebars | `zoffset` too small — the floor sits too high on screen | Move the floor line down the artwork |
| Camera doesn't scroll as far as the image allows | `boundleft` / `boundright` magnitude smaller than formula | Acceptable (creative choice) — recompute only if you want full scroll |
| Background snaps upward when a character jumps | `boundhigh` shallower than image allows, or `verticalfollow` too aggressive | Recompute `boundhigh` from the placement (Section 1.3) and lower `verticalfollow` |
| Background scrolls slower than other elements | Layer's `delta < 1, 1` while you expected 1:1 parallax | Set `delta = 1, 1` on the main layer |

---

## Section 2 — Canonical Stage Templates

> **Revised.** Templates no longer carry `boundleft`, `boundright`,
> `boundhigh`, `start` or `zoffset`. Those are all functions of the actual
> artwork — its real pixel dimensions and where the horizon sits in it — so
> hardcoding them only works for the one source image they were copied from.
> They are derived per-image in `stage-core::geometry`. The per-template
> numbers below are retained as the *derivation of the reference stage*, not
> as values to copy into code.
>
> **`T3_WIDE` is withdrawn.** Its bounds were computed with the `delta = 1`
> formula (±960) while its cited source, Elecbyte's `stage0-720`, is
> parallax-only and ships ±500. A wide backdrop is now handled by importing a
> wider image into `T3`, which derives correct bounds for whatever width is
> actually supplied. That leaves four templates, one per target resolution.

One template per `localcoord` group, populated from Phase 2 data. Each template has a **confidence level**:

- **Empirical** — camera feel copied from a real third-party stage that passed Phase 2 validation.
- **Formula-derived** — camera params scaled from the nearest template because no usable real source existed.

Templates **must** be encoded as Rust constants in the Phase 4 backend, **not** as user-editable values. The user picks a template; the camera feel is fixed, and the geometry follows the image.

---

### Template T1 — `320×240 Classic (WinMUGEN / lo-res)`

- **Confidence:** Empirical (1 strict-tier stage in Phase 2 dataset)
- **Source stage:** `Japan` (author unknown — `[Info] author` field absent)
- **Source dir:** `/Users/davidphillips/Sites/macmame/Ikemen-GO/stages`
- **Source axis convention:** center-bottom (`(312, 483)` for the 624×483 image — matches our rule)

| Field | Value | Origin |
|---|---|---|
| `localcoord` | `320, 240` | Source (implicit — DEF omitted; MUGEN default) |
| Recommended image | 624 × 483 | Source `Japan.sff` |
| Sprite axis | `(312, 483)` | Source — exactly `(imageWidth/2, imageHeight)` |
| `boundleft` | `-152` | Formula: `-((624 - 320) / 2)` |
| `boundright` | `152` | Formula |
| `boundhigh` | `-243` | Formula: `-(483 - 240)` (source used `-200`; Stage Studio uses formula maximum) |
| `boundlow` | `0` | Convention |
| `zoffset` | `217` | Source |
| `tension` | `60` | Convention (see Section 3) |
| `floortension` | `90` | Convention (Japan's source value `75` is an outlier — convention preferred) |
| `verticalfollow` | `0.2` | Convention (Japan's source value `1.0` is an outlier) |
| `screenleft` | `25` | Source |
| `screenright` | `25` | Source |

**Inferred fields (absent in source data):** `tension`, `floortension`, `verticalfollow` — Japan's source values are atypical (one strict stage in the dataset is not a strong sample); the values above use the documented MUGEN 1.0 / 320×240 convention instead.

**Derivation (full):**
```
boundleft  = -((imageWidth  - localcoordWidth)  / 2)  = -((624 - 320) / 2) = -152
boundright =  ((imageWidth  - localcoordWidth)  / 2)  =  ((624 - 320) / 2) =  152
boundhigh  = -(imageHeight - localcoordHeight)        = -(483 - 240)        = -243
```

---

### Template T2 — `640×480 MUGEN 1.0 hi-res`

- **Confidence:** Empirical (three independent third-party stages, identical camera config)
- **Source stages:**
  - `GenbuTempleNight` by Phantom.of.the.Server (1280×279, MUGEN 1.1)
  - `HaHaciendaIsland` by Phantom.of.the.Server (1280×853, MUGEN 1.1)
  - `KeepersImmortalDreams` by Iced & Phantom.of.the.Server (1280×1280, MUGEN 1.1)
- **Source dir:** `/Users/davidphillips/Downloads/640/{GenbuTempleNight,HaHaciendaIsland,KeepersImmortalDreams}`
- **Cluster signature:** all three stages share image width = 1280, `boundleft/right = -212/212`, `zoffset = 432`, `tension = 120`, `verticalfollow = 1.0`, `screenleft/right = 30/30`, `floortension` omitted. Image height varies per artwork (279 / 853 / 1280). All within-formula (soft tier); none parallax-only.

| Field | Value | Origin |
|---|---|---|
| `localcoord` | `640, 480` | All three sources, explicit declaration |
| Recommended image | 1280 × 480 | Empirical width (3 of 3 sources use 1280); height defaults to localcoord height for the canonical flat-aspect template — empirical heights vary per artwork (279, 853, 1280) |
| Sprite axis | `(640, 480)` | Center-bottom of recommended image (Stage Studio convention; sources use non-canonical axes — `(640, -288)`, `(640, 168)`, `(640, 652)`) |
| `boundleft` | `-320` | Formula: `-((1280 - 640) / 2)` (sources used `-212` — tighter than formula; either is safe) |
| `boundright` | `320` | Formula (sources used `212`) |
| `boundhigh` | `0` | Formula: `-(480 - 480)` — no vertical scroll for flat-aspect default |
| `boundlow` | `0` | Convention (all sources `0`) |
| `zoffset` | `432` | All three sources — exactly 0.9 × `localcoordHeight` |
| `tension` | `120` | All three sources |
| `floortension` | _(omitted — engine default)_ | All three sources omit `floortension`; the engine applies its default. Stage Studio's generated DEF should likewise omit this field rather than substitute a guess. |
| `verticalfollow` | `1.0` | All three sources. **Note:** This is unusually high — see Section 3 for why the linear scaling story breaks at this row. |
| `screenleft` | `30` | All three sources |
| `screenright` | `30` | All three sources |

**Inferred fields:** sprite axis only (rewritten from sources' non-canonical Y values to canonical center-bottom). Every other value is reproduced byte-for-byte across all three sources, then bounds are formula-derived from the recommended image dimensions.

**Caveat on author bias:** All three sources are authored by Phantom.of.the.Server (one solo on Keepers). The cluster's internal consistency is therefore one author's reproducible voice rather than three independent author voices. Treat this template as empirical but be open to revising `verticalfollow` and `floortension` when a stage by a different 640×480 author surfaces.

**Source `boundhigh` discrepancy:** All three sources hardcode `boundhigh = -480` regardless of their image height. For GenbuTempleNight (1280×279, image shorter than localcoord) this is meaningless; for HaHaciendaIsland (1280×853) it exceeds the formula maximum (-373); for KeepersImmortalDreams (1280×1280) it's within (formula max -800). Stage Studio's templates use formula-derived `boundhigh`, so this discrepancy doesn't propagate.

**Derivation:**
```
boundleft  = -((imageWidth  - localcoordWidth)  / 2)  = -((1280 - 640) / 2) = -320
boundright =  ((imageWidth  - localcoordWidth)  / 2)  =  ((1280 - 640) / 2) =  320
boundhigh  = -(imageHeight - localcoordHeight)        = -(480 - 480)         = 0
```

---

### Template T3_STANDARD — `1280×720 IKEMEN GO Standard`

- **Confidence:** Empirical (third-party `bounds-match` source)
- **Source stage:** `CF3GRAVE` by JoeStar
- **Source dir:** `/Users/davidphillips/Downloads/1280`
- **Source axis convention:** top-anchored `(900, 0)` — non-canonical; Stage Studio rewrites to center-bottom `(900, 1050)` on import

| Field | Value | Origin |
|---|---|---|
| `localcoord` | `1280, 720` | Source |
| Recommended image | 1800 × 1050 | Source `CF3GRAVE.sff` |
| Sprite axis | `(900, 1050)` | Center-bottom of source image (Stage Studio convention; source uses `(900, 0)`) |
| `boundleft` | `-260` | Formula: `-((1800 - 1280) / 2)` — matches source exactly |
| `boundright` | `260` | Formula — matches source exactly |
| `boundhigh` | `-330` | Formula: `-(1050 - 720)` (source used `-326`, within rounding) |
| `boundlow` | `0` | Source |
| `zoffset` | `594` | Source |
| `tension` | `200` | Source |
| `floortension` | `400` | Source |
| `verticalfollow` | `0.75` | Source |
| `screenleft` | `60` | Source |
| `screenright` | `60` | Source |

**Inferred fields:** sprite axis (source uses top-anchored `(900, 0)`; we standardize to center-bottom). Everything else is empirical.

**Cross-check against Elecbyte's `stage0-720`** (the source for T3_WIDE below — soft tier, parallax-only): image 3200×1072, `tension=200`, `floortension=200`, `verticalfollow=0.85`, `zoffset=660`, `screenleft/right=60/60`. The two sources agree on `tension=200` and `screenleft/right=60`; they diverge on `floortension` (CF3GRAVE 400 vs Elecbyte 200) and `verticalfollow` (0.75 vs 0.85). T3_STANDARD uses CF3GRAVE because its bounds match the formula exactly; T3_WIDE uses stage0-720 because its 3200-wide image is the right canonical reference for wide-scroll stages.

**Derivation:**
```
boundleft  = -((imageWidth  - localcoordWidth)  / 2)  = -((1800 - 1280) / 2) = -260
boundright =  ((imageWidth  - localcoordWidth)  / 2)  =  ((1800 - 1280) / 2) =  260
boundhigh  = -(imageHeight - localcoordHeight)        = -(1050 - 720)        = -330
```

---

### Template T3_WIDE — `1280×720 IKEMEN GO Wide`

- **Confidence:** Empirical (Elecbyte first-party — but parallax-only; see flag below)
- **Source stage:** `stage0-720` by Elecbyte
- **Source dir:** `/Users/davidphillips/Sites/macmame/Ikemen-GO/stages`
- **Source axis convention:** non-canonical `(1600, 460)` — center-X with Y at roughly the floor line; Stage Studio rewrites to center-bottom `(1600, 1072)` on import
- **Parallax flag:** `stage0-720`'s main BG element has `delta = .75, .75` (every layer in the stage is `delta < 1`). The `(W − lc)/2` bounds formula is conservative for `delta < 1` layers (see Section 5) — it's still safe to use as the bound, but a parallax-only stage will not exhibit the camera-blow-past-edge symptom that the formula is designed to prevent. The source DEF uses `boundhigh = -450`, more negative than the formula maximum (-352); this would be a bug for a `delta = 1` stage but is safe here because the layer travels at 75% of camera speed and never reaches the edge. **The template uses the formula-derived `boundhigh = -352` to keep behavior predictable on any future image at this template's recommended dimensions.**

| Field | Value | Origin |
|---|---|---|
| `localcoord` | `1280, 720` | Source |
| Recommended image | 3200 × 1072 | Source `stage0-720.sff` |
| Sprite axis | `(1600, 1072)` | Center-bottom of source image (Stage Studio convention; source uses `(1600, 460)`) |
| `boundleft` | `-960` | Formula: `-((3200 - 1280) / 2)` (source used `-500` — tighter than formula; either is safe) |
| `boundright` | `960` | Formula (source used `500`) |
| `boundhigh` | `-352` | Formula: `-(1072 - 720)`. Source used `-450`; see parallax flag above for why the template prefers the formula value |
| `boundlow` | `0` | Source |
| `zoffset` | `660` | Source |
| `tension` | `200` | Source — matches T3_STANDARD |
| `floortension` | `200` | Source — half of T3_STANDARD's 400 |
| `verticalfollow` | `0.85` | Source — slightly higher than T3_STANDARD's 0.75 |
| `screenleft` | `60` | Source — matches T3_STANDARD |
| `screenright` | `60` | Source — matches T3_STANDARD |

**Inferred fields:** sprite axis (rewritten from source's non-canonical position to canonical center-bottom); `boundhigh` (formula-derived rather than copied from source — the source value exceeds the formula maximum and is only safe because all layers are parallax-only).

**When to choose T3_WIDE over T3_STANDARD:** T3_STANDARD is the default for typical 1280×720 stages with a backdrop ~1.4× the viewport width (1800×1050) — moderate horizontal travel, indoor scenes, fight-game-classic compositions. T3_WIDE is for cinematic stages and large arenas where the artwork is designed to scroll significantly — wide vistas, side-scrolling-style cityscapes, long battlefields — backdrop ~2.5× the viewport width (3200×1072). Formula bounds are ±960 vs T3_STANDARD's ±260, so the camera travels roughly 3.7× further horizontally. Pick T3_WIDE when the artwork itself is built for that travel; pick T3_STANDARD otherwise.

**Derivation:**
```
boundleft  = -((imageWidth  - localcoordWidth)  / 2)  = -((3200 - 1280) / 2) = -960
boundright =  ((imageWidth  - localcoordWidth)  / 2)  =  ((3200 - 1280) / 2) =  960
boundhigh  = -(imageHeight - localcoordHeight)        = -(1072 - 720)        = -352
```

---

### Template T4 — `1920×1080 IKEMEN GO 1080p`

- **Confidence:** Formula-derived (no source stage in Phase 2 dataset declared `localcoord = 1920, 1080`)
- **Source:** none — every value below is calculated.

| Field | Value | Origin |
|---|---|---|
| `localcoord` | `1920, 1080` | Convention |
| Recommended image | 2700 × 1577 | Formula-derived (CF3GRAVE's image-to-localcoord ratio scaled to 1920×1080: 1.41 × 1.46) |
| Sprite axis | `(1350, 1577)` | Center-bottom of recommended image |
| `boundleft` | `-390` | Formula: `-((2700 - 1920) / 2)` |
| `boundright` | `390` | Formula |
| `boundhigh` | `-497` | Formula: `-(1577 - 1080)` |
| `boundlow` | `0` | Convention |
| `zoffset` | `920` | Derived (≈ 0.85 × 1080, between CF3GRAVE's 0.825 ratio and a slightly more conservative position) |
| `tension` | `300` | Section 3 scaling rule |
| `floortension` | `600` | Section 3 scaling rule |
| `verticalfollow` | `0.75` | Section 3 scaling rule |
| `screenleft` | `90` | Section 3 scaling rule |
| `screenright` | `90` | Section 3 scaling rule |

**Inferred fields:** every field. There is no real reference stage to anchor against.

**Validation note:** Replace with empirical values the moment a clean 1920×1080 third-party stage surfaces. The values above are mathematically consistent but not validated in-engine.

**Derivation:**
```
boundleft  = -((imageWidth  - localcoordWidth)  / 2)  = -((2700 - 1920) / 2) = -390
boundright =  ((imageWidth  - localcoordWidth)  / 2)  =  ((2700 - 1920) / 2) =  390
boundhigh  = -(imageHeight - localcoordHeight)        = -(1577 - 1080)       = -497
```

---

## Section 3 — Camera Scaling by Resolution

The conventional MUGEN 1.0 camera defaults — `tension = 60`, `floortension = 90`, `verticalfollow = 0.2` — were tuned for a 320×240 viewport. They produce sluggish, wrong-feeling camera behavior at hi-res.

### Why scaling is necessary

`tension` is the horizontal distance (in `localcoord` units) a character can be from the screen edge before the camera starts moving to follow them. On a 320-wide viewport, `tension = 60` means the camera kicks in when a character is within 60 units (≈19%) of the edge. On a 1280-wide viewport, the same `tension = 60` is only ≈4.7% of the screen — the camera reacts only when the character is right at the edge, which feels laggy.

`floortension` is the analogous vertical distance from the floor before the camera starts rising. Same scaling logic.

`verticalfollow` is a multiplier (0.0–1.0) on how aggressively the camera tracks vertical character motion. Hi-res stages need a larger value because the larger viewport makes any given vertical motion appear smaller.

### Empirical and derived values

| `localcoord` | `tension` | `floortension` | `verticalfollow` | Source |
|---|---|---|---|---|
| 320, 240 | 60 | 90 | 0.2 | Documented MUGEN 1.0 convention |
| 640, 480 | 120 | _omitted (engine default)_ | 1.0 | Empirical — Phantom.of.the.Server cluster (3 stages) |
| 1280, 720 | 200 | 400 | 0.75 | Empirical — `CF3GRAVE` (1280×720 source) |
| 1920, 1080 | 300 | 600 | 0.75 | Formula-derived (linear extrapolation from 1280) |

`tension` scales roughly proportionally with `localcoordWidth` — 60 → 120 → 200 → 300 tracks the 1× / 2× / 4× / 6× width ratios reasonably well.

`floortension` is where the empirical data diverges from a clean scaling story. The 320 row uses MUGEN's 1.0 convention (90); the 1280 row uses CF3GRAVE's `400`; the 640 row's three sources **all omit `floortension`**, leaving the engine default to take over. Treat omission as the empirical choice at 640×480; do not synthesize an interpolated value.

`verticalfollow` does **not** scale linearly. Empirically it goes 0.2 → 1.0 → 0.75, which is non-monotonic. Two readings:

1. The 640 cluster is one author's stylistic preference (Phantom.of.the.Server prefers a camera that fully tracks vertical motion at this resolution) and may not reflect a universal convention.
2. There is no universal convention — 0.2–1.0 is the full valid range and authors pick by feel within it.

When a 640×480 stage by a different author surfaces, re-evaluate. Until then, the template uses `1.0` because that is what the only three available reference stages do.

`screenleft` / `screenright` (the `[Bound]` group margin from screen edges) follows the tension pattern closely. Empirical values:

| `localcoord` | `screenleft / screenright` | Source |
|---|---|---|
| 320, 240 | 25 | `Japan` |
| 640, 480 | 30 | Phantom.of.the.Server cluster (3 stages, all `30`) |
| 1280, 720 | 60 | `CF3GRAVE` |
| 1920, 1080 | 90 | Derived (60 × 1920/1280) |

### Don't apply 320×240 defaults to hi-res stages

If you use `tension = 60` on a 1280×720 stage, the camera will not follow characters until they are nearly at the screen edge. The original Swift app made this mistake. Always pick the row of the table that matches the stage's `localcoord`.

---

## Section 4 — The SFF Axis Rule

Each sprite in an SFF file carries an `(axisX, axisY)` pair. The engine treats this as the *anchor point* of the sprite — when rendering, the sprite is placed such that this anchor sits at the coordinate given by the `[BG ]` element's `start`.

### Screen space: where `start` is measured from

`start` is measured from the **top-left of the viewport**, not from the floor:

```
x = 0                  horizontal centre of the viewport
y = 0                  TOP edge of the viewport, camera at rest
y = localcoordHeight   BOTTOM edge of the viewport, camera at rest
```

So for a sprite `w × h` with axis `(ax, ay)` and `start = sx, sy`:

```
left   = sx - ax        top    = sy - ay
right  = left + w       bottom = top + h
```

> **Correction.** Earlier revisions of this document stated that `start = 0, 0`
> places the axis at `(0, zoffset)`, so a center-bottom axis would put the
> bottom of the image on the floor line. **That is wrong.** `start = 0, 0`
> places the axis on the *top edge of the screen*; with a center-bottom axis
> the whole backdrop ends up above the viewport and characters stand in empty
> space. This was the single largest source of broken output.

Both clean `delta = 1,1` reference stages confirm the top-of-viewport origin — in each, `sy - ay` is the artwork's top edge and `boundhigh` tracks it:

| Stage | axis | `start` | image | `boundhigh` | `sy - ay` |
|---|---|---|---|---|---|
| `Japan` | (312, 483) | `0,240` | 624×483 | −200 | −243 |
| `CF3GRAVE` | (900, 0) | `0,-326` | 1800×1050 | −326 | −326 |

### Center-bottom is the documented standard

```
axisX = imageWidth / 2
axisY = imageHeight
```

The `start` that pairs with it, for a backdrop mounted flush with the bottom of the viewport, is:

```
start = 0, localcoordHeight
```

Note `Japan` ships exactly this: `start = 0,240` against a `localcoord` of 320×240.

### Axis and `start` are a coupled pair

Neither value means anything alone. Changing one without the other translates the artwork by the difference — rewriting `CF3GRAVE`'s axis from `(900, 0)` to `(900, 1050)` while leaving `start = 0,-326` moves the backdrop 1050 units up. Always rewrite them together.

### Other conventions exist in the wild

Phase 2 found four axis patterns in working stages:

| Convention | axisX | axisY | Example |
|---|---|---|---|
| Center-bottom (canonical) | `imageWidth/2` | `imageHeight` | `Japan` |
| Top-anchored | `imageWidth/2` | `0` | `CF3GRAVE`, `apple_campus`, `Utopia` |
| Floor-anchored | `imageWidth/2` | `zoffset` value | `Google_campus` |
| Corner | `0` | `0` | `fog_city_rumble` |

All four produce working stages because **`start` compensates for whatever Y the axis sits at** — not `zoffset`. `zoffset` says where characters' feet go; it has no effect on where the backdrop is drawn. Of 48 stages with a readable sprite, only 2 use center-bottom, so the alternates are the norm rather than the exception.

### Stage Studio always writes center-bottom

Never expose axis as a user-configurable value. On import:

1. Read the source axis **and** the source `[BG ] start`.
2. Resolve the artwork's actual edges: `top = start.y - axis.y`, `left = start.x - axis.x`.
3. Rewrite the axis to `(imageWidth/2, imageHeight)`.
4. Recompute `start` so the artwork lands on the *same edges*:
   `start = (left + imageWidth/2, top + imageHeight)`.

Step 4 is not optional. Rewriting the axis alone translates the backdrop by the difference between the two axis values, which for a 1050-tall image is 1050 units.

The output is always center-bottom regardless of the input convention.

### Validator behavior — top-anchored is a warning, not an error

When the validator encounters a top-anchored stage:

```
[WARN] Sprite axis uses top-anchored convention
  Was:  axis = (900, 0)  on a 1800×1050 image
  Note: This works in IKEMEN GO because zoffset positions characters relative
        to the camera, not the axis. The center-bottom convention (900, 1050)
        is the documented standard and what Stage Studio generates.
        Your stage is functional as-is; the warning is informational.
```

Do **not** flag top-anchored stages as broken. Do **not** auto-rewrite without user consent — the user might be using the source for a different purpose.

### What goes wrong when axisX is wrong

If `axisX ≠ imageWidth / 2`, the background drifts horizontally as the camera scrolls. The drift is proportional to the offset:

```
visible_drift_per_unit_camera_scroll = (axisX - imageWidth/2) / (imageWidth/2)
```

A 10-pixel offset on a 1800-wide image produces ≈1% drift — visible to a careful eye. A 100-pixel offset is severely visible. This is the most common defect in stages produced by buggy authoring tools (the original Swift app had this bug).

---

## Section 5 — Parallax Stages and the `delta` Parameter

Each `[BG ]` element has a `delta = dx, dy` parameter that controls how fast the layer scrolls relative to the camera.

| `delta` value | Behavior |
|---|---|
| `1, 1` (or omitted; this is the default) | True 1:1 parallax — layer moves with the camera at full speed. Floor and background plates that should appear "attached" to the world. |
| `< 1` (e.g. `0.5, 0.5`) | Slow parallax — layer moves slower than the camera, appearing to recede into the distance. Distant skylines, mountains. |
| `> 1` | Fast parallax — layer moves faster than the camera, appearing to be in front of the action. Foreground elements. |

### The bounds formula applies only to `delta = 1, 1` layers

```
boundleft = -((imageWidth - localcoordWidth) / 2)
```

This formula sets the camera's leftward limit to the point where the *1:1 layer's* left edge reaches the screen's left edge. For a slower layer (`delta < 1`), the same camera scroll moves the layer less, so the layer doesn't reach the screen edge — the formula is *conservative* for slow-parallax layers (more headroom than required).

### `parallax_only` classification

A stage is `parallax_only` if **none of its `[BG ]` elements has `delta = 1, 1`** (or an omitted delta, which defaults to 1,1). Phase 2 examples:

- `stage0-720` (Elecbyte): main BG `delta = .75, .75` — parallax-only, but bounds within formula → soft tier.
- `Grand_Cathedral` (Alice): every layer `delta < 0.5` — parallax-only, bounds far exceed formula → broken under the formula but possibly fine in-engine because no layer actually reaches the camera edges.

### Validator behavior

| Bounds match formula? | Any `delta = 1, 1` layer? | Verdict |
|---|---|---|
| Yes | Yes | **Clean** |
| Yes | No (parallax-only) | **Clean** with parallax-only note |
| No, within formula | Yes | **Degraded** — author chose tighter scroll than image allows; safe |
| No, within formula | No (parallax-only) | **Clean** with parallax-only note |
| No, exceeds formula | Yes | **Broken** — camera scrolls past image edge → visible black gap. Auto-fix candidate. |
| No, exceeds formula | No (parallax-only) | **Warn only** — formula does not strictly apply; bounds are author-chosen. Do **not** auto-fix; surface the discrepancy and explain. |

The auto-fix is only safe when at least one layer is true 1:1 parallax. For pure-parallax stages, "wrong" bounds may be intentional and the validator must defer to the author.

---

## Section 6 — Multi-Layer Stage Handling

A stage's `[BGdef]` section can be followed by any number of `[BG ]` (or `[BG name]`) elements, each rendering one layer. Real-world stages routinely have 5–30+ layers: floor tiles, sky, mid-distance buildings, foreground decorations, animated effects.

### The first `[BG ]` is rarely the canonical backdrop

Authors order BG elements by render priority (back-to-front). The first element is whatever sits furthest behind in the visual stack — often a tiled floor or a small repeating texture, not the main backdrop.

Phase 2 examples:

- **`CF3GRAVE`** — first `[BG image]` element references `spriteno = 1, 0` which happens to be 1800×1050 (the main sky). All five `[BG ]` elements share that 1800×1050 dimension because they're variants of the same backdrop with different effects.
- **`Grand_Cathedral`** — first `[BG 1]` element is `spriteno = 21, 1` with `tile = 1, 1` (a tiled stone floor, 1000×1000). The actual backdrop is `[BG back]` at `spriteno = 1, 4` (1523×1392). A naive "first element" parser would think the stage's backdrop is 1000×1000 — wildly wrong.

### Largest-area heuristic

The reliable rule for identifying the canonical backdrop:

1. Enumerate every `[BG ]` element (sections starting with `bg`, excluding `[BGdef]` and any `[BGCtrlDef]`).
2. For each, parse `spriteno = group, item` and look up the sprite in the SFF.
3. Compute `width × height` (pixel area) for each.
4. **Pick the element with the largest pixel area** as the canonical backdrop.

This is what `parse_stage.py` does (search for `largest-area BG element` in that file).

### Tie-breaker: prefer `delta = 1, 1`

If multiple layers have similar area, prefer the one whose `delta` is `1, 1` (or omitted). That layer is the bounds-formula reference. `parse_stage.py` records `delta_is_1_1` for each candidate to support this.

### When the heuristic fails

The heuristic can pick the wrong layer in two cases:

1. **Tiled large layer**: a tiled floor with `tile = 1, 1` and `tilespacing = 0, 0` may be a small sprite (e.g. 256×128) intended to be repeated to fill the screen. If it happens to be the largest sprite in the stage's SFF, it gets picked. **Detection:** if `tile != 0, 0` and the sprite is smaller than `localcoord` in either dimension, it's a tile pattern, not a backdrop. Skip it and pick the next largest non-tiled layer.
2. **Foreground filler**: a long horizontal strip (e.g. 2695×164 dust effect) might have larger width than the actual backdrop but be a foreground overlay. **Detection:** extreme aspect ratios (width:height > 5:1 or < 1:5) likely indicate strips, not backdrops.

The current `parse_stage.py` does *not* implement these refinements — it picks pure largest-area. For the validator, add the tile/aspect filters. For Stage Studio's import flow, the user is choosing a single image so these issues don't arise.

---

## Section 7 — Image Conformance Rules

> **Revised.** The rules below ask "does this image match the template's
> required dimensions, and can we crop or pad it into shape?" That is the
> wrong question for the workflow this tool serves. A backdrop generated by an
> image model comes out at 1536×1024 or 1792×1024 and will never match a
> hand-picked 1800×1050; forcing it to meant cropping away the user's artwork
> or rejecting it outright.
>
> The rule is now: **any image that covers the viewport is accepted at
> whatever size it is, and the camera values are derived from that size.** A
> larger backdrop is never a problem — it simply buys more scroll. Only an
> image too small to fill the viewport is rejected, and the app reports the
> exact minimum it needs:
>
> ```
> minWidth  = ceil(localcoordWidth  / zoomout)
> minHeight = ceil(localcoordHeight / zoomout)
> ```
>
> An image short of that is scaled up uniformly, up to 2×, with a warning.
> Non-uniform scale is still never applied. The "safe / unsafe transforms"
> table below remains accurate on transform quality; the per-template
> conformance windows that follow it are superseded.

Stage Studio accepts user-supplied background images and conforms them to the chosen template. The conformance rules below preserve image quality and ensure the resulting stage is correct.

### Safe transforms

| Transform | When safe | What it does |
|---|---|---|
| **Center-crop** | Source aspect matches target's, but source is larger | Trim equal pixels from both horizontal edges (or both vertical edges) until target dimensions are reached |
| **Extend-with-fill** | Source is within ~10% of target dimensions in both axes | Add solid-color or blurred-edge padding to reach target dimensions; preserves the artwork untouched |
| **Uniform downscale (≥ 50%)** | Source is significantly larger than target and aspect ratio matches | Bilinear or Lanczos downscale; preserves quality if the user provides hi-res source |

### Unsafe transforms

| Transform | Why never | What goes wrong |
|---|---|---|
| **Non-uniform scale (stretch)** | Distorts artwork | Characters appear correctly proportioned but the background is squashed/elongated; obvious to any viewer |
| **Uniform upscale > 110%** | Quality loss | Pixel art shows interpolation artifacts; photographic art shows blur |
| **Skew, rotate, perspective** | Not part of MUGEN's render model | Output won't match preview |

### Per-template conformance windows

For each template, define a "minimum viable" source size (smaller than this, ask the user to choose a different image) and a "comfortable" range (auto-conform without warning).

| Template | Min viable (W × H) | Comfortable range (W × H) | Recommended target |
|---|---|---|---|
| `320×240 Classic` | 480 × 240 | 560–700 × 240–540 | 624 × 483 |
| `640×480 MUGEN 1.0` | 960 × 480 | 1100–1400 × 480–540 | 1280 × 480 |
| `1280×720 IKEMEN GO Standard` | 1640 × 720 | 1700–1900 × 1000–1100 | 1800 × 1050 |
| `1920×1080 IKEMEN GO 1080p` | 2440 × 1080 | 2560–2880 × 1500–1700 | 2700 × 1577 |

If the source is below the minimum viable size, the only safe option is to choose a different image. Don't upscale; present a clear error.

### What the user never sees

- The axis is set programmatically. Never a user-facing field.
- The bounds are derived from the conformed image dimensions. Never a user-facing field.
- The `boundhigh` is computed from image height. Never a user-facing field.

The only image-related decisions the user makes are: **which image** and **how to handle the aspect mismatch** (crop vs extend).

---

## Section 7b — Stage Zoom

Zoom was absent from every earlier revision of this document, from the Phase 1
parser, and from the template constants. The Phase 2 dataset contains five
Zoom / NoZoom stage pairs — `Jjjsoffice_11zoom`, `Warrior'sPeak_1.1Zoom`,
`BalanceOfTheMultiverse_1.1Zoom`, `smurfs_village_1.1zoom` and their
counterparts — and the analysis discarded the one field that distinguishes
them. That omission is why zoom-enabled stages appeared to "scroll past the
background edge" for no visible reason.

### The parameters

```
[Camera]
zoomin    = 1.2     ; largest scale the camera may reach (>= 1)
zoomout   = 0.75    ; smallest scale the camera may reach (<= 1)
startzoom = 1       ; scale at round start
```

### Why zoom invalidates every bound

`zoomout` is a divisor on the viewport. At `zoomout = 0.75` the camera shows
`1 / 0.75 = 1.333x` the normal area, so the *effective* viewport is wider and
taller than `localcoord`:

```
visibleWidth  = localcoordWidth  / zoomout
visibleHeight = localcoordHeight / zoomout
```

Every bound is computed against the visible size, not the nominal one:

```
boundright = (imageWidth - localcoordWidth / zoomout) / 2
```

The difference is not marginal. For an 1800x1050 backdrop in a 1280x720
viewport:

| `zoomout` | visible width | `boundright` |
|---|---|---|
| 1.0 (off) | 1280 | 260 |
| 0.9 | 1422 | 189 |
| 0.75 | 1707 | 46 |
| 0.6 | 2133 | 0 — the backdrop cannot even fill the frame |

A stage that hardcodes `boundright = 260` and then enables `zoomout = 0.75`
lets the camera travel 214 units past the edge of its own artwork.

### Minimum backdrop for a zoom-enabled stage

```
minWidth  = ceil(localcoordWidth  / zoomout)
minHeight = ceil(localcoordHeight / zoomout)
```

At 1280x720 with `zoomout = 0.75` that is 1707x960 just to *fill the frame* at
full zoom-out, before any scroll room. This is the number to give someone
prompting an image generator.

### The bottom edge

Zooming out grows the viewport in both directions. A backdrop mounted flush
with the bottom of the screen (`start = 0, localcoordHeight`) has no slack
below the floor, so pulling back exposes its lower edge. A zoom-enabled stage
wants artwork that continues below the floor line. Stage Studio warns about
this rather than silently shifting the mount, because moving the backdrop down
also moves the floor and the ground would no longer line up with the art.

### Rule

Never write a `zoomout` value without re-deriving the bounds that depend on
it. Stage Studio omits the `[Camera] zoomin` / `zoomout` lines entirely when
zoom is disabled, precisely so nobody can add one by hand without going back
through the derivation.

---

## Section 8 — Validator Quick-Reference

This section is a standalone reference card. A future Claude session implementing the Phase 5 validator can act on it without reading Sections 1–7 (though the rationale lives there).

### 8.1 Three validation tiers

| Tier | Meaning | UI label |
|---|---|---|
| **Clean** | Stage passes all formula checks; no anomalies | Green badge |
| **Degraded** | Stage works but uses a non-canonical convention or bounds tighter than the image allows | Yellow badge |
| **Broken** | Stage has a likely-visible defect at runtime | Red badge |

### 8.2 Issue → tier mapping

| Issue | Tier | Auto-fix? |
|---|---|---|
| Sprite axis is center-bottom `(w/2, h)` | Clean | — |
| Sprite axis is top-anchored `(w/2, 0)` | Degraded | No (warn only — Section 4) |
| Sprite axis is floor-anchored `(w/2, zoffset)` | Degraded | No (warn only) |
| Sprite axis at `(0, 0)` or other corner | Degraded | No (warn only) |
| Sprite axisX off-center by any amount (e.g. `(641, 720)` on a 1280-wide image) | Broken | **Yes** — set `axisX = imageWidth / 2` |
| `boundleft`/`boundright` exactly match formula | Clean | — |
| `boundleft`/`boundright` within formula but not exact (tighter scroll) | Degraded | No (creator's choice) |
| `boundleft`/`boundright` exceed formula AND a `delta = 1, 1` layer exists | Broken | **Yes** — recompute from formula |
| `boundleft`/`boundright` exceed formula AND no `delta = 1, 1` layer | Degraded | No (parallax-only — warn only, Section 5) |
| `boundleft` positive or `boundright` negative (inverted signs) | Broken | **Yes** — recompute from formula |
| `boundhigh` exceeds formula (more negative than `-(imageHeight − localcoordHeight)`) | Broken | **Yes** — recompute from formula |
| `boundhigh` shallower than formula (less negative or zero) | Clean | — (creator's choice) |
| `localcoord` declared explicitly | Clean | — |
| `localcoord` omitted | Clean (treated as `320, 240`) | Optional — add explicit declaration |
| `hires = 1` flag without `localcoord` | Degraded | Optional — replace with `localcoord = 640, 480` |
| `zoffset` value | Always Clean (subjective) | No — warn only if symptoms suggest off |
| Missing optional camera params (`tension`, `verticalfollow`) | Clean (engine has defaults) | Optional — add scaled defaults from Section 3 |
| Missing `floortension` at `localcoord` 320×240 or 640×480 | Clean | None — this is valid community practice. The Phantom.of.the.Server 640×480 cluster routinely omits it; the engine default is appropriate at these sizes |
| Missing `floortension` at `localcoord` 1280×720 | Informational | Note absence in the report; do not fix. At hi-res, explicit `floortension` is meaningful — but absence is still a valid creator choice |
| Missing `floortension` at `localcoord` 1920×1080 | Warn | Recommend adding an explicit value (≈600, per Section 3). At 1080p, characters spend more time near the floor camera boundary and the engine default produces a sluggish-feeling camera |
| SFF v1 format | Clean | Optional — offer v2.01 upgrade with explicit user opt-in |
| SFF unparseable / corrupt | Broken | No — surface the parse error |
| First `[BG ]` element has tiny sprite (`tile = 1, 1`, smaller than localcoord) — main backdrop is a different element | Clean (this is normal) | — (parser must use largest-area heuristic, Section 6) |

### 8.3 Auto-fix safe list

Apply without explicit user confirmation (but always show the diff):

1. **Sprite axis** — set to `(imageWidth / 2, imageHeight)`. Center-bottom is canonical.
2. **`boundleft` / `boundright`** — recompute from formula when the source value exceeds formula and at least one layer is `delta = 1, 1`.
3. **`boundhigh`** — recompute from formula when the source value exceeds formula (more negative than allowed).
4. **Missing optional camera params** — add scaled defaults from Section 3 based on `localcoord`.
5. **Inverted bound signs** — flip to canonical signs and recompute magnitude from formula.

### 8.4 Warn-only list

Surface in the UI but never modify without explicit user opt-in:

1. **`zoffset`** — "correct" value is artistic; symptom (floating/sinking characters) hints but doesn't determine the fix.
2. **Parallax-only stages** — bounds may legitimately diverge from formula.
3. **Top-anchored or other non-canonical axis** — works in IKEMEN GO; rewriting requires recomputing `start` for every BG element.
4. **SFF v1 → v2.01 format upgrade** — potentially lossy if the source uses palette tricks.
5. **Multi-layer interactions** — when changing one layer's bounds affects how other layers register, defer to the author.
6. **Bounds tighter than formula (within-formula)** — author chose less scroll than max; not a bug.

### 8.5 The "show your work" requirement

Every fix must emit a diff with the formula or rule used. Example:

```
[FIXED] Sprite axis
  Was:  (641, 718)
  Now:  (640, 720)
  Why:  Axis must be at horizontal center (width ÷ 2) and bottom edge
        (height) of the image. Off-center axis causes background drift.
        Formula: axis = (imageWidth / 2, imageHeight) = (1280 / 2, 720) = (640, 720)

[FIXED] Camera bounds
  Was:  boundleft = -700, boundright = 700
  Now:  boundleft = -640, boundright = 640
  Why:  Source bounds exceeded the formula maximum. Camera would scroll
        past the image edge (visible black gap or repeated edge).
        Formula: ±(imageWidth − localcoordWidth) ÷ 2 = ±(2560 − 1280) ÷ 2 = ±640

[WARN] Sprite axis convention is top-anchored
  Found: (640, 0) on a 1280×720 image
  Note:  This works in IKEMEN GO because zoffset positions characters
         relative to the camera. Center-bottom (640, 720) is the documented
         standard. Stage Studio generates center-bottom; if you re-import
         this stage in Stage Studio, the axis will be rewritten and BG
         start coordinates will be adjusted to compensate.
  Action: Acknowledged. No change applied — your stage is functional as-is.

[CLEAN] zoffset = 660
  No change. Value is in the normal range for a 1280×720 stage
  (typical: 0.7 × localcoordHeight to 0.9 × localcoordHeight, i.e. 504–648).
```

Every action — `[FIXED]`, `[WARN]`, `[CLEAN]` — has a one-line `Why:` or `Note:` explaining the rule. No silent changes. No black-box judgments.

---

## Appendix A — Phase 2 Source Stages

For traceability. Every value in this skill that is marked **empirical** comes from one of these stages.

| Stage | Author | localcoord | Image | Notes |
|---|---|---|---|---|
| `Japan` | (unknown) | 320, 240 | 624 × 483 | Only strict-tier source — axis matches center-bottom |
| `GenbuTempleNight` | Phantom.of.the.Server | 640, 480 | 1280 × 279 | Soft tier — part of 640×480 empirical cluster |
| `HaHaciendaIsland` | Phantom.of.the.Server | 640, 480 | 1280 × 853 | Soft tier — part of 640×480 empirical cluster |
| `KeepersImmortalDreams` | Iced & Phantom.of.the.Server | 640, 480 | 1280 × 1280 | Soft tier — part of 640×480 empirical cluster |
| `SamuraiPalace` | (unknown) | 640, 480 (via `hires = 1`) | 2047 × 2498 | Soft tier — outlier vertical-hi-res image; superseded by Phantom cluster |
| `CF3GRAVE` | JoeStar | 1280, 720 | 1800 × 1050 | Bounds-match tier — axis is top-anchored |
| `stage0-720` | Elecbyte | 1280, 720 | 3200 × 1072 | Soft tier, parallax-only — secondary cross-check for 1280×720 |

Excluded from canonical pool:

- Authors `MUGEN Stage Studio` (4 stages) and `David Phillips` (1 stage) — self-authored, would encode our own assumptions.
- 18 stages with bounds exceeding formula or unparseable SFF/DEF — see `template-candidates.md` Section 1d.

## Appendix B — Confidence Summary

| Template | Confidence | Inferred fields (not in source data) |
|---|---|---|
| T1 — `320×240 Classic` | Empirical | `tension=60`, `floortension=90`, `verticalfollow=0.2` (Japan's source values 60/75/1.0 are atypical; convention preferred) |
| T2 — `640×480 MUGEN 1.0` | Empirical (single-author cluster) | sprite axis (rewritten from non-canonical source values to canonical center-bottom); recommended image height (sources vary 279–1280; template defaults to localcoord height) |
| T3_STANDARD — `1280×720 IKEMEN GO Standard` | Empirical | sprite axis (rewritten from source's top-anchored to canonical center-bottom) |
| T3_WIDE — `1280×720 IKEMEN GO Wide` | Empirical (parallax-only source) | sprite axis (rewritten from source's non-canonical position); `boundhigh` (formula-derived because source's parallax-only value exceeds formula) |
| T4 — `1920×1080 IKEMEN GO 1080p` | **Formula-derived** | every field |

Re-validate T4 the moment a clean third-party 1920×1080 reference stage surfaces. T2 was promoted from formula-derived to empirical when three Phantom.of.the.Server stages (`GenbuTempleNight`, `HaHaciendaIsland`, `KeepersImmortalDreams`) entered the dataset with identical camera configs; consider revisiting `verticalfollow` and `floortension` if a 640×480 stage by a different author surfaces, since the cluster is one author's reproducible voice rather than three independent voices.
