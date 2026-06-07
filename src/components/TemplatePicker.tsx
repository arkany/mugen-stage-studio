import { useEffect, useState } from "react";
import { getTemplates } from "../hooks/useTauriCommands";
import type { StageTemplate } from "../types/stage";

interface Props {
  templates: StageTemplate[];
  setTemplates: (t: StageTemplate[]) => void;
  selectedTemplateId: string | null;
  setSelectedTemplateId: (id: string | null) => void;
}

export function TemplatePicker({
  templates,
  setTemplates,
  selectedTemplateId,
  setSelectedTemplateId,
}: Props) {
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (templates.length > 0) return;
    getTemplates()
      .then(setTemplates)
      .catch((e) => setLoadError(String(e)));
  }, [templates.length, setTemplates]);

  return (
    <section className="rounded border border-[#d9d1c3] bg-white p-4 shadow-sm">
      <div className="mb-3 flex items-end justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold">Template</h2>
          <p className="text-xs text-[#6c655b]">Choose the target coordinate model.</p>
        </div>
        <span className="text-xs text-[#6c655b]">{templates.length} presets</span>
      </div>

      {loadError && (
        <p className="mb-3 rounded border border-red-200 bg-red-50 p-2 text-sm text-red-700">
          Failed to load templates: {loadError}
        </p>
      )}

      <ul className="flex gap-3 overflow-x-auto pb-1">
        {templates.map((t) => {
          const selected = t.id === selectedTemplateId;
          return (
            <li key={t.id} className="min-w-[200px] flex-1">
              <button
                type="button"
                onClick={() => setSelectedTemplateId(t.id)}
                className={
                  "h-full w-full rounded border p-3 text-left transition " +
                  (selected
                    ? "border-[#1f5f5b] bg-[#ecf6f1] shadow-sm"
                    : "border-[#d9d1c3] bg-[#fffdf8] hover:border-[#8f744d]")
                }
                aria-pressed={selected}
              >
                <div className="flex h-full flex-col gap-3">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="text-sm font-semibold leading-snug">{t.id}</div>
                      <div className="mt-1 text-xs leading-snug text-[#4f4940]">
                        {t.displayName}
                      </div>
                    </div>
                    <span
                      className={
                        "whitespace-nowrap rounded px-2 py-1 text-[11px] " +
                        (t.confidence === "Empirical"
                          ? "bg-[#dff0dc] text-[#235323]"
                          : "bg-[#fff1c7] text-[#745000]")
                      }
                    >
                      {t.confidence === "Empirical" ? "Empirical" : "Formula"}
                    </span>
                  </div>
                  <div className="mt-auto space-y-1 text-xs text-[#6c655b]">
                    <div>
                      localcoord {t.localcoordW}×{t.localcoordH} · image {t.bgWidth}×{t.bgHeight}
                    </div>
                    <div>
                      Source: {t.sourceStage}
                      {t.sourceAuthor && t.sourceAuthor !== "(none — no source at this resolution)"
                        ? ` (${t.sourceAuthor})`
                        : ""}
                    </div>
                  </div>
                </div>
              </button>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
