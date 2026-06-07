import { useEffect, useState } from "react";
import { TemplatePicker } from "./components/TemplatePicker";
import { ImageImport } from "./components/ImageImport";
import { PreviewExport } from "./components/PreviewExport";
import type { StageConfig, StageTemplate } from "./types/stage";
import { emptyConfig } from "./store/stageStore";
import "./App.css";

function App() {
  const [templates, setTemplates] = useState<StageTemplate[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [config, setConfig] = useState<StageConfig | null>(null);

  const selectedTemplate =
    templates.find((t) => t.id === selectedTemplateId) ?? null;

  useEffect(() => {
    if (selectedTemplateId || templates.length === 0) return;
    const firstTemplate = templates[0];
    setSelectedTemplateId(firstTemplate.id);
    setConfig(emptyConfig(firstTemplate.id));
  }, [selectedTemplateId, templates]);

  const selectTemplate = (templateId: string | null) => {
    setSelectedTemplateId(templateId);
    setConfig(templateId ? emptyConfig(templateId) : null);
  };

  return (
    <main className="min-h-screen bg-[#f5f2eb] text-[#211f1b]">
      <header className="border-b border-[#d9d1c3] bg-[#fffaf0] px-5 py-3">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#7c5b2c]">
              Compact utility
            </p>
            <h1 className="text-xl font-semibold">MUGEN Stage Studio</h1>
          </div>
          <div className="hidden text-right text-xs text-[#6c655b] sm:block">
            Templates, image check, and export in one window
          </div>
        </div>
      </header>

      <div className="mx-auto flex max-w-6xl flex-col gap-4 p-4 sm:p-5">
        <TemplatePicker
          templates={templates}
          setTemplates={setTemplates}
          selectedTemplateId={selectedTemplateId}
          setSelectedTemplateId={selectTemplate}
        />

        <section className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
          {selectedTemplate ? (
            <ImageImport
              template={selectedTemplate}
              config={config}
              setConfig={setConfig}
            />
          ) : (
            <div className="rounded border border-[#d9d1c3] bg-white p-5 text-sm text-[#6c655b]">
              Select a template to import a background image.
            </div>
          )}

          {selectedTemplate && config ? (
            <PreviewExport
              template={selectedTemplate}
              config={config}
              setConfig={setConfig}
            />
          ) : (
            <div className="rounded border border-[#d9d1c3] bg-white p-5 text-sm text-[#6c655b]">
              Export settings appear after a template is ready.
            </div>
          )}
        </section>
      </div>
    </main>
  );
}

export default App;
