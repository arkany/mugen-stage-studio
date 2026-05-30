// MUGEN Stage Studio — Tauri backend entry point.
//
// Phase 4a scaffold: registers the three command stubs (`get_templates`,
// `load_image`, `export_stage`) so the React frontend can call them via
// `invoke`. Phase 4b will replace the stubs with real implementations.

mod commands;
mod image_check;
mod stage_config;
mod templates;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            commands::get_templates,
            commands::load_image,
            commands::export_stage,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
