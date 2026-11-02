#!/usr/bin/env python3
"""Renders a SCREEN 5 page dump (build/test/NAME.vram + NAME.pal, written by
tools/boot_test.tcl) to build/test/NAME.png (page 0) and NAME_p1.png .. NAME_p3.png.

    vram2png.py NAME [NAME ...]
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def render(name):
    base = os.path.join(ROOT, 'build', 'test', name)
    v = open(base + '.vram', 'rb').read()
    p = open(base + '.pal', 'rb').read()
    pal = []
    for i in range(16):
        rb, g = p[2 * i], p[2 * i + 1]
        pal.append(((rb >> 4 & 7) * 255 // 7, (g & 7) * 255 // 7, (rb & 7) * 255 // 7))
    pages = len(v) // 0x8000 or 1
    for page in range(pages):
        rows = 256 if pages > 1 else 212
        im = Image.new('RGB', (256, rows))
        px = im.load()
        for y in range(rows):
            for x in range(128):
                b = v[page * 0x8000 + y * 128 + x]
                px[2 * x, y] = pal[b >> 4]
                px[2 * x + 1, y] = pal[b & 15]
        im.save(base + ('.png' if page == 0 else '_p%d.png' % page))


if __name__ == '__main__':
    for n in sys.argv[1:]:
        render(n)
