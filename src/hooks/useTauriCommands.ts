// Typed wrappers around the Tauri `invoke` calls.
//
// Every camera value the UI displays comes back through one of these. The
// frontend deliberately has no copy of the geometry — duplicating it is how
// the preview and the exported file drift apart.

import { invoke } from "@tauri-apps/api/core";
import type {
  DerivedStage,
  ExportResult,
  ImportResult,
  StageConfig,
  StageTemplate,
} from "../types/stage";

export function getTemplates(): Promise<StageTemplate[]> {
  return invoke<StageTemplate[]>("get_templates");
}

/** Reads a backdrop off disk and derives everything that follows from it. */
export function loadImage(
  imagePath: string,
  templateId: string,
): Promise<ImportResult> {
  return invoke<ImportResult>("load_image", { imagePath, templateId });
}

/** Re-derive after the floor line moves or the zoom changes. */
export function deriveStage(config: StageConfig): Promise<DerivedStage | null> {
  return invoke<DerivedStage | null>("derive_stage", { config });
}

export function previewDef(config: StageConfig): Promise<string> {
  return invoke<string>("preview_def", { config });
}

export function defaultOutputDir(): Promise<string> {
  return invoke<string>("default_output_dir");
}

/** Writes the .def and .sff. The SFF axis and the DEF start come from one
 *  derivation, so they cannot disagree. */
export function exportStage(
  config: StageConfig,
  outputDir: string,
): Promise<ExportResult> {
  return invoke<ExportResult>("export_stage", { config, outputDir });
}

/** Swap the running app's icon (Dock tile on macOS, window/taskbar elsewhere). */
export function setAppIcon(id: string): Promise<void> {
  return invoke<void>("set_app_icon", { id });
}
