// Friendly, plain-language presentation for the Rust templates. The numbers
// always come from the backend; this file only adds names and copy.

import type { StageTemplate } from "../types/stage";

interface TemplateCopy {
  name: string;
  tagline: string;
  blurb: string;
}

const COPY: Record<string, TemplateCopy> = {
  T1: {
    name: "Classic",
    tagline: "WinMUGEN / lo-res",
    blurb: "Old-school 4:3 pixel look. Works in WinMUGEN and every newer engine.",
  },
  T2: {
    name: "MUGEN 1.0 HD",
    tagline: "MUGEN 1.0 / 1.1",
    blurb: "Sharper 4:3 stages for MUGEN 1.0 and 1.1 hi-res screenpacks.",
  },
  T3: {
    name: "IKEMEN GO",
    tagline: "Widescreen HD",
    blurb: "IKEMEN GO's default widescreen size. A good balance of detail and speed.",
  },
  T4: {
    name: "IKEMEN GO 1080p",
    tagline: "Full HD",
    blurb: "Full HD stages for 1080p screenpacks. Needs a large image.",
  },
};

export const RECOMMENDED_TEMPLATE_ID = "T3";

export function templateCopy(t: StageTemplate): TemplateCopy {
  return COPY[t.id] ?? { name: t.displayName, tagline: "", blurb: "" };
}

export function confidenceLabel(t: StageTemplate): string {
  return t.confidence === "Empirical" ? "Tested" : "Calculated";
}

export function confidenceHelp(t: StageTemplate): string {
  return t.confidence === "Empirical"
    ? "Camera feel copied from real, working stages at this resolution."
    : "No reference stage exists at this resolution, so the camera feel is calculated from the others.";
}

function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b);
}

export function aspectRatio(w: number, h: number): string {
  const d = gcd(w, h);
  return `${w / d} : ${h / d}`;
}

export function dims(w: number, h: number): string {
  return `${w} × ${h}`;
}

/** Smallest image that covers the screen at this template's zoom (mirrors image_check). */
export function minImageSize(t: StageTemplate, zoomoutOverride: number | null = null) {
  const zoomout = zoomoutOverride ?? t.zoomout;
  return { w: Math.ceil(t.localcoordW / zoomout), h: Math.ceil(t.localcoordH / zoomout) };
}
