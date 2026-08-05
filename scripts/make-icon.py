#!/usr/bin/env python3
"""Generate build/icon.png (512x512) — a flask glyph on a rounded terracotta tile.

Pure stdlib (zlib + struct), no Pillow required. Rendered at 4x and box-filtered
down for antialiasing.
"""
import os
import struct
import zlib

SIZE = 512
SS = 4  # supersampling factor
N = SIZE * SS

BG = (217, 119, 87)      # Anthropic terracotta
FG = (255, 251, 247)     # off-white glyph
LIQUID = (156, 62, 40)   # darker fill inside the flask

RADIUS = 0.2237 * N      # squircle-ish corner radius (macOS-like proportion)


def rounded_rect(x, y):
    """Inside the rounded square?"""
    cx = min(max(x, RADIUS), N - RADIUS)
    cy = min(max(y, RADIUS), N - RADIUS)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= RADIUS * RADIUS


# Flask geometry, in units of N.
NECK_HALF = 0.052 * N
NECK_TOP = 0.215 * N
NECK_BOT = 0.400 * N
BODY_BOT = 0.790 * N
BODY_HALF = 0.255 * N
LIP_HALF = 0.098 * N
LIP_TOP = 0.190 * N
STROKE = 0.030 * N
LIQUID_TOP = 0.615 * N


def body_half_at(y):
    """Half-width of the flask cone at height y (flares from neck to base)."""
    t = (y - NECK_BOT) / (BODY_BOT - NECK_BOT)
    return NECK_HALF + t * (BODY_HALF - NECK_HALF)


def flask_outer(x, y):
    d = abs(x - N / 2)
    if LIP_TOP <= y <= NECK_TOP:
        return d <= LIP_HALF
    if NECK_TOP < y <= NECK_BOT:
        return d <= NECK_HALF
    if NECK_BOT < y <= BODY_BOT:
        return d <= body_half_at(y)
    return False


def flask_inner(x, y):
    d = abs(x - N / 2)
    if NECK_TOP + STROKE <= y <= NECK_BOT:
        return d <= NECK_HALF - STROKE
    if NECK_BOT < y <= BODY_BOT - STROKE:
        return d <= body_half_at(y) - STROKE
    return False


def render():
    """Return an SIZE x SIZE x 4 RGBA buffer."""
    acc = [[[0, 0, 0, 0] for _ in range(SIZE)] for _ in range(SIZE)]
    for sy in range(N):
        y = sy + 0.5
        row = acc[sy // SS]
        for sx in range(N):
            x = sx + 0.5
            if not rounded_rect(x, y):
                continue  # transparent outside the tile
            if flask_outer(x, y):
                if flask_inner(x, y):
                    px = LIQUID if y >= LIQUID_TOP else BG
                else:
                    px = FG
            else:
                px = BG
            cell = row[sx // SS]
            cell[0] += px[0]
            cell[1] += px[1]
            cell[2] += px[2]
            cell[3] += 255

    samples = SS * SS
    out = bytearray()
    for y in range(SIZE):
        out.append(0)  # PNG filter type 0
        for x in range(SIZE):
            r, g, b, a = acc[y][x]
            if a == 0:
                out += b"\x00\x00\x00\x00"
                continue
            # Un-premultiply against coverage so edges stay crisp, not dark.
            cov = a // 255
            out += bytes((r // cov, g // cov, b // cov, a // samples))
    return bytes(out)


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def main():
    raw = render()
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    dest = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "build", "icon.png")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as fh:
        fh.write(png)
    print(f"wrote {dest} ({len(png)} bytes)")


if __name__ == "__main__":
    main()
