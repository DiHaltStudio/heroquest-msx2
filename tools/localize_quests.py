"""English base-game briefings without changing any quest or event address.

Both arguments to translate_banks are complete 16 KiB bank images based at
C000h (the first bank's original data starts at D000h). Only the briefing
bytes and their two-byte length fields may change. The readable English
source is assets/lang/briefings_en.txt; all other data is shared with Spanish.
"""
from pathlib import Path
from build_expansion import briefings, briefing_bytes

ROOT = Path(__file__).resolve().parents[1]
# Addresses from the original quest pointer table at overlay address 6637h.
QUESTS = (
    (0xD000, 0xD678, 0xDD79, 0xE3F8, 0xEA75, 0xF1D4, 0xF94A),
    (0xC000, 0xC70F, 0xCE4E, 0xD51C, 0xDD46, 0xE4DC, 0xEC91),
)


def translate_banks(bank1, bank3):
    """Return English (bank1, bank3), retaining every non-text byte."""
    texts = briefings('en', ROOT / 'assets/lang/briefings_en.txt')
    assert set(texts) == set(range(14)), 'all 14 base briefings are required'
    result = []
    for bank_index, source in enumerate((bank1, bank3)):
        assert len(source) == 0x4000, 'expected a full C000h-FFFFh bank image'
        data = bytearray(source)
        for index, address in enumerate(QUESTS[bank_index]):
            quest = bank_index * 7 + index
            header = address - 0xC000 + 0x462
            offset = int.from_bytes(data[header:header + 2], 'little')
            size = int.from_bytes(data[header + 2:header + 4], 'little')
            start = header + offset
            text = briefing_bytes(*texts[quest])
            assert 0 < size <= 0x300 and start + size <= 0x4000
            assert len(text) <= size, (
                f'quest {quest}: English briefing needs {len(text)}, only {size} bytes available')
            # Clear leftovers of the source translation. Keep the record and
            # every following pointer in exactly the same position.
            data[start:start + size] = text + bytes(size - len(text))
            data[header + 2:header + 4] = len(text).to_bytes(2, 'little')
        assert len(data) == len(source)
        result.append(bytes(data))
    return tuple(result)
