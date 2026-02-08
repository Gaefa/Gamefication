// ── Main Entry Point ───────────────────────────────────────────────
import { GRID_SIZE, BUILDINGS, RESOURCES, CATEGORIES, TERRAIN } from "./config.js";
import { STATE, createEmptyGrid, createStartingResources } from "./state.js";
import { generateTerrain, canBuildOnTerrain, getTerrainBuildCostMultiplier } from "./mapgen.js";
import {
  hasResources, spendResources, addResources, setMessage, resourceToString, formatRes,
  getBuildingLevelData, getNextLevelData, forEachBuilding, isConnectedToRoad,
  getUpgradeDiscount, clamp, getPrestigeProductionBonus, getCityLevelProductionBonus,
  computePassiveStats, round1, getRoadMask,
} from "./economy.js";
import { getEventDefinition, resolveEvent } from "./events.js";
import {
  getCurrentLevelEntry, getNextLevelEntry, canLevelUp, levelUp,
  prestige, calculatePrestigeGain, getWinConditionRows,
  canUpgradeSelected, upgradeSelected, getRepairCost, repairSelected,
  getSelectedCell, getUpgradeCost, tickSecond,
} from "./progression.js";
import { renderWorld, renderMenu, screenToWorld, isoToGrid, gridToIso, drawMinimap } from "./renderer.js";
import { saveGame, loadGame, getAllSlotInfo, deleteSave } from "./save.js";
import { SFX, toggleMute, isMuted } from "./sound.js";
import { getCurrentTutorialStep, advanceTutorial, dismissTutorialStep, skipTutorial } from "./tutorial.js";

// ── DOM elements ──
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const resourceBar = document.getElementById("resource-bar");
const buildList = document.getElementById("build-list");
const infoPanel = document.getElementById("city-stats");
const selectedInfo = document.getElementById("selected-info");
const levelBtn = document.getElementById("level-btn");
const prestigeBtn = document.getElementById("prestige-btn");
const winConditionsPanel = document.getElementById("win-conditions");
const eventPanel = document.getElementById("event-panel");
const eventAcceptBtn = document.getElementById("event-accept-btn");
const eventDeclineBtn = document.getElementById("event-decline-btn");
const upgradeWindowBtn = document.getElementById("upgrade-window-btn");
const upgradeBtn = document.getElementById("upgrade-btn");
const repairBtn = document.getElementById("repair-btn");
const bulldozeBtn = document.getElementById("bulldoze-btn");
const upgradeModal = document.getElementById("upgrade-modal");
const closeUpgradeModalBtn = document.getElementById("close-upgrade-modal-btn");
const upgradeSummary = document.getElementById("upgrade-summary");
const upgradeTree = document.getElementById("upgrade-tree");
const upgradeFromModalBtn = document.getElementById("upgrade-from-modal-btn");
const startBtn = document.getElementById("start-btn");
const tutorialPanel = document.getElementById("tutorial-panel");
const tutorialTitle = document.getElementById("tutorial-title");
const tutorialText = document.getElementById("tutorial-text");
const tutorialDismissBtn = document.getElementById("tutorial-dismiss-btn");
const tutorialSkipBtn = document.getElementById("tutorial-skip-btn");
const statsPanel = document.getElementById("stats-panel");
const statsCanvas = document.getElementById("stats-canvas");
const muteBtn = document.getElementById("mute-btn");
const minimapEl = document.getElementById("minimap-canvas");
const dayIndicator = document.getElementById("day-indicator");
const slotContainer = document.getElementById("slot-container");

// ── Canvas setup ──
function resizeCanvas() {
  // Match internal canvas resolution to its CSS display size
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.round(rect.width * dpr);
  canvas.height = Math.round(rect.height * dpr);
}
resizeCanvas();

// ── Resource bar ──
function buildResourceBar() {
  resourceBar.innerHTML = "";
  RESOURCES.forEach(r => {
    const d = document.createElement("div");
    d.id = `res-${r.id}`;
    d.className = "res-item";
    resourceBar.appendChild(d);
  });
}

function renderResources() {
  RESOURCES.forEach(r => {
    const el = document.getElementById(`res-${r.id}`);
    if (!el) return;
    const v = STATE.resources[r.id] || 0;
    const cap = STATE.caps[r.id] ?? 999999;
    const capText = cap >= 999999 ? "" : `/${formatRes(cap)}`;
    el.textContent = `${r.icon} ${formatRes(v)}${capText}`;
    el.classList.toggle("res-full", v >= cap * 0.95 && cap < 999999);
    el.classList.toggle("res-low", v < 10 && r.id !== "fame");
  });
}

// ── City stats ──
function renderCityStats() {
  const current = getCurrentLevelEntry();
  const next = getNextLevelEntry();
  const passive = computePassiveStats();
  const buffText = STATE.buffs.length > 0
    ? STATE.buffs.map(b => `${b.name} (${Math.ceil(b.remaining)}s)`).join(", ")
    : "None";

  const lines = [
    `Level: ${STATE.cityLevel} (${current?.name || "-"})`,
    `Population: ${Math.floor(STATE.population)} / ${passive.popCap}`,
    `Happiness: ${STATE.happiness}`,
    `Prestige: ${STATE.prestigeStars} stars`,
    `Boost: +${Math.round((getPrestigeProductionBonus() + getCityLevelProductionBonus()) * 100)}%`,
    `Buffs: ${buffText}`,
  ];
  if (next) {
    lines.push(`<div class="divider-thin"></div>`);
    lines.push(`Next: ${resourceToString(next.requirements)}`);
  } else {
    lines.push("Max level reached.");
  }
  infoPanel.innerHTML = lines.map(l => `<div>${l}</div>`).join("");
  levelBtn.disabled = !canLevelUp();
  prestigeBtn.disabled = STATE.cityLevel < 7;
}

// ── Build menu ──
function renderBuildMenu() {
  buildList.innerHTML = "";
  const unlocked = Object.entries(BUILDINGS)
    .filter(([, d]) => d.unlockLevel <= STATE.cityLevel)
    .map(([id]) => id);

  STATE.quickSlots = [];

  CATEGORIES.forEach(cat => {
    const title = document.createElement("div");
    title.className = "cat-title";
    title.textContent = cat;
    buildList.appendChild(title);

    Object.entries(BUILDINGS)
      .filter(([, d]) => d.category === cat)
      .forEach(([id, d]) => {
        const item = document.createElement("div");
        item.className = "build-item";

        const btn = document.createElement("button");
        btn.textContent = d.label;
        btn.disabled = !unlocked.includes(id);
        btn.addEventListener("click", () => {
          STATE.selectedTool = id;
          SFX.click();
          renderBuildMenu();
        });
        if (STATE.selectedTool === id) btn.classList.add("active-tool");

        const meta = document.createElement("div");
        meta.className = "meta";
        meta.textContent = resourceToString(d.buildCost);

        item.appendChild(btn);
        item.appendChild(meta);
        buildList.appendChild(item);

        if (unlocked.includes(id) && STATE.quickSlots.length < 9) {
          STATE.quickSlots.push(id);
        }
      });
  });
}

// ── Selected building info ──
function renderSelectedInfo() {
  const cell = getSelectedCell();
  if (!cell) {
    selectedInfo.textContent = "Click a building to select it.";
    upgradeBtn.disabled = true;
    repairBtn.disabled = true;
    upgradeWindowBtn.disabled = true;
    return;
  }

  const data = BUILDINGS[cell.type];
  const ld = getBuildingLevelData(cell);
  const next = getNextLevelData(cell);
  const { x, y } = STATE.selectedBuilding;
  const connected = isConnectedToRoad(x, y);

  const lines = [
    `<strong>${data.label}</strong> (${ld.stage})`,
    `Level: ${cell.level}/${data.levels.length}`,
    `Issue: <span class="${cell.issue ? 'status-bad' : ''}">${cell.issue || "None"}</span>`,
    `Output: ${resourceToString(ld.produces)}`,
  ];
  if (ld.consumes) lines.push(`Input: ${resourceToString(ld.consumes)}`);
  if (ld.population) lines.push(`Pop +${ld.population}`);
  if (ld.happiness) lines.push(`Happy +${ld.happiness}`);
  if (data.requiresRoad) lines.push(`Road: <span class="${connected ? 'status-ok' : 'status-bad'}">${connected ? 'Connected' : 'NOT CONNECTED'}</span>`);

  if (next?.cost) {
    const discounted = getUpgradeCost(cell, x, y);
    lines.push(`<div class="divider-thin"></div>Upgrade: ${resourceToString(discounted)}`);
  }

  selectedInfo.innerHTML = lines.map(l => `<div>${l}</div>`).join("");
  upgradeBtn.disabled = !canUpgradeSelected();
  repairBtn.disabled = !cell.issue || !hasResources(getRepairCost(cell));
  upgradeWindowBtn.disabled = false;
}

// ── Upgrade modal ──
function renderUpgradeModal() {
  const cell = getSelectedCell();
  if (!cell) {
    upgradeSummary.innerHTML = "<div>Select a building to inspect.</div>";
    upgradeTree.innerHTML = "";
    upgradeFromModalBtn.disabled = true;
    return;
  }

  const data = BUILDINGS[cell.type];
  const ld = getBuildingLevelData(cell);
  const { x, y } = STATE.selectedBuilding;
  const discount = getUpgradeDiscount(x, y);

  upgradeSummary.innerHTML = [
    `<div><strong>${data.label}</strong> at (${x}, ${y})</div>`,
    `<div>Stage: ${ld.stage} (L${cell.level}/${data.levels.length})</div>`,
    `<div>Issue: ${cell.issue || "None"}</div>`,
    `<div>Discount: ${Math.round(discount * 100)}%</div>`,
  ].join("");

  upgradeTree.innerHTML = data.levels.map((entry, idx) => {
    const level = idx + 1;
    const cls = level < cell.level ? "done" : level === cell.level ? "current" : "locked";
    const bits = [];
    if (entry.produces) bits.push(`+ ${resourceToString(entry.produces)}`);
    if (entry.consumes) bits.push(`- ${resourceToString(entry.consumes)}`);
    if (entry.population) bits.push(`Pop +${entry.population}`);
    if (entry.happiness) bits.push(`Happy +${entry.happiness}`);
    if (entry.storage) bits.push(`Storage +${entry.storage}`);
    const cost = entry.cost ? `Cost: ${resourceToString(entry.cost)}` : "Base level";
    return `<div class="tree-node ${cls}"><div><strong>L${level} ${entry.stage}</strong></div><div>${cost}</div>${bits.map(b => `<div>${b}</div>`).join("")}</div>`;
  }).join("");

  upgradeFromModalBtn.disabled = !canUpgradeSelected();
}

function openUpgradeModal() {
  if (!getSelectedCell()) { setMessage("Select a building."); return; }
  renderUpgradeModal();
  upgradeModal.classList.remove("hidden");
}

function closeUpgradeModal() {
  upgradeModal.classList.add("hidden");
}

// ── Events panel ──
function renderEventPanel() {
  const def = getEventDefinition();
  if (!def) {
    eventPanel.textContent = `No events. Next: ${Math.max(0, Math.ceil(STATE.eventTimer))}s`;
    eventAcceptBtn.disabled = true;
    eventDeclineBtn.disabled = true;
    return;
  }
  eventPanel.innerHTML = `<strong>${def.title}</strong><div>${def.body}</div>`;
  eventAcceptBtn.textContent = def.acceptLabel || "Accept";
  eventDeclineBtn.textContent = def.declineLabel || "Decline";
  eventAcceptBtn.disabled = def.canAccept ? !def.canAccept() : false;
  eventDeclineBtn.disabled = false;
}

// ── Win conditions ──
function renderWinConditions() {
  const rows = getWinConditionRows();
  winConditionsPanel.innerHTML = rows
    .map(r => `<div class="${r.done ? 'status-ok' : 'status-bad'}">${r.done ? '[+]' : '[ ]'} ${r.text}</div>`)
    .join("");
}

// ── Tutorial ──
function renderTutorial() {
  if (!tutorialPanel) return;
  const step = getCurrentTutorialStep();
  if (!step) {
    tutorialPanel.classList.add("hidden");
    return;
  }
  tutorialPanel.classList.remove("hidden");
  tutorialTitle.textContent = step.title;
  tutorialText.textContent = step.text;
}

// ── Stats chart ──
function renderStatsChart() {
  if (!statsCanvas) return;
  const sctx = statsCanvas.getContext("2d");
  const w = statsCanvas.width;
  const h = statsCanvas.height;
  sctx.clearRect(0, 0, w, h);
  sctx.fillStyle = "rgba(0,0,0,0.5)";
  sctx.fillRect(0, 0, w, h);

  const hist = STATE.stats.history;
  if (hist.length < 2) {
    sctx.fillStyle = "#888";
    sctx.font = "11px monospace";
    sctx.fillText("Collecting data...", 10, h / 2);
    return;
  }

  function drawLine(data, key, color) {
    const maxVal = Math.max(...data.map(d => d[key]), 1);
    sctx.strokeStyle = color;
    sctx.lineWidth = 1.5;
    sctx.beginPath();
    data.forEach((d, i) => {
      const x = (i / (data.length - 1)) * w;
      const y = h - (d[key] / maxVal) * (h - 20) - 10;
      i === 0 ? sctx.moveTo(x, y) : sctx.lineTo(x, y);
    });
    sctx.stroke();
  }

  drawLine(hist, "pop", "#4a4");
  drawLine(hist, "happy", "#aa4");
  drawLine(hist, "coins", "#ffd65c");

  // Legend
  sctx.font = "9px monospace";
  const legend = [["Pop", "#4a4"], ["Happy", "#aa4"], ["Coins", "#ffd65c"]];
  legend.forEach(([l, c], i) => {
    sctx.fillStyle = c;
    sctx.fillRect(4 + i * 55, 4, 8, 8);
    sctx.fillStyle = "#ccc";
    sctx.fillText(l, 14 + i * 55, 11);
  });
}

// ── Day indicator ──
function renderDayIndicator() {
  if (!dayIndicator) return;
  const t = STATE.dayTime;
  let phase;
  if (t < 0.2 || t > 0.8) phase = "Night";
  else if (t < 0.3) phase = "Dawn";
  else if (t < 0.7) phase = "Day";
  else phase = "Dusk";
  dayIndicator.textContent = phase;
}

// ── Save slots ──
function renderSlots() {
  if (!slotContainer) return;
  const slots = getAllSlotInfo();
  slotContainer.innerHTML = slots.map(({ slot, info }) => {
    if (info) {
      return `<div class="slot-item ${slot === STATE.currentSlot ? 'active' : ''}">
        <button class="slot-btn" data-slot="${slot}">
          <strong>Slot ${slot + 1}</strong>
          <div>Lvl ${info.cityLevel} | Pop ${info.population} | Stars ${info.prestigeStars}</div>
          <div class="slot-time">${info.lastSaved}</div>
        </button>
      </div>`;
    }
    return `<div class="slot-item"><button class="slot-btn slot-empty" data-slot="${slot}">Slot ${slot + 1} — Empty</button></div>`;
  }).join("");

  slotContainer.querySelectorAll(".slot-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const s = parseInt(btn.dataset.slot);
      if (STATE.mode === "play") saveGame(STATE.currentSlot);
      if (loadGame(s)) {
        STATE.mode = "play";
        startBtn.classList.add("hidden");
        renderBuildMenu();
        SFX.click();
      } else {
        STATE.currentSlot = s;
        startNewGame();
      }
    });
  });
}

// ── Minimap ──
function renderMinimap() {
  if (!minimapEl) return;
  const mctx = minimapEl.getContext("2d");
  drawMinimap(mctx, 0, 0, minimapEl.width, minimapEl.height);
}

// ── Building placement ──
function handleBuild(type) {
  if (STATE.mode !== "play" || !STATE.hover.inGrid) return;
  const { x, y } = STATE.hover;
  const cell = STATE.grid[y][x];

  if (type === "bulldoze") {
    if (!cell) { setMessage("Nothing to clear."); return; }
    STATE.grid[y][x] = null;
    if (STATE.selectedBuilding?.x === x && STATE.selectedBuilding?.y === y) {
      STATE.selectedBuilding = null;
    }
    SFX.bulldoze();
    setMessage("Tile cleared.");
    return;
  }

  if (cell) { setMessage("Tile occupied."); SFX.error(); return; }

  const data = BUILDINGS[type];
  if (!data || data.unlockLevel > STATE.cityLevel) { setMessage("Building locked."); SFX.error(); return; }

  const terrainType = STATE.terrain[y][x];
  if (!canBuildOnTerrain(terrainType)) { setMessage("Can't build on water!"); SFX.error(); return; }

  const costMult = getTerrainBuildCostMultiplier(terrainType);
  const adjustedCost = {};
  for (const [k, v] of Object.entries(data.buildCost)) {
    adjustedCost[k] = Math.ceil(v * costMult);
  }

  if (!hasResources(adjustedCost)) { setMessage("Not enough resources."); SFX.error(); return; }

  spendResources(adjustedCost);
  STATE.grid[y][x] = { type, level: 1, issue: null };
  STATE.stats.totalBuildingsPlaced++;
  SFX.build();
  setMessage(`${data.label} built.`);
  renderBuildMenu();
}

function setSelectedBuilding(x, y) {
  const cell = STATE.grid[y][x];
  STATE.selectedBuilding = cell ? { x, y } : null;
  SFX.click();
  renderSelectedInfo();
  renderUpgradeModal();
}

// ── Start new game ──
function startNewGame() {
  STATE.mode = "play";
  STATE.terrain = generateTerrain(Date.now());
  STATE.grid = createEmptyGrid();
  STATE.resources = createStartingResources();
  STATE.cityLevel = 1;
  STATE.population = 0;
  STATE.happiness = 60;
  STATE.camera.x = GRID_SIZE * 16;
  STATE.camera.y = 0;
  STATE.camera.zoom = 1;
  STATE.tutorialStep = 0;
  STATE.tutorialDone = false;
  startBtn.classList.add("hidden");
  renderBuildMenu();
  SFX.click();
}

function startGame() {
  // Try to load current slot first
  if (loadGame(STATE.currentSlot)) {
    STATE.mode = "play";
    startBtn.classList.add("hidden");
    renderBuildMenu();
  } else {
    startNewGame();
  }
}

// ── Input handling ──
const mouse = { x: 0, y: 0, inCanvas: false };

function updateHover(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  // Convert CSS pixels to canvas internal pixels
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const sx = (clientX - rect.left) * scaleX;
  const sy = (clientY - rect.top) * scaleY;
  const { wx, wy } = screenToWorld(sx, sy, canvas.width, canvas.height);
  const { gx, gy } = isoToGrid(wx, wy);
  const inGrid = gx >= 0 && gx < GRID_SIZE && gy >= 0 && gy < GRID_SIZE;
  STATE.hover = { x: gx, y: gy, inGrid };
}

canvas.addEventListener("mousemove", e => {
  mouse.x = e.clientX;
  mouse.y = e.clientY;
  mouse.inCanvas = true;

  if (STATE.isDragging) {
    const dx = e.clientX - STATE.dragStart.x;
    const dy = e.clientY - STATE.dragStart.y;
    STATE.camera.x = STATE.camStart.x - dx / STATE.camera.zoom;
    STATE.camera.y = STATE.camStart.y - dy / STATE.camera.zoom;
    return;
  }

  updateHover(e.clientX, e.clientY);
});

canvas.addEventListener("mouseleave", () => {
  mouse.inCanvas = false;
  STATE.hover = { x: -1, y: -1, inGrid: false };
});

canvas.addEventListener("mousedown", e => {
  if (STATE.mode === "menu") { startGame(); return; }

  if (e.button === 1 || (e.button === 0 && e.shiftKey)) {
    STATE.isDragging = true;
    STATE.dragStart = { x: e.clientX, y: e.clientY };
    STATE.camStart = { x: STATE.camera.x, y: STATE.camera.y };
    return;
  }

  if (e.button === 0 && !STATE.isDragging) {
    updateHover(e.clientX, e.clientY);
    if (!STATE.hover.inGrid) return;
    const { x, y } = STATE.hover;
    const cell = STATE.grid[y][x];

    if (STATE.selectedTool === "bulldoze") { handleBuild("bulldoze"); return; }
    if (cell) { setSelectedBuilding(x, y); return; }
    handleBuild(STATE.selectedTool);
  }

  if (e.button === 2) {
    updateHover(e.clientX, e.clientY);
    handleBuild("bulldoze");
  }
});

canvas.addEventListener("mouseup", () => {
  STATE.isDragging = false;
});

canvas.addEventListener("wheel", e => {
  e.preventDefault();
  const delta = -Math.sign(e.deltaY) * 0.1;
  STATE.camera.zoom = clamp(STATE.camera.zoom + delta, 0.3, 3);
}, { passive: false });

canvas.addEventListener("contextmenu", e => e.preventDefault());

// Touch support
let lastTouchDist = 0;
canvas.addEventListener("touchstart", e => {
  if (e.touches.length === 1) {
    const t = e.touches[0];
    STATE.isDragging = true;
    STATE.dragStart = { x: t.clientX, y: t.clientY };
    STATE.camStart = { x: STATE.camera.x, y: STATE.camera.y };
  } else if (e.touches.length === 2) {
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    lastTouchDist = Math.sqrt(dx * dx + dy * dy);
  }
}, { passive: true });

canvas.addEventListener("touchmove", e => {
  e.preventDefault();
  if (e.touches.length === 1 && STATE.isDragging) {
    const t = e.touches[0];
    STATE.camera.x = STATE.camStart.x - (t.clientX - STATE.dragStart.x) / STATE.camera.zoom;
    STATE.camera.y = STATE.camStart.y - (t.clientY - STATE.dragStart.y) / STATE.camera.zoom;
  } else if (e.touches.length === 2) {
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (lastTouchDist > 0) {
      const scale = dist / lastTouchDist;
      STATE.camera.zoom = clamp(STATE.camera.zoom * scale, 0.3, 3);
    }
    lastTouchDist = dist;
  }
}, { passive: false });

canvas.addEventListener("touchend", e => {
  if (e.touches.length === 0) {
    STATE.isDragging = false;
    lastTouchDist = 0;
  }
});

// Keyboard
window.addEventListener("keydown", e => {
  const key = e.key.toLowerCase();

  if (e.key === "Enter" && STATE.mode === "menu") { startGame(); return; }

  if (key === "f") {
    if (!document.fullscreenElement) canvas.requestFullscreen?.();
    else document.exitFullscreen?.();
  }
  if (key === "b") { STATE.selectedTool = "bulldoze"; renderBuildMenu(); }
  if (key === "u") { upgradeSelected(); SFX.upgrade(); }
  if (key === "r") { repairSelected(); SFX.repair(); }
  if (key === "o") openUpgradeModal();
  if (key === "p") { prestige(); SFX.prestige(); }
  if (key === "m") {
    toggleMute();
    if (muteBtn) muteBtn.textContent = isMuted() ? "Unmute" : "Mute";
  }
  if (key === "escape") closeUpgradeModal();

  // Quick slots 1-9
  const idx = parseInt(e.key, 10);
  if (idx >= 1 && idx <= 9 && STATE.quickSlots[idx - 1]) {
    STATE.selectedTool = STATE.quickSlots[idx - 1];
    renderBuildMenu();
  }

  // Arrow keys for camera
  const camSpeed = 20 / STATE.camera.zoom;
  if (key === "arrowleft" || key === "a") STATE.camera.x -= camSpeed;
  if (key === "arrowright" || key === "d") STATE.camera.x += camSpeed;
  if (key === "arrowup" || key === "w") STATE.camera.y -= camSpeed;
  if (key === "arrowdown" || key === "s") STATE.camera.y += camSpeed;
});

// ── Button listeners ──
startBtn.addEventListener("click", startGame);
levelBtn.addEventListener("click", () => { levelUp(); SFX.levelUp(); renderBuildMenu(); renderCityStats(); });
prestigeBtn.addEventListener("click", () => { prestige(); SFX.prestige(); });
upgradeBtn.addEventListener("click", () => { upgradeSelected(); SFX.upgrade(); renderSelectedInfo(); renderUpgradeModal(); });
repairBtn.addEventListener("click", () => { repairSelected(); SFX.repair(); renderSelectedInfo(); renderUpgradeModal(); });
upgradeWindowBtn.addEventListener("click", openUpgradeModal);
upgradeFromModalBtn.addEventListener("click", () => { upgradeSelected(); SFX.upgrade(); renderSelectedInfo(); renderUpgradeModal(); });
closeUpgradeModalBtn.addEventListener("click", closeUpgradeModal);
upgradeModal.addEventListener("click", e => { if (e.target === upgradeModal) closeUpgradeModal(); });
bulldozeBtn.addEventListener("click", () => { STATE.selectedTool = "bulldoze"; renderBuildMenu(); });
eventAcceptBtn.addEventListener("click", () => { resolveEvent(true); SFX.event(); renderEventPanel(); });
eventDeclineBtn.addEventListener("click", () => { resolveEvent(false); renderEventPanel(); });
if (tutorialDismissBtn) tutorialDismissBtn.addEventListener("click", () => { dismissTutorialStep(); renderTutorial(); });
if (tutorialSkipBtn) tutorialSkipBtn.addEventListener("click", () => { skipTutorial(); renderTutorial(); });
if (muteBtn) muteBtn.addEventListener("click", () => {
  toggleMute();
  muteBtn.textContent = isMuted() ? "Unmute" : "Mute";
});

// ── Game loop ──
let lastTime = performance.now();

function update(dt) {
  if (STATE.mode !== "play") return;

  if (STATE.messageTimer > 0) {
    STATE.messageTimer -= dt;
    if (STATE.messageTimer <= 0) STATE.message = "";
  }

  // Day/night cycle
  if (!STATE.dayPaused) {
    STATE.dayTime += STATE.daySpeed * dt;
    if (STATE.dayTime >= 1) STATE.dayTime -= 1;
  }

  STATE.tickTimer += dt;
  while (STATE.tickTimer >= 1) {
    tickSecond(true);
    STATE.tickTimer -= 1;
  }

  // Tutorial check
  advanceTutorial();
}

function loop(now) {
  const dt = Math.min(0.05, (now - lastTime) / 1000);
  lastTime = now;

  update(dt);

  if (STATE.mode === "play") {
    renderWorld(ctx, canvas.width, canvas.height);

    // HUD overlay on canvas
    ctx.save();
    ctx.font = "12px 'Courier New', monospace";
    ctx.textBaseline = "top";

    // Message
    if (STATE.message) {
      ctx.fillStyle = "rgba(0,0,0,0.6)";
      ctx.fillRect(canvas.width / 2 - 150, 60, 300, 24);
      ctx.fillStyle = "#ffd65c";
      ctx.textAlign = "center";
      ctx.fillText(STATE.message, canvas.width / 2, 65);
      ctx.textAlign = "left";
    }

    // Tool indicator
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(8, canvas.height - 30, 200, 22);
    ctx.fillStyle = "#fff";
    const toolLabel = STATE.selectedTool === "bulldoze" ? "Bulldoze" : BUILDINGS[STATE.selectedTool]?.label || "-";
    ctx.fillText(`Tool: ${toolLabel}`, 14, canvas.height - 26);

    // Hover info
    if (STATE.hover.inGrid) {
      const { x, y } = STATE.hover;
      const t = STATE.terrain[y]?.[x];
      const tLabel = { 0: "Grass", 1: "Water", 2: "Sand", 3: "Hill", 4: "Forest", 5: "Rock" }[t] || "?";
      ctx.fillStyle = "rgba(0,0,0,0.5)";
      ctx.fillRect(8, canvas.height - 54, 200, 22);
      ctx.fillStyle = "#ccc";
      ctx.fillText(`(${x},${y}) ${tLabel}`, 14, canvas.height - 50);
    }

    ctx.restore();
  } else {
    renderMenu(ctx, canvas.width, canvas.height);
    renderSlots();
  }

  // DOM UI
  renderResources();
  renderCityStats();
  renderSelectedInfo();
  renderEventPanel();
  renderWinConditions();
  renderTutorial();
  renderDayIndicator();
  renderMinimap();

  // Stats chart less frequently
  if (Math.floor(now / 2000) !== Math.floor((now - 16) / 2000)) {
    renderStatsChart();
  }

  requestAnimationFrame(loop);
}

// ── Init ──
window.addEventListener("resize", resizeCanvas);
window.addEventListener("beforeunload", () => saveGame());

buildResourceBar();
renderBuildMenu();
renderResources();
renderCityStats();
renderSelectedInfo();
renderUpgradeModal();
renderEventPanel();
renderWinConditions();
renderTutorial();

setInterval(() => saveGame(), 5000);
requestAnimationFrame(loop);
