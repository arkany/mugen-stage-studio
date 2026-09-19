# Design Prompt — MUGEN Stage Studio UI

## Context

MUGEN Stage Studio is a Tauri 2 + React 19 + TypeScript + Tailwind v4 desktop app (Rust backend) that turns a single background image into a working MUGEN / IKEMEN GO stage (`.def` + `.sff`) with mathematically correct parameters. It ships on **macOS and Windows** (Linux as a bonus) from one codebase.

The current UI (`src/App.tsx`, `src/components/TemplatePicker.tsx`, `ImageImport.tsx`, `PreviewExport.tsx`) is a functional "compact utility" pass: a warm beige palette, three stacked cards, and a lot of raw engine jargon (`localcoord`, `zoffset`, `boundhigh`, `tension`) shown up front. Your job is to **redesign the frontend** so the app feels **fun**, genuinely useful, and easy for anyone — including someone making their first stage — while still giving experienced modders the numbers they want.

**Design goal in one sentence:** Pick a game resolution, drop in an image, see exactly how it will look in a fight, and export a stage that just works — in under a minute, with no MUGEN knowledge required, and with the energy of a fighting-game select screen.

**Tone:** fun first, but never at the expense of clarity. The personality lives in color, type, motion, sound-free feedback and copy — the flow itself stays dead simple. Think "arcade character select meets a well-made creative tool," not a spreadsheet and not a cluttered game launcher.

---

## Who uses this

1. **First-timers** — have a cool image and want it as a stage. Don't know what `localcoord` means and shouldn't have to.
2. **Hobbyist modders** — know MUGEN vs IKEMEN GO, want to trust the numbers, and want to see them when asked.
3. **Both are on Mac or Windows** — the app must feel native-ish on both, never like a Mac app awkwardly running on Windows or vice versa.

---

## Hard constraints (do not break)

- **Do not modify** anything in `src-tauri/src/templates.rs` — template values are compile-time constants derived in `mugen-stage-skill.md`.
- Keep the Tauri command contract in `src/hooks/useTauriCommands.ts` and the types in `src/types/stage.ts`. UI work only; if a new command is truly needed, propose it rather than inventing it.
- Keep Tailwind v4 (Vite plugin, no config file). Define design tokens as CSS variables in `src/App.css` (`@theme` block) instead of scattering hex values like `#f5f2eb` through components.
- No new heavy UI frameworks. Small, justified dependencies only (e.g. an icon set like `lucide-react` is fine).
- Must build clean: `npx tsc --noEmit` and `npm run build`.

---

## Information architecture

Keep it **one window, one flow, three steps**, with everything visible at a glance rather than hidden behind "Next" buttons:

```
┌───────────────────────────────────────────────────────────────┐
│  Toolbar: app name · step indicator (1 Resolution · 2 Image ·  │
│           3 Export) · Details toggle                          │
├───────────────┬───────────────────────────────────────────────┤
│ Left rail     │  Main stage preview (the hero)                │
│  1. Resolution│   - background image scaled into the template │
│     (5 cards) │   - camera/viewport frame, floor line,        │
│  2. Image     │     axis marker, two fighter silhouettes      │
│     drop zone │   - crop / pad overlay when needed            │
│     + status  │                                               │
│  3. Name,     │                                               │
│     author,   │                                               │
│     Export    │                                               │
└───────────────┴───────────────────────────────────────────────┘
```

- **Left rail** (~340px) holds the controls top-to-bottom in step order. **Main area** is a large live preview — this is the thing that makes the app feel useful and trustworthy.
- Before an image is loaded, the preview shows the empty template frame (viewport rectangle, floor, fighter silhouettes on a neutral checkerboard) with a big friendly drop target: "Drop an image here".
- The whole window is a drop target for images, not just the input.
- Minimum window size ~960×640; raise `tauri.conf.json` default from 800×600 to around 1200×780. At narrow widths the rail stacks above the preview.

---

## Step-by-step UX

### 1. Resolution (template picker)
- Show the five templates as select-screen tiles (see Visual direction) with **plain-language labels first**, specs second:
  - "Classic" — 320×240 · WinMUGEN / lo-res
  - "MUGEN 1.0 HD" — 640×480
  - "IKEMEN GO" — 1280×720 (mark as **Recommended** default)
  - "IKEMEN GO Wide" — 1280×720, extra-wide scrolling
  - "IKEMEN GO 1080p" — 1920×1080
- Each card shows a tiny aspect-ratio thumbnail shape and the ideal image size ("Best with a 1800×1050 image").
- `Empirical` vs `FormulaDerived` confidence becomes a subtle badge: "Tested" vs "Calculated", with a tooltip explaining the difference. Not a loud colored pill.
- Source stage / author go into the Details panel, not the card face.

### 2. Image
- Drop zone + "Choose image…" button (use the native file dialog via `@tauri-apps/plugin-dialog` if available; otherwise note the dependency). Show filename, pixel size, and a thumbnail once loaded.
- Translate `ConformanceState` into human status with a clear icon, color, and **a one-click action**:
  | State | Message | Action |
  |---|---|---|
  | `NoImage` | "Add a background image to get started" | Choose image |
  | `Correct` | "Perfect fit — ready to export" | — |
  | `FixableWithCrop` | "A bit too big — we'll trim N×M px" | Preview crop / adjust position |
  | `FixableWithExtend` | "A bit small — we'll extend the edges by N×M px" | Preview extend |
  | `TooSmall` | "This image is too small for this resolution. Try a larger image or a lower resolution." | Suggest the best-fitting template |
- If the image fits a *different* template better, suggest it: "This image is a great match for IKEMEN GO Wide — switch?"
- The preview shows the crop/extend region as an overlay so the user sees exactly what changes.

### 3. Export
- Fields: Stage name (required, with a sensible default from the filename), Author (remembered between sessions via `localStorage`), optional Music.
- Primary button: **Export Stage…** — disabled with a clear reason until requirements are met ("Add an image first").
- On success: a confirmation with the output folder, file list (`.def`, `.sff`), and a **Show in Finder** / **Show in Explorer** button (label depends on OS). Include a short "How to add it to your game" hint (copy folder into `stages/`, add to `select.def`).
- On error: plain-language message first, technical detail in an expandable section, with a "Copy details" button.

### Details panel ("Show details" toggle)
- A collapsible right-hand or bottom drawer for modders showing every template parameter: localcoord, axis, bounds (left/right/high/low), zoffset, tension, floor tension, vertical follow, screen edges, source stage/author.
- Monospace values, each with a one-line explanation on hover. Copy-to-clipboard for the full block.
- Off by default; remember the setting.

---

## Visual direction — make it fun

The app should feel like it belongs to the fighting-game world it serves. Borrow the language of arcade select screens, versus splashes and round announcers — then apply it with restraint so it stays easy to use.

- **Mood:** bold, punchy, playful, confident. Dark-leaning by default with a light mode that keeps the same energy (not a washed-out afterthought). Both follow `prefers-color-scheme`.
- **Color:** a deep ink/navy base with **two** high-energy accents (e.g. hot red/orange for "Player 1" primary actions and electric cyan/blue for "Player 2" secondary highlights), plus a gold for success/"Perfect". Define all as tokens in `App.css`: bg, surface, surface-raised, border, text, text-muted, accent-p1, accent-p2, success/perfect, warning, danger, focus ring. Drop the current beige/brown palette.
- **Typography:**
  - Display font for headings, step numbers, and status callouts — something chunky and game-like but legible (e.g. a condensed bold/italic from Google Fonts such as "Bebas Neue", "Anton", or "Russo One"; bundle it locally so it works offline). Use it sparingly.
  - Body/UI: system font stack — `-apple-system, BlinkMacSystemFont, "Segoe UI Variable", "Segoe UI", system-ui, sans-serif` — so controls still read as native on Mac and Windows.
  - Numbers: `ui-monospace, "SF Mono", "Cascadia Mono", Consolas, monospace`.
- **Template picker as a character select:** the five resolutions are big selectable tiles in a grid/row with a bold selection frame (angled corners or a thick P1-colored border), a hover lift, and the tile's name in the display font. Keyboard arrows move the "cursor" like a select screen. "IKEMEN GO" carries a **Recommended** tag.
- **Shape & texture:** slightly angled/slanted accents (skewed section headers, diagonal stripes on the preview background or step badges), chunky 2px selection borders, soft glows on the active element. Keep content cards simple so the decoration doesn't compete with the image.
- **Preview as the stage:** the preview shows the image framed like a match — two fighter silhouettes (P1 left, P2 right), floor line, HUD-style corners (thin life-bar shapes at the top are a nice touch), and the camera frame. Optionally a "Pan" toggle that slides the camera across the stage bounds so users see the scroll range in action.
- **Status callouts with personality:**
  - `Correct` → a big "PERFECT!" stamp animation.
  - `FixableWithCrop` / `FixableWithExtend` → "Almost there!" with the fix shown on the preview.
  - `TooSmall` → friendly "Too small!" with a suggested fix, never scolding.
  - Export success → a short "STAGE READY!" / "K.O."-style celebration, then the practical info (files, Show in Finder/Explorer, how to install).
- **Motion:** snappy and satisfying — quick scale/flash on selection (~120–200ms), a stamp/slam on status changes, subtle idle motion on fighter silhouettes is optional. All of it disabled or reduced under `prefers-reduced-motion`. Nothing loops distractingly while the user is working.
- **Copy voice:** short, upbeat, a little playful ("Pick your arena", "Drop your background", "Name your stage", "Ready? Export!"). Headings can have flavor; helper text, errors, and buttons stay plain and specific.
- **Icons:** one consistent line icon set (e.g. Lucide) at 16px in controls; the flair comes from type and color, not from mixed icon styles.
- **Guardrail:** if a decorative element ever makes something harder to read, click, or understand, cut it. Fun is the wrapper; usability is the product.

---

## Cross-platform (Mac + Windows) requirements

- Detect the platform (Tauri `@tauri-apps/plugin-os` or `navigator.userAgent` fallback) and adapt small details:
  - Keyboard shortcuts show `⌘` on Mac, `Ctrl` on Windows: Open image (`⌘O`/`Ctrl+O`), Export (`⌘E`/`Ctrl+E`), Toggle details (`⌘I`/`Ctrl+I`).
  - "Show in Finder" vs "Show in Explorer".
  - Button order in any dialog: primary on the right on Mac; follow Windows convention (primary left of Cancel) on Windows — or avoid modal dialogs entirely where possible.
- Don't fake OS window chrome (no drawn traffic lights). Keep the native title bar unless a custom one is done properly on both OSes.
- Works at 100%, 125%, 150% Windows display scaling and on Retina — no blurry 1px borders, no clipped text.
- Paths display correctly with either `/` or `\`.

---

## Usability & accessibility

- Every interactive element is keyboard reachable with a visible focus ring; template cards behave as a radio group (arrow keys).
- Color is never the only signal — status uses icon + text + color.
- WCAG AA contrast in both themes.
- Playful headings are fine, but labels, buttons, and errors stay plain. Jargon appears only in the Details panel or tooltips.
- Remove developer-facing copy from the UI ("Phase 4a stub", "Output contract", "DEF/SFF generation remains behind the existing Tauri export command", "Compact utility"). If a feature is still stubbed, show a neutral "Coming soon" state instead.
- Empty, loading, success, and error states designed for every section.

---

## Deliverables

1. Redesigned `App.tsx` layout (rail + preview + details drawer) and restyled `TemplatePicker`, `ImageImport`, `PreviewExport`.
2. New `StagePreview` component: renders the template viewport, floor line, axis marker, fighter silhouettes, and crop/extend overlay from template + config data (canvas or SVG — your call, justify it).
3. Design tokens, bundled display font, and dark/light themes in `src/App.css`.
4. Small platform helper (`src/lib/platform.ts`) for shortcut labels and Finder/Explorer wording.
5. Updated `tauri.conf.json` window size/min size.
6. A short summary of design decisions and anything left for Phase 4b wiring.

## Acceptance criteria

- A first-time user can go from launch → exported stage without reading docs or seeing an unexplained term.
- The preview makes it obvious what the stage will look like and what the app will crop or extend.
- Feels fun and distinctive — someone should smile the first time they hit "PERFECT!" — while looking at home on both macOS and Windows, in both dark and light mode.
- `npx tsc --noEmit` and `npm run build` pass; `npm run tauri dev` launches and every state (no image, correct, crop, extend, too small, export success, export error) is reachable or mockable for review.
