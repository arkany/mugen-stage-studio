import { useState } from "react";
import { loadImage } from "../hooks/useTauriCommands";
import type { ConformanceState, StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig | null;
  setConfig: (c: StageConfig) => void;
  onBack: () => void;
  onContinue: () => void;
}

function describeConformance(state: ConformanceState): string {
  switch (state.type) {
    case "NoImage":
      return "No image loaded yet";
    case "Correct":
      return "Ready";
    case "FixableWithCrop":
      return `Will crop ${state.cropX}×${state.cropY}px from each edge`;
    case "FixableWithExtend":
      return `Will pad ${state.padX}×${state.padY}px on each edge`;
    case "TooSmall":
      return "Image too small — choose a different source";
  }
}

function conformanceClass(state: ConformanceState): string {
  switch (state.type) {
    case "Correct":
      return "border-green-200 bg-green-50 text-green-800 dark:border-green-900 dark:bg-green-950/50 dark:text-green-300";
    case "FixableWithCrop":
    case "FixableWithExtend":
      return "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-900 dark:bg-amber-950/50 dark:text-amber-300";
    case "TooSmall":
      return "border-red-200 bg-red-50 text-red-800 dark:border-red-900 dark:bg-red-950/50 dark:text-red-300";
    case "NoImage":
      return "border-gray-200 bg-gray-50 text-gray-700 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-300";
  }
}

export function ImageImport({ template, config, setConfig, onBack, onContinue }: Props) {
  const [error, setError] = useState<string | null>(null);

  const onChooseImage = async () => {
    setError(null);
    try {
      const updated = await loadImage(template.id);
      setConfig(updated);
    } catch (e) {
      setError(String(e));
    }
  };

  const state = config?.conformanceState ?? { type: "NoImage" as const };
  const canContinue =
    state.type === "Correct" ||
    state.type === "FixableWithCrop" ||
    state.type === "FixableWithExtend";

  return (
    <section className="p-6">
      <h1 className="text-xl font-semibold mb-2">Import background</h1>
      <p className="text-sm text-gray-600 mb-4 dark:text-gray-300">
        Template: <span className="font-medium">{template.displayName}</span> · target {template.bgWidth}×{template.bgHeight}
      </p>

      <button
        type="button"
        onClick={onChooseImage}
        className="mb-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400"
      >
        Choose image…
      </button>

      <div className={`mb-4 p-3 border rounded ${conformanceClass(state)}`}>
        <div className="text-sm font-medium">Conformance state</div>
        <div className="text-sm">{describeConformance(state)}</div>
        {config?.bgImagePath && (
          <div className="text-xs mt-1 opacity-80">
            {config.bgImagePath}
            {config.bgImageWidth && config.bgImageHeight
              ? ` · ${config.bgImageWidth}×${config.bgImageHeight}`
              : ""}
          </div>
        )}
      </div>

      {error && <p className="text-red-600 mb-4 dark:text-red-400">{error}</p>}

      <div className="flex gap-2">
        <button
          type="button"
          onClick={onBack}
          className="px-4 py-2 border border-gray-400 rounded hover:bg-gray-50 dark:border-gray-600 dark:hover:bg-gray-900"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onContinue}
          disabled={!canContinue}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed dark:bg-blue-500 dark:hover:bg-blue-400 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        >
          Continue
        </button>
      </div>
    </section>
  );
}
