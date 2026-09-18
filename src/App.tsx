import { useEffect, useState } from "react";
import { TemplatePicker } from "./components/TemplatePicker";
import { ImageImport } from "./components/ImageImport";
import { PreviewExport } from "./components/PreviewExport";
import type { Screen, StageConfig, StageTemplate } from "./types/stage";
import { emptyConfig } from "./store/stageStore";
import "./App.css";

type Theme = "light" | "dark";

function getInitialTheme(): Theme {
  if (typeof window === "undefined") return "light";

  const savedTheme = window.localStorage.getItem("theme");
  if (savedTheme === "light" || savedTheme === "dark") return savedTheme;

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function App() {
  const [screen, setScreen] = useState<Screen>("pick");
  const [theme, setTheme] = useState<Theme>(getInitialTheme);
  const [templates, setTemplates] = useState<StageTemplate[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [config, setConfig] = useState<StageConfig | null>(null);

  const selectedTemplate =
    templates.find((t) => t.id === selectedTemplateId) ?? null;

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
    window.localStorage.setItem("theme", theme);
  }, [theme]);

  return (
    <main className="min-h-screen bg-white text-gray-900 transition-colors dark:bg-gray-950 dark:text-gray-100">
      <header className="flex items-center justify-between gap-4 border-b border-gray-200 px-6 py-3 text-sm text-gray-500 dark:border-gray-800 dark:text-gray-400">
        <div>
          MUGEN Stage Studio · {screen === "pick" ? "1 · Template" : screen === "import" ? "2 · Image" : "3 · Preview"}
        </div>
        <button
          type="button"
          onClick={() => setTheme((current) => (current === "dark" ? "light" : "dark"))}
          className="rounded border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition hover:border-gray-500 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:border-gray-500 dark:hover:bg-gray-900"
          aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}
        >
          {theme === "dark" ? "Light mode" : "Dark mode"}
        </button>
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

      {screen === "import" && selectedTemplate && config && (
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
