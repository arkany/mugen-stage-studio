// Step 3 (name, music, save folder), the pinned Export bar, and the export
// outcome shown over the stage preview. The .def and .sff come from one
// backend derivation, so they cannot disagree with the preview.

import { useEffect, useRef, useState } from "react";
import { Check, ChevronDown, CheckCircle2, Circle, Copy, ExternalLink, FolderOpen, Loader2, X } from "lucide-react";
import { revealItemInDir } from "@tauri-apps/plugin-opener";
import type { ExportResult, IkemenLab, InstallResult, StageConfig } from "../types/stage";
import { openIkemenLab } from "../hooks/useTauriCommands";
import { fileManagerName, shortcutLabel } from "../lib/platform";
import { SectionHeading } from "./SectionHeading";
import exportPlate from "../assets/export-plate.webp";

/** Where Export writes: into the IKEMEN GO folder IKEMEN Lab manages, or a folder of the user's choosing. */
export type Destination = "ikemen" | "folder";

export type ExportOutcome =
  | { ok: true; result: ExportResult; install: InstallResult | null }
  | { ok: false; message: string; destination: Destination };

const inputClass =
  "w-full rounded-md border border-line-strong bg-sunken px-3 py-2 text-[14px] text-ink placeholder:text-muted/70 outline-none transition-colors focus:border-p2 focus:ring-2 focus:ring-p2-soft";

/** Mirrors `file_stem` in src-tauri/src/export.rs so the preview names the files that get written. */
function fileStem(name: string): string {
  return name.trim().replace(/[^A-Za-z0-9_-]/gu, "_") || "stage";
}

/** Step 3: name, author, music, where to save, and the files that will be written. */
export function StageNameFields({
  config,
  setConfig,
  onAuthorChange,
  outputDir,
  onChooseDir,
  lab,
  destination,
  onDestinationChange,
  defReady,
  sffReady,
}: {
  config: StageConfig;
  setConfig: (c: StageConfig) => void;
  onAuthorChange: (author: string) => void;
  outputDir: string;
  onChooseDir: () => void;
  /** IKEMEN Lab, when installed; null hides the IKEMEN GO option. */
  lab: IkemenLab | null;
  /** The effective destination (already falls back to "folder" when IKEMEN GO isn't usable). */
  destination: Destination;
  onDestinationChange: (d: Destination) => void;
  defReady: boolean;
  sffReady: boolean;
}) {
  const base = fileStem(config.name);
  const toIkemen = destination === "ikemen";
  const files = [
    { file: `${base}.def`, desc: "Stage settings: camera, floor and screen edges", ready: defReady },
    { file: `${base}.sff`, desc: "Your background image, packed for the game", ready: sffReady },
    ...(toIkemen
      ? [{ file: "select.def", desc: "Adds it to the game's stage select", ready: defReady }]
      : []),
  ];
  return (
    <section aria-labelledby="step-3-title">
      <SectionHeading
        step={3}
        id="step-3-title"
        title="Name your stage"
        subtitle="Give it a name, then export it for MUGEN or IKEMEN GO."
      />
      <div className="grid grid-cols-2 gap-2.5">
        <label className="block">
          <span className="mb-1 block text-[12px] font-semibold text-muted">Stage name</span>
          <input
            type="text"
            value={config.name}
            onChange={(e) => setConfig({ ...config, name: e.target.value })}
            className={inputClass}
            placeholder="Sunset Temple"
            spellCheck={false}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-[12px] font-semibold text-muted">
            Author <span className="font-normal">(optional)</span>
          </span>
          <input
            type="text"
            value={config.author}
            onChange={(e) => onAuthorChange(e.target.value)}
            className={inputClass}
            placeholder="Your name"
            spellCheck={false}
          />
        </label>
      </div>

      <label className="mt-2.5 block">
        <span className="mb-1 block text-[12px] font-semibold text-muted">
          Music <span className="font-normal">(optional)</span>
        </span>
        <input
          type="text"
          value={config.music ?? ""}
          onChange={(e) => setConfig({ ...config, music: e.target.value || null })}
          className={inputClass}
          placeholder="sound/yourtrack.ogg"
          spellCheck={false}
        />
      </label>

      {lab ? (
        <DestinationPicker
          lab={lab}
          destination={destination}
          onChange={onDestinationChange}
          outputDir={outputDir}
          onChooseDir={onChooseDir}
        />
      ) : (
        <div className="mt-2.5">
          <span className="mb-1 block text-[12px] font-semibold text-muted">Save to</span>
          <div className="flex items-center gap-2">
            <PathBox path={outputDir} placeholder="Choose a folder" boxed />
            <ChangeButton onClick={onChooseDir} />
          </div>
        </div>
      )}

      <h3 className="mt-4 mb-2 text-[12px] font-semibold text-muted">What you'll get</h3>
      <ul className="space-y-2">
        {files.map((f) => (
          <li key={f.file} className="flex items-start gap-2.5">
            {f.ready ? (
              <CheckCircle2 size={17} className="mt-px shrink-0 text-good" aria-hidden />
            ) : (
              <Circle size={17} className="mt-px shrink-0 text-line-strong" aria-hidden />
            )}
            <div className="min-w-0">
              <div className="truncate font-mono text-[13px] font-semibold">
                {f.file}
                <span className="sr-only">{f.ready ? " (ready)" : " (not ready yet)"}</span>
              </div>
              <div className="text-[12px] text-muted">{f.desc}</div>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Right-aligned path that truncates from the left, so the folder name stays visible. */
function PathBox({ path, placeholder, boxed }: { path: string; placeholder: string; boxed?: boolean }) {
  return (
    <div
      className={
        "min-w-0 flex-1 truncate font-mono text-[12px] text-muted " +
        (boxed ? "rounded-md border border-line bg-sunken px-3 py-2" : "")
      }
      title={path || undefined}
      dir="rtl"
    >
      <bdi>{path || placeholder}</bdi>
    </div>
  );
}

function ChangeButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="shrink-0 rounded-md border border-line-strong px-3 py-2 text-[13px] font-semibold hover:bg-raised"
    >
      Change…
    </button>
  );
}

/** "Save to" when IKEMEN Lab is installed: straight into IKEMEN GO, or a folder. */
function DestinationPicker({
  lab,
  destination,
  onChange,
  outputDir,
  onChooseDir,
}: {
  lab: IkemenLab;
  destination: Destination;
  onChange: (d: Destination) => void;
  outputDir: string;
  onChooseDir: () => void;
}) {
  const [openError, setOpenError] = useState<string | null>(null);
  const ready = lab.problem === null && lab.ikemenGoPath !== null;
  const option = (checked: boolean, disabled = false) =>
    "flex min-w-0 flex-1 items-start gap-2.5 rounded-md border px-3 py-2 transition-colors " +
    (disabled
      ? "cursor-not-allowed border-line opacity-70"
      : checked
        ? "cursor-pointer border-p2 bg-p2-soft"
        : "cursor-pointer border-line hover:bg-raised");

  return (
    <fieldset className="mt-2.5 min-w-0">
      <legend className="mb-1 block text-[12px] font-semibold text-muted">Save to</legend>
      <div className="space-y-1.5">
        <label className={option(destination === "ikemen", !ready)}>
          <input
            type="radio"
            name="destination"
            value="ikemen"
            checked={destination === "ikemen"}
            disabled={!ready}
            onChange={() => onChange("ikemen")}
            className="mt-[3px] accent-p2"
          />
          <div className="min-w-0 flex-1">
            <div className="text-[13px] font-semibold">
              IKEMEN GO <span className="font-normal text-muted">· via IKEMEN Lab</span>
            </div>
            {ready ? (
              <PathBox path={`${lab.ikemenGoPath}/stages`} placeholder="" />
            ) : (
              <div className="text-[12px] text-warn">{lab.problem}</div>
            )}
          </div>
        </label>
        {!ready && (
          <button
            type="button"
            onClick={() => openIkemenLab().catch((e) => setOpenError(String(e)))}
            className="ml-8 inline-flex items-center gap-1 text-[12px] font-semibold text-p2 hover:underline"
          >
            <ExternalLink size={13} aria-hidden /> Open IKEMEN Lab
          </button>
        )}
        {openError && <div className="ml-8 text-[12px] text-bad">{openError}</div>}

        <div className="flex items-center gap-2">
          <label className={option(destination === "folder")}>
            <input
              type="radio"
              name="destination"
              value="folder"
              checked={destination === "folder"}
              onChange={() => onChange("folder")}
              className="mt-[3px] accent-p2"
            />
            <div className="min-w-0 flex-1">
              <div className="text-[13px] font-semibold">A folder</div>
              <PathBox path={outputDir} placeholder="Choose a folder" />
            </div>
          </label>
          <ChangeButton onClick={onChooseDir} />
        </div>
      </div>
    </fieldset>
  );
}

/** The pinned Export action at the bottom of the rail. */
export function ExportBar({
  blockedReason,
  exporting,
  onExport,
  destination,
}: {
  blockedReason: string | null;
  exporting: boolean;
  onExport: () => void;
  destination: Destination;
}) {
  const disabled = blockedReason !== null || exporting;
  return (
    <div className="shrink-0 border-t border-line bg-surface px-5 pt-2 pb-3">
      <button
        type="button"
        onClick={onExport}
        disabled={disabled}
        aria-describedby="export-hint"
        style={{ backgroundImage: `url(${exportPlate})` }}
        className="mx-auto grid aspect-[900/289] w-full max-w-[300px] place-items-center bg-[length:100%_100%] bg-no-repeat drop-shadow-[0_8px_18px_rgb(255_70_85/0.35)] transition-[transform,filter] duration-150 hover:scale-[1.03] hover:brightness-110 active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-40 disabled:drop-shadow-none disabled:grayscale disabled:hover:scale-100 disabled:hover:brightness-100"
      >
        <span className="flex -rotate-[8deg] items-center gap-2 font-display text-[28px] leading-none tracking-wider text-white [paint-order:stroke] [-webkit-text-stroke:5px_rgb(40_4_8)] [text-shadow:0_3px_0_rgb(40_4_8)]">
          {exporting && <Loader2 size={22} className="animate-spin" aria-hidden />}
          {exporting ? (destination === "ikemen" ? "Installing…" : "Exporting…") : "Export stage"}
        </span>
      </button>
      <p id="export-hint" className="mt-1 text-center text-[12px] text-muted">
        {blockedReason ?? (
          <>
            {destination === "ikemen" ? "Installs it into IKEMEN GO" : "Saves a .def and .sff pair"} · <kbd className="font-mono">{shortcutLabel("E")}</kbd>
          </>
        )}
      </p>
    </div>
  );
}

/** Export outcome, shown over the stage preview where the user is looking. */
export function ExportResultPanel({
  result,
  onDismiss,
}: {
  result: ExportOutcome;
  onDismiss: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    ref.current?.focus();
  }, [result]);

  return (
    <div
      ref={ref}
      tabIndex={-1}
      role={result.ok ? "status" : "alert"}
      onKeyDown={(e) => e.key === "Escape" && onDismiss()}
      className={
        "pop relative w-[min(520px,calc(100%-2rem))] rounded-xl border p-4 pr-10 text-[13px] shadow-2xl backdrop-blur-md outline-none focus-visible:ring-2 focus-visible:ring-p2 " +
        (result.ok ? "border-good/50 bg-surface/95" : "border-warn/50 bg-surface/95")
      }
    >
      <button
        type="button"
        onClick={onDismiss}
        aria-label="Dismiss"
        className="absolute top-2.5 right-2.5 grid size-7 place-items-center rounded-md text-muted hover:bg-raised hover:text-ink"
      >
        <X size={16} />
      </button>
      {!result.ok ? (
        <ExportError raw={result.message} destination={result.destination} />
      ) : result.install ? (
        <InstallSuccess install={result.install} />
      ) : (
        <ExportSuccess result={result.result} />
      )}
    </div>
  );
}

function ExportSuccess({ result }: { result: ExportResult }) {
  const [revealError, setRevealError] = useState<string | null>(null);
  return (
    <>
      <div className="font-display text-[26px] leading-none tracking-wider text-good">Stage ready!</div>
      <p className="mt-1 text-muted">
        Saved with a {result.backdropWidth} × {result.backdropHeight} background
        {result.resampled ? ", resized to fill the screen" : ""}.
      </p>
      <div className="mt-1 break-all font-mono text-[12px] text-muted select-text">
        {result.defPath}
        <br />
        {result.sffPath}
      </div>
      <button
        type="button"
        onClick={() => revealItemInDir(result.defPath).catch((e) => setRevealError(String(e)))}
        className="mt-2 inline-flex items-center gap-1.5 rounded-md border border-line-strong bg-raised px-2.5 py-1 text-[12px] font-semibold hover:border-p2"
      >
        <FolderOpen size={14} /> Show in {fileManagerName}
      </button>
      {revealError && <div className="mt-1 text-bad">{revealError}</div>}
      <p className="mt-3 text-muted">
        To play it, copy the files into your game's <code className="font-mono">stages</code> folder and add the{" "}
        <code className="font-mono">.def</code> under <code className="font-mono">[ExtraStages]</code> in{" "}
        <code className="font-mono">data/select.def</code>.
      </p>
    </>
  );
}

function InstallSuccess({ install }: { install: InstallResult }) {
  const [actionError, setActionError] = useState<string | null>(null);
  const { export: result } = install;
  const buttonClass =
    "inline-flex items-center gap-1.5 rounded-md border border-line-strong bg-raised px-2.5 py-1 text-[12px] font-semibold hover:border-p2";
  return (
    <>
      <div className="font-display text-[26px] leading-none tracking-wider text-good">
        {install.replaced ? "Stage updated!" : "Stage installed!"}
      </div>
      <p className="mt-1 text-muted">
        {install.replaced
          ? "Your earlier version in IKEMEN GO was replaced."
          : "It's in IKEMEN GO's stage select, ready for your next match."}{" "}
        {result.backdropWidth} × {result.backdropHeight} background
        {result.resampled ? ", resized to fill the screen" : ""}.
      </p>
      <div className="mt-1 break-all font-mono text-[12px] text-muted select-text">
        {result.defPath}
        <br />
        {result.sffPath}
      </div>
      <div className="mt-2 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => openIkemenLab().catch((e) => setActionError(String(e)))}
          className={buttonClass}
        >
          <ExternalLink size={14} /> Open IKEMEN Lab
        </button>
        <button
          type="button"
          onClick={() => revealItemInDir(result.defPath).catch((e) => setActionError(String(e)))}
          className={buttonClass}
        >
          <FolderOpen size={14} /> Show in {fileManagerName}
        </button>
      </div>
      {actionError && <div className="mt-1 text-bad">{actionError}</div>}
      <p className="mt-3 text-muted">If IKEMEN Lab is already open, click Refresh there to see it.</p>
    </>
  );
}

function ExportError({ raw, destination }: { raw: string; destination: Destination }) {
  // Install failures are phrased for the user (a name clash, a missing folder), so show them up front.
  const [open, setOpen] = useState(destination === "ikemen");
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(raw);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard can be unavailable; the text is still visible to select.
    }
  };

  return (
    <>
      <div className="font-bold text-warn">
        {destination === "ikemen" ? "Couldn't install into IKEMEN GO" : "Export didn't finish"}
      </div>
      <div className="text-muted">
        {destination === "ikemen"
          ? "Your settings are kept. The details below say what went wrong. You can also choose A folder and export there instead."
          : "Your settings are kept. Check that the save folder exists and you can write to it, then try again."}{" "}
        If it keeps failing, copy the details below and report them.
      </div>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="mt-1.5 inline-flex items-center gap-1 text-[12px] font-semibold text-muted hover:text-ink"
      >
        <ChevronDown size={14} className={open ? "rotate-180 transition-transform" : "transition-transform"} />
        Technical details
      </button>
      {open && (
        <div className="mt-1.5 flex items-start gap-2 rounded-md bg-sunken p-2">
          <code className="min-w-0 flex-1 break-all font-mono text-[12px] select-text">{raw}</code>
          <button
            type="button"
            onClick={copy}
            aria-label="Copy details"
            className="grid size-6 shrink-0 place-items-center rounded text-muted hover:text-ink"
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
          </button>
        </div>
      )}
    </>
  );
}
