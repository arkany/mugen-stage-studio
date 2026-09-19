// The preview canvas: the screen, the camera's reach, the lifebar zone and the
// floor line, drawn over the actual backdrop with two fighters standing on it.
//
// Every geometric value drawn here is read from the backend's `DerivedStage`.
// The one value this component sends back is the floor line the user drags
// (or nudges with the arrow keys).

import { useCallback, useId, useRef, useState } from "react";
import { ImagePlus, Maximize } from "lucide-react";
import type { DerivedStage, StageTemplate } from "../types/stage";
import { dims } from "../lib/templateMeta";

interface Props {
  template: StageTemplate;
  imageUrl: string | null;
  derived: DerivedStage | null;
  /** Native artwork height, so floor moves report in native pixels. */
  nativeHeight: number | null;
  onFloorChange: (nativeFloorY: number) => void;
  onBrowse: () => void;
  /** Text for the arcade-style stamp; a new `key` replays the animation. */
  stamp: { key: number; text: string; tone: "gold" | "good" } | null;
  /** Floating panel shown over the bottom of the stage (e.g. the export result). */
  overlay?: React.ReactNode;
}

interface Layers {
  screen: boolean;
  lifebars: boolean;
  fighters: boolean;
}

/** Share of viewport height the lifebars occupy; mirrors stage-core. */
const LIFEBAR_ZONE_RATIO = 0.15;
/** Character height as a share of viewport height; mirrors stage-core. */
const CHARACTER_HEIGHT_RATIO = 0.375;

export function StagePreview({
  template: t,
  imageUrl,
  derived,
  nativeHeight,
  onFloorChange,
  onBrowse,
  stamp,
  overlay,
}: Props) {
  const [zoom, setZoom] = useState(1);
  const [layers, setLayers] = useState<Layers>({ screen: true, lifebars: true, fighters: true });
  const uid = useId().replace(/:/g, "");
  const toggle = (key: keyof Layers) => setLayers((l) => ({ ...l, [key]: !l[key] }));

  return (
    <section
      aria-label="Stage preview"
      className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border border-line bg-surface"
    >
      <div className="flex flex-wrap items-center gap-x-5 gap-y-2 border-b border-line px-4 py-2.5">
        <h2 className="text-[16px] font-bold">Stage preview</h2>

        <div className="ml-auto flex items-center gap-2 text-[13px]">
          <label htmlFor={`${uid}-zoom`} className="text-muted">
            Zoom
          </label>
          <input
            id={`${uid}-zoom`}
            type="range"
            min={1}
            max={4}
            step={0.25}
            value={zoom}
            onChange={(e) => setZoom(Number(e.target.value))}
            className="w-28 accent-p1"
          />
          <span className="w-10 font-mono text-[12px] tabular-nums">{Math.round(zoom * 100)}%</span>
          <button
            type="button"
            onClick={() => setZoom(1)}
            disabled={zoom === 1}
            title="Fit to window"
            aria-label="Fit to window"
            className="grid size-7 place-items-center rounded-md text-muted hover:bg-raised hover:text-ink disabled:opacity-40"
          >
            <Maximize size={15} />
          </button>
        </div>

        <fieldset className="flex items-center gap-3 text-[13px]">
          <legend className="sr-only">Overlays</legend>
          {(
            [
              ["screen", "Screen"],
              ["lifebars", "Lifebars"],
              ["fighters", "Fighters"],
            ] as const
          ).map(([key, label]) => (
            <label key={key} className="flex cursor-pointer items-center gap-1.5">
              <input
                type="checkbox"
                checked={layers[key]}
                onChange={() => toggle(key)}
                className="size-3.5 accent-p1"
              />
              {label}
            </label>
          ))}
        </fieldset>
      </div>

      <div className="relative min-h-0 flex-1 bg-stage">
        <div className="absolute inset-0 overflow-auto">
          {imageUrl && derived && nativeHeight ? (
            <DerivedCanvas
              uid={uid}
              imageUrl={imageUrl}
              derived={derived}
              nativeHeight={nativeHeight}
              onFloorChange={onFloorChange}
              layers={layers}
              zoom={zoom}
            />
          ) : (
            <EmptyCanvas template={t} layers={layers} zoom={zoom} uid={uid} />
          )}
        </div>

        {!imageUrl && (
          <div className="pointer-events-none absolute inset-0 grid place-items-center">
            <button
              type="button"
              onClick={onBrowse}
              tabIndex={-1}
              aria-hidden
              className="pointer-events-auto flex flex-col items-center gap-2 rounded-xl border-2 border-dashed border-white/30 bg-black/45 px-8 py-6 text-white backdrop-blur-sm transition-colors hover:border-p2"
            >
              <ImagePlus size={28} />
              <span className="font-display text-[26px] leading-none tracking-wider">Drop an image here</span>
              <span className="text-[13px] text-white/75">
                Suggested: {dims(t.recommendedBgWidth, t.recommendedBgHeight)} or larger
              </span>
            </button>
          </div>
        )}

        {imageUrl && derived && (
          <div className="pointer-events-none absolute bottom-3 left-3 z-10 flex gap-3 rounded-md bg-black/60 px-2.5 py-1.5 text-[12px] text-white backdrop-blur-sm">
            <Legend swatch="bg-gold">Floor: drag it onto the ground</Legend>
            <Legend swatch="border-2 border-dashed border-white/70">Camera reach</Legend>
          </div>
        )}

        {overlay && <div className="absolute inset-x-0 bottom-4 z-20 flex justify-center">{overlay}</div>}

        {stamp && (
          <div
            key={stamp.key}
            aria-hidden
            className={
              "stamp rounded-lg border-4 px-6 py-2 font-display text-[64px] leading-none tracking-wider drop-shadow-[0_4px_0_rgba(0,0,0,0.6)] " +
              (stamp.tone === "gold" ? "border-gold text-gold" : "border-good text-good")
            }
          >
            {stamp.text}
          </div>
        )}
      </div>
    </section>
  );
}

/** The real stage: artwork in its own (scaled) pixel grid, overlays from `DerivedStage`. */
function DerivedCanvas({
  uid,
  imageUrl,
  derived,
  nativeHeight,
  onFloorChange,
  layers,
  zoom,
}: {
  uid: string;
  imageUrl: string;
  derived: DerivedStage;
  nativeHeight: number;
  onFloorChange: (nativeFloorY: number) => void;
  layers: Layers;
  zoom: number;
}) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const { placement, bounds, localcoordW: W, localcoordH: H, bgWidth, bgHeight } = derived;

  // The SVG's user space is the artwork's own pixel grid, so every
  // screen-space value just needs the artwork's top-left subtracted from it.
  const toX = (screenX: number) => screenX - placement.left;
  const toY = (screenY: number) => screenY - placement.top;

  const viewport = { x: toX(-W / 2), y: toY(0), w: W, h: H };
  const floorY = toY(derived.zoffset);
  const reach = {
    x: toX(bounds.boundLeft - W / 2),
    y: toY(bounds.boundHigh),
    w: bounds.boundRight - bounds.boundLeft + W,
    h: H - bounds.boundHigh,
  };

  const pad = bgWidth * 0.02;
  const u = H / 34;
  const fighterH = H * CHARACTER_HEIGHT_RATIO;
  const fighterX = W * 0.17;
  const centerX = viewport.x + W / 2;

  // Pointer → SVG user space → native artwork row. getScreenCTM accounts for
  // letterboxing and zoom, so the handle tracks the pointer exactly.
  const reportFloor = useCallback(
    (clientX: number, clientY: number) => {
      const svg = svgRef.current;
      const ctm = svg?.getScreenCTM();
      if (!svg || !ctm) return;
      const pt = svg.createSVGPoint();
      pt.x = clientX;
      pt.y = clientY;
      const y = pt.matrixTransform(ctm.inverse()).y;
      const scaledY = Math.max(0, Math.min(bgHeight, y));
      onFloorChange(Math.round((scaledY / bgHeight) * nativeHeight));
    },
    [bgHeight, nativeHeight, onFloorChange],
  );

  const nativeFloor = Math.round((floorY / bgHeight) * nativeHeight);
  const nudge = (e: React.KeyboardEvent) => {
    const step = e.shiftKey ? Math.round(nativeHeight / 20) : Math.max(1, Math.round(nativeHeight / 200));
    if (e.key === "ArrowUp") onFloorChange(Math.max(0, nativeFloor - step));
    else if (e.key === "ArrowDown") onFloorChange(Math.min(nativeHeight, nativeFloor + step));
    else return;
    e.preventDefault();
  };

  return (
    <svg
      ref={svgRef}
      viewBox={`${-pad} ${-pad} ${bgWidth + pad * 2} ${bgHeight + pad * 2}`}
      preserveAspectRatio="xMidYMid meet"
      style={{ width: `${zoom * 100}%`, height: `${zoom * 100}%`, display: "block" }}
      className="touch-none select-none"
      role="group"
      aria-label={`Stage preview: ${W} × ${H} screen over a ${bgWidth} × ${bgHeight} background`}
    >
      <defs>
        <mask id={`${uid}-reach`}>
          <rect x={0} y={0} width={bgWidth} height={bgHeight} fill="white" />
          <rect x={reach.x} y={reach.y} width={reach.w} height={reach.h} fill="black" />
        </mask>
      </defs>

      <image href={imageUrl} x={0} y={0} width={bgWidth} height={bgHeight} preserveAspectRatio="none" />

      {/* Artwork the camera can never reach. */}
      <rect x={0} y={0} width={bgWidth} height={bgHeight} fill="black" opacity={0.5} mask={`url(#${uid}-reach)`} />
      <rect
        x={reach.x}
        y={reach.y}
        width={reach.w}
        height={reach.h}
        fill="none"
        stroke="white"
        strokeOpacity="0.7"
        strokeWidth={1.5}
        strokeDasharray="6 5"
        vectorEffect="non-scaling-stroke"
      />
      <Tag x={reach.x + u * 0.6} y={reach.y + u * 0.6} u={u} anchor="start" faint>
        Camera reach
      </Tag>

      {layers.lifebars && (
        <g>
          <rect x={viewport.x} y={viewport.y} width={W} height={H * LIFEBAR_ZONE_RATIO} fill="var(--p1)" opacity={0.22} />
          <LifebarShapes x={viewport.x} y={viewport.y} w={W} h={H} />
        </g>
      )}

      {layers.screen && (
        <g>
          <rect
            x={viewport.x}
            y={viewport.y}
            width={W}
            height={H}
            fill="none"
            stroke="white"
            strokeWidth={2}
            vectorEffect="non-scaling-stroke"
          />
          <Tag x={viewport.x + W - u * 0.6} y={viewport.y + H * LIFEBAR_ZONE_RATIO + u * 0.6} u={u} anchor="end">
            {`Screen ${W} × ${H}`}
          </Tag>
        </g>
      )}

      {layers.fighters && (
        <g>
          <Fighter x={centerX - fighterX} floor={floorY} height={fighterH} facing={1} label="P1" color="var(--p1)" u={u} />
          <Fighter x={centerX + fighterX} floor={floorY} height={fighterH} facing={-1} label="P2" color="var(--p2)" u={u} />
        </g>
      )}

      {/* Floor line and its grab handle. */}
      <line
        x1={0}
        x2={bgWidth}
        y1={floorY}
        y2={floorY}
        stroke="var(--gold)"
        strokeWidth={3}
        vectorEffect="non-scaling-stroke"
      />
      <Tag x={viewport.x + W - u * 0.6} y={floorY - u * 2.6} u={u} anchor="end" color="var(--gold)">
        Floor ↕
      </Tag>
      <rect
        x={0}
        y={floorY - bgHeight / 40}
        width={bgWidth}
        height={bgHeight / 20}
        fill="transparent"
        className="cursor-ns-resize outline-none focus-visible:fill-[rgb(255_197_61/0.18)]"
        tabIndex={0}
        role="slider"
        aria-label="Floor line. Drag, or use the up and down arrow keys, to line it up with the ground."
        aria-orientation="vertical"
        aria-valuemin={0}
        aria-valuemax={nativeHeight}
        aria-valuenow={nativeFloor}
        aria-valuetext={`${nativeFloor} pixels from the top of the image`}
        onKeyDown={nudge}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          reportFloor(e.clientX, e.clientY);
        }}
        onPointerMove={(e) => {
          if (e.currentTarget.hasPointerCapture(e.pointerId)) reportFloor(e.clientX, e.clientY);
        }}
        onPointerUp={(e) => e.currentTarget.releasePointerCapture(e.pointerId)}
      />
    </svg>
  );
}

/** Before an image arrives: an empty arena in the template's screen shape. Decorative only. */
function EmptyCanvas({
  template: t,
  layers,
  zoom,
  uid,
}: {
  template: StageTemplate;
  layers: Layers;
  zoom: number;
  uid: string;
}) {
  const W = t.localcoordW;
  const H = t.localcoordH;
  const u = H / 34;
  const floorY = H * t.defaultFloorRatio;
  const pad = W * 0.04;
  return (
    <svg
      viewBox={`${-pad} ${-pad} ${W + pad * 2} ${H + pad * 2}`}
      preserveAspectRatio="xMidYMid meet"
      style={{ width: `${zoom * 100}%`, height: `${zoom * 100}%`, display: "block" }}
      role="img"
      aria-label={`Empty ${W} × ${H} stage`}
    >
      <defs>
        <linearGradient id={`${uid}-empty`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="var(--p2)" stopOpacity="0.16" />
          <stop offset="1" stopColor="var(--p1)" stopOpacity="0.16" />
        </linearGradient>
      </defs>
      <rect x={0} y={0} width={W} height={H} fill={`url(#${uid}-empty)`} />
      {layers.lifebars && <LifebarShapes x={0} y={0} w={W} h={H} />}
      {layers.screen && (
        <rect
          x={0}
          y={0}
          width={W}
          height={H}
          fill="none"
          stroke="white"
          strokeOpacity="0.5"
          strokeWidth={2}
          vectorEffect="non-scaling-stroke"
        />
      )}
      {layers.fighters && (
        <g>
          <Fighter x={W / 2 - W * 0.17} floor={floorY} height={H * CHARACTER_HEIGHT_RATIO} facing={1} label="P1" color="var(--p1)" u={u} />
          <Fighter x={W / 2 + W * 0.17} floor={floorY} height={H * CHARACTER_HEIGHT_RATIO} facing={-1} label="P2" color="var(--p2)" u={u} />
        </g>
      )}
      <line
        x1={0}
        x2={W}
        y1={floorY}
        y2={floorY}
        stroke="white"
        strokeOpacity="0.35"
        strokeWidth={2}
        strokeDasharray="8 6"
        vectorEffect="non-scaling-stroke"
      />
    </svg>
  );
}

function LifebarShapes({ x, y, w, h }: { x: number; y: number; w: number; h: number }) {
  const barW = w * 0.38;
  const barH = h * 0.035;
  const top = y + h * 0.05;
  return (
    <g opacity={0.9} pointerEvents="none">
      <rect x={x + w * 0.04} y={top} width={barW} height={barH} rx={barH / 3} fill="var(--gold)" />
      <rect x={x + w - w * 0.04 - barW} y={top} width={barW} height={barH} rx={barH / 3} fill="var(--gold)" />
    </g>
  );
}

function Legend({ swatch, children }: { swatch: string; children: React.ReactNode }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className={"size-2.5 rounded-sm " + swatch} />
      {children}
    </span>
  );
}

function Tag({
  x,
  y,
  u,
  anchor,
  faint,
  color = "white",
  children,
}: {
  x: number;
  y: number;
  u: number;
  anchor: "start" | "end";
  faint?: boolean;
  color?: string;
  children: string;
}) {
  const fs = u * 1.25;
  const w = children.length * fs * 0.56 + fs * 1.2;
  const h = fs * 1.7;
  const rx = anchor === "end" ? x - w : x;
  return (
    <g opacity={faint ? 0.75 : 1} pointerEvents="none">
      <rect x={rx} y={y} width={w} height={h} rx={h * 0.25} fill="black" fillOpacity="0.6" />
      <text
        x={rx + w / 2}
        y={y + h * 0.68}
        textAnchor="middle"
        fontSize={fs}
        fontWeight={600}
        fill={color}
        fontFamily="var(--font-sans)"
      >
        {children}
      </text>
    </g>
  );
}

/** A fighting-stance silhouette in a 100-unit-tall box, feet at y=100, facing right. */
function Fighter({
  x,
  floor,
  height,
  facing,
  label,
  color,
  u,
}: {
  x: number;
  floor: number;
  height: number;
  facing: 1 | -1;
  label: string;
  color: string;
  u: number;
}) {
  const s = height / 100;
  return (
    <g pointerEvents="none">
      <g
        transform={`translate(${x} ${floor}) scale(${s * facing} ${s}) translate(0 -100)`}
        fill="var(--silhouette)"
        stroke="var(--silhouette)"
        strokeLinecap="round"
        strokeLinejoin="round"
        opacity="0.9"
      >
        <circle cx="5" cy="11" r="7.5" stroke="none" />
        <path d="M -6 20 L 13 20 L 11 53 L -5 53 Z" strokeWidth="6" />
        <polyline points="-2,24 12,39 24,33" fill="none" strokeWidth="7" />
        <polyline points="11,23 24,34 31,23" fill="none" strokeWidth="7" />
        <polyline points="0,53 -13,74 -21,99" fill="none" strokeWidth="9" />
        <polyline points="8,53 21,75 27,99" fill="none" strokeWidth="9" />
        <line x1="-21" y1="99" x2="-28" y2="99" strokeWidth="6" />
        <line x1="27" y1="99" x2="35" y2="99" strokeWidth="6" />
      </g>
      <ellipse cx={x} cy={floor} rx={height * 0.22} ry={height * 0.025} fill="black" opacity="0.35" />
      <text
        x={x}
        y={floor - height - u * 0.6}
        textAnchor="middle"
        fontSize={u * 1.3}
        fontFamily="var(--font-display)"
        letterSpacing={u * 0.08}
        fill={color}
        stroke="black"
        strokeWidth={u * 0.12}
        paintOrder="stroke"
      >
        {label}
      </text>
    </g>
  );
}
