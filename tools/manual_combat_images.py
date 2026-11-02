#!/usr/bin/env python3
"""Capture English combat, inventory and search pictures from the ROM.

Debugger fixtures select heroes/dice and call native drawing routines.
All text, sprites and art are rendered by the cartridge, never painted over.
Run after make all: .venv/bin/python tools/manual_combat_images.py
"""
import os
from pathlib import Path
import subprocess
from PIL import Image
from build_rom import symbols
import vram2png
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/test'
IMAGES = ROOT / 'docs/manual/images'
CASES = ['buscar_en', 'combate_victoria_en', 'combate_bloqueado_en', 'combate_herido_en',
         'hoja_hechicero_en', 'hoja_barbaro_en'] + [f'lamina_{n}_en' for n in (0, 1, 2, 3, 4, 8)]
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    syms = symbols(ROOT / 'build/runtime.sym')
    template = (ROOT / 'tools/manual_combat_images.tcl').read_text()
    for name in CASES:
        prefix = OUT / ('manual-' + name)
        script = prefix.with_suffix('.tcl')
        script.write_text(template.replace('@CASE@', name).replace('@SYMBOLS@',
            ' '.join(f'{k} {v}' for k, v in syms.items() if '.' not in k)))
        prefix.with_suffix('.ready').unlink(missing_ok=True)
        env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
                   HQ_OUT=str(prefix), HQ_SECS='60',
                   HQ_KEYS='21 space/0.4 24 up/0.3 26 7:128/0.3 28 space/0.3',
                   HQ_TCL=f'0.1 {{source {script}}}')
        for key in ('HQ_PLUG', 'HQ_LOG', 'HQ_VDPLOG', 'HQ_SYM'): env.pop(key, None)
        result = subprocess.run(['openmsx', '-machine', 'Philips_NMS_8250',
            '-carta', 'build/heroquest.rom', '-romtype', 'ASCII16',
            '-command', 'set renderer none', '-script', 'tools/boot_test.tcl'],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
        assert result.returncode == 0 and not result.stderr.strip(), result.stderr
        assert prefix.with_suffix('.ready').is_file(), f'{name}: fixture never completed'
        vram2png.render(prefix.name)
        image = Image.open(prefix.with_suffix('.png'))
        box = (64, 26, 192, 90) if name.startswith('lamina_') else (0, 10, 256, 202)
        image = image.crop(box)
        image.resize((image.width * 3, image.height * 3), Image.Resampling.NEAREST).save(IMAGES / (name + '.png'))
        print(name + '.png', flush=True)
if __name__ == '__main__': main()
