import assert from "node:assert/strict";
import test from "node:test";
import { buildExportDebugFixture } from "../src/lib/exportDebug.ts";
import type { StageConfig, StageTemplate } from "../src/types/stage.ts";

const template: StageTemplate = {
  id: "T3_STANDARD",
  displayName: "1280x720 IKEMEN GO Standard",
  confidence: "Empirical",
  localcoordW: 1280,
  localcoordH: 720,
  bgWidth: 1800,
  bgHeight: 1050,
  axisX: 900,
  axisY: 1050,
  boundLeft: -260,
  boundRight: 260,
  boundHigh: -330,
  boundLow: 0,
  zoffset: 594,
  tension: 200,
  floorTension: 400,
  verticalFollow: 0.75,
  screenLeft: 60,
  screenRight: 60,
  sourceStage: "CF3GRAVE",
  sourceAuthor: "JoeStar",
};

const config: StageConfig = {
  name: "Training Cliff",
  author: "Stage Maker",
  music: null,
  templateId: "T3_STANDARD",
  bgImagePath: "cliff.png",
  bgImageWidth: null,
  bgImageHeight: null,
  conformanceState: { type: "Correct" },
};

test("builds export debug details from template and config", () => {
  const fixture = buildExportDebugFixture(template, config);

  assert.deepEqual(fixture.sffSprites, [
    {
      group: 0,
      image: 0,
      label: "main",
      dimensions: "1800x1050",
      axis: "900,1050",
      source: "cliff.png",
    },
    {
      group: 9000,
      image: 1,
      label: "thumbnail",
      dimensions: "240x100",
      axis: "0,0",
      source: "generated from main",
    },
  ]);

  assert.match(fixture.defPreview, /spr = Training Cliff\.sff/);
  assert.match(fixture.defPreview, /localcoord = 1280,720/);
  assert.match(fixture.defPreview, /boundleft = -260/);
  assert.match(fixture.defPreview, /zoffset = 594/);
  assert.match(fixture.defPreview, /spriteno = 0,0/);
  assert.match(fixture.fixtureText, /image = 1800x1050/);
  assert.match(fixture.fixtureText, /start = 0,0/);
  assert.match(fixture.fixtureText, /bounds = -260,260,-330,0/);
});
