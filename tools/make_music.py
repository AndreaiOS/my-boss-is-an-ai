#!/usr/bin/env python3
"""Synthesizes three looping background tracks, one per office stage.
Warmth drops as automation rises. Pure stdlib, deterministic.
Usage: python3 tools/make_music.py   (writes to App/Resources/)
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "App" / "Resources"


def square(p):
    return 1.0 if math.sin(p) >= 0 else -1.0


def triangle(p):
    return 2 / math.pi * math.asin(math.sin(p))


def tone(freq, dur, fn, vol, decay):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.005) * math.exp(-decay * t)
        out.append(vol * env * fn(2 * math.pi * freq * t))
    return out


def mix(a, b):
    n = max(len(a), len(b))
    out = [0.0] * n
    for i in range(len(a)):
        out[i] += a[i]
    for i in range(len(b)):
        out[i] += b[i]
    return out


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples)
        )
    print(f"wrote {name} ({len(samples) / RATE:.2f}s)")


C4, E4, G4, A4, C5, E5, G5 = 261.63, 329.63, 392.0, 440.0, 523.25, 659.25, 783.99
STEP = 0.25  # seconds per step; 32 steps = 8.0s = whole bars
STEPS = 32


def lively():
    melody = [C5, E5, G5, E5, A4, C5, E5, C5] * 4
    track = []
    for f in melody:
        track += tone(f, STEP, triangle, 0.32, 4.0)
    bass = []
    for i in range(len(melody)):
        bass += tone([C4, G4][i % 2], STEP, triangle, 0.20, 3.0)
    return mix(track, bass)[: int(RATE * STEP * STEPS)]


def hybrid():
    melody = [C5, E5, G5, E5, A4, C5, E5, C5] * 4
    track = []
    for i, f in enumerate(melody):
        fn = triangle if i % 2 else square
        track += tone(f, STEP, fn, 0.28, 5.0)
    return track[: int(RATE * STEP * STEPS)]


def automated():
    track = []
    for _ in range(STEPS):
        track += tone(C4, STEP, square, 0.22, 8.0)
    return track[: int(RATE * STEP * STEPS)]


write("music_lively.wav", lively())
write("music_hybrid.wav", hybrid())
write("music_automated.wav", automated())
