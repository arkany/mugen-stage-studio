use std::{fs, path::Path};

use image::{imageops, Rgba, RgbaImage};

use crate::stage_config::ConformanceState;
use crate::templates::StageTemplate;

pub fn write_sff(
    output_path: &Path,
    bg_image_path: &str,
    template: &StageTemplate,
    conformance: &ConformanceState,
) -> Result<(), String> {
    let source = image::open(bg_image_path)
        .map_err(|e| format!("Failed to read background image: {e}"))?
        .to_rgba8();
    let transformed = transform_image(source, template, conformance)?;
    let pcx = encode_pcx_8(&transformed)?;

    let mut bytes = vec![0u8; 512];
    bytes[0..12].copy_from_slice(b"ElecbyteSpr\0");
    bytes[12..16].copy_from_slice(&[0, 1, 0, 1]);
    write_u32(&mut bytes, 16, 1);
    write_u32(&mut bytes, 20, 1);
    write_u32(&mut bytes, 24, 512);
    write_u32(&mut bytes, 28, 32);
    bytes[32] = 0;

    let mut subfile = vec![0u8; 32];
    write_u32(&mut subfile, 0, 0);
    write_u32(
        &mut subfile,
        4,
        u32::try_from(pcx.len()).map_err(|_| "PCX payload is too large".to_string())?,
    );
    write_i16(&mut subfile, 8, checked_i16(template.axis_x, "axis_x")?);
    write_i16(&mut subfile, 10, checked_i16(template.axis_y, "axis_y")?);
    write_u16(&mut subfile, 12, 0);
    write_u16(&mut subfile, 14, 0);
    write_u16(&mut subfile, 16, 0);
    subfile[18] = 0;

    bytes.extend_from_slice(&subfile);
    bytes.extend_from_slice(&pcx);
    fs::write(output_path, bytes).map_err(|e| format!("Failed to write SFF: {e}"))
}

fn transform_image(
    source: RgbaImage,
    template: &StageTemplate,
    conformance: &ConformanceState,
) -> Result<RgbaImage, String> {
    match conformance {
        ConformanceState::Correct => {
            if source.width() == template.bg_width && source.height() == template.bg_height {
                Ok(source)
            } else {
                Err("Image dimensions no longer match the selected template".to_string())
            }
        }
        ConformanceState::FixableWithCrop { crop_x, crop_y } => {
            if source.width() < template.bg_width || source.height() < template.bg_height {
                return Err("Image is too small to crop to the selected template".to_string());
            }
            Ok(imageops::crop_imm(
                &source,
                *crop_x,
                *crop_y,
                template.bg_width,
                template.bg_height,
            )
            .to_image())
        }
        ConformanceState::FixableWithExtend { pad_x, pad_y } => {
            if source.width() > template.bg_width || source.height() > template.bg_height {
                return Err("Image is too large for the selected padding operation".to_string());
            }
            let mut canvas =
                RgbaImage::from_pixel(template.bg_width, template.bg_height, Rgba([0, 0, 0, 255]));
            imageops::overlay(&mut canvas, &source, i64::from(*pad_x), i64::from(*pad_y));
            Ok(canvas)
        }
        ConformanceState::NoImage | ConformanceState::TooSmall => {
            Err("Choose an image that matches, can be cropped, or can be padded".to_string())
        }
    }
}

fn encode_pcx_8(image: &RgbaImage) -> Result<Vec<u8>, String> {
    let width = checked_u16(image.width(), "width")?;
    let height = checked_u16(image.height(), "height")?;
    let bytes_per_line = if width % 2 == 0 { width } else { width + 1 };
    let mut bytes = vec![0u8; 128];
    bytes[0] = 0x0A;
    bytes[1] = 5;
    bytes[2] = 1;
    bytes[3] = 8;
    write_u16(&mut bytes, 4, 0);
    write_u16(&mut bytes, 6, 0);
    write_u16(&mut bytes, 8, width - 1);
    write_u16(&mut bytes, 10, height - 1);
    write_u16(&mut bytes, 12, width);
    write_u16(&mut bytes, 14, height);
    bytes[65] = 1;
    write_u16(&mut bytes, 66, bytes_per_line);
    write_u16(&mut bytes, 68, 1);
    write_u16(&mut bytes, 70, width);
    write_u16(&mut bytes, 72, height);

    for y in 0..image.height() {
        let mut line = Vec::with_capacity(bytes_per_line as usize);
        for x in 0..image.width() {
            line.push(rgb_to_palette_index(image.get_pixel(x, y).0));
        }
        if line.len() < bytes_per_line as usize {
            line.push(0);
        }
        write_pcx_rle(&line, &mut bytes);
    }

    bytes.push(12);
    bytes.extend_from_slice(&ega_332_palette());
    Ok(bytes)
}

fn rgb_to_palette_index(rgba: [u8; 4]) -> u8 {
    let r = rgba[0] >> 5;
    let g = rgba[1] >> 5;
    let b = rgba[2] >> 6;
    (r << 5) | (g << 2) | b
}

fn ega_332_palette() -> [u8; 768] {
    let mut palette = [0u8; 768];
    for index in 0..=255usize {
        let r = ((index >> 5) & 0x07) as u8;
        let g = ((index >> 2) & 0x07) as u8;
        let b = (index & 0x03) as u8;
        palette[index * 3] = (u16::from(r) * 255 / 7) as u8;
        palette[index * 3 + 1] = (u16::from(g) * 255 / 7) as u8;
        palette[index * 3 + 2] = (u16::from(b) * 255 / 3) as u8;
    }
    palette
}

fn write_pcx_rle(input: &[u8], output: &mut Vec<u8>) {
    let mut index = 0;
    while index < input.len() {
        let value = input[index];
        let mut count = 1usize;
        while index + count < input.len() && input[index + count] == value && count < 63 {
            count += 1;
        }

        if count > 1 || value & 0xC0 == 0xC0 {
            output.push(0xC0 | count as u8);
            output.push(value);
        } else {
            output.push(value);
        }
        index += count;
    }
}

fn checked_u16(value: u32, label: &str) -> Result<u16, String> {
    u16::try_from(value).map_err(|_| format!("{label} is too large for PCX"))
}

fn checked_i16(value: u32, label: &str) -> Result<i16, String> {
    i16::try_from(value).map_err(|_| format!("{label} is too large for SFF"))
}

fn write_u16(bytes: &mut [u8], offset: usize, value: u16) {
    bytes[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
}

fn write_i16(bytes: &mut [u8], offset: usize, value: i16) {
    bytes[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
}

fn write_u32(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::templates::{StageTemplate, TemplateConfidence};
    use image::{ImageBuffer, Rgba};
    use std::fs;
    use tempfile::{tempdir, TempDir};

    fn tiny_template() -> StageTemplate {
        StageTemplate {
            id: "TEST",
            display_name: "Test",
            confidence: TemplateConfidence::FormulaDerived,
            localcoord_w: 4,
            localcoord_h: 3,
            bg_width: 4,
            bg_height: 3,
            axis_x: 2,
            axis_y: 3,
            bound_left: 0,
            bound_right: 0,
            bound_high: 0,
            bound_low: 0,
            zoffset: 0,
            tension: 0,
            floor_tension: None,
            vertical_follow: 0.0,
            screen_left: 0,
            screen_right: 0,
            source_stage: "test",
            source_author: "test",
        }
    }

    fn write_png(width: u32, height: u32) -> (TempDir, String) {
        let dir = tempdir().expect("temp dir");
        let path = dir.path().join(format!("{width}x{height}.png"));
        let image = ImageBuffer::from_pixel(width, height, Rgba([200u8, 100, 50, 255]));
        image.save(&path).expect("write png");
        (dir, path.to_string_lossy().into_owned())
    }

    fn read_u16(bytes: &[u8], offset: usize) -> u16 {
        u16::from_le_bytes([bytes[offset], bytes[offset + 1]])
    }

    fn read_u32(bytes: &[u8], offset: usize) -> u32 {
        u32::from_le_bytes([
            bytes[offset],
            bytes[offset + 1],
            bytes[offset + 2],
            bytes[offset + 3],
        ])
    }

    #[test]
    fn writes_single_sprite_sff_header_and_subfile_metadata() {
        let template = tiny_template();
        let (_image_dir, image_path) = write_png(template.bg_width, template.bg_height);
        let output_dir = tempdir().expect("output dir");
        let output_path = output_dir.path().join("stage.sff");

        write_sff(
            &output_path,
            &image_path,
            &template,
            &ConformanceState::Correct,
        )
        .expect("write sff");

        let bytes = fs::read(output_path).expect("read sff");
        assert_eq!(&bytes[0..12], b"ElecbyteSpr\0");
        assert_eq!(&bytes[12..16], &[0, 1, 0, 1]);
        assert_eq!(read_u32(&bytes, 16), 1);
        assert_eq!(read_u32(&bytes, 20), 1);
        assert_eq!(read_u32(&bytes, 24), 512);
        assert_eq!(read_u32(&bytes, 28), 32);
        assert_eq!(read_u32(&bytes, 512), 0);
        assert!(read_u32(&bytes, 516) > 128);
        assert_eq!(read_u16(&bytes, 520), template.axis_x as u16);
        assert_eq!(read_u16(&bytes, 522), template.axis_y as u16);
        assert_eq!(read_u16(&bytes, 524), 0);
        assert_eq!(read_u16(&bytes, 526), 0);
    }

    #[test]
    fn crops_before_encoding_pcx_to_template_size() {
        let template = tiny_template();
        let (_image_dir, image_path) = write_png(8, 7);
        let output_dir = tempdir().expect("output dir");
        let output_path = output_dir.path().join("stage.sff");

        write_sff(
            &output_path,
            &image_path,
            &template,
            &ConformanceState::FixableWithCrop {
                crop_x: 2,
                crop_y: 2,
            },
        )
        .expect("write sff");

        let bytes = fs::read(output_path).expect("read sff");
        let pcx_offset = 512 + 32;
        assert_eq!(bytes[pcx_offset], 0x0A);
        assert_eq!(bytes[pcx_offset + 1], 5);
        assert_eq!(read_u16(&bytes, pcx_offset + 8), template.bg_width as u16 - 1);
        assert_eq!(read_u16(&bytes, pcx_offset + 10), template.bg_height as u16 - 1);
        assert_eq!(bytes[pcx_offset + 65], 1);
        assert_eq!(bytes[bytes.len() - 769], 12);
    }
}
