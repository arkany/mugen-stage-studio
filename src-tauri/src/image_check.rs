use crate::stage_config::ConformanceState;
use crate::templates::StageTemplate;

pub fn read_dimensions(path: &str) -> Option<(u32, u32)> {
    image::image_dimensions(path).ok()
}

pub fn check_image_conformance(image_path: &str, template: &StageTemplate) -> ConformanceState {
    let Some((width, height)) = read_dimensions(image_path) else {
        return ConformanceState::NoImage;
    };

    if width == template.bg_width && height == template.bg_height {
        return ConformanceState::Correct;
    }

    if width >= template.bg_width
        && height >= template.bg_height
        && (width > template.bg_width || height > template.bg_height)
    {
        return ConformanceState::FixableWithCrop {
            crop_x: (width - template.bg_width) / 2,
            crop_y: (height - template.bg_height) / 2,
        };
    }

    let min_width = template.bg_width.saturating_mul(9) / 10;
    let min_height = template.bg_height.saturating_mul(9) / 10;
    if width <= template.bg_width
        && height <= template.bg_height
        && (width < template.bg_width || height < template.bg_height)
        && width >= min_width
        && height >= min_height
    {
        return ConformanceState::FixableWithExtend {
            pad_x: (template.bg_width - width) / 2,
            pad_y: (template.bg_height - height) / 2,
        };
    }

    ConformanceState::TooSmall
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::templates::T1;
    use image::{ImageBuffer, Rgba};
    use tempfile::{tempdir, TempDir};

    fn write_png(width: u32, height: u32) -> (TempDir, String) {
        let dir = tempdir().expect("temp dir");
        let path = dir.path().join(format!("{width}x{height}.png"));
        let image = ImageBuffer::from_pixel(width, height, Rgba([20u8, 40, 60, 255]));
        image.save(&path).expect("write png");
        (dir, path.to_string_lossy().into_owned())
    }

    #[test]
    fn exact_template_dimensions_are_correct() {
        let (_dir, path) = write_png(T1.bg_width, T1.bg_height);

        let state = check_image_conformance(&path, &T1);

        assert!(matches!(state, ConformanceState::Correct));
    }

    #[test]
    fn larger_images_are_center_crop_fixable() {
        let (_dir, path) = write_png(T1.bg_width + 20, T1.bg_height + 10);

        let state = check_image_conformance(&path, &T1);

        assert!(matches!(
            state,
            ConformanceState::FixableWithCrop {
                crop_x: 10,
                crop_y: 5
            }
        ));
    }

    #[test]
    fn slightly_smaller_images_are_extend_fixable() {
        let (_dir, path) = write_png(T1.bg_width - 20, T1.bg_height - 10);

        let state = check_image_conformance(&path, &T1);

        assert!(matches!(
            state,
            ConformanceState::FixableWithExtend {
                pad_x: 10,
                pad_y: 5
            }
        ));
    }

    #[test]
    fn one_axis_crop_or_extend_is_fixable() {
        let (_wide_dir, wide_path) = write_png(T1.bg_width + 20, T1.bg_height);
        let (_short_dir, short_path) = write_png(T1.bg_width, T1.bg_height - 10);

        assert!(matches!(
            check_image_conformance(&wide_path, &T1),
            ConformanceState::FixableWithCrop {
                crop_x: 10,
                crop_y: 0
            }
        ));
        assert!(matches!(
            check_image_conformance(&short_path, &T1),
            ConformanceState::FixableWithExtend {
                pad_x: 0,
                pad_y: 5
            }
        ));
    }

    #[test]
    fn very_small_images_are_rejected() {
        let (_dir, path) = write_png(T1.bg_width / 2, T1.bg_height / 2);

        let state = check_image_conformance(&path, &T1);

        assert!(matches!(state, ConformanceState::TooSmall));
    }
}
