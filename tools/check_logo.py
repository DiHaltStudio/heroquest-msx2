#!/usr/bin/env python3
"""Verify both logo fanfares on 50/60 Hz MSX machines in headless openMSX.

Run after make all. Inputs are driven by program breakpoints, not delays.
The test compares every PSG/OPL4 write with the compiled source, checks OPL4
sample RAM, timing, unskippable playback, silence and the opening/selector.
"""
import os
from pathlib import Path
import subprocess

from build_rom import symbols
from build_logo_psg import data as psg_data
from build_fanfare import decode_stream

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/test'


def psg_writes(stream):
    """Decode source events as (zero-based tick, register, effective value)."""
    tick, cursor, writes = 0, 0, []
    while cursor < len(stream):
        register = stream[cursor]
        cursor += 1
        if register == 0xFF:
            assert cursor == len(stream)
            return writes, tick
        if register & 0x80:
            assert register != 0x80
            tick += register & 0x7F
            continue
        assert register <= 13 and cursor < len(stream)
        value = stream[cursor]
        cursor += 1
        if register == 7:
            value = (value & 0x3F) | 0x80
        writes.append((tick, register, value))
    raise AssertionError('PSG stream has no end marker')


def run_case(machine, opl4):
    syms = symbols(ROOT / 'build/runtime.sym')
    syms.update(symbols(ROOT / 'build/intro.sym'))
    syms.update(symbols(ROOT / 'build/logo.sym'))
    stream, psg_ticks = psg_data()
    assert stream == (ROOT / 'build/logo_psg.bin').read_bytes(), 'stale PSG build'
    psg, decoded_ticks = psg_writes(stream)
    assert decoded_ticks == psg_ticks == 471
    opl, opl_ticks = decode_stream((ROOT / 'assets/sound/dihalt.mus').read_bytes())
    assert opl_ticks == 500
    expected_ticks = opl_ticks if opl4 else psg_ticks
    # The final stop follows playback on the last tick, before logo_done.
    silence = [(8, 0), (9, 0), (10, 0), (7, 0xBF)]
    psg = ([] if opl4 else psg) + [(expected_ticks - 1, reg, value) for reg, value in silence]
    opl = (opl + [(expected_ticks - 1, 0x7E, reg, 0) for reg in range(0x68, 0x80)]) if opl4 else []
    name = f'logo-{machine}-' + ('opl4' if opl4 else 'psg')
    prefix = OUT / name
    report = prefix.with_suffix('.checks')
    report.unlink(missing_ok=True)
    template = (ROOT / 'tools/check_logo.tcl').read_text()
    substitutions = {
        '@SYMBOLS@': ' '.join(f'{k} {v}' for k, v in syms.items() if '.' not in k),
        '@TICKS@': str(expected_ticks),
        '@OPL4@': str(int(opl4)),
        '@HZ60@': str(int(machine == 'Panasonic_FS-A1GT')),
        '@PSG@': '\n'.join('{' + ' '.join(map(str, item)) + '}' for item in psg),
        '@OPL@': '\n'.join('{' + ' '.join(map(str, item)) + '}' for item in opl),
        '@PCM@': (ROOT / 'assets/sound/dihalt.pcm').read_bytes().hex() if opl4 else '',
    }
    for token, value in substitutions.items():
        template = template.replace(token, value)
    tcl = prefix.with_suffix('.tcl')
    tcl.write_text(template)
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy', HQ_OUT=str(prefix))
    command = ['openmsx', '-machine', machine, '-carta', 'build/heroquest.rom',
               '-romtype', 'ASCII16', '-command', 'set renderer none', '-script', str(tcl)]
    if opl4:
        command += ['-ext', 'moonsound']
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=60)
    assert result.returncode == 0, result.stderr
    assert report.exists(), result.stderr
    content = report.read_text()
    assert 'FAIL' not in content and 'PASS: fanfare, opening and selector' in content, content + result.stderr
    print(f'{machine} {"OPL4" if opl4 else "PSG"}: {expected_ticks} ticks, '
          f'{len(psg)} PSG / {len(opl)} OPL4 writes, silence and boot flow passed')
    return float(next(line.split()[1] for line in content.splitlines() if line.startswith('DURATION ')))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for opl4 in (False, True):
        durations = [run_case(machine, opl4) for machine in ('Philips_NMS_8250', 'Panasonic_FS-A1GT')]
        assert abs(durations[0] - durations[1]) < 0.04, ('frame-rate dependent fanfare', durations)


if __name__ == '__main__':
    main()
