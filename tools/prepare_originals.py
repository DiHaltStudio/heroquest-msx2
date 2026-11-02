#!/usr/bin/env python3
"""Extract the required payloads from user-supplied HeroQuest TZX tapes.

Usage: python3 tools/prepare_originals.py BASE.tzx WITCH_LORD_SIDE1.tzx
The destination follows ORIGINAL_DIR or HEROQUEST_ZX_ORIG. Tapes and extracted
payloads stay outside the public repository. Only recognized hashes are saved.
"""
import argparse
from hashlib import sha256
from pathlib import Path

from check_originals import EXPECTED, main as check_originals
from original_paths import ZX_ORIG


def tape_blocks(path):
    data = path.read_bytes()
    if not data.startswith(b'ZXTape!\x1a'):
        raise ValueError(f'{path.name}: expected a TZX tape')
    pos = 10
    while pos < len(data):
        kind = data[pos]
        pos += 1
        if kind in (0x10, 0x11, 0x14):
            header, length_offset, length_bytes = {
                0x10: (4, 2, 2), 0x11: (18, 15, 3), 0x14: (10, 7, 3)
            }[kind]
            size = int.from_bytes(data[pos + length_offset:pos + length_offset + length_bytes], 'little')
            end = pos + header + size
            if end > len(data):
                raise ValueError(f'{path.name}: truncated tape data')
            block = data[pos + header:end]
            # TZX data includes the flag byte and final XOR checksum.
            if len(block) >= 2:
                checksum = 0
                for value in block:
                    checksum ^= value
                if checksum == 0:
                    yield block[1:-1]
            pos = end
        elif kind in (0x20, 0x23):
            pos += 2
        elif kind in (0x21, 0x30):
            pos += 1 + data[pos]
        elif kind in (0x22, 0x25, 0x27):
            pass
        elif kind == 0x31:
            pos += 2 + data[pos + 1]
        elif kind == 0x32:
            pos += 2 + int.from_bytes(data[pos:pos + 2], 'little')
        elif kind == 0x33:
            pos += 1 + 3 * data[pos]
        elif kind == 0x35:
            pos += 20 + int.from_bytes(data[pos + 16:pos + 20], 'little')
        elif kind == 0x5A:
            pos += 9
        else:
            raise ValueError(f'{path.name}: unsupported TZX block {kind:02X} at {pos - 1}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tapes', type=Path, nargs='+')
    args = parser.parse_args()
    wanted = {digest: name for name, (_, digest) in EXPECTED.items()}
    found = {}
    for tape in args.tapes:
        for payload in tape_blocks(tape):
            digest = sha256(payload).hexdigest()
            if digest in wanted:
                found[wanted[digest]] = payload
    missing = sorted(set(EXPECTED) - found.keys())
    if missing:
        raise SystemExit('The supplied tapes do not contain these supported payloads: ' +
                         ', '.join(missing) + '. See docs/BUILDING.md for the required editions.')
    for name, payload in found.items():
        target = ZX_ORIG / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        print('Extracted ' + name)
    check_originals()


if __name__ == '__main__':
    main()
