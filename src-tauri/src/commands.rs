use crate::def_writer;
use crate::image_check;
use crate::sff_writer;
use crate::stage_config::{ConformanceState, StageConfig};
use crate::templates::{self, StageTemplate};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use tauri_plugin_dialog::DialogExt;
use zip::write::SimpleFileOptions;

#[tauri::command]
pub fn get_templates() -> Vec<StageTemplate> {
    templates::ALL_TEMPLATES.to_vec()
}

#[tauri::command]
pub async fn load_image(app: tauri::AppHandle, template_id: String) -> Result<StageConfig, String> {
    let template = templates::by_id(&template_id)
        .ok_or_else(|| format!("Unknown stage template: {template_id}"))?;
    let image_path = app
        .dialog()
        .file()
        .add_filter("Images", &["png", "jpg", "jpeg"])
        .blocking_pick_file()
        .ok_or_else(|| "Image selection cancelled".to_string())?
        .into_path()
        .map_err(|e| format!("Selected image path is not available: {e}"))?;
    let image_path = image_path.to_string_lossy().into_owned();
    let dimensions = image_check::read_dimensions(&image_path)
        .ok_or_else(|| "Could not read PNG/JPEG image dimensions".to_string())?;
    let mut config = StageConfig::empty_for_template(&template_id);
    config.bg_image_path = Some(image_path.clone());
    config.bg_image_width = Some(dimensions.0);
    config.bg_image_height = Some(dimensions.1);
    config.conformance_state = image_check::check_image_conformance(&image_path, template);
    Ok(config)
}

#[tauri::command]
pub async fn export_stage(app: tauri::AppHandle, config: StageConfig) -> Result<String, String> {
    let output_dir = app
        .dialog()
        .file()
        .set_title("Choose export folder")
        .blocking_pick_folder()
        .ok_or_else(|| "Export cancelled".to_string())?
        .into_path()
        .map_err(|e| format!("Selected output folder is not available: {e}"))?;

    export_stage_to_dir(config, &output_dir)
}

fn export_stage_to_dir(_config: StageConfig, _output_dir: &Path) -> Result<String, String> {
    let config = _config;
    if config.name.trim().is_empty() {
        return Err("Stage name is required".to_string());
    }
    let template = templates::by_id(&config.template_id)
        .ok_or_else(|| format!("Unknown stage template: {}", config.template_id))?;
    let bg_image_path = config
        .bg_image_path
        .as_deref()
        .ok_or_else(|| "Choose a background image before exporting".to_string())?;
    if !matches!(
        config.conformance_state,
        ConformanceState::Correct
            | ConformanceState::FixableWithCrop { .. }
            | ConformanceState::FixableWithExtend { .. }
    ) {
        return Err("Choose an image that matches, can be cropped, or can be padded".to_string());
    }

    let slug = stage_slug(&config.name);
    let sff_filename = format!("{slug}.sff");
    let def_path: PathBuf = _output_dir.join(format!("{slug}.def"));
    let sff_path: PathBuf = _output_dir.join(&sff_filename);
    let zip_path: PathBuf = _output_dir.join(format!("{slug}.zip"));

    sff_writer::write_sff(&sff_path, bg_image_path, template, &config.conformance_state)?;
    def_writer::write_def(
        &def_path,
        &sff_filename,
        config.name.trim(),
        config.author.trim(),
        config.music.as_deref(),
        template,
    )?;
    write_stage_zip(&zip_path, &slug, &def_path, &sff_path)?;

    Ok(_output_dir.to_string_lossy().into_owned())
}

fn write_stage_zip(
    zip_path: &Path,
    slug: &str,
    def_path: &Path,
    sff_path: &Path,
) -> Result<(), String> {
    let zip_file =
        fs::File::create(zip_path).map_err(|e| format!("Failed to create ZIP package: {e}"))?;
    let mut zip = zip::ZipWriter::new(zip_file);
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);

    for source_path in [def_path, sff_path] {
        let file_name = source_path
            .file_name()
            .and_then(|name| name.to_str())
            .ok_or_else(|| "Exported file has an invalid filename".to_string())?;
        let entry_name = format!("{slug}/{file_name}");
        let bytes = fs::read(source_path)
            .map_err(|e| format!("Failed to read exported file for ZIP package: {e}"))?;
        zip.start_file(entry_name, options)
            .map_err(|e| format!("Failed to add file to ZIP package: {e}"))?;
        zip.write_all(&bytes)
            .map_err(|e| format!("Failed to write ZIP package: {e}"))?;
    }

    zip.finish()
        .map_err(|e| format!("Failed to finish ZIP package: {e}"))?;
    Ok(())
}

fn stage_slug(name: &str) -> String {
    let mut slug = String::new();
    let mut previous_was_separator = false;

    for ch in name.trim().chars() {
        if ch.is_ascii_alphanumeric() {
            slug.push(ch);
            previous_was_separator = false;
        } else if (ch.is_ascii_whitespace() || ch == '_' || ch == '-') && !previous_was_separator {
            slug.push('_');
            previous_was_separator = true;
        }
    }

    while slug.ends_with('_') {
        slug.pop();
    }

    if slug.is_empty() {
        "stage".to_string()
    } else {
        slug
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::stage_config::ConformanceState;
    use crate::templates::T1;
    use image::{ImageBuffer, Rgba};
    use std::fs;
    use tempfile::{tempdir, TempDir};

    fn write_png(width: u32, height: u32) -> (TempDir, String) {
        let dir = tempdir().expect("temp dir");
        let path = dir.path().join(format!("{width}x{height}.png"));
        let image = ImageBuffer::from_pixel(width, height, Rgba([80u8, 90, 100, 255]));
        image.save(&path).expect("write png");
        (dir, path.to_string_lossy().into_owned())
    }

    fn valid_config(image_path: String) -> StageConfig {
        StageConfig {
            name: "My Stage!".to_string(),
            author: "Tester".to_string(),
            music: None,
            template_id: T1.id.to_string(),
            bg_image_path: Some(image_path),
            bg_image_width: Some(T1.bg_width),
            bg_image_height: Some(T1.bg_height),
            conformance_state: ConformanceState::Correct,
        }
    }

    #[test]
    fn creates_slug_from_stage_name() {
        assert_eq!(stage_slug("My Stage! 2026"), "My_Stage_2026");
        assert_eq!(stage_slug("***"), "stage");
    }

    #[test]
    fn export_to_dir_writes_def_and_sff() {
        let (_image_dir, image_path) = write_png(T1.bg_width, T1.bg_height);
        let output_dir = tempdir().expect("output dir");

        let result = export_stage_to_dir(valid_config(image_path), output_dir.path())
            .expect("export stage");

        assert_eq!(result, output_dir.path().to_string_lossy());
        let sff = output_dir.path().join("My_Stage.sff");
        let def = output_dir.path().join("My_Stage.def");
        assert!(sff.exists());
        assert!(def.exists());
        assert!(fs::read_to_string(def).expect("read def").contains("spr = My_Stage.sff"));
    }

    #[test]
    fn export_to_dir_writes_importable_zip_package() {
        let (_image_dir, image_path) = write_png(T1.bg_width, T1.bg_height);
        let output_dir = tempdir().expect("output dir");

        export_stage_to_dir(valid_config(image_path), output_dir.path()).expect("export stage");

        let zip_path = output_dir.path().join("My_Stage.zip");
        assert!(zip_path.exists());
        let zip_file = fs::File::open(zip_path).expect("open zip");
        let mut archive = zip::ZipArchive::new(zip_file).expect("read zip");
        assert!(archive.by_name("My_Stage/My_Stage.def").is_ok());
        assert!(archive.by_name("My_Stage/My_Stage.sff").is_ok());
    }

    #[test]
    fn export_rejects_empty_name() {
        let (_image_dir, image_path) = write_png(T1.bg_width, T1.bg_height);
        let output_dir = tempdir().expect("output dir");
        let mut config = valid_config(image_path);
        config.name = "   ".to_string();

        let err = export_stage_to_dir(config, output_dir.path()).expect_err("validation error");

        assert!(err.contains("Stage name"));
    }

    #[test]
    fn export_fixture_from_env_when_present() {
        let Ok(image_path) = std::env::var("MUGEN_STAGE_FIXTURE_IMAGE") else {
            return;
        };
        let output_dir = std::env::var("MUGEN_STAGE_FIXTURE_OUT")
            .map(PathBuf::from)
            .unwrap_or_else(|_| tempdir().expect("temp dir").keep());
        fs::create_dir_all(&output_dir).expect("create fixture output dir");

        let mut config = valid_config(image_path);
        config.name = "Apple Fixture".to_string();

        export_stage_to_dir(config, &output_dir).expect("export fixture");

        assert!(output_dir.join("Apple_Fixture.def").exists());
        assert!(output_dir.join("Apple_Fixture.sff").exists());
        assert!(output_dir.join("Apple_Fixture.zip").exists());
    }
}
