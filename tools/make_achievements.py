#!/usr/bin/env python3
"""Generates the 7 Game Center achievement images (1024x1024 PNG).

Each ending gets its iconic sprite, nearest-neighbor upscaled (crisp
pixels) and centered on a flat brand color. Pure stdlib.

Usage: python3 tools/make_achievements.py
Writes to docs/appstore/achievements/.
"""

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "App" / "Resources"
OUT = ROOT / "docs" / "appstore" / "achievements"

SIZE = 1024
SPRITE_SCALE = 11  # 64px sprite -> 704px, comfortably inside the circle crop


def read_png(path):
    """Minimal reader for 8-bit RGB/RGBA non-interlaced PNGs."""
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, width, height, channels, idat = 8, 0, 0, 0, b""
    while pos < len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and interlace == 0, "unsupported PNG"
            channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
        elif ctype == b"IDAT":
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    pixels = bytearray(height * stride)
    previous = bytearray(stride)
    pos = 0
    for y in range(height):
        filt = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            if filt == 1:
                line[x] = (line[x] + a) & 0xFF
            elif filt == 2:
                line[x] = (line[x] + b) & 0xFF
            elif filt == 3:
                line[x] = (line[x] + (a + b) // 2) & 0xFF
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 0xFF
        pixels[y * stride:(y + 1) * stride] = line
        previous = line
    return width, height, channels, pixels


def write_png(path, width, height, rgb):
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]

    def chunk(ctype, payload):
        out = struct.pack(">I", len(payload)) + ctype + payload
        return out + struct.pack(">I", zlib.crc32(ctype + payload) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def make(sprite_name, background, out_name):
    w, h, channels, px = read_png(SPRITES / f"{sprite_name}.png")
    canvas = bytearray()
    for _ in range(SIZE * SIZE):
        canvas += bytes(background)
    canvas = bytearray(bytes(background) * (SIZE * SIZE))

    scaled = w * SPRITE_SCALE
    ox = (SIZE - scaled) // 2
    oy = (SIZE - h * SPRITE_SCALE) // 2
    for sy in range(h * SPRITE_SCALE):
        src_y = sy // SPRITE_SCALE
        for sx in range(scaled):
            src_x = sx // SPRITE_SCALE
            i = (src_y * w + src_x) * channels
            if channels == 4 and px[i + 3] < 128:
                continue
            j = ((oy + sy) * SIZE + (ox + sx)) * 3
            canvas[j:j + 3] = px[i:i + 3]
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / f"{out_name}.png", SIZE, SIZE, canvas)
    print(f"wrote {out_name}.png")


# Ending -> (sprite, flat background RGB)
make("robot_worker", (245, 158, 66), "ending.robots_with_feelings")
make("coffee_machine_ai", (24, 34, 58), "ending.corporate_singularity")
make("kpi_dashboard", (52, 58, 74), "ending.ghost_in_the_open_space")
make("gino", (243, 200, 88), "ending.employee_of_the_century")
make("printer", (150, 60, 50), "ending.burnout_speedrun")
make("pizza_box", (88, 130, 82), "ending.great_compromise")
make("mug_gino", (120, 100, 82), "ending.just_another_quarter")
