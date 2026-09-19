import { useCallback, useEffect, useRef, useState } from "react";
import { convertFileSrc } from "@tauri-apps/api/core";
import { getCurrentWebview } from "@tauri-apps/api/webview";
import { open } from "@tauri-apps/plugin-dialog";
import { ImagePlus } from "lucide-react";
import { Header, type StepId, type Theme } from "./components/Header";
import { TemplatePicker } from "./components/TemplatePicker";
import { ImageImport, type LoadedImage } from "./components/ImageImport";
import {
  ExportBar,
  ExportResultPanel,
  StageNameFields,
  type ExportOutcome,
} from "./components/PreviewExport";
import { StagePreview } from "./components/StagePreview";
import { DetailsDrawer } from "./components/DetailsDrawer";
import {
  defaultOutputDir,
  deriveStage,
  exportStage,
  loadImage,
  previewDef,
} from "./hooks/useTauriCommands";
import type { DerivedStage, ImportFit, StageConfig, StageTemplate } from "./types/stage";
import { emptyConfig } from "./store/stageStore";
import { RECOMMENDED_TEMPLATE_ID, minImageSize } from "./lib/templateMeta";
import { hasPrimaryModifier } from "./lib/platform";
import "./App.css";

const AUTHOR_KEY = "mss.author";
const DETAILS_KEY = "mss.detailsOpen";
const THEME_KEY = "theme";
const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "webp"];

function readStored(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStored(key: string, value: string) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Storage can be unavailable; these are conveniences only.
  }
}

function initialTheme(): Theme {
  const saved = readStored(THEME_KEY);
  if (saved === "light" || saved === "dark") return saved;
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

/** "sunset_temple-02.png" → "Sunset Temple 02" */
function nameFromFile(fileName: string): string {
  return fileName
    .replace(/\.[^.]+$/, "")
    .replace(/[_\-.]+/g, " ")
    .trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function fileName(path: string): string {
  return path.split(/[\\/]/).pop() ?? path;
}

function App() {
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const [templates, setTemplates] = useState<StageTemplate[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [config, setConfig] = useState<StageConfig | null>(null);
  const [image, setImage] = useState<LoadedImage | null>(null);
  const [fit, setFit] = useState<ImportFit | null>(null);
  const [derived, setDerived] = useState<DerivedStage | null>(null);
  const [def, setDef] = useState<string | null>(null);
  const [imageError, setImageError] = useState<string | null>(null);
  const [outputDir, setOutputDir] = useState("");
  const [detailsOpen, setDetailsOpen] = useState(() => readStored(DETAILS_KEY) === "1");
  const [exporting, setExporting] = useState(false);
  const [exportResult, setExportResult] = useState<ExportOutcome | null>(null);
  const [stamp, setStamp] = useState<{ key: number; text: string; tone: "gold" | "good" } | null>(null);
  const [dragActive, setDragActive] = useState(false);

  const loadSeq = useRef(0);
  const deriveSeq = useRef(0);
  const celebrated = useRef<string | null>(null);

  const template = templates.find((t) => t.id === selectedTemplateId) ?? null;
  const usable = fit?.type === "Usable";
  const tooSmall = fit?.type === "TooSmall";

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
    writeStored(THEME_KEY, theme);
  }, [theme]);

  useEffect(() => {
    defaultOutputDir()
      .then(setOutputDir)
      .catch(() => setOutputDir(""));
  }, []);

  // Pick the recommended resolution once templates arrive.
  useEffect(() => {
    if (selectedTemplateId || templates.length === 0) return;
    const initial = templates.find((t) => t.id === RECOMMENDED_TEMPLATE_ID) ?? templates[0];
    setSelectedTemplateId(initial.id);
    setConfig({ ...emptyConfig(initial.id), author: readStored(AUTHOR_KEY) ?? "" });
  }, [selectedTemplateId, templates]);

  // Re-derive whenever the floor line, zoom or template changes. Drags fire
  // faster than the round trip, so only the newest answer wins.
  useEffect(() => {
    if (!config || !usable || config.bgImageWidth == null) {
      setDerived(null);
      setDef(null);
      return;
    }
    const seq = ++deriveSeq.current;
    Promise.all([deriveStage(config), previewDef(config)])
      .then(([d, text]) => {
        if (seq !== deriveSeq.current) return;
        setDerived(d);
        setDef(text);
      })
      .catch((e) => {
        if (seq === deriveSeq.current) setImageError(`Couldn't work out the camera. ${String(e)}`);
      });
  }, [config, usable]);

  // Celebrate an image that works first time with nothing to fix.
  useEffect(() => {
    if (!image || !derived || derived.warnings.length > 0) return;
    if (celebrated.current === image.path) return;
    celebrated.current = image.path;
    setStamp({ key: Date.now(), text: "Perfect!", tone: "gold" });
  }, [image, derived]);

  /** Read a file through the backend for a template, keeping the user's own fields. */
  const importImage = useCallback(async (path: string, templateId: string) => {
    const seq = ++loadSeq.current;
    setImageError(null);
    setExportResult(null);
    try {
      const result = await loadImage(path, templateId);
      if (seq !== loadSeq.current) return;
      const { config: loaded } = result;
      setFit(result.fit);
      setImage({
        path,
        url: convertFileSrc(path),
        name: fileName(path),
        width: loaded.bgImageWidth ?? 0,
        height: loaded.bgImageHeight ?? 0,
      });
      setConfig((prev) => {
        const samePicture = prev?.bgImagePath === path;
        return {
          ...loaded,
          name: prev?.name.trim() ? prev.name : nameFromFile(fileName(path)),
          author: prev?.author ?? "",
          music: prev?.music ?? null,
          // Keep a floor the user already placed on this picture.
          floorY: samePicture && prev?.floorY != null ? prev.floorY : loaded.floorY,
          zoomoutOverride: prev?.zoomoutOverride ?? null,
        };
      });
    } catch (e) {
      if (seq === loadSeq.current) setImageError(`Couldn't open that image. ${String(e)}`);
    }
  }, []);

  const browseForImage = useCallback(async () => {
    try {
      const picked = await open({
        multiple: false,
        directory: false,
        filters: [{ name: "Images", extensions: IMAGE_EXTENSIONS }],
      });
      if (typeof picked === "string" && selectedTemplateId) await importImage(picked, selectedTemplateId);
    } catch (e) {
      setImageError(String(e));
    }
  }, [importImage, selectedTemplateId]);

  const selectTemplate = (id: string) => {
    setSelectedTemplateId(id);
    setExportResult(null);
    if (image) void importImage(image.path, id);
    else setConfig((prev) => ({ ...(prev ?? emptyConfig(id)), templateId: id }));
  };

  const removeImage = () => {
    loadSeq.current++;
    setImage(null);
    setFit(null);
    setImageError(null);
    setExportResult(null);
    setConfig(
      (prev) =>
        prev && {
          ...prev,
          bgImagePath: null,
          bgImageWidth: null,
          bgImageHeight: null,
          floorY: null,
        },
    );
  };

  const chooseOutputDir = async () => {
    try {
      const picked = await open({ directory: true, multiple: false, defaultPath: outputDir || undefined });
      if (typeof picked === "string") setOutputDir(picked);
    } catch (e) {
      setExportResult({ ok: false, message: String(e) });
    }
  };

  const nameOk = (config?.name.trim() ?? "") !== "";
  const blockedReason = !image
    ? "Add a background image to export."
    : tooSmall
      ? "This image is too small for this resolution."
      : !derived
        ? "Working out the camera…"
        : !nameOk
          ? "Give your stage a name to export."
          : !outputDir
            ? "Choose where to save it."
            : null;

  const runExport = useCallback(async () => {
    if (!config || blockedReason || exporting) return;
    setExporting(true);
    setExportResult(null);
    try {
      const result = await exportStage(config, outputDir);
      setExportResult({ ok: true, result });
      setStamp({ key: Date.now(), text: "Stage ready!", tone: "good" });
    } catch (e) {
      setExportResult({ ok: false, message: String(e) });
    } finally {
      setExporting(false);
    }
  }, [config, blockedReason, exporting, outputDir]);

  const toggleDetails = useCallback(() => {
    setDetailsOpen((open) => {
      writeStored(DETAILS_KEY, open ? "0" : "1");
      return !open;
    });
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!hasPrimaryModifier(e) || e.shiftKey || e.altKey) return;
      const key = e.key.toLowerCase();
      if (key === "o") {
        e.preventDefault();
        void browseForImage();
      } else if (key === "e") {
        e.preventDefault();
        void runExport();
      } else if (key === "i") {
        e.preventDefault();
        toggleDetails();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [browseForImage, runExport, toggleDetails]);

  // Native drag and drop gives real file paths, which the backend needs.
  const importRef = useRef({ importImage, selectedTemplateId });
  importRef.current = { importImage, selectedTemplateId };
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    let cancelled = false;
    getCurrentWebview()
      .onDragDropEvent((event) => {
        const p = event.payload;
        if (p.type === "enter" || p.type === "over") setDragActive(true);
        else if (p.type === "leave") setDragActive(false);
        else if (p.type === "drop") {
          setDragActive(false);
          const path = p.paths.find((f) =>
            IMAGE_EXTENSIONS.includes(f.split(".").pop()?.toLowerCase() ?? ""),
          );
          const { importImage: load, selectedTemplateId: id } = importRef.current;
          if (!path) setImageError("That file isn't an image. Try a PNG, JPG, or WEBP.");
          else if (id) void load(path, id);
        }
      })
      .then((fn) => {
        if (cancelled) fn();
        else unlisten = fn;
      })
      .catch(() => {
        // No webview (e.g. running in a plain browser): drag and drop is unavailable.
      });
    return () => {
      cancelled = true;
      unlisten?.();
    };
  }, []);

  const currentStep: StepId = !template ? 1 : !image || !usable ? 2 : 3;
  const completed: Record<StepId, boolean> = {
    1: template !== null,
    2: usable && derived !== null,
    3: exportResult?.ok === true,
  };

  const goToStep = (step: StepId) => {
    const section = document.getElementById(`step-${step}-title`)?.closest("section");
    section?.scrollIntoView({ behavior: "smooth", block: "start" });
    section
      ?.querySelector<HTMLElement>('[role="radio"][tabindex="0"], button, input')
      ?.focus({ preventScroll: true });
  };

  // Highest resolution this image can fill, offered when it's too small.
  const suggestion =
    image && tooSmall
      ? ([...templates]
          .filter((t) => {
            const min = minImageSize(t, config?.zoomoutOverride ?? null);
            return image.width >= min.w && image.height >= min.h;
          })
          .sort((a, b) => b.localcoordW * b.localcoordH - a.localcoordW * a.localcoordH)[0] ?? null)
      : null;

  return (
    <div className="flex h-full flex-col bg-bg text-ink">
      <Header
        currentStep={currentStep}
        completed={completed}
        onStepClick={goToStep}
        detailsOpen={detailsOpen}
        onToggleDetails={toggleDetails}
        theme={theme}
        onToggleTheme={() => setTheme((t) => (t === "dark" ? "light" : "dark"))}
      />

      <div className="flex min-h-0 flex-1">
        <aside className="flex w-[380px] shrink-0 flex-col border-r border-line bg-surface">
          <div className="min-h-0 flex-1 space-y-7 overflow-y-auto px-5 py-5">
            <TemplatePicker
              templates={templates}
              setTemplates={setTemplates}
              selectedTemplateId={selectedTemplateId}
              setSelectedTemplateId={selectTemplate}
              imageUrl={image?.url ?? null}
            />

            {template && (
              <ImageImport
                template={template}
                image={image}
                fit={fit}
                derived={derived}
                error={imageError}
                zoomoutOverride={config?.zoomoutOverride ?? null}
                onZoomChange={(zoomoutOverride) =>
                  setConfig((prev) => prev && { ...prev, zoomoutOverride })
                }
                onBrowse={browseForImage}
                onRemove={removeImage}
                suggestion={suggestion}
                onUseSuggestion={selectTemplate}
              />
            )}

            {config && (
              <StageNameFields
                config={config}
                setConfig={setConfig}
                onAuthorChange={(author) => {
                  writeStored(AUTHOR_KEY, author);
                  setConfig({ ...config, author });
                }}
                outputDir={outputDir}
                onChooseDir={chooseOutputDir}
                defReady={nameOk && derived !== null}
                sffReady={derived !== null}
              />
            )}
          </div>

          {config && (
            <ExportBar blockedReason={blockedReason} exporting={exporting} onExport={runExport} />
          )}
        </aside>

        <main className="relative flex min-w-0 flex-1 flex-col p-4">
          {template ? (
            <StagePreview
              template={template}
              imageUrl={usable ? (image?.url ?? null) : null}
              derived={derived}
              nativeHeight={config?.bgImageHeight ?? null}
              onFloorChange={(floorY) => setConfig((prev) => prev && { ...prev, floorY })}
              onBrowse={browseForImage}
              stamp={stamp}
              overlay={
                exportResult && (
                  <ExportResultPanel result={exportResult} onDismiss={() => setExportResult(null)} />
                )
              }
            />
          ) : (
            <div className="grid flex-1 place-items-center text-muted">Loading resolutions…</div>
          )}

          {detailsOpen && template && (
            <DetailsDrawer template={template} derived={derived} def={def} onClose={toggleDetails} />
          )}
        </main>
      </div>

      {dragActive && (
        <div className="pointer-events-none fixed inset-0 z-50 grid place-items-center bg-bg/80 backdrop-blur-sm">
          <div className="flex flex-col items-center gap-3 rounded-2xl border-4 border-dashed border-p2 px-14 py-10 text-p2">
            <ImagePlus size={40} />
            <span className="-skew-x-6 font-display text-[44px] leading-none tracking-wider text-ink">
              Drop it here!
            </span>
            <span className="text-[14px] text-muted">Release to use this image as your background</span>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
