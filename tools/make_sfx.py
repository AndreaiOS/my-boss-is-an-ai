#!/usr/bin/env python3
"""Synthesizes the game's 8-bit sound effects as WAV files.

Usage: python3 tools/make_sfx.py
Writes to App/Resources/. Pure stdlib, deterministic output.
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "App" / "Resources"


def square(phase: float) -> float:
    return 1.0 if math.sin(phase) >= 0 else -1.0


def triangle(phase: float) -> float:
    return 2 / math.pi * math.asin(math.sin(phase))


def note(freq: float, dur: float, wave_fn, volume=0.5, decay=6.0):
    """One note with a fast attack and exponential decay."""
    samples = []
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.005) * math.exp(-decay * t)
        samples.append(volume * env * wave_fn(2 * math.pi * freq * t))
    return samples


def silence(dur: float):
    return [0.0] * int(RATE * dur)


def write(name: str, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        f.writeframes(frames)
    print(f"wrote {path.name} ({len(samples) / RATE:.2f}s)")


C5, D5, E5, G5, A5, C6, E6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5
A4, F4, D4, G4, C4 = 440.0, 349.23, 293.66, 392.0, 261.63

# Human choice: warm little pop, two triangle notes.
write("sfx_human.wav", note(C5, 0.09, triangle, 0.55) + note(E5, 0.14, triangle, 0.55))

# AI choice: robotic beep-boop, square arpeggio.
write("sfx_ai.wav", note(E6, 0.06, square, 0.28) + note(A5, 0.06, square, 0.28) + note(E6, 0.1, square, 0.28))

# Office event (automation marches on): dramatic descending sting.
write("sfx_event_bad.wav", note(A4, 0.14, square, 0.32) + note(F4, 0.14, square, 0.32) + note(D4, 0.3, square, 0.32, decay=4))

# Comeback event: ascending sparkle.
write("sfx_event_good.wav", note(C5, 0.08, triangle, 0.5) + note(E5, 0.08, triangle, 0.5) + note(G5, 0.08, triangle, 0.5) + note(C6, 0.2, triangle, 0.5, decay=4))

# Day end: sleepy two-note lullaby.
write("sfx_day_end.wav", note(G4, 0.2, triangle, 0.45, decay=3) + note(C4, 0.45, triangle, 0.45, decay=3))

# Campaign ending: tiny fanfare.
write(
    "sfx_ending.wav",
    note(C5, 0.12, square, 0.3) + note(C5, 0.08, square, 0.3) + silence(0.02)
    + note(G5, 0.16, square, 0.3) + note(E5, 0.12, square, 0.3)
    + note(G5, 0.35, square, 0.3, decay=3),
)

# UI tap: tiny click.
write("sfx_tap.wav", note(C6, 0.04, triangle, 0.35, decay=25))
