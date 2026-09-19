import { useEffect, useRef, useState } from "react";
import { getTemplates } from "../hooks/useTauriCommands";
import type { StageTemplate } from "../types/stage";
import {
  RECOMMENDED_TEMPLATE_ID,
  confidenceHelp,
  confidenceLabel,
  dims,
  templateCopy,
} from "../lib/templateMeta";
import { SectionHeading } from "./SectionHeading";

interface Props {
  templates: StageTemplate[];
  setTemplates: (t: StageTemplate[]) => void;
  selectedTemplateId: string | null;
  setSelectedTemplateId: (id: string) => void;
  /** Object URL of the loaded background, used to preview each crop shape. */
  imageUrl: string | null;
}

export function TemplatePicker({
  templates,
  setTemplates,
  selectedTemplateId,
  setSelectedTemplateId,
  imageUrl,
}: Props) {
  const [loadError, setLoadError] = useState<string | null>(null);
  const buttonRefs = useRef<(HTMLButtonElement | null)[]>([]);

  useEffect(() => {
    if (templates.length > 0) return;
    getTemplates()
      .then(setTemplates)
      .catch((e) => setLoadError(String(e)));
  }, [templates.length, setTemplates]);

  // Arrow keys move the "cursor" like a character select screen.
  const onKeyDown = (e: React.KeyboardEvent, index: number) => {
    const delta =
      e.key === "ArrowDown" || e.key === "ArrowRight"
        ? 1
        : e.key === "ArrowUp" || e.key === "ArrowLeft"
          ? -1
          : 0;
    if (!delta) return;
    e.preventDefault();
    const next = (index + delta + templates.length) % templates.length;
    setSelectedTemplateId(templates[next].id);
    buttonRefs.current[next]?.focus();
  };

  return (
    <section aria-labelledby="step-1-title">
      <SectionHeading
        step={1}
        id="step-1-title"
        title="Pick your arena"
        subtitle="Choose the game resolution. You can change this later."
      />

      {loadError && (
        <p className="mb-3 rounded-md bg-bad-soft p-3 text-[13px] text-bad">
          Couldn't load resolutions. {loadError}
        </p>
      )}

      <div role="radiogroup" aria-labelledby="step-1-title" className="flex flex-col gap-2">
        {templates.map((t, i) => {
          const selected = t.id === selectedTemplateId;
          const copy = templateCopy(t);
          const recommended = t.id === RECOMMENDED_TEMPLATE_ID;
          return (
            <button
              key={t.id}
              ref={(el) => {
                buttonRefs.current[i] = el;
              }}
              type="button"
              role="radio"
              aria-checked={selected}
              aria-label={`${copy.name}, ${t.localcoordW} by ${t.localcoordH}, ${copy.tagline}${recommended ? ", recommended" : ""}. ${confidenceLabel(t)}: ${confidenceHelp(t)}`}
              tabIndex={selected || (!selectedTemplateId && i === 0) ? 0 : -1}
              onClick={() => setSelectedTemplateId(t.id)}
              onKeyDown={(e) => onKeyDown(e, i)}
              className={
                "group relative flex items-center gap-3 rounded-lg border-2 p-2.5 pr-3 text-left transition-[background-color,border-color,transform] duration-150 " +
                (selected
                  ? "pop border-p1 bg-p1-soft"
                  : "border-transparent bg-raised hover:-translate-y-px hover:border-line-strong")
              }
            >
              <AspectThumb template={t} imageUrl={imageUrl} selected={selected} />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="truncate text-[14px] font-bold">{copy.name}</span>
                  {recommended && (
                    <span className="shrink-0 rounded-sm bg-p1-fill px-1.5 py-px text-[11px] font-bold tracking-wide text-white">
                      Recommended
                    </span>
                  )}
                </div>
                <div className="flex items-baseline justify-between gap-2">
                  <span className="whitespace-nowrap font-mono text-[12px] font-semibold">
                    {dims(t.localcoordW, t.localcoordH)}
                  </span>
                  <span
                    title={confidenceHelp(t)}
                    className={
                      "text-[11px] font-semibold tracking-wide " +
                      (t.confidence === "Empirical" ? "text-gold" : "text-muted")
                    }
                  >
                    {confidenceLabel(t)}
                  </span>
                </div>
                <div className="truncate text-[12px] text-muted">
                  {selected ? `Suggested image: ${dims(t.recommendedBgWidth, t.recommendedBgHeight)} or larger` : copy.tagline}
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

/** A small frame in the template's screen shape, filled with the user's image if they have one. */
function AspectThumb({
  template,
  imageUrl,
  selected,
}: {
  template: StageTemplate;
  imageUrl: string | null;
  selected: boolean;
}) {
  const ratio = template.localcoordW / template.localcoordH;
  const height = 36;
  const width = Math.round(height * ratio);
  return (
    <span className="grid h-10 w-16 shrink-0 place-items-center">
      <span
        className={
          "block overflow-hidden rounded-[3px] border " +
          (selected ? "border-p1" : "border-line-strong")
        }
        style={{
          width,
          height,
          background: imageUrl
            ? `center bottom / cover no-repeat url("${imageUrl}")`
            : "linear-gradient(160deg, var(--p2-soft), var(--p1-soft))",
        }}
      />
    </span>
  );
}
