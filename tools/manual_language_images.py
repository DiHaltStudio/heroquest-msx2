#!/usr/bin/env python3
"""Capture bilingual manual illustrations from the built ROM in openMSX.

Run after make all: .venv/bin/python tools/manual_language_images.py
The keyboard drives the real opening, language selector and menus. The
visible SCREEN 5 page is decoded with vram2png, cropped to the same artwork
or game viewport as the existing manual images, and enlarged 3x without
filtering. Dumps and machine reports remain under build/test/.
"""
import os
from pathlib import Path
import re
import subprocess

from PIL import Image
import vram2png

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build' / 'test'
IMAGES = ROOT / 'docs' / 'manual' / 'images'
ENGLISH = '13 space/0.4 16 up/0.3 18 7:128/0.3'
MENU = ENGLISH + ' 20 space/0.3'
CAPTURES = (
    ('language_selector_en', 17, '13 space/0.4 16 up/0.3', (0, 14, 256, 174)),
    ('language_selector', 18, '13 space/0.4', (0, 14, 256, 174)),
    ('intro_titulo_en', 19, ENGLISH, (0, 14, 256, 174)),
    ('intro_texto_en', 40, ENGLISH, (0, 14, 256, 174)),
    ('menu_principal_en', 24, MENU, (0, 0, 256, 192)),
    ('controles_en', 31, MENU + ' 25 down/0.3 26 down/0.3 27 down/0.3 28 space/0.3',
     (0, 0, 256, 192)),
)


def capture(name, seconds, keys, crop):
    # Leave room for either complete logo fanfare before the old capture schedule.
    seconds += 8
    pairs = keys.split()
    keys = ' '.join(f'{float(pairs[i]) + 8:g} {pairs[i+1]}' for i in range(0, len(pairs), 2))
    dump_name = 'manual-' + name
    prefix = OUT / dump_name
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
               HQ_OUT=str(prefix), HQ_SECS=str(seconds), HQ_KEYS=keys)
    # Keep caller test hooks from changing the reproducible menu sequence.
    for key in ('HQ_TCL', 'HQ_PLUG', 'HQ_LOG', 'HQ_VDPLOG', 'HQ_SYM'):
        env.pop(key, None)
    subprocess.run(['openmsx', '-machine', 'Philips_NMS_8250',
                    '-carta', 'build/heroquest.rom', '-romtype', 'ASCII16',
                    '-command', 'set renderer none', '-script', 'tools/boot_test.tcl'],
                   cwd=ROOT, env=env, capture_output=True, text=True, check=True, timeout=60)
    report = prefix.with_suffix('.txt').read_text()
    registers = re.search(r'^vdp regs: (.+)$', report, re.M)
    assert registers, report
    values = [int(value, 16) for value in registers[1].split()]
    assert values[0] & 0x0E == 0x06 and values[1] & 0x40, 'capture is not visible SCREEN 5'
    page = (values[2] >> 5) & 3
    vram2png.render(dump_name)
    source = OUT / (dump_name + (f'_p{page}' if page else '') + '.png')
    image = Image.open(source).crop(crop)
    image = image.resize((image.width * 3, image.height * 3), Image.Resampling.NEAREST)
    target = IMAGES / (name + '.png')
    image.save(target)
    print(target.relative_to(ROOT))


def main():
    assert (ROOT / 'build' / 'heroquest.rom').is_file(), 'run make all first'
    OUT.mkdir(parents=True, exist_ok=True)
    IMAGES.mkdir(parents=True, exist_ok=True)
    for args in CAPTURES:
        capture(*args)


if __name__ == '__main__':
    main()
