//! Registering a stage in IKEMEN GO's `data/select.def`.
//!
//! Works on raw bytes rather than `String`: plenty of `select.def` files in
//! the wild are Latin-1 or Shift-JIS, and a lossy UTF-8 round trip would
//! quietly mangle every character name in them. Only ASCII is ever inspected
//! or inserted, so the rest of the file passes through untouched.

/// The `select.def` line for a stage installed as `stages/<stem>/<stem>.def`.
pub fn stage_entry(stem: &str) -> String {
    format!("stages/{stem}/{stem}.def")
}

/// Add `entry` under `[ExtraStages]`, creating the section if the file has
/// none. Returns `None` when the stage is already listed there, so the caller
/// can skip the write.
///
/// The entry goes directly under the section header, the same place IKEMEN
/// Lab puts the stages it installs, and uses the file's own line endings.
pub fn add_extra_stage(content: &[u8], entry: &str) -> Option<Vec<u8>> {
    let newline: &[u8] = if content.windows(2).any(|w| w == b"\r\n") {
        b"\r\n"
    } else {
        b"\n"
    };
    let wanted = normalize_path(entry.as_bytes());

    let mut in_extra = false;
    let mut insert_at: Option<usize> = None;
    let mut offset = 0;
    for line in content.split_inclusive(|&b| b == b'\n') {
        let start = offset;
        offset += line.len();

        let text = trim(strip_comment(line));
        if text.first() == Some(&b'[') {
            in_extra = text.eq_ignore_ascii_case(b"[ExtraStages]");
            if in_extra && insert_at.is_none() {
                insert_at = Some(if line.ends_with(b"\n") { offset } else { start + line.len() });
            }
            continue;
        }
        if in_extra {
            // Entries can carry options after a comma: `stages/x.def, music=…`.
            let path = trim(text.split(|&b| b == b',').next().unwrap_or(&[]));
            if !path.is_empty() && normalize_path(path) == wanted {
                return None;
            }
        }
    }

    let mut out = Vec::with_capacity(content.len() + entry.len() + 32);
    match insert_at {
        Some(at) => {
            out.extend_from_slice(&content[..at]);
            // A header on the very last line has no newline to insert after.
            if at == content.len() && !content.ends_with(b"\n") {
                out.extend_from_slice(newline);
            }
            out.extend_from_slice(entry.as_bytes());
            out.extend_from_slice(newline);
            out.extend_from_slice(&content[at..]);
        }
        None => {
            out.extend_from_slice(content);
            if !content.is_empty() && !content.ends_with(b"\n") {
                out.extend_from_slice(newline);
            }
            out.extend_from_slice(newline);
            out.extend_from_slice(b"[ExtraStages]");
            out.extend_from_slice(newline);
            out.extend_from_slice(entry.as_bytes());
            out.extend_from_slice(newline);
        }
    }
    Some(out)
}

fn strip_comment(line: &[u8]) -> &[u8] {
    match line.iter().position(|&b| b == b';') {
        Some(i) => &line[..i],
        None => line,
    }
}

fn trim(bytes: &[u8]) -> &[u8] {
    let start = bytes.iter().position(|b| !b.is_ascii_whitespace()).unwrap_or(bytes.len());
    let end = bytes.iter().rposition(|b| !b.is_ascii_whitespace()).map_or(start, |i| i + 1);
    &bytes[start..end]
}

/// Case-insensitive, separator-insensitive form for comparing paths, matching
/// how IKEMEN GO resolves them on case-insensitive filesystems.
fn normalize_path(path: &[u8]) -> Vec<u8> {
    path.iter()
        .map(|&b| if b == b'\\' { b'/' } else { b.to_ascii_lowercase() })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn add(content: &str, entry: &str) -> Option<String> {
        add_extra_stage(content.as_bytes(), entry).map(|b| String::from_utf8(b).unwrap())
    }

    #[test]
    fn entry_path_uses_a_folder_per_stage() {
        assert_eq!(stage_entry("Neon_Rooftop"), "stages/Neon_Rooftop/Neon_Rooftop.def");
    }

    #[test]
    fn inserts_directly_under_the_section_header() {
        let before = "[Characters]\nkfm\n\n[ExtraStages]\nstages/stage0.def\n\n[Options]\narcade.maxmatches = 6\n";
        let after = add(before, "stages/New/New.def").unwrap();
        assert_eq!(
            after,
            "[Characters]\nkfm\n\n[ExtraStages]\nstages/New/New.def\nstages/stage0.def\n\n[Options]\narcade.maxmatches = 6\n"
        );
    }

    #[test]
    fn already_listed_is_a_no_op_regardless_of_case_slashes_or_options() {
        let content = "[ExtraStages]\n  STAGES\\New\\new.DEF , music=sound/x.ogg ; mine\n";
        assert_eq!(add(content, "stages/New/New.def"), None);
    }

    #[test]
    fn a_commented_out_entry_does_not_count_as_listed() {
        let content = "[ExtraStages]\n;stages/New/New.def\n";
        assert_eq!(
            add(content, "stages/New/New.def").unwrap(),
            "[ExtraStages]\nstages/New/New.def\n;stages/New/New.def\n"
        );
    }

    #[test]
    fn the_same_path_in_another_section_does_not_count() {
        let content = "[Characters]\nstages/New/New.def\n[ExtraStages]\n";
        assert!(add(content, "stages/New/New.def").is_some());
    }

    #[test]
    fn keeps_crlf_line_endings() {
        let after = add("[ExtraStages]\r\nstages/a.def\r\n", "stages/B/B.def").unwrap();
        assert_eq!(after, "[ExtraStages]\r\nstages/B/B.def\r\nstages/a.def\r\n");
    }

    #[test]
    fn header_on_the_last_line_without_a_newline() {
        assert_eq!(add("[extrastages]", "stages/B/B.def").unwrap(), "[extrastages]\nstages/B/B.def\n");
    }

    #[test]
    fn creates_the_section_when_missing() {
        assert_eq!(
            add("[Characters]\nkfm", "stages/B/B.def").unwrap(),
            "[Characters]\nkfm\n\n[ExtraStages]\nstages/B/B.def\n"
        );
    }

    #[test]
    fn non_utf8_bytes_elsewhere_survive() {
        let mut content = b"[Characters]\n\xe9\x82\xa3 kfm\n[ExtraStages]\n".to_vec();
        content.extend_from_slice(b"\xff\xfe weird\n");
        let after = add_extra_stage(&content, "stages/B/B.def").unwrap();
        assert!(after.windows(2).any(|w| w == b"\xff\xfe"));
        assert!(after.windows(3).any(|w| w == b"\xe9\x82\xa3"));
    }
}
