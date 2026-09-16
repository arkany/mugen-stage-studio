// TypeScript mirror of the `stage-core` Rust structs.
//
// The frontend never computes a camera value. It edits a StageConfig and asks
// the backend to re-derive, so there is exactly one implementation of the
// geometry and no way for the preview to disagree with the exported file.

export type Screen = "pick" | "import" | "preview";

export type TemplateConfidence = "Empirical" | "FormulaDerived";

export interface StageTemplate {
  id: string;
  displayName: string;
  confidence: TemplateConfidence;

  localcoordW: number;
  localcoordH: number;

  /** Guidance for the image generator, not a requirement. */
  recommendedBgWidth: number;
  recommendedBgHeight: number;
  defaultFloorRatio: number;

  tension: number;
  floorTension: number | null;
  verticalFollow: number;
  screenLeft: number;
  screenRight: number;

  zoomin: number;
  zoomout: number;

  sourceStage: string;
  sourceAuthor: string;
  notes: string;
}

export interface StageConfig {
  name: string;
  author: string;
  music: string | null;
  templateId: string;

  bgImagePath: string | null;
  /** Native pixel size of the imported file, before any scaling. */
  bgImageWidth: number | null;
  bgImageHeight: number | null;

  /** Floor line in pixels down from the top of the native artwork. */
  floorY: number | null;

  zoomoutOverride: number | null;
}

export type ImportFit =
  | { type: "NoImage" }
  | {
      type: "Usable";
      scale: number;
      scaledWidth: number;
      scaledHeight: number;
      upscaled: boolean;
    }
  | {
      type: "TooSmall";
      minWidth: number;
      minHeight: number;
      requiredScale: number;
    };

export type WarningCode =
  | "upscaled"
  | "no-horizontal-scroll"
  | "no-vertical-scroll"
  | "floor-below-viewport"
  | "lifebar-overlap"
  | "zoom-exposes-bottom";

export interface Warning {
  code: WarningCode;
  message: string;
}

export interface Axis {
  x: number;
  y: number;
}

export interface Start {
  x: number;
  y: number;
}

/** Where the artwork's edges land in screen space. */
export interface Placement {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface CameraBounds {
  boundLeft: number;
  boundRight: number;
  boundHigh: number;
  boundLow: number;
}

export interface DerivedStage {
  localcoordW: number;
  localcoordH: number;

  bgWidth: number;
  bgHeight: number;
  scale: number;

  axis: Axis;
  start: Start;
  placement: Placement;

  bounds: CameraBounds;
  zoffset: number;
  floorY: number;

  zoomin: number;
  zoomout: number;

  warnings: Warning[];
}

export interface ImportResult {
  config: StageConfig;
  fit: ImportFit;
  derived: DerivedStage | null;
}
