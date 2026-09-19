// Step 2: pick a backdrop, see whether it works, and choose the camera zoom.
//
// Any image that covers the screen is accepted at whatever size it is; the
// backend reads the real file and derives every camera value from it.

import { AlertTriangle, CheckCircle2, CircleDashed, ImagePlus, X, XCircle } from "lucide-react";
import type { DerivedStage, ImportFit, StageTemplate } from "../types/stage";
import { describeImport, toneText, type Tone } from "../lib/conformance";
import { shortcutLabel } from "../lib/platform";
import { dims, minImageSize, templateCopy } from "../lib/templateMeta";
import { SectionHeading } from "./SectionHeading";

export interface LoadedImage {
  path: string;
  url: string;
  name: string;
  width: number;
  height: number;
}

interface Props {
  template: StageTemplate;
  image: LoadedImage | null;
  fit: ImportFit | null;
  derived: DerivedStage | null;
  error: string | null;
  zoomoutOverride: number | null;
  onZoomChange: (zoomout: number | null) => void;
  onBrowse: () => void;
  onRemove: () => void;
  /** The highest resolution the image is big enough for, offered when it's too small. */
  suggestion: StageTemplate | null;
  onUseSuggestion: (id: string) => void;
}

const TONE_ICON: Record<Tone, typeof CheckCircle2> = {
  neutral: CircleDashed,
  good: CheckCircle2,
  warn: AlertTriangle,
  bad: XCircle,
};

const ZOOM_CHOICES = [
  { value: null, label: "No zoom" },
  { value: 0.9, label: "Slight zoom-out" },
  { value: 0.75, label: "Moderate zoom-out" },
  { value: 0.6, label: "Big zoom-out" },
];

export function ImageImport({
  template,
  image,
  fit,
  derived,
  error,
  zoomoutOverride,
  onZoomChange,
  onBrowse,
  onRemove,
  suggestion,
  onUseSuggestion,
}: Props) {
  const status = describeImport(fit, derived, image);
  const StatusIcon = TONE_ICON[status.tone];
  const min = minImageSize(template, zoomoutOverride);

  return (
    <section aria-labelledby="step-2-title">
      <SectionHeading
        step={2}
        id="step-2-title"
        title="Drop your background"
        subtitle={`Drag an image onto the window, or browse. At least ${dims(min.w, min.h)}; ${dims(template.recommendedBgWidth, template.recommendedBgHeight)} or larger is ideal.`}
      />

      {!image ? (
        <button
          type="button"
          onClick={onBrowse}
          className="group flex w-full items-center gap-4 rounded-lg border-2 border-dashed border-line-strong bg-sunken p-4 text-left transition-colors hover:border-p2 hover:bg-p2-soft"
        >
          <span className="grid size-12 shrink-0 place-items-center rounded-full bg-raised text-muted transition-colors group-hover:text-p2">
            <ImagePlus size={22} />
          </span>
          <span className="min-w-0">
            <span className="block text-[14px] font-bold">Drop an image here</span>
            <span className="block text-[12px] text-muted">PNG, JPG, or WEBP</span>
            <span className="mt-2 inline-flex items-center gap-2 rounded-md border border-line-strong bg-surface px-2.5 py-1 text-[12px] font-semibold">
              Choose image…
              <kbd className="font-mono text-[11px] text-muted">{shortcutLabel("O")}</kbd>
            </span>
          </span>
        </button>
      ) : (
        <div className="overflow-hidden rounded-lg border border-line bg-raised">
          <div className="flex items-center gap-3 p-2.5">
            <img src={image.url} alt="" className="h-10 w-16 shrink-0 rounded-[3px] object-cover" />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-semibold" title={image.path}>
                {image.name}
              </div>
              <div className="truncate font-mono text-[12px] text-muted">{dims(image.width, image.height)}</div>
            </div>
            <button
              type="button"
              onClick={onBrowse}
              className="rounded-md px-2 py-1 text-[12px] font-semibold text-p2 hover:bg-p2-soft"
            >
              Replace
            </button>
            <button
              type="button"
              onClick={onRemove}
              aria-label="Remove image"
              className="grid size-7 place-items-center rounded-md text-muted hover:bg-bad-soft hover:text-bad"
            >
              <X size={16} />
            </button>
          </div>

          <div role="status" className="flex items-start gap-2.5 border-t border-line px-3 py-2.5">
            <StatusIcon size={18} className={"mt-px shrink-0 " + toneText[status.tone]} />
            <div className="min-w-0 text-[13px]">
              <div className={"font-bold " + toneText[status.tone]}>{status.title}</div>
              <div className="text-muted">{status.detail}</div>
              {status.warnings.length > 0 && (
                <ul className="mt-1.5 list-disc space-y-1 pl-4 text-muted">
                  {status.warnings.map((w) => (
                    <li key={w}>{w}</li>
                  ))}
                </ul>
              )}
              {fit?.type === "TooSmall" && suggestion && suggestion.id !== template.id && (
                <div className="mt-2">
                  <button
                    type="button"
                    onClick={() => onUseSuggestion(suggestion.id)}
                    className="rounded-md border border-line-strong bg-surface px-2.5 py-1 text-[12px] font-semibold hover:border-p2"
                  >
                    Use {templateCopy(suggestion).name} ({dims(suggestion.localcoordW, suggestion.localcoordH)}) instead
                  </button>
                  <p className="mt-1 text-[12px] text-muted">
                    A lower resolution looks chunkier in game, but this image will fill it.
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {image && fit?.type === "Usable" && (
        <label className="mt-3 block">
          <span className="mb-1 block text-[12px] font-semibold text-muted">Camera zoom</span>
          <select
            value={zoomoutOverride ?? ""}
            onChange={(e) => onZoomChange(e.target.value === "" ? null : Number(e.target.value))}
            className="w-full rounded-md border border-line-strong bg-sunken px-3 py-2 text-[14px] text-ink outline-none focus:border-p2 focus:ring-2 focus:ring-p2-soft"
          >
            {ZOOM_CHOICES.map((c) => (
              <option key={c.label} value={c.value ?? ""}>
                {c.label}
              </option>
            ))}
          </select>
          <span className="mt-1 block text-[12px] text-muted">
            Zooming out shows more of the stage during fights, so it needs a bigger image.
          </span>
        </label>
      )}

      {error && (
        <p role="alert" className="mt-2 rounded-md bg-bad-soft p-2.5 text-[13px] text-bad">
          {error}
        </p>
      )}
    </section>
  );
}
