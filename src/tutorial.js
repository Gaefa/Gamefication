// ── Tutorial / Hints System ─────────────────────────────────────────
import { STATE } from "./state.js";

export const TUTORIAL_STEPS = [
  {
    id: "welcome",
    title: "Welcome, Mayor!",
    text: "Your settlement awaits. Let's build a city from scratch! Start by placing some roads — they connect your buildings.",
    autoAdvance: false,
  },
  {
    id: "build_road",
    title: "Build Roads",
    text: "Select ROAD from the build menu and place a few tiles. Roads boost adjacent buildings and enable them to operate.",
    condition: () => {
      let roads = 0;
      for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) if (STATE.grid[y][x]?.type === "road") roads++;
      return roads >= 3;
    },
  },
  {
    id: "build_farm",
    title: "Feed Your People",
    text: "Build a FARM near your roads. Farms on grass terrain produce bonus food. Place them on green tiles!",
    condition: () => {
      for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) if (STATE.grid[y][x]?.type === "farm") return true;
      return false;
    },
  },
  {
    id: "build_hut",
    title: "Attract Residents",
    text: "Build a HUT next to a road. Residents need food and water. Without a road connection, they'll be unhappy.",
    condition: () => {
      for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) if (STATE.grid[y][x]?.type === "hut") return true;
      return false;
    },
  },
  {
    id: "build_water",
    title: "Water Supply",
    text: "Build a WATER TOWER to supply water to nearby buildings. Residential buildings without water produce less!",
    condition: () => {
      for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) if (STATE.grid[y][x]?.type === "water_tower") return true;
      return false;
    },
  },
  {
    id: "upgrade",
    title: "Upgrade Buildings",
    text: "Click a building to select it, then press U or click Upgrade. Higher levels produce more resources!",
    condition: () => STATE.stats.totalUpgradesDone >= 1,
  },
  {
    id: "level_up",
    title: "Grow Your City",
    text: "Check the city stats panel for level-up requirements. Meet them to unlock new buildings and bonuses!",
    condition: () => STATE.cityLevel >= 2,
  },
  {
    id: "done",
    title: "You're Ready!",
    text: "Great job! You know the basics. Keep building, upgrading, and expanding. Aim for City Level 7 and beyond!",
    autoAdvance: false,
  },
];

export function getCurrentTutorialStep() {
  if (STATE.tutorialDone) return null;
  return TUTORIAL_STEPS[STATE.tutorialStep] || null;
}

// Called by the game loop — only auto-advances steps that have a condition
export function advanceTutorial() {
  if (STATE.tutorialDone) return;
  const step = TUTORIAL_STEPS[STATE.tutorialStep];
  if (!step) return;
  // Only auto-advance if step has a condition and it's met
  if (step.condition && step.condition()) {
    STATE.tutorialStep++;
    if (STATE.tutorialStep >= TUTORIAL_STEPS.length) {
      STATE.tutorialDone = true;
    }
  }
}

// Called when user clicks "Got it" — always advances to next step
export function dismissTutorialStep() {
  if (STATE.tutorialDone) return;
  STATE.tutorialStep++;
  if (STATE.tutorialStep >= TUTORIAL_STEPS.length) {
    STATE.tutorialDone = true;
  }
}

export function skipTutorial() {
  STATE.tutorialDone = true;
}
