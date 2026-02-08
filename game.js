const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const startBtn = document.getElementById("start-btn");
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

const pixelCanvas = document.createElement("canvas");
const pctx = pixelCanvas.getContext("2d");

const TILE_SIZE = 16;
const GRID_SIZE = 20;
const UI_TOP = 16;
const UI_BOTTOM = 32;
const BASE_WIDTH = GRID_SIZE * TILE_SIZE;
const BASE_HEIGHT = UI_TOP + GRID_SIZE * TILE_SIZE + UI_BOTTOM;

const SAVE_KEY = "pixel-city-builder-save";
const MAX_OFFLINE_SECONDS = 4 * 60 * 60;

pixelCanvas.width = BASE_WIDTH;
pixelCanvas.height = BASE_HEIGHT;

pctx.imageSmoothingEnabled = false;
ctx.imageSmoothingEnabled = false;

const RESOURCES = [
  { id: "wood", label: "Wood" },
  { id: "stone", label: "Stone" },
  { id: "food", label: "Food" },
  { id: "coins", label: "Coins" },
  { id: "planks", label: "Planks" },
  { id: "bricks", label: "Bricks" },
  { id: "tools", label: "Tools" },
  { id: "cloth", label: "Cloth" },
  { id: "metal", label: "Metal" },
  { id: "glass", label: "Glass" },
  { id: "energy", label: "Energy" },
  { id: "science", label: "Science" },
  { id: "culture", label: "Culture" },
  { id: "fame", label: "Fame" },
];

const BUILDINGS = {
  hut: {
    label: "Hut",
    category: "Residential",
    unlockLevel: 1,
    buildCost: { wood: 25, stone: 10 },
    levels: [
      {
        stage: "Hut",
        produces: { coins: 0.5 },
        consumes: { food: 0.5 },
        population: 2,
        happiness: 1,
      },
      {
        stage: "House",
        cost: { coins: 50, planks: 40, bricks: 30 },
        produces: { coins: 1 },
        consumes: { food: 0.6 },
        population: 5,
        happiness: 2,
      },
      {
        stage: "Cottage",
        cost: { coins: 150, planks: 80, bricks: 60, cloth: 30 },
        produces: { coins: 2 },
        consumes: { food: 0.7 },
        population: 10,
        happiness: 5,
      },
      {
        stage: "Mansion",
        cost: { coins: 400, bricks: 100, metal: 80, glass: 50 },
        produces: { coins: 5 },
        consumes: { food: 0.9 },
        population: 20,
        happiness: 12,
      },
      {
        stage: "Villa",
        cost: { coins: 1000, metal: 200, glass: 150, energy: 100 },
        produces: { coins: 12, culture: 0.5 },
        consumes: { food: 1 },
        population: 35,
        happiness: 24,
      },
    ],
  },
  apartment: {
    label: "Apartment",
    category: "Residential",
    unlockLevel: 4,
    buildCost: { coins: 200, bricks: 100, metal: 80 },
    levels: [
      {
        stage: "Low-rise",
        produces: { coins: 1 },
        consumes: { food: 2, energy: 0.5 },
        population: 15,
        happiness: 3,
      },
      {
        stage: "Tower",
        cost: { coins: 400, metal: 150, glass: 100 },
        produces: { coins: 2 },
        consumes: { food: 2.5, energy: 0.8 },
        population: 30,
        happiness: 4,
      },
      {
        stage: "Complex",
        cost: { coins: 800, metal: 250, glass: 200, energy: 150 },
        produces: { coins: 4 },
        consumes: { food: 3.5, energy: 1.2 },
        population: 50,
        happiness: 6,
      },
      {
        stage: "Skyblock",
        cost: { coins: 1600, metal: 400, glass: 300, energy: 250 },
        produces: { coins: 8 },
        consumes: { food: 4.5, energy: 1.8 },
        population: 80,
        happiness: 8,
      },
      {
        stage: "Megablock",
        cost: { coins: 3200, metal: 600, energy: 500, science: 100 },
        produces: { coins: 15 },
        consumes: { food: 5.5, energy: 2.6 },
        population: 120,
        happiness: 12,
      },
    ],
  },
  farm: {
    label: "Farm",
    category: "Production",
    unlockLevel: 1,
    buildCost: { wood: 10 },
    levels: [
      { stage: "Field", produces: { food: 2 } },
      { stage: "Barn Farm", cost: { coins: 50, wood: 20 }, produces: { food: 3 } },
      {
        stage: "Mill Farm",
        cost: { coins: 100, planks: 30, stone: 20 },
        produces: { food: 5 },
        synergy: { auraFoodBoost: 0.05, radius: 3 },
      },
      {
        stage: "Greenhouse",
        cost: { coins: 200, bricks: 50, tools: 30 },
        produces: { food: 8 },
        synergy: { auraFoodBoost: 0.07, radius: 3 },
      },
      {
        stage: "Hydro Farm",
        cost: { coins: 500, metal: 100, glass: 50 },
        produces: { food: 15 },
        synergy: { auraFoodBoost: 0.1, radius: 4, autoSellFood: true },
      },
    ],
  },
  lumber: {
    label: "Lumber Mill",
    category: "Production",
    unlockLevel: 1,
    buildCost: { coins: 15 },
    levels: [
      { stage: "Yard", produces: { wood: 1 } },
      {
        stage: "Saw Mill",
        cost: { coins: 40, wood: 30 },
        produces: { wood: 2, planks: 0.5 },
        synergy: { farmAdjBoost: 0.1 },
      },
      {
        stage: "Timber Plant",
        cost: { coins: 80, planks: 50, stone: 30 },
        produces: { wood: 3, planks: 1 },
        synergy: { farmAdjBoost: 0.12 },
      },
      {
        stage: "Industrial Lumber",
        cost: { coins: 150, bricks: 40, tools: 20 },
        produces: { wood: 5, planks: 2 },
        synergy: { farmAdjBoost: 0.14 },
      },
      {
        stage: "Auto Forestry",
        cost: { coins: 400, metal: 80 },
        produces: { wood: 8, planks: 4 },
        synergy: { farmAdjBoost: 0.15 },
      },
    ],
  },
  quarry: {
    label: "Quarry",
    category: "Production",
    unlockLevel: 1,
    buildCost: { coins: 20, wood: 10 },
    levels: [
      { stage: "Pit", produces: { stone: 1 } },
      {
        stage: "Stone Yard",
        cost: { coins: 60, wood: 40 },
        produces: { stone: 2, bricks: 0.3 },
      },
      {
        stage: "Brickworks",
        cost: { coins: 120, planks: 60, food: 40 },
        produces: { stone: 3, bricks: 0.8 },
      },
      {
        stage: "Deep Quarry",
        cost: { coins: 250, bricks: 50, tools: 30 },
        produces: { stone: 5, bricks: 1.5 },
      },
      {
        stage: "Mega Quarry",
        cost: { coins: 600, metal: 100, energy: 50 },
        produces: { stone: 10, bricks: 3, glass: 0.2 },
      },
    ],
  },
  workshop: {
    label: "Workshop",
    category: "Production",
    unlockLevel: 2,
    buildCost: { coins: 50, wood: 30, stone: 20 },
    levels: [
      {
        stage: "Craft Shed",
        produces: { tools: 0.5 },
        consumes: { wood: 1, stone: 0.5 },
      },
      {
        stage: "Tool House",
        cost: { coins: 100, planks: 40, bricks: 30 },
        produces: { tools: 1 },
        consumes: { wood: 1.2, stone: 0.6 },
        synergy: { upgradeDiscount: 0.1, radius: 3 },
      },
      {
        stage: "Mechanic Hall",
        cost: { coins: 200, planks: 60, bricks: 40, tools: 20 },
        produces: { tools: 2, cloth: 1 },
        consumes: { wood: 1.5, stone: 0.8 },
        synergy: { upgradeDiscount: 0.12, radius: 3 },
      },
      {
        stage: "Automation Yard",
        cost: { coins: 400, metal: 80, tools: 40 },
        produces: { tools: 4, cloth: 2 },
        consumes: { wood: 1.8, stone: 1 },
        synergy: { upgradeDiscount: 0.14, radius: 4 },
      },
      {
        stage: "Nano Workshop",
        cost: { coins: 800, metal: 150, glass: 80 },
        produces: { tools: 8, cloth: 3 },
        consumes: { wood: 2, stone: 1.2 },
        synergy: { upgradeDiscount: 0.16, radius: 4 },
      },
    ],
  },
  foundry: {
    label: "Foundry",
    category: "Production",
    unlockLevel: 3,
    buildCost: { coins: 150, bricks: 80, tools: 40 },
    levels: [
      {
        stage: "Smelter",
        produces: { metal: 0.3 },
        consumes: { stone: 2, tools: 0.3 },
      },
      {
        stage: "Furnace",
        cost: { coins: 300, bricks: 100, tools: 60 },
        produces: { metal: 0.8 },
        consumes: { stone: 2.4, tools: 0.4 },
      },
      {
        stage: "Refinery",
        cost: { coins: 600, metal: 80, cloth: 40 },
        produces: { metal: 1.5, glass: 0.5 },
        consumes: { stone: 2.8, energy: 0.3 },
      },
      {
        stage: "Steel Plant",
        cost: { coins: 1200, metal: 150, glass: 100 },
        produces: { metal: 3, glass: 1.2 },
        consumes: { stone: 3.2, energy: 0.6 },
      },
      {
        stage: "Fusion Forge",
        cost: { coins: 2500, metal: 300, energy: 200 },
        produces: { metal: 6, glass: 3 },
        consumes: { stone: 4, energy: 1.2 },
      },
    ],
  },
  market: {
    label: "Market",
    category: "Commercial",
    unlockLevel: 2,
    buildCost: { coins: 80, planks: 50, bricks: 30 },
    levels: [
      {
        stage: "Bazaar",
        produces: { coins: 2 },
        synergy: { residentialCoins: 0.15 },
      },
      {
        stage: "Town Market",
        cost: { coins: 160, planks: 80, bricks: 60 },
        produces: { coins: 4 },
        synergy: { residentialCoins: 0.2 },
      },
      {
        stage: "Trade Hall",
        cost: { coins: 320, metal: 100, glass: 80 },
        produces: { coins: 7 },
        synergy: { residentialCoins: 0.3 },
      },
      {
        stage: "Grand Exchange",
        cost: { coins: 640, metal: 200, glass: 150 },
        produces: { coins: 12 },
        synergy: { residentialCoins: 0.4 },
      },
      {
        stage: "Global Market",
        cost: { coins: 1280, metal: 300, glass: 250, energy: 100 },
        produces: { coins: 20 },
        synergy: { residentialCoins: 0.5 },
      },
    ],
  },
  bank: {
    label: "Bank",
    category: "Commercial",
    unlockLevel: 5,
    buildCost: { coins: 500, bricks: 150, metal: 100, glass: 80 },
    levels: [
      { stage: "Credit Office", produces: { coins: 5 }, interestPerMin: 0.02 },
      {
        stage: "Regional Bank",
        cost: { coins: 1000, metal: 200, glass: 150 },
        produces: { coins: 10 },
        interestPerMin: 0.03,
      },
      {
        stage: "National Bank",
        cost: { coins: 2000, metal: 350, glass: 250, energy: 200 },
        produces: { coins: 18 },
        interestPerMin: 0.05,
      },
      {
        stage: "Central Reserve",
        cost: { coins: 4000, metal: 500, energy: 400, science: 150 },
        produces: { coins: 30 },
        interestPerMin: 0.08,
      },
      {
        stage: "Hyperbank",
        cost: { coins: 8000, metal: 800, energy: 600, science: 300 },
        produces: { coins: 50 },
        interestPerMin: 0.12,
      },
    ],
  },
  park: {
    label: "Park",
    category: "Culture",
    unlockLevel: 3,
    buildCost: { coins: 100, planks: 60, food: 40 },
    levels: [
      { stage: "Park", produces: { culture: 0.5 }, happiness: 10, synergy: { happinessAura: 0.15, radius: 4 } },
      {
        stage: "City Garden",
        cost: { coins: 200, planks: 100, cloth: 60 },
        produces: { culture: 1 },
        happiness: 20,
        synergy: { happinessAura: 0.2, radius: 4 },
      },
      {
        stage: "Recreation Zone",
        cost: { coins: 400, bricks: 150, cloth: 100, metal: 80 },
        produces: { culture: 2 },
        happiness: 35,
        synergy: { happinessAura: 0.25, radius: 5 },
      },
      {
        stage: "Grand Park",
        cost: { coins: 800, metal: 200, glass: 150, energy: 100 },
        produces: { culture: 4 },
        happiness: 55,
        synergy: { happinessAura: 0.3, radius: 5 },
      },
      {
        stage: "National Park",
        cost: { coins: 1600, glass: 300, energy: 250, science: 100 },
        produces: { culture: 7 },
        happiness: 80,
        synergy: { happinessAura: 0.35, radius: 6 },
      },
    ],
  },
  library: {
    label: "Library",
    category: "Culture",
    unlockLevel: 4,
    buildCost: { coins: 250, planks: 150, bricks: 100 },
    levels: [
      { stage: "Library", produces: { science: 0.5, culture: 1 } },
      {
        stage: "Research Library",
        cost: { coins: 500, bricks: 200, cloth: 150 },
        produces: { science: 1.2, culture: 2 },
      },
      {
        stage: "Academy",
        cost: { coins: 1000, metal: 250, glass: 200, cloth: 150 },
        produces: { science: 2.5, culture: 4 },
      },
      {
        stage: "Knowledge Hub",
        cost: { coins: 2000, metal: 400, glass: 350, energy: 250 },
        produces: { science: 5, culture: 7 },
      },
      {
        stage: "Archive Nexus",
        cost: { coins: 4000, metal: 600, energy: 500, science: 200 },
        produces: { science: 10, culture: 12 },
      },
    ],
  },
  theater: {
    label: "Theater",
    category: "Culture",
    unlockLevel: 5,
    buildCost: { coins: 400, bricks: 200, cloth: 150, glass: 100 },
    levels: [
      { stage: "Theater", produces: { culture: 3, fame: 0.3 }, happiness: 25 },
      {
        stage: "Opera Hall",
        cost: { coins: 800, metal: 300, glass: 200 },
        produces: { culture: 6, fame: 0.6 },
        happiness: 40,
      },
      {
        stage: "Arts Center",
        cost: { coins: 1600, metal: 500, glass: 400, energy: 300 },
        produces: { culture: 10, fame: 1 },
        happiness: 60,
      },
      {
        stage: "Grand Theater",
        cost: { coins: 3200, energy: 800, science: 300 },
        produces: { culture: 18, fame: 2 },
        happiness: 90,
      },
      {
        stage: "Cultural Capital",
        cost: { coins: 6400, energy: 1200, science: 600, fame: 200 },
        produces: { culture: 30, fame: 4 },
        happiness: 130,
      },
    ],
  },
  power: {
    label: "Power Plant",
    category: "Infrastructure",
    unlockLevel: 4,
    buildCost: { coins: 300, bricks: 150, metal: 100 },
    levels: [
      {
        stage: "Plant",
        produces: { energy: 2 },
        consumes: { stone: 1, metal: 0.5 },
      },
      {
        stage: "Grid Plant",
        cost: { coins: 600, metal: 250, tools: 150 },
        produces: { energy: 4 },
        consumes: { stone: 1.2, metal: 0.6 },
        synergy: { poweredBoost: 0.1, radius: 6 },
      },
      {
        stage: "Solar Station",
        cost: { coins: 1200, metal: 400, glass: 300 },
        produces: { energy: 7 },
        synergy: { poweredBoost: 0.12, radius: 7 },
      },
      {
        stage: "Fusion Plant",
        cost: { coins: 2400, metal: 600, glass: 500, science: 200 },
        produces: { energy: 12 },
        synergy: { poweredBoost: 0.15, radius: 8 },
      },
      {
        stage: "Reactor",
        cost: { coins: 4800, metal: 1000, energy: 800, science: 400 },
        produces: { energy: 20 },
        synergy: { poweredBoost: 0.2, radius: 10 },
      },
    ],
  },
  road: {
    label: "Road",
    category: "Infrastructure",
    unlockLevel: 2,
    buildCost: { coins: 5, stone: 3 },
    levels: [
      { stage: "Dirt", bonus: { roadBoost: 0.05 } },
      { stage: "Stone", cost: { coins: 10, stone: 8 }, bonus: { roadBoost: 0.08 } },
      { stage: "Paved", cost: { coins: 25, bricks: 20 }, bonus: { roadBoost: 0.12 } },
      { stage: "Asphalt", cost: { coins: 50, metal: 30 }, bonus: { roadBoost: 0.18 } },
      { stage: "Highway", cost: { coins: 100, metal: 60, energy: 40 }, bonus: { roadBoost: 0.25 } },
    ],
  },
  warehouse: {
    label: "Warehouse",
    category: "Infrastructure",
    unlockLevel: 2,
    buildCost: { coins: 150, planks: 100, bricks: 80 },
    levels: [
      { stage: "Storage", storage: 1000 },
      {
        stage: "Depot",
        cost: { coins: 300, planks: 150, metal: 120 },
        storage: 2500,
      },
      {
        stage: "Mega Depot",
        cost: { coins: 600, metal: 200, glass: 150 },
        storage: 5000,
      },
      {
        stage: "Logistics Hub",
        cost: { coins: 1200, metal: 350, energy: 250 },
        storage: 10000,
      },
      {
        stage: "Quantum Storage",
        cost: { coins: 2400, metal: 500, energy: 400, science: 150 },
        storage: 20000,
      },
    ],
  },
  research: {
    label: "Research Center",
    category: "Advanced",
    unlockLevel: 6,
    buildCost: { coins: 3000, metal: 700, glass: 500, energy: 400 },
    levels: [
      { stage: "Lab", produces: { science: 15, fame: 0.5 }, consumes: { energy: 2 } },
      {
        stage: "Institute",
        cost: { coins: 6000, metal: 900, energy: 700, science: 300 },
        produces: { science: 25, fame: 1 },
        consumes: { energy: 3 },
      },
      {
        stage: "Innovation Core",
        cost: { coins: 12000, metal: 1400, energy: 1200, science: 800 },
        produces: { science: 40, fame: 2 },
        consumes: { energy: 4 },
      },
    ],
  },
  wonder: {
    label: "Wonder",
    category: "Advanced",
    unlockLevel: 6,
    buildCost: { coins: 8000, metal: 1500, glass: 900, culture: 400 },
    levels: [
      { stage: "Wonder", produces: { fame: 3, culture: 10 }, happiness: 150 },
      {
        stage: "Grand Wonder",
        cost: { coins: 16000, energy: 1500, science: 800, fame: 400 },
        produces: { fame: 6, culture: 20 },
        happiness: 220,
      },
      {
        stage: "World Wonder",
        cost: { coins: 30000, energy: 2500, science: 1600, fame: 900 },
        produces: { fame: 12, culture: 35 },
        happiness: 320,
      },
    ],
  },
};

const CITY_LEVELS = [
  {
    level: 1,
    name: "Settlement",
    requirements: null,
    reward: { coins: 100 },
  },
  {
    level: 2,
    name: "Village",
    requirements: { food: 100, wood: 150, stone: 100, coins: 50 },
    reward: { coins: 250, planks: 50 },
  },
  {
    level: 3,
    name: "Town",
    requirements: { food: 500, planks: 300, bricks: 250, tools: 100, coins: 500 },
    reward: { coins: 1000, metal: 100 },
  },
  {
    level: 4,
    name: "Large City",
    requirements: { food: 1000, metal: 500, glass: 400, tools: 200, coins: 2000 },
    reward: { coins: 3000, energy: 300, science: 50 },
  },
  {
    level: 5,
    name: "Metropolis",
    requirements: { food: 2000, metal: 1000, energy: 800, science: 300, coins: 5000 },
    reward: { coins: 10000, energy: 500, science: 200, fame: 100 },
  },
  {
    level: 6,
    name: "Megapolis",
    requirements: { food: 5000, metal: 2500, energy: 2000, science: 1000, culture: 500, coins: 20000 },
    reward: { coins: 50000, fame: 500 },
  },
  {
    level: 7,
    name: "Futuristic City",
    requirements: {
      wood: 10000,
      stone: 10000,
      food: 10000,
      coins: 100000,
      energy: 5000,
      science: 3000,
      culture: 1500,
      fame: 500,
    },
    reward: { fame: 1000, science: 500 },
  },
];

const EVENT_DEFS = [
  {
    id: "caravan",
    minLevel: 2,
    title: "Trade Caravan",
    body: "A caravan offers supplies for cash flow.",
    acceptLabel: "Take Deal",
    declineLabel: "Ignore",
    onAccept: () => {
      addResources({ coins: 400, wood: 120, stone: 120 });
      setMessage("Caravan delivered resources.");
    },
    onDecline: () => {
      setMessage("Caravan moved on.");
    },
  },
  {
    id: "festival",
    minLevel: 3,
    title: "City Festival",
    body: "Hold a festival to boost morale and production for 3 minutes.",
    acceptLabel: "Fund Festival",
    declineLabel: "Skip",
    canAccept: () => hasResources({ coins: 300, food: 150 }),
    onAccept: () => {
      spendResources({ coins: 300, food: 150 });
      STATE.buffs.push({
        id: "festival-buff",
        name: "Festival",
        remaining: 180,
        productionMult: 0.2,
        happinessAdd: 15,
      });
      setMessage("Festival started.");
    },
    onDecline: () => {
      STATE.happinessPenaltyTicks += 60;
      setMessage("Citizens are disappointed.");
    },
  },
  {
    id: "storm",
    minLevel: 4,
    title: "Storm Warning",
    body: "Bad weather incoming. Protect infrastructure or risk widespread issues.",
    acceptLabel: "Mitigate",
    declineLabel: "Risk It",
    canAccept: () => hasResources({ coins: 400, tools: 40 }),
    onAccept: () => {
      spendResources({ coins: 400, tools: 40 });
      STATE.buffs.push({
        id: "storm-shield",
        name: "Protected Grid",
        remaining: 120,
        productionMult: 0.1,
        happinessAdd: 5,
      });
      setMessage("Storm defenses active.");
    },
    onDecline: () => {
      forceIssues(6);
      addResources({ wood: -100, stone: -100, food: -80 });
      setMessage("Storm caused damage.");
    },
  },
  {
    id: "innovation",
    minLevel: 5,
    title: "Innovation Grant",
    body: "A grant can accelerate high-tech growth.",
    acceptLabel: "Accept Grant",
    declineLabel: "Pass",
    onAccept: () => {
      addResources({ science: 180, energy: 200, coins: 600 });
      setMessage("Grant applied to city labs.");
    },
    onDecline: () => {
      setMessage("Grant was offered elsewhere.");
    },
  },
];

const STATE = {
  mode: "menu",
  cityLevel: 1,
  prestigeStars: 0,
  prestigeCount: 0,
  grid: createEmptyGrid(),
  resources: createStartingResources(),
  caps: createBaseCaps(),
  population: 0,
  happiness: 60,
  selectedTool: "hut",
  selectedBuilding: null,
  hover: { x: -1, y: -1, inGrid: false },
  message: "",
  messageTimer: 0,
  tickTimer: 0,
  eventTimer: 75,
  activeEvent: null,
  buffs: [],
  quickSlots: [],
  winUnlockedAt: null,
  hasUltimateWin: false,
  happinessPenaltyTicks: 0,
};

const mouse = {
  x: 0,
  y: 0,
  inCanvas: false,
};

let renderScale = 3;

function createEmptyGrid() {
  return Array.from({ length: GRID_SIZE }, () => Array(GRID_SIZE).fill(null));
}

function createStartingResources() {
  return {
    wood: 50,
    stone: 30,
    food: 20,
    coins: 100,
    planks: 0,
    bricks: 0,
    tools: 0,
    cloth: 0,
    metal: 0,
    glass: 0,
    energy: 0,
    science: 0,
    culture: 0,
    fame: 0,
  };
}

function createBaseCaps() {
  return {
    wood: 300,
    stone: 300,
    food: 300,
    coins: 999999,
    planks: 150,
    bricks: 150,
    tools: 120,
    cloth: 120,
    metal: 120,
    glass: 120,
    energy: 200,
    science: 200,
    culture: 200,
    fame: 999999,
  };
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

function formatResourceValue(value) {
  return round1(value).toString();
}

function setMessage(text) {
  STATE.message = text;
  STATE.messageTimer = 2.6;
}

function getPrestigeProductionBonus() {
  return STATE.prestigeStars * 0.05;
}

function getPrestigeHappinessBonus() {
  return STATE.prestigeStars * 0.02;
}

function getCityLevelProductionBonus() {
  if (STATE.cityLevel >= 7) return 1;
  if (STATE.cityLevel === 6) return 0.5;
  if (STATE.cityLevel === 5) return 0.35;
  if (STATE.cityLevel === 4) return 0.2;
  if (STATE.cityLevel === 3) return 0.1;
  return 0;
}

function buildResourceBar() {
  resourceBar.innerHTML = "";
  RESOURCES.forEach((resource) => {
    const item = document.createElement("div");
    item.id = `res-${resource.id}`;
    resourceBar.appendChild(item);
  });
}

function hasResources(cost) {
  if (!cost) return true;
  return Object.entries(cost).every(([key, value]) => (STATE.resources[key] || 0) >= value);
}

function spendResources(cost) {
  if (!cost) return;
  Object.entries(cost).forEach(([key, value]) => {
    STATE.resources[key] = Math.max(0, (STATE.resources[key] || 0) - value);
  });
}

function addResources(bundle) {
  if (!bundle) return;
  Object.entries(bundle).forEach(([key, value]) => {
    const cap = STATE.caps[key] ?? 999999;
    const current = STATE.resources[key] || 0;
    STATE.resources[key] = clamp(current + value, 0, cap);
  });
}

function resourceToString(cost) {
  if (!cost) return "None";
  return Object.entries(cost)
    .filter(([, value]) => value !== 0)
    .map(([key, value]) => `${formatResourceValue(value)} ${key}`)
    .join(", ");
}

function getBuildingLevelData(cell) {
  return BUILDINGS[cell.type].levels[cell.level - 1];
}

function getNextLevelData(cell) {
  return BUILDINGS[cell.type].levels[cell.level];
}

function getAdjacency(x, y) {
  const nodes = [
    { x, y: y - 1 },
    { x: x + 1, y },
    { x, y: y + 1 },
    { x: x - 1, y },
  ];
  return nodes.filter((node) => node.x >= 0 && node.x < GRID_SIZE && node.y >= 0 && node.y < GRID_SIZE);
}

function getRoadMask(x, y) {
  let mask = 0;
  const up = y > 0 ? STATE.grid[y - 1][x] : null;
  const right = x < GRID_SIZE - 1 ? STATE.grid[y][x + 1] : null;
  const down = y < GRID_SIZE - 1 ? STATE.grid[y + 1][x] : null;
  const left = x > 0 ? STATE.grid[y][x - 1] : null;
  if (up && up.type === "road") mask |= 1;
  if (right && right.type === "road") mask |= 2;
  if (down && down.type === "road") mask |= 4;
  if (left && left.type === "road") mask |= 8;
  return mask;
}

function countAdjacent(type, x, y) {
  return getAdjacency(x, y).filter((pos) => {
    const cell = STATE.grid[pos.y][pos.x];
    return cell && cell.type === type;
  }).length;
}

function forEachBuilding(callback) {
  for (let y = 0; y < GRID_SIZE; y += 1) {
    for (let x = 0; x < GRID_SIZE; x += 1) {
      const cell = STATE.grid[y][x];
      if (!cell) continue;
      callback(cell, x, y);
    }
  }
}

function getBuildingsInRadius(cx, cy, radius, filterFn) {
  const out = [];
  forEachBuilding((cell, x, y) => {
    const dx = x - cx;
    const dy = y - cy;
    if (dx * dx + dy * dy <= radius * radius && filterFn(cell, x, y)) {
      out.push({ cell, x, y });
    }
  });
  return out;
}

function getUpgradeDiscount(x, y) {
  let discount = 0;
  const workshops = getBuildingsInRadius(x, y, 4, (cell) => cell.type === "workshop" && cell.level >= 2);
  workshops.forEach(({ cell, x: sx, y: sy }) => {
    const levelData = getBuildingLevelData(cell);
    const radius = levelData.synergy?.radius || 3;
    const dx = x - sx;
    const dy = y - sy;
    if (dx * dx + dy * dy <= radius * radius) {
      discount += levelData.synergy?.upgradeDiscount || 0;
    }
  });
  return clamp(discount, 0, 0.45);
}

function getRoadBoost(x, y) {
  let roadCount = 0;
  let bestLevel = 1;
  getAdjacency(x, y).forEach((pos) => {
    const cell = STATE.grid[pos.y][pos.x];
    if (cell && cell.type === "road") {
      roadCount += 1;
      bestLevel = Math.max(bestLevel, cell.level);
    }
  });
  if (roadCount === 0) return 0;
  const boost = BUILDINGS.road.levels[bestLevel - 1].bonus.roadBoost;
  return boost * roadCount;
}

function getMarketResidentialBoost(x, y) {
  let boost = 0;
  getAdjacency(x, y).forEach((pos) => {
    const cell = STATE.grid[pos.y][pos.x];
    if (cell && cell.type === "market") {
      const levelData = getBuildingLevelData(cell);
      boost += levelData.synergy?.residentialCoins || 0;
    }
  });
  return boost;
}

function getFarmAuraBoost(x, y) {
  let boost = 0;
  const farms = getBuildingsInRadius(x, y, 4, (cell) => cell.type === "farm" && cell.level >= 3);
  farms.forEach(({ cell, x: fx, y: fy }) => {
    const levelData = getBuildingLevelData(cell);
    const radius = levelData.synergy?.radius || 3;
    const dx = x - fx;
    const dy = y - fy;
    if (dx * dx + dy * dy <= radius * radius) {
      boost += levelData.synergy?.auraFoodBoost || 0;
    }
  });
  return clamp(boost, 0, 0.5);
}

function getPowerAuraBoost(x, y) {
  let boost = 0;
  const plants = getBuildingsInRadius(x, y, 10, (cell) => cell.type === "power" && cell.level >= 2);
  plants.forEach(({ cell, x: px, y: py }) => {
    const levelData = getBuildingLevelData(cell);
    const radius = levelData.synergy?.radius || 6;
    const dx = x - px;
    const dy = y - py;
    if (dx * dx + dy * dy <= radius * radius) {
      boost += levelData.synergy?.poweredBoost || 0;
    }
  });
  return clamp(boost, 0, 0.6);
}

function getActiveBuffProductionBonus() {
  return STATE.buffs.reduce((sum, buff) => sum + (buff.productionMult || 0), 0);
}

function getActiveBuffHappinessBonus() {
  return STATE.buffs.reduce((sum, buff) => sum + (buff.happinessAdd || 0), 0);
}

function getProductionMultiplier(cell, x, y, resourceKey) {
  let multiplier = 1;
  multiplier += getCityLevelProductionBonus();
  multiplier += getPrestigeProductionBonus();
  multiplier += getActiveBuffProductionBonus();

  if (cell.type !== "road") {
    multiplier += getRoadBoost(x, y);
  }

  if (resourceKey === "food") {
    multiplier += getFarmAuraBoost(x, y);
  }

  if (resourceKey === "coins" && (cell.type === "hut" || cell.type === "apartment")) {
    multiplier += getMarketResidentialBoost(x, y);
  }

  if (cell.type !== "power" && cell.type !== "road") {
    multiplier += getPowerAuraBoost(x, y);
  }

  if (cell.type === "farm" && cell.level >= 1) {
    const lumberAdj = countAdjacent("lumber", x, y);
    if (lumberAdj > 0) {
      let bonus = 0;
      getAdjacency(x, y).forEach((pos) => {
        const neighbor = STATE.grid[pos.y][pos.x];
        if (neighbor && neighbor.type === "lumber" && neighbor.level >= 2) {
          const levelData = getBuildingLevelData(neighbor);
          bonus += levelData.synergy?.farmAdjBoost || 0;
        }
      });
      multiplier += bonus;
    }
  }

  if (cell.issue) {
    multiplier *= 0.5;
  }

  return Math.max(0, multiplier);
}

function canBuildingOperate(cell) {
  const levelData = getBuildingLevelData(cell);
  const consumes = levelData.consumes;
  if (!consumes) return true;
  return hasResources(consumes);
}

function applyProduction(cell, x, y) {
  const levelData = getBuildingLevelData(cell);

  if (!canBuildingOperate(cell)) {
    return;
  }

  if (levelData.consumes) {
    spendResources(levelData.consumes);
  }

  const produced = {};
  Object.entries(levelData.produces || {}).forEach(([key, value]) => {
    const mult = getProductionMultiplier(cell, x, y, key);
    produced[key] = (produced[key] || 0) + value * mult;
  });

  if (levelData.interestPerMin && STATE.resources.coins > 0) {
    const interest = (STATE.resources.coins * levelData.interestPerMin) / 60;
    produced.coins = (produced.coins || 0) + interest;
  }

  addResources(produced);
}

function computePassiveStats() {
  let popCap = 0;
  let happiness = 50;
  let issues = 0;

  forEachBuilding((cell, x, y) => {
    const levelData = getBuildingLevelData(cell);
    if (levelData.population) popCap += levelData.population;
    if (levelData.happiness) happiness += levelData.happiness;

    if (cell.issue) {
      issues += 1;
      happiness -= 2;
    }

    if (cell.type !== "park") {
      const parks = getBuildingsInRadius(x, y, 6, (other) => other.type === "park");
      parks.forEach(({ cell: park, x: px, y: py }) => {
        const parkLevel = getBuildingLevelData(park);
        const radius = parkLevel.synergy?.radius || 4;
        const dx = x - px;
        const dy = y - py;
        if (dx * dx + dy * dy <= radius * radius) {
          const aura = parkLevel.synergy?.happinessAura || 0;
          happiness += aura * 10;
        }
      });
    }
  });

  happiness += getActiveBuffHappinessBonus();
  happiness += getPrestigeHappinessBonus() * 100;

  if (STATE.happinessPenaltyTicks > 0) {
    happiness -= 8;
  }

  return {
    popCap: Math.max(0, Math.round(popCap)),
    happiness: clamp(Math.round(happiness), 0, 250),
    issues,
  };
}

function updateCaps() {
  const base = createBaseCaps();
  let storageBonus = 0;
  forEachBuilding((cell) => {
    if (cell.type !== "warehouse") return;
    const levelData = getBuildingLevelData(cell);
    storageBonus += levelData.storage || 0;
  });

  const caps = { ...base };
  Object.keys(caps).forEach((key) => {
    if (key === "coins" || key === "fame") return;
    caps[key] += storageBonus;
  });
  STATE.caps = caps;

  Object.keys(STATE.resources).forEach((key) => {
    const cap = STATE.caps[key] ?? 999999;
    STATE.resources[key] = Math.min(STATE.resources[key], cap);
  });
}

function maybeCreateIssue() {
  forEachBuilding((cell) => {
    if (cell.type === "road" || cell.issue) return;
    const chance = 0.001 + cell.level * 0.00035;
    if (Math.random() < chance) {
      const issueTypes = ["Power", "Traffic", "Maintenance", "Supply"];
      cell.issue = issueTypes[Math.floor(Math.random() * issueTypes.length)];
    }
  });
}

function forceIssues(count) {
  const candidates = [];
  forEachBuilding((cell, x, y) => {
    if (cell.type !== "road") {
      candidates.push({ cell, x, y });
    }
  });

  for (let i = candidates.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = candidates[i];
    candidates[i] = candidates[j];
    candidates[j] = tmp;
  }

  for (let i = 0; i < Math.min(count, candidates.length); i += 1) {
    candidates[i].cell.issue = candidates[i].cell.issue || "Emergency";
  }
}

function resolveAutoSellFood() {
  let hasAutoSell = false;
  forEachBuilding((cell) => {
    if (cell.type !== "farm") return;
    const levelData = getBuildingLevelData(cell);
    if (levelData.synergy?.autoSellFood) hasAutoSell = true;
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

function processEventsTick() {
  STATE.eventTimer -= 1;
  if (STATE.activeEvent || STATE.eventTimer > 0 || STATE.mode !== "play") return;

  const pool = EVENT_DEFS.filter((event) => event.minLevel <= STATE.cityLevel);
  if (pool.length === 0) {
    STATE.eventTimer = 60;
    return;
  }

  const pick = pool[Math.floor(Math.random() * pool.length)];
  STATE.activeEvent = { id: pick.id };
  STATE.eventTimer = 90 + Math.floor(Math.random() * 60);
  renderEventPanel();
}

function applyBuffDecay() {
  STATE.buffs = STATE.buffs
    .map((buff) => ({ ...buff, remaining: buff.remaining - 1 }))
    .filter((buff) => buff.remaining > 0);
}

function tickSecond(allowIssues = true) {
  updateCaps();

  forEachBuilding((cell, x, y) => {
    applyProduction(cell, x, y);
  });

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

  if (STATE.happinessPenaltyTicks > 0) {
    STATE.happinessPenaltyTicks -= 1;
  }

  if (allowIssues) {
    maybeCreateIssue();
  }

  processEventsTick();
  evaluateWinConditions();
}

function update(dt) {
  if (STATE.mode !== "play") return;

  if (STATE.messageTimer > 0) {
    STATE.messageTimer -= dt;
    if (STATE.messageTimer <= 0) STATE.message = "";
  }

  STATE.tickTimer += dt;
  while (STATE.tickTimer >= 1) {
    tickSecond(true);
    STATE.tickTimer -= 1;
  }
}

function canBuild(type) {
  const data = BUILDINGS[type];
  if (!data) return false;
  return data.unlockLevel <= STATE.cityLevel && hasResources(data.buildCost);
}

function handleBuild(type) {
  if (STATE.mode !== "play") return;
  if (!STATE.hover.inGrid) return;
  const { x, y } = STATE.hover;
  const cell = STATE.grid[y][x];

  if (type === "bulldoze") {
    if (!cell) {
      setMessage("Nothing to clear.");
      return;
    }
    STATE.grid[y][x] = null;
    if (STATE.selectedBuilding && STATE.selectedBuilding.x === x && STATE.selectedBuilding.y === y) {
      STATE.selectedBuilding = null;
    }
    setMessage("Tile cleared.");
    renderSelectedInfo();
    renderUpgradeModal();
    return;
  }

  if (cell) {
    setMessage("Tile occupied.");
    return;
  }

  const data = BUILDINGS[type];
  if (!data || data.unlockLevel > STATE.cityLevel) {
    setMessage("Building locked.");
    return;
  }

  if (!hasResources(data.buildCost)) {
    setMessage("Not enough resources.");
    return;
  }

  spendResources(data.buildCost);
  STATE.grid[y][x] = {
    type,
    level: 1,
    issue: null,
  };
  setMessage(`${data.label} built.`);
  renderBuildMenu();
}

function setSelectedBuilding(x, y) {
  const cell = STATE.grid[y][x];
  STATE.selectedBuilding = cell ? { x, y } : null;
  renderSelectedInfo();
  renderUpgradeModal();
}

function getSelectedCell() {
  if (!STATE.selectedBuilding) return null;
  const { x, y } = STATE.selectedBuilding;
  if (x < 0 || y < 0 || x >= GRID_SIZE || y >= GRID_SIZE) return null;
  return STATE.grid[y][x] || null;
}

function getUpgradeCost(cell) {
  const next = getNextLevelData(cell);
  if (!next || !next.cost) return null;
  const discount = getUpgradeDiscount(STATE.selectedBuilding.x, STATE.selectedBuilding.y);
  const cost = {};
  Object.entries(next.cost).forEach(([key, value]) => {
    cost[key] = Math.max(0, round1(value * (1 - discount)));
  });
  return cost;
}

function canUpgradeSelected() {
  const cell = getSelectedCell();
  if (!cell || cell.issue) return false;
  const data = BUILDINGS[cell.type];
  if (cell.level >= data.levels.length) return false;
  const cost = getUpgradeCost(cell);
  return hasResources(cost);
}

function upgradeSelected() {
  const cell = getSelectedCell();
  if (!cell) {
    setMessage("Select a building.");
    return;
  }
  if (cell.issue) {
    setMessage("Repair issue first.");
    return;
  }

  const data = BUILDINGS[cell.type];
  if (cell.level >= data.levels.length) {
    setMessage("Max level reached.");
    return;
  }

  const cost = getUpgradeCost(cell);
  if (!hasResources(cost)) {
    setMessage("Need more resources.");
    return;
  }

  spendResources(cost);
  cell.level += 1;
  setMessage(`${data.label} upgraded to level ${cell.level}.`);
  renderSelectedInfo();
  renderUpgradeModal();
  renderBuildMenu();
}

function getRepairCost(cell) {
  const base = 12 * cell.level;
  return {
    coins: base,
    tools: Math.max(2, Math.floor(base / 8)),
  };
}

function repairSelected() {
  const cell = getSelectedCell();
  if (!cell) {
    setMessage("Select a building.");
    return;
  }
  if (!cell.issue) {
    setMessage("No issue to repair.");
    return;
  }

  const cost = getRepairCost(cell);
  if (!hasResources(cost)) {
    setMessage("Need repair resources.");
    return;
  }

  spendResources(cost);
  cell.issue = null;
  setMessage("Building repaired.");
  renderSelectedInfo();
  renderUpgradeModal();
}

function getCurrentLevelEntry() {
  return CITY_LEVELS.find((entry) => entry.level === STATE.cityLevel);
}

function getNextLevelEntry() {
  return CITY_LEVELS.find((entry) => entry.level === STATE.cityLevel + 1) || null;
}

function canLevelUp() {
  const next = getNextLevelEntry();
  if (!next) return false;
  return hasResources(next.requirements);
}

function levelUp() {
  const next = getNextLevelEntry();
  if (!next) {
    setMessage("City is at max level.");
    return;
  }
  if (!hasResources(next.requirements)) {
    setMessage("Requirements are not met.");
    return;
  }

  spendResources(next.requirements);
  addResources(next.reward);
  STATE.cityLevel = next.level;
  setMessage(`City advanced: ${next.name}.`);
  renderBuildMenu();
  renderCityStats();
}

function calculatePrestigeGain() {
  if (STATE.cityLevel < 7) return 0;
  const base = 1;
  const fameBonus = Math.floor((STATE.resources.fame || 0) / 2000);
  const scienceBonus = Math.floor((STATE.resources.science || 0) / 5000);
  return base + fameBonus + scienceBonus;
}

function prestige() {
  if (STATE.cityLevel < 7) {
    setMessage("Reach level 7 to prestige.");
    return;
  }

  const gain = calculatePrestigeGain();
  if (gain <= 0) {
    setMessage("No prestige gain available.");
    return;
  }

  STATE.prestigeStars += gain;
  STATE.prestigeCount += 1;

  STATE.grid = createEmptyGrid();
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
  STATE.selectedTool = "hut";
  STATE.eventTimer = 60;
  STATE.activeEvent = null;
  STATE.buffs = [];
  STATE.happinessPenaltyTicks = 0;

  setMessage(`Prestige complete. +${gain} stars.`);
  renderBuildMenu();
  renderSelectedInfo();
  renderUpgradeModal();
}

function evaluateWinConditions() {
  const condition1 = STATE.cityLevel >= 7;
  const condition2 = STATE.prestigeCount >= 1;
  const condition3 = STATE.prestigeStars >= 3 && (STATE.resources.fame || 0) >= 1000;

  if (condition1 && !STATE.winUnlockedAt) {
    STATE.winUnlockedAt = Date.now();
  }

  const ultimate = condition1 && condition2 && condition3;
  if (ultimate && !STATE.hasUltimateWin) {
    STATE.hasUltimateWin = true;
    setMessage("Ultimate win condition completed.");
  }
}

function getWinConditionRows() {
  const rows = [
    {
      done: STATE.cityLevel >= 7,
      text: "Reach City Level 7",
    },
    {
      done: STATE.prestigeCount >= 1,
      text: "Use Prestige at least once",
    },
    {
      done: STATE.prestigeStars >= 3 && (STATE.resources.fame || 0) >= 1000,
      text: "3 Prestige Stars and 1000 Fame",
    },
  ];
  return rows;
}

function renderWinConditions() {
  const rows = getWinConditionRows();
  winConditionsPanel.innerHTML = rows
    .map((row) => `<div class="${row.done ? "status-ok" : "status-bad"}">${row.done ? "[Done]" : "[ ]"} ${row.text}</div>`)
    .join("");
}

function getEventDefinition() {
  if (!STATE.activeEvent) return null;
  return EVENT_DEFS.find((event) => event.id === STATE.activeEvent.id) || null;
}

function renderEventPanel() {
  const eventDef = getEventDefinition();
  if (!eventDef) {
    eventPanel.textContent = `No active events. Next check in ${Math.max(0, Math.ceil(STATE.eventTimer))}s.`;
    eventAcceptBtn.disabled = true;
    eventDeclineBtn.disabled = true;
    eventAcceptBtn.textContent = "Accept";
    eventDeclineBtn.textContent = "Decline";
    return;
  }

  eventPanel.innerHTML = `<strong>${eventDef.title}</strong><div>${eventDef.body}</div>`;
  eventAcceptBtn.textContent = eventDef.acceptLabel || "Accept";
  eventDeclineBtn.textContent = eventDef.declineLabel || "Decline";
  const canAccept = eventDef.canAccept ? eventDef.canAccept() : true;
  eventAcceptBtn.disabled = !canAccept;
  eventDeclineBtn.disabled = false;
}

function resolveEvent(accepted) {
  const eventDef = getEventDefinition();
  if (!eventDef) return;

  if (accepted) {
    if (eventDef.canAccept && !eventDef.canAccept()) {
      setMessage("Cannot accept this event yet.");
      return;
    }
    eventDef.onAccept?.();
  } else {
    eventDef.onDecline?.();
  }

  STATE.activeEvent = null;
  renderEventPanel();
}

function renderResources() {
  RESOURCES.forEach((resource) => {
    const el = document.getElementById(`res-${resource.id}`);
    if (!el) return;
    const value = STATE.resources[resource.id] || 0;
    const cap = STATE.caps[resource.id] ?? 999999;
    const capText = cap >= 999999 ? "inf" : formatResourceValue(cap);
    el.textContent = `${resource.label}: ${formatResourceValue(value)}/${capText}`;
  });
}

function renderCityStats() {
  const current = getCurrentLevelEntry();
  const next = getNextLevelEntry();
  const passive = computePassiveStats();

  const buffText =
    STATE.buffs.length > 0
      ? STATE.buffs.map((buff) => `${buff.name} (${Math.ceil(buff.remaining)}s)`).join(", ")
      : "None";

  const lines = [
    `Level: ${STATE.cityLevel} (${current?.name || "-"})`,
    `Population: ${Math.floor(STATE.population)} / ${passive.popCap}`,
    `Happiness: ${STATE.happiness}`,
    `Prestige Stars: ${STATE.prestigeStars}`,
    `Production Boost: +${Math.round((getPrestigeProductionBonus() + getCityLevelProductionBonus()) * 100)}%`,
    `Active Buffs: ${buffText}`,
  ];

  if (next) {
    lines.push("Next level req:");
    lines.push(resourceToString(next.requirements));
  } else {
    lines.push("Max city level reached.");
  }

  infoPanel.innerHTML = lines.map((line) => `<div>${line}</div>`).join("");
  levelBtn.disabled = !canLevelUp();
  prestigeBtn.disabled = STATE.cityLevel < 7;
}

function buildLevelDescription(levelData) {
  const bits = [];
  if (levelData.produces) bits.push(`+ ${resourceToString(levelData.produces)}`);
  if (levelData.consumes) bits.push(`- ${resourceToString(levelData.consumes)}`);
  if (levelData.population) bits.push(`Population +${levelData.population}`);
  if (levelData.happiness) bits.push(`Happiness +${levelData.happiness}`);
  if (levelData.storage) bits.push(`Storage +${levelData.storage}`);
  if (levelData.interestPerMin) bits.push(`Interest ${Math.round(levelData.interestPerMin * 100)}%/min`);
  if (levelData.synergy?.auraFoodBoost) bits.push(`Food aura +${Math.round(levelData.synergy.auraFoodBoost * 100)}%`);
  if (levelData.synergy?.poweredBoost) bits.push(`Power aura +${Math.round(levelData.synergy.poweredBoost * 100)}%`);
  if (levelData.synergy?.upgradeDiscount) bits.push(`Upgrade discount aura ${Math.round(levelData.synergy.upgradeDiscount * 100)}%`);
  if (levelData.synergy?.residentialCoins) bits.push(`Residential coin boost ${Math.round(levelData.synergy.residentialCoins * 100)}%`);
  return bits;
}

function renderSelectedInfo() {
  const cell = getSelectedCell();
  if (!cell) {
    selectedInfo.textContent = "Click a building.";
    upgradeBtn.disabled = true;
    repairBtn.disabled = true;
    upgradeWindowBtn.disabled = true;
    return;
  }

  const data = BUILDINGS[cell.type];
  const levelData = getBuildingLevelData(cell);
  const next = getNextLevelData(cell);
  const lines = [
    `${data.label} (${levelData.stage})`,
    `Level: ${cell.level}/${data.levels.length}`,
    `Issue: ${cell.issue || "None"}`,
    `Output: ${resourceToString(levelData.produces)}`,
  ];

  if (levelData.consumes) lines.push(`Input: ${resourceToString(levelData.consumes)}`);
  if (levelData.population) lines.push(`Population +${levelData.population}`);
  if (levelData.happiness) lines.push(`Happiness +${levelData.happiness}`);

  if (next?.cost) {
    const discounted = getUpgradeCost(cell);
    lines.push(`Next cost: ${resourceToString(discounted)}`);
  }

  selectedInfo.innerHTML = lines.map((line) => `<div>${line}</div>`).join("");
  upgradeBtn.disabled = !canUpgradeSelected();
  repairBtn.disabled = !cell.issue || !hasResources(getRepairCost(cell));
  upgradeWindowBtn.disabled = false;
}

function renderUpgradeModal() {
  const cell = getSelectedCell();
  if (!cell) {
    upgradeSummary.innerHTML = "<div>Select a building to inspect upgrade tree.</div>";
    upgradeTree.innerHTML = "";
    upgradeFromModalBtn.disabled = true;
    return;
  }

  const data = BUILDINGS[cell.type];
  const levelData = getBuildingLevelData(cell);
  const discount = getUpgradeDiscount(STATE.selectedBuilding.x, STATE.selectedBuilding.y);

  upgradeSummary.innerHTML = [
    `<div><strong>${data.label}</strong> at (${STATE.selectedBuilding.x}, ${STATE.selectedBuilding.y})</div>`,
    `<div>Current stage: ${levelData.stage} (L${cell.level}/${data.levels.length})</div>`,
    `<div>Issue: ${cell.issue || "None"}</div>`,
    `<div>Upgrade discount nearby: ${Math.round(discount * 100)}%</div>`,
  ].join("");

  const nodes = data.levels
    .map((entry, idx) => {
      const level = idx + 1;
      const statusClass = level < cell.level ? "done" : level === cell.level ? "current" : "locked";
      const details = buildLevelDescription(entry)
        .map((line) => `<div>${line}</div>`)
        .join("");
      const cost = entry.cost ? `<div>Cost: ${resourceToString(entry.cost)}</div>` : "<div>Base level</div>";

      return `<div class="tree-node ${statusClass}"><div><strong>L${level} ${entry.stage}</strong></div>${cost}${details}</div>`;
    })
    .join("");

  upgradeTree.innerHTML = nodes;
  upgradeFromModalBtn.disabled = !canUpgradeSelected();
}

function openUpgradeModal() {
  const cell = getSelectedCell();
  if (!cell) {
    setMessage("Select a building first.");
    return;
  }
  renderUpgradeModal();
  upgradeModal.classList.remove("hidden");
}

function closeUpgradeModal() {
  upgradeModal.classList.add("hidden");
}

function renderBuildMenu() {
  buildList.innerHTML = "";
  const categories = ["Residential", "Production", "Commercial", "Culture", "Infrastructure", "Advanced"];
  const unlocked = Object.entries(BUILDINGS)
    .filter(([, data]) => data.unlockLevel <= STATE.cityLevel)
    .map(([id]) => id);

  STATE.quickSlots = [];

  categories.forEach((category) => {
    const title = document.createElement("div");
    title.textContent = category;
    title.style.fontWeight = "bold";
    title.style.marginTop = "8px";
    buildList.appendChild(title);

    Object.entries(BUILDINGS)
      .filter(([, data]) => data.category === category)
      .forEach(([id, data]) => {
        const item = document.createElement("div");
        item.className = "build-item";

        const button = document.createElement("button");
        button.textContent = data.label;
        button.disabled = !unlocked.includes(id);
        button.addEventListener("click", () => {
          STATE.selectedTool = id;
          renderBuildMenu();
        });
        if (STATE.selectedTool === id) {
          button.style.background = "#ffeaa2";
        }

        const meta = document.createElement("div");
        meta.className = "meta";
        meta.textContent = `Build: ${resourceToString(data.buildCost)}`;

        item.appendChild(button);
        item.appendChild(meta);
        buildList.appendChild(item);

        if (unlocked.includes(id) && STATE.quickSlots.length < 9) {
          STATE.quickSlots.push(id);
        }
      });
  });
}

function handleKeySelection(key) {
  const index = parseInt(key, 10);
  if (Number.isNaN(index) || index < 1 || index > 9) return false;
  const id = STATE.quickSlots[index - 1];
  if (!id) return false;
  STATE.selectedTool = id;
  renderBuildMenu();
  return true;
}

function resizeCanvas() {
  const availableWidth = Math.max(320, window.innerWidth - 560);
  const availableHeight = Math.max(360, window.innerHeight - 220);
  const scaleX = Math.floor(availableWidth / BASE_WIDTH);
  const scaleY = Math.floor(availableHeight / BASE_HEIGHT);
  renderScale = clamp(Math.min(scaleX, scaleY), 1, 4);
  canvas.width = BASE_WIDTH * renderScale;
  canvas.height = BASE_HEIGHT * renderScale;
}

function screenToPixel(event) {
  const rect = canvas.getBoundingClientRect();
  const x = (event.clientX - rect.left) / renderScale;
  const y = (event.clientY - rect.top) / renderScale;
  return { x, y };
}

function updateHover() {
  if (!mouse.inCanvas) {
    STATE.hover = { x: -1, y: -1, inGrid: false };
    return;
  }
  const tileX = Math.floor(mouse.x / TILE_SIZE);
  const tileY = Math.floor((mouse.y - UI_TOP) / TILE_SIZE);
  const inGrid = tileX >= 0 && tileX < GRID_SIZE && tileY >= 0 && tileY < GRID_SIZE;
  STATE.hover = { x: tileX, y: tileY, inGrid };
}

function drawBackground() {
  for (let y = 0; y < GRID_SIZE; y += 1) {
    for (let x = 0; x < GRID_SIZE; x += 1) {
      const shade = (x + y) % 2 === 0 ? "#7bbf5f" : "#74b657";
      pctx.fillStyle = shade;
      pctx.fillRect(x * TILE_SIZE, UI_TOP + y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
    }
  }

  pctx.fillStyle = "#2f2f2f";
  pctx.fillRect(0, 0, BASE_WIDTH, UI_TOP);
  pctx.fillRect(0, BASE_HEIGHT - UI_BOTTOM, BASE_WIDTH, UI_BOTTOM);
}

function drawHouseBlock(px, py, palette, level) {
  pctx.fillStyle = palette.shadow;
  pctx.fillRect(px + 1, py + 13, 14, 2);
  pctx.fillStyle = palette.body;
  pctx.fillRect(px + 2, py + 6, 12, 7);
  pctx.fillStyle = palette.roofDark;
  pctx.fillRect(px + 1, py + 5, 14, 2);
  pctx.fillStyle = palette.roof;
  pctx.fillRect(px + 2, py + 3, 12, 2);
  pctx.fillStyle = palette.door;
  pctx.fillRect(px + 7, py + 9, 2, 4);

  pctx.fillStyle = palette.window;
  pctx.fillRect(px + 4, py + 8, 2, 2);
  pctx.fillRect(px + 10, py + 8, 2, 2);

  if (level >= 2) {
    pctx.fillStyle = palette.trim;
    pctx.fillRect(px + 3, py + 11, 10, 1);
    pctx.fillRect(px + 3, py + 2, 10, 1);
  }
  if (level >= 3) {
    pctx.fillStyle = palette.window;
    pctx.fillRect(px + 6, py + 6, 4, 2);
  }
  if (level >= 4) {
    pctx.fillStyle = palette.tower;
    pctx.fillRect(px + 11, py + 5, 3, 6);
  }
  if (level >= 5) {
    pctx.fillStyle = palette.garden;
    pctx.fillRect(px + 1, py + 10, 3, 3);
  }
}

function drawIndustrialBlock(px, py, palette, level) {
  pctx.fillStyle = palette.floor;
  pctx.fillRect(px + 1, py + 13, 14, 2);
  pctx.fillStyle = palette.body;
  pctx.fillRect(px + 2, py + 6, 12, 7);
  pctx.fillStyle = palette.roof;
  pctx.fillRect(px + 2, py + 4, 12, 2);
  pctx.fillStyle = palette.panel;
  pctx.fillRect(px + 3, py + 8, 10, 3);

  if (level >= 2) {
    pctx.fillStyle = palette.pipe;
    pctx.fillRect(px + 11, py + 2, 2, 8);
  }
  if (level >= 3) {
    pctx.fillStyle = palette.glow;
    pctx.fillRect(px + 4, py + 9, 2, 2);
    pctx.fillRect(px + 8, py + 9, 2, 2);
  }
  if (level >= 4) {
    pctx.fillStyle = palette.pipe;
    pctx.fillRect(px + 3, py + 3, 2, 4);
  }
  if (level >= 5) {
    pctx.fillStyle = palette.glow;
    pctx.fillRect(px + 6, py + 5, 4, 1);
  }
}

function drawServiceBlock(px, py, palette, level) {
  pctx.fillStyle = palette.base;
  pctx.fillRect(px + 1, py + 13, 14, 2);
  pctx.fillStyle = palette.body;
  pctx.fillRect(px + 2, py + 6, 12, 7);
  pctx.fillStyle = palette.roof;
  pctx.fillRect(px + 2, py + 3, 12, 3);
  pctx.fillStyle = palette.detail;
  pctx.fillRect(px + 3, py + 8, 10, 2);

  if (level >= 2) {
    pctx.fillStyle = palette.window;
    pctx.fillRect(px + 4, py + 10, 2, 2);
    pctx.fillRect(px + 7, py + 10, 2, 2);
    pctx.fillRect(px + 10, py + 10, 2, 2);
  }
  if (level >= 3) {
    pctx.fillStyle = palette.badge;
    pctx.fillRect(px + 6, py + 4, 4, 2);
  }
  if (level >= 4) {
    pctx.fillStyle = palette.antenna;
    pctx.fillRect(px + 12, py + 1, 1, 4);
  }
  if (level >= 5) {
    pctx.fillStyle = palette.badge;
    pctx.fillRect(px + 2, py + 5, 2, 2);
  }
}

function drawFarm(px, py, level) {
  pctx.fillStyle = "#a8733c";
  pctx.fillRect(px + 1, py + 6, 14, 8);
  pctx.fillStyle = "#6eab39";
  pctx.fillRect(px + 2, py + 2, 12, 4);
  pctx.fillStyle = "#84c44a";
  pctx.fillRect(px + 3, py + 7, 10, 1);
  pctx.fillRect(px + 3, py + 10, 10, 1);
  if (level >= 2) {
    pctx.fillStyle = "#8b5b3a";
    pctx.fillRect(px + 11, py + 7, 3, 5);
  }
  if (level >= 3) {
    pctx.fillStyle = "#d7cda5";
    pctx.fillRect(px + 4, py + 9, 3, 3);
  }
  if (level >= 4) {
    pctx.fillStyle = "#69b9b1";
    pctx.fillRect(px + 7, py + 8, 3, 4);
  }
  if (level >= 5) {
    pctx.fillStyle = "#c6e8e5";
    pctx.fillRect(px + 1, py + 10, 3, 3);
  }
}

function drawPark(px, py, level) {
  pctx.fillStyle = "#4f8f3a";
  pctx.fillRect(px + 1, py + 2, 14, 12);
  pctx.fillStyle = "#2f6f2a";
  pctx.fillRect(px + 4, py + 4, 2, 6);
  pctx.fillRect(px + 10, py + 4, 2, 6);
  pctx.fillStyle = "#7dbb4e";
  pctx.fillRect(px + 2, py + 11, 12, 2);
  if (level >= 2) {
    pctx.fillStyle = "#b5651d";
    pctx.fillRect(px + 7, py + 8, 2, 5);
  }
  if (level >= 3) {
    pctx.fillStyle = "#d9d9d9";
    pctx.fillRect(px + 3, py + 11, 3, 3);
  }
  if (level >= 4) {
    pctx.fillStyle = "#f0d35c";
    pctx.fillRect(px + 11, py + 10, 3, 3);
  }
  if (level >= 5) {
    pctx.fillStyle = "#75d0ff";
    pctx.fillRect(px + 1, py + 9, 3, 4);
  }
}

function drawRoad(px, py, level, mask) {
  const shades = ["#6d655c", "#5d5d5d", "#4c5359", "#41484e", "#333a40"];
  const road = shades[Math.min(level - 1, shades.length - 1)];
  pctx.fillStyle = "#2f353a";
  pctx.fillRect(px, py, 16, 16);

  pctx.fillStyle = road;
  pctx.fillRect(px + 6, py + 6, 4, 4);

  if (mask & 1) pctx.fillRect(px + 6, py, 4, 10);
  if (mask & 2) pctx.fillRect(px + 6, py + 6, 10, 4);
  if (mask & 4) pctx.fillRect(px + 6, py + 6, 4, 10);
  if (mask & 8) pctx.fillRect(px, py + 6, 10, 4);

  if (mask === 0) {
    if (level % 2 === 0) pctx.fillRect(px + 2, py + 6, 12, 4);
    else pctx.fillRect(px + 6, py + 2, 4, 12);
  }

  pctx.fillStyle = "#d9d9d9";
  if ((mask & 1) && (mask & 4) && !(mask & 2) && !(mask & 8)) {
    pctx.fillRect(px + 7, py + 1, 2, 2);
    pctx.fillRect(px + 7, py + 13, 2, 2);
  } else if ((mask & 2) && (mask & 8) && !(mask & 1) && !(mask & 4)) {
    pctx.fillRect(px + 1, py + 7, 2, 2);
    pctx.fillRect(px + 13, py + 7, 2, 2);
  } else {
    pctx.fillRect(px + 7, py + 7, 2, 2);
  }
}

function drawBuildingSprite(cell, px, py, x, y) {
  switch (cell.type) {
    case "farm":
      drawFarm(px, py, cell.level);
      break;
    case "road":
      drawRoad(px, py, cell.level, getRoadMask(x, y));
      break;
    case "hut":
      drawHouseBlock(px, py, {
        shadow: "#9f8a70",
        body: "#d9c4a9",
        roof: "#b36a42",
        roofDark: "#844a2d",
        door: "#4f3d2b",
        window: "#f4efda",
        trim: "#6b8e23",
        tower: "#7e5936",
        garden: "#6ca445",
      }, cell.level);
      break;
    case "apartment":
      drawHouseBlock(px, py, {
        shadow: "#6f7884",
        body: "#a6afba",
        roof: "#6a7380",
        roofDark: "#48505c",
        door: "#2b2f37",
        window: "#d9ecff",
        trim: "#9ad0e6",
        tower: "#586978",
        garden: "#7fa7be",
      }, cell.level);
      break;
    case "lumber":
      drawIndustrialBlock(px, py, {
        floor: "#5e452e",
        body: "#8b5b3a",
        roof: "#4d3b2a",
        panel: "#a36f48",
        pipe: "#6b5b4a",
        glow: "#d7b46a",
      }, cell.level);
      break;
    case "quarry":
      drawIndustrialBlock(px, py, {
        floor: "#5b5b62",
        body: "#8d8d95",
        roof: "#6a6a72",
        panel: "#787881",
        pipe: "#4c4c53",
        glow: "#d2c7b1",
      }, cell.level);
      break;
    case "workshop":
      drawIndustrialBlock(px, py, {
        floor: "#77654f",
        body: "#bca77c",
        roof: "#7b4f2a",
        panel: "#8f7a5d",
        pipe: "#4e4a44",
        glow: "#d9d9d9",
      }, cell.level);
      break;
    case "foundry":
      drawIndustrialBlock(px, py, {
        floor: "#3f3f45",
        body: "#67676d",
        roof: "#3f3f44",
        panel: "#55555c",
        pipe: "#2b2b30",
        glow: "#f0b25b",
      }, cell.level);
      break;
    case "market":
      drawServiceBlock(px, py, {
        base: "#98603f",
        body: "#d97b4a",
        roof: "#f4efda",
        detail: "#ffe399",
        window: "#fff6cf",
        badge: "#ffd65c",
        antenna: "#8e5f2e",
      }, cell.level);
      break;
    case "bank":
      drawServiceBlock(px, py, {
        base: "#65707a",
        body: "#aab3bd",
        roof: "#5d6b78",
        detail: "#d8dee4",
        window: "#eef7ff",
        badge: "#ffd65c",
        antenna: "#3b4650",
      }, cell.level);
      break;
    case "library":
      drawServiceBlock(px, py, {
        base: "#7f6549",
        body: "#c9b28f",
        roof: "#7f5532",
        detail: "#ece2d1",
        window: "#f6f1e6",
        badge: "#8b9fab",
        antenna: "#5d7a8a",
      }, cell.level);
      break;
    case "theater":
      drawServiceBlock(px, py, {
        base: "#60384e",
        body: "#b47a8f",
        roof: "#6f3e55",
        detail: "#d9bfd0",
        window: "#f2dfeb",
        badge: "#f29f05",
        antenna: "#4f273a",
      }, cell.level);
      break;
    case "power":
      drawIndustrialBlock(px, py, {
        floor: "#4f4339",
        body: "#7b6f65",
        roof: "#524941",
        panel: "#64574d",
        pipe: "#2f2f2f",
        glow: "#f0c65f",
      }, cell.level);
      break;
    case "warehouse":
      drawIndustrialBlock(px, py, {
        floor: "#584b3f",
        body: "#7b6b5a",
        roof: "#bca77c",
        panel: "#94816e",
        pipe: "#4f5b66",
        glow: "#d9d9d9",
      }, cell.level);
      break;
    case "research":
      drawIndustrialBlock(px, py, {
        floor: "#4a5a5f",
        body: "#8ca2a8",
        roof: "#4f6470",
        panel: "#6f8a91",
        pipe: "#2f3f45",
        glow: "#7cc3ff",
      }, cell.level);
      break;
    case "wonder":
      drawServiceBlock(px, py, {
        base: "#746642",
        body: "#d8cfb0",
        roof: "#8b7a4a",
        detail: "#e6dfc6",
        window: "#f4efda",
        badge: "#ffd65c",
        antenna: "#9c5bd9",
      }, cell.level);
      break;
    case "park":
      drawPark(px, py, cell.level);
      break;
    default:
      pctx.fillStyle = "#2f2f2f";
      pctx.fillRect(px + 2, py + 2, 12, 12);
      break;
  }
}

function drawBuildings() {
  forEachBuilding((cell, x, y) => {
    const px = x * TILE_SIZE;
    const py = UI_TOP + y * TILE_SIZE;
    drawBuildingSprite(cell, px, py, x, y);
    if (cell.issue) {
      pctx.fillStyle = "#b5332a";
      pctx.fillRect(px + 11, py + 2, 3, 3);
    }
  });
}

function drawSelected() {
  if (!STATE.selectedBuilding) return;
  const cell = getSelectedCell();
  if (!cell) return;
  const { x, y } = STATE.selectedBuilding;
  const px = x * TILE_SIZE;
  const py = UI_TOP + y * TILE_SIZE;
  pctx.strokeStyle = "#3f7fd9";
  pctx.lineWidth = 1;
  pctx.strokeRect(px + 1.5, py + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
}

function drawHover() {
  if (!STATE.hover.inGrid || STATE.mode !== "play") return;
  const { x, y } = STATE.hover;
  const px = x * TILE_SIZE;
  const py = UI_TOP + y * TILE_SIZE;
  const cell = STATE.grid[y][x];

  pctx.strokeStyle = cell ? "#b5332a" : "#fff2b3";
  pctx.lineWidth = 1;
  pctx.strokeRect(px + 0.5, py + 0.5, TILE_SIZE - 1, TILE_SIZE - 1);

  if (!cell && STATE.selectedTool !== "bulldoze") {
    pctx.globalAlpha = 0.65;
    drawBuildingSprite({ type: STATE.selectedTool, level: 1 }, px, py, x, y);
    pctx.globalAlpha = 1;
  }
}

function drawTopBar() {
  pctx.fillStyle = "#f4efda";
  pctx.fillRect(0, 0, BASE_WIDTH, UI_TOP);
  pctx.fillStyle = "#2f2f2f";
  pctx.font = "10px Courier New, monospace";
  pctx.textBaseline = "middle";

  const leftText = `Lvl ${STATE.cityLevel} Pop ${Math.floor(STATE.population)} Happy ${STATE.happiness} Star ${STATE.prestigeStars}`;
  pctx.fillText(leftText, 6, UI_TOP / 2 + 0.5);

  if (STATE.message) {
    pctx.fillStyle = "#b5332a";
    pctx.fillText(STATE.message, 170, UI_TOP / 2 + 0.5);
  }
}

function drawBottomBar() {
  pctx.fillStyle = "#f4efda";
  pctx.fillRect(0, BASE_HEIGHT - UI_BOTTOM, BASE_WIDTH, UI_BOTTOM);
  pctx.fillStyle = "#2f2f2f";
  pctx.font = "10px Courier New, monospace";
  pctx.textBaseline = "middle";

  const toolLabel = STATE.selectedTool === "bulldoze" ? "Bulldoze" : BUILDINGS[STATE.selectedTool]?.label || "-";
  pctx.fillText(`Tool ${toolLabel}`, 6, BASE_HEIGHT - UI_BOTTOM / 2);

  if (STATE.activeEvent) {
    const def = getEventDefinition();
    if (def) {
      pctx.fillText(`Event: ${def.title}`, 150, BASE_HEIGHT - UI_BOTTOM / 2);
    }
  }
}

function drawMenu() {
  pctx.fillStyle = "#2f2f2f";
  pctx.fillRect(0, 0, BASE_WIDTH, BASE_HEIGHT);
  pctx.fillStyle = "#f4efda";
  pctx.font = "16px Courier New, monospace";
  pctx.textAlign = "center";
  pctx.textBaseline = "top";
  pctx.fillText("PIXEL CITY BUILDER", BASE_WIDTH / 2, 24);
  pctx.font = "10px Courier New, monospace";
  pctx.fillText("Build, upgrade, unlock level 7, prestige, and complete win conditions.", BASE_WIDTH / 2, 64);
  pctx.fillText("Use upgrade window for full level tree on selected buildings.", BASE_WIDTH / 2, 84);
  pctx.fillText("Press Enter or click Start City.", BASE_WIDTH / 2, 114);
  pctx.textAlign = "left";
}

function render() {
  pctx.clearRect(0, 0, BASE_WIDTH, BASE_HEIGHT);
  if (STATE.mode === "menu") {
    drawMenu();
  } else {
    drawBackground();
    drawBuildings();
    drawSelected();
    drawHover();
    drawTopBar();
    drawBottomBar();
  }

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(pixelCanvas, 0, 0, canvas.width, canvas.height);
}

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    canvas.requestFullscreen?.();
  } else {
    document.exitFullscreen?.();
  }
}

function startGame() {
  STATE.mode = "play";
  startBtn.classList.add("hidden");
}

function saveGame() {
  if (STATE.mode !== "play") return;
  const payload = {
    cityLevel: STATE.cityLevel,
    prestigeStars: STATE.prestigeStars,
    prestigeCount: STATE.prestigeCount,
    grid: STATE.grid,
    resources: STATE.resources,
    population: STATE.population,
    happiness: STATE.happiness,
    selectedTool: STATE.selectedTool,
    lastSavedAt: Date.now(),
  };
  localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
}

function applyOfflineProgress(seconds) {
  const capped = Math.min(seconds, MAX_OFFLINE_SECONDS);
  for (let i = 0; i < capped; i += 1) {
    tickSecond(false);
  }
  if (capped > 60) {
    setMessage(`Offline progress applied: ${Math.floor(capped / 60)} minutes.`);
  }
}

function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return;

  try {
    const payload = JSON.parse(raw);
    if (payload.cityLevel) STATE.cityLevel = payload.cityLevel;
    if (payload.prestigeStars) STATE.prestigeStars = payload.prestigeStars;
    if (payload.prestigeCount) STATE.prestigeCount = payload.prestigeCount;
    if (payload.grid) STATE.grid = payload.grid;
    if (payload.resources) STATE.resources = { ...createStartingResources(), ...payload.resources };
    if (payload.population) STATE.population = payload.population;
    if (payload.happiness) STATE.happiness = payload.happiness;
    if (payload.selectedTool) STATE.selectedTool = payload.selectedTool;

    if (payload.lastSavedAt) {
      const delta = Math.floor((Date.now() - payload.lastSavedAt) / 1000);
      if (delta > 15) applyOfflineProgress(delta);
    }
  } catch (error) {
    console.warn("Failed to parse save", error);
  }
}

function resetInvalidSelection() {
  if (!STATE.selectedBuilding) return;
  const cell = getSelectedCell();
  if (!cell) {
    STATE.selectedBuilding = null;
  }
}

canvas.addEventListener("mousemove", (event) => {
  const coords = screenToPixel(event);
  mouse.x = coords.x;
  mouse.y = coords.y;
  mouse.inCanvas = true;
  updateHover();
});

canvas.addEventListener("mouseleave", () => {
  mouse.inCanvas = false;
  updateHover();
});

canvas.addEventListener("mousedown", (event) => {
  if (STATE.mode === "menu") {
    startGame();
    return;
  }

  if (!STATE.hover.inGrid) return;

  if (event.button === 0) {
    const { x, y } = STATE.hover;
    const cell = STATE.grid[y][x];

    if (STATE.selectedTool === "bulldoze") {
      handleBuild("bulldoze");
      return;
    }

    if (cell) {
      setSelectedBuilding(x, y);
      return;
    }

    handleBuild(STATE.selectedTool);
  }

  if (event.button === 2) {
    handleBuild("bulldoze");
  }
});

canvas.addEventListener("contextmenu", (event) => {
  event.preventDefault();
});

startBtn.addEventListener("click", () => {
  startGame();
});

levelBtn.addEventListener("click", () => {
  levelUp();
});

prestigeBtn.addEventListener("click", () => {
  prestige();
});

upgradeBtn.addEventListener("click", () => {
  upgradeSelected();
});

repairBtn.addEventListener("click", () => {
  repairSelected();
});

upgradeWindowBtn.addEventListener("click", () => {
  openUpgradeModal();
});

upgradeFromModalBtn.addEventListener("click", () => {
  upgradeSelected();
});

closeUpgradeModalBtn.addEventListener("click", () => {
  closeUpgradeModal();
});

upgradeModal.addEventListener("click", (event) => {
  if (event.target === upgradeModal) {
    closeUpgradeModal();
  }
});

bulldozeBtn.addEventListener("click", () => {
  STATE.selectedTool = "bulldoze";
  renderBuildMenu();
});

eventAcceptBtn.addEventListener("click", () => {
  resolveEvent(true);
});

eventDeclineBtn.addEventListener("click", () => {
  resolveEvent(false);
});

window.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();

  if (event.key === "Enter" && STATE.mode === "menu") {
    startGame();
  }

  if (key === "f") toggleFullscreen();
  if (key === "b") {
    STATE.selectedTool = "bulldoze";
    renderBuildMenu();
  }
  if (key === "u") upgradeSelected();
  if (key === "r") repairSelected();
  if (key === "o") openUpgradeModal();
  if (key === "p") prestige();
  if (key === "escape") closeUpgradeModal();
  if (handleKeySelection(event.key)) return;
});

window.addEventListener("resize", resizeCanvas);
window.addEventListener("beforeunload", saveGame);

let lastTime = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - lastTime) / 1000);
  lastTime = now;

  update(dt);
  resetInvalidSelection();

  renderResources();
  renderCityStats();
  renderSelectedInfo();
  renderUpgradeModal();
  renderEventPanel();
  renderWinConditions();
  render();

  requestAnimationFrame(loop);
}

window.render_game_to_text = () => {
  const buildings = [];
  forEachBuilding((cell, x, y) => {
    buildings.push({
      x,
      y,
      type: cell.type,
      level: cell.level,
      issue: cell.issue,
      roadMask: cell.type === "road" ? getRoadMask(x, y) : null,
    });
  });

  const payload = {
    mode: STATE.mode,
    cityLevel: STATE.cityLevel,
    prestigeStars: STATE.prestigeStars,
    prestigeCount: STATE.prestigeCount,
    resources: STATE.resources,
    caps: STATE.caps,
    population: Math.floor(STATE.population),
    happiness: STATE.happiness,
    selectedTool: STATE.selectedTool,
    selectedBuilding: STATE.selectedBuilding,
    activeEvent: getEventDefinition()
      ? {
          id: getEventDefinition().id,
          title: getEventDefinition().title,
          body: getEventDefinition().body,
        }
      : null,
    winConditions: getWinConditionRows().map((row) => ({ text: row.text, done: row.done })),
    gridSize: { width: GRID_SIZE, height: GRID_SIZE },
    coordSystem: "origin top-left of build grid; x right, y down; tiles are 16px; UI top and bottom bars are outside grid",
    hover: STATE.hover.inGrid ? { x: STATE.hover.x, y: STATE.hover.y } : null,
    buildings,
  };

  return JSON.stringify(payload);
};

window.advanceTime = (ms) => {
  const steps = Math.max(1, Math.round(ms / (1000 / 60)));
  for (let i = 0; i < steps; i += 1) {
    update(1 / 60);
  }
  render();
};

buildResourceBar();
resizeCanvas();
loadGame();
updateCaps();
renderBuildMenu();
renderResources();
renderCityStats();
renderSelectedInfo();
renderUpgradeModal();
renderEventPanel();
renderWinConditions();
requestAnimationFrame(loop);
setInterval(saveGame, 5000);
