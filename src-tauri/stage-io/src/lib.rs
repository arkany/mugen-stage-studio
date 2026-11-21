// File I/O for MUGEN Stage Studio: reading a backdrop's dimensions on import
// and writing the exported `.def` and `.sff`.
//
// `stage-core` decides every number; this crate only reads and writes files.
// It is kept apart from the Tauri shell so its tests, including the full
// export round trip, run in CI without a GUI toolchain.

pub mod export;
pub mod image_check;
