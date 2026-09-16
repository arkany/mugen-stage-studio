// Name the stage and export it.
//
// The DEF is generated from the same derivation the preview screen showed, so
// what is written here is exactly what was approved there.

import { useEffect, useState } from "react";
import { exportStage, previewDef } from "../hooks/useTauriCommands";
import type { StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig;
  setConfig: (c: StageConfig) => void;
  onBack: () => void;
}

export function PreviewExport({ template, config, setConfig, onBack }: Props) {
  const [def, setDef] = useState<string | null>(null);
  const [defError, setDefError] = useState<string | null>(null);
  const [exportMessage, setExportMessage] = useState<string | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  useEffect(() => {
    previewDef(config)
      .then((text) => {
        setDef(text);
        setDefError(null);
      })
      .catch((e) => {
        setDef(null);
        setDefError(String(e));
      });
  }, [config]);

  const onExport = async () => {
    setExportMessage(null);
    setExportError(null);
    try {
      setExportMessage(await exportStage(config));
    } catch (e) {
      setExportError(String(e));
    }
  };

  return (
    <section className="p-6 max-w-4xl">
      <h1 className="text-xl font-semibold mb-1">Name &amp; export</h1>
      <p className="text-sm text-gray-600 mb-4">{template.displayName}</p>

      <div className="grid gap-3 sm:grid-cols-2 mb-6">
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

        <label className="block sm:col-span-2">
          <span className="block text-sm font-medium mb-1">
            Music <span className="text-gray-500 font-normal">(optional)</span>
          </span>
          <input
            type="text"
            value={config.music ?? ""}
            onChange={(e) =>
              setConfig({ ...config, music: e.target.value || null })
            }
            className="w-full px-3 py-2 border border-gray-300 rounded"
            placeholder="sound/yourtrack.ogg"
          />
        </label>
      </div>

      {def && (
        <details className="mb-6" open>
          <summary className="text-sm font-medium cursor-pointer mb-2">
            Generated DEF
          </summary>
          <pre className="text-xs font-mono bg-gray-900 text-gray-100 p-4 rounded overflow-x-auto max-h-96">
            {def}
          </pre>
        </details>
      )}

      {defError && (
        <p className="mb-4 p-3 text-red-700 bg-red-50 border border-red-200 rounded">
          {defError}
        </p>
      )}

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
