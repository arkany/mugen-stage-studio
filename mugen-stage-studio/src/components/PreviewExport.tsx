import { useState } from "react";
import { exportStage } from "../hooks/useTauriCommands";
import type { StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig;
  setConfig: (c: StageConfig) => void;
  onBack: () => void;
}

export function PreviewExport({ template, config, setConfig, onBack }: Props) {
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
    <section className="p-6">
      <h1 className="text-xl font-semibold mb-2">Preview &amp; export</h1>
      <p className="text-sm text-gray-600 mb-4">
        Template: <span className="font-medium">{template.displayName}</span>
      </p>

      <div className="space-y-3 mb-6 max-w-md">
        <label className="block">
          <span className="block text-sm font-medium mb-1">Stage name</span>
          <input
            type="text"
            value={config.name}
            onChange={(e) => setConfig({ ...config, name: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded"
            placeholder="My new stage"
          />
        </label>

        <label className="block">
          <span className="block text-sm font-medium mb-1">Author</span>
          <input
            type="text"
            value={config.author}
            onChange={(e) => setConfig({ ...config, author: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded"
            placeholder="Your name"
          />
        </label>
      </div>

      <div className="flex gap-2 mb-4">
        <button
          type="button"
          onClick={onBack}
          className="px-4 py-2 border border-gray-400 rounded"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onExport}
          className="px-4 py-2 bg-blue-600 text-white rounded"
        >
          Export
        </button>
      </div>

      {exportMessage && (
        <p className="text-green-700 bg-green-50 border border-green-200 rounded p-3">
          {exportMessage}
        </p>
      )}
      {exportError && (
        <p className="text-amber-700 bg-amber-50 border border-amber-200 rounded p-3">
          {exportError}
        </p>
      )}
    </section>
  );
}
