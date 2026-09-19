// Engine details for modders: every derived camera value in plain words, plus
// the exact .def the backend will write. Slides over the preview.

import { useState } from "react";
import { Check, Copy, X } from "lucide-react";
import type { DerivedStage, StageTemplate } from "../types/stage";
import { confidenceHelp, confidenceLabel, templateCopy } from "../lib/templateMeta";

interface Props {
  template: StageTemplate;
  derived: DerivedStage | null;
  /** The generated .def body, or null until an image is loaded. */
  def: string | null;
  onClose: () => void;
}

type Row = { key: string; value: string; help: string };

function rows(t: StageTemplate, d: DerivedStage | null): Row[] {
  const derivedRows: Row[] = d
    ? [
        { key: "localcoord", value: `${d.localcoordW}, ${d.localcoordH}`, help: "Screen size the stage is authored for." },
        { key: "backdrop", value: `${d.bgWidth} × ${d.bgHeight}`, help: `Background size in screen units (scaled ×${d.scale.toFixed(2)}).` },
        { key: "sprite axis", value: `${d.axis.x}, ${d.axis.y}`, help: "Anchor point of the background image." },
        { key: "BG start", value: `${d.start.x}, ${d.start.y}`, help: "Where that anchor sits, from the top-center of the screen. Always written as a pair with the axis." },
        { key: "boundleft / right", value: `${d.bounds.boundLeft} / ${d.bounds.boundRight}`, help: "How far the camera can scroll left and right." },
        { key: "boundhigh", value: `${d.bounds.boundHigh}`, help: "How far the camera can rise (negative is up)." },
        { key: "zoffset", value: `${d.zoffset}`, help: "Where fighters' feet land, from the top of the screen. Set by the floor line." },
        { key: "zoom in / out", value: `${d.zoomin} / ${d.zoomout}`, help: "Camera zoom limits." },
      ]
    : [];
  return [
    ...derivedRows,
    { key: "tension", value: `${t.tension}`, help: "Distance from the screen edge before the camera starts to scroll." },
    { key: "floortension", value: t.floorTension === null ? "—" : `${t.floorTension}`, help: "Vertical distance before the camera follows a jump. Omitted when blank." },
    { key: "verticalfollow", value: `${t.verticalFollow}`, help: "How strongly the camera follows fighters upward (0–1)." },
    { key: "screenleft / right", value: `${t.screenLeft} / ${t.screenRight}`, help: "Closest a fighter can get to each screen edge." },
  ];
}

export function DetailsDrawer({ template: t, derived, def, onClose }: Props) {
  const [copied, setCopied] = useState(false);
  const list = rows(t, derived);

  const copyDef = async () => {
    if (!def) return;
    try {
      await navigator.clipboard.writeText(def);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // The .def stays selectable below if the clipboard is unavailable.
    }
  };

  return (
    <aside
      aria-label="Engine details"
      onKeyDown={(e) => e.key === "Escape" && onClose()}
      className="absolute inset-y-0 right-0 z-30 flex w-[340px] flex-col border-l border-line bg-surface shadow-[-16px_0_40px_-12px_rgb(0_0_0/0.5)]"
    >
      <div className="flex items-center gap-2 border-b border-line px-4 py-3">
        <div className="min-w-0 flex-1">
          <h2 className="text-[15px] font-bold">Engine details</h2>
          <p className="truncate text-[12px] text-muted">
            {templateCopy(t).name} · {confidenceLabel(t)}
          </p>
        </div>
        <button
          type="button"
          onClick={copyDef}
          disabled={!def}
          className="flex items-center gap-1.5 rounded-md border border-line-strong px-2 py-1 text-[12px] font-semibold hover:bg-raised disabled:opacity-40"
        >
          {copied ? <Check size={14} /> : <Copy size={14} />}
          {copied ? "Copied" : "Copy .def"}
        </button>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close details"
          className="grid size-7 place-items-center rounded-md text-muted hover:bg-raised hover:text-ink"
        >
          <X size={16} />
        </button>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-2">
        <p className="border-b border-line/60 pt-1 pb-3 text-[12px] text-muted">
          {templateCopy(t).blurb} {confidenceHelp(t)} Camera feel from{" "}
          <span className="font-semibold text-ink">{t.sourceStage}</span>
          {t.sourceAuthor && !t.sourceAuthor.startsWith("(") ? ` by ${t.sourceAuthor}` : ""}.
        </p>

        {!derived && (
          <p className="border-b border-line/60 py-3 text-[12px] text-muted">
            Bounds, start and zoffset are worked out from your image. Add one to see them.
          </p>
        )}

        <dl>
          {list.map((r) => (
            <div key={r.key} className="border-b border-line/60 py-2 last:border-0">
              <div className="flex items-baseline justify-between gap-3">
                <dt className="font-mono text-[12px] text-muted">{r.key}</dt>
                <dd className="font-mono text-[13px] font-semibold select-text">{r.value}</dd>
              </div>
              <p className="mt-0.5 text-[12px] text-muted">{r.help}</p>
            </div>
          ))}
        </dl>

        {def && (
          <details className="my-3">
            <summary className="cursor-pointer text-[13px] font-semibold">Generated .def</summary>
            <pre className="mt-2 max-h-80 overflow-auto rounded-md bg-sunken p-3 font-mono text-[11px] leading-relaxed select-text">
              {def}
            </pre>
          </details>
        )}
      </div>
    </aside>
  );
}
