import type { StageConfig } from "../types/stage";

export function emptyConfig(templateId: string): StageConfig {
  return {
    name: "",
    author: "",
    music: null,
    templateId,
    bgImagePath: null,
    bgImageWidth: null,
    bgImageHeight: null,
    floorY: null,
    zoomoutOverride: null,
  };
}
