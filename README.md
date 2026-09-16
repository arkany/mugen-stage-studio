# MUGEN Stage Studio

Cross-platform desktop app for creating MUGEN / IKEMEN GO stages with
mathematically correct parameters. Replaces the broken Swift/macOS app
with a Tauri 2 + Rust + React 19 stack so Windows, macOS, and Linux all
ship from one codebase.

> **Status** — the geometry, templates, image import, preview canvas and DEF
> generation are implemented and tested. SFF binary generation is the
> remaining gap, so export produces parameters but not yet a packaged stage.
> See [`rebuild-plan.md`](./rebuild-plan.md) for the phase plan.

## Architecture

- **`stage-core`** ([`src-tauri/stage-core/`](./src-tauri/stage-core/)) — the
  coordinate model, camera derivations, templates and DEF writer. Pure
  arithmetic with no Tauri and no image decoding, so `cargo test -p
  stage-core` runs the logic that decides whether a stage works without
  needing a GUI toolchain. The web validator will share this crate.
- **Rust backend** ([`src-tauri/src/`](./src-tauri/src/)) — the desktop shell:
  reads image dimensions, forwards to `stage-core`, owns file I/O.
- **React frontend** ([`src/`](./src/)) — three step-based screens
  (`TemplatePicker` → `ImageImport` → `PreviewExport`) talking to Rust via
  typed `invoke` wrappers in [`src/hooks/useTauriCommands.ts`](./src/hooks/useTauriCommands.ts).
  The frontend holds **no** copy of the geometry — it edits a `StageConfig`
  and asks the backend to re-derive, so the preview can never disagree with
  the exported file.
- **Tailwind v4** for styling via the Vite plugin.

## How it works

You pick a target resolution, drop in a background image at whatever size your
image generator produced, and drag the floor line onto the ground in the
artwork. Everything else — `boundleft`/`boundright`, `boundhigh`, `zoffset`,
the sprite axis and the matching `[BG ] start` — is derived from the image's
real dimensions and that floor line. None of them is a template constant,
because none of them is a property of the template.

The preview draws the viewport, the camera's full reach and the lifebar zone
over your artwork, so a backdrop that is mounted wrong or a floor line in the
sky is visible before you export.

## Documentation

Read in this order:

1. [`rebuild-plan.md`](./rebuild-plan.md) — why we're rebuilding, the
   stack choice, and the phase breakdown.
2. [`mugen-stage-skill.md`](./mugen-stage-skill.md) — the full reasoning
   kit: parameter model, all five canonical templates with derivations,
   axis conventions, parallax/`delta` semantics, image conformance windows,
   and validator quick-reference. **Read this before changing any
   template values.**
3. [`template-candidates.md`](./template-candidates.md) — Phase 2 curated
   report of the 50 reference stages and which became canonical sources.
4. [`stage-analysis.json`](./stage-analysis.json) — Phase 2 raw parsed data.
5. [`VALIDATOR-CONCEPT.md`](./VALIDATOR-CONCEPT.md) — sibling Phase 5
   web tool that shares the Rust core library.

## Build & test

From this directory:

```bash
# The logic that decides whether a stage works (32 tests, no GUI deps)
(cd src-tauri && cargo test -p stage-core)

# Backend builds clean
(cd src-tauri && cargo build)

# Frontend type-check
npx tsc --noEmit

# Full production build
npm run build

# Launch the desktop app (opens a WebKit window)
npm run tauri dev
```

The first `tauri dev` run takes 1–3 minutes to compile the debug bundle.
Subsequent runs are fast (Vite HMR + Rust incremental compile).

## What's in this scaffold

| Path | Contents |
|---|---|
| [`src-tauri/stage-core/src/geometry.rs`](./src-tauri/stage-core/src/geometry.rs) | The screen-space coordinate model and every camera derivation. **Read this first.** |
| [`src-tauri/stage-core/src/templates.rs`](./src-tauri/stage-core/src/templates.rs) | 4 `StageTemplate` constants — camera feel only, no geometry |
| [`src-tauri/stage-core/src/stage.rs`](./src-tauri/stage-core/src/stage.rs) | `StageConfig`, `ImportFit`, and the `derive` entry point |
| [`src-tauri/stage-core/src/def.rs`](./src-tauri/stage-core/src/def.rs) | DEF serialization |
| [`src-tauri/src/commands.rs`](./src-tauri/src/commands.rs) | Tauri commands: `get_templates`, `load_image`, `derive_stage`, `preview_def`, `export_stage` |
| [`src-tauri/src/image_check.rs`](./src-tauri/src/image_check.rs) | Header-only image dimension reads |
| [`src/components/StagePreview.tsx`](./src/components/StagePreview.tsx) | The preview canvas and draggable floor line |
| [`src/types/stage.ts`](./src/types/stage.ts) | TypeScript mirror of the Rust structs |
| [`tools/`](./tools/) | Phase 1 parser and the dataset re-validator |

## What's still missing

- **SFF v2.01 binary generation** — the one thing standing between this and a
  complete exported stage. The axis it must write is `DerivedStage::axis`, and
  the `[BG ] start` that pairs with it is `DerivedStage::start`; the two are
  meaningless apart.
- 240×100 thumbnail generation (sprite group 9000, sprite 1)
- Writing the scaled backdrop to disk when an image needed upscaling
- Multi-BG-element / parallax layer editing. `geometry::horizontal_bound_multi`
  already implements the per-layer bound rule the UI would need.
- Dialog-plugin file picker. The import screen works from the browser file
  input today; the exporter will need a real on-disk path.
