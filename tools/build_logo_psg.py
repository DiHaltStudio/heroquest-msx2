#!/usr/bin/env python3
"""Compile the DiHalt logo fanfare used by Mad Mix 2 into a 50 Hz PSG stream.

The selected source frames are identical to Mad Mix 2: [0,384), [432,469).
The two omitted echoes and the start of the next repetition stay omitted.
421 music ticks plus 50 silent logo-hold ticks = 471 ticks, or 9.42 seconds.

Stream format (no header):
    00..0D, value  Write one AY/PSG sound register.
    81..FE        Wait (opcode & 7Fh) ticks at 50 Hz (1..126 ticks).
    FF            End. Do not read beyond it.
Register 7 values contain the VGM mixer bits, NOT MSX port directions. The
player must merge (value & 3Fh) with the current register-7 bits C0h (normally
80h on MSX). Never write VGM values directly to register 7, and never write
registers 14/15. Silence at frame 468 is already present in the source.

One player call per 50 Hz tick: if wait != 0, decrement it and return;
otherwise consume register writes until WAIT, store n-1 and return. END
returns without further writes. On a 60 Hz machine use five ticks per six
VBlanks. After 471 ticks, explicitly silence channels 8..10 and set the
mixer sound bits to 3Fh while preserving register 7's port-direction bits.
"""
import argparse
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets' / 'sound' / 'dihalt_psg.vgm'
KEEP = ((0, 384), (432, 469))
MUSIC_FRAMES = sum(end - start for start, end in KEEP)
SILENT_HOLD_FRAMES = 50
TOTAL_FRAMES = MUSIC_FRAMES + SILENT_HOLD_FRAMES
HZ = 50
SAMPLES_PER_TICK = 44100 // HZ


def source_frames(path=SOURCE):
    """Read AY writes grouped into 50 Hz ticks, as in Mad Mix 2's compiler."""
    path = Path(path)
    raw = path.read_bytes()
    if len(raw) < 0x40 or raw[:4] != b'Vgm ':
        raise ValueError(f'{path}: not a complete VGM header')
    version = struct.unpack_from('<I', raw, 8)[0]
    offset = struct.unpack_from('<I', raw, 0x34)[0] if version >= 0x150 else 0
    cursor = 0x34 + offset if offset else 0x40
    frames, samples = [[]], 0
    while cursor < len(raw):
        command = raw[cursor]
        cursor += 1
        if command == 0x66:
            return frames
        if command == 0xA0:
            if cursor + 2 > len(raw):
                raise ValueError(f'{path}: truncated AY write')
            register, value = raw[cursor:cursor + 2]
            cursor += 2
            if register > 13:
                raise ValueError(f'{path}: unsupported AY register {register}')
            frames[-1].append((register, value))
            continue
        if command == 0x61:
            if cursor + 2 > len(raw):
                raise ValueError(f'{path}: truncated wait')
            wait = struct.unpack_from('<H', raw, cursor)[0]
            cursor += 2
        elif command == 0x62:
            wait = 735
        elif command == 0x63:
            wait = 882
        elif 0x70 <= command <= 0x7F:
            wait = command - 0x6F
        else:
            raise ValueError(f'{path}: unsupported VGM command {command:02X} at {cursor-1:X}')
        before = samples // SAMPLES_PER_TICK
        samples += wait
        frames.extend([] for _ in range(samples // SAMPLES_PER_TICK - before))
    raise ValueError(f'{path}: missing VGM end command')


def data(path=SOURCE):
    """Return (stream bytes, total 50 Hz ticks), including the silent hold."""
    frames = source_frames(path)
    state, stream = {}, bytearray()
    pending = played = 0

    def flush_wait():
        nonlocal pending
        while pending:
            # FFh is END, so the longest wait is FEh (126), never FFh.
            count = min(pending, 126)
            stream.append(0x80 + count)
            pending -= count

    for start, end in KEEP:
        if not 0 <= start < end <= len(frames):
            raise ValueError(f'{path}: fanfare selection {start}:{end} exceeds source')
        full_state = {}
        for writes in frames[:start]:
            full_state.update(writes)
        # Restore changed state across the editorial cut, but never retrigger
        # an envelope merely because an earlier envelope shape was selected.
        restore = [(reg, value) for reg, value in sorted(full_state.items())
                   if reg != 13 and state.get(reg) != value]
        for frame in range(start, end):
            writes = (restore if frame == start else []) + frames[frame]
            if writes:
                flush_wait()
                for register, value in writes:
                    stream.extend((register, value))
                    state[register] = value
            pending += 1
            played += 1
    if any(state.get(register, 0) != 0 for register in (8, 9, 10)):
        raise ValueError(f'{path}: selected fanfare does not end with silent channels')
    pending += SILENT_HOLD_FRAMES
    flush_wait()
    stream.append(0xFF)
    assert played == MUSIC_FRAMES
    return bytes(stream), played + SILENT_HOLD_FRAMES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--output', type=Path, default=ROOT / 'build' / 'logo_psg.bin')
    args = parser.parse_args()
    stream, ticks = data(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(stream)
    args.output.with_suffix('.json').write_text(json.dumps({
        'source': 'assets/sound/dihalt_psg.vgm',
        'source_frame_ranges': KEEP,
        'music_frames': MUSIC_FRAMES,
        'silent_hold_frames': SILENT_HOLD_FRAMES,
        'total_frames': ticks,
        'hz': HZ,
        'seconds': ticks / HZ,
        'stream_bytes': len(stream),
        'register_7': 'preserve live bits 7-6; replace only mixer bits 5-0',
    }, indent=2) + '\n')
    print(f'{args.output}: {len(stream)} bytes, {ticks} ticks at {HZ} Hz ({ticks/HZ:.2f} s)')


if __name__ == '__main__':
    main()
