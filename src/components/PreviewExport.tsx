// Name the stage and write it to disk.
//
// The DEF shown here is generated from the same derivation the preview screen
// showed, and the SFF written alongside it carries the matching sprite axis —
// both come from one backend call, so they cannot disagree.

import { useEffect, useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import {
  defaultOutputDir,
  exportStage,
  previewDef,
} from "../hooks/useTauriCommands";
import type { ExportResult, StageConfig, StageTemplate } from "../types/stage";

interface Props {
  template: StageTemplate;
  config: StageConfig;
  setConfig: (c: StageConfig) => void;
  onBack: () => void;
}

export function PreviewExport({ template, config, setConfig, onBack }: Props) {
  const [def, setDef] = useState<string | null>(null);
  const [defError, setDefError] = useState<string | null>(null);
  const [outputDir, setOutputDir] = useState<string>("");
  const [result, setResult] = useState<ExportResult | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    defaultOutputDir()
      .then(setOutputDir)
      .catch(() => setOutputDir(""));
  }, []);

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

  const onChooseDir = async () => {
    try {
      const picked = await open({ directory: true, multiple: false });
      if (typeof picked === "string") setOutputDir(picked);
    } catch (e) {
      setExportError(String(e));
    }
  };

  const onExport = async () => {
    setResult(null);
    setExportError(null);
    setBusy(true);
    try {
      setResult(await exportStage(config, outputDir));
    } catch (e) {
      setExportError(String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="p-6 max-w-4xl">
      <h1 className="text-xl font-semibold mb-1">Name &amp; export</h1>
      <p className="text-sm text-gray-600 mb-4 dark:text-gray-300">{template.displayName}</p>

      <div className="grid gap-3 sm:grid-cols-2 mb-4">
        <label className="block">
          <span className="block text-sm font-medium mb-1">Stage name</span>
          <input
            type="text"
            value={config.name}
            onChange={(e) => setConfig({ ...config, name: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded bg-white text-gray-900 placeholder:text-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100 dark:placeholder:text-gray-500"
            placeholder="My new stage"
          />
        </label>

        <label className="block">
          <span className="block text-sm font-medium mb-1">Author</span>
          <input
            type="text"
            value={config.author}
            onChange={(e) => setConfig({ ...config, author: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded bg-white text-gray-900 placeholder:text-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100 dark:placeholder:text-gray-500"
            placeholder="Your name"
          />
        </label>

        <label className="block sm:col-span-2">
          <span className="block text-sm font-medium mb-1">
            Music <span className="text-gray-500 font-normal dark:text-gray-400">(optional)</span>
          </span>
          <input
            type="text"
            value={config.music ?? ""}
            onChange={(e) =>
              setConfig({ ...config, music: e.target.value || null })
            }
            className="w-full px-3 py-2 border border-gray-300 rounded bg-white text-gray-900 placeholder:text-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100 dark:placeholder:text-gray-500"
            placeholder="sound/yourtrack.ogg"
          />
        </label>
      </div>

      <div className="mb-6">
        <span className="block text-sm font-medium mb-1">Export to</span>
        <div className="flex gap-2">
          <input
            type="text"
            value={outputDir}
            onChange={(e) => setOutputDir(e.target.value)}
            className="flex-1 px-3 py-2 border border-gray-300 rounded font-mono text-xs bg-white text-gray-900 placeholder:text-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100 dark:placeholder:text-gray-500"
            placeholder="Choose a folder"
          />
          <button
            type="button"
            onClick={onChooseDir}
            className="px-4 py-2 border border-gray-400 rounded hover:bg-gray-50 dark:border-gray-600 dark:hover:bg-gray-900"
          >
            Browse…
          </button>
        </div>
        <span className="block text-xs text-gray-500 mt-1 dark:text-gray-400">
          Writes a <code>.def</code> and a <code>.sff</code>. Point IKEMEN Lab
          at this folder to import the stage.
        </span>
      </div>

      {def && (
        <details className="mb-6">
          <summary className="text-sm font-medium cursor-pointer mb-2">
            Generated DEF
          </summary>
          <pre className="text-xs font-mono bg-gray-900 text-gray-100 p-4 rounded overflow-x-auto max-h-96">
            {def}
          </pre>
        </details>
      )}

      {defError && (
        <p className="mb-4 p-3 text-red-700 bg-red-50 border border-red-200 rounded dark:text-red-300 dark:bg-red-950/50 dark:border-red-900">
          {defError}
        </p>
      )}

      <div className="flex gap-2 mb-4">
        <button
          type="button"
          onClick={onBack}
          className="px-4 py-2 border border-gray-400 rounded hover:bg-gray-50 dark:border-gray-600 dark:hover:bg-gray-900"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onExport}
          disabled={busy || !outputDir}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed dark:bg-blue-500 dark:hover:bg-blue-400 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        >
          {busy ? "Exporting…" : "Export"}
        </button>
      </div>

      {result && (
        <div className="text-green-800 bg-green-50 border border-green-200 rounded p-3 text-sm dark:text-green-300 dark:bg-green-950/50 dark:border-green-900">
          <p className="font-medium mb-1">
            Exported {result.backdropWidth}×{result.backdropHeight} backdrop
            {result.resampled ? " (resampled to cover the viewport)" : ""}.
          </p>
          <p className="font-mono text-xs">{result.defPath}</p>
          <p className="font-mono text-xs">{result.sffPath}</p>
        </div>
      )}
      {exportError && (
        <p className="text-red-700 bg-red-50 border border-red-200 rounded p-3 dark:text-red-300 dark:bg-red-950/50 dark:border-red-900">
          {exportError}
        </p>
      )}
    </section>
  );
}
