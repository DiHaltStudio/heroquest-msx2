"""English variants of the resident game and its menu overlay.

Apply AFTER the normal MSX patches (and the Spanish CHAOS -> CAOS fix).
Every replacement is tied to an address and exact source bytes. Sizes,
terminators, pointers, dynamic fields and the surrounding code stay in place.
The editable catalog is assets/lang/base_en.json. English YES hitboxes are
one cell wider, matching their three letters.
"""
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / 'assets/lang/base_en.json'
CODES = {' ': 0x5F, '.': 0x3A, ',': 0x3B}


def encode(text):
    """Strict game-font encoding; reject unsupported punctuation/accents."""
    out = bytearray()
    for char in text:
        if char in CODES:
            out.append(CODES[char])
        elif 'A' <= char <= 'Z' or '0' <= char <= '9':
            out.append(ord(char))
        else:
            raise ValueError(f'Unsupported game-font character: {char!r}')
    return bytes(out)


def translate(data, part, base):
    result = bytearray(data)
    occupied = set()
    for entry in json.loads(CATALOG.read_text())[part]:
        address = int(entry['address'], 16)
        offset = address - base
        source = bytes.fromhex(entry['source'])
        size = len(source)
        assert 0 <= offset <= len(result) - size, f'{part}:{address:04X} outside image'
        assert not occupied.intersection(range(offset, offset + size)), f'{part}:{address:04X} overlaps another translation'
        occupied.update(range(offset, offset + size))
        actual = bytes(result[offset:offset + size])
        assert actual == source, f'{part}:{address:04X}: expected {source.hex()}, found {actual.hex()}'
        if 'english_bytes' in entry:
            replacement = bytes.fromhex(entry['english_bytes'])
            assert len(replacement) == size
        else:
            replacement = encode(entry['english'])
            assert len(replacement) <= size, f'{part}:{address:04X}: translation does not fit'
            if entry.get('align', 'left') == 'center':
                replacement = replacement.center(size, b'\x5F')
            else:
                replacement = replacement.ljust(size, b'\x5F')
        result[offset:offset + size] = replacement
    assert len(result) == len(data)
    return bytes(result)


def translate_game(data):
    """Patched resident image, loaded at 6400h (segments 1-3)."""
    return translate(data, 'game', 0x6400)


def translate_overlay(bank6):
    """Patched whole bank 6: overlay at DB58h runs at 5B00h."""
    return translate(bank6, 'overlay', 0x5B00 - 0x1B58)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    rom = (root / 'build/heroquest.rom').read_bytes()
    translate_game(rom[0x4000:0x4000 + 39934])
    translate_overlay(rom[7 * 0x4000:8 * 0x4000])
    catalog = json.loads(CATALOG.read_text())
    print(f"Validated {len(catalog['game'])} game and {len(catalog['overlay'])} overlay translations")
