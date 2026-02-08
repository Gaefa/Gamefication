// ── Configuration & Constants ──────────────────────────────────────
export const TILE_W = 32;
export const TILE_H = 16;
export const GRID_SIZE = 64;
export const HALF_W = TILE_W / 2;
export const HALF_H = TILE_H / 2;

export const SAVE_KEY = "pixel-city-builder-save";
export const MAX_OFFLINE_SECONDS = 4 * 60 * 60;
export const AUTOSAVE_INTERVAL = 5000;

export const TERRAIN = {
  GRASS: 0,
  WATER: 1,
  SAND: 2,
  HILL: 3,
  FOREST: 4,
  ROCK: 5,
};

export const TERRAIN_LABELS = {
  [TERRAIN.GRASS]: "Grass",
  [TERRAIN.WATER]: "Water",
  [TERRAIN.SAND]: "Sand",
  [TERRAIN.HILL]: "Hill",
  [TERRAIN.FOREST]: "Forest",
  [TERRAIN.ROCK]: "Rock",
};

export const RESOURCES = [
  { id: "wood", label: "Wood", icon: "W" },
  { id: "stone", label: "Stone", icon: "S" },
  { id: "food", label: "Food", icon: "F" },
  { id: "coins", label: "Coins", icon: "$" },
  { id: "planks", label: "Planks", icon: "P" },
  { id: "bricks", label: "Bricks", icon: "B" },
  { id: "tools", label: "Tools", icon: "T" },
  { id: "cloth", label: "Cloth", icon: "C" },
  { id: "metal", label: "Metal", icon: "M" },
  { id: "glass", label: "Glass", icon: "G" },
  { id: "energy", label: "Energy", icon: "E" },
  { id: "science", label: "Science", icon: "R" },
  { id: "culture", label: "Culture", icon: "A" },
  { id: "fame", label: "Fame", icon: "!" },
  { id: "water_res", label: "Water Supply", icon: "~" },
];

export const BUILDINGS = {
  hut: {
    label: "Hut",
    category: "Residential",
    unlockLevel: 1,
    buildCost: { wood: 25, stone: 10 },
    requiresRoad: true,
    levels: [
      { stage: "Hut", produces: { coins: 0.5 }, consumes: { food: 0.5 }, population: 2, happiness: 1 },
      { stage: "House", cost: { coins: 50, planks: 40, bricks: 30 }, produces: { coins: 1 }, consumes: { food: 0.6 }, population: 5, happiness: 2 },
      { stage: "Cottage", cost: { coins: 150, planks: 80, bricks: 60, cloth: 30 }, produces: { coins: 2 }, consumes: { food: 0.7 }, population: 10, happiness: 5 },
      { stage: "Mansion", cost: { coins: 400, bricks: 100, metal: 80, glass: 50 }, produces: { coins: 5 }, consumes: { food: 0.9 }, population: 20, happiness: 12 },
      { stage: "Villa", cost: { coins: 1000, metal: 200, glass: 150, energy: 100 }, produces: { coins: 12, culture: 0.5 }, consumes: { food: 1 }, population: 35, happiness: 24 },
    ],
  },
  apartment: {
    label: "Apartment",
    category: "Residential",
    unlockLevel: 4,
    buildCost: { coins: 200, bricks: 100, metal: 80 },
    requiresRoad: true,
    levels: [
      { stage: "Low-rise", produces: { coins: 1 }, consumes: { food: 2, energy: 0.5 }, population: 15, happiness: 3 },
      { stage: "Tower", cost: { coins: 400, metal: 150, glass: 100 }, produces: { coins: 2 }, consumes: { food: 2.5, energy: 0.8 }, population: 30, happiness: 4 },
      { stage: "Complex", cost: { coins: 800, metal: 250, glass: 200, energy: 150 }, produces: { coins: 4 }, consumes: { food: 3.5, energy: 1.2 }, population: 50, happiness: 6 },
      { stage: "Skyblock", cost: { coins: 1600, metal: 400, glass: 300, energy: 250 }, produces: { coins: 8 }, consumes: { food: 4.5, energy: 1.8 }, population: 80, happiness: 8 },
      { stage: "Megablock", cost: { coins: 3200, metal: 600, energy: 500, science: 100 }, produces: { coins: 15 }, consumes: { food: 5.5, energy: 2.6 }, population: 120, happiness: 12 },
    ],
  },
  farm: {
    label: "Farm",
    category: "Production",
    unlockLevel: 1,
    buildCost: { wood: 10 },
    requiresRoad: false,
    terrainBonus: { [TERRAIN.GRASS]: 0.2, [TERRAIN.SAND]: -0.1 },
    levels: [
      { stage: "Field", produces: { food: 2 } },
      { stage: "Barn Farm", cost: { coins: 50, wood: 20 }, produces: { food: 3 } },
      { stage: "Mill Farm", cost: { coins: 100, planks: 30, stone: 20 }, produces: { food: 5 }, synergy: { auraFoodBoost: 0.05, radius: 3 } },
      { stage: "Greenhouse", cost: { coins: 200, bricks: 50, tools: 30 }, produces: { food: 8 }, synergy: { auraFoodBoost: 0.07, radius: 3 } },
      { stage: "Hydro Farm", cost: { coins: 500, metal: 100, glass: 50 }, produces: { food: 15 }, synergy: { auraFoodBoost: 0.1, radius: 4, autoSellFood: true } },
    ],
  },
  lumber: {
    label: "Lumber Mill",
    category: "Production",
    unlockLevel: 1,
    buildCost: { coins: 15 },
    requiresRoad: false,
    terrainBonus: { [TERRAIN.FOREST]: 0.5 },
    levels: [
      { stage: "Yard", produces: { wood: 1 } },
      { stage: "Saw Mill", cost: { coins: 40, wood: 30 }, produces: { wood: 2, planks: 0.5 }, synergy: { farmAdjBoost: 0.1 } },
      { stage: "Timber Plant", cost: { coins: 80, planks: 50, stone: 30 }, produces: { wood: 3, planks: 1 }, synergy: { farmAdjBoost: 0.12 } },
      { stage: "Industrial Lumber", cost: { coins: 150, bricks: 40, tools: 20 }, produces: { wood: 5, planks: 2 }, synergy: { farmAdjBoost: 0.14 } },
      { stage: "Auto Forestry", cost: { coins: 400, metal: 80 }, produces: { wood: 8, planks: 4 }, synergy: { farmAdjBoost: 0.15 } },
    ],
  },
  quarry: {
    label: "Quarry",
    category: "Production",
    unlockLevel: 1,
    buildCost: { coins: 20, wood: 10 },
    requiresRoad: false,
    terrainBonus: { [TERRAIN.ROCK]: 0.4, [TERRAIN.HILL]: 0.2 },
    levels: [
      { stage: "Pit", produces: { stone: 1 } },
      { stage: "Stone Yard", cost: { coins: 60, wood: 40 }, produces: { stone: 2, bricks: 0.3 } },
      { stage: "Brickworks", cost: { coins: 120, planks: 60, food: 40 }, produces: { stone: 3, bricks: 0.8 } },
      { stage: "Deep Quarry", cost: { coins: 250, bricks: 50, tools: 30 }, produces: { stone: 5, bricks: 1.5 } },
      { stage: "Mega Quarry", cost: { coins: 600, metal: 100, energy: 50 }, produces: { stone: 10, bricks: 3, glass: 0.2 } },
    ],
  },
  workshop: {
    label: "Workshop",
    category: "Production",
    unlockLevel: 2,
    buildCost: { coins: 50, wood: 30, stone: 20 },
    requiresRoad: true,
    levels: [
      { stage: "Craft Shed", produces: { tools: 0.5 }, consumes: { wood: 1, stone: 0.5 } },
      { stage: "Tool House", cost: { coins: 100, planks: 40, bricks: 30 }, produces: { tools: 1 }, consumes: { wood: 1.2, stone: 0.6 }, synergy: { upgradeDiscount: 0.1, radius: 3 } },
      { stage: "Mechanic Hall", cost: { coins: 200, planks: 60, bricks: 40, tools: 20 }, produces: { tools: 2, cloth: 1 }, consumes: { wood: 1.5, stone: 0.8 }, synergy: { upgradeDiscount: 0.12, radius: 3 } },
      { stage: "Automation Yard", cost: { coins: 400, metal: 80, tools: 40 }, produces: { tools: 4, cloth: 2 }, consumes: { wood: 1.8, stone: 1 }, synergy: { upgradeDiscount: 0.14, radius: 4 } },
      { stage: "Nano Workshop", cost: { coins: 800, metal: 150, glass: 80 }, produces: { tools: 8, cloth: 3 }, consumes: { wood: 2, stone: 1.2 }, synergy: { upgradeDiscount: 0.16, radius: 4 } },
    ],
  },
  foundry: {
    label: "Foundry",
    category: "Production",
    unlockLevel: 3,
    buildCost: { coins: 150, bricks: 80, tools: 40 },
    requiresRoad: true,
    levels: [
      { stage: "Smelter", produces: { metal: 0.3 }, consumes: { stone: 2, tools: 0.3 } },
      { stage: "Furnace", cost: { coins: 300, bricks: 100, tools: 60 }, produces: { metal: 0.8 }, consumes: { stone: 2.4, tools: 0.4 } },
      { stage: "Refinery", cost: { coins: 600, metal: 80, cloth: 40 }, produces: { metal: 1.5, glass: 0.5 }, consumes: { stone: 2.8, energy: 0.3 } },
      { stage: "Steel Plant", cost: { coins: 1200, metal: 150, glass: 100 }, produces: { metal: 3, glass: 1.2 }, consumes: { stone: 3.2, energy: 0.6 } },
      { stage: "Fusion Forge", cost: { coins: 2500, metal: 300, energy: 200 }, produces: { metal: 6, glass: 3 }, consumes: { stone: 4, energy: 1.2 } },
    ],
  },
  market: {
    label: "Market",
    category: "Commercial",
    unlockLevel: 2,
    buildCost: { coins: 80, planks: 50, bricks: 30 },
    requiresRoad: true,
    levels: [
      { stage: "Bazaar", produces: { coins: 2 }, synergy: { residentialCoins: 0.15 } },
      { stage: "Town Market", cost: { coins: 160, planks: 80, bricks: 60 }, produces: { coins: 4 }, synergy: { residentialCoins: 0.2 } },
      { stage: "Trade Hall", cost: { coins: 320, metal: 100, glass: 80 }, produces: { coins: 7 }, synergy: { residentialCoins: 0.3 } },
      { stage: "Grand Exchange", cost: { coins: 640, metal: 200, glass: 150 }, produces: { coins: 12 }, synergy: { residentialCoins: 0.4 } },
      { stage: "Global Market", cost: { coins: 1280, metal: 300, glass: 250, energy: 100 }, produces: { coins: 20 }, synergy: { residentialCoins: 0.5 } },
    ],
  },
  bank: {
    label: "Bank",
    category: "Commercial",
    unlockLevel: 5,
    buildCost: { coins: 500, bricks: 150, metal: 100, glass: 80 },
    requiresRoad: true,
    levels: [
      { stage: "Credit Office", produces: { coins: 5 }, interestPerMin: 0.02 },
      { stage: "Regional Bank", cost: { coins: 1000, metal: 200, glass: 150 }, produces: { coins: 10 }, interestPerMin: 0.03 },
      { stage: "National Bank", cost: { coins: 2000, metal: 350, glass: 250, energy: 200 }, produces: { coins: 18 }, interestPerMin: 0.05 },
      { stage: "Central Reserve", cost: { coins: 4000, metal: 500, energy: 400, science: 150 }, produces: { coins: 30 }, interestPerMin: 0.08 },
      { stage: "Hyperbank", cost: { coins: 8000, metal: 800, energy: 600, science: 300 }, produces: { coins: 50 }, interestPerMin: 0.12 },
    ],
  },
  park: {
    label: "Park",
    category: "Culture",
    unlockLevel: 3,
    buildCost: { coins: 100, planks: 60, food: 40 },
    requiresRoad: false,
    levels: [
      { stage: "Park", produces: { culture: 0.5 }, happiness: 10, synergy: { happinessAura: 0.15, radius: 4 } },
      { stage: "City Garden", cost: { coins: 200, planks: 100, cloth: 60 }, produces: { culture: 1 }, happiness: 20, synergy: { happinessAura: 0.2, radius: 4 } },
      { stage: "Recreation Zone", cost: { coins: 400, bricks: 150, cloth: 100, metal: 80 }, produces: { culture: 2 }, happiness: 35, synergy: { happinessAura: 0.25, radius: 5 } },
      { stage: "Grand Park", cost: { coins: 800, metal: 200, glass: 150, energy: 100 }, produces: { culture: 4 }, happiness: 55, synergy: { happinessAura: 0.3, radius: 5 } },
      { stage: "National Park", cost: { coins: 1600, glass: 300, energy: 250, science: 100 }, produces: { culture: 7 }, happiness: 80, synergy: { happinessAura: 0.35, radius: 6 } },
    ],
  },
  library: {
    label: "Library",
    category: "Culture",
    unlockLevel: 4,
    buildCost: { coins: 250, planks: 150, bricks: 100 },
    requiresRoad: true,
    levels: [
      { stage: "Library", produces: { science: 0.5, culture: 1 } },
      { stage: "Research Library", cost: { coins: 500, bricks: 200, cloth: 150 }, produces: { science: 1.2, culture: 2 } },
      { stage: "Academy", cost: { coins: 1000, metal: 250, glass: 200, cloth: 150 }, produces: { science: 2.5, culture: 4 } },
      { stage: "Knowledge Hub", cost: { coins: 2000, metal: 400, glass: 350, energy: 250 }, produces: { science: 5, culture: 7 } },
      { stage: "Archive Nexus", cost: { coins: 4000, metal: 600, energy: 500, science: 200 }, produces: { science: 10, culture: 12 } },
    ],
  },
  theater: {
    label: "Theater",
    category: "Culture",
    unlockLevel: 5,
    buildCost: { coins: 400, bricks: 200, cloth: 150, glass: 100 },
    requiresRoad: true,
    levels: [
      { stage: "Theater", produces: { culture: 3, fame: 0.3 }, happiness: 25 },
      { stage: "Opera Hall", cost: { coins: 800, metal: 300, glass: 200 }, produces: { culture: 6, fame: 0.6 }, happiness: 40 },
      { stage: "Arts Center", cost: { coins: 1600, metal: 500, glass: 400, energy: 300 }, produces: { culture: 10, fame: 1 }, happiness: 60 },
      { stage: "Grand Theater", cost: { coins: 3200, energy: 800, science: 300 }, produces: { culture: 18, fame: 2 }, happiness: 90 },
      { stage: "Cultural Capital", cost: { coins: 6400, energy: 1200, science: 600, fame: 200 }, produces: { culture: 30, fame: 4 }, happiness: 130 },
    ],
  },
  power: {
    label: "Power Plant",
    category: "Infrastructure",
    unlockLevel: 4,
    buildCost: { coins: 300, bricks: 150, metal: 100 },
    requiresRoad: true,
    networkType: "power",
    levels: [
      { stage: "Plant", produces: { energy: 2 }, consumes: { stone: 1, metal: 0.5 } },
      { stage: "Grid Plant", cost: { coins: 600, metal: 250, tools: 150 }, produces: { energy: 4 }, consumes: { stone: 1.2, metal: 0.6 }, synergy: { poweredBoost: 0.1, radius: 6 } },
      { stage: "Solar Station", cost: { coins: 1200, metal: 400, glass: 300 }, produces: { energy: 7 }, synergy: { poweredBoost: 0.12, radius: 7 } },
      { stage: "Fusion Plant", cost: { coins: 2400, metal: 600, glass: 500, science: 200 }, produces: { energy: 12 }, synergy: { poweredBoost: 0.15, radius: 8 } },
      { stage: "Reactor", cost: { coins: 4800, metal: 1000, energy: 800, science: 400 }, produces: { energy: 20 }, synergy: { poweredBoost: 0.2, radius: 10 } },
    ],
  },
  water_tower: {
    label: "Water Tower",
    category: "Infrastructure",
    unlockLevel: 2,
    buildCost: { coins: 60, stone: 40, wood: 20 },
    requiresRoad: false,
    networkType: "water",
    levels: [
      { stage: "Well", produces: { water_res: 3 }, synergy: { waterRadius: 4 } },
      { stage: "Cistern", cost: { coins: 120, bricks: 60, tools: 20 }, produces: { water_res: 6 }, synergy: { waterRadius: 6 } },
      { stage: "Tower", cost: { coins: 300, metal: 100, bricks: 80 }, produces: { water_res: 12 }, synergy: { waterRadius: 8 } },
      { stage: "Treatment Plant", cost: { coins: 700, metal: 200, glass: 100, energy: 50 }, produces: { water_res: 20 }, synergy: { waterRadius: 10 } },
      { stage: "Purification Hub", cost: { coins: 1500, metal: 400, energy: 200, science: 80 }, produces: { water_res: 35 }, synergy: { waterRadius: 14 } },
    ],
  },
  road: {
    label: "Road",
    category: "Infrastructure",
    unlockLevel: 1,
    buildCost: { coins: 5, stone: 3 },
    requiresRoad: false,
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
    requiresRoad: true,
    levels: [
      { stage: "Storage", storage: 1000 },
      { stage: "Depot", cost: { coins: 300, planks: 150, metal: 120 }, storage: 2500 },
      { stage: "Mega Depot", cost: { coins: 600, metal: 200, glass: 150 }, storage: 5000 },
      { stage: "Logistics Hub", cost: { coins: 1200, metal: 350, energy: 250 }, storage: 10000 },
      { stage: "Quantum Storage", cost: { coins: 2400, metal: 500, energy: 400, science: 150 }, storage: 20000 },
    ],
  },
  research: {
    label: "Research Center",
    category: "Advanced",
    unlockLevel: 6,
    buildCost: { coins: 3000, metal: 700, glass: 500, energy: 400 },
    requiresRoad: true,
    levels: [
      { stage: "Lab", produces: { science: 15, fame: 0.5 }, consumes: { energy: 2 } },
      { stage: "Institute", cost: { coins: 6000, metal: 900, energy: 700, science: 300 }, produces: { science: 25, fame: 1 }, consumes: { energy: 3 } },
      { stage: "Innovation Core", cost: { coins: 12000, metal: 1400, energy: 1200, science: 800 }, produces: { science: 40, fame: 2 }, consumes: { energy: 4 } },
    ],
  },
  wonder: {
    label: "Wonder",
    category: "Advanced",
    unlockLevel: 6,
    buildCost: { coins: 8000, metal: 1500, glass: 900, culture: 400 },
    requiresRoad: true,
    levels: [
      { stage: "Wonder", produces: { fame: 3, culture: 10 }, happiness: 150 },
      { stage: "Grand Wonder", cost: { coins: 16000, energy: 1500, science: 800, fame: 400 }, produces: { fame: 6, culture: 20 }, happiness: 220 },
      { stage: "World Wonder", cost: { coins: 30000, energy: 2500, science: 1600, fame: 900 }, produces: { fame: 12, culture: 35 }, happiness: 320 },
    ],
  },
};

export const CITY_LEVELS = [
  { level: 1, name: "Settlement", requirements: null, reward: { coins: 100 } },
  { level: 2, name: "Village", requirements: { food: 100, wood: 150, stone: 100, coins: 50 }, reward: { coins: 250, planks: 50 } },
  { level: 3, name: "Town", requirements: { food: 500, planks: 300, bricks: 250, tools: 100, coins: 500 }, reward: { coins: 1000, metal: 100 } },
  { level: 4, name: "Large City", requirements: { food: 1000, metal: 500, glass: 400, tools: 200, coins: 2000 }, reward: { coins: 3000, energy: 300, science: 50 } },
  { level: 5, name: "Metropolis", requirements: { food: 2000, metal: 1000, energy: 800, science: 300, coins: 5000 }, reward: { coins: 10000, energy: 500, science: 200, fame: 100 } },
  { level: 6, name: "Megapolis", requirements: { food: 5000, metal: 2500, energy: 2000, science: 1000, culture: 500, coins: 20000 }, reward: { coins: 50000, fame: 500 } },
  { level: 7, name: "Futuristic City", requirements: { wood: 10000, stone: 10000, food: 10000, coins: 100000, energy: 5000, science: 3000, culture: 1500, fame: 500 }, reward: { fame: 1000, science: 500 } },
];

export const CATEGORIES = ["Residential", "Production", "Commercial", "Culture", "Infrastructure", "Advanced"];
