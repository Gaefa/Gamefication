// ── Procedural Map Generation ──────────────────────────────────────
import { GRID_SIZE, TERRAIN } from "./config.js";

// Simple seeded PRNG (mulberry32)
function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 2D value noise
function createNoise2D(seed) {
  const rng = mulberry32(seed);
  const SIZE = 256;
  const perm = Array.from({ length: SIZE }, (_, i) => i);
  for (let i = SIZE - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [perm[i], perm[j]] = [perm[j], perm[i]];
  }
  const grad = Array.from({ length: SIZE }, () => rng() * 2 - 1);

  function fade(t) { return t * t * t * (t * (t * 6 - 15) + 10); }
  function lerp(a, b, t) { return a + t * (b - a); }

  return function noise(x, y) {
    const X = Math.floor(x) & 255;
    const Y = Math.floor(y) & 255;
    const xf = x - Math.floor(x);
    const yf = y - Math.floor(y);
    const u = fade(xf);
    const v = fade(yf);

    const aa = perm[(perm[X] + Y) & 255];
    const ab = perm[(perm[X] + Y + 1) & 255];
    const ba = perm[(perm[(X + 1) & 255] + Y) & 255];
    const bb = perm[(perm[(X + 1) & 255] + Y + 1) & 255];

    return lerp(
      lerp(grad[aa] * xf + grad[ab] * yf, grad[ba] * (xf - 1) + grad[bb] * yf, u),
      lerp(grad[aa] * xf + grad[ab] * (yf - 1), grad[ba] * (xf - 1) + grad[bb] * (yf - 1), u),
      v
    );
  };
}

function fbm(noise, x, y, octaves, lacunarity, gain) {
  let value = 0;
  let amplitude = 1;
  let frequency = 1;
  let max = 0;
  for (let i = 0; i < octaves; i++) {
    value += noise(x * frequency, y * frequency) * amplitude;
    max += amplitude;
    amplitude *= gain;
    frequency *= lacunarity;
  }
  return value / max;
}

export function generateTerrain(seed) {
  const rng = mulberry32(seed || (Date.now() ^ 0xdeadbeef));
  const actualSeed = Math.floor(rng() * 0xffffffff);

  const elevNoise = createNoise2D(actualSeed);
  const moistNoise = createNoise2D(actualSeed + 1337);
  const forestNoise = createNoise2D(actualSeed + 7777);

  const terrain = Array.from({ length: GRID_SIZE }, () =>
    Array.from({ length: GRID_SIZE }, () => TERRAIN.GRASS)
  );

  const cx = GRID_SIZE / 2;
  const cy = GRID_SIZE / 2;
  const maxDist = GRID_SIZE * 0.45;

  for (let y = 0; y < GRID_SIZE; y++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      const nx = x / GRID_SIZE;
      const ny = y / GRID_SIZE;

      const elev = fbm(elevNoise, nx * 4, ny * 4, 5, 2.0, 0.5);
      const moist = fbm(moistNoise, nx * 3 + 10, ny * 3 + 10, 4, 2.0, 0.5);
      const forest = fbm(forestNoise, nx * 6 + 20, ny * 6 + 20, 3, 2.0, 0.5);

      // island falloff
      const dx = (x - cx) / maxDist;
      const dy = (y - cy) / maxDist;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const falloff = Math.max(0, 1 - dist * dist);
      const h = elev * falloff;

      if (h < -0.1) {
        terrain[y][x] = TERRAIN.WATER;
      } else if (h < -0.02) {
        terrain[y][x] = TERRAIN.SAND;
      } else if (h > 0.35) {
        terrain[y][x] = TERRAIN.ROCK;
      } else if (h > 0.2) {
        terrain[y][x] = TERRAIN.HILL;
      } else if (forest > 0.15 && moist > -0.05 && h > 0.02) {
        terrain[y][x] = TERRAIN.FOREST;
      }
      // else GRASS (default)
    }
  }

  // Clear a starting area in the center
  const clearRadius = 6;
  for (let y = cy - clearRadius; y <= cy + clearRadius; y++) {
    for (let x = cx - clearRadius; x <= cx + clearRadius; x++) {
      if (x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE) {
        const dx = x - cx;
        const dy = y - cy;
        if (dx * dx + dy * dy <= clearRadius * clearRadius) {
          terrain[y][x] = TERRAIN.GRASS;
        }
      }
    }
  }

  return terrain;
}

export function canBuildOnTerrain(terrainType) {
  return terrainType !== TERRAIN.WATER;
}

export function getTerrainBuildCostMultiplier(terrainType) {
  switch (terrainType) {
    case TERRAIN.HILL: return 1.5;
    case TERRAIN.ROCK: return 2.0;
    case TERRAIN.FOREST: return 1.3;
    case TERRAIN.SAND: return 1.1;
    default: return 1.0;
  }
}
