"""The ten quests of the expansion "Return of the Witch Lord" for the ROM
build: quests 14-23 of the game.

The quest data comes from the expansion program (ZX/orig/rotwl/: bank1.bin
with its quests 0-4, bank3.bin with quests 5-9, and the pointer table in the
overlay of bank6.bin), in the format of the base game: 400h bytes of map,
then the block that the quest loader copies (hero starts, room tables, a
directory and the briefing, the monster records and the object list). The
briefing is replaced by assets/expansion/briefings_<language>.txt.
Each quest is stored again as 400h + 4B0h bytes, five per "bank" image, at
the addresses the loader expects (bank 1 from D000h, bank 3 from C000h).
"""
import os
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
from original_paths import ZX_ORIG
SRC = str(ZX_ORIG / "rotwl")
TEXTS = os.path.join(ROOT, 'assets', 'expansion', 'briefings_es.txt')
PTRS = 0x65CC               # pointer table in the expansion overlay (runs at 5B00h, stored at 1B58h of bank 6)
MAP, BLOCK, HEAD = 0x400, 0x4B0, 12 + 0x56      # hero starts and room tables come before the directory
FIRST = 14                  # number of the first expansion quest in the game
BOXES = os.path.join(ROOT, 'assets', 'expansion', 'boxes_es.txt')
XDATA = 0xEC00              # texts of the expansion, after the quests of the second bank image
EVENT_BASE = 18             # the search events 1-11 of the expansion are events 19-29 of the game
CODES = {' ': 0x5F, ',': 0x3B, '.': 0x3A, '"': 0x3D}


def glyphs(s):
    out = bytearray()
    for c in s:
        if c in CODES:
            out.append(CODES[c])
        elif c.isdigit() or 'A' <= c <= 'Z':
            out.append(ord(c))
        else:
            raise SystemExit('text character %r is not in the game font' % c)
    return bytes(out)


def text_path(kind, language):
    assert language in ('es', 'en'), language
    return os.path.join(ROOT, 'assets', 'expansion', kind + '_' + language + '.txt')


def briefings(language='es', path=None):
    """{quest: (title, [paragraph, ...])}"""
    out, cur = {}, None
    for line in open(path or text_path('briefings', language), encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#'):
            continue
        if line.startswith('=='):
            n, title = line[2:].split(':', 1)
            cur = out[int(n)] = (title.strip(), [])
        elif cur is not None:
            if line.strip():
                cur[1].append(line.strip())
    return out


def briefing_bytes(title, paragraphs):
    """PrintString stream: title in colour 3 on text row 0, the paragraphs
    in colour 6 from row 3 or 4, wrapped at 32 columns, lines centred, one
    empty row between paragraphs."""
    rows = []
    for k, p in enumerate(paragraphs):
        if k:
            rows.append('')
        rows += textwrap.wrap(p, 32)
    first = 4 if len(rows) <= 17 else 3
    if first + len(rows) > 22:              # too long: no empty rows
        rows = [r for r in rows if r]
        first = 3
    assert first + len(rows) <= 22, 'briefing "%s" does not fit the screen' % title
    out = bytearray([0xFB, 3, 0xFF, (32 - len(title)) // 2, 0]) + glyphs(title) + bytes([0xFB, 6])
    for k, r in enumerate(rows):
        if r:
            out += bytes([0xFF, (32 - len(r)) // 2, first + k]) + glyphs(r)
    return bytes(out) + b'\xFA'


def boxes(language='es'):
    """[(name, bytes)]: text windows as DrawTextBox wants them: column, row,
    width, height, then the characters row by row."""
    out, cur = [], None
    for line in open(text_path('boxes', language), encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#'):
            continue
        if line.startswith('['):
            name, row = line.strip('[]').split()
            cur = [name, int(row), []]
            out.append(cur)
        elif cur is not None and line.strip():
            cur[2].append(line.strip())
    res = []
    for name, row, lines in out:
        w = max(len(l) for l in lines)
        data = bytes([(32 - w) // 2, row, w, len(lines)])
        for l in lines:
            data += glyphs(l.center(w))
        res.append((name, data))
    return res


def epilogue(language='es'):
    """[[chunk, ...] per page]: PrintString streams of at most 120 bytes,
    each ending with FAh: title in colour 6, text in colour 5 from row 2,
    "PULSA FUEGO PARA CONTINUAR" in colour 3 on row 21."""
    pages, cur = [], None
    for line in open(text_path('epilogue', language), encoding='utf-8'):
        line = line.strip()
        if line.startswith('#'):
            continue
        if line.startswith('=='):
            cur = []
            pages.append(cur)
        elif cur is not None and line:
            cur.append(line)
    out = []
    for n, paragraphs in enumerate(pages):
        items = []                              # (colour, row, text)
        if n == 0:
            items.append((6, 0, paragraphs[0]))
            paragraphs = paragraphs[1:]
        row = 2
        for k, p in enumerate(paragraphs):
            for l in textwrap.wrap(p, 32):
                items.append((5, row, l))
                row += 1
            row += 1
        assert row <= 21, 'epilogue page %d does not fit' % (n + 1)
        items.append((3, 21, 'PULSA FUEGO PARA CONTINUAR' if language == 'es'
                      else 'PRESS FIRE TO CONTINUE'))
        chunks, cur_chunk, colour = [], bytearray(), None
        for col, r, text in items:
            piece = bytes([0xFF, (32 - len(text)) // 2, r]) + glyphs(text)
            if len(cur_chunk) + len(piece) + 3 > 120:
                chunks.append(bytes(cur_chunk) + b'\xFA')
                cur_chunk, colour = bytearray(), None
            if col != colour:
                cur_chunk += bytes([0xFB, col])
                colour = col
            cur_chunk += piece
        chunks.append(bytes(cur_chunk) + b'\xFA')
        out.append(chunks)
    return out


def build(language='es'):
    """Returns (image of the first bank segment, image of the second, the
    ten quest addresses)."""
    bank = [open(os.path.join(SRC, 'bank1.bin'), 'rb').read(), open(os.path.join(SRC, 'bank3.bin'), 'rb').read()]
    base = [0xD000, 0xC000]
    ov = open(os.path.join(SRC, 'bank6.bin'), 'rb').read()
    texts = briefings(language)
    images, ptrs = [bytearray(b'\xFF' * 0x4000), bytearray(b'\xFF' * 0x4000)], []
    for q in range(10):
        b = q // 5
        o = PTRS - 0x5B00 + 0x1B58 + 2 * q
        src = (ov[o] | ov[o + 1] << 8) - base[b]
        rec = bytearray(bank[b][src:src + MAP + BLOCK])
        rec += bytes(MAP + BLOCK - len(rec))
        for k in range(MAP + 12, MAP + HEAD):   # the two tables of search events, one byte per room
            if rec[k] not in (0, 0xFF):
                rec[k] += EVENT_BASE
        d = MAP + HEAD                      # directory: text offset, length, monsters, objects
        toff = rec[d] | rec[d + 1] << 8
        mlen = rec[d + 6] | rec[d + 7] << 8     # monster records: the game has room for 32
        if mlen > 320:                          # (the original drops the rest as well)
            rec[d + 6], rec[d + 7] = 320 & 255, 320 >> 8
        text = briefing_bytes(*texts[FIRST + q])
        room = BLOCK - HEAD - toff
        assert len(text) <= min(room, 0x300), 'briefing of quest %d: %d bytes, room for %d' % (FIRST + q, len(text), room)
        rec[d + toff:] = text + bytes(room - len(text))
        rec[d + 2], rec[d + 3] = len(text) & 255, len(text) >> 8
        addr = base[b] + (q % 5) * (MAP + BLOCK)
        images[b][addr - 0xC000:addr - 0xC000 + len(rec)] = rec
        ptrs.append(addr)
    inc, a = [], XDATA
    for name, data in boxes(language):
        images[1][a - 0xC000:a - 0xC000 + len(data)] = data
        inc.append('XBOX_%-12s equ 0x%04X' % (name.upper(), a))
        inc.append('XBOX_%-12s equ %d' % (name.upper() + '_N', len(data)))
        a += len(data)
    inc.append('r2_epilogue:                ; chunks of the epilogue: address, length; 0,0 ends a page; 0,1 ends it')
    # Keep the runtime epilogue pointer table the same size in both languages.
    # Blank chunks terminate immediately and do not alter the displayed page.
    pages = epilogue(language)
    reference = epilogue('es')
    assert len(pages) == len(reference)
    for chunks, spanish in zip(pages, reference):
        assert len(chunks) <= len(spanish), 'English epilogue needs too many chunks'
        chunks = chunks + [b'\xFA'] * (len(spanish) - len(chunks))
        for data in chunks:
            images[1][a - 0xC000:a - 0xC000 + len(data)] = data
            inc.append('        dw 0x%04X, %d' % (a, len(data)))
            a += len(data)
        inc.append('        dw 0, 0')
    inc[-1] = '        dw 0, 1'
    assert a <= 0xF800, 'expansion text overlaps the hero-code program'
    return bytes(images[0]), bytes(images[1]), ptrs, inc


if __name__ == '__main__':
    a, b, ptrs, inc = build()
    print(' '.join('%04X' % p for p in ptrs))
    for q, (title, paragraphs) in sorted(briefings().items()):
        print(q, title, len(briefing_bytes(title, paragraphs)))
