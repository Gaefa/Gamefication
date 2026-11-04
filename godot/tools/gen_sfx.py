#!/usr/bin/env python3
"""Procedural sound pack for Mandate Cities. Run from the repo root:
    python3 godot/tools/gen_sfx.py
Writes 16-bit mono WAVs into godot/assets/audio/. No dependencies beyond the standard
library, so the pack is reproducible by anyone; tweak a number here, not the WAVs.
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples, peak_to=0.9):
    """Every clip is normalised to the same peak so one slider fits them all; the wind sits
    lower because it plays all the time."""
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = peak_to / peak
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data)
    print("%-16s %5.2f s" % (name, len(samples) / RATE))


def env(i, n, attack=0.005, decay=None, curve=4.0):
    """Attack in seconds, then an exponential decay over the rest of the sound."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-curve * i / n) if decay is None else math.exp(-t / decay)
    return a * d


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff); dt = 1.0 / RATE; alpha = dt / (rc + dt)
    out = []; y = 0.0
    for s in samples:
        y += alpha * (s - y); out.append(y)
    return out


def highpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff); dt = 1.0 / RATE; alpha = rc / (rc + dt)
    out = []; y = 0.0; prev = 0.0
    for s in samples:
        y = alpha * (y + s - prev); prev = s; out.append(y)
    return out


def noise(n, seed):
    rnd = random.Random(seed)
    return [rnd.uniform(-1.0, 1.0) for _ in range(n)]


def tone(n, freq, harmonics=((1, 1.0),), glide=1.0):
    out = []; phase = 0.0
    for i in range(n):
        f = freq * (1.0 + (glide - 1.0) * i / n)
        phase += 2 * math.pi * f / RATE
        out.append(sum(a * math.sin(phase * h) for h, a in harmonics))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    return [sum(l[i] if i < len(l) else 0.0 for l in layers) for i in range(n)]


def scaled(samples, k):
    return [s * k for s in samples]


def shaped(samples, **kw):
    n = len(samples)
    return [s * env(i, n, **kw) for i, s in enumerate(samples)]


# --- UI -------------------------------------------------------------------------------
n = int(0.045 * RATE)
write("ui_click", shaped(mix(scaled(highpass(noise(n, 1), 2500), 0.5), scaled(tone(n, 1900), 0.4)), attack=0.001, curve=9), 0.5)
n = int(0.16 * RATE)
write("ui_open", shaped(scaled(lowpass(highpass(noise(n, 2), 600), 2400), 0.8), attack=0.03, curve=5))
write("ui_close", list(reversed(shaped(scaled(lowpass(highpass(noise(n, 3), 500), 1800), 0.8), attack=0.03, curve=5))))

# --- the Desk: paper and a stamp -----------------------------------------------------
n = int(0.32 * RATE)
rustle = lowpass(highpass(noise(n, 4), 900), 4000)
rustle = [s * (0.6 + 0.4 * math.sin(i / RATE * 23.0)) for i, s in enumerate(rustle)]
write("letter_open", shaped(rustle, attack=0.02, curve=3.5))
n = int(0.14 * RATE)
write("stamp", shaped(mix(scaled(tone(n, 140, glide=0.5), 0.9), scaled(lowpass(noise(n, 5), 1200), 0.5)), attack=0.002, curve=7))

# --- the map ---------------------------------------------------------------------------
n = int(0.22 * RATE)
write("build_place", shaped(mix(scaled(tone(n, 95, glide=0.45), 1.0), scaled(lowpass(noise(n, 6), 900), 0.45)), attack=0.003, curve=6))
n = int(0.5 * RATE)
write("demolish", shaped(scaled(lowpass(noise(n, 7), 350), 1.0), attack=0.01, curve=4))
n = int(0.26 * RATE)
clank = mix(scaled(tone(n, 1240, ((1, 1.0), (2.7, 0.4))), 0.7), scaled(highpass(noise(n, 8), 3000), 0.2))
clank = shaped(clank, attack=0.001, curve=10)
gap = [0.0] * int(0.11 * RATE)
write("repair", clank + gap + scaled(clank, 0.8))
n = int(0.14 * RATE)
write("build_fail", shaped(mix(scaled(tone(n, 220), 0.5), scaled(tone(n, 233), 0.5)), attack=0.004, curve=5))
n = int(0.12 * RATE)
write("issue", shaped(mix(scaled(tone(n, 880), 0.5), scaled(highpass(noise(n, 9), 2000), 0.25)), attack=0.002, curve=8))

# --- the day --------------------------------------------------------------------------
def bell(freq, seconds, seed):
    n = int(seconds * RATE)
    return shaped(tone(n, freq, ((1, 1.0), (2.0, 0.35), (3.01, 0.18), (4.2, 0.08))), attack=0.004, decay=seconds / 3.2)

write("day_start", mix(bell(523.25, 0.9, 10), [0.0] * int(0.18 * RATE) + bell(784.0, 0.9, 11)), 0.7)
write("evening_bell", bell(392.0, 1.6, 12), 0.7)
write("alarm", mix(bell(660.0, 0.35, 13), [0.0] * int(0.22 * RATE) + bell(880.0, 0.5, 14)))
write("ending", mix(bell(261.6, 2.2, 15), [0.0] * int(0.3 * RATE) + bell(329.6, 2.0, 16), [0.0] * int(0.6 * RATE) + bell(392.0, 2.0, 17)), 0.75)

# --- ambient wind loops, one per season (seamless: the tail is crossfaded into the head)
def wind(seconds, seed, cutoff, gust_rate, gust_depth, whistle):
    n = int(seconds * RATE)
    base = lowpass(noise(n, seed), cutoff)
    rnd = random.Random(seed + 100)
    out = []
    g1 = rnd.uniform(0, 6.28); g2 = rnd.uniform(0, 6.28)
    for i, s in enumerate(base):
        t = i / RATE
        gust = 1.0 - gust_depth + gust_depth * (0.5 + 0.5 * math.sin(2 * math.pi * gust_rate * t + g1)) * (0.6 + 0.4 * math.sin(2 * math.pi * gust_rate * 0.37 * t + g2))
        v = s * gust
        if whistle > 0.0:
            v += whistle * gust * math.sin(2 * math.pi * (620 + 40 * math.sin(2 * math.pi * 0.21 * t)) * t) * 0.5 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.11 * t))
        out.append(v)
    fade = int(0.8 * RATE)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
    return out[: n - fade]

write("wind_window", wind(9.0, 21, 420, 0.09, 0.35, 0.0), 0.3)
write("wind_dust", wind(9.0, 22, 700, 0.16, 0.6, 0.0), 0.45)
write("wind_heat", wind(9.0, 23, 520, 0.07, 0.3, 0.12), 0.35)
