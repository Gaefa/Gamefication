// ── Economy & Resource Management ──────────────────────────────────
import { BUILDINGS, GRID_SIZE, TERRAIN } from "./config.js";
import { STATE, createBaseCaps, createStartingResources } from "./state.js";

// ── Helpers ──
export function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }
export function round1(v) { return Math.round(v * 10) / 10; }
export function formatRes(v) { return round1(v).toString(); }

export function setMessage(text) {
  STATE.message = text;
  STATE.messageTimer = 2.6;
}

// ── Resources ──
export function hasResources(cost) {
  if (!cost) return true;
  return Object.entries(cost).every(([k, v]) => (STATE.resources[k] || 0) >= v);
}

export function spendResources(cost) {
  if (!cost) return;
  for (const [k, v] of Object.entries(cost)) {
    STATE.resources[k] = Math.max(0, (STATE.resources[k] || 0) - v);
  }
}

export function addResources(bundle) {
  if (!bundle) return;
  for (const [k, v] of Object.entries(bundle)) {
    const cap = STATE.caps[k] ?? 999999;
    STATE.resources[k] = clamp((STATE.resources[k] || 0) + v, 0, cap);
  }
}

export function resourceToString(cost) {
  if (!cost) return "None";
  return Object.entries(cost)
    .filter(([, v]) => v !== 0)
    .map(([k, v]) => `${formatRes(v)} ${k}`)
    .join(", ");
}

// ── Building data helpers ──
export function getBuildingLevelData(cell) {
  return BUILDINGS[cell.type].levels[cell.level - 1];
}

export function getNextLevelData(cell) {
  return BUILDINGS[cell.type].levels[cell.level];
}

// ── Grid helpers ──
export function getAdjacency(x, y) {
  const dirs = [
    { x, y: y - 1 }, { x: x + 1, y },
    { x, y: y + 1 }, { x: x - 1, y },
  ];
  return dirs.filter(n => n.x >= 0 && n.x < GRID_SIZE && n.y >= 0 && n.y < GRID_SIZE);
}

export function forEachBuilding(cb) {
  for (let y = 0; y < GRID_SIZE; y++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      const cell = STATE.grid[y][x];
      if (cell) cb(cell, x, y);
    }
  }
}

export function getBuildingsInRadius(cx, cy, radius, filterFn) {
  const out = [];
  forEachBuilding((cell, x, y) => {
    const dx = x - cx, dy = y - cy;
    if (dx * dx + dy * dy <= radius * radius && filterFn(cell, x, y)) {
      out.push({ cell, x, y });
    }
  });
  return out;
}

export function countAdjacent(type, x, y) {
  return getAdjacency(x, y).filter(p => {
    const c = STATE.grid[p.y][p.x];
    return c && c.type === type;
  }).length;
}

// ── Road connection check (BFS) ──
export function isConnectedToRoad(x, y) {
  const cell = STATE.grid[y]?.[x];
  if (!cell) return false;
  if (cell.type === "road") return true;
  return getAdjacency(x, y).some(p => {
    const c = STATE.grid[p.y][p.x];
    return c && c.type === "road";
  });
}

// ── Road mask for rendering ──
export function getRoadMask(x, y) {
  let mask = 0;
  if (y > 0 && STATE.grid[y - 1][x]?.type === "road") mask |= 1;
  if (x < GRID_SIZE - 1 && STATE.grid[y][x + 1]?.type === "road") mask |= 2;
  if (y < GRID_SIZE - 1 && STATE.grid[y + 1][x]?.type === "road") mask |= 4;
  if (x > 0 && STATE.grid[y][x - 1]?.type === "road") mask |= 8;
  return mask;
}

// ── Synergy calculations ──
export function getPrestigeProductionBonus() { return STATE.prestigeStars * 0.05; }
export function getPrestigeHappinessBonus() { return STATE.prestigeStars * 0.02; }

export function getCityLevelProductionBonus() {
  if (STATE.cityLevel >= 7) return 1;
  if (STATE.cityLevel === 6) return 0.5;
  if (STATE.cityLevel === 5) return 0.35;
  if (STATE.cityLevel === 4) return 0.2;
  if (STATE.cityLevel === 3) return 0.1;
  return 0;
}

export function getRoadBoost(x, y) {
  let roadCount = 0, bestLevel = 1;
  for (const p of getAdjacency(x, y)) {
    const c = STATE.grid[p.y][p.x];
    if (c?.type === "road") {
      roadCount++;
      bestLevel = Math.max(bestLevel, c.level);
    }
  }
  if (!roadCount) return 0;
  return BUILDINGS.road.levels[bestLevel - 1].bonus.roadBoost * roadCount;
}

export function getMarketResidentialBoost(x, y) {
  let boost = 0;
  for (const p of getAdjacency(x, y)) {
    const c = STATE.grid[p.y][p.x];
    if (c?.type === "market") {
      boost += getBuildingLevelData(c).synergy?.residentialCoins || 0;
    }
  }
  return boost;
}

export function getFarmAuraBoost(x, y) {
  let boost = 0;
  const farms = getBuildingsInRadius(x, y, 4, c => c.type === "farm" && c.level >= 3);
  for (const { cell, x: fx, y: fy } of farms) {
    const ld = getBuildingLevelData(cell);
    const r = ld.synergy?.radius || 3;
    const dx = x - fx, dy = y - fy;
    if (dx * dx + dy * dy <= r * r) boost += ld.synergy?.auraFoodBoost || 0;
  }
  return clamp(boost, 0, 0.5);
}

export function getPowerAuraBoost(x, y) {
  let boost = 0;
  const plants = getBuildingsInRadius(x, y, 10, c => c.type === "power" && c.level >= 2);
  for (const { cell, x: px, y: py } of plants) {
    const ld = getBuildingLevelData(cell);
    const r = ld.synergy?.radius || 6;
    const dx = x - px, dy = y - py;
    if (dx * dx + dy * dy <= r * r) boost += ld.synergy?.poweredBoost || 0;
  }
  return clamp(boost, 0, 0.6);
}

export function getWaterCoverage(x, y) {
  let covered = false;
  const towers = getBuildingsInRadius(x, y, 14, c => c.type === "water_tower");
  for (const { cell, x: wx, y: wy } of towers) {
    const ld = getBuildingLevelData(cell);
    const r = ld.synergy?.waterRadius || 4;
    const dx = x - wx, dy = y - wy;
    if (dx * dx + dy * dy <= r * r) { covered = true; break; }
  }
  return covered;
}

export function getUpgradeDiscount(x, y) {
  let discount = 0;
  const workshops = getBuildingsInRadius(x, y, 4, c => c.type === "workshop" && c.level >= 2);
  for (const { cell, x: sx, y: sy } of workshops) {
    const ld = getBuildingLevelData(cell);
    const r = ld.synergy?.radius || 3;
    const dx = x - sx, dy = y - sy;
    if (dx * dx + dy * dy <= r * r) discount += ld.synergy?.upgradeDiscount || 0;
  }
  return clamp(discount, 0, 0.45);
}

export function getTerrainBonus(buildingType, x, y) {
  const bld = BUILDINGS[buildingType];
  if (!bld?.terrainBonus) return 0;
  const t = STATE.terrain[y]?.[x];
  return bld.terrainBonus[t] || 0;
}

export function getActiveBuffProductionBonus() {
  return STATE.buffs.reduce((s, b) => s + (b.productionMult || 0), 0);
}

export function getActiveBuffHappinessBonus() {
  return STATE.buffs.reduce((s, b) => s + (b.happinessAdd || 0), 0);
}

// ── Production multiplier ──
export function getProductionMultiplier(cell, x, y, resourceKey) {
  let mult = 1;
  mult += getCityLevelProductionBonus();
  mult += getPrestigeProductionBonus();
  mult += getActiveBuffProductionBonus();
  mult += getTerrainBonus(cell.type, x, y);

  if (cell.type !== "road") mult += getRoadBoost(x, y);
  if (resourceKey === "food") mult += getFarmAuraBoost(x, y);
  if (resourceKey === "coins" && (cell.type === "hut" || cell.type === "apartment")) {
    mult += getMarketResidentialBoost(x, y);
  }
  if (cell.type !== "power" && cell.type !== "road") mult += getPowerAuraBoost(x, y);

  // Lumber adjacent boost to farms
  if (cell.type === "farm" && cell.level >= 1) {
    for (const p of getAdjacency(x, y)) {
      const n = STATE.grid[p.y][p.x];
      if (n?.type === "lumber" && n.level >= 2) {
        mult += getBuildingLevelData(n).synergy?.farmAdjBoost || 0;
      }
    }
  }

  // Road-connected bonus (non-road buildings without road get penalty)
  const bld = BUILDINGS[cell.type];
  if (bld?.requiresRoad && !isConnectedToRoad(x, y)) {
    mult *= 0.3;
  }

  // Water coverage bonus for residential
  if ((cell.type === "hut" || cell.type === "apartment") && !getWaterCoverage(x, y)) {
    mult *= 0.6;
  }

  if (cell.issue) mult *= 0.5;
  return Math.max(0, mult);
}

export function canBuildingOperate(cell) {
  const ld = getBuildingLevelData(cell);
  return !ld.consumes || hasResources(ld.consumes);
}

export function applyProduction(cell, x, y) {
  const ld = getBuildingLevelData(cell);
  if (!canBuildingOperate(cell)) return;
  if (ld.consumes) spendResources(ld.consumes);

  const produced = {};
  for (const [k, v] of Object.entries(ld.produces || {})) {
    const m = getProductionMultiplier(cell, x, y, k);
    produced[k] = (produced[k] || 0) + v * m;
  }

  if (ld.interestPerMin && STATE.resources.coins > 0) {
    produced.coins = (produced.coins || 0) + (STATE.resources.coins * ld.interestPerMin) / 60;
  }

  addResources(produced);

  // Track stats
  if (produced.coins) STATE.stats.totalCoinsEarned += produced.coins;
  if (produced.food) STATE.stats.totalFoodProduced += produced.food;
}

export function computePassiveStats() {
  let popCap = 0, happiness = 50, issues = 0;

  forEachBuilding((cell, x, y) => {
    const ld = getBuildingLevelData(cell);
    if (ld.population) popCap += ld.population;
    if (ld.happiness) happiness += ld.happiness;
    if (cell.issue) { issues++; happiness -= 2; }

    if (cell.type !== "park") {
      for (const { cell: park, x: px, y: py } of getBuildingsInRadius(x, y, 6, c => c.type === "park")) {
        const pl = getBuildingLevelData(park);
        const r = pl.synergy?.radius || 4;
        const dx = x - px, dy = y - py;
        if (dx * dx + dy * dy <= r * r) happiness += (pl.synergy?.happinessAura || 0) * 10;
      }
    }
  });

  happiness += getActiveBuffHappinessBonus();
  happiness += getPrestigeHappinessBonus() * 100;
  if (STATE.happinessPenaltyTicks > 0) happiness -= 8;

  return {
    popCap: Math.max(0, Math.round(popCap)),
    happiness: clamp(Math.round(happiness), 0, 250),
    issues,
  };
}

export function updateCaps() {
  const base = createBaseCaps();
  let storageBonus = 0;
  forEachBuilding(cell => {
    if (cell.type === "warehouse") storageBonus += getBuildingLevelData(cell).storage || 0;
  });
  const caps = { ...base };
  for (const k of Object.keys(caps)) {
    if (k !== "coins" && k !== "fame" && k !== "water_res") caps[k] += storageBonus;
  }
  STATE.caps = caps;
  for (const k of Object.keys(STATE.resources)) {
    STATE.resources[k] = Math.min(STATE.resources[k], STATE.caps[k] ?? 999999);
  }
}

export function maybeCreateIssue() {
  forEachBuilding((cell, x, y) => {
    if (cell.type === "road" || cell.issue) return;
    const chance = 0.001 + cell.level * 0.00035;
    if (Math.random() >= chance) return;

    // Context-aware: only assign issues that actually apply
    const possibleIssues = [];

    // Traffic — only if NOT connected to a road
    const bld = BUILDINGS[cell.type];
    if (bld?.requiresRoad && !isConnectedToRoad(x, y)) {
      possibleIssues.push("Traffic");
    }

    // Power — only if no power plant in range
    if (cell.type !== "power" && cell.type !== "road" && getPowerAuraBoost(x, y) === 0) {
      possibleIssues.push("Power");
    }

    // Water — only if residential and no water coverage
    if ((cell.type === "hut" || cell.type === "apartment") && !getWaterCoverage(x, y)) {
      possibleIssues.push("Water");
    }

    // Generic issues that can happen randomly regardless of infrastructure
    possibleIssues.push("Maintenance");
    if (cell.level >= 2) possibleIssues.push("Supply");

    cell.issue = possibleIssues[Math.floor(Math.random() * possibleIssues.length)];
  });
}

export function forceIssues(count) {
  const candidates = [];
  forEachBuilding((cell, x, y) => { if (cell.type !== "road") candidates.push({ cell, x, y }); });
  for (let i = candidates.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [candidates[i], candidates[j]] = [candidates[j], candidates[i]];
  }
  for (let i = 0; i < Math.min(count, candidates.length); i++) {
    candidates[i].cell.issue = candidates[i].cell.issue || "Emergency";
  }
}

export function resolveAutoSellFood() {
  let hasAutoSell = false;
  forEachBuilding(cell => {
    if (cell.type === "farm" && getBuildingLevelData(cell).synergy?.autoSellFood) hasAutoSell = true;
  });
  if (!hasAutoSell) return;
  const cap = STATE.caps.food;
  if (STATE.resources.food > cap * 0.95) {
    const excess = STATE.resources.food - cap * 0.95;
    if (excess > 0) {
      STATE.resources.food -= excess;
      STATE.resources.coins += excess * 1.2;
    }
  }
}
