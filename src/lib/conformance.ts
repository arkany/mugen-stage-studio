// Plain-language presentation of the backend's import check and warnings.
// The facts all come from `ImportFit` and `DerivedStage`; this only words them.

import type { DerivedStage, ImportFit } from "../types/stage";

export type Tone = "neutral" | "good" | "warn" | "bad";

export interface StatusCopy {
  tone: Tone;
  title: string;
  detail: string;
  /** Backend warnings to list under the status, already in plain words. */
  warnings: string[];
}

export function describeImport(
  fit: ImportFit | null,
  derived: DerivedStage | null,
  image: { width: number; height: number } | null,
): StatusCopy {
  if (!fit || fit.type === "NoImage") {
    return {
      tone: "neutral",
      title: "No image yet",
      detail: "Add a background image to get started.",
      warnings: [],
    };
  }
  if (fit.type === "TooSmall") {
    const yours = image ? ` Yours is ${image.width} × ${image.height}.` : "";
    return {
      tone: "bad",
      title: "Too small!",
      detail: `This resolution needs an image at least ${fit.minWidth} × ${fit.minHeight} to fill the screen.${yours}`,
      warnings: [],
    };
  }
  if (!derived) {
    return { tone: "neutral", title: "Measuring…", detail: "Working out the camera.", warnings: [] };
  }
  const warnings = derived.warnings.map((w) => w.message);
  if (warnings.length === 0) {
    return {
      tone: "good",
      title: "Looks great!",
      detail: "Drag the floor line in the preview so the fighters stand on the ground.",
      warnings,
    };
  }
  return {
    tone: "warn",
    title: "Almost there!",
    detail: "It'll work. A few things are worth a look:",
    warnings,
  };
}

export const toneText: Record<Tone, string> = {
  neutral: "text-muted",
  good: "text-good",
  warn: "text-warn",
  bad: "text-bad",
};
