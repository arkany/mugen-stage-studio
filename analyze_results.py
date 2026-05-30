#!/usr/bin/env python3
"""
analyze_results.py — Phase 2 analysis over stage-analysis.json.

Reads the parser output, classifies every stage, groups by localcoord,
selects canonical representatives, and prints a markdown report intended
to be redirected into template-candidates.md.
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


CONVENTIONAL_CAMERA = {
    "tension": 60,
    "floortension": 90,
    "verticalfollow": 0.2,
}

# Authors whose stages were produced by us (the broken Swift app or hand-tuned by
# the user). These cannot serve as canonical templates — they would just encode our
# own assumptions. Surfaced in the report but excluded from representative pools.
SELF_AUTHORED = {"mugen stage studio", "david phillips"}


def _is_self_authored(d: dict[str, Any]) -> bool:
    a = (d.get("author") or "").strip().lower()
    return a in SELF_AUTHORED


def load() -> list[dict[str, Any]]:
    p = Path("stage-analysis.json")
    return json.loads(p.read_text())


def _bounds_within_formula(d: dict[str, Any], der: dict[str, Any]) -> bool | None:
    """
    True if the source's [boundleft, boundright] are sign-correct and have
    magnitude no greater than the formula maximum — i.e. the camera stays
    inside the image. None if data missing.

    Conventions checked:
      - boundleft <= 0 (camera scrolls leftward = negative)
      - boundright >= 0
      - |boundleft|  <= expectedBoundleft magnitude
      - |boundright| <= expectedBoundright magnitude

    A stage with bounds tighter than formula is structurally valid; the author
    just chose less scroll than the image allows. Bounds that exceed formula
    let the camera scroll past the image edge → broken.
    """
    bl = d.get("boundleft")
    br = d.get("boundright")
    ebl = der.get("expectedBoundleft")
    ebr = der.get("expectedBoundright")
    if None in (bl, br, ebl, ebr):
        return None
    if bl > 0 or br < 0:
        return False
    return abs(bl) <= abs(ebl) and abs(br) <= abs(ebr)


def classify(r: dict[str, Any]) -> dict[str, Any]:
    s = r.get("sprite")
    d = r.get("def") or {}
    der = r.get("derived") or {}
    bounds_match = bool(der.get("boundsMatchDerived"))
    bounds_within = _bounds_within_formula(d, der) if d and der else None
    axis_correct = bool(s and s.get("axisIsCorrect"))
    parallax_only = bool(r.get("parallax_only"))
    sff_ok = s is not None
    has_def = bool(d)
    failure_reasons: list[str] = []
    if not sff_ok:
        failure_reasons.append(f"sff_unreadable({r.get('sff_error')})")
    if not has_def:
        failure_reasons.append("def_unreadable")
    if parallax_only:
        # Informational, not disqualifying. The (W-lc)/2 formula is conservative
        # for delta < 1, so a parallax-only stage can still pass within-formula
        # checks. We surface this so soft-tier picks are aware their source uses
        # parallax for the main BG (the new app's templates assume delta=1,1).
        failure_reasons.append("parallax_only(no delta=1,1 layer; informational)")
    if sff_ok and not axis_correct:
        ax = s.get("axisX")
        ay = s.get("axisY")
        w = s.get("width")
        h = s.get("height")
        failure_reasons.append(f"axis_wrong(axis=({ax},{ay}) expected=({w//2},{h}))")
    if has_def and not bounds_match:
        ebl = der.get("expectedBoundleft")
        ebr = der.get("expectedBoundright")
        bl = d.get("boundleft")
        br = d.get("boundright")
        if bounds_within is True:
            note = "tighter-than-formula"
        elif bounds_within is False:
            note = "exceeds-formula"
        else:
            note = "unknown"
        failure_reasons.append(
            f"bounds_diverge[{note}](actual=[{bl},{br}] expected=[{ebl},{ebr}])"
        )
    return {
        "stage": r["stage"],
        "directory": r.get("directory"),
        "sff_version": r.get("sff_version"),
        "author": d.get("author"),
        "selfAuthored": _is_self_authored(d),
        "parallaxOnly": parallax_only,
        "axisCorrect": axis_correct,
        "boundsMatch": bounds_match,
        "boundsWithinFormula": bool(bounds_within),
        "valid_strict": axis_correct and bounds_match,
        "valid_bounds_only": bounds_match and not axis_correct,
        "valid_soft": bool(bounds_within) and not bounds_match,
        "failure_reasons": failure_reasons,
        "raw": r,
    }


def group_by_localcoord(classified: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for c in classified:
        d = c["raw"].get("derived") or {}
        lcw = d.get("localcoordWidth")
        lch = d.get("localcoordHeight")
        if lcw is None:
            continue
        key = f"{lcw},{lch}"
        groups[key].append(c)
    return groups


def conventional_score(c: dict[str, Any]) -> int:
    """Higher = more conventional camera params. Tie-breaker."""
    d = c["raw"].get("def") or {}
    score = 0
    if d.get("tension") == CONVENTIONAL_CAMERA["tension"]:
        score += 1
    if d.get("floortension") == CONVENTIONAL_CAMERA["floortension"]:
        score += 1
    vf = d.get("verticalfollow")
    if vf is not None and abs(vf - CONVENTIONAL_CAMERA["verticalfollow"]) < 1e-6:
        score += 1
    return score


def select_representative(group: list[dict[str, Any]]) -> tuple[dict[str, Any] | None, str]:
    """
    Pick the best canonical representative within a localcoord group, in tiers:
      1. strict   — axis correct AND bounds exactly match formula.
      2. bounds   — bounds exactly match formula but axis convention differs.
      3. soft     — bounds within (≤) formula maximum and sign-correct;
                    author chose tighter scroll than the image allows. Camera
                    params + zoffset are still usable; bounds in the template
                    will be formula-derived from a chosen image dimension.
    Within each tier, prefer the modal image dimension; tie-break on
    conventional camera params (60 / 90 / 0.2). Returns (rep, tier) or (None, "").
    """
    # Self-authored stages (this user's broken Swift app, or hand-tuned by the
    # user) would just encode our own assumptions — exclude them from the
    # canonical representative pool.
    eligible = [c for c in group if not c["selfAuthored"]]
    tiered = [
        ("strict", [c for c in eligible if c["valid_strict"]]),
        ("bounds", [c for c in eligible if c["valid_bounds_only"]]),
        ("soft", [c for c in eligible if c["valid_soft"]]),
    ]
    pool: list[dict[str, Any]] = []
    tier = ""
    for t, members in tiered:
        if members:
            pool, tier = members, t
            break
    if not pool:
        return None, ""

    # Mode of (w,h) within pool
    dim_counts: dict[tuple[int, int], int] = defaultdict(int)
    for c in pool:
        s = c["raw"].get("sprite")
        if s:
            dim_counts[(s["width"], s["height"])] += 1
    if dim_counts:
        common_dim = max(dim_counts.items(), key=lambda kv: kv[1])[0]
        primary = [
            c
            for c in pool
            if c["raw"].get("sprite")
            and (c["raw"]["sprite"]["width"], c["raw"]["sprite"]["height"]) == common_dim
        ]
    else:
        primary = pool

    primary.sort(key=lambda c: (-conventional_score(c), c["stage"]))
    return primary[0], tier


def format_template(name: str, lc_key: str, rep: dict[str, Any], tier: str) -> str:
    s = rep["raw"]["sprite"]
    d = rep["raw"]["def"]
    der = rep["raw"]["derived"]
    lcw = der["localcoordWidth"]
    lch = der["localcoordHeight"]

    tier_badge = {
        "strict": "**Tier:** strict (axis + bounds match formula)",
        "bounds": "**Tier:** bounds-match (formula bounds; non-canonical axis convention)",
        "soft":   "**Tier:** soft (bounds tighter than formula; template uses formula-derived bounds, copies camera + zoffset from source)",
    }.get(tier, "")

    lc_note = ""
    src = der.get("localcoordSource") or ""
    if src == "default(320,240)":
        lc_note = "  *(implicit — DEF omitted localcoord; MUGEN defaults to 320,240)*"
    elif src.startswith("implicit"):
        lc_note = "  *(implicit via legacy `hires = 1` flag → 640,480)*"

    axis_note = (
        "  *(matches our center-bottom rule)*"
        if rep["axisCorrect"]
        else "  *(non-canonical; new app will rewrite to (w/2, h))*"
    )

    if tier == "soft":
        bounds_lines = [
            f"- **boundleft (template, formula-derived):** **{der.get('expectedBoundleft')}**  "
            f"_(source DEF used `{d.get('boundleft')}` — tighter than formula; either is safe)_",
            f"- **boundright (template, formula-derived):** **{der.get('expectedBoundright')}**  "
            f"_(source DEF used `{d.get('boundright')}`)_",
            f"- **boundhigh (template, formula-derived max):** **{der.get('expectedBoundhigh')}**  "
            f"_(source DEF used `{d.get('boundhigh')}`)_",
        ]
    else:
        bounds_lines = [
            f"- **boundleft:** {d.get('boundleft')}    *(expected {der.get('expectedBoundleft')})*",
            f"- **boundright:** {d.get('boundright')}   *(expected {der.get('expectedBoundright')})*",
            f"- **boundhigh:** {d.get('boundhigh')}    *(formula expects {der.get('expectedBoundhigh')})*",
        ]

    lines = [
        f"### Template: \"{name}\"",
        "",
        tier_badge,
        "",
        f"- **Source stage:** `{rep['stage']}` ({rep['raw']['sff_file']} + {rep['raw']['def_file']})",
        f"- **Source author:** {d.get('author') or '—'}",
        f"- **Source dir:** `{rep['raw'].get('directory')}`",
        f"- **localcoord:** `{lcw},{lch}`{lc_note}",
        f"- **Background image:** {s['width']}×{s['height']} (SFF v{rep['raw']['sff_version']})",
        f"- **Sprite axis (in source SFF):** ({s['axisX']}, {s['axisY']}){axis_note}",
        *bounds_lines,
        f"- **boundlow:** {d.get('boundlow')}",
        f"- **zoffset:** {d.get('zoffset')}",
        f"- **tension:** {d.get('tension')}",
        f"- **floortension:** {d.get('floortension')}",
        f"- **verticalfollow:** {d.get('verticalfollow')}",
        f"- **screenleft:** {d.get('screenleft')}",
        f"- **screenright:** {d.get('screenright')}",
        "",
        "**Derivation:**",
        "",
        "```",
        f"boundleft  = -((imageWidth  - localcoordWidth)  / 2) "
        f"= -(({s['width']} - {lcw}) / 2) = {der.get('expectedBoundleft')}",
        f"boundright =  ((imageWidth  - localcoordWidth)  / 2) "
        f"=  (({s['width']} - {lcw}) / 2) = {der.get('expectedBoundright')}",
        f"boundhigh  = -(imageHeight - localcoordHeight)      "
        f"= -({s['height']} - {lch})         = {der.get('expectedBoundhigh')}",
        "```",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    data = load()
    classified = [classify(r) for r in data]

    valid_strict = [c for c in classified if c["valid_strict"]]
    valid_bounds_only = [c for c in classified if c["valid_bounds_only"]]
    valid_soft = [c for c in classified if c["valid_soft"]]
    broken = [
        c
        for c in classified
        if not (c["valid_strict"] or c["valid_bounds_only"] or c["valid_soft"])
    ]

    out: list[str] = []
    out.append("# MUGEN Stage Studio — Phase 2 Template Candidates")
    out.append("")
    out.append("Generated by `analyze_results.py` from `stage-analysis.json`.")
    out.append("")
    self_authored = [c for c in classified if c["selfAuthored"]]
    out.append(
        f"**Total stages parsed:** {len(classified)}  "
        f"  •  strict: {len(valid_strict)}  "
        f"  •  bounds-only: {len(valid_bounds_only)}  "
        f"  •  soft: {len(valid_soft)}  "
        f"  •  broken: {len(broken)}  "
        f"  •  self-authored (excluded from canonical pool): {len(self_authored)}"
    )
    out.append("")

    # Section: classification summary
    out.append("## 1. Validity classification")
    out.append("")
    out.append("We apply three checks per stage:")
    out.append("")
    out.append(
        "1. **`axisCorrect`** — sprite axis equals `(imageWidth/2, imageHeight)`. "
        "This is the rule the new app will enforce."
    )
    out.append(
        "2. **`boundsMatchDerived`** — `boundleft`/`boundright` exactly equal "
        "`±(imageWidth − localcoordWidth) / 2` (camera scrolls to the image edges)."
    )
    out.append(
        "3. **`boundsWithinFormula`** — sign-correct (`boundleft ≤ 0`, "
        "`boundright ≥ 0`) and `|boundleft|, |boundright|` ≤ formula maximum. "
        "Stages that pass this but not (2) just chose tighter scroll than the image "
        "allows; they're structurally valid."
    )
    out.append("")
    out.append(
        "*Note:* MUGEN treats omitted `localcoord` as `320,240`. Stages without an "
        "explicit declaration are evaluated against that default. We also use the DEF's "
        "first `[BG ]` element's `spriteno` to find the right sprite in the SFF — many "
        "stages do not put their main background at `(0,0)`."
    )
    out.append("")

    out.append("### 1a. Strict-valid stages (axisCorrect AND boundsMatchDerived)")
    out.append("")
    if valid_strict:
        out.append("| stage | author | localcoord | imgW×imgH | zoffset | self-auth? |")
        out.append("|---|---|---|---|---|---|")
        for c in valid_strict:
            s = c["raw"]["sprite"]
            d = c["raw"]["def"]
            der = c["raw"]["derived"]
            lc = f"{der['localcoordWidth']},{der['localcoordHeight']}"
            src = der.get("localcoordSource") or ""
            if src == "default(320,240)":
                lc += " *(default)*"
            elif src.startswith("implicit"):
                lc += " *(hires=1)*"
            out.append(
                f"| `{c['stage']}` | {c.get('author') or '—'} | {lc} | "
                f"{s['width']}×{s['height']} | {d.get('zoffset')} | "
                f"{'**yes**' if c['selfAuthored'] else 'no'} |"
            )
    else:
        out.append("_None — see notes below._")
    out.append("")

    out.append("### 1b. Bounds-valid only (axisCorrect=False, boundsMatchDerived=True)")
    out.append("")
    out.append(
        "These stages have correct bounds math but use a non-center-bottom axis "
        "convention. The most common alternate convention seen in the data is "
        "**axis = (w/2, zoffset)** — i.e. the sprite anchor sits at the floor inside "
        "the image, rather than at the bottom edge. Both conventions can produce a "
        "working stage, but the new app standardizes on center-bottom and rewrites "
        "axes on import."
    )
    out.append("")
    if valid_bounds_only:
        out.append(
            "| stage | author | localcoord | imgW×imgH | axis(actual) | zoffset | axis hint | self-auth? |"
        )
        out.append("|---|---|---|---|---|---|---|---|")
        for c in valid_bounds_only:
            s = c["raw"]["sprite"]
            d = c["raw"]["def"]
            der = c["raw"]["derived"]
            lc = f"{der['localcoordWidth']},{der['localcoordHeight']}"
            src = der.get("localcoordSource") or ""
            if src == "default(320,240)":
                lc += "*"
            elif src.startswith("implicit"):
                lc += "†"
            ax, ay = s["axisX"], s["axisY"]
            w, h = s["width"], s["height"]
            hint = ""
            if ax == w // 2 and ay == d.get("zoffset"):
                hint = "axis = (w/2, zoffset)"
            elif ax == 0 and ay == 0:
                hint = "axis at (0,0)"
            elif ax == w // 2 and ay == 0:
                hint = "axis = (w/2, 0)"
            else:
                hint = "non-standard"
            out.append(
                f"| `{c['stage']}` | {c.get('author') or '—'} | {lc} | {w}×{h} | "
                f"({ax},{ay}) | {d.get('zoffset')} | {hint} | "
                f"{'**yes**' if c['selfAuthored'] else 'no'} |"
            )
    else:
        out.append("_None._")
    out.append("")

    out.append(
        "### 1c. Soft references (boundsWithinFormula=True, boundsMatchDerived=False)"
    )
    out.append("")
    out.append(
        "These stages have bounds tighter than the formula maximum — author "
        "chose less scroll than the image allows. The new app derives bounds from "
        "the formula, so we keep their `zoffset`, camera params, and "
        "`screenleft`/`screenright` as canonical, but override their bounds."
    )
    out.append("")
    if valid_soft:
        out.append(
            "| stage | author | localcoord | imgW×imgH | source bounds (L/R) | formula bounds (L/R) | zoffset | self-auth? |"
        )
        out.append("|---|---|---|---|---|---|---|---|")
        for c in valid_soft:
            s = c["raw"]["sprite"]
            d = c["raw"]["def"]
            der = c["raw"]["derived"]
            lc = f"{der['localcoordWidth']},{der['localcoordHeight']}"
            src = der.get("localcoordSource") or ""
            if src == "default(320,240)":
                lc += "*"
            elif src.startswith("implicit"):
                lc += "†"
            out.append(
                f"| `{c['stage']}` | {c.get('author') or '—'} | {lc} | "
                f"{s['width']}×{s['height']} | "
                f"{d.get('boundleft')}/{d.get('boundright')} | "
                f"{der.get('expectedBoundleft')}/{der.get('expectedBoundright')} | "
                f"{d.get('zoffset')} | "
                f"{'**yes**' if c['selfAuthored'] else 'no'} |"
            )
    else:
        out.append("_None._")
    out.append("")

    out.append("### 1d. Broken stages (excluded from template selection)")
    out.append("")
    out.append("| stage | localcoord | reasons |")
    out.append("|---|---|---|")
    for c in broken:
        der = c["raw"].get("derived") or {}
        if der.get("localcoordWidth") is not None:
            lc = f"{der['localcoordWidth']},{der['localcoordHeight']}"
            src = der.get("localcoordSource") or ""
            if src == "default(320,240)":
                lc += "*"
            elif src.startswith("implicit"):
                lc += "†"
        else:
            lc = "?"
        reasons = "; ".join(c["failure_reasons"]) or "—"
        out.append(f"| `{c['stage']}` | {lc} | {reasons} |")
    out.append("")
    out.append(
        "*\\* Asterisk indicates `localcoord` was implicit and defaulted to `320,240`. "
        "† Dagger indicates `localcoord` was implicit via the legacy `hires = 1` flag → `640,480`.*"
    )
    out.append("")

    # Section: groups
    out.append("## 2. localcoord groups")
    out.append("")

    expected_groups = ["320,240", "640,480", "1280,720", "1920,1080"]
    groups = group_by_localcoord(classified)

    out.append(
        "Counts of valid stages per `localcoord` group (broken excluded):"
    )
    out.append("")
    out.append(
        "| localcoord | total parsed | strict | bounds-only | soft | absent? |"
    )
    out.append("|---|---|---|---|---|---|")
    seen_keys = set()
    for key in expected_groups:
        members = groups.get(key, [])
        seen_keys.add(key)
        strict_n = sum(1 for c in members if c["valid_strict"])
        bounds_n = sum(1 for c in members if c["valid_bounds_only"])
        soft_n = sum(1 for c in members if c["valid_soft"])
        absent = "yes — no stages in data" if not members else ""
        out.append(
            f"| `{key}` | {len(members)} | {strict_n} | {bounds_n} | {soft_n} | {absent} |"
        )
    extras = [k for k in groups if k not in seen_keys]
    for key in extras:
        members = groups[key]
        strict_n = sum(1 for c in members if c["valid_strict"])
        bounds_n = sum(1 for c in members if c["valid_bounds_only"])
        soft_n = sum(1 for c in members if c["valid_soft"])
        out.append(
            f"| `{key}` *(non-standard)* | {len(members)} | {strict_n} | {bounds_n} | {soft_n} | — |"
        )
    out.append("")

    # Section: canonical representatives
    out.append("## 3. Canonical template selections")
    out.append("")
    out.append(
        "For each localcoord group with at least one bounds-valid stage, we select a "
        "single representative. Selection rule:"
    )
    out.append("")
    out.append(
        "**Self-authored stages are excluded from the canonical pool** — they were "
        "produced by the original broken Swift app (`MUGEN Stage Studio`) or "
        "hand-tuned by the project author (`David Phillips`). Picking them as "
        "canonical references would just encode our own assumptions.\n\n"
    )

    out.append(
        "1. Prefer **strict** (axis + bounds correct).\n"
        "2. Otherwise fall back to **bounds-only** (formula bounds; non-canonical axis).\n"
        "3. Otherwise fall back to **soft** (bounds tighter than formula). For soft tier, "
        "the template uses formula-derived bounds; the source's `zoffset` and camera "
        "params are still copied.\n"
        "4. Within the tier, pick the modal image dimension across the group "
        "(reflects the standard frame for that localcoord).\n"
        "5. Tie-break by conventional camera params (tension=60, floortension=90, "
        "verticalfollow=0.2).\n"
    )

    template_names = {
        "320,240": "320×240 Classic (WinMUGEN / lo-res)",
        "640,480": "640×480 MUGEN 1.0 hi-res",
        "1280,720": "1280×720 IKEMEN GO Standard",
        "1920,1080": "1920×1080 IKEMEN GO 1080p",
    }

    for key in expected_groups + extras:
        members = groups.get(key, [])
        rep, tier = select_representative(members)
        name = template_names.get(key, f"{key} (non-standard)")
        if rep is None:
            out.append(f"### Template: \"{name}\"")
            out.append("")
            if not members:
                out.append("_No stages in the dataset declared this localcoord._")
            else:
                out.append(
                    "_No representative selectable — every stage in this group has "
                    "bounds that exceed the formula maximum, inverted bound signs, "
                    "or unparseable SFF/DEF. See section 1d for per-stage reasons._"
                )
            out.append("")
            continue
        out.append(format_template(name, key, rep, tier))

    # Section: notes / open questions
    out.append("## 4. Notes for Phase 3 / Phase 4")
    out.append("")
    out.append(
        "- **Axis convention divergence.** Most working reference stages do **not** "
        "use the strict `(w/2, h)` axis. The most common pattern is `(w/2, zoffset)` "
        "(floor-anchored). The new app should still rewrite axes to center-bottom on "
        "import and adjust BG `start` accordingly — but the templates derived here "
        "are valid because we draw `localcoord`, dimensions, bounds, and `zoffset` "
        "from the DEF, not from the source axis."
    )
    out.append("")
    out.append(
        "- **`localcoord` defaulting.** Many older stages omit `localcoord` entirely; "
        "MUGEN treats this as `320,240`. The parser respects that default, so a stage "
        "marked `320,240*` had no explicit declaration."
    )
    out.append("")
    out.append(
        "- **Legacy `hires = 1` flag.** Pre-1.0 stages indicated 640×480 coordinate "
        "space via `hires = 1` in `[StageInfo]` instead of `localcoord`. The parser "
        "treats those as implicit `localcoord = 640,480` (marked `†` in tables)."
    )
    out.append("")
    out.append(
        "- **640×480 source caveat.** Only one of three 640×480 reference stages has "
        "structurally sane bounds (`SamuraiPalace`, soft tier). Its background image "
        "is 2047×2498 — unusually tall for a 640×480 stage, which produces a very "
        "large `boundhigh` (≈ −2018). Phase 4 may want a more conventional "
        "recommended image size (e.g. 1280×480 for 2:1 horizontal scroll, no "
        "vertical) when the user creates a new 640×480 stage; the formula handles "
        "any image size, so the template's recommended dimensions are a UX choice, "
        "not a math constraint."
    )
    out.append("")
    out.append(
        "- **No `1920×1080` source stages found.** Phase 3/4 templates for that "
        "localcoord will need to be derived from the formula alone (analogously to "
        "the 1280×720 group, where the canonical pattern is "
        "`imageWidth = 1.2 × localcoordWidth, imageHeight = 1.42 × localcoordHeight`)."
    )
    out.append("")
    out.append(
        "- **`spriteno` lookup.** Some SFFs (e.g. `Beast_Lab`, `Utopia`) place the "
        "main BG at sprite numbers other than `(0,0)`. The parser reads the DEF's "
        "first `[BG ]` element's `spriteno` and uses that as the lookup hint."
    )
    out.append("")
    out.append(
        "- **`boundhigh` is informational.** The formula "
        "`boundhigh = -(imageHeight - localcoordHeight)` represents the *maximum* "
        "vertical scroll allowed by image size. Real stages frequently use a smaller "
        "(less negative) value to limit camera rise — that's a creative choice, not "
        "an error. Templates record both the source value and the formula maximum."
    )
    out.append("")

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
