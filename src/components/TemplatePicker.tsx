import { useEffect, useState } from "react";
import { getTemplates } from "../hooks/useTauriCommands";
import type { StageTemplate } from "../types/stage";

interface Props {
  templates: StageTemplate[];
  setTemplates: (t: StageTemplate[]) => void;
  selectedTemplateId: string | null;
  setSelectedTemplateId: (id: string | null) => void;
  onContinue: () => void;
}

export function TemplatePicker({
  templates,
  setTemplates,
  selectedTemplateId,
  setSelectedTemplateId,
  onContinue,
}: Props) {
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (templates.length > 0) return;
    getTemplates()
      .then(setTemplates)
      .catch((e) => setLoadError(String(e)));
  }, [templates.length, setTemplates]);

  return (
    <section className="p-6">
      <h1 className="text-xl font-semibold mb-4">Pick a template</h1>

      {loadError && (
        <p className="text-red-600 mb-4 dark:text-red-400">Failed to load templates: {loadError}</p>
      )}

      <ul className="space-y-2">
        {templates.map((t) => {
          const selected = t.id === selectedTemplateId;
          return (
            <li key={t.id}>
              <button
                type="button"
                onClick={() => setSelectedTemplateId(t.id)}
                className={
                  "w-full text-left p-3 border rounded " +
                  (selected
                    ? "border-blue-600 bg-blue-50 dark:border-blue-400 dark:bg-blue-950/50"
                    : "border-gray-300 hover:border-gray-500 dark:border-gray-700 dark:hover:border-gray-500")
                }
              >
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-medium">{t.displayName}</div>
                    <div className="text-sm text-gray-600 dark:text-gray-300">
                      viewport {t.localcoordW}×{t.localcoordH} · suggested
                      backdrop {t.recommendedBgWidth}×{t.recommendedBgHeight}
                    </div>
                    <div className="text-xs text-gray-500 mt-1 dark:text-gray-400">
                      Camera feel from {t.sourceStage}
                      {t.sourceAuthor.startsWith("(") ? "" : ` (${t.sourceAuthor})`}
                      {" · "}
                      bounds and zoffset are derived from your image
                    </div>
                    {t.notes && (
                      <div className="text-xs text-gray-400 mt-1 dark:text-gray-500">{t.notes}</div>
                    )}
                  </div>
                  <span
                    className={
                      "text-xs px-2 py-1 rounded " +
                      (t.confidence === "Empirical"
                        ? "bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300"
                        : "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300")
                    }
                  >
                    {t.confidence === "Empirical" ? "Empirical" : "Formula-derived"}
                  </span>
                </div>
              </button>
            </li>
          );
        })}
      </ul>

      <div className="mt-6">
        <button
          type="button"
          onClick={onContinue}
          disabled={selectedTemplateId === null}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed dark:bg-blue-500 dark:hover:bg-blue-400 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        >
          Use Template
        </button>
      </div>
    </section>
  );
}
