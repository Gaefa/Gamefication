// ── Game State ─────────────────────────────────────────────────────
import { GRID_SIZE, TERRAIN } from "./config.js";

export function createStartingResources() {
  return {
    wood: 50, stone: 30, food: 20, coins: 100,
    planks: 0, bricks: 0, tools: 0, cloth: 0,
    metal: 0, glass: 0, energy: 0, science: 0,
    culture: 0, fame: 0, water_res: 0,
  };
}

export function createBaseCaps() {
  return {
    wood: 300, stone: 300, food: 300, coins: 999999,
    planks: 150, bricks: 150, tools: 120, cloth: 120,
    metal: 120, glass: 120, energy: 200, science: 200,
    culture: 200, fame: 999999, water_res: 999999,
  };
}

export function createEmptyGrid() {
  return Array.from({ length: GRID_SIZE }, () => Array(GRID_SIZE).fill(null));
}

export function createEmptyTerrain() {
  return Array.from({ length: GRID_SIZE }, () =>
    Array.from({ length: GRID_SIZE }, () => TERRAIN.GRASS)
  );
}

export const STATE = {
  mode: "menu",
  cityLevel: 1,
  prestigeStars: 0,
  prestigeCount: 0,
  grid: createEmptyGrid(),
  terrain: createEmptyTerrain(),
  resources: createStartingResources(),
  caps: createBaseCaps(),
  population: 0,
  happiness: 60,
  selectedTool: "road",
  selectedBuilding: null,
  hover: { x: -1, y: -1, inGrid: false },
  message: "",
  messageTimer: 0,
  tickTimer: 0,
  eventTimer: 30,
  activeEvent: null,
  buffs: [],
  quickSlots: [],
  winUnlockedAt: null,
  hasUltimateWin: false,
  happinessPenaltyTicks: 0,

  // camera
  camera: { x: GRID_SIZE * 16, y: 0, zoom: 1 },
  isDragging: false,
  dragStart: { x: 0, y: 0 },
  camStart: { x: 0, y: 0 },

  // day/night
  dayTime: 0.35,
  daySpeed: 0.0003,
  dayPaused: false,

  // stats tracking
  stats: {
    totalCoinsEarned: 0,
    totalFoodProduced: 0,
    totalBuildingsPlaced: 0,
    totalUpgradesDone: 0,
    playTimeSeconds: 0,
    history: [],
  },

  // save slots
  currentSlot: 0,

  // tutorial
  tutorialStep: 0,
  tutorialDone: false,
};
