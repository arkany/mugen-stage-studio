#!/usr/bin/env python3
"""
parse_stage.py — Extract ground-truth parameters from MUGEN stage SFF + DEF pairs.

Phase 1 of the MUGEN Stage Studio rebuild. Supports SFF v1 (WinMUGEN) and
SFF v2/v2.01 (MUGEN 1.0+, IKEMEN GO).

Usage:
    python3 parse_stage.py <stage_dir>                # analyze a directory
    python3 parse_stage.py --pair <sff> <def>         # analyze a specific pair
    python3 parse_stage.py --walk <root_dir>          # walk root, parse every pair
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# SFF parsing
# ---------------------------------------------------------------------------

SFF_SIGNATURE = b"ElecbyteSpr\x00"


@dataclass
class SpriteInfo:
    width: int
    height: int
    axisX: int
    axisY: int
    axisIsCorrect: bool


def _read_sff_header(data: bytes) -> tuple[int, tuple[int, int, int, int]]:
    """Returns (sff_version, raw_version_bytes). version is 1 or 2."""
    if len(data) < 36:
        raise ValueError("file too small to be SFF")
    if data[:12] != SFF_SIGNATURE:
        raise ValueError("not an SFF file (signature mismatch)")
    v3, v2, v1, v0 = data[12], data[13], data[14], data[15]
    # v0 is the major version: 1 for SFF v1, 2 for SFF v2
    if v0 == 1:
        version = 1
    elif v0 == 2:
        version = 2
    else:
        raise ValueError(f"unsupported SFF version bytes {(v3,v2,v1,v0)}")
    return version, (v3, v2, v1, v0)


def _parse_sff_v1(data: bytes, target_group: int = 0, target_image: int = 0) -> SpriteInfo:
    # Header layout (from Elecbyte SFF v1 spec):
    #  16-19: number of groups (uint32)
    #  20-23: number of images (uint32)
    #  24-27: offset of first sprite header (uint32)
    #  28-31: subheader size (uint32)
    #  32:    shared palette flag (uint8)
    num_images = struct.unpack_from("<I", data, 20)[0]
    first_offset = struct.unpack_from("<I", data, 24)[0]

    # Walk the linked list and index every sprite by flat index, recording its
    # group/image, axis, payload offset, and length. Then resolve by (group,image)
    # with linked-sprite fallback.
    sprites: list[dict[str, Any]] = []
    offset = first_offset
    visited = 0
    while offset != 0 and visited < num_images + 16:
        if offset + 32 > len(data):
            break
        next_offset, length, axisX, axisY, group, image, prev_copy, _shared = (
            struct.unpack_from("<IIhhHHHB", data, offset)
        )
        sprites.append(
            {
                "offset": offset,
                "next": next_offset,
                "length": length,
                "axisX": axisX,
                "axisY": axisY,
                "group": group,
                "image": image,
                "prev_copy": prev_copy,
            }
        )
        offset = next_offset
        visited += 1

    # Find target. Try exact match first; if not found and target was (0,0),
    # fall back to the first sprite with non-empty payload that doesn't look
    # like a thumbnail (group != 9000).
    target = None
    for s in sprites:
        if s["group"] == target_group and s["image"] == target_image:
            target = s
            break
    if target is None and (target_group, target_image) == (0, 0):
        for s in sprites:
            if s["length"] > 0 and s["group"] != 9000:
                target = s
                break

    if target is None:
        raise ValueError(f"SFFv1: sprite ({target_group},{target_image}) not found")

    pcx_offset = target["offset"] + 32
    axisX = target["axisX"]
    axisY = target["axisY"]

    # Linked (zero-length) sprite: follow prev_copy index for PCX dimensions.
    if target["length"] == 0:
        pc = target["prev_copy"]
        if 0 <= pc < len(sprites):
            pcx_offset = sprites[pc]["offset"] + 32
        else:
            raise ValueError("SFFv1: linked sprite has invalid prev_copy")

    if pcx_offset + 12 > len(data):
        raise ValueError("SFFv1: PCX header truncated")

    # PCX header: width = xmax-xmin+1, height = ymax-ymin+1
    xmin, ymin, xmax, ymax = struct.unpack_from("<HHHH", data, pcx_offset + 4)
    width = xmax - xmin + 1
    height = ymax - ymin + 1

    return SpriteInfo(
        width=width,
        height=height,
        axisX=axisX,
        axisY=axisY,
        axisIsCorrect=(axisX == width // 2 and axisY == height),
    )


def _parse_sff_v2(data: bytes, target_group: int = 0, target_image: int = 0) -> SpriteInfo:
    # SFF v2 header:
    #  36-39: first sprite node offset (uint32)
    #  40-43: number of sprites (uint32)
    #  44-47: first palette node offset
    #  48-51: number of palettes
    #  52-55: l-data block offset (literal/uncompressed data)
    #  56-59: l-data block length
    #  60-63: t-data block offset (translated/compressed data, typically PNG)
    #  64-67: t-data block length
    sprite_node_off = struct.unpack_from("<I", data, 36)[0]
    num_sprites = struct.unpack_from("<I", data, 40)[0]

    # Sprite node entry: 28 bytes
    #  0-1   group (uint16)
    #  2-3   item (uint16)
    #  4-5   width (uint16)
    #  6-7   height (uint16)
    #  8-9   axisX (int16)
    # 10-11  axisY (int16)
    # 12-13  linked index (uint16)
    # 14     format (uint8): 0=raw,2=RLE8,3=RLE5,4=LZ5,10=PNG8,11=PNG24,12=PNG32
    # 15     color depth (uint8)
    # 16-19  data offset (uint32) into the appropriate data block
    # 20-23  data length (uint32)
    # 24-25  palette index
    # 26-27  flags
    nodes = []
    for i in range(num_sprites):
        off = sprite_node_off + i * 28
        if off + 28 > len(data):
            break
        group, item, w, h, ax, ay, linked, fmt, cdepth, dlen_off, dlen, pal, flags = (
            struct.unpack_from("<HHHHhhHBBIIHH", data, off)
        )
        nodes.append((group, item, w, h, ax, ay, linked, fmt, dlen))

    target = None
    for n in nodes:
        if n[0] == target_group and n[1] == target_image:
            target = n
            break
    if target is None and (target_group, target_image) == (0, 0):
        for n in nodes:
            if n[8] > 0 and n[0] != 9000 and n[2] > 0 and n[3] > 0:
                target = n
                break

    if target is None:
        raise ValueError(f"SFFv2: sprite ({target_group},{target_image}) not found")

    group, item, w, h, ax, ay, linked, fmt, dlen = target

    # Linked sprite: width/height/axis on the link node should already be valid
    # in v2 (the node carries them), so we use them as-is.
    return SpriteInfo(
        width=w,
        height=h,
        axisX=ax,
        axisY=ay,
        axisIsCorrect=(ax == w // 2 and ay == h),
    )


def parse_sff(
    path: Path, target_group: int = 0, target_image: int = 0
) -> tuple[int, SpriteInfo]:
    data = path.read_bytes()
    version, _raw = _read_sff_header(data)
    if version == 1:
        return version, _parse_sff_v1(data, target_group, target_image)
    return version, _parse_sff_v2(data, target_group, target_image)


# ---------------------------------------------------------------------------
# DEF parsing
# ---------------------------------------------------------------------------


@dataclass
class DefInfo:
    localcoord: str | None = None
    hires: int | None = None
    zoffset: int | None = None
    name: str | None = None
    author: str | None = None
    mugenversion: str | None = None
    boundleft: int | None = None
    boundright: int | None = None
    boundhigh: int | None = None
    boundlow: int | None = None
    tension: int | None = None
    floortension: int | None = None
    verticalfollow: float | None = None
    screenleft: int | None = None
    screenright: int | None = None
    bg_start: str | None = None
    bg_delta: str | None = None
    bg_tile: str | None = None
    bg_tilespacing: str | None = None
    bg_spriteno: str | None = None
    bg_section_name: str | None = None
    bg_elements: list[dict[str, str]] = field(default_factory=list)


def _read_def_text(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", errors="replace")


def _strip_comment(line: str) -> str:
    # MUGEN comments are introduced by ';'. Strip but preserve content.
    in_str = False
    out = []
    for ch in line:
        if ch == '"':
            in_str = not in_str
        if ch == ";" and not in_str:
            break
        out.append(ch)
    return "".join(out)


def _parse_def_text(text: str) -> dict[str, dict[str, str]]:
    """
    Parse INI-like .def text into {section_name: {key: value}}.
    Section names are stored verbatim (case preserved). Keys are lowercased.
    For sections that appear multiple times (e.g. [BG ...]) we keep the first
    occurrence under its full name and append a numeric suffix for the rest:
    `[BG ground]` first time -> "BG ground", second `[BG ground]` -> "BG ground#2".
    """
    sections: dict[str, dict[str, str]] = {}
    section_seen: dict[str, int] = {}
    current: str | None = None
    current_dict: dict[str, str] | None = None

    for raw in text.splitlines():
        line = _strip_comment(raw).strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1].strip()
            count = section_seen.get(name, 0)
            section_seen[name] = count + 1
            key = name if count == 0 else f"{name}#{count + 1}"
            current = key
            current_dict = {}
            sections[current] = current_dict
            continue
        if current_dict is None:
            continue
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        current_dict[k.strip().lower()] = v.strip()

    return sections


def _to_int(s: str | None) -> int | None:
    if s is None:
        return None
    s = s.split(",")[0].strip()
    if s == "":
        return None
    try:
        return int(s)
    except ValueError:
        try:
            return int(float(s))
        except ValueError:
            return None


def _to_float(s: str | None) -> float | None:
    if s is None:
        return None
    s = s.split(",")[0].strip()
    if s == "":
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _find_section(sections: dict[str, dict[str, str]], target: str) -> dict[str, str] | None:
    target_lower = target.lower()
    for name, body in sections.items():
        if name.lower() == target_lower:
            return body
    return None


def _is_bg_section(name: str) -> bool:
    n = name.strip().lower()
    if not n.startswith("bg"):
        return False
    if n == "bgdef":
        return False
    if "ctrl" in n:
        return False
    if n == "bg" or n.startswith("bg "):
        return True
    return bool(re.match(r"^bg\d+$", n))


def _find_first_bg_section(
    sections: dict[str, dict[str, str]],
) -> tuple[str | None, dict[str, str] | None]:
    """First [BG ...] section (NOT [BGdef], NOT [BGCtrlDef])."""
    for name, body in sections.items():
        if _is_bg_section(name):
            return name, body
    return None, None


def _collect_bg_sections(
    sections: dict[str, dict[str, str]],
) -> list[tuple[str, dict[str, str]]]:
    """All [BG ...] sections in declaration order."""
    return [(name, body) for name, body in sections.items() if _is_bg_section(name)]


def parse_def(path: Path) -> DefInfo:
    text = _read_def_text(path)
    sections = _parse_def_text(text)

    info = DefInfo()

    info_section = _find_section(sections, "Info")
    if info_section:
        info.name = (info_section.get("name") or "").strip().strip('"') or None
        info.author = (info_section.get("author") or "").strip().strip('"') or None
        info.mugenversion = (info_section.get("mugenversion") or "").strip() or None

    stage_info = _find_section(sections, "StageInfo")
    if stage_info:
        info.localcoord = stage_info.get("localcoord")
        info.hires = _to_int(stage_info.get("hires"))
        info.zoffset = _to_int(stage_info.get("zoffset"))

    camera = _find_section(sections, "Camera")
    if camera:
        info.boundleft = _to_int(camera.get("boundleft"))
        info.boundright = _to_int(camera.get("boundright"))
        info.boundhigh = _to_int(camera.get("boundhigh"))
        info.boundlow = _to_int(camera.get("boundlow"))
        info.tension = _to_int(camera.get("tension"))
        info.floortension = _to_int(camera.get("floortension"))
        info.verticalfollow = _to_float(camera.get("verticalfollow"))

    bound = _find_section(sections, "Bound")
    if bound:
        info.screenleft = _to_int(bound.get("screenleft"))
        info.screenright = _to_int(bound.get("screenright"))
    # Some DEF files put screenleft/screenright in [StageInfo] instead.
    if info.screenleft is None and stage_info:
        info.screenleft = _to_int(stage_info.get("screenleft"))
    if info.screenright is None and stage_info:
        info.screenright = _to_int(stage_info.get("screenright"))

    bg_name, bg = _find_first_bg_section(sections)
    if bg:
        info.bg_section_name = bg_name
        info.bg_start = bg.get("start")
        info.bg_delta = bg.get("delta")
        info.bg_tile = bg.get("tile")
        info.bg_tilespacing = bg.get("tilespacing")
        info.bg_spriteno = bg.get("spriteno") or bg.get("sprite")

    for name, body in _collect_bg_sections(sections):
        info.bg_elements.append(
            {
                "section": name,
                "type": body.get("type", ""),
                "spriteno": body.get("spriteno") or body.get("sprite") or "",
                "start": body.get("start", ""),
                "delta": body.get("delta", ""),
                "tile": body.get("tile", ""),
                "tilespacing": body.get("tilespacing", ""),
            }
        )

    return info


# ---------------------------------------------------------------------------
# Derivation + analysis
# ---------------------------------------------------------------------------


def _parse_localcoord(s: str | None) -> tuple[int | None, int | None]:
    if not s:
        return (None, None)
    parts = [p.strip() for p in s.split(",")]
    if len(parts) < 2:
        return (None, None)
    try:
        return (int(float(parts[0])), int(float(parts[1])))
    except ValueError:
        return (None, None)


def _parse_spriteno(s: str | None) -> tuple[int, int]:
    """Parse a 'group, item' spriteno string. Defaults to (0,0)."""
    if not s:
        return (0, 0)
    parts = [p.strip() for p in s.split(",")]
    try:
        g = int(float(parts[0])) if parts[0] else 0
        i = int(float(parts[1])) if len(parts) > 1 and parts[1] else 0
        return (g, i)
    except ValueError:
        return (0, 0)


def analyze_pair(sff_path: Path, def_path: Path, label: str | None = None) -> dict[str, Any]:
    label = label or sff_path.stem

    result: dict[str, Any] = {
        "stage": label,
        "sff_file": sff_path.name,
        "def_file": def_path.name,
        "directory": str(sff_path.parent),
    }

    # DEF first — we need bg_spriteno to find the right SFF sprite.
    try:
        d = parse_def(def_path)
        result["def"] = asdict(d)
    except Exception as e:
        result["def"] = None
        result["def_error"] = f"{type(e).__name__}: {e}"

    # SFF lookup. The bounds formula `±(imgW - lcW)/2` only applies to layers
    # that scroll 1:1 with the camera (`delta = 1, 1`, the default). Stages with
    # no 1:1 layer are pure-parallax and bounds are author-chosen.
    #
    # Strategy:
    #   1. Iterate every [BG ] element, parse delta, look up its sprite.
    #   2. Prefer the largest 1:1 layer as the canonical backdrop.
    #   3. If no 1:1 layer exists, fall back to the largest layer overall and
    #      flag the stage as parallax-only (formula doesn't apply).
    def_data = result.get("def") or {}

    def _delta_is_one_one(s: str) -> bool:
        if s is None or s == "":
            return True  # MUGEN default when delta is omitted is 1, 1
        parts = [p.strip() for p in s.split(",")]
        try:
            dx = float(parts[0]) if parts and parts[0] else 1.0
            dy = float(parts[1]) if len(parts) > 1 and parts[1] else 1.0
        except ValueError:
            return False
        return abs(dx - 1.0) < 1e-6 and abs(dy - 1.0) < 1e-6

    candidates: list[tuple[int, int, str, bool]] = []
    for el in def_data.get("bg_elements", []) or []:
        g, i = _parse_spriteno(el.get("spriteno"))
        candidates.append((g, i, el.get("section", ""), _delta_is_one_one(el.get("delta", ""))))
    if not candidates:
        g, i = _parse_spriteno(def_data.get("bg_spriteno"))
        candidates = [(g, i, "fallback", True)]

    candidate_results: list[dict[str, Any]] = []
    best_one_to_one: tuple[int, SpriteInfo, int, str] | None = None
    best_any: tuple[int, SpriteInfo, int, str] | None = None
    for g, i, section, is_1_1 in candidates:
        try:
            version, sp = parse_sff(sff_path, g, i)
            area = sp.width * sp.height
            candidate_results.append(
                {
                    "section": section,
                    "spriteno": f"{g},{i}",
                    "delta_is_1_1": is_1_1,
                    "width": sp.width,
                    "height": sp.height,
                    "axisX": sp.axisX,
                    "axisY": sp.axisY,
                }
            )
            if is_1_1 and (best_one_to_one is None or area > best_one_to_one[2]):
                best_one_to_one = (version, sp, area, section)
            if best_any is None or area > best_any[2]:
                best_any = (version, sp, area, section)
        except Exception:
            candidate_results.append(
                {
                    "section": section,
                    "spriteno": f"{g},{i}",
                    "delta_is_1_1": is_1_1,
                    "error": "lookup_failed",
                }
            )

    chosen = best_one_to_one or best_any
    result["bg_candidates"] = candidate_results
    result["parallax_only"] = best_one_to_one is None and best_any is not None
    if chosen is not None:
        version, sprite, _area, section = chosen
        result["sff_version"] = version
        result["sprite"] = asdict(sprite)
        tag = "" if best_one_to_one is not None else " [no 1:1 layer; parallax-only]"
        result["sff_spriteno_used"] = (
            f"{sprite.width}x{sprite.height} from [{section}]{tag}"
        )
    else:
        result["sff_version"] = None
        result["sprite"] = None
        result["sff_error"] = "no BG element resolved to a readable sprite"

    # Derived. If localcoord is missing in the DEF, use MUGEN's default (320,240).
    derived: dict[str, Any] = {
        "localcoordSource": None,
        "localcoordWidth": None,
        "localcoordHeight": None,
        "expectedBoundleft": None,
        "expectedBoundright": None,
        "expectedBoundhigh": None,
        "boundsMatchDerived": False,
    }
    if result.get("def"):
        d = result["def"]
        lcw, lch = _parse_localcoord(d.get("localcoord"))
        if lcw is None:
            # Legacy MUGEN: `hires = 1` in [StageInfo] means 640x480 coordinate space.
            # Without that flag, the implicit default is 320x240.
            if d.get("hires") == 1:
                lcw, lch = 640, 480
                derived["localcoordSource"] = "implicit(hires=1 -> 640,480)"
            else:
                lcw, lch = 320, 240
                derived["localcoordSource"] = "default(320,240)"
        else:
            derived["localcoordSource"] = "explicit"
        derived["localcoordWidth"] = lcw
        derived["localcoordHeight"] = lch

        if result.get("sprite"):
            sprite = result["sprite"]
            # If the image is smaller than the localcoord viewport, no scroll is
            # possible in that axis — clamp to 0 rather than producing inverted bounds.
            half_extra_w = max(0, (sprite["width"] - lcw) // 2)
            extra_h = max(0, sprite["height"] - lch)
            ebl = -half_extra_w
            ebr = half_extra_w
            ebh = -extra_h
            derived["expectedBoundleft"] = ebl
            derived["expectedBoundright"] = ebr
            derived["expectedBoundhigh"] = ebh
            derived["boundsMatchDerived"] = (
                d.get("boundleft") == ebl and d.get("boundright") == ebr
            )
    result["derived"] = derived

    return result


# ---------------------------------------------------------------------------
# Directory walking
# ---------------------------------------------------------------------------


def find_pairs_in_dir(directory: Path) -> list[tuple[Path, Path, str]]:
    """
    Find all (sff, def, label) pairs in a single directory.
    A "pair" is a .sff and .def with matching base names (case-insensitive).
    If multiple .def files share the same .sff (e.g., variants), each is a
    separate pair. If a .def has no matching .sff, it is skipped.

    Matching strategy:
      1. Exact stem match (case-insensitive) — primary.
      2. If a .def's stem starts with the .sff's stem followed by a separator
         (`_`, `-`, `.`, ` `), treat it as a variant and pair with that .sff.
    """
    sffs = sorted(
        [
            p
            for p in directory.iterdir()
            if p.is_file() and p.suffix.lower() == ".sff" and p.stat().st_size > 0
        ]
    )
    defs = sorted(
        [
            p
            for p in directory.iterdir()
            if p.is_file() and p.suffix.lower() == ".def" and p.stat().st_size > 0
        ]
    )

    sff_by_stem = {p.stem.lower(): p for p in sffs}
    pairs: list[tuple[Path, Path, str]] = []
    used_sffs: set[Path] = set()

    # Pass 1: exact stem match
    matched_defs: set[Path] = set()
    for d in defs:
        stem = d.stem.lower()
        if stem in sff_by_stem:
            sff = sff_by_stem[stem]
            pairs.append((sff, d, d.stem))
            matched_defs.add(d)
            used_sffs.add(sff)

    # Pass 2: variant match — def stem and sff stem share a common prefix
    # followed by a separator on either side. Covers:
    #   "Foo_Stage.def"      + "Foo_Stage_v2.sff"     (def is prefix of sff)
    #   "Foo_Stage_v2.def"   + "Foo_Stage.sff"        (sff is prefix of def)
    #   "Foo_Stage.def"      + "Foo_Stage(c).sff"     (parenthesis suffix on sff)
    seps = ("_", "-", ".", " ", "(", ")")
    sff_stems_sorted = sorted(sff_by_stem.keys(), key=lambda s: -len(s))  # longest first
    for d in defs:
        if d in matched_defs:
            continue
        stem = d.stem.lower()
        # Direction A: def stem is the longer one; trim its trailing variant tag.
        for sff_stem in sff_stems_sorted:
            if stem.startswith(sff_stem) and len(stem) > len(sff_stem):
                if stem[len(sff_stem)] in seps:
                    sff = sff_by_stem[sff_stem]
                    pairs.append((sff, d, d.stem))
                    matched_defs.add(d)
                    used_sffs.add(sff)
                    break
        if d in matched_defs:
            continue
        # Direction B: sff stem is the longer one; def stem is a prefix.
        for sff_stem in sff_stems_sorted:
            if sff_stem.startswith(stem) and len(sff_stem) > len(stem):
                if sff_stem[len(stem)] in seps:
                    sff = sff_by_stem[sff_stem]
                    pairs.append((sff, d, d.stem))
                    matched_defs.add(d)
                    used_sffs.add(sff)
                    break

    return pairs


def walk_for_pairs(root: Path) -> list[tuple[Path, Path, str]]:
    pairs: list[tuple[Path, Path, str]] = []
    for dirpath, _dirnames, _filenames in os.walk(root):
        d = Path(dirpath)
        # Skip hidden directories
        if any(part.startswith(".") for part in d.relative_to(root).parts):
            continue
        pairs.extend(find_pairs_in_dir(d))
    return pairs


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def _fmt(v: Any) -> str:
    if v is None:
        return "?"
    return str(v)


def print_markdown_table(results: list[dict[str, Any]]) -> None:
    print("| stage | localcoord | imgW×imgH | axisCorrect | boundsMatch | zoffset |")
    print("|---|---|---|---|---|---|")
    for r in results:
        stage = r["stage"]
        if r.get("sprite"):
            dims = f"{r['sprite']['width']}×{r['sprite']['height']}"
            axis_ok = r["sprite"]["axisIsCorrect"]
        else:
            dims = "?"
            axis_ok = "?"
        d = r.get("def") or {}
        derived = r.get("derived") or {}
        lcw = derived.get("localcoordWidth")
        lch = derived.get("localcoordHeight")
        if lcw is not None and lch is not None:
            lc = f"{lcw},{lch}"
            src = derived.get("localcoordSource") or ""
            if src == "default(320,240)":
                lc += "*"
            elif src.startswith("implicit"):
                lc += "†"
        else:
            lc = "?"
        zo = d.get("zoffset")
        bm = derived.get("boundsMatchDerived", False)
        print(
            f"| {stage} | {lc} | {dims} | {_fmt(axis_ok)} | {_fmt(bm)} | {_fmt(zo)} |"
        )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("path", nargs="?", help="stage directory (single dir mode)")
    ap.add_argument("--pair", nargs=2, metavar=("SFF", "DEF"), help="analyze a single pair")
    ap.add_argument(
        "--walk",
        metavar="ROOT",
        action="append",
        help="walk root directory recursively (may be passed multiple times)",
    )
    ap.add_argument(
        "--out",
        default="stage-analysis.json",
        help="output JSON path (default: stage-analysis.json)",
    )
    args = ap.parse_args()

    pairs: list[tuple[Path, Path, str]] = []

    if args.pair:
        sff = Path(args.pair[0])
        d = Path(args.pair[1])
        pairs = [(sff, d, d.stem)]
    elif args.walk:
        seen: set[tuple[Path, Path]] = set()
        for root in args.walk:
            for sff, d, label in walk_for_pairs(Path(root)):
                key = (sff.resolve(), d.resolve())
                if key in seen:
                    continue
                seen.add(key)
                pairs.append((sff, d, label))
    elif args.path:
        pairs = find_pairs_in_dir(Path(args.path))
    else:
        ap.error("provide a path, --pair, or --walk")

    if not pairs:
        print("No SFF+DEF pairs found.", file=sys.stderr)
        return 1

    results = [analyze_pair(s, d, label) for s, d, label in pairs]

    out_path = Path(args.out)
    out_path.write_text(json.dumps(results, indent=2))
    print_markdown_table(results)
    print(f"\nWrote {len(results)} entries to {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
