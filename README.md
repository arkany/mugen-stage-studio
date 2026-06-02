# MUGEN Stage Studio

Cross-platform desktop app for creating MUGEN / IKEMEN GO stages with
mathematically correct parameters. Replaces the broken Swift/macOS app
with a Tauri 2 + Rust + React 19 stack so Windows, macOS, and Linux all
ship from one codebase.

> **Phase 4b export pipeline** — the app now reads PNG/JPEG dimensions,
> checks image conformance, writes IKEMEN-loadable DEF/SFF files, and exports
> an importable ZIP package. The first verified target is the T1 320×240
> template using a 624×483 background. See the revised phase plan below for
> the validation gates before expanding to every template.

## Architecture

- **Rust backend** ([`src-tauri/`](./src-tauri/)) — owns format logic, file
  I/O, and the typed `StageTemplate` constants. Templates are compile-time
  constants, not user-configurable values.
- **React frontend** ([`src/`](./src/)) — three step-based screens
  (`TemplatePicker` → `ImageImport` → `PreviewExport`) talking to Rust via
  typed `invoke` wrappers in [`src/hooks/useTauriCommands.ts`](./src/hooks/useTauriCommands.ts).
- **Tailwind v4** for styling via the Vite plugin.

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

### Export fixture test

Use the env-gated fixture test to generate deterministic loose files and a ZIP
without launching the desktop shell:

```bash
MUGEN_STAGE_FIXTURE_IMAGE="/Users/davidphillips/Downloads/MUGEN stages/apple-624x483.jpg" \
MUGEN_STAGE_FIXTURE_OUT="/private/tmp/mugen-stage-studio-apple-fixture" \
(cd src-tauri && cargo test commands::tests::export_fixture_from_env_when_present -- --nocapture)
```

The output directory contains:

- `Apple_Fixture.def`
- `Apple_Fixture.sff`
- `Apple_Fixture.zip`

This is the fastest loop for IKEMEN import testing because the Rust export
path is deterministic and does not require Tauri file dialogs.

## What's implemented

| Path | Contents |
|---|---|
| [`src-tauri/src/templates.rs`](./src-tauri/src/templates.rs) | 5 `StageTemplate` constants (T1, T2, T3_STANDARD, T3_WIDE, T4) populated from `mugen-stage-skill.md` Section 2 |
| [`src-tauri/src/commands.rs`](./src-tauri/src/commands.rs) | Tauri commands for templates, native image selection, and export. Export writes loose DEF/SFF files plus a ZIP package. |
| [`src-tauri/src/stage_config.rs`](./src-tauri/src/stage_config.rs) | `StageConfig` + `ConformanceState` shared structs |
| [`src-tauri/src/image_check.rs`](./src-tauri/src/image_check.rs) | Real image dimension reading and conformance classification (`Correct`, crop, pad, too small). |
| [`src-tauri/src/def_writer.rs`](./src-tauri/src/def_writer.rs) | DEF serialization using template camera values and the known-good T1 BG placement convention (`start = 0, localcoord_h`, `layerno = 0`). |
| [`src-tauri/src/sff_writer.rs`](./src-tauri/src/sff_writer.rs) | SFF v1 writer with 8-bit paletted PCX sprites: main background `0,0` plus stage-select thumbnail `9000,1`, including crop/pad transforms. |
| [`src/types/stage.ts`](./src/types/stage.ts) | TypeScript mirror of the Rust structs |
| [`src/components/`](./src/components/) | Three React step screens |

## Revised phase plan

The original Phase 4b bundled too many independent unknowns: native dialogs,
binary SFF output, DEF semantics, ZIP import behavior, and actual IKEMEN
rendering. Going forward, split the work by validation gate.

### Phase 4a — App skeleton

Complete: Tauri + React shell, typed templates, step flow, and IPC wrappers.

### Phase 4b — Browser/CLI export harness

Build deterministic export fixtures before depending on desktop dialogs:

- Generate DEF/SFF/ZIP from `image_path + template_id`.
- Write artifacts to `/tmp` or another explicit output directory.
- Assert SFF header, PCX header, sprite metadata, DEF blocks, and ZIP contents.
- Keep this as the first debugging tool when IKEMEN behavior is wrong.

### Phase 4c — IKEMEN-compatible T1 export

Complete the first production-grade template before broadening scope:

- Target T1 (`320×240`, background `624×483`).
- Match known-good `Japan.def` conventions where the engine behavior has been
  proven.
- Required IKEMEN checks: image visible, image positioned, floor sane,
  characters visible, and ZIP import works.
- Locked-in generated BG pattern:
  - `spriteno = 0, 0`
  - `start = 0, 240`
  - `delta = 1, 1`
  - `layerno = 0`

### Phase 4d — Export UI integration

After the Rust export path is proven:

- Native Tauri image picker and export directory picker.
- Export loose DEF/SFF files plus ZIP.
- Clear conformance status and export success/error messages.
- Optional dev/debug export button that reuses the fixture path.

### Phase 4e — Templates one at a time

Do not treat every template as production-ready just because the writer works.
Each template needs its own known-good fixture ZIP and IKEMEN screenshot pass:

- T2 (`640×480`)
- T3 standard (`1280×720`)
- T3 wide (`1280×720`)
- T4 (`1920×1080`)

For each template, lock the DEF snapshot and any engine-specific placement
rules before moving to the next one.

### Phase 4p — Compact utility UI (parallel)

This can proceed in parallel with export-format validation because it does not
change the DEF/SFF/ZIP contract.

Redesign the desktop shell as a compact single-window utility instead of a
three-screen studio flow:

- Use one horizontal row of rectangular template cards.
- Show the template name, `localcoord`, required image size, and validation
  status directly on each card.
- Selecting a template expands the image/conformance/export controls below the
  row instead of navigating to a separate full-screen step.
- Keep the normal window small, roughly `640×460` to `720×520`, with dense but
  readable controls.
- Keep the debug panel collapsible so the primary export flow stays compact.
- Consider tray/menu-bar affordances later for quick actions like "new stage",
  recent export folder, or reopen app, but do not make tray behavior the first
  implementation target.

This phase should preserve all existing command APIs and tests. Its success
criteria are faster visual scanning, fewer screen transitions, and no loss of
export/debug information.

### Phase 4f — Preview/debug panel

Add a browser-friendly debug panel showing:

- source and target dimensions
- conformance state
- axis and `start`
- bounds and `zoffset`
- generated DEF preview
- ZIP contents

This should reduce screenshot guessing and make engine failures easier to
triage.

### Phase 4g — Image transform quality

Only after placement and import are reliable:

- crop preview
- pad preview
- edge-color or dominant-color padding instead of black
- palette quality improvements

### Phase 5 — Validator/importer

Build the reverse path:

- Parse existing stage ZIPs.
- Inspect DEF/SFF and detect known bad combinations.
- Flag axis, `start`, `layerno`, bounds, `zoffset`, and image conformance
  issues.
- Offer fixed DEF/SFF/ZIP output.

## What's deliberately absent / still gated

- SFF v2.01 binary generation
- Visual preview canvas (localcoord viewport overlaid on background)
- Multi-BG-element editing
- Production validation for T2/T3/T4 templates
- Reverse import/validator workflow
