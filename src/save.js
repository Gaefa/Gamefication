// ── Save/Load System with Multiple Slots ───────────────────────────
import { SAVE_KEY, MAX_OFFLINE_SECONDS } from "./config.js";
import { STATE, createStartingResources, createEmptyGrid, createEmptyTerrain } from "./state.js";
import { setMessage } from "./economy.js";
import { tickSecond } from "./progression.js";

const SLOT_PREFIX = "pcb-slot-";
const MAX_SLOTS = 3;

function getSlotKey(slot) {
  return `${SLOT_PREFIX}${slot}`;
}

function serializeState() {
  return {
    cityLevel: STATE.cityLevel,
    prestigeStars: STATE.prestigeStars,
    prestigeCount: STATE.prestigeCount,
    grid: STATE.grid,
    terrain: STATE.terrain,
    resources: STATE.resources,
    population: STATE.population,
    happiness: STATE.happiness,
    selectedTool: STATE.selectedTool,
    dayTime: STATE.dayTime,
    stats: STATE.stats,
    tutorialStep: STATE.tutorialStep,
    tutorialDone: STATE.tutorialDone,
    lastSavedAt: Date.now(),
  };
}

function deserializeState(payload) {
  if (payload.cityLevel) STATE.cityLevel = payload.cityLevel;
  if (payload.prestigeStars) STATE.prestigeStars = payload.prestigeStars;
  if (payload.prestigeCount) STATE.prestigeCount = payload.prestigeCount;
  if (payload.grid) STATE.grid = payload.grid;
  if (payload.terrain) STATE.terrain = payload.terrain;
  if (payload.resources) STATE.resources = { ...createStartingResources(), ...payload.resources };
  if (payload.population) STATE.population = payload.population;
  if (payload.happiness) STATE.happiness = payload.happiness;
  if (payload.selectedTool) STATE.selectedTool = payload.selectedTool;
  if (payload.dayTime !== undefined) STATE.dayTime = payload.dayTime;
  if (payload.stats) STATE.stats = { ...STATE.stats, ...payload.stats };
  if (payload.tutorialStep !== undefined) STATE.tutorialStep = payload.tutorialStep;
  if (payload.tutorialDone !== undefined) STATE.tutorialDone = payload.tutorialDone;
}

export function saveGame(slot) {
  if (STATE.mode !== "play") return;
  const s = slot ?? STATE.currentSlot;
  const payload = serializeState();
  try {
    localStorage.setItem(getSlotKey(s), JSON.stringify(payload));
  } catch (e) {
    console.warn("Save failed:", e);
  }
}

export function loadGame(slot) {
  const s = slot ?? STATE.currentSlot;
  const raw = localStorage.getItem(getSlotKey(s));
  if (!raw) {
    // Try legacy save
    const legacy = localStorage.getItem(SAVE_KEY);
    if (legacy) {
      try {
        const payload = JSON.parse(legacy);
        deserializeState(payload);
        applyOffline(payload.lastSavedAt);
        STATE.currentSlot = s;
        return true;
      } catch (e) { console.warn("Legacy load failed:", e); }
    }
    return false;
  }

  try {
    const payload = JSON.parse(raw);
    deserializeState(payload);
    applyOffline(payload.lastSavedAt);
    STATE.currentSlot = s;
    return true;
  } catch (e) {
    console.warn("Failed to parse save:", e);
    return false;
  }
}

function applyOffline(lastSavedAt) {
  if (!lastSavedAt) return;
  const delta = Math.floor((Date.now() - lastSavedAt) / 1000);
  if (delta > 15) {
    const capped = Math.min(delta, MAX_OFFLINE_SECONDS);
    for (let i = 0; i < capped; i++) tickSecond(false);
    if (capped > 60) setMessage(`Offline progress: ${Math.floor(capped / 60)} minutes.`);
  }
}

export function deleteSave(slot) {
  localStorage.removeItem(getSlotKey(slot));
}

export function getSlotInfo(slot) {
  const raw = localStorage.getItem(getSlotKey(slot));
  if (!raw) return null;
  try {
    const p = JSON.parse(raw);
    return {
      cityLevel: p.cityLevel || 1,
      cityName: `City ${slot + 1}`,
      population: Math.floor(p.population || 0),
      prestigeStars: p.prestigeStars || 0,
      lastSaved: p.lastSavedAt ? new Date(p.lastSavedAt).toLocaleString() : "Unknown",
    };
  } catch { return null; }
}

export function getAllSlotInfo() {
  const slots = [];
  for (let i = 0; i < MAX_SLOTS; i++) {
    slots.push({ slot: i, info: getSlotInfo(i) });
  }
  return slots;
}
