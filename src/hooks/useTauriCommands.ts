// Typed wrappers around the Tauri `invoke` calls. Keeps every component
// out of direct contact with the Tauri API surface and gives us a single
// place to evolve the IPC contract.

import { invoke } from "@tauri-apps/api/core";
import type { StageConfig, StageTemplate } from "../types/stage";

const browserPreviewTemplates: StageTemplate[] = [
  {
    id: "T1",
    displayName: "320×240 Classic (WinMUGEN / lo-res)",
    confidence: "Empirical",
    localcoordW: 320,
    localcoordH: 240,
    bgWidth: 624,
    bgHeight: 483,
    axisX: 312,
    axisY: 483,
    boundLeft: -152,
    boundRight: 152,
    boundHigh: -243,
    boundLow: 0,
    zoffset: 217,
    tension: 60,
    floorTension: 90,
    verticalFollow: 0.2,
    screenLeft: 25,
    screenRight: 25,
    sourceStage: "Japan",
    sourceAuthor: "unknown",
  },
  {
    id: "T2",
    displayName: "640×480 MUGEN 1.0 hi-res",
    confidence: "Empirical",
    localcoordW: 640,
    localcoordH: 480,
    bgWidth: 1280,
    bgHeight: 480,
    axisX: 640,
    axisY: 480,
    boundLeft: -320,
    boundRight: 320,
    boundHigh: 0,
    boundLow: 0,
    zoffset: 432,
    tension: 120,
    floorTension: null,
    verticalFollow: 1,
    screenLeft: 30,
    screenRight: 30,
    sourceStage: "GenbuTempleNight",
    sourceAuthor: "Phantom.of.the.Server",
  },
  {
    id: "T3_STANDARD",
    displayName: "1280×720 IKEMEN GO Standard",
    confidence: "Empirical",
    localcoordW: 1280,
    localcoordH: 720,
    bgWidth: 1800,
    bgHeight: 1050,
    axisX: 900,
    axisY: 1050,
    boundLeft: -260,
    boundRight: 260,
    boundHigh: -330,
    boundLow: 0,
    zoffset: 594,
    tension: 200,
    floorTension: 400,
    verticalFollow: 0.75,
    screenLeft: 60,
    screenRight: 60,
    sourceStage: "CF3GRAVE",
    sourceAuthor: "JoeStar",
  },
  {
    id: "T3_WIDE",
    displayName: "1280×720 IKEMEN GO Wide",
    confidence: "Empirical",
    localcoordW: 1280,
    localcoordH: 720,
    bgWidth: 3200,
    bgHeight: 1072,
    axisX: 1600,
    axisY: 1072,
    boundLeft: -960,
    boundRight: 960,
    boundHigh: -352,
    boundLow: 0,
    zoffset: 660,
    tension: 200,
    floorTension: 200,
    verticalFollow: 0.85,
    screenLeft: 60,
    screenRight: 60,
    sourceStage: "stage0-720",
    sourceAuthor: "Elecbyte",
  },
  {
    id: "T4",
    displayName: "1920×1080 IKEMEN GO 1080p",
    confidence: "FormulaDerived",
    localcoordW: 1920,
    localcoordH: 1080,
    bgWidth: 2700,
    bgHeight: 1577,
    axisX: 1350,
    axisY: 1577,
    boundLeft: -390,
    boundRight: 390,
    boundHigh: -497,
    boundLow: 0,
    zoffset: 920,
    tension: 300,
    floorTension: 600,
    verticalFollow: 0.75,
    screenLeft: 90,
    screenRight: 90,
    sourceStage: "(formula-derived)",
    sourceAuthor: "(none — no source at this resolution)",
  },
];

function isMissingTauriRuntime(error: unknown): boolean {
  return String(error).includes("invoke");
}

function browserPreviewConfig(imagePath: string, templateId: string): StageConfig {
  return {
    name: "",
    author: "",
    music: null,
    templateId,
    bgImagePath: imagePath,
    bgImageWidth: null,
    bgImageHeight: null,
    conformanceState: { type: "NoImage" },
  };
}

export function getTemplates(): Promise<StageTemplate[]> {
  return invoke<StageTemplate[]>("get_templates").catch((error) => {
    if (import.meta.env.DEV && isMissingTauriRuntime(error)) {
      return browserPreviewTemplates;
    }
    throw error;
  });
}

export function loadImage(
  imagePath: string,
  templateId: string,
): Promise<StageConfig> {
  return invoke<StageConfig>("load_image", { imagePath, templateId }).catch((error) => {
    if (import.meta.env.DEV && isMissingTauriRuntime(error)) {
      return browserPreviewConfig(imagePath, templateId);
    }
    throw error;
  });
}

export function exportStage(config: StageConfig): Promise<string> {
  return invoke<string>("export_stage", { config });
}
