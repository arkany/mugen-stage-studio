import type { StageConfig, StageTemplate } from "../types/stage";

export interface ExportDebugSprite {
  group: number;
  image: number;
  label: "main" | "thumbnail";
  dimensions: string;
  axis: string;
  source: string;
}

export interface ExportDebugFixture {
  stageName: string;
  sffFileName: string;
  defPreview: string;
  fixtureText: string;
  sffSprites: ExportDebugSprite[];
  imageDimensions: string;
  axis: string;
  start: string;
  bounds: string;
  zoffset: number;
}

function stageFileStem(name: string): string {
  const trimmed = name.trim();
  if (!trimmed) return "untitled-stage";

  return trimmed
    .replace(/[^a-zA-Z0-9._ -]+/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function buildExportDebugFixture(
  template: StageTemplate,
  config: StageConfig,
): ExportDebugFixture {
  const stageName = stageFileStem(config.name);
  const sffFileName = `${stageName}.sff`;
  const imageDimensions = `${template.bgWidth}x${template.bgHeight}`;
  const axis = `${template.axisX},${template.axisY}`;
  const start = "0,0";
  const bounds = [
    template.boundLeft,
    template.boundRight,
    template.boundHigh,
    template.boundLow,
  ].join(",");

  const sffSprites: ExportDebugSprite[] = [
    {
      group: 0,
      image: 0,
      label: "main",
      dimensions: imageDimensions,
      axis,
      source: config.bgImagePath ?? "no image selected",
    },
    {
      group: 9000,
      image: 1,
      label: "thumbnail",
      dimensions: "240x100",
      axis: "0,0",
      source: "generated from main",
    },
  ];

  const defPreview = [
    "[Info]",
    `name = "${config.name.trim() || "Untitled Stage"}"`,
    `author = "${config.author.trim() || "unknown"}"`,
    "",
    "[Files]",
    `spr = ${sffFileName}`,
    "",
    "[StageInfo]",
    `localcoord = ${template.localcoordW},${template.localcoordH}`,
    `zoffset = ${template.zoffset}`,
    "",
    "[Camera]",
    `boundleft = ${template.boundLeft}`,
    `boundright = ${template.boundRight}`,
    `boundhigh = ${template.boundHigh}`,
    `boundlow = ${template.boundLow}`,
    `verticalfollow = ${template.verticalFollow}`,
    `tension = ${template.tension}`,
    ...(template.floorTension === null
      ? []
      : [`floortension = ${template.floorTension}`]),
    "",
    "[PlayerInfo]",
    `p1startx = ${-template.localcoordW / 4}`,
    `p2startx = ${template.localcoordW / 4}`,
    "p1starty = 0",
    "p2starty = 0",
    "",
    "[BoundInfo]",
    `screenleft = ${template.screenLeft}`,
    `screenright = ${template.screenRight}`,
    "",
    "[BGdef]",
    `spr = ${sffFileName}`,
    `debugbg = 1`,
    "",
    "[BG main]",
    "type = normal",
    "spriteno = 0,0",
    "layerno = 0",
    `start = ${start}`,
    "delta = 1,1",
    `mask = 0`,
    "",
    "[BGCtrlDef thumbnail]",
    "; SFF sprite 9000,1 is generated for select screens.",
  ].join("\n");

  const fixtureText = [
    `stage = ${config.name.trim() || "Untitled Stage"}`,
    `template = ${template.id}`,
    `sff = ${sffFileName}`,
    `image = ${imageDimensions}`,
    `axis = ${axis}`,
    `start = ${start}`,
    `bounds = ${bounds}`,
    `zoffset = ${template.zoffset}`,
    "sprites:",
    ...sffSprites.map(
      (sprite) =>
        `  ${sprite.group},${sprite.image} ${sprite.label} ${sprite.dimensions} axis ${sprite.axis} source ${sprite.source}`,
    ),
    "",
    "DEF preview:",
    defPreview,
  ].join("\n");

  return {
    stageName,
    sffFileName,
    defPreview,
    fixtureText,
    sffSprites,
    imageDimensions,
    axis,
    start,
    bounds,
    zoffset: template.zoffset,
  };
}
