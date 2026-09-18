#!/usr/bin/env python3
"""
Re-check `stage-analysis.json` against the corrected coordinate model.

The Phase 2 dataset was validated with two faults:

  1. `boundsMatchDerived` compared only `boundleft` / `boundright`. Every
     vertical-scroll error in the reference set passed silently — which is how
     `Japan` came to be recorded as a clean match while its shipped
     `boundhigh` of -200 sat against a derived -243.

  2. The expected bounds assumed the artwork was mounted flush with the bottom
     of the viewport. Most reference stages are not: they use a top-anchored
     or offset axis with a compensating `[BG] start`. Deriving `boundhigh` as
     `-(imageHeight - localcoordHeight)` is only right for the flush case.

This script re-derives from each stage's actual placement (axis + start) and
its per-layer deltas, then reports which stages genuinely keep the camera
inside their artwork.

It rewrites the `derived` block in place unless `--dry-run` is passed.

Note: the stored dataset carries no zoom fields — the Phase 1 parser never
extracted them — so every stage here is re-checked as if zoom were disabled.
Re-run `parse_stage.py` against the stage library to pick up zoom.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from parse_stage import _layer_deltas, _resolve_placement  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
ANALYSIS = REPO_ROOT / "stage-analysis.json"


def rederive(record: dict) -> dict:
    d = record.get("def") or {}
    derived = dict(record.get("derived") or {})
    sprite = record.get("sprite")

    lcw = derived.get("localcoordWidth")
    lch = derived.get("localcoordHeight")

    derived.update(
        expectedBoundleft=None,
        expectedBoundright=None,
        expectedBoundhigh=None,
        boundsMatchDerived=None,
        boundhighWithinArtwork=None,
        boundsVerdict="no-sprite",
        placement=None,
    )

    if not sprite or sprite.get("width") is None or not lcw:
        return derived

    placement = _resolve_placement(sprite, d)
    derived["placement"] = placement
    if placement is None:
        derived["boundsVerdict"] = "no-placement"
        return derived

    # Phase 1 reads sprite group 0, sprite 0 and treats it as the backdrop.
    # In plenty of stages that sprite is a tile, an overlay or a fragment -
    # anything narrower or shorter than the viewport cannot be the backdrop,
    # and deriving bounds from it says nothing about the stage.
    if sprite["width"] < lcw or sprite["height"] < lch:
        derived["boundsVerdict"] = "sprite-not-backdrop"
        return derived

    deltas = [dx for dx in (_layer_deltas(d) or [1.0]) if dx > 0] or [1.0]
    ebr = int(min(max(0.0, (sprite["width"] - lcw) / (2.0 * dx)) for dx in deltas))
    ebh = -int(max(0.0, -placement["top"]))

    derived["expectedBoundleft"] = -ebr
    derived["expectedBoundright"] = ebr
    derived["expectedBoundhigh"] = ebh

    abl, abr, abh = d.get("boundleft"), d.get("boundright"), d.get("boundhigh")
    checks = []
    if abl is not None:
        checks.append(abl >= -ebr)
    if abr is not None:
        checks.append(abr <= ebr)
    if abh is not None:
        checks.append(abh >= ebh)

    derived["boundsMatchDerived"] = bool(checks) and all(checks)
    derived["boundhighWithinArtwork"] = None if abh is None else abh >= ebh
    derived["boundsVerdict"] = (
        "within-artwork" if derived["boundsMatchDerived"] else "exceeds-artwork"
    )
    return derived


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="report without rewriting")
    ap.add_argument("--path", type=Path, default=ANALYSIS)
    args = ap.parse_args()

    records = json.loads(args.path.read_text())

    changed_verdict = []
    vertical_failures = []
    for r in records:
        before = (r.get("derived") or {}).get("boundsMatchDerived")
        after = rederive(r)
        r["derived"] = after
        if before != after["boundsMatchDerived"]:
            changed_verdict.append((r["stage"], before, after["boundsMatchDerived"]))
        if after.get("boundhighWithinArtwork") is False:
            vertical_failures.append(
                (
                    r["stage"],
                    (r.get("def") or {}).get("boundhigh"),
                    after["expectedBoundhigh"],
                )
            )

    total = len(records)
    clean = sum(1 for r in records if r["derived"]["boundsMatchDerived"])
    skipped = sum(
        1
        for r in records
        if r["derived"]["boundsVerdict"] in ("sprite-not-backdrop", "no-sprite", "no-placement")
    )
    print(
        f"{total} stages re-checked; {clean} keep the camera inside the artwork; "
        f"{skipped} not assessable from sprite 0,0 alone.\n"
    )

    print(f"Verdict changed for {len(changed_verdict)} stage(s) "
          f"(old check ignored boundhigh and assumed a flush-bottom mount):")
    for stage, before, after in changed_verdict:
        print(f"  {stage:<34} {before}  ->  {after}")

    print(f"\n{len(vertical_failures)} stage(s) let the camera rise past the top "
          f"of their own artwork:")
    for stage, actual, expected in vertical_failures:
        print(f"  {stage:<34} boundhigh {actual}  (artwork top {expected})")

    if not args.dry_run:
        args.path.write_text(json.dumps(records, indent=1) + "\n")
        print(f"\nRewrote {args.path.relative_to(REPO_ROOT)}")
    else:
        print("\n(dry run — nothing written)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
