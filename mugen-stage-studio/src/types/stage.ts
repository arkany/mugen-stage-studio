// TypeScript mirror of the Rust structs in src-tauri/src/templates.rs and
// src-tauri/src/stage_config.rs. The Rust side serializes with camelCase
// for struct fields and tag-discriminated PascalCase variants for enums.

export type TemplateConfidence = "Empirical" | "FormulaDerived";

export interface StageTemplate {
  id: string;
  displayName: string;
  confidence: TemplateConfidence;
  localcoordW: number;
  localcoordH: number;
  bgWidth: number;
  bgHeight: number;
  axisX: number;
  axisY: number;
  boundLeft: number;
  boundRight: number;
  boundHigh: number;
  boundLow: number;
  zoffset: number;
  tension: number;
  floorTension: number | null;
  verticalFollow: number;
  screenLeft: number;
  screenRight: number;
  sourceStage: string;
  sourceAuthor: string;
}

export type ConformanceState =
  | { type: "NoImage" }
  | { type: "Correct" }
  | { type: "FixableWithCrop"; cropX: number; cropY: number }
  | { type: "FixableWithExtend"; padX: number; padY: number }
  | { type: "TooSmall" };

export interface StageConfig {
  name: string;
  author: string;
  music: string | null;
  templateId: string;
  bgImagePath: string | null;
  bgImageWidth: number | null;
  bgImageHeight: number | null;
  conformanceState: ConformanceState;
}

export type Screen = "pick" | "import" | "preview";
