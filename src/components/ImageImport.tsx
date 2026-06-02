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
      return "Image matches template dimensions";
    case "FixableWithCrop":
      return `Crop needed: trim ${state.cropX}×${state.cropY} px`;
    case "FixableWithExtend":
      return `Extend needed: pad ${state.padX}×${state.padY} px`;
    case "TooSmall":
      return "Image too small — choose a different source";
  }
}

export function ImageImport({ template, config, setConfig, onBack, onContinue }: Props) {
  const [error, setError] = useState<string | null>(null);

  const onFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    setError(null);
    const file = e.target.files?.[0];
    if (!file) return;

    // Phase 4a: we pass the file name as a placeholder path. Phase 4b will
    // resolve a real on-disk path via Tauri's dialog plugin.
    const imagePath = file.name;
    try {
      const updated = await loadImage(imagePath, template.id);
      setConfig(updated);
    } catch (e) {
      setError(String(e));
    }
  };

  const state = config?.conformanceState ?? { type: "NoImage" as const };
  const canContinue = state.type === "Correct";

  return (
    <section className="p-6">
      <h1 className="text-xl font-semibold mb-2">Import background</h1>
      <p className="text-sm text-gray-600 mb-4">
        Template: <span className="font-medium">{template.displayName}</span> · target {template.bgWidth}×{template.bgHeight}
      </p>

      <label className="block mb-4">
        <span className="block text-sm font-medium mb-1">Background image</span>
        <input type="file" accept="image/*" onChange={onFileChange} />
      </label>

      <div className="mb-4 p-3 border border-gray-200 rounded bg-gray-50">
        <div className="text-sm font-medium">Conformance state</div>
        <div className="text-sm text-gray-700">{describeConformance(state)}</div>
        {state.type === "NoImage" && config?.bgImagePath && (
          <div className="text-xs text-gray-500 mt-1">
            (Phase 4a stub — real conformance arrives in Phase 4b)
          </div>
        )}
      </div>

      {error && <p className="text-red-600 mb-4">{error}</p>}

      <div className="flex gap-2">
        <button
          type="button"
          onClick={onBack}
          className="px-4 py-2 border border-gray-400 rounded"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onContinue}
          disabled={!canContinue}
          className="px-4 py-2 bg-blue-600 text-white rounded disabled:bg-gray-300 disabled:cursor-not-allowed"
        >
          Continue
        </button>
      </div>
    </section>
  );
}
