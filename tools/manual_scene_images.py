#!/usr/bin/env python3
"""Capture the two language-dependent map illustrations for the English manual.

The other scene illustrations show only SIGMAR, numbers and icons, and are
shared between manuals. Hero/monster portraits, animation strips and furniture
strips have no embedded labels and are also language independent.

This fixture boots the English ROM, loads the real Rescue of Sir Ragnar quest,
lets its setup and first hero turn run, then calls the game's native map and
caption renderers. No screenshot pixels or text glyphs are patched afterwards.
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

TCL = r'''
set ::scene_started 0
set ::scene_menu_bp [debug set_bp 0x5B06 {} {
    if {!$::scene_started} {
        set ::scene_started 1
        debug remove_bp $::scene_menu_bp
        if {[peek @LANG@] != 1} {error "manual scene is not English"}
        poke 0xA981 1
        reg SP 0x6D70
        poke 0x6D70 0x84
        poke 0x6D71 0x6D
        reg PC 0x5B3F
    }
}]
set ::scene_brief_bp [debug set_bp 0x5C53 {} {
    debug remove_bp $::scene_brief_bp
    after time 0.1 {hq_key 8 1 0.3}
    after time 2 scene_draw
}]
proc scene_draw {} {
    # Reveal the adjoining room for an informative enemy-selection example.
    # This changes only the illustrative game state, never text or graphics.
    for {set a 0x6200} {$a < 0x63EE} {incr a} {
        set cell [peek $a]
        if {($cell & 63) == 38} {poke $a [expr {$cell | 192}]}
    }
    # C200h is unused walking-animation data while this stopped map fixture
    # runs. Unlike screen scratch RAM it survives the native clear routine.
    debug write_block memory 0xC200 [binary format H* cdC8A3dd21@CAPTION@cd1B997618fd]
    reg SP 0x6D70
    reg PC 0xC200
}
debug set_bp 0xC20A {} {after time 0.04 hq_report}
'''


def capture(name, caption):
    prefix = OUT / ('manual-' + name)
    syms = symbols(ROOT / 'build/runtime.sym')
    tcl = TCL.replace('@LANG@', str(syms['rt_language'])).replace(
        '@CAPTION@', caption.to_bytes(2, 'little').hex())
    script = prefix.with_suffix('.tcl')
    script.write_text(tcl)
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
               HQ_OUT=str(prefix), HQ_SECS='60',
               HQ_KEYS='21 space/0.4 24 up/0.3 26 7:128/0.3 28 space/0.3',
               HQ_TCL=f'0.1 {{source {script}}}')
    for key in ('HQ_PLUG', 'HQ_LOG', 'HQ_VDPLOG', 'HQ_SYM'):
        env.pop(key, None)
    r = subprocess.run(['openmsx', '-machine', 'Philips_NMS_8250',
                        '-carta', 'build/heroquest.rom', '-romtype', 'ASCII16',
                        '-command', 'set renderer none', '-script', 'tools/boot_test.tcl'],
                       cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
    assert r.returncode == 0 and 'error' not in r.stderr.lower(), r.stderr
    report = prefix.with_suffix('.txt').read_text()
    assert 'pc=C20' in report, report
    vram2png.render(prefix.name)
    image = Image.open(prefix.with_suffix('.png')).crop((0, 16, 256, 208))
    image.resize((768, 576), Image.Resampling.NEAREST).save(IMAGES / (name + '.png'))
    print('docs/manual/images/' + name + '.png')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    capture('mapa_ataque_en', 0xB851)
    capture('turno_morcar_en', 0xA438)


if __name__ == '__main__':
    main()
