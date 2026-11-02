#!/usr/bin/env python3
from original_paths import ZX_ORIG
"""Exercise the bilingual boot and all 24 quest loaders in headless openMSX.

Run after make all cheat-rom. Selection uses actual key presses, driven by
breakpoints so disk speed, OPL4 sample loading and 50/60 Hz do not affect it.
The quest checks enter the real setup routine, check the loaded briefing and
wait until it has been rendered before restoring the menu overlay for the
next quest. They never inject translated text into the emulated machine.
"""
import os
from pathlib import Path
import subprocess

from build_rom import symbols, caos, fix_briefing10
from localize_quests import QUESTS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/test'
SEG = 0x4000


def bank_tables(rom, sym):
    spanish = rom[0x400 + sym['rt_bank_segs']:0x408 + sym['rt_bank_segs']]
    intro_base = sym['SEG_INTRO'] * SEG
    p = intro_base + sym['in_english_banks'] - 0x8000
    english = rom[p:p + 8]
    assert len(spanish) == len(english) == 8
    assert spanish[1] == 5 and spanish[3] == 6 and spanish[6] == 7
    assert english[1] != spanish[1]
    return spanish, english


def briefings(rom, banks):
    """Read the actual ROM quest directories, returning text/map bytes."""
    result = []
    for q in range(24):
        if q < 14:
            bank = banks[1 if q < 7 else 3]
            address = QUESTS[q // 7][q % 7]
        else:
            bank = banks[2 if q < 19 else 5]
            address = (0xD000 if q < 19 else 0xC000) + ((q - 14) % 5) * 0x8B0
        start = bank * SEG + address - 0xC000
        header = start + 0x462
        offset = int.from_bytes(rom[header:header + 2], 'little')
        size = int.from_bytes(rom[header + 2:header + 4], 'little')
        assert 0 < size <= 0x300, (q, size)
        text = rom[header + offset:header + offset + size]
        assert b'\xfa' in text and len(text) == size, q
        result.append((text, rom[start:start + 0x462], rom[header + 4:header + offset]))
    return result


def static_checks(rom, sym):
    es, en = bank_tables(rom, sym)
    a, b = briefings(rom, es), briefings(rom, en)
    for q, (old, new) in enumerate(zip(a, b)):
        assert old[0] != new[0], f'quest {q}: untranslated briefing'
        assert old[1:] == new[1:], f'quest {q}: map/event/monster/object data changed'
    # Existing Spanish fixes and all original quest bytes must be retained.
    original = ZX_ORIG
    for index, file, transform, offset in (
        (1, 'block06_flag0B.bin', caos, 0x1000),
        (3, 'block07_flag0C.bin', lambda x: fix_briefing10(caos(x)), 0),
    ):
        data = bytes(transform((original / file).read_bytes()))
        start = es[index] * SEG + offset
        assert rom[start:start + len(data)] == data, 'Spanish quest data changed'
    return es, en


def run_case(language, machine, cheat, opl4):
    name = f'language-{language}-{machine}-' + ('cheat' if cheat else 'normal')
    prefix = OUT / name
    report = prefix.with_suffix('.checks')
    report.unlink(missing_ok=True)
    syms = symbols(ROOT / 'build/runtime.sym')
    syms.update(symbols(ROOT / 'build/intro.sym'))
    rom_name = 'heroquest-cheat' if cheat else 'heroquest'
    rom = (ROOT / f'build/{rom_name}.rom').read_bytes()
    tables = static_checks(rom, syms)
    banks = tables[language == 'en']
    quests = briefings(rom, banks)
    script = (ROOT / 'tools/check_languages.tcl').read_text()
    replacements = {
        '@LANGUAGE@': str(int(language == 'en')),
        '@SYMBOLS@': ' '.join(f'{k} {v}' for k, v in syms.items() if '.' not in k),
        '@BANKS@': banks.hex(),
        '@QUESTS@': '\n'.join('{' + text.hex() + '}' for text, _, _ in quests),
        '@MENU@': ('PLAY' if language == 'en' else 'JUGAR').encode().hex(),
        '@HERO@': ('BARBARIAN' if language == 'en' else '_BARBARO_').encode().hex(),
        '@CODE@': ('HERO_CODE' if language == 'en' else 'CODIGO_DEL_HEROE').encode().hex(),
        '@OPL4@': str(int(opl4)),
        '@HZ60@': str(int(machine == 'Panasonic_FS-A1GT')),
    }
    for token, value in replacements.items():
        script = script.replace(token, value)
    tcl = prefix.with_suffix('.tcl')
    tcl.write_text(script)
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
               HQ_OUT=str(prefix), HQ_SECS='240',
               HQ_TCL=f'0.1 {{source {tcl}}}')
    command = ['openmsx', '-machine', machine, '-carta', f'build/{rom_name}.rom',
               '-romtype', 'ASCII16', '-command', 'set renderer none',
               '-script', 'tools/boot_test.tcl']
    if opl4:
        command += ['-ext', 'moonsound']
    r = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                       text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert report.exists(), r.stderr
    content = report.read_text()
    assert 'FAIL' not in content and 'PASS: 24 bilingual quest loaders' in content, content + r.stderr
    print(f'{language.upper()} {machine} {rom_name} {"OPL4" if opl4 else "PSG"}: selector, intro, menu, 24 briefings passed')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for case in (
        ('es', 'Philips_NMS_8250', False, False),
        ('en', 'Philips_NMS_8250', False, True),
        ('es', 'Panasonic_FS-A1GT', True, False),
        ('en', 'Panasonic_FS-A1GT', True, True),
    ):
        run_case(*case)


if __name__ == '__main__':
    main()
