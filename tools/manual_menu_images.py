#!/usr/bin/env python3
"""Capture English manual menus from the current ROM using native game routines.

Run after make all: .venv/bin/python tools/manual_menu_images.py
The normal boot and language selection use keyboard input. Once the English
menu is loaded, debugger entry points select the UI being documented. All
text and glyphs come from the cartridge; no translated pixels are injected.
"""
import os
from pathlib import Path
import re
import subprocess

from PIL import Image
from build_rom import symbols
import vram2png

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/test'
IMAGES = ROOT / 'docs/manual/images'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    syms = symbols(ROOT / 'build/runtime.sym')
    syms.update(symbols(ROOT / 'build/runtime2.sym'))
    cases = {
        'crear_personaje_en': 'reg PC 0x5DE5',
        'codigo_guardar_en': f'reg PC {syms["r2_code_save"]}',
        'codigo_cargar_en': f'reg PC {syms["r2_code_load"]}',
        'tienda_en': 'reg PC 0x62C4',
        'hechizos_en': 'reg PC 0x61F9',
        'aventuras1_en': f'poke {syms["r2_qpage"]} 0; reg PC 0x6166',
        'aventuras2_en': f'poke {syms["r2_qpage"]} 1; reg PC 0x6166',
        'pergamino1_en': 'poke 0xA981 0; reg PC 0x5B3F',
        'pergamino_exp_en': 'poke 0xA981 14; reg PC 0x5B3F',
    }
    for name, entry in cases.items():
        prefix = OUT / ('manual-' + name)
        script = prefix.with_suffix('.tcl')
        script.write_text('''
proc manual_enter {} {
    if {[peek LANGUAGE] != 1 || [debug read_block memory 0x6667 4] ne "PLAY"} {
        error "English main menu was not reached"
    }
    foreach address {0x8FE4 0x8FE5 0x8FE6 0x8FE7} {poke $address 255}
    poke 0x65F0 0
    poke 0x65F1 0
    reg SP 0x6D70
    ENTRY
}
after time 32 manual_enter
'''.replace('LANGUAGE', str(syms['rt_language'])).replace('ENTRY', entry))
        env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
                   HQ_OUT=str(prefix), HQ_SECS='36',
                   HQ_KEYS='21 space/0.4 24 up/0.3 26 7:128/0.3 28 space/0.3',
                   HQ_TCL=f'0.1 {{source {script}}}')
        for key in ('HQ_PLUG', 'HQ_LOG', 'HQ_VDPLOG', 'HQ_SYM'):
            env.pop(key, None)
        result = subprocess.run(['openmsx', '-machine', 'Philips_NMS_8250',
                                 '-carta', 'build/heroquest.rom', '-romtype', 'ASCII16',
                                 '-command', 'set renderer none', '-script', 'tools/boot_test.tcl'],
                                cwd=ROOT, env=env, capture_output=True, text=True,
                                check=True, timeout=60)
        assert not result.stderr.strip(), result.stderr
        report = prefix.with_suffix('.txt').read_text()
        regs = [int(n, 16) for n in re.search(r'^vdp regs: (.+)$', report, re.M)[1].split()]
        assert regs[0] & 14 == 6 and regs[1] & 64, name
        page = (regs[2] >> 5) & 3
        vram2png.render(prefix.name)
        source = Path(str(prefix) + (f'_p{page}' if page else '') + '.png')
        image = Image.open(source).crop((0, 16, 256, 208)).resize((768, 576), Image.Resampling.NEAREST)
        image.save(IMAGES / (name + '.png'))
        print(name + '.png')


if __name__ == '__main__':
    main()
