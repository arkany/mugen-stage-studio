# MUGEN Stage Validator — Concept & Architecture

## What This Is

A free, browser-based tool for validating and auto-fixing MUGEN and IKEMEN GO
stage files. Companion to MUGEN Stage Studio, but a separate surface targeting
a different use case: repairing existing stages rather than creating new ones.

Target users:
- **Stage makers** getting bug reports ("characters float in your stage") with
  no idea why
- **Screenpack / full game builders** normalizing stages from 50+ authors so
  characters stand at consistent heights across all stages
- **Anyone** who downloaded a stage that looks subtly wrong and wants to know
  why

---

## Core Principle: Local-Only Processing

No files are ever uploaded to a server. Ever.

Processing happens entirely in the user's browser via WebAssembly. The user
drops files onto the page, the WASM module reads them from memory, validation
and fixing runs client-side, and corrected files are offered as downloads via
blob URLs. The server handles only static asset delivery.

This is the honest, privacy-respecting approach for a community of creators
who are sharing their own work. It also eliminates hosting costs for
processing, scales to any traffic volume, and removes any legal ambiguity
around storing game assets.

---

## WASM + Tauri Shared Architecture

The parser and fixer logic is written once in Rust and compiled to two targets:

```
src/core/ (Rust — format logic, validation, fixing)
    │
    ├── compiled to WASM
    │       └── website/pkg/          → runs in browser
    │
    └── compiled as native library
            └── Tauri app backend     → runs on desktop
```

When a bug is fixed or a new edge case is handled in the core library, both
the website and the desktop app benefit automatically. They share the same
source of truth for all SFF/DEF parsing and generation logic.

### Build targets

```toml
# Cargo.toml
[lib]
crate-type = ["cdylib", "rlib"]  # cdylib for WASM, rlib for Tauri

[features]
wasm = ["wasm-bindgen"]
```

```bash
# Build for website
wasm-pack build --target web --features wasm

# Build for Tauri
cargo build --release  # standard native compile
```

---

## What Gets Measured (Analytics)

Analytics are anonymous, aggregate, and privacy-respecting. No filenames,
no file contents, no IP addresses stored. Use **Plausible** or self-hosted
**Umami** — both support custom events without cookies or GDPR overhead.

### Event schema

| Event | Properties |
|---|---|
| `tool_loaded` | — |
| `file_dropped` | `sff_version: 1\|2`, `file_count: int` |
| `validation_complete` | `issues_found: int`, `issue_types: string[]`, `stage_is_clean: bool` |
| `fix_applied` | `fix_types: string[]` |
| `file_downloaded` | `format: "def"\|"sff"\|"zip"`, `was_batch: bool` |

### What this tells us

- How many people use the tool (sessions + `tool_loaded`)
- Whether the community is mostly on old (v1) or new (v2) SFF files
- Which error types are most common in the wild — feeds back into Stage Studio
  template decisions and any future Fighter Factory guidance
- Whether people follow through to download after seeing results (engagement
  quality signal)

### Public counter (optional)

A visible "X stages validated, Y fixes applied" counter on the page, driven
by the anonymous aggregates. Gives the page life and signals community trust.
No individual data is ever surfaced.

---

## Fix Philosophy

Not all issues are safe to auto-correct. The tool must be transparent about
what it changed and why, and must never silently make a judgment call that
belongs to the creator.

| Issue | Behavior | Rationale |
|---|---|---|
| Axis off by any amount | ✅ Auto-fix | Unambiguous — center-bottom is always correct for single-layer stages |
| `boundleft`/`boundright` don't match image dimensions | ✅ Auto-fix | Pure math from known formula |
| Missing optional DEF params | ✅ Add defaults | All defaults are documented in Elecbyte spec |
| `boundhigh` inconsistent with image height | ✅ Auto-fix | Derived directly from image height − localcoord height |
| `zoffset` appears wrong (characters underground/floating) | ⚠️ Warn only | "Correct" is subjective; depends on artistic intent |
| SFF v1 → v2.01 format upgrade | ⚠️ Optional, explicit | Potentially lossy if palette-dependent art; user must opt in |
| Multi-layer stages with complex BG elements | ⚠️ Warn only | Interactions between layers require human review |

### The diff principle

Every fix shows its work. No black boxes. Example output:

```
[FIXED] Sprite axis
  Was:  (641, 718)
  Now:  (640, 720)
  Why:  Axis must be at horizontal center (width ÷ 2) and bottom edge
        (height) of the image. Off-center axis causes background drift.

[FIXED] Camera bounds
  Was:  boundleft = -630, boundright = 630
  Now:  boundleft = -640, boundright = 640
  Why:  Formula: ±(imageWidth − localcoordWidth) ÷ 2
        ±(2560 − 1280) ÷ 2 = ±640

[CLEAN] zoffset = 400
  No change. Value is within normal range for a 1280×720 stage.
```

---

## Website Features

### Drop zone
Accepts a single stage folder, multiple files, or a zip. Processes
immediately on drop — no submit button. Prioritizes time-to-feedback.

Accepted inputs:
- A `.def` file alone (validates camera params, flags missing SFF reference)
- A `.sff` file alone (validates sprite dimensions and axis)
- A `.def` + `.sff` pair (full validation)
- A zip or folder containing multiple stage pairs (batch mode)

### Result card (per stage)
- Stage name and SFF version detected
- Overall status: **Clean** / **Degraded** (wrong but playable) / **Broken**
  (likely unplayable)
- Expandable list of issues found, each with plain-English explanation
- Diff view of all proposed changes
- Download options: fixed DEF, fixed SFF, or full corrected package as zip

### Batch mode
Drop an entire stages folder. The tool processes all valid pairs, then
offers:
- A zip of all corrected stages
- A summary report (`validation-report.md`) listing every stage, its status,
  and what was changed

This is the primary workflow for screenpack builders normalizing large
collections.

### Inline explainers
Each error type links to a short explainer — what this parameter controls,
what goes wrong when it's off, and a small diagram. Serves both education
and SEO for queries like "MUGEN stage characters floating fix" or "MUGEN
camera scrolls too far."

### "What does this mean?" panel
Persistent sidebar or modal explaining the five interdependent parameters
and how they relate to each other. Useful for stage makers who want to
understand the fix, not just apply it.

---

## Relationship to Stage Studio

| | Validator (website) | Stage Studio (desktop) |
|---|---|---|
| **Use case** | Repair existing stages | Create new stages |
| **User** | Anyone with broken stages | Active stage creators |
| **Input** | Existing .sff + .def files | Background images |
| **Output** | Corrected .sff + .def files | New .sff + .def files |
| **Core logic** | Shared Rust library | Shared Rust library |
| **Platform** | Browser (WASM) | Desktop (Tauri) |

Release the validator first. It has no UI complexity (no canvas, no layer
editor), reaches a broader audience, and generates community goodwill and
real-world stage data before Stage Studio ships.

---

## Community Validation Loop

T4 (1920×1080) has no empirical source stages — it is entirely
formula-derived. Rather than waiting passively for a source stage to
surface, the app can generate its own validation data.

**Proposed feature:** On first export at 1920×1080, show a one-time
opt-in prompt:

> "This template hasn't been validated against real-world gameplay yet.
> Would you like to share your exported stage config (no images, no
> personal data) with the MUGEN Stage Studio project to help validate it?"

If accepted:
- Post the DEF parameter block only (no SFF, no background image) to a
  designated GitHub Discussions thread or a simple POST endpoint
- Tag it with the localcoord, image dimensions, and IKEMEN GO version
- The post is fully anonymous — no username, no file metadata

When enough submissions cluster around consistent values, T4 graduates
from formula-derived to empirical and the skill file is updated.

The same mechanism could be used for any future template resolution where
no reference stage exists at the time of shipping.

**Implementation note:** This is an opt-in, transparent, no-image feature.
It should be framed as contributing to the community, not as telemetry.
The prompt appears once and is never shown again regardless of choice.

---

## Phasing

This is **Phase 5**, after Stage Studio ships.

The Phase 1/2 parser script is the direct ancestor of the validator's core
logic. Once `parse_stage.py` is proven correct against real reference stages,
that logic gets ported to Rust as the shared library that powers both tools.

Prerequisites before starting Phase 5:
- Phase 2 analysis complete (real-world error patterns documented)
- Phase 4 Rust core library exists and is tested
- At least one version of Stage Studio shipped (validator borrows its credibility)
