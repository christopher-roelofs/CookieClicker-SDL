#!/usr/bin/env python3
"""Generate the game's sound effects (assets/sfx_*.wav).

Everything is synthesized here, so the sounds are original and free to ship.
Run from the repo root:  python3 tools/make_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets")


def write(name, samples, level=0.55):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = level / peak  # leave headroom; the game sets the volume
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f"{path}: {len(samples) / RATE * 1000:.0f} ms")


def env(t, attack, decay):
    """Fast attack, exponential decay."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def pop(f_start, f_end, length, decay, noise=0.15, seed=0):
    """A soft cookie 'pop': a sine sweeping down plus a little crunch."""
    rnd = random.Random(seed)
    out, phase = [], 0.0
    n = int(length * RATE)
    for i in range(n):
        t = i / RATE
        f = f_end + (f_start - f_end) * math.exp(-t / 0.012)
        phase += 2 * math.pi * f / RATE
        crunch = (rnd.random() * 2 - 1) * math.exp(-t / 0.006)
        out.append((math.sin(phase) + noise * crunch) * env(t, 0.002, decay))
    return out


def tone(freq, length, decay, harmonics=(1.0, 0.3, 0.1), attack=0.003):
    out = []
    n = int(length * RATE)
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))
        out.append(s * env(t, attack, decay))
    return out


def sequence(*parts, gap=0.0):
    """Notes that overlap: each starts `gap` seconds after the previous one."""
    total = int((gap * (len(parts) - 1)) * RATE) + max(len(p) for p in parts)
    out = [0.0] * total
    for k, p in enumerate(parts):
        start = int(gap * k * RATE)
        for i, s in enumerate(p):
            out[start + i] += s
    return out


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# Cookie clicks: three slightly different pops so mashing doesn't sound robotic
write("sfx_click1.wav", pop(950, 320, 0.09, 0.025, seed=1))
write("sfx_click2.wav", pop(1050, 360, 0.09, 0.022, seed=2))
write("sfx_click3.wav", pop(880, 300, 0.10, 0.028, seed=3))

# Buy: bright two-note coin (B5 -> E6)
write("sfx_buy.wav", sequence(tone(note(83), 0.10, 0.04), tone(note(88), 0.22, 0.07), gap=0.06))

# Sell: the same coin falling (E6 -> B5), a little duller
write("sfx_sell.wav", sequence(tone(note(88), 0.10, 0.04, (1.0, 0.15)), tone(note(83), 0.22, 0.07, (1.0, 0.15)), gap=0.06))

# Upgrade: quick rising arpeggio (C6 E6 G6 C7)
write("sfx_upgrade.wav", sequence(*[tone(note(n), 0.25, 0.08) for n in (84, 88, 91, 96)], gap=0.045))

# Can't afford: short, soft low buzz
write("sfx_denied.wav", sequence(tone(note(45), 0.14, 0.05, (1.0, 0.5, 0.33, 0.25), attack=0.004),
                                 tone(note(44), 0.16, 0.05, (1.0, 0.5, 0.33, 0.25), attack=0.004), gap=0.07))

# Menu navigation: a soft tick for moving, a blip up to select, a blip down to go back.
# The tick is quieter than the rest since holding a direction repeats it.
write("sfx_nav.wav", tone(note(91), 0.05, 0.012, (1.0, 0.2)), level=0.3)
write("sfx_select.wav", sequence(tone(note(84), 0.07, 0.025), tone(note(91), 0.12, 0.04), gap=0.04), level=0.45)
write("sfx_back.wav", sequence(tone(note(84), 0.07, 0.025), tone(note(79), 0.12, 0.04), gap=0.04), level=0.4)
