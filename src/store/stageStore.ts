// Phase 4a uses simple useState in App.tsx as the spec mandates.
// This file documents the contract — what state the app needs — without
// introducing a state library. Phase 4b may upgrade to Zustand if shape
// growth warrants it.

import type { Screen, StageConfig, StageTemplate } from "../types/stage";

export interface AppState {
  screen: Screen;
  templates: StageTemplate[];
  selectedTemplateId: string | null;
  config: StageConfig | null;
}

export const initialState: AppState = {
  screen: "pick",
  templates: [],
  selectedTemplateId: null,
  config: null,
};

export function emptyConfig(templateId: string): StageConfig {
  return {
    name: "",
    author: "",
    music: null,
    templateId,
    bgImagePath: null,
    bgImageWidth: null,
    bgImageHeight: null,
    conformanceState: { type: "NoImage" },
  };
}
