# MUGEN Stage Studio — Rebuild Plan

## Why We're Rebuilding

The original Swift/macOS implementation produced broken stages: characters
floated, got cut off, or the camera scrolled past the background edge. The
root cause was not a UI bug — it was a fundamentally incorrect model of how
MUGEN stages work.

MUGEN stage creation is not open-ended configuration. It requires five
interdependent values that must all be mathematically consistent with each
other and with the background image dimensions:

| Parameter | Role |
|---|---|
| `localcoord` | The coordinate space ruler everything else is measured in |
| `boundleft` / `boundright` | How far the camera scrolls horizontally — `±(imageWidth - localcoordWidth / zoomout) / 2` |
| `boundhigh` | How far the camera may rise — the artwork's top edge in screen space |
| `zoffset` | Where the floor sits in coordinate space — characters stand here |
| **Sprite axis (in SFF)** | Stage Studio always writes `(imageWidth / 2, imageHeight)` — center-bottom |
| **`[BG ] start`** | Where that axis is placed. **Coupled to the axis; neither means anything alone.** |

If any one of these is wrong, the stage breaks.

> **Correction to the original plan.** The plan named the sprite axis as "the
> silent killer" and prescribed rewriting it to center-bottom always. That is
> half a rule. The axis is only an anchor *point*; `[BG ] start` says where
> that anchor goes, measured from the top of the viewport. Rewriting the axis
> without recomputing `start` translates the backdrop by the difference — for
> a 1050-tall image, 1050 units — which puts the artwork above the screen and
> leaves characters standing in empty space. That is the actual cause of the
> floating and cut-off backgrounds. With a center-bottom axis the matching
> value is `start = 0, localcoordHeight`, not `0, 0`.
>
> Two further corrections: `zoomout` is a divisor on the viewport and shrinks
> every bound, so bounds derived without it let the camera scroll past the
> artwork the moment the stage zooms out; and `zoffset` cannot be a template
> constant, because it depends on where the horizon happens to sit in the
> artwork.

The correct approach is to offer a small set of **canonical templates** that
fix the coordinate space and the camera *feel*, and to **derive** every
geometric value — bounds, `zoffset`, axis and `start` — from the image the
user actually supplies. Hardcoding those values only ever works for the one
reference image they were copied from.

---

## Why Tauri + Rust + React

- **Cross-platform**: The MUGEN/IKEMEN GO creator community is overwhelmingly
  Windows. A macOS-only tool reaches almost no one. Tauri 2.x gives us
  Windows, macOS, and Linux from one codebase.
- **Rust backend**: SFF is a binary format. Rust's `struct` parsing, byte
  manipulation, and correctness guarantees make it the right tool. The
  backend also owns image resize/crop and all file I/O.
- **React frontend**: Larger Tauri community support, more reference
  implementations for tool-style apps, no constraints imposed by prior
  framework choices.
- **Clean separation**: Format logic never leaks into the UI layer.
  Templates are Rust constants — not user-configurable values.

The Phase 1 Python parser is a reference implementation and validation tool.
Once templates are confirmed from real data, the same logic is ported to
Rust for the app backend.

---

## Phases

### Phase 1 — SFF + DEF Parser Script

Write a Python script that accepts a path to a stage directory and extracts
ground-truth parameters from both the SFF and DEF files.

**SFF parsing** (supports v1 and v2/v2.01):
- From sprite group 0, sprite 0: image width, height, axisX, axisY
- Flag whether axis is correct (axisX == width/2 and axisY == height)

**DEF parsing**:
- All camera values: `boundleft`, `boundright`, `boundhigh`, `boundlow`,
  `tension`, `floortension`, `verticalfollow`
- Stage info: `localcoord`, `zoffset`
- Bound group: `screenleft`, `screenright`
- First BG element: `start`, `delta`, `tile`, `tilespacing`

**Derived validation**:
- Compute expected bounds from formula and compare to actual
- Flag any mismatch as a broken stage

**Output**: Per-stage JSON + markdown summary table to stdout.
Write all results to `stage-analysis.json`.

---

### Phase 2 — Analyze Reference Stages

Run the Phase 1 script against all stages at:

```
/Users/davidphillips/Sites/macmame/Ikemen-GO/stages
```

Walk all subdirectories. For each with a matching `.sff` + `.def` pair,
parse and collect results.

From the full output:
- Discard broken stages (axis wrong, bounds don't match formula)
- Group valid stages by `localcoord`
- Select the best representative per group (axis correct + bounds match)
- Document which stages were selected and why

These become the **canonical template sources** for Phase 4.

---

### Phase 3 — Generate MUGEN Stage Skill

Write `mugen-stage-skill.md` encoding the following for future Claude
sessions working on the app:

1. **Complete parameter model** — what each value controls, formula
   relationships, and what breaks when they are wrong
2. **Canonical templates** — one entry per localcoord group, populated with
   real values from Phase 2 reference stages
3. **SFF axis rule** — center-bottom is always correct; document what
   happens in-engine when it is wrong
4. **Diagnosis guide** — symptom → likely wrong parameter → correction
5. **Image conformance rules** — acceptable dimensions per template,
   safe transforms (center-crop, extend-with-fill) vs. unsafe (stretch)

---

### Phase 4 — New App (Tauri 2 + Rust + React)

Scaffold and build the cross-platform replacement app.

**Rust backend responsibilities:**
- SFF v2.01 read/write (PNG-compressed sprites, correct axis encoding)
- DEF read/write from a typed `StageConfig` struct
- Image resize and crop (center-crop and extend-with-fill only — no stretch)
- 240×100 thumbnail generation (sprite group 9000, sprite 1)
- All file I/O and export packaging

**React frontend responsibilities:**
- Template selection (5 cards, one per canonical template)
- Image import with conformance check and correction flow
- Visual preview canvas: localcoord viewport overlaid on full background
- Export trigger and progress UI
- Layer list (multi-BG-element support, future scope)

**Key constraints:**
- Templates are Rust constants — not runtime-configurable by users
- Sprite axis is always set programmatically to `(imageWidth / 2, imageHeight)`
- No stretch/non-uniform scale is ever applied to imported images

**Deliverables:**
1. Scaffolded Tauri 2 project with correct directory structure
2. Rust `StageTemplate` constants populated from Phase 2 data
3. Tauri command bindings: `load_image`, `apply_template`, `export_stage`
4. React frontend with template picker and import flow stubbed out
5. README with architecture decisions and traceability to Phase 2 sources

---

## Sequencing Note

Phases 1 and 2 must complete before Phase 3 or 4 begin. The skill file
and the app's template constants both depend on what Phase 2 actually finds
in the real stage data. Do not hardcode template values before that analysis
is done.
