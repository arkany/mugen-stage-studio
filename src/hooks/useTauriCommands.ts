// Typed wrappers around the Tauri `invoke` calls.
//
// Every camera value the UI displays comes back through one of these. The
// frontend deliberately has no copy of the geometry — duplicating it is how
// the preview and the exported file drift apart.

import { invoke } from "@tauri-apps/api/core";
import type {
  DerivedStage,
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

export function exportStage(config: StageConfig): Promise<string> {
  return invoke<string>("export_stage", { config });
}
