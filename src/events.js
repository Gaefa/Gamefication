// ── Events System ──────────────────────────────────────────────────
import { STATE } from "./state.js";
import { addResources, hasResources, spendResources, setMessage, forceIssues } from "./economy.js";

export const EVENT_DEFS = [
  {
    id: "wanderer",
    minLevel: 1,
    title: "Wandering Trader",
    body: "A wandering trader offers a small supply of materials.",
    acceptLabel: "Trade",
    declineLabel: "Pass",
    onAccept: () => { addResources({ wood: 30, stone: 20, food: 15 }); setMessage("Trader left some supplies."); },
    onDecline: () => { setMessage("Trader wandered away."); },
  },
  {
    id: "settlers",
    minLevel: 1,
    title: "Settlers Arrive",
    body: "A group of settlers wants to join your settlement. Accept for extra coins!",
    acceptLabel: "Welcome!",
    declineLabel: "Turn Away",
    onAccept: () => { addResources({ coins: 80 }); setMessage("Settlers brought some coins."); },
    onDecline: () => { setMessage("Settlers moved on."); },
  },
  {
    id: "caravan",
    minLevel: 2,
    title: "Trade Caravan",
    body: "A caravan offers supplies for cash flow.",
    acceptLabel: "Take Deal",
    declineLabel: "Ignore",
    onAccept: () => { addResources({ coins: 400, wood: 120, stone: 120 }); setMessage("Caravan delivered resources."); },
    onDecline: () => { setMessage("Caravan moved on."); },
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
      STATE.buffs.push({ id: "festival-buff", name: "Festival", remaining: 180, productionMult: 0.2, happinessAdd: 15 });
      setMessage("Festival started.");
    },
    onDecline: () => { STATE.happinessPenaltyTicks += 60; setMessage("Citizens are disappointed."); },
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
      STATE.buffs.push({ id: "storm-shield", name: "Protected Grid", remaining: 120, productionMult: 0.1, happinessAdd: 5 });
      setMessage("Storm defenses active.");
    },
    onDecline: () => { forceIssues(6); addResources({ wood: -100, stone: -100, food: -80 }); setMessage("Storm caused damage."); },
  },
  {
    id: "innovation",
    minLevel: 5,
    title: "Innovation Grant",
    body: "A grant can accelerate high-tech growth.",
    acceptLabel: "Accept Grant",
    declineLabel: "Pass",
    onAccept: () => { addResources({ science: 180, energy: 200, coins: 600 }); setMessage("Grant applied to city labs."); },
    onDecline: () => { setMessage("Grant was offered elsewhere."); },
  },
  {
    id: "drought",
    minLevel: 3,
    title: "Drought",
    body: "Water supply is dwindling. Invest in reserves or farms suffer.",
    acceptLabel: "Emergency Supply",
    declineLabel: "Wait It Out",
    canAccept: () => hasResources({ coins: 200, water_res: 10 }),
    onAccept: () => {
      spendResources({ coins: 200 });
      STATE.buffs.push({ id: "drought-shield", name: "Water Reserves", remaining: 90, productionMult: 0.05, happinessAdd: 3 });
      setMessage("Emergency water distributed.");
    },
    onDecline: () => {
      STATE.buffs.push({ id: "drought-debuff", name: "Drought", remaining: 120, productionMult: -0.15 });
      setMessage("Farms are suffering from drought.");
    },
  },
];

export function getEventDefinition() {
  if (!STATE.activeEvent) return null;
  return EVENT_DEFS.find(e => e.id === STATE.activeEvent.id) || null;
}

export function processEventsTick() {
  STATE.eventTimer -= 1;
  if (STATE.activeEvent || STATE.eventTimer > 0 || STATE.mode !== "play") return;
  const pool = EVENT_DEFS.filter(e => e.minLevel <= STATE.cityLevel);
  if (!pool.length) { STATE.eventTimer = 60; return; }
  STATE.activeEvent = { id: pool[Math.floor(Math.random() * pool.length)].id };
  STATE.eventTimer = 90 + Math.floor(Math.random() * 60);
}

export function resolveEvent(accepted) {
  const def = getEventDefinition();
  if (!def) return;
  if (accepted) {
    if (def.canAccept && !def.canAccept()) { setMessage("Cannot accept this event yet."); return; }
    def.onAccept?.();
  } else {
    def.onDecline?.();
  }
  STATE.activeEvent = null;
}
