// The app icons a user can switch between. Ids match src-tauri/src/app_icon.rs.

import toriiSunset from "../assets/app-icon-torii-sunset.webp";
import inkM from "../assets/app-icon-ink-m.webp";

export interface AppIconChoice {
  id: string;
  name: string;
  thumb: string;
}

export const APP_ICONS: AppIconChoice[] = [
  { id: "torii-sunset", name: "Torii sunset", thumb: toriiSunset },
  { id: "ink-m", name: "Ink M", thumb: inkM },
];

export const DEFAULT_APP_ICON = "torii-sunset";
