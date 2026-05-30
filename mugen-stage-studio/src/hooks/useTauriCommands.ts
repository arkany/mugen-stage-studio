// Typed wrappers around the Tauri `invoke` calls. Keeps every component
// out of direct contact with the Tauri API surface and gives us a single
// place to evolve the IPC contract.

import { invoke } from "@tauri-apps/api/core";
import type { StageConfig, StageTemplate } from "../types/stage";

export function getTemplates(): Promise<StageTemplate[]> {
  return invoke<StageTemplate[]>("get_templates");
}

export function loadImage(
  imagePath: string,
  templateId: string,
): Promise<StageConfig> {
  return invoke<StageConfig>("load_image", { imagePath, templateId });
}

export function exportStage(config: StageConfig): Promise<string> {
  return invoke<string>("export_stage", { config });
}
