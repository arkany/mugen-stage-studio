import { useState } from "react";
import { exportStage } from "../hooks/useTauriCommands";
import { buildExportDebugFixture } from "../lib/exportDebug";
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
  const [copyMessage, setCopyMessage] = useState<string | null>(null);
  const debugFixture = buildExportDebugFixture(template, config);

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

  const onCopyFixture = async () => {
    setCopyMessage(null);
    await navigator.clipboard.writeText(debugFixture.fixtureText);
    setCopyMessage("Fixture details copied");
  };

  const onDownloadFixture = () => {
    const blob = new Blob([debugFixture.fixtureText], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${debugFixture.stageName}-export-fixture.txt`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <section className="p-6 space-y-6">
      <h1 className="text-xl font-semibold mb-2">Preview &amp; export</h1>
      <p className="text-sm text-gray-600 mb-4">
        Template: <span className="font-medium">{template.displayName}</span>
      </p>

      <div className="space-y-3 max-w-md">
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

      <div className="border border-gray-200 rounded bg-gray-50">
        <div className="px-4 py-3 border-b border-gray-200">
          <h2 className="text-sm font-semibold">Export debug panel</h2>
        </div>

        <div className="grid gap-4 p-4 lg:grid-cols-[minmax(0,1fr)_minmax(360px,0.85fr)]">
          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
                Generated DEF preview
              </h3>
              <pre className="max-h-96 overflow-auto rounded border border-gray-200 bg-white p-3 text-xs leading-relaxed text-gray-800">
                {debugFixture.defPreview}
              </pre>
            </div>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={onCopyFixture}
                className="px-3 py-2 border border-gray-400 rounded text-sm"
              >
                Copy fixture details
              </button>
              <button
                type="button"
                onClick={onDownloadFixture}
                className="px-3 py-2 border border-gray-400 rounded text-sm"
              >
                Export fixture details
              </button>
              {copyMessage && (
                <span className="self-center text-sm text-green-700">
                  {copyMessage}
                </span>
              )}
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
                SFF sprite list
              </h3>
              <div className="overflow-hidden rounded border border-gray-200 bg-white">
                <table className="w-full text-left text-sm">
                  <thead className="bg-gray-100 text-xs uppercase text-gray-500">
                    <tr>
                      <th className="px-3 py-2 font-semibold">Sprite</th>
                      <th className="px-3 py-2 font-semibold">Role</th>
                      <th className="px-3 py-2 font-semibold">Size</th>
                      <th className="px-3 py-2 font-semibold">Axis</th>
                    </tr>
                  </thead>
                  <tbody>
                    {debugFixture.sffSprites.map((sprite) => (
                      <tr
                        key={`${sprite.group}-${sprite.image}`}
                        className="border-t border-gray-200"
                      >
                        <td className="px-3 py-2 font-mono">
                          {sprite.group},{sprite.image}
                        </td>
                        <td className="px-3 py-2">{sprite.label}</td>
                        <td className="px-3 py-2 font-mono">
                          {sprite.dimensions}
                        </td>
                        <td className="px-3 py-2 font-mono">{sprite.axis}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            <dl className="grid grid-cols-2 gap-3 rounded border border-gray-200 bg-white p-3 text-sm">
              <div>
                <dt className="text-xs uppercase text-gray-500">Image</dt>
                <dd className="font-mono">{debugFixture.imageDimensions}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase text-gray-500">Axis</dt>
                <dd className="font-mono">{debugFixture.axis}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase text-gray-500">Start</dt>
                <dd className="font-mono">{debugFixture.start}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase text-gray-500">Bounds</dt>
                <dd className="font-mono">{debugFixture.bounds}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase text-gray-500">Zoffset</dt>
                <dd className="font-mono">{debugFixture.zoffset}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase text-gray-500">SFF</dt>
                <dd className="font-mono break-all">{debugFixture.sffFileName}</dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

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
