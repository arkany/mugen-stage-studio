// Switch the running app's icon between the bundled choices.
//
// This changes the icon while the app runs: the macOS Dock tile, and the
// window / taskbar icon on Windows and Linux. The icon baked into the
// installed bundle (Finder, Start menu) stays the default; the frontend
// re-applies the saved choice at every launch.

use tauri::image::Image;
use tauri::{AppHandle, Manager};

const TORII_SUNSET: &[u8] = include_bytes!("../icons/choices/torii-sunset.png");
const INK_M: &[u8] = include_bytes!("../icons/choices/ink-m.png");

fn icon_bytes(id: &str) -> Result<&'static [u8], String> {
    match id {
        "torii-sunset" => Ok(TORII_SUNSET),
        "ink-m" => Ok(INK_M),
        other => Err(format!("Unknown app icon: {other}")),
    }
}

#[tauri::command]
pub fn set_app_icon(app: AppHandle, id: String) -> Result<(), String> {
    let bytes = icon_bytes(&id)?;

    // Window and taskbar icon (a no-op on macOS, where the Dock tile is used).
    if let Some(window) = app.get_webview_window("main") {
        let image = Image::from_bytes(bytes).map_err(|e| e.to_string())?;
        window.set_icon(image).map_err(|e| e.to_string())?;
    }

    #[cfg(target_os = "macos")]
    app.run_on_main_thread(move || set_dock_icon(bytes))
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[cfg(target_os = "macos")]
fn set_dock_icon(png: &'static [u8]) {
    use objc2::{AllocAnyThread, MainThreadMarker};
    use objc2_app_kit::{NSApplication, NSImage};
    use objc2_foundation::NSData;

    // run_on_main_thread guarantees we are on the main thread.
    let Some(mtm) = MainThreadMarker::new() else { return };
    let data = NSData::with_bytes(png);
    let Some(image) = NSImage::initWithData(NSImage::alloc(), &data) else { return };
    let app = NSApplication::sharedApplication(mtm);
    unsafe { app.setApplicationIconImage(Some(&image)) };
}
