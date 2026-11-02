#!/usr/bin/env python3
"""Converts the user-supplied Amiga modules in ORIGINAL_DIR/Amiga/ for the OPL4 (MoonSound).

    build_music.py            hqintro.mod, hqgame.mod -> .mus and .pcm

For each module, tools/mod2vgm (compiled on the fly with gcc) plays it and
writes the OPL4 register writes as a VGM plus the image of the wave memory.
This script turns them into the two files the ROM build stores:

<name>.pcm  image for the OPL4 wave RAM, loaded at 200000h: 128 headers of
            12 bytes and the 8-bit samples.
<name>.mus  the register writes in 50 Hz ticks:
              3 bytes   offset of the loop point in the stream that follows
              n (1-251), then n times: address port (C4h FM bank 0, C6h FM
                        bank 1, 7Eh wave), register, value: one tick
              FEh n     n ticks without writes
              FFh       end: go on at the loop point
The results are kept in assets/sound/ so that the ROM builds without gcc.
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUND = os.path.join(ROOT, 'assets', 'sound')
from original_paths import ORIGINAL_DIR
MODULES = ORIGINAL_DIR / 'Amiga'
MOD2VGM = os.path.join(ROOT, 'tools', 'mod2vgm')
TUNES = ['hqintro', 'hqgame']
SAMPLES_PER_TICK = 882          # 44.1 kHz / 50 Hz
PORTS = [0xC4, 0xC6, 0x7E]
MAX_WRITES = 251


def u32(buf, pos):
    return int.from_bytes(buf[pos:pos + 4], 'little')


def parse_vgm(data):
    """OPL4 writes of a VGM as (time in samples, port 0-2, register, value),
    the duration and the index of the first write of the loop."""
    assert data[:4] == b'Vgm ', 'not a VGM file'
    pos = 0x34 + u32(data, 0x34) if u32(data, 0x34) else 0x40
    loop_abs = 0x1C + u32(data, 0x1C) if u32(data, 0x1C) else None
    time, writes, loop_index = 0, [], None
    while True:
        if pos == loop_abs:
            loop_index = len(writes)
        op = data[pos]
        pos += 1
        if op == 0xD0:
            port, reg, value = data[pos:pos + 3]
            writes.append((time, port, reg, value))
            pos += 3
        elif op == 0x61:
            time += int.from_bytes(data[pos:pos + 2], 'little')
            pos += 2
        elif op == 0x62:
            time += 735
        elif op == 0x63:
            time += 882
        elif 0x70 <= op <= 0x7F:
            time += (op & 15) + 1
        elif op == 0x67 and data[pos] == 0x66:
            pos += 6 + (u32(data, pos + 2) & 0x7FFFFFFF)
        elif op == 0x66:
            break
        else:
            raise ValueError('unsupported VGM command %02X at %06X' % (op, pos - 1))
    return writes, time, loop_index or 0


def pack_stream(vgm):
    writes, duration, loop_index = parse_vgm(vgm)
    ticks = [(t + SAMPLES_PER_TICK // 2) // SAMPLES_PER_TICK for t, *_ in writes]
    loop_tick = ticks[loop_index] if loop_index < len(ticks) else 0
    # the set-up of the chip (first tick) must not be repeated on every loop
    if 0 < loop_index and ticks[loop_index - 1] == loop_tick:
        for i in range(loop_index, len(ticks)):
            ticks[i] += 1
        loop_tick += 1
    frames = {}
    for tick, (_, port, reg, value) in zip(ticks, writes):
        frames.setdefault(tick, []).append((PORTS[port], reg, value))
    last = max((duration + SAMPLES_PER_TICK - 1) // SAMPLES_PER_TICK, max(ticks))
    body = bytearray()
    loop_off = 0
    tick = 0
    while tick <= last:
        if tick == loop_tick:
            loop_off = len(body)
        group = frames.get(tick)
        if group:
            assert len(group) <= MAX_WRITES, 'too many writes in one tick'
            body.append(len(group))
            for w in group:
                body += bytes(w)
            tick += 1
            continue
        run = 1
        while run < 255 and tick + run <= last and tick + run not in frames and tick + run != loop_tick:
            run += 1
        body += bytes((0xFE, run))
        tick += run
    body.append(0xFF)
    return loop_off.to_bytes(3, 'little') + bytes(body), last, max(len(g) for g in frames.values())


def main():
    with tempfile.TemporaryDirectory() as work:
        exe = os.path.join(work, 'mod2vgm')
        src = sorted(os.path.join(MOD2VGM, f) for f in os.listdir(MOD2VGM) if f.endswith('.c'))
        subprocess.run(['gcc', '-fcommon', '-O2', '-w', '-o', exe] + src + ['-lm'], check=True)
        for name in TUNES:
            base = os.path.join(work, name)
            subprocess.run([exe, '-s', str(MODULES / (name + '.mod')), base], check=True,
                           stdout=subprocess.DEVNULL)
            stream, ticks, most = pack_stream(open(base + '.vgm', 'rb').read())
            pcm = open(base + '_samples.bin', 'rb').read()
            open(os.path.join(SOUND, name + '.mus'), 'wb').write(stream)
            open(os.path.join(SOUND, name + '.pcm'), 'wb').write(pcm)
            print('%-8s %6d bytes of stream (%d s, at most %d writes in a tick), %6d bytes of samples'
                  % (name, len(stream), ticks // 50, most, len(pcm)))


if __name__ == '__main__':
    main()
