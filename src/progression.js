// ── Progression: Levels, Prestige, Win Conditions ──────────────────
import { CITY_LEVELS, BUILDINGS, GRID_SIZE } from "./config.js";
import { STATE, createEmptyGrid, createStartingResources } from "./state.js";
import { hasResources, spendResources, addResources, setMessage, canBuildingOperate,
         applyProduction, computePassiveStats, updateCaps, maybeCreateIssue,
         resolveAutoSellFood, forEachBuilding, clamp, getPrestigeProductionBonus,
         getCityLevelProductionBonus, getUpgradeDiscount, getBuildingLevelData,
         getNextLevelData, round1 } from "./economy.js";
import { processEventsTick, resolveEvent as resolveEvt } from "./events.js";
import { generateTerrain } from "./mapgen.js";

export function getCurrentLevelEntry() {
  return CITY_LEVELS.find(e => e.level === STATE.cityLevel);
}

export function getNextLevelEntry() {
  return CITY_LEVELS.find(e => e.level === STATE.cityLevel + 1) || null;
}

export function canLevelUp() {
  const next = getNextLevelEntry();
  return next && hasResources(next.requirements);
}

export function levelUp() {
  const next = getNextLevelEntry();
  if (!next) { setMessage("City is at max level."); return; }
  if (!hasResources(next.requirements)) { setMessage("Requirements are not met."); return; }
  spendResources(next.requirements);
  addResources(next.reward);
  STATE.cityLevel = next.level;
  setMessage(`City advanced: ${next.name}.`);
}

export function calculatePrestigeGain() {
  if (STATE.cityLevel < 7) return 0;
  return 1 + Math.floor((STATE.resources.fame || 0) / 2000) + Math.floor((STATE.resources.science || 0) / 5000);
}

export function prestige() {
  if (STATE.cityLevel < 7) { setMessage("Reach level 7 to prestige."); return; }
  const gain = calculatePrestigeGain();
  if (gain <= 0) { setMessage("No prestige gain available."); return; }

  STATE.prestigeStars += gain;
  STATE.prestigeCount += 1;
  STATE.grid = createEmptyGrid();
  STATE.terrain = generateTerrain(Date.now());
  STATE.cityLevel = 1;
  STATE.resources = createStartingResources();
  addResources({
    wood: STATE.prestigeStars * 10,
    stone: STATE.prestigeStars * 8,
    food: STATE.prestigeStars * 8,
    coins: STATE.prestigeStars * 60,
  });
  STATE.population = 0;
  STATE.happiness = 60;
  STATE.selectedBuilding = null;
  STATE.selectedTool = "road";
  STATE.eventTimer = 60;
  STATE.activeEvent = null;
  STATE.buffs = [];
  STATE.happinessPenaltyTicks = 0;
  setMessage(`Prestige complete. +${gain} stars.`);
}

export function evaluateWinConditions() {
  const c1 = STATE.cityLevel >= 7;
  const c2 = STATE.prestigeCount >= 1;
  const c3 = STATE.prestigeStars >= 3 && (STATE.resources.fame || 0) >= 1000;
  if (c1 && !STATE.winUnlockedAt) STATE.winUnlockedAt = Date.now();
  if (c1 && c2 && c3 && !STATE.hasUltimateWin) {
    STATE.hasUltimateWin = true;
    setMessage("Ultimate win condition completed!");
  }
}

export function getWinConditionRows() {
  return [
    { done: STATE.cityLevel >= 7, text: "Reach City Level 7" },
    { done: STATE.prestigeCount >= 1, text: "Use Prestige at least once" },
    { done: STATE.prestigeStars >= 3 && (STATE.resources.fame || 0) >= 1000, text: "3 Prestige Stars and 1000 Fame" },
  ];
}

// ── Building actions ──
export function getUpgradeCost(cell, x, y) {
  const next = getNextLevelData(cell);
  if (!next?.cost) return null;
  const discount = getUpgradeDiscount(x, y);
  const cost = {};
  for (const [k, v] of Object.entries(next.cost)) {
    cost[k] = Math.max(0, round1(v * (1 - discount)));
  }
  return cost;
}

export function canUpgradeSelected() {
  const cell = getSelectedCell();
  if (!cell || cell.issue) return false;
  const data = BUILDINGS[cell.type];
  if (cell.level >= data.levels.length) return false;
  const { x, y } = STATE.selectedBuilding;
  return hasResources(getUpgradeCost(cell, x, y));
}

export function upgradeSelected() {
  const cell = getSelectedCell();
  if (!cell) { setMessage("Select a building."); return; }
  if (cell.issue) { setMessage("Repair issue first."); return; }
  const data = BUILDINGS[cell.type];
  if (cell.level >= data.levels.length) { setMessage("Max level reached."); return; }
  const { x, y } = STATE.selectedBuilding;
  const cost = getUpgradeCost(cell, x, y);
  if (!hasResources(cost)) { setMessage("Need more resources."); return; }
  spendResources(cost);
  cell.level += 1;
  STATE.stats.totalUpgradesDone++;
  setMessage(`${data.label} upgraded to level ${cell.level}.`);
}

export function getRepairCost(cell) {
  const base = 12 * cell.level;
  return { coins: base, tools: Math.max(2, Math.floor(base / 8)) };
}

export function repairSelected() {
  const cell = getSelectedCell();
  if (!cell) { setMessage("Select a building."); return; }
  if (!cell.issue) { setMessage("No issue to repair."); return; }
  const cost = getRepairCost(cell);
  if (!hasResources(cost)) { setMessage("Need repair resources."); return; }
  spendResources(cost);
  cell.issue = null;
  setMessage("Building repaired.");
}

export function getSelectedCell() {
  if (!STATE.selectedBuilding) return null;
  const { x, y } = STATE.selectedBuilding;
  if (x < 0 || y < 0 || x >= GRID_SIZE || y >= GRID_SIZE) return null;
  return STATE.grid[y][x] || null;
}

// ── Tick ──
export function applyBuffDecay() {
  STATE.buffs = STATE.buffs
    .map(b => ({ ...b, remaining: b.remaining - 1 }))
    .filter(b => b.remaining > 0);
}

export function tickSecond(allowIssues = true) {
  updateCaps();
  forEachBuilding((cell, x, y) => applyProduction(cell, x, y));
  resolveAutoSellFood();
  applyBuffDecay();

  const stats = computePassiveStats();
  STATE.happiness = stats.happiness;

  if (STATE.population < stats.popCap && (STATE.resources.food || 0) > 0) {
    const growth = clamp(STATE.happiness / 260, 0.05, 0.8);
    STATE.population = Math.min(stats.popCap, STATE.population + growth);
  }
  if (STATE.population > stats.popCap) {
    STATE.population = Math.max(stats.popCap, STATE.population - 0.2);
  }

  if (STATE.happinessPenaltyTicks > 0) STATE.happinessPenaltyTicks -= 1;
  if (allowIssues) maybeCreateIssue();
  processEventsTick();
  evaluateWinConditions();

  STATE.stats.playTimeSeconds++;

  // Record history every 30 seconds
  if (STATE.stats.playTimeSeconds % 30 === 0) {
    STATE.stats.history.push({
      t: STATE.stats.playTimeSeconds,
      pop: Math.floor(STATE.population),
      happy: STATE.happiness,
      coins: Math.floor(STATE.resources.coins),
      food: Math.floor(STATE.resources.food),
    });
    if (STATE.stats.history.length > 200) STATE.stats.history.shift();
  }
}
