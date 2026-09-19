// MUGEN Stage Studio — Tauri backend entry point.
//
// The stage geometry, templates and DEF writing all live in the `stage-core`
// crate; this crate is the desktop shell around them. Keeping them apart means
// the arithmetic that decides whether a stage actually works is testable
// without a GUI toolchain — run `cargo test -p stage-core`.

mod app_icon;
mod commands;
mod export;
mod image_check;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            commands::get_templates,
            commands::load_image,
            commands::derive_stage,
            commands::preview_def,
            commands::default_output_dir,
            commands::export_stage,
            app_icon::set_app_icon,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
