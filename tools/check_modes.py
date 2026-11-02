#!/usr/bin/env python3
"""Check cheat combat/damage and intro timing in headless openMSX.

Run after `make all cheat-rom`: .venv/bin/python tools/check_modes.py
"""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build' / 'test'


def run(name, machine, rom, keys, commands, opl4=False):
    prefix = OUT / name
    for suffix in ('.checks', '.timing', '.txt'):
        prefix.with_suffix(suffix).unlink(missing_ok=True)
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
               HQ_OUT=str(prefix), HQ_SECS='300', HQ_KEYS=keys, HQ_TCL=commands)
    command = ['openmsx', '-machine', machine, '-carta', f'build/{rom}.rom',
               '-romtype', 'ASCII16', '-command', 'set renderer none',
               '-script', 'tools/boot_test.tcl']
    if opl4:
        command += ['-ext', 'moonsound']
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                            text=True, timeout=60)
    assert result.returncode == 0, result.stderr
    return prefix


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for opl4 in (False, True):
        mode = 'opl4' if opl4 else 'psg'
        prefix = run('cheat-' + mode, 'Philips_NMS_8250', 'heroquest-cheat',
                     '18 space/0.5 21 space/0.5 24 space/0.5 28 space/0.5 33 space/0.5 '
                     '39 space/0.5 44 space/0.5 48 space/0.5',
                     '6 {source tools/cheat_check.tcl} '
                     '30 {poke 0x8FE6 0; poke 0x8FE7 0}', opl4)
        report = prefix.with_suffix('.checks').read_text()
        assert 'FAIL' not in report and 'PASS: all 21 cheat cases' in report, report
        print(f'{mode}: 21 combat and damage cases passed')

    durations = []
    for machine in ('Philips_NMS_8250', 'Panasonic_FS-A1GT'):
        prefix = run('intro-' + machine, machine, 'heroquest', '21 space/0.5 24 space/0.5',
                     '6 {source tools/intro_timing_check.tcl}')
        report = prefix.with_suffix('.timing').read_text()
        waits = re.findall(r'wait (\d+) ticks ([\d.]+) seconds', report)
        assert len(waits) == 43, report
        for ticks, seconds in waits:
            assert abs(float(seconds) - int(ticks) / 50) < 0.04, report
        start = float(re.search(r'music starts ([\d.]+)', report)[1])
        end = float(re.search(r'intro ends ([\d.]+)', report)[1])
        durations.append(end - start)
        print(f'{machine}: 43 waits at 50 Hz; intro {end-start:.2f} seconds')
    assert abs(durations[0] - durations[1]) < 2, durations


if __name__ == '__main__':
    main()
