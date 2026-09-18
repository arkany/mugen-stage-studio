// The preview canvas: the viewport, the camera's reach, and the floor line,
// drawn over the actual backdrop.
//
// This is the part that was missing entirely. Every parameter the tool derives
// is a geometric claim about where things sit, and without seeing them over
// the artwork there was no way to notice that a backdrop was mounted above the
// screen or that the floor line was in the sky.
//
// Everything drawn here is read from the backend's `DerivedStage`. The one
// value this component sends back is the floor line the user drags.

import { useCallback, useRef } from "react";
import type { DerivedStage } from "../types/stage";

interface Props {
  imageUrl: string;
  derived: DerivedStage;
  /** Native artwork height, so the drag can report in native pixels. */
  nativeHeight: number;
  onFloorChange: (nativeFloorY: number) => void;
}

/** Share of viewport height the lifebars occupy; mirrors stage-core. */
const LIFEBAR_ZONE_RATIO = 0.15;
/** Character height as a share of viewport height; mirrors stage-core. */
const CHARACTER_HEIGHT_RATIO = 0.375;

export function StagePreview({
  imageUrl,
  derived,
  nativeHeight,
  onFloorChange,
}: Props) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const { placement, bounds, localcoordW, localcoordH, bgWidth, bgHeight } =
    derived;

  // The SVG's user space is the artwork's own pixel grid, so every screen-space
  // value just needs the artwork's top-left subtracted from it.
  const toX = (screenX: number) => screenX - placement.left;
  const toY = (screenY: number) => screenY - placement.top;

  const viewportX = toX(-localcoordW / 2);
  const viewportY = toY(0);
  const floorY = toY(derived.zoffset);

  // The full region the camera can ever reveal.
  const reachX = toX(bounds.boundLeft - localcoordW / 2);
  const reachY = toY(bounds.boundHigh);
  const reachW = bounds.boundRight - bounds.boundLeft + localcoordW;
  const reachH = localcoordH - bounds.boundHigh;

  const characterH = localcoordH * CHARACTER_HEIGHT_RATIO;
  const lifebarH = localcoordH * LIFEBAR_ZONE_RATIO;

  const handleDrag = useCallback(
    (e: React.PointerEvent<SVGRectElement>) => {
      const svg = svgRef.current;
      if (!svg) return;
      const rect = svg.getBoundingClientRect();
      if (rect.height === 0) return;

      // Pointer position -> artwork pixel row -> native artwork pixel row.
      const ratio = (e.clientY - rect.top) / rect.height;
      const scaledY = Math.max(0, Math.min(bgHeight, ratio * bgHeight));
      const native = Math.round((scaledY / bgHeight) * nativeHeight);
      onFloorChange(Math.max(0, Math.min(nativeHeight, native)));
    },
    [bgHeight, nativeHeight, onFloorChange],
  );

  return (
    <div className="space-y-2">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${bgWidth} ${bgHeight}`}
        className="w-full border border-gray-300 rounded bg-gray-100 touch-none select-none dark:border-gray-700 dark:bg-gray-900"
        role="img"
        aria-label="Stage preview with viewport and floor line"
      >
        <image href={imageUrl} x={0} y={0} width={bgWidth} height={bgHeight} />

        {/* Everything outside the camera's reach is dead artwork. */}
        <defs>
          <mask id="reach-mask">
            <rect x={0} y={0} width={bgWidth} height={bgHeight} fill="white" />
            <rect x={reachX} y={reachY} width={reachW} height={reachH} fill="black" />
          </mask>
        </defs>
        <rect
          x={0}
          y={0}
          width={bgWidth}
          height={bgHeight}
          fill="black"
          opacity={0.45}
          mask="url(#reach-mask)"
        />

        {/* Camera reach. */}
        <rect
          x={reachX}
          y={reachY}
          width={reachW}
          height={reachH}
          fill="none"
          stroke="#38bdf8"
          strokeWidth={bgWidth / 400}
          strokeDasharray={`${bgWidth / 100} ${bgWidth / 150}`}
        />

        {/* The viewport at rest. */}
        <rect
          x={viewportX}
          y={viewportY}
          width={localcoordW}
          height={localcoordH}
          fill="none"
          stroke="#22c55e"
          strokeWidth={bgWidth / 300}
        />

        {/* Lifebar zone along the top of the viewport. */}
        <rect
          x={viewportX}
          y={viewportY}
          width={localcoordW}
          height={lifebarH}
          fill="#ef4444"
          opacity={0.18}
        />

        {/* Floor line, and a character box standing on it. */}
        <rect
          x={viewportX + localcoordW * 0.5 - localcoordW * 0.06}
          y={floorY - characterH}
          width={localcoordW * 0.12}
          height={characterH}
          fill="#f59e0b"
          opacity={0.35}
          stroke="#f59e0b"
          strokeWidth={bgWidth / 600}
        />
        <line
          x1={0}
          y1={floorY}
          x2={bgWidth}
          y2={floorY}
          stroke="#f59e0b"
          strokeWidth={bgWidth / 250}
        />

        {/* Fat invisible grab handle over the floor line. */}
        <rect
          x={0}
          y={floorY - bgHeight / 40}
          width={bgWidth}
          height={bgHeight / 20}
          fill="transparent"
          className="cursor-ns-resize"
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            handleDrag(e);
          }}
          onPointerMove={(e) => {
            if (e.currentTarget.hasPointerCapture(e.pointerId)) handleDrag(e);
          }}
          onPointerUp={(e) =>
            e.currentTarget.releasePointerCapture(e.pointerId)
          }
        />
      </svg>

      <ul className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-600 dark:text-gray-300">
        <Key color="#22c55e" label="Viewport at rest" />
        <Key color="#38bdf8" label="Camera reach" />
        <Key color="#f59e0b" label="Floor line — drag to place the ground" />
        <Key color="#ef4444" label="Lifebar zone" />
      </ul>
    </div>
  );
}

function Key({ color, label }: { color: string; label: string }) {
  return (
    <li className="flex items-center gap-1.5">
      <span
        className="inline-block w-3 h-3 rounded-sm border"
        style={{ backgroundColor: color, borderColor: color }}
      />
      {label}
    </li>
  );
}
