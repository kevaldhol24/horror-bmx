#!/usr/bin/env python3
"""Generates every sound in assets/audio/ procedurally (original, CC0).

Run:  python3 tools/gen_audio.py
Needs numpy + scipy. Output: 16-bit mono WAV @ 22050 Hz (music is 32 kHz).
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
SR = 22050
rng = np.random.default_rng(84)


def save(name, x, sr=SR, peak=0.89):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    wavfile.write(os.path.join(OUT, name), sr, (x * 32767).astype(np.int16))
    print(f"{name}: {len(x) / sr:.1f}s")


def lp(x, hz, sr=SR, order=2):
    b, a = butter(order, hz / (sr / 2), "low")
    return lfilter(b, a, x)


def hp(x, hz, sr=SR, order=2):
    b, a = butter(order, hz / (sr / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, sr=SR, order=2):
    b, a = butter(order, [lo / (sr / 2), hi / (sr / 2)], "band")
    return lfilter(b, a, x)


def loopify(x, fade):
    """Crossfade the tail into the head so the file loops seamlessly."""
    n = len(x) - fade
    out = x[:n].copy()
    w = np.linspace(0, 1, fade)
    out[:fade] = x[:fade] * w + x[n:] * (1 - w)
    return out


def t_axis(sec, sr=SR):
    return np.arange(int(sec * sr)) / sr


# ------------------------------------------------------------------ music
def synth_theme():
    """Original dark 80s synth loop: pulsing A-minor arpeggio over a slow pad
    and a sub bass. 96 BPM, 8 bars, loops seamlessly."""
    sr = 32000
    bpm = 96
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    t = t_axis(total + 2.0, sr)
    out = np.zeros_like(t)

    def note(m):
        return 440.0 * 2 ** ((m - 69) / 12)

    # Chord per bar (root midi + minor/major triad + 7th colour).
    prog = [(57, "m"), (53, "M"), (50, "m"), (52, "M"), (57, "m"), (53, "M"), (55, "M"), (52, "M")]

    def triad(root, kind):
        third = 3 if kind == "m" else 4
        return [root, root + third, root + 7, root + 12]

    # Arpeggio: 16th notes, pattern up-down with octave jumps.
    pattern = [0, 1, 2, 3, 2, 1, 2, 3, 0, 2, 1, 3, 2, 1, 0, 1]
    sixteenth = beat / 4
    for bar, (root, kind) in enumerate(prog):
        tones = triad(root + 12, kind)
        for i in range(16):
            st = (bar * 16 + i) * sixteenth
            f = note(tones[pattern[i]])
            dur = sixteenth * 0.92
            n0 = int(st * sr)
            n = int(dur * sr)
            tt = np.arange(n) / sr
            # Detuned saw-ish (additive) with plucky envelope.
            w = np.zeros(n)
            for k in range(1, 9):
                w += np.sin(2 * np.pi * f * k * tt) / k
                w += np.sin(2 * np.pi * f * 1.004 * k * tt) / k * 0.6
            env = np.exp(-tt * 9.0) * (1 - np.exp(-tt * 400))
            accent = 1.0 if i % 4 == 0 else 0.7
            out[n0:n0 + n] += w * env * 0.16 * accent
    # Pad: slow-attack chords, filtered.
    pad = np.zeros_like(t)
    for bar, (root, kind) in enumerate(prog):
        st = bar * 4 * beat
        n0 = int(st * sr)
        n = int(4 * beat * sr * 1.15)
        n = min(n, len(t) - n0)
        tt = np.arange(n) / sr
        env = np.minimum(1, tt / 0.9) * np.exp(-np.maximum(0, tt - 4 * beat) * 3)
        for m in triad(root, kind)[:3]:
            f = note(m)
            for det in (0.997, 1.0, 1.003):
                pad[n0:n0 + n] += np.sin(2 * np.pi * f * det * tt + np.sin(2 * np.pi * 0.3 * tt)) * env * 0.05
    out += lp(pad, 1800, sr)
    # Sub bass: root on every beat, sidechain-ish pump.
    bass = np.zeros_like(t)
    for bar, (root, kind) in enumerate(prog):
        for b in range(4):
            st = (bar * 4 + b) * beat
            n0 = int(st * sr)
            n = int(beat * 0.9 * sr)
            tt = np.arange(n) / sr
            f = note(root - 12)
            env = np.exp(-tt * 3.5) * (1 - np.exp(-tt * 200))
            bass[n0:n0 + n] += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * env * 0.35
    out += bass
    # Soft kick on 1 and 3.
    for bb in range(bars * 2):
        n0 = int(bb * 2 * beat * sr)
        n = int(0.25 * sr)
        tt = np.arange(n) / sr
        f = 120 * np.exp(-tt * 25) + 42
        out[n0:n0 + n] += np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-tt * 12) * 0.45
    # Simple stereo-less echo for space.
    d = int(beat * 0.75 * sr)
    echo = np.zeros_like(out)
    echo[d:] = out[:-d] * 0.32
    out = out + lp(echo, 2500, sr)
    n_loop = int(total * sr)
    tail = out[n_loop:]
    body = out[:n_loop].copy()
    body[:len(tail)] += tail  # wrap the echo tail into the start
    save("synth_theme.wav", body, sr, 0.8)


# ------------------------------------------------------------------ ambience
def ambience():
    t = t_axis(24)
    n = rng.standard_normal(len(t))
    wind = bp(n, 120, 900)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1)
    wind *= gust
    drone = np.zeros_like(t)
    for f, a in ((55, 0.5), (55.4, 0.4), (82.4, 0.25), (110.7, 0.12)):
        drone += a * np.sin(2 * np.pi * f * t + 0.5 * np.sin(2 * np.pi * 0.07 * t))
    drone = lp(drone, 300) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 12.0))
    # Distant metallic groans.
    groan = np.zeros_like(t)
    for st in (4.0, 15.5):
        n0 = int(st * SR)
        tt = np.arange(int(3.0 * SR)) / SR
        f = 180 + 40 * np.sin(tt * 2)
        g = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 3.0) ** 2
        groan[n0:n0 + len(tt)] += g * 0.18
    groan = bp(groan, 120, 700)
    x = wind * 0.5 + drone * 0.6 + groan
    save("ambience.wav", loopify(x, SR), peak=0.7)


def tire_roll():
    t = t_axis(4)
    n = rng.standard_normal(len(t))
    x = bp(n, 200, 1600) * 0.6 + lp(n, 120) * 1.5
    x *= 1 + 0.15 * np.sin(2 * np.pi * 6 * t)
    save("tire_roll.wav", loopify(x, 2000), peak=0.6)


def freewheel():
    # BMX freewheel ticking: clicks at 18 Hz.
    t = t_axis(2)
    x = np.zeros_like(t)
    for k in range(int(2 * 18)):
        n0 = int(k / 18 * SR)
        n = 220
        tt = np.arange(n) / SR
        x[n0:n0 + n] += np.sin(2 * np.pi * 3800 * tt) * np.exp(-tt * 900)
    x = hp(x, 1500)
    save("freewheel.wav", x, peak=0.5)


def rough():
    t = t_axis(2)
    n = rng.standard_normal(len(t))
    rattle = bp(n, 300, 3000) * (np.abs(np.sin(2 * np.pi * 13 * t)) ** 4)
    thump = lp(n, 90) * 3
    save("rough.wav", loopify(rattle + thump, 1500), peak=0.6)


# ------------------------------------------------------------------ one-shots
def thunder():
    t = t_axis(6)
    n = rng.standard_normal(len(t))
    crack = hp(n, 400) * np.exp(-t * 6) * 0.6
    rumble = lp(n, 160, order=3) * 6
    env = (1 - np.exp(-t * 4)) * np.exp(-t * 0.65)
    env *= 0.7 + 0.3 * np.abs(lp(rng.standard_normal(len(t)), 3)) * 8
    save("thunder.wav", crack + rumble * env, peak=0.85)


def crash():
    t = t_axis(1.6)
    n = rng.standard_normal(len(t))
    hit = lp(n, 300) * np.exp(-t * 12) * 4
    metal = np.zeros_like(t)
    for f in (1240, 1873, 2611, 3320):
        metal += np.sin(2 * np.pi * f * t) * np.exp(-t * (5 + f / 900))
    scrape = bp(n, 1200, 5000) * np.exp(-t * 3) * 0.5
    save("crash.wav", hit + metal * 0.25 + scrape, peak=0.9)


def hop():
    t = t_axis(0.35)
    n = rng.standard_normal(len(t))
    whoosh = bp(n, 500, 2500) * np.sin(np.pi * t / 0.35) ** 2
    creak = np.sin(2 * np.pi * (600 + 300 * t) * t) * np.exp(-t * 20) * 0.3
    save("hop.wav", whoosh * 0.5 + creak, peak=0.6)


def land():
    t = t_axis(0.5)
    n = rng.standard_normal(len(t))
    thud = lp(n, 200) * np.exp(-t * 14) * 3
    rattle = bp(n, 800, 4000) * np.exp(-t * 18) * 0.5
    save("land.wav", thud + rattle, peak=0.75)


def sting():
    """Horror stinger: dissonant brass-ish stab + noise riser for the Watcher."""
    t = t_axis(3.0)
    x = np.zeros_like(t)
    for f in (110, 116.5, 155.6, 164.8, 233):
        w = np.zeros_like(t)
        for k in range(1, 7):
            w += np.sin(2 * np.pi * f * k * t * (1 + 0.002 * k)) / k
        x += w
    env = (1 - np.exp(-t * 30)) * np.exp(-t * 0.9)
    x = lp(x, 2200) * env
    n = rng.standard_normal(len(t))
    screech = bp(n, 2000, 6000) * np.exp(-t * 2.5) * 0.4
    save("sting.wav", x + screech, peak=0.85)


def buzz():
    t = t_axis(1.2)
    hum = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.3 + np.sin(2 * np.pi * 240 * t) * 0.2
    crackle = (rng.random(len(t)) > 0.995) * rng.standard_normal(len(t)) * 2
    gate = (np.sin(2 * np.pi * 9 * t) > -0.2).astype(float)
    x = lp(hum * gate + crackle, 3000)
    save("buzz.wav", x, peak=0.5)


def heartbeat():
    t = t_axis(1.0)
    x = np.zeros_like(t)
    for st, a in ((0.0, 1.0), (0.22, 0.7)):
        n0 = int(st * SR)
        tt = np.arange(int(0.2 * SR)) / SR
        x[n0:n0 + len(tt)] += np.sin(2 * np.pi * 52 * tt) * np.exp(-tt * 22) * a
    save("heartbeat.wav", x, peak=0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    synth_theme()
    ambience()
    tire_roll()
    freewheel()
    rough()
    thunder()
    crash()
    hop()
    land()
    sting()
    buzz()
    heartbeat()
