// ── Isometric Renderer ─────────────────────────────────────────────
import { TILE_W, TILE_H, HALF_W, HALF_H, GRID_SIZE, TERRAIN, BUILDINGS } from "./config.js";
import { STATE } from "./state.js";
import { getRoadMask, isConnectedToRoad, getWaterCoverage, getBuildingLevelData } from "./economy.js";

// Convert grid (x,y) to isometric screen position
export function gridToIso(gx, gy) {
  return {
    sx: (gx - gy) * HALF_W,
    sy: (gx + gy) * HALF_H,
  };
}

// Convert screen position to grid (x,y)
export function isoToGrid(sx, sy) {
  const gx = (sx / HALF_W + sy / HALF_H) / 2;
  const gy = (sy / HALF_H - sx / HALF_W) / 2;
  return { gx: Math.floor(gx), gy: Math.floor(gy) };
}

// Convert screen coordinates to world (accounting for camera)
export function screenToWorld(screenX, screenY, canvasW, canvasH) {
  const zoom = STATE.camera.zoom;
  const wx = (screenX - canvasW / 2) / zoom + STATE.camera.x;
  const wy = (screenY - canvasH / 2) / zoom + STATE.camera.y;
  return { wx, wy };
}

export function worldToScreen(wx, wy, canvasW, canvasH) {
  const zoom = STATE.camera.zoom;
  const sx = (wx - STATE.camera.x) * zoom + canvasW / 2;
  const sy = (wy - STATE.camera.y) * zoom + canvasH / 2;
  return { sx, sy };
}

// ── Day/Night color tinting ──
function getDayNightTint() {
  const t = STATE.dayTime;
  // 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
  if (t < 0.2) return { r: 0.3, g: 0.3, b: 0.5, a: 0.35 };   // night
  if (t < 0.3) return { r: 0.7, g: 0.5, b: 0.4, a: 0.15 };   // dawn
  if (t < 0.7) return { r: 1, g: 1, b: 0.95, a: 0 };          // day
  if (t < 0.8) return { r: 0.9, g: 0.6, b: 0.3, a: 0.15 };   // dusk
  return { r: 0.3, g: 0.3, b: 0.5, a: 0.35 };                  // night
}

function isNight() {
  return STATE.dayTime < 0.2 || STATE.dayTime > 0.8;
}

// ── Terrain colors ──
const TERRAIN_COLORS = {
  [TERRAIN.GRASS]: ["#7bbf5f", "#74b657"],
  [TERRAIN.WATER]: ["#4a9bd9", "#4090cc"],
  [TERRAIN.SAND]: ["#d4c284", "#c9b87a"],
  [TERRAIN.HILL]: ["#8f9f6f", "#849462"],
  [TERRAIN.FOREST]: ["#4f8f3a", "#478733"],
  [TERRAIN.ROCK]: ["#8a8a8a", "#7d7d7d"],
};

// ── Draw isometric diamond tile ──
function drawIsoDiamond(ctx, sx, sy, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(sx, sy - HALF_H);
  ctx.lineTo(sx + HALF_W, sy);
  ctx.lineTo(sx, sy + HALF_H);
  ctx.lineTo(sx - HALF_W, sy);
  ctx.closePath();
  ctx.fill();
}

// Draw isometric tile with height (for hills, buildings)
function drawIsoBlock(ctx, sx, sy, topColor, sideColor1, sideColor2, h) {
  // top
  ctx.fillStyle = topColor;
  ctx.beginPath();
  ctx.moveTo(sx, sy - HALF_H - h);
  ctx.lineTo(sx + HALF_W, sy - h);
  ctx.lineTo(sx, sy + HALF_H - h);
  ctx.lineTo(sx - HALF_W, sy - h);
  ctx.closePath();
  ctx.fill();

  if (h > 0) {
    // left side
    ctx.fillStyle = sideColor1;
    ctx.beginPath();
    ctx.moveTo(sx - HALF_W, sy - h);
    ctx.lineTo(sx, sy + HALF_H - h);
    ctx.lineTo(sx, sy + HALF_H);
    ctx.lineTo(sx - HALF_W, sy);
    ctx.closePath();
    ctx.fill();

    // right side
    ctx.fillStyle = sideColor2;
    ctx.beginPath();
    ctx.moveTo(sx + HALF_W, sy - h);
    ctx.lineTo(sx, sy + HALF_H - h);
    ctx.lineTo(sx, sy + HALF_H);
    ctx.lineTo(sx + HALF_W, sy);
    ctx.closePath();
    ctx.fill();
  }
}

// ── Terrain rendering (draws in world coordinates — canvas transform applied by caller) ──
function drawTerrain(ctx, canvasW, canvasH) {
  for (let gy = 0; gy < GRID_SIZE; gy++) {
    for (let gx = 0; gx < GRID_SIZE; gx++) {
      const { sx, sy } = gridToIso(gx, gy);

      // Frustum culling (check screen-space position)
      const screen = worldToScreen(sx, sy, canvasW, canvasH);
      if (screen.sx < -TILE_W * 2 || screen.sx > canvasW + TILE_W * 2) continue;
      if (screen.sy < -TILE_H * 8 || screen.sy > canvasH + TILE_H * 2) continue;

      const t = STATE.terrain[gy][gx];
      const checker = (gx + gy) % 2;
      const colors = TERRAIN_COLORS[t] || TERRAIN_COLORS[TERRAIN.GRASS];
      const baseColor = colors[checker];

      if (t === TERRAIN.WATER) {
        const wave = Math.sin((gx * 0.7 + gy * 0.5) + STATE.dayTime * Math.PI * 20) * 0.5;
        drawIsoDiamond(ctx, sx, sy + wave, baseColor);
      } else if (t === TERRAIN.HILL) {
        drawIsoBlock(ctx, sx, sy, baseColor, "#6f7f5a", "#5f6f4a", 6);
      } else if (t === TERRAIN.ROCK) {
        drawIsoBlock(ctx, sx, sy, baseColor, "#6a6a6a", "#5a5a5a", 10);
      } else {
        drawIsoDiamond(ctx, sx, sy, baseColor);
      }

      // Forest trees (on terrain layer)
      if (t === TERRAIN.FOREST && !STATE.grid[gy][gx]) {
        drawTree(ctx, sx, sy - 4);
      }
    }
  }
}

function drawTree(ctx, sx, sy) {
  ctx.fillStyle = "#3a6b2a";
  ctx.beginPath();
  ctx.moveTo(sx, sy - 14);
  ctx.lineTo(sx + 6, sy - 2);
  ctx.lineTo(sx - 6, sy - 2);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "#5a3d1e";
  ctx.fillRect(sx - 1, sy - 3, 2, 5);
}

// ── Building sprites (isometric) ──
const BUILDING_PALETTES = {
  hut: { body: "#d9c4a9", roof: "#b36a42", roofDark: "#844a2d", door: "#4f3d2b", window: "#f4efda", accent: "#6b8e23" },
  apartment: { body: "#a6afba", roof: "#6a7380", roofDark: "#48505c", door: "#2b2f37", window: "#d9ecff", accent: "#9ad0e6" },
  farm: { body: "#a8733c", field: "#6eab39", fieldLight: "#84c44a" },
  lumber: { body: "#8b5b3a", roof: "#4d3b2a", panel: "#a36f48", pipe: "#6b5b4a", glow: "#d7b46a" },
  quarry: { body: "#8d8d95", roof: "#6a6a72", panel: "#787881", pipe: "#4c4c53", glow: "#d2c7b1" },
  workshop: { body: "#bca77c", roof: "#7b4f2a", panel: "#8f7a5d", pipe: "#4e4a44", glow: "#d9d9d9" },
  foundry: { body: "#67676d", roof: "#3f3f44", panel: "#55555c", pipe: "#2b2b30", glow: "#f0b25b" },
  market: { body: "#d97b4a", roof: "#f4efda", detail: "#ffe399", badge: "#ffd65c" },
  bank: { body: "#aab3bd", roof: "#5d6b78", detail: "#d8dee4", badge: "#ffd65c" },
  park: { ground: "#4f8f3a", tree: "#2f6f2a", path: "#d9d9d9" },
  library: { body: "#c9b28f", roof: "#7f5532", detail: "#ece2d1", badge: "#8b9fab" },
  theater: { body: "#b47a8f", roof: "#6f3e55", detail: "#d9bfd0", badge: "#f29f05" },
  power: { body: "#7b6f65", roof: "#524941", panel: "#64574d", pipe: "#2f2f2f", glow: "#f0c65f" },
  water_tower: { body: "#7aafcc", roof: "#5a8faa", tank: "#a8d8ea", pipe: "#4a7a8a" },
  road: { shades: ["#6d655c", "#5d5d5d", "#4c5359", "#41484e", "#333a40"] },
  warehouse: { body: "#7b6b5a", roof: "#bca77c", panel: "#94816e", pipe: "#4f5b66" },
  research: { body: "#8ca2a8", roof: "#4f6470", panel: "#6f8a91", glow: "#7cc3ff" },
  wonder: { body: "#d8cfb0", roof: "#8b7a4a", detail: "#e6dfc6", badge: "#ffd65c", spire: "#9c5bd9" },
};

function drawBuildingIso(ctx, cell, sx, sy, gx, gy) {
  const pal = BUILDING_PALETTES[cell.type];
  if (!pal) {
    drawIsoBlock(ctx, sx, sy, "#999", "#777", "#666", 8);
    return;
  }

  const lvl = cell.level;
  const h = getBuildingHeight(cell);
  const night = isNight();

  switch (cell.type) {
    case "road":
      drawRoadIso(ctx, sx, sy, cell, gx, gy);
      return;
    case "farm":
      drawFarmIso(ctx, sx, sy, lvl, pal);
      return;
    case "park":
      drawParkIso(ctx, sx, sy, lvl, pal);
      return;
    case "water_tower":
      drawWaterTowerIso(ctx, sx, sy, lvl, pal);
      return;
    case "hut":
    case "apartment":
      drawResidentialIso(ctx, sx, sy, lvl, pal, h, night);
      return;
    case "market":
    case "bank":
    case "library":
    case "theater":
      drawServiceIso(ctx, sx, sy, lvl, pal, h, night);
      return;
    case "wonder":
      drawWonderIso(ctx, sx, sy, lvl, pal, h);
      return;
    default:
      drawIndustrialIso(ctx, sx, sy, lvl, pal, h, night);
      return;
  }
}

function getBuildingHeight(cell) {
  const base = 8;
  switch (cell.type) {
    case "road": return 1;
    case "farm": return 3;
    case "park": return 2;
    case "hut": return base + cell.level * 3;
    case "apartment": return base + cell.level * 6;
    case "wonder": return 16 + cell.level * 8;
    case "water_tower": return 10 + cell.level * 3;
    default: return base + cell.level * 2;
  }
}

function drawRoadIso(ctx, sx, sy, cell, gx, gy) {
  const mask = getRoadMask(gx, gy);
  const shade = BUILDING_PALETTES.road.shades[Math.min(cell.level - 1, 4)];

  // Base road diamond (slightly darker)
  drawIsoDiamond(ctx, sx, sy, "#2f353a");
  // Road surface
  ctx.fillStyle = shade;

  // Center
  ctx.beginPath();
  ctx.moveTo(sx, sy - 3);
  ctx.lineTo(sx + 6, sy);
  ctx.lineTo(sx, sy + 3);
  ctx.lineTo(sx - 6, sy);
  ctx.closePath();
  ctx.fill();

  // Extensions
  if (mask & 1) { // up-left
    ctx.beginPath();
    ctx.moveTo(sx - HALF_W, sy - HALF_H);
    ctx.lineTo(sx - 3, sy - 6);
    ctx.lineTo(sx + 3, sy - 2);
    ctx.lineTo(sx - HALF_W + 6, sy - HALF_H + 3);
    ctx.closePath();
    ctx.fill();
  }
  if (mask & 2) { // up-right
    ctx.beginPath();
    ctx.moveTo(sx + HALF_W, sy - HALF_H);
    ctx.lineTo(sx + 3, sy - 6);
    ctx.lineTo(sx - 3, sy - 2);
    ctx.lineTo(sx + HALF_W - 6, sy - HALF_H + 3);
    ctx.closePath();
    ctx.fill();
  }
  if (mask & 4) { // down-right
    ctx.beginPath();
    ctx.moveTo(sx + HALF_W, sy + HALF_H);
    ctx.lineTo(sx + 3, sy + 6);
    ctx.lineTo(sx - 3, sy + 2);
    ctx.lineTo(sx + HALF_W - 6, sy + HALF_H - 3);
    ctx.closePath();
    ctx.fill();
  }
  if (mask & 8) { // down-left
    ctx.beginPath();
    ctx.moveTo(sx - HALF_W, sy + HALF_H);
    ctx.lineTo(sx - 3, sy + 6);
    ctx.lineTo(sx + 3, sy + 2);
    ctx.lineTo(sx - HALF_W + 6, sy + HALF_H - 3);
    ctx.closePath();
    ctx.fill();
  }

  // Lane markings
  if (cell.level >= 3) {
    ctx.fillStyle = "#d9d9d9";
    ctx.fillRect(sx - 1, sy - 1, 2, 2);
  }
}

function drawFarmIso(ctx, sx, sy, lvl, pal) {
  // Field base
  drawIsoBlock(ctx, sx, sy, pal.field, "#5a9430", "#4a8428", 2);
  // Crop rows
  ctx.fillStyle = pal.fieldLight;
  for (let i = -2; i <= 2; i++) {
    ctx.fillRect(sx + i * 4 - 1, sy - 4 + i * 2, 3, 1);
  }
  // Barn at higher levels
  if (lvl >= 2) {
    ctx.fillStyle = "#8b5b3a";
    ctx.fillRect(sx - 4, sy - 12, 8, 8);
    ctx.fillStyle = "#b36a42";
    ctx.beginPath();
    ctx.moveTo(sx - 5, sy - 12);
    ctx.lineTo(sx, sy - 17);
    ctx.lineTo(sx + 5, sy - 12);
    ctx.closePath();
    ctx.fill();
  }
  if (lvl >= 4) {
    ctx.fillStyle = "#69b9b1";
    ctx.fillRect(sx + 4, sy - 10, 6, 6);
    ctx.fillStyle = "#c6e8e5";
    ctx.fillRect(sx + 5, sy - 9, 4, 4);
  }
}

function drawParkIso(ctx, sx, sy, lvl, pal) {
  drawIsoDiamond(ctx, sx, sy, pal.ground);
  drawTree(ctx, sx - 5, sy - 2);
  drawTree(ctx, sx + 5, sy - 2);
  if (lvl >= 2) {
    ctx.fillStyle = pal.path;
    ctx.fillRect(sx - 1, sy - 1, 3, 3);
  }
  if (lvl >= 3) {
    ctx.fillStyle = "#d9d9d9";
    ctx.fillRect(sx - 6, sy + 1, 4, 2);
  }
  if (lvl >= 4) {
    ctx.fillStyle = "#75d0ff";
    ctx.beginPath();
    ctx.arc(sx + 2, sy + 3, 3, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawWaterTowerIso(ctx, sx, sy, lvl, pal) {
  const h = 10 + lvl * 3;
  // Legs
  ctx.fillStyle = pal.pipe;
  ctx.fillRect(sx - 4, sy - h + 4, 2, h - 4);
  ctx.fillRect(sx + 2, sy - h + 4, 2, h - 4);
  // Tank
  ctx.fillStyle = pal.tank;
  ctx.fillRect(sx - 6, sy - h, 12, 8);
  ctx.fillStyle = pal.roof;
  ctx.fillRect(sx - 7, sy - h - 2, 14, 3);
  // Water indicator
  ctx.fillStyle = "#4a9bd9";
  ctx.fillRect(sx - 4, sy - h + 2, 8, 4);
}

function drawResidentialIso(ctx, sx, sy, lvl, pal, h, night) {
  drawIsoBlock(ctx, sx, sy, pal.roof, pal.body, pal.roofDark, h);
  // Door
  ctx.fillStyle = pal.door;
  ctx.fillRect(sx - 1, sy - 2, 3, 4);
  // Windows — more rows per level
  ctx.fillStyle = night ? "#ffe066" : pal.window;
  const floors = Math.min(lvl, 5);
  for (let f = 0; f < floors; f++) {
    const wy = sy - 6 - f * (h / floors);
    ctx.fillRect(sx - 6, wy, 3, 3);
    ctx.fillRect(sx + 3, wy, 3, 3);
    if (lvl >= 3) ctx.fillRect(sx - 1, wy, 2, 3);
  }
  // Trim at level 2+
  if (lvl >= 2) {
    ctx.fillStyle = pal.accent || pal.roofDark;
    ctx.fillRect(sx - 8, sy - h + 2, 16, 1);
  }
  // Balconies at level 4+
  if (lvl >= 4) {
    ctx.fillStyle = pal.accent || "#6b8e23";
    ctx.fillRect(sx - 9, sy - h / 2, 2, 4);
    ctx.fillRect(sx + 7, sy - h / 2, 2, 4);
  }
  // Antenna/flag at level 5
  if (lvl >= 5) {
    ctx.fillStyle = pal.roofDark;
    ctx.fillRect(sx, sy - h - 6, 1, 6);
    ctx.fillStyle = "#ffd65c";
    ctx.fillRect(sx + 1, sy - h - 6, 4, 3);
  }
}

function drawServiceIso(ctx, sx, sy, lvl, pal, h, night) {
  drawIsoBlock(ctx, sx, sy, pal.roof, pal.body, pal.detail || pal.body, h);
  // Signage — grows with level
  ctx.fillStyle = pal.badge || "#ffd65c";
  const signW = 4 + lvl * 2;
  ctx.fillRect(sx - signW / 2, sy - h + 4, signW, 3);
  // Windows — more rows per level
  ctx.fillStyle = night ? "#ffe066" : (pal.detail || "#eee");
  const wRows = Math.min(lvl, 4);
  for (let r = 0; r < wRows; r++) {
    const wy = sy - 6 - r * (h / (wRows + 1));
    ctx.fillRect(sx - 6, wy, 3, 2);
    ctx.fillRect(sx + 3, wy, 3, 2);
  }
  // Awning at level 3+
  if (lvl >= 3) {
    ctx.fillStyle = pal.roof;
    ctx.fillRect(sx - 8, sy - 3, 16, 2);
  }
  // Flag at level 5
  if (lvl >= 5) {
    ctx.fillStyle = "#444";
    ctx.fillRect(sx - 1, sy - h - 8, 1, 8);
    ctx.fillStyle = pal.badge || "#ffd65c";
    ctx.fillRect(sx, sy - h - 8, 5, 3);
  }
}

function drawIndustrialIso(ctx, sx, sy, lvl, pal, h, night) {
  drawIsoBlock(ctx, sx, sy, pal.roof, pal.body, pal.panel || pal.body, h);
  // Chimneys — more at higher levels
  if (pal.pipe) {
    const chimneys = Math.min(lvl, 3);
    for (let c = 0; c < chimneys; c++) {
      const cx = sx + 4 + c * 5 - (chimneys - 1) * 2;
      ctx.fillStyle = pal.pipe;
      ctx.fillRect(cx, sy - h - 4 - c * 3, 2, 6 + c * 3);
      // Smoke at level 2+
      if (lvl >= 2) {
        ctx.fillStyle = `rgba(180,180,180,${0.2 + c * 0.1})`;
        ctx.beginPath();
        ctx.arc(cx + 1, sy - h - 8 - c * 3, 2 + c, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
  // Windows/panels
  if (pal.glow) {
    ctx.fillStyle = night ? pal.glow : pal.glow + "88";
    const panels = Math.min(lvl, 4);
    for (let p = 0; p < panels; p++) {
      ctx.fillRect(sx - 5 + p * 4, sy - h / 2, 2, 2);
    }
  }
  // Pipes at level 4+
  if (lvl >= 4) {
    ctx.fillStyle = pal.pipe || "#444";
    ctx.fillRect(sx - 8, sy - 4, 2, 6);
    ctx.fillRect(sx - 8, sy - 4, 6, 2);
  }
}

function drawWonderIso(ctx, sx, sy, lvl, pal, h) {
  drawIsoBlock(ctx, sx, sy, pal.roof, pal.body, pal.detail, h);
  // Spire
  ctx.fillStyle = pal.spire;
  ctx.beginPath();
  ctx.moveTo(sx, sy - h - 12);
  ctx.lineTo(sx + 4, sy - h);
  ctx.lineTo(sx - 4, sy - h);
  ctx.closePath();
  ctx.fill();
  // Badge
  ctx.fillStyle = pal.badge;
  ctx.fillRect(sx - 4, sy - h + 3, 8, 3);
  // Glow at top
  ctx.fillStyle = "rgba(255,215,90,0.5)";
  ctx.beginPath();
  ctx.arc(sx, sy - h - 12, 3 + lvl, 0, Math.PI * 2);
  ctx.fill();
}

// ── Issue indicator ──
function drawIssueIndicator(ctx, sx, sy, h, issueType) {
  // Red circle with !
  ctx.fillStyle = "#b5332a";
  ctx.beginPath();
  ctx.arc(sx + 8, sy - h - 6, 5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.font = "bold 7px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("!", sx + 8, sy - h - 6);
  // Issue type label
  if (issueType) {
    ctx.fillStyle = "rgba(0,0,0,0.7)";
    const tw = ctx.measureText(issueType).width + 6;
    ctx.fillRect(sx + 12, sy - h - 12, tw, 10);
    ctx.fillStyle = "#ff8866";
    ctx.font = "6px sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(issueType, sx + 15, sy - h - 7);
  }
}

// ── No-road indicator ──
function drawNoRoadIndicator(ctx, sx, sy) {
  ctx.strokeStyle = "#ff6644";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(sx - 8, sy - 4, 3, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(sx - 10, sy - 6);
  ctx.lineTo(sx - 6, sy - 2);
  ctx.stroke();
}

// ── Selection & Hover ──
function drawSelectionHighlight(ctx, sx, sy) {
  ctx.strokeStyle = "#3f7fd9";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(sx, sy - HALF_H - 1);
  ctx.lineTo(sx + HALF_W + 1, sy);
  ctx.lineTo(sx, sy + HALF_H + 1);
  ctx.lineTo(sx - HALF_W - 1, sy);
  ctx.closePath();
  ctx.stroke();
}

function drawHoverHighlight(ctx, sx, sy, occupied) {
  ctx.strokeStyle = occupied ? "#b5332a" : "#fff2b3";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(sx, sy - HALF_H);
  ctx.lineTo(sx + HALF_W, sy);
  ctx.lineTo(sx, sy + HALF_H);
  ctx.lineTo(sx - HALF_W, sy);
  ctx.closePath();
  ctx.stroke();

  // Ghost preview
  if (!occupied && STATE.selectedTool !== "bulldoze") {
    ctx.globalAlpha = 0.5;
    drawBuildingIso(ctx, { type: STATE.selectedTool, level: 1 }, sx, sy, 0, 0);
    ctx.globalAlpha = 1;
  }
}

// ── Minimap ──
export function drawMinimap(ctx, x, y, w, h) {
  ctx.fillStyle = "rgba(0,0,0,0.7)";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "#555";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);

  const scale = Math.min(w / GRID_SIZE, h / GRID_SIZE);

  for (let gy = 0; gy < GRID_SIZE; gy++) {
    for (let gx = 0; gx < GRID_SIZE; gx++) {
      const t = STATE.terrain[gy][gx];
      const cell = STATE.grid[gy][gx];
      let color;

      if (cell) {
        if (cell.type === "road") color = "#555";
        else if (cell.type === "hut" || cell.type === "apartment") color = "#4a4";
        else if (cell.type === "farm") color = "#8b4";
        else if (cell.type === "water_tower") color = "#5af";
        else if (cell.type === "power") color = "#fa5";
        else color = "#aa8";
      } else {
        const colors = { [TERRAIN.GRASS]: "#5a5", [TERRAIN.WATER]: "#38a", [TERRAIN.SAND]: "#ba8",
          [TERRAIN.HILL]: "#686", [TERRAIN.FOREST]: "#375", [TERRAIN.ROCK]: "#777" };
        color = colors[t] || "#5a5";
      }

      ctx.fillStyle = color;
      ctx.fillRect(x + gx * scale, y + gy * scale, Math.max(1, scale), Math.max(1, scale));
    }
  }

  // Camera viewport indicator
  const vpLeft = STATE.camera.x - (w / 2) / STATE.camera.zoom;
  const vpTop = STATE.camera.y;
  // Rough approximation
  ctx.strokeStyle = "#fff";
  ctx.lineWidth = 1;
  const msx = x + (GRID_SIZE / 2 + vpLeft / (TILE_W)) * scale;
  const msy = y + (GRID_SIZE / 2 + vpTop / (TILE_H)) * scale;
  ctx.strokeRect(msx - 8, msy - 4, 16, 8);
}

// ── Main render function ──
export function renderWorld(ctx, canvasW, canvasH) {
  ctx.clearRect(0, 0, canvasW, canvasH);

  // Sky gradient based on time of day
  const tint = getDayNightTint();
  const skyGrad = ctx.createLinearGradient(0, 0, 0, canvasH);
  if (STATE.dayTime > 0.25 && STATE.dayTime < 0.75) {
    skyGrad.addColorStop(0, "#87ceeb");
    skyGrad.addColorStop(1, "#e0f0e8");
  } else if (STATE.dayTime < 0.2 || STATE.dayTime > 0.8) {
    skyGrad.addColorStop(0, "#1a1a3a");
    skyGrad.addColorStop(1, "#2a2a4a");
  } else {
    skyGrad.addColorStop(0, "#dd7744");
    skyGrad.addColorStop(1, "#445566");
  }
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, canvasW, canvasH);

  ctx.save();

  // Apply camera transform
  const zoom = STATE.camera.zoom;
  ctx.translate(canvasW / 2, canvasH / 2);
  ctx.scale(zoom, zoom);
  ctx.translate(-STATE.camera.x, -STATE.camera.y);

  // Draw terrain
  drawTerrain(ctx, canvasW, canvasH);

  // Draw buildings (sorted by depth for correct overlap)
  for (let gy = 0; gy < GRID_SIZE; gy++) {
    for (let gx = 0; gx < GRID_SIZE; gx++) {
      const cell = STATE.grid[gy][gx];
      if (!cell) continue;

      const { sx, sy } = gridToIso(gx, gy);
      drawBuildingIso(ctx, cell, sx, sy, gx, gy);

      if (cell.issue) {
        drawIssueIndicator(ctx, sx, sy, getBuildingHeight(cell), cell.issue);
      }

      const bld = BUILDINGS[cell.type];
      if (bld?.requiresRoad && !isConnectedToRoad(gx, gy)) {
        drawNoRoadIndicator(ctx, sx, sy);
      }
    }
  }

  // Selection highlight
  if (STATE.selectedBuilding) {
    const { x, y } = STATE.selectedBuilding;
    const { sx, sy } = gridToIso(x, y);
    drawSelectionHighlight(ctx, sx, sy);
  }

  // Hover highlight
  if (STATE.hover.inGrid && STATE.mode === "play") {
    const { x, y } = STATE.hover;
    const { sx, sy } = gridToIso(x, y);
    const occupied = !!STATE.grid[y][x];
    drawHoverHighlight(ctx, sx, sy, occupied);
  }

  ctx.restore();

  // Day/night overlay
  if (tint.a > 0) {
    ctx.fillStyle = `rgba(${Math.floor(tint.r * 80)},${Math.floor(tint.g * 80)},${Math.floor(tint.b * 150)},${tint.a})`;
    ctx.fillRect(0, 0, canvasW, canvasH);
  }
}

export function renderMenu(ctx, canvasW, canvasH) {
  ctx.fillStyle = "#1a1a2e";
  ctx.fillRect(0, 0, canvasW, canvasH);

  // Stars
  for (let i = 0; i < 60; i++) {
    const hash = (i * 7919 + 1013) % 9973;
    const sx = (hash % canvasW);
    const sy = (hash * 37) % canvasH;
    const brightness = 0.4 + (hash % 100) / 160;
    ctx.fillStyle = `rgba(255,255,255,${brightness})`;
    ctx.fillRect(sx, sy, 1, 1);
  }

  ctx.fillStyle = "#f4efda";
  ctx.font = "bold 28px 'Courier New', monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText("PIXEL CITY BUILDER", canvasW / 2, canvasH * 0.15);

  ctx.font = "14px 'Courier New', monospace";
  ctx.fillStyle = "#aaa";
  ctx.fillText("Build your dream city from scratch", canvasW / 2, canvasH * 0.25);
  ctx.fillText("Roads connect buildings. Water and power keep them running.", canvasW / 2, canvasH * 0.30);
  ctx.fillText("Terrain affects production. Plan wisely!", canvasW / 2, canvasH * 0.35);

  ctx.font = "16px 'Courier New', monospace";
  ctx.fillStyle = "#ffd65c";
  const pulse = 0.7 + 0.3 * Math.sin(Date.now() / 400);
  ctx.globalAlpha = pulse;
  ctx.fillText("Press ENTER or click START CITY", canvasW / 2, canvasH * 0.5);
  ctx.globalAlpha = 1;
  ctx.textAlign = "left";
}
