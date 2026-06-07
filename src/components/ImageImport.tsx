import { useState } from "react";
import { loadImage } from "../hooks/useTauriCommands";
import type { ConformanceState, StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig | null;
  setConfig: (c: StageConfig) => void;
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

export function ImageImport({ template, config, setConfig }: Props) {
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
  const imageLabel = config?.bgImagePath ?? "No file selected";

  return (
    <section className="rounded border border-[#d9d1c3] bg-white p-4 shadow-sm">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold">Image and conformance</h2>
          <p className="text-xs text-[#6c655b]">
            {template.displayName} · target {template.bgWidth}×{template.bgHeight}
          </p>
        </div>
        <div className="rounded bg-[#f5f2eb] px-2 py-1 text-xs text-[#4f4940]">
          axis {template.axisX},{template.axisY}
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-[minmax(0,1fr)_260px]">
        <label className="flex min-h-40 cursor-pointer flex-col justify-center rounded border border-dashed border-[#b7a98f] bg-[#fffdf8] p-4">
          <span className="text-sm font-semibold">Background image</span>
          <span className="mt-1 text-xs text-[#6c655b]">{imageLabel}</span>
          <input
            className="mt-4 text-sm"
            type="file"
            accept="image/*"
            onChange={onFileChange}
          />
        </label>

        <div className="rounded border border-[#d9d1c3] bg-[#f8f6f0] p-3">
          <div className="text-sm font-semibold">Conformance state</div>
          <div className="mt-2 text-sm text-[#4f4940]">{describeConformance(state)}</div>
          {state.type === "NoImage" && config?.bgImagePath && (
            <div className="mt-2 text-xs text-[#7c5b2c]">
              Phase 4a stub: real dimension checks arrive in Phase 4b.
            </div>
          )}
          <dl className="mt-4 grid grid-cols-2 gap-2 text-xs text-[#6c655b]">
            <div>
              <dt className="font-semibold text-[#4f4940]">Bounds</dt>
              <dd>{template.boundLeft} / {template.boundRight}</dd>
            </div>
            <div>
              <dt className="font-semibold text-[#4f4940]">zoffset</dt>
              <dd>{template.zoffset}</dd>
            </div>
            <div>
              <dt className="font-semibold text-[#4f4940]">boundhigh</dt>
              <dd>{template.boundHigh}</dd>
            </div>
            <div>
              <dt className="font-semibold text-[#4f4940]">tension</dt>
              <dd>{template.tension}</dd>
            </div>
          </dl>
        </div>
      </div>

      {error && (
        <p className="mt-3 rounded border border-red-200 bg-red-50 p-2 text-sm text-red-700">
          {error}
        </p>
      )}
    </section>
  );
}
