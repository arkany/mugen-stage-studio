// Small platform helper so copy and shortcut labels match the user's OS.
// userAgent is enough here — we only need Mac vs everything else, and it
// avoids pulling in @tauri-apps/plugin-os for two strings.

export type Platform = "mac" | "windows" | "linux";

export const platform: Platform = (() => {
  const ua = typeof navigator === "undefined" ? "" : navigator.userAgent;
  if (/Mac|iPhone|iPad/.test(ua)) return "mac";
  if (/Windows/.test(ua)) return "windows";
  return "linux";
})();

export const isMac = platform === "mac";

/** Label for a Cmd/Ctrl shortcut, e.g. `shortcutLabel("O")` → "⌘O" or "Ctrl+O". */
export function shortcutLabel(key: string): string {
  return isMac ? `⌘${key}` : `Ctrl+${key}`;
}

/** True when the platform's primary modifier (Cmd on Mac, Ctrl elsewhere) is held. */
export function hasPrimaryModifier(e: KeyboardEvent): boolean {
  return isMac ? e.metaKey && !e.ctrlKey : e.ctrlKey && !e.metaKey;
}

export const fileManagerName =
  platform === "mac" ? "Finder" : platform === "windows" ? "Explorer" : "File Manager";
