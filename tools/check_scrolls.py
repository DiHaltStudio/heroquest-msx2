#!/usr/bin/env python3
from original_paths import ZX_ORIG
"""Emulator checks: window geometry, ROM reload, transparency and themes.

    .venv/bin/python tools/check_scrolls.py [C-BIOS_MSX2_EU|Philips_NMS_8250]
Uses an independent openMSX instance with its video renderer disabled.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

from PIL import Image

from vram2png import render

ROOT = Path(__file__).resolve().parents[1]


def pixel(vram, page, x, y):
    byte = vram[page * 0x8000 + y * 128 + x // 2]
    return (byte >> 4 if x % 2 == 0 else byte) & 15


def main():
    machine = sys.argv[1] if len(sys.argv) > 1 else 'C-BIOS_MSX2_EU'
    name = 'scroll-' + machine
    prefix = ROOT / 'build' / 'test' / name
    prefix.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, HQ_OUT=str(prefix), SDL_AUDIODRIVER='dummy')
    env.setdefault('SDL_VIDEODRIVER', 'dummy')
    result = subprocess.run([
        'openmsx', '-machine', machine, '-carta', 'build/heroquest.rom',
        '-romtype', 'ASCII16', '-command', 'set renderer none',
        '-script', 'tools/scroll_check.tcl',
    ], cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stderr
    report = prefix.with_suffix('.txt').read_text()
    assert 'failed=0' in report and 'FAIL' not in report, report + result.stderr

    # Verify the real search menu's empty font pixels retain textured paper,
    # while its ink pixels are painted correctly. Compare both VRAM pages.
    atlas = Image.open(ROOT / 'assets' / 'scrolls.png')
    styles = json.loads((ROOT / 'assets' / 'scrolls.json').read_text())
    font = Image.open(ROOT / 'assets' / 'font.png')
    original = (ZX_ORIG / 'block05_flagFF.bin').read_bytes()
    # Every distinct effective paper colour in the room table has its own
    # style, including normal/bright white, cyan, green and magenta.
    zx_palette = [12, 1, 4, 5, 2, 3, 14, 7, 12, 9, 0, 13, 10, 11, 14, 15]
    room_attrs = original[0xC47C - 0x6400 + 2:0xC47C - 0x6400 + 43 * 4:4]
    papers = {zx_palette[((a >> 3) & 7) + (8 if a & 64 else 0)] for a in room_attrs}
    assert len(papers) == 10
    assert len({styles['paper_to_style'][p] for p in papers}) == len(papers)
    text = original[0xAFE2 - 0x6400 + 4:0xAFE2 - 0x6400 + 49]
    for case, family, ink in [('search', 0, 12), ('inverse', 0, 12)]:
        vram = Path(str(prefix) + '-' + case + '.vram').read_bytes()
        for n, char in enumerate(text):
            col, row = n % 15 + 1, n // 15 + 1
            tile = family * 2 + (row ^ col) % 2
            for dy in range(8):
                for dx in range(8):
                    glyph = char - 0x30
                    on = font.getpixel(((glyph % 16) * 8 + dx, (glyph // 16) * 8 + dy))
                    expected = ink if on else atlas.getpixel(((tile % 6) * 8 + dx, (tile // 6) * 8 + dy))
                    x, y = (8 + col) * 8 + dx, 26 + (11 + row) * 8 + dy
                    for page in (0, 1):
                        assert pixel(vram, page, x, y) == expected, (case, page, x, y)
        # Rendering a letter may change scratch only, never atlas tiles.
        for tile in range(28):
            for dy in range(8):
                for dx in range(8):
                    x, y = (tile % 6) * 8 + dx, (tile // 6) * 8 + dy
                    assert pixel(vram, 2, 192 + x, 160 + y) == atlas.getpixel((x, y))
        render(name + '-' + case)
    render(name + '-gallery')
    # Share the visible screen only, excluding the VDP's hidden lines.
    preview = prefix.parent / (name + '-gallery.png')
    with Image.open(preview) as im:
        im.crop((0, 0, 256, 212)).save(preview)
    print(report, end='')
    print('10 original room paper colours: 10 distinct styles')
    print('Transparent text, scene presentation and immutable atlas: OK')


if __name__ == '__main__':
    main()
