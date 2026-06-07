import { useState } from "react";
import { exportStage } from "../hooks/useTauriCommands";
import type { StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig;
  setConfig: (c: StageConfig) => void;
}

export function PreviewExport({ template, config, setConfig }: Props) {
  const [exportMessage, setExportMessage] = useState<string | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  const onExport = async () => {
    setExportMessage(null);
    setExportError(null);
    try {
      const result = await exportStage(config);
      setExportMessage(result);
    } catch (e) {
      // Phase 4a stub returns Err("Export not yet implemented — Phase 4b").
      // Surfacing the error string is the correct UX for this phase.
      setExportError(String(e));
    }
  };

  return (
    <section className="rounded border border-[#d9d1c3] bg-white p-4 shadow-sm">
      <div className="mb-4">
        <h2 className="text-base font-semibold">Export</h2>
        <p className="text-xs text-[#6c655b]">
          {template.id} · {template.localcoordW}×{template.localcoordH}
        </p>
      </div>

      <div className="mb-4 space-y-3">
        <label className="block">
          <span className="mb-1 block text-sm font-medium">Stage name</span>
          <input
            type="text"
            value={config.name}
            onChange={(e) => setConfig({ ...config, name: e.target.value })}
            className="w-full rounded border border-[#cfc4b1] px-3 py-2 text-sm outline-none focus:border-[#1f5f5b] focus:ring-2 focus:ring-[#b9d8ce]"
            placeholder="My new stage"
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium">Author</span>
          <input
            type="text"
            value={config.author}
            onChange={(e) => setConfig({ ...config, author: e.target.value })}
            className="w-full rounded border border-[#cfc4b1] px-3 py-2 text-sm outline-none focus:border-[#1f5f5b] focus:ring-2 focus:ring-[#b9d8ce]"
            placeholder="Your name"
          />
        </label>
      </div>

      <div className="mb-4 rounded bg-[#f8f6f0] p-3 text-xs text-[#6c655b]">
        <div className="font-semibold text-[#4f4940]">Output contract</div>
        <div className="mt-1">
          DEF/SFF generation remains behind the existing Tauri export command.
        </div>
      </div>

      <div className="mb-4">
        <button
          type="button"
          onClick={onExport}
          className="w-full rounded bg-[#1f5f5b] px-4 py-2 text-sm font-semibold text-white hover:bg-[#174844]"
        >
          Export
        </button>
      </div>

      {exportMessage && (
        <p className="rounded border border-green-200 bg-green-50 p-3 text-sm text-green-700">
          {exportMessage}
        </p>
      )}
      {exportError && (
        <p className="rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-700">
          {exportError}
        </p>
      )}
    </section>
  );
}
