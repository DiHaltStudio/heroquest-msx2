"""Intro data for the ROM build: the pictures of assets/intro/ as VRAM
blobs, and build/intro.inc with their palettes, the laid-out texts, the
animation tables and the script of src/intro_script.py as bytes for the
interpreter in src/intro.asm."""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INTRO = os.path.join(ROOT, 'assets', 'intro')
sys.path.insert(0, os.path.join(ROOT, 'src'))

# text layout of the original intro
TEXT_X, TEXT_COLUMNS = 42, 23
# the font in animations.png: A-Z . , : ; - on line 0; the accented vowels,
# the tilde n and the 4 on line 9 from x = 80, written a e i o u n 4
ROW0 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ.,:;-'
ROW1 = {c: 32 + 10 + i for i, c in enumerate('aeioun4')}
PICTURES = ['title', 'text_background', 'animations'] + ['scene%d' % n for n in range(6)] + ['title_en']
COMMANDS = ['end', 'cls', 'picture', 'palette', 'show', 'screen', 'wait', 'text', 'anim', 'music']
TITLE_CREDITS = (
    (90, 'JUEGO ORIGINAL', 2),
    (100, 'GREMLIN GRAPHICS 1991', 5),
    (119, 'PORT MSX2', 2),
    (129, 'DIHALT 2026', 5),
)


def load(name):
    im = Image.open(os.path.join(INTRO, name + '.png'))
    assert im.mode == 'P' and im.width == 256, '%s.png must be an indexed PNG 256 pixels wide' % name
    return im


def picture_bytes(im):
    px = im.load()
    out = bytearray()
    for y in range(im.height):
        for x in range(0, 256, 2):
            out.append((px[x, y] & 15) << 4 | (px[x + 1, y] & 15))
    return bytes(out)


def palette_bytes(im):
    p = im.getpalette()[:48]
    out = []
    for i in range(16):
        r, g, b = [(v * 7 + 127) // 255 for v in p[3 * i:3 * i + 3]]
        out += [r << 4 | b, g]
    return out


def title_with_credits(im, language='es'):
    """Draw the menu credits with the game's 8x8 font on the intro title."""
    im = im.copy()
    # Two pairs of title colours are identical. Keep the artwork unchanged
    # while giving those duplicate palette entries to the credits.
    im = im.point([0 if c == 2 else 4 if c == 5 else c for c in range(256)])
    palette = im.getpalette()
    palette[2 * 3:2 * 3 + 3] = [0, 182, 182]
    palette[5 * 3:5 * 3 + 3] = [255, 218, 36]
    im.putpalette(palette)

    font = Image.open(os.path.join(ROOT, 'assets', 'font.png'))
    src, dst = font.load(), im.load()
    for y, line, colour in TITLE_CREDITS:
        if language == 'en' and line == 'JUEGO ORIGINAL':
            line = 'ORIGINAL GAME'
        x0 = (im.width - 8 * len(line)) // 2
        for n, char in enumerate(line):
            if char == ' ':
                continue
            glyph = ord(char) - 0x30  # font.png contains codes 30h-74h
            assert 0 <= glyph < 69, 'missing title glyph: %s' % char
            sx, sy = 8 * (glyph % 16), 8 * (glyph // 16)
            x = x0 + 8 * n
            for dy in range(8):
                for dx in range(8):
                    if src[sx + dx, sy + dy]:
                        dst[x + dx + 1, y + dy + 1] = 0  # shadow over the artwork
                        dst[x + dx, y + dy] = colour
    return im


def layout(y, text, first_line):
    """Glyphs of a text as (x, y, glyph), wrapped like the original: a word
    that would reach the right margin starts a new line."""
    out = []
    x = TEXT_X
    y += first_line
    for word in text.split(' '):
        if word and x + 8 * len(word) >= TEXT_X + 8 * TEXT_COLUMNS:
            x, y = TEXT_X, y + 8
        for c in word:
            g = ROW0.index(c) if c in ROW0 else ROW1[c]
            out.append((x, y, g))
            x += 8
        x += 8
    return out


def data():
    """Returns (pictures as (name, first VRAM line, bytes), function that
    writes intro.inc once the ROM position of the pictures is known)."""
    anims = json.load(open(os.path.join(INTRO, 'animations.json')))
    first = {'title': anims['text_first_line'], 'title_en': anims['text_first_line'], 'text_background': anims['text_first_line'], 'animations': 0}
    for s in anims['scenes']:
        first[s['picture']] = s['first_line']
    texts = {}
    for language in ('es', 'en'):
        texts[language] = {}
        for line in open(os.path.join(INTRO, 'texts_' + language + '.txt'), encoding='utf-8'):
            if ':' in line:
                k, v = line.split(':', 1)
                texts[language][k.strip()] = v.strip()
    assert texts['es'].keys() == texts['en'].keys(), 'intro translation keys differ'
    images = {n: load(n) for n in PICTURES if n != 'title_en'}
    images['title_en'] = title_with_credits(images['title'], 'en')
    images['title'] = title_with_credits(images['title'])
    pictures = [('intro_' + n, first[n] * 128, picture_bytes(images[n])) for n in PICTURES]
    # the opening: 512 x 424, shown in SCREEN 7 with interlace. Its even
    # lines go to page 0 and its odd lines to page 1 (256 bytes per line);
    # the black lines above and below the picture are not stored
    opening = Image.open(os.path.join(INTRO, 'opening.png'))
    assert opening.mode == 'P' and opening.size == (512, 424), 'opening.png must be an indexed PNG of 512 x 424'
    opx = opening.load()
    used = [y for y in range(424) if any(opx[x, y] for x in range(512))]
    top, bottom = used[0] & ~1, (used[-1] | 1) + 1
    for field in (0, 1):
        rows = bytearray()
        for y in range(top + field, bottom, 2):
            for x in range(0, 512, 2):
                rows.append((opx[x, y] & 15) << 4 | (opx[x + 1, y] & 15))
        pictures.append(('intro_opening%d' % field, 0x10000 * field + (top // 2) * 256, bytes(rows)))

    def write(path, table):
        from intro_script import SCRIPT
        pos = {name: pieces for name, vaddr, pieces in table}
        inc = ['; Generated by tools/build_intro.py', '',
               'IN_TITLE_EN equ %d' % PICTURES.index('title_en')]
        inc.append('in_pictures:')
        inc += ['        dw in_pic_%s' % n for n in PICTURES]
        for n in PICTURES:
            v = first[n] * 128
            pieces = pos['intro_' + n]
            inc += ['in_pic_%s:' % n, '        db %d' % (v >> 14), '        dw 0x%04X' % (v & 0x3FFF),
                    '        db %d' % len(pieces)]
            for seg, addr, size in pieces:
                inc += ['        db %d' % seg, '        dw 0x%04X, 0x%04X' % (addr, size)]
        for field in (0, 1):
            name = 'intro_opening%d' % field
            v = [vaddr for n, vaddr, pieces in table if n == name][0]
            pieces = pos[name]
            inc += ['in_opening%d:' % field, '        db %d' % (v >> 14), '        dw 0x%04X' % (v & 0x3FFF),
                    '        db %d' % len(pieces)]
            for seg, addr, size in pieces:
                inc += ['        db %d' % seg, '        dw 0x%04X, 0x%04X' % (addr, size)]
        inc.append('in_opening_palette:')
        inc.append('        db ' + ','.join('0x%02X' % b for b in palette_bytes(opening)))
        inc.append('in_palettes:')
        for n in PICTURES:
            inc.append('        db ' + ','.join('0x%02X' % b for b in palette_bytes(images[n])) + '    ; ' + n)
        inc.append('in_anims:')
        inc += ['        dw in_anim_%d' % n for n in range(len(anims['scenes']))]
        for n, s in enumerate(anims['scenes']):
            inc += ['in_anim_%d:' % n, '        db %d,%d,%d       ; frames between copies, passes, frames'
                    % (s['frame_delay'], s['passes'], len(s['frames']))]
            for sx, sy, dx, dy, nx, ny in s['frames']:
                inc.append('        db %d,%d,%d,%d,%d,%d' % (sx, sy, dx, dy + s['first_line'], nx, ny))
        blocks, script = {'es': [], 'en': []}, []
        for cmd in SCRIPT:
            op = COMMANDS.index(cmd[0])
            if cmd[0] == 'picture':
                script.append([op, PICTURES.index(cmd[1]), cmd[2]])
            elif cmd[0] == 'palette':
                script.append([op, PICTURES.index(cmd[1])])
            elif cmd[0] == 'text':
                script.append([op, len(blocks['es']), cmd[1]])
                for language in ('es', 'en'):
                    glyphs = []
                    for k, (y, name) in enumerate(cmd[2]):
                        line = layout(y, texts[language][name], anims['text_first_line'])
                        bottom = max(yy + 8 for x, yy, g in line)
                        limit = cmd[2][k + 1][0] + anims['text_first_line'] if k + 1 < len(cmd[2]) else 192
                        assert bottom <= limit, '%s: %s overlaps the next paragraph or screen edge' % (language, name)
                        glyphs += line
                    blocks[language].append(glyphs)
            else:
                script.append([op] + list(cmd[1:]))
        script.append([0])
        def emit_glyphs(label, glyphs):
            inc.append(label + ':')
            for i in range(0, len(glyphs), 8):
                inc.append('        db ' + ', '.join('%d,%d,%d' % g for g in glyphs[i:i + 8]))
            inc.append('        db 255')

        for language in ('es', 'en'):
            inc.append('in_texts_' + language + ':')
            inc += ['        dw in_text_%s_%d' % (language, n) for n in range(len(blocks[language]))]
            for n, glyphs in enumerate(blocks[language]):
                emit_glyphs('in_text_%s_%d' % (language, n), glyphs)
        # The language selector uses the same font, including its actual tilde n.
        # Coordinates are absolute screen pixels and deliberately independent of
        # the narrative layout and its 23-column paragraph width.
        for selected in ('es', 'en'):
            glyphs = []
            for y, line in ((58, 'LANGUAGE - IDIOMA'),
                            (90, '- ENGLISH -' if selected == 'en' else 'ENGLISH'),
                            (114, '- ESPAnOL -' if selected == 'es' else 'ESPAnOL')):
                x = (256 - 8 * len(line)) // 2
                for c in line:
                    if c != ' ':
                        glyphs.append((x, y, ROW0.index(c) if c in ROW0 else ROW1[c]))
                    x += 8
            emit_glyphs('in_select_text_' + selected, glyphs)
        inc.append('in_script:')
        for c in script:
            inc.append('        db ' + ','.join(str(v) for v in c))
        open(path, 'w').write('\n'.join(inc) + '\n')

    return pictures, write


def preview(path, language='es'):
    """Text screens as the intro shows them, for checking the layout."""
    from intro_script import SCRIPT
    anims = json.load(open(os.path.join(INTRO, 'animations.json')))
    texts = dict(l.split(':', 1) for l in open(os.path.join(INTRO, 'texts_' + language + '.txt'), encoding='utf-8') if ':' in l)
    bg, font = load('text_background'), load('animations')
    pages = [c for c in SCRIPT if c[0] == 'text']
    sheet = Image.new('P', (256 * 4, 192 * ((len(pages) + 3) // 4)))
    sheet.putpalette(bg.getpalette())
    for n, c in enumerate(pages):
        page = Image.new('P', (256, 192))
        page.paste(bg, (0, anims['text_first_line']))
        px, fp = page.load(), font.load()
        for y, name in c[2]:
            for x, yy, g in layout(y, texts[name].strip(), anims['text_first_line']):
                sx, sy = (g * 8, 0) if g < 32 else ((g - 32) * 8, 9)
                for j in range(8):
                    for i in range(8):
                        if fp[sx + i, sy + j]:
                            px[x + i, yy + j] = fp[sx + i, sy + j]
        sheet.paste(page, (256 * (n % 4), 192 * (n // 4)))
    sheet.save(path)


if __name__ == '__main__':
    preview(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'es')
