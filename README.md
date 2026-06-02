# MUGEN Stage Studio

Cross-platform desktop app for creating MUGEN / IKEMEN GO stages with
mathematically correct parameters. Replaces the broken Swift/macOS app
with a Tauri 2 + Rust + React 19 stack so Windows, macOS, and Linux all
ship from one codebase.

> **Phase 4a scaffold** — this is the architectural skeleton. SFF binary
> generation, DEF serialization, image conformance, and the preview canvas
> are stubs until Phase 4b. See [`rebuild-plan.md`](./rebuild-plan.md) for
> the full phase plan.

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

## What's in this scaffold

| Path | Contents |
|---|---|
| [`src-tauri/src/templates.rs`](./src-tauri/src/templates.rs) | 5 `StageTemplate` constants (T1, T2, T3_STANDARD, T3_WIDE, T4) populated from `mugen-stage-skill.md` Section 2 |
| [`src-tauri/src/commands.rs`](./src-tauri/src/commands.rs) | 3 Tauri commands: `get_templates`, `load_image`, `export_stage` (last two are typed stubs for Phase 4b) |
| [`src-tauri/src/stage_config.rs`](./src-tauri/src/stage_config.rs) | `StageConfig` + `ConformanceState` shared structs |
| [`src-tauri/src/image_check.rs`](./src-tauri/src/image_check.rs) | Conformance API surface — stub returning `NoImage` until Phase 4b |
| [`src/types/stage.ts`](./src/types/stage.ts) | TypeScript mirror of the Rust structs |
| [`src/components/`](./src/components/) | Three React step screens |

## What's deliberately absent (Phase 4b scope)

- SFF v2.01 binary generation
- DEF file serialization
- Real image dimension reading, crop, extend
- 240×100 thumbnail generation (sprite group 9000, sprite 1)
- Visual preview canvas (localcoord viewport overlaid on background)
- Multi-BG-element editing
- Dialog-plugin file picker (currently uses `<input type="file">`)
