#!/usr/bin/env python3
"""Build the logo's OPL4 fanfare from the local, self-contained VGM source.

assets/sound/dihalt_opl4.vgm -> dihalt.pcm + dihalt.mus

The type-87 VGM block addresses are relative to YMF278B RAM at 200000h.
Copy its entire payload unchanged: in particular, do not relocate the tone
384+ headers or the absolute sample addresses embedded in those headers.
The normal HeroQuest loader uploads the resulting image at 200000h.

The stream uses the existing 50 Hz OPL4 format from build_music.py. It ends
with FFh and has no source loop. The caller must set rt_opl_once=1, as for
the introduction, so the runtime stops instead of following its loop word.
No module compiler or files from another project are needed to rebuild it.
"""
import argparse
from hashlib import sha256
from pathlib import Path

from build_music import MAX_WRITES, PORTS, SAMPLES_PER_TICK, parse_vgm, u32

ROOT = Path(__file__).resolve().parents[1]
SOUND = ROOT / 'assets/sound'
# The fanfare works with the smallest MoonSound RAM configuration supported
# by this port. The source VGM declares a larger address space, not usage.
RAM_CAPACITY = 128 * 1024


def ram_image(data):
    """Extract initial YMF278B RAM blocks, validating every command boundary."""
    assert data[:4] == b'Vgm ', 'not a VGM file'
    assert len(data) >= 0x64 and u32(data, 0x60) == 33868800, 'expected one OPL4'
    assert u32(data, 0x1C) == 0, 'the logo fanfare must not loop'
    end = u32(data, 4) + 4
    assert end == len(data), 'invalid VGM file length'
    pos = 0x34 + u32(data, 0x34) if u32(data, 0x34) else 0x40
    blocks, elapsed = [], 0
    while pos < end:
        op = data[pos]
        pos += 1
        if op == 0x67:
            assert pos + 6 <= end and data[pos] == 0x66, 'invalid data block'
            kind = data[pos + 1]
            size = u32(data, pos + 2)
            assert kind == 0x87 and not (size & 0x80000000), 'expected single-chip OPL4 RAM'
            pos += 6
            assert size >= 8 and pos + size <= end, 'truncated RAM block'
            total, offset = u32(data, pos), u32(data, pos + 4)
            payload = data[pos + 8:pos + size]
            assert elapsed == 0, 'cannot preload RAM modified during playback'
            assert offset + len(payload) <= total, 'RAM block exceeds declared address space'
            assert offset + len(payload) <= RAM_CAPACITY, 'fanfare needs more than 128 KiB RAM'
            blocks.append((offset, payload))
            pos += size
        elif op == 0xD0:
            assert pos + 3 <= end and data[pos] < len(PORTS), 'invalid OPL4 write'
            pos += 3
        elif op == 0x61:
            assert pos + 2 <= end, 'truncated wait'
            elapsed += int.from_bytes(data[pos:pos + 2], 'little')
            pos += 2
        elif op in (0x62, 0x63):
            elapsed += 735 if op == 0x62 else 882
        elif 0x70 <= op <= 0x7F:
            elapsed += (op & 15) + 1
        elif op == 0x66:
            break
        else:
            raise ValueError(f'unsupported VGM command {op:02X} at {pos - 1:06X}')
    else:
        raise ValueError('VGM has no end command')
    assert blocks, 'fanfare has no embedded OPL4 samples'
    assert elapsed == u32(data, 0x18), 'VGM total-sample count differs from commands'
    ram = bytearray(max(offset + len(payload) for offset, payload in blocks))
    for offset, payload in blocks:
        ram[offset:offset + len(payload)] = payload
    return bytes(ram), elapsed


def decode_stream(stream):
    """Decode for a lossless register-order and frame-duration check."""
    assert stream[:3] == bytes(3), 'one-shot source has no loop offset'
    tick, pos, writes = 0, 3, []
    while pos < len(stream):
        count = stream[pos]
        pos += 1
        if count == 0xFF:
            assert pos == len(stream), 'bytes after stream end'
            return writes, tick
        if count == 0xFE:
            assert pos < len(stream) and stream[pos], 'invalid idle run'
            tick += stream[pos]
            pos += 1
        else:
            assert 1 <= count <= MAX_WRITES, 'invalid write count'
            for _ in range(count):
                assert pos + 3 <= len(stream), 'truncated register write'
                port, reg, value = stream[pos:pos + 3]
                assert port in PORTS
                writes.append((tick, port, reg, value))
                pos += 3
            tick += 1
    raise ValueError('stream has no end marker')


def validate_sample_headers(ram, writes):
    """Every RAM tone actually selected must address samples in our image."""
    high = [0] * 24
    used = set()
    for _, port, register, value in writes:
        if port != 2:
            continue
        if 0x20 <= register < 0x38:
            high[register - 0x20] = value & 1
        elif 0x08 <= register < 0x20:
            tone = value + 256 * high[register - 0x08]
            if tone >= 384:
                used.add(tone)
    assert used, 'source does not select its embedded RAM instruments'
    for tone in used:
        header = ram[(tone - 384) * 12:(tone - 383) * 12]
        assert len(header) == 12, f'missing tone {tone} header'
        address = int.from_bytes(header[:3], 'big') & 0x3FFFFF
        samples = 65536 - int.from_bytes(header[5:7], 'big')
        format_bits = header[0] >> 6
        assert format_bits < 3, f'unsupported sample format in tone {tone}'
        byte_length = (samples, (samples * 3 + 1) // 2, samples * 2)[format_bits]
        assert 0x200000 <= address and address + byte_length <= 0x200000 + len(ram), (
            f'tone {tone} points outside the embedded sample image')
    return used


def convert(data):
    """Return (PCM image, one-shot stream, frame count, maximum writes/frame)."""
    ram, duration = ram_image(data)
    writes, parsed_duration, _ = parse_vgm(data)
    assert duration == parsed_duration and writes, 'empty or inconsistent source'
    validate_sample_headers(ram, writes)
    quantized = [((time + SAMPLES_PER_TICK // 2) // SAMPLES_PER_TICK,
                  PORTS[port], reg, value) for time, port, reg, value in writes]
    frames = {}
    for tick, port, reg, value in quantized:
        frames.setdefault(tick, []).append((port, reg, value))
    most = max(map(len, frames.values()))
    assert most <= MAX_WRITES, f'{most} writes do not fit one runtime tick'
    # The source duration is an end boundary. A source write exactly at that
    # boundary still gets its own frame, but no extra blank frame is appended.
    count = max((duration + SAMPLES_PER_TICK - 1) // SAMPLES_PER_TICK,
                max(frames) + 1)
    body, tick = bytearray(), 0
    while tick < count:
        group = frames.get(tick)
        if group:
            body.append(len(group))
            for write in group:
                body.extend(write)
            tick += 1
        else:
            idle = 1
            while idle < 255 and tick + idle < count and tick + idle not in frames:
                idle += 1
            body.extend((0xFE, idle))
            tick += idle
    stream = bytes(3) + body + b'\xFF'
    decoded, frames_played = decode_stream(stream)
    assert decoded == quantized, 'conversion changed register writes or their order'
    assert frames_played == count, 'conversion changed frame count'
    return ram, bytes(stream), count, most


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='verify committed outputs without writing')
    args = parser.parse_args()
    source = (SOUND / 'dihalt_opl4.vgm').read_bytes()
    ram, stream, frames, most = convert(source)
    for suffix, payload in (('pcm', ram), ('mus', stream)):
        path = SOUND / ('dihalt.' + suffix)
        if args.check:
            assert path.read_bytes() == payload, f'{path.name} is stale; rebuild the fanfare'
        else:
            path.write_bytes(payload)
    print(f'dihalt: {frames} frames ({frames / 50:.2f} s), {len(stream)} stream bytes, '
          f'{len(ram)} RAM bytes, at most {most} writes/frame')
    print(f'VGM SHA-256: {sha256(source).hexdigest()}')


if __name__ == '__main__':
    main()
