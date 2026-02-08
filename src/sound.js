// ── Sound Effects System (Web Audio API) ───────────────────────────
// Generates all sounds procedurally — no external files needed.

let audioCtx = null;
let masterGain = null;
let muted = false;

function ensureAudio() {
  if (audioCtx) return;
  audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  masterGain = audioCtx.createGain();
  masterGain.gain.value = 0.3;
  masterGain.connect(audioCtx.destination);
}

function playTone(freq, duration, type = "square", attack = 0.01, decay = 0.1) {
  if (muted) return;
  ensureAudio();
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0, audioCtx.currentTime);
  gain.gain.linearRampToValueAtTime(0.3, audioCtx.currentTime + attack);
  gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + duration);
  osc.connect(gain);
  gain.connect(masterGain);
  osc.start(audioCtx.currentTime);
  osc.stop(audioCtx.currentTime + duration);
}

function playNoise(duration, freq = 800) {
  if (muted) return;
  ensureAudio();
  const bufferSize = audioCtx.sampleRate * duration;
  const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) {
    data[i] = Math.random() * 2 - 1;
  }
  const source = audioCtx.createBufferSource();
  source.buffer = buffer;
  const filter = audioCtx.createBiquadFilter();
  filter.type = "lowpass";
  filter.frequency.value = freq;
  const gain = audioCtx.createGain();
  gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
  gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + duration);
  source.connect(filter);
  filter.connect(gain);
  gain.connect(masterGain);
  source.start();
}

export const SFX = {
  build() {
    playTone(220, 0.12, "square");
    setTimeout(() => playTone(330, 0.08, "square"), 60);
  },
  bulldoze() {
    playNoise(0.15, 400);
  },
  upgrade() {
    playTone(330, 0.1, "square");
    setTimeout(() => playTone(440, 0.1, "square"), 80);
    setTimeout(() => playTone(550, 0.15, "square"), 160);
  },
  repair() {
    playTone(280, 0.08, "triangle");
    setTimeout(() => playTone(380, 0.12, "triangle"), 70);
  },
  levelUp() {
    playTone(440, 0.15, "square");
    setTimeout(() => playTone(550, 0.15, "square"), 120);
    setTimeout(() => playTone(660, 0.15, "square"), 240);
    setTimeout(() => playTone(880, 0.25, "square"), 360);
  },
  prestige() {
    for (let i = 0; i < 6; i++) {
      setTimeout(() => playTone(440 + i * 110, 0.2, "sine"), i * 100);
    }
  },
  click() {
    playTone(600, 0.04, "square");
  },
  error() {
    playTone(200, 0.1, "sawtooth");
    setTimeout(() => playTone(150, 0.15, "sawtooth"), 80);
  },
  event() {
    playTone(500, 0.1, "triangle");
    setTimeout(() => playTone(600, 0.1, "triangle"), 100);
    setTimeout(() => playTone(500, 0.15, "triangle"), 200);
  },
  win() {
    const notes = [523, 659, 784, 1047];
    notes.forEach((n, i) => setTimeout(() => playTone(n, 0.3, "sine"), i * 150));
  },
};

export function toggleMute() {
  muted = !muted;
  return muted;
}

export function isMuted() { return muted; }

export function setVolume(v) {
  ensureAudio();
  masterGain.gain.value = Math.max(0, Math.min(1, v));
}
