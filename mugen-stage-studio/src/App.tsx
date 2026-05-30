import { useState } from "react";
import { TemplatePicker } from "./components/TemplatePicker";
import { ImageImport } from "./components/ImageImport";
import { PreviewExport } from "./components/PreviewExport";
import type { Screen, StageConfig, StageTemplate } from "./types/stage";
import { emptyConfig } from "./store/stageStore";
import "./App.css";

function App() {
  const [screen, setScreen] = useState<Screen>("pick");
  const [templates, setTemplates] = useState<StageTemplate[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [config, setConfig] = useState<StageConfig | null>(null);

  const selectedTemplate =
    templates.find((t) => t.id === selectedTemplateId) ?? null;

  return (
    <main className="min-h-screen bg-white text-gray-900">
      <header className="px-6 py-3 border-b border-gray-200 text-sm text-gray-500">
        MUGEN Stage Studio · {screen === "pick" ? "1 · Template" : screen === "import" ? "2 · Image" : "3 · Preview"}
      </header>

      {screen === "pick" && (
        <TemplatePicker
          templates={templates}
          setTemplates={setTemplates}
          selectedTemplateId={selectedTemplateId}
          setSelectedTemplateId={setSelectedTemplateId}
          onContinue={() => {
            if (selectedTemplateId) {
              setConfig(emptyConfig(selectedTemplateId));
              setScreen("import");
            }
          }}
        />
      )}

      {screen === "import" && selectedTemplate && (
        <ImageImport
          template={selectedTemplate}
          config={config}
          setConfig={setConfig}
          onBack={() => setScreen("pick")}
          onContinue={() => setScreen("preview")}
        />
      )}

      {screen === "preview" && selectedTemplate && config && (
        <PreviewExport
          template={selectedTemplate}
          config={config}
          setConfig={setConfig}
          onBack={() => setScreen("import")}
        />
      )}
    </main>
  );
}

export default App;
