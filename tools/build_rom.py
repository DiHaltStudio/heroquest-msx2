#!/usr/bin/env python3
"""Builds the HeroQuest MSX2 ASCII16 MegaROM.

    build_rom.py [--cheat]

Inputs: user-supplied tape blocks located by tools/original_paths.py,
src/patches.py, src/runtime.asm and src/rom.asm.
Output: build/heroquest.rom, or build/heroquest-cheat.rom with --cheat
(16 KiB segments, see docs/DESIGN.md section 4).
"""
import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
from original_paths import ZX_ORIG
ZX = str(ZX_ORIG)
BUILD = os.path.join(ROOT, 'build')
SEG = 0x4000
ROM_SEGMENTS = 128


def sjasm(src, out):
    r = subprocess.run(['sjasm', '-s', src, out], cwd=os.path.join(ROOT, 'src'),
                       capture_output=True, text=True)
    errs = [l for l in r.stdout.splitlines() if '(' in l and ') :' in l]
    if errs or not os.path.exists(os.path.join(ROOT, 'src', out)):
        sys.exit('sjasm %s failed:\n%s' % (src, '\n'.join(errs) or r.stdout))


def load_patches(cheat=False):
    spec = importlib.util.spec_from_file_location('patches', os.path.join(ROOT, 'src', 'patches.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    patches = list(mod.PATCHES)
    if cheat:
        spec = importlib.util.spec_from_file_location('cheats', os.path.join(ROOT, 'src', 'cheats.py'))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        patches.extend(mod.PATCHES)
    return patches


def symbols(path):
    """Label values from a sjasm .sym file (name: equ 0000xxxxh)."""
    out = {}
    for line in open(path):
        p = line.split()
        if len(p) >= 3 and p[1].lower() == 'equ':
            out[p[0].rstrip(':')] = int(p[2].rstrip('hH'), 16)
    return out


def place_blobs(blobs, first_seg):
    """Lays the blobs out from ROM segment first_seg on. Returns the ROM
    bytes and, per blob, its VRAM address and (segment, window address,
    length) pieces; a piece never crosses a segment boundary."""
    rom = bytearray()
    table = []
    for name, vaddr, data in blobs:
        pieces = []
        o = 0
        while o < len(data):
            pos = len(rom)
            n = min(len(data) - o, SEG - pos % SEG)
            pieces.append((first_seg + pos // SEG, 0x4000 + pos % SEG, n))
            rom += data[o:o + n]
            o += n
        table.append((name, vaddr, pieces))
    return bytes(rom), table


def caos(data):
    """The Spanish texts of the original write CHAOS: make it CAOS. The
    rest of the text line (up to its next control byte) moves one place to
    the left and a space is added at its end, so every length stays."""
    data = bytearray(data)
    i = data.find(b'CHAOS')
    while i >= 0:
        e = i
        while data[e] < 0xFA and data[e] != 0:
            e += 1
        data[i:e] = b'CAOS' + data[i + 5:e] + b'\x5F'
        i = data.find(b'CHAOS', i)
    return data


def fix_briefing10(data):
    """Defect D11 of the original (docs/DESIGN.md): two stray bytes
    before the position code of a line of the briefing of quest 10 sent it
    to row 255. The five bytes become the position (column 1, row 15) and
    two spaces, so the line starts at column 3 of row 15 as intended."""
    data = bytearray(data)
    i = data.find(bytes.fromhex('ff 11 ff 03 0f 31 30'))
    assert i >= 0, 'briefing of quest 10: bytes of defect D11 not found'
    data[i:i + 5] = bytes.fromhex('ff 01 0f 5f 5f')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cheat', action='store_true',
                        help='build heroquest-cheat.rom: heroes always win and take no damage')
    args = parser.parse_args()
    patches = load_patches(args.cheat)
    os.makedirs(BUILD, exist_ok=True)
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import build_logo_psg
    import build_fanfare
    logo_psg, logo_psg_frames = build_logo_psg.data()
    Path(BUILD, 'logo_psg.bin').write_bytes(logo_psg)
    logo_pcm, logo_mus, logo_opl_frames, _ = build_fanfare.convert(
        Path(ROOT, 'assets/sound/dihalt_opl4.vgm').read_bytes())
    Path(BUILD, 'logo_music.inc').write_text(
        f'LOGO_PSG_FRAMES equ {logo_psg_frames}\nLOGO_OPL_FRAMES equ {logo_opl_frames}\n')
    import pack_assets
    blobs, inc, rects = pack_assets.pack()
    gfx_rom, table = place_blobs(blobs, 9)
    gfx_rom = bytearray(gfx_rom)
    rect_pos = {}
    for name, data in rects:                # a rectangle never crosses a segment
        if len(gfx_rom) % SEG + len(data) > SEG:
            gfx_rom += b'\xFF' * (SEG - len(gfx_rom) % SEG)
        rect_pos[name] = (9 + len(gfx_rom) // SEG, 0x4000 + len(gfx_rom) % SEG)
        gfx_rom += data
    gfx_rom = bytes(gfx_rom)
    # after the game graphics: the intro program (one segment), its pictures
    # and the OPL4 music (each file starts a segment)
    import build_intro
    seg_intro = 9 + (len(gfx_rom) + SEG - 1) // SEG
    intro_pictures, write_intro = build_intro.data()
    intro_rom, intro_table = place_blobs(intro_pictures, seg_intro + 1)
    seg_music = seg_intro + 1 + (len(intro_rom) + SEG - 1) // SEG
    music_rom = bytearray()
    music_inc = ['; Generated by tools/build_rom.py: the OPL4 tunes in ROM',
                 'r2_tunes:                   ; samples: segment, 256-byte pieces; stream: segment, address; loop: segment, address; 0']
    tunes = ['hqgame', 'hqintro', 'dihalt']   # game, menu/intro, one-shot logo
    for name in tunes:
        if name == 'dihalt':
            pcm, mus = logo_pcm, logo_mus
        else:
            pcm = open(os.path.join(ROOT, 'assets', 'sound', name + '.pcm'), 'rb').read()
            mus = open(os.path.join(ROOT, 'assets', 'sound', name + '.mus'), 'rb').read()
        pcm += bytes(-len(pcm) % 256)
        pcm_seg = seg_music + len(music_rom) // SEG
        music_rom += pcm + b'\xFF' * (-len(pcm) % SEG)
        mus_seg = seg_music + len(music_rom) // SEG
        loop = int.from_bytes(mus[:3], 'little') + 3
        music_rom += mus + b'\xFF' * (-len(mus) % SEG)
        music_inc += ['        db %d' % pcm_seg, '        dw %d' % (len(pcm) // 256),
                      '        db %d' % mus_seg, '        dw 0x4003',
                      '        db %d' % (mus_seg + loop // SEG), '        dw 0x%04X' % (0x4000 + loop % SEG),
                      '        db 0']
    music_inc.append('MUSIC_TUNES     equ %d' % len(tunes))
    open(os.path.join(BUILD, 'music.inc'), 'w').write('\n'.join(music_inc) + '\n')
    # the ten quests of the expansion: two more "banks" of quest data
    import build_expansion
    xbank1, xbank3, xptrs, xinc = build_expansion.build()
    seg_x = seg_music + len(music_rom) // SEG
    seg_en = seg_x + 2
    seg_logo = seg_en + 8
    assert seg_logo + 1 <= ROM_SEGMENTS, 'the ROM is full'
    music_inc += ['r2_xquest_ptrs:              ; address of the quests 14-23 in their bank']
    music_inc += ['        dw 0x%04X' % p for p in xptrs]
    music_inc += xinc
    open(os.path.join(BUILD, 'music.inc'), 'w').write('\n'.join(music_inc) + '\n')
    inc.append('SEG_XBANK1      equ %d      ; quests 14-18 (paged as Spectrum bank 2)' % seg_x)
    inc.append('SEG_XBANK3      equ %d      ; quests 19-23 (paged as Spectrum bank 5)' % (seg_x + 1))
    inc.append('SEG_INTRO       equ %d      ; ROM segment of the intro program' % seg_intro)
    inc.append('SEG_LOGO        equ %d      ; transient logo fanfare program' % seg_logo)
    with open(os.path.join(BUILD, 'menu.inc'), 'w') as f:
        f.write('; Generated by tools/build_rom.py\ncm_font_rects:              ; ROM segment and address: first font (64 glyphs, last 5), second font\n')
        for name in ('font0a', 'font0b', 'font1a', 'font1b'):
            f.write('        db %d\n        dw 0x%04X\n' % rect_pos[name])
    for prefix, count, label in (('furn%02d', 17, 'rt_rect_furn'), ('pic%d', 10, 'rt_rect_pic')):
        inc += ['', '%s:               ; ROM segment and address of each rectangle' % label]
        for n in range(count):
            seg, addr = rect_pos[prefix % n]
            inc.append('        db %d' % seg)
            inc.append('        dw 0x%04X' % addr)
    for name, vaddr, pieces in table:
        inc += ['', 'rt_blob_%s:' % name,
                '        db %d                 ; VRAM address bits 16-14' % (vaddr >> 14),
                '        dw 0x%04X            ; VRAM address bits 13-0' % (vaddr & 0x3FFF),
                '        db %d                 ; pieces: segment, address in the ROM window, length' % len(pieces)]
        for seg, addr, n in pieces:
            inc.append('        db %d' % seg)
            inc.append('        dw 0x%04X, 0x%04X' % (addr, n))
    inc += ['', 'rt_palette:                 ; 16 entries: R << 4 | B, G']
    pal = pack_assets.palette_bytes()
    inc.append('        db ' + ','.join('0x%02X' % b for b in pal))
    game0 = open(os.path.join(ZX, 'block05_flagFF.bin'), 'rb').read()
    def operand(addr):
        return game0[addr - 0x6400] | game0[addr - 0x6400 + 1] << 8
    inc = ['; Addresses of the Spectrum game read from its image',
           'ZX_VIEWCELLPTR  equ 0x%04X      ; ViewCellBufferPtr' % operand(0x8B8D),
           'ZX_VIEWORIGIN   equ 0x%04X      ; ViewOriginCell' % operand(0x8723),
           'ZX_ROOMATTR     equ 0x%04X      ; RoomAttribute' % operand(0x8937),
           'ZX_VIEWATTRRUNS equ 0x%04X      ; ViewAttrRuns' % operand(0x8BD6),
           'ZX_FONT         equ 0x%04X      ; Font8x8' % operand(0x8C82),
           'ZX_ATTRCALL     equ 0x8C89      ; operand of the attribute call in PrintString',
           'ZX_PAINTATTR    equ 0x%04X      ; PaintGlyphAttr' % operand(0x8C57),
           'ZX_TEXTATTR     equ 0x%04X      ; TextAttr' % operand(0x8C61),
           'ZX_INVOP        equ 0x8E72      ; NOP or CPL: inverse video of the glyph plotter',
           'ZX_DEPTHTAB     equ 0xFD00      ; SpriteDepthTable',
           'ZX_SLOTS        equ 0x6A8E      ; 14 sprite records of 18 bytes',
           'ZX_BACKDROPLEN  equ 0x9C0C      ; operand of the copy length in ShowBackdrop',
           'ZX_PAGEBANK6    equ 0x9CCE',
           'ZX_FROZEN       equ 0x%04X      ; SpritesFrozen' % operand(0xA535),
           'ZX_PAGEBANK0    equ 0x9CD7',
           'ZX_LOSY         equ 0x%04X' % operand(0x7F2E),
           'ZX_LOSX         equ 0x%04X' % operand(0x7F3C),
           'ZX_FRAMETABLE   equ 0xC23A      ; width, height, graphic address per frame', ''] + inc
    open(os.path.join(BUILD, 'gfx.inc'), 'w').write('\n'.join(inc) + '\n')
    import build_sound
    SOUND_BASE = 0x1CF0
    sound, sound_entry = build_sound.build(SOUND_BASE)
    assert SOUND_BASE + len(sound) <= 0x4000
    open(os.path.join(BUILD, 'snd.inc'), 'w').write(
        '; Generated by tools/build_rom.py\nSOUND_SIZE      equ %d\nSOUND_ENTRY     equ 0x%04X\n' % (len(sound), sound_entry))
    sjasm('runtime.asm', '../build/runtime.bin')
    sym = symbols(os.path.join(BUILD, 'runtime.sym'))
    assert sym.get('SOUND_BASE', SOUND_BASE) == SOUND_BASE
    open(os.path.join(BUILD, 'rt_syms.inc'), 'w').write(
        '; runtime labels used by the boot code\nrt_palette      equ 0x%04X\n' % sym['rt_palette'])
    with open(os.path.join(BUILD, 'rt_all.inc'), 'w') as f:
        f.write('; every label of the runtime, for the programs assembled after it\n')
        ssym = symbols(os.path.join(BUILD, 'sound.sym'))
        for ch in 'ABC':        # end of each order list of the PSG menu tune: the word 0000h
            a = ssym['Tune2Order' + ch]
            while sound[a - SOUND_BASE] | sound[a - SOUND_BASE + 1]:
                a += 2
            f.write('%-24s equ 0x%04X\n' % ('PSG_TUNE2_END_' + ch, a))
        for k, v in sorted(sym.items()):
            if '.' not in k:
                f.write('%-24s equ 0x%04X\n' % (k, v))
    sjasm('runtime2.asm', '../build/runtime2.bin')
    # Reassemble with the English expansion's addresses and lengths. All
    # executable labels must stay at the same addresses in both languages.
    en_xbank1, en_xbank3, en_xptrs, en_xinc = build_expansion.build('en')
    assert en_xptrs == xptrs
    music_path = Path(BUILD) / 'music.inc'
    spanish_music = music_path.read_text()
    music_path.write_text('\n'.join(music_inc[:-len(xinc)] + en_xinc) + '\n')
    try:
        sjasm('runtime2.asm', '../build/runtime2-en.bin')
    finally:
        music_path.write_text(spanish_music)
    rt2_es_symbols = symbols(os.path.join(BUILD, 'runtime2.sym'))
    rt2_en_symbols = symbols(os.path.join(BUILD, 'runtime2-en.sym'))
    for label, address in rt2_es_symbols.items():
        if not label.startswith('XBOX_'):
            assert rt2_en_symbols[label] == address, ('language changed runtime address', label)
    sjasm('savecode.asm', '../build/savecode.bin')
    sjasm('ctrlmenu.asm', '../build/ctrlmenu.bin')
    sjasm('scroll.asm', '../build/scroll.bin')
    import localize_runtime
    localize_runtime.write_boot_include(Path(BUILD) / 'language.inc', seg_en)
    write_intro(os.path.join(BUILD, 'intro.inc'), intro_table)
    sjasm('intro.asm', '../build/intro.bin')
    sjasm('logo.asm', '../build/logo.bin')
    sjasm('rom.asm', '../build/seg0.bin')

    game = bytearray(open(os.path.join(ZX, 'block05_flagFF.bin'), 'rb').read())   # 6400h
    bank6 = bytearray(open(os.path.join(ZX, 'block09_flag0E.bin'), 'rb').read())  # C000h

    rt2 = bytearray(open(os.path.join(BUILD, 'runtime2.bin'), 'rb').read())
    rt2_en = bytearray(open(os.path.join(BUILD, 'runtime2-en.bin'), 'rb').read())
    sym.update(symbols(os.path.join(BUILD, 'runtime2.sym')))

    def target(addr, part):
        if part == 'game':
            return game, addr - 0x6400
        if part == 'overlay':               # 5B00h at run time = DB58h in bank 6
            return bank6, addr - 0x5B00 + 0x1B58
        if part == 'runtime2':
            return rt2, addr - sym['RT2_BASE']
        raise ValueError(part)

    for entry in patches:
        part, addr, expect, new, why = entry[:5]
        if isinstance(addr, str):
            addr = sym[addr]
        buf, off = target(addr, part)
        expect = bytes.fromhex(expect)
        if len(entry) > 5:                  # instruction longer than the bytes checked
            expect = bytes(buf[off:off + len(expect)]) and expect + bytes(buf[off + len(expect):off + entry[5]])
        if isinstance(new, tuple):          # ('jp'|'call', runtime label) [+ filler]
            op = {'jp': 0xC3, 'call': 0xCD}[new[0]]
            v = sym[new[1]]
            new = bytes([op, v & 255, v >> 8])
        else:
            values = dict(sym, snd=sound_entry)      # {name}: address of a runtime label
            new = bytes.fromhex(re.sub(r'\{(\w+)\}', lambda m: '%02x %02x' % (
                values[m.group(1)] & 255, values[m.group(1)] >> 8), new))
        new = new + b'\x00' * (len(expect) - len(new))      # NOP filler
        if len(new) != len(expect):
            sys.exit('patch %04X: replacement longer than the original' % addr)
        if bytes(buf[off:off + len(expect)]) != expect:
            sys.exit('patch %04X (%s): expected %s, found %s' % (
                addr, why, expect.hex(), bytes(buf[off:off + len(expect)]).hex()))
        buf[off:off + len(new)] = new
        if part == 'runtime2':
            assert bytes(rt2_en[off:off + len(expect)]) == expect
            rt2_en[off:off + len(new)] = new

    rom = bytearray(b'\xFF' * (SEG * ROM_SEGMENTS))
    seg0 = open(os.path.join(BUILD, 'seg0.bin'), 'rb').read()
    rom[0:len(seg0)] = seg0
    rom[1 * SEG:1 * SEG + len(game)] = game                         # segments 1-3
    def put(seg, off, name=None, data=None):
        d = data if data is not None else open(os.path.join(ZX, name), 'rb').read()
        assert off + len(d) <= SEG
        rom[seg * SEG + off:seg * SEG + off + len(d)] = d
    put(4, 0, 'block08_flag0D.bin')         # bank 4
    put(5, 0x1000, data=bytes(caos(open(os.path.join(ZX, 'block06_flag0B.bin'), 'rb').read())))    # bank 1 loads at D000h
    put(6, 0, data=bytes(fix_briefing10(caos(open(os.path.join(ZX, 'block07_flag0C.bin'), 'rb').read()))))    # bank 3
    put(7, 0, data=bytes(caos(bank6)))      # bank 6, with the overlay patches
    put(8, 0, 'block10_flag0F.bin')         # bank 7
    put(8, 0x1000, data=sound)              # sound driver image
    rom[9 * SEG:9 * SEG + len(gfx_rom)] = gfx_rom       # SCREEN 5 graphics
    assert len(seg0) <= 0x2000 and len(rt2) <= 0x1000
    rom[0x2000:0x2000 + len(rt2)] = rt2                 # RT2_ROM = 6000h of segment 0
    scroll = open(os.path.join(BUILD, 'scroll.bin'), 'rb').read()
    assert len(rt2) <= 0x0C00 and len(scroll) == 0x0400
    rom[0x2C00:0x3000] = scroll                       # transient text-window renderer
    intro = open(os.path.join(BUILD, 'intro.bin'), 'rb').read()
    assert len(intro) <= SEG
    rom[seg_intro * SEG:seg_intro * SEG + len(intro)] = intro
    rom[(seg_intro + 1) * SEG:(seg_intro + 1) * SEG + len(intro_rom)] = intro_rom
    rom[seg_music * SEG:seg_music * SEG + len(music_rom)] = music_rom
    code = open(os.path.join(BUILD, 'savecode.bin'), 'rb').read()
    assert len(code) <= 0x4F0 and xbank3[0x3800:0x3800 + 0x4F0] == b'\xFF' * 0x4F0
    xbank3 = xbank3[:0x3800] + code + xbank3[0x3800 + len(code):]      # CODE_ROM = F800h of that bank
    menu = open(os.path.join(BUILD, 'ctrlmenu.bin'), 'rb').read()
    assert len(menu) <= 0x300 and xbank3[0x3D00:] == b'\xFF' * 0x300
    xbank3 = xbank3[:0x3D00] + menu + xbank3[0x3D00 + len(menu):]      # CTRL_ROM = FD00h of that bank
    rom[seg_x * SEG:(seg_x + 1) * SEG] = xbank1
    rom[(seg_x + 1) * SEG:(seg_x + 2) * SEG] = xbank3
    # English copies retain all game addresses, event bytes and save-code
    # formats. Only the selected bank table and boot operands change.
    import localize_base
    import localize_quests
    en_game = localize_base.translate_game(bytes(game))
    assert len(en_game) == len(game) and len(game) <= 2 * SEG + 0x2000
    rom[seg_en * SEG:seg_en * SEG + len(en_game)] = en_game
    en_b1, en_b3 = localize_quests.translate_banks(
        bytes(rom[5 * SEG:6 * SEG]), bytes(rom[6 * SEG:7 * SEG]))
    put(seg_en + 3, 0, data=en_b1)
    put(seg_en + 4, 0, data=en_b3)
    put(seg_en + 5, 0, data=localize_base.translate_overlay(bytes(caos(bank6))))
    rt2_en = localize_runtime.translate(rt2_en, localize_runtime.RUNTIME2)
    put(seg_en + 2, 0x2000, data=rt2_en)
    runtime = Path(BUILD, 'runtime.bin').read_bytes()
    messages = runtime[sym['rt_spell_prompt_wizard']:sym['sc_txt_end']]
    put(seg_en + 2, 0x2C00, data=localize_runtime.translate(messages, localize_runtime.RUNTIME))
    en_xbank3 = bytearray(en_xbank3)
    assert en_xbank3[0x3800:0x3800 + len(code)] == b'\xFF' * len(code)
    assert en_xbank3[0x3D00:0x3D00 + len(menu)] == b'\xFF' * len(menu)
    en_xbank3[0x3800:0x3800 + len(code)] = code
    en_xbank3[0x3D00:0x3D00 + len(menu)] = localize_runtime.translate(menu, localize_runtime.OPTIONS)
    put(seg_en + 6, 0, data=en_xbank1)
    put(seg_en + 7, 0, data=en_xbank3)
    put(seg_logo, 0, data=Path(BUILD, 'logo.bin').read_bytes())
    Path(BUILD, 'languages.json').write_text(json.dumps({
        'spanish_game': 1, 'english_game': seg_en,
        'spanish_expansion': seg_x, 'english_expansion': seg_en + 6,
        'logo': seg_logo, 'used_segments': seg_logo + 1, 'rom_segments': ROM_SEGMENTS,
    }, indent=2) + '\n')
    name = 'heroquest-cheat.rom' if args.cheat else 'heroquest.rom'
    out = os.path.join(BUILD, name)
    open(out, 'wb').write(rom)
    print('build/%s  %d KiB, graphics %d KiB, runtime %d bytes, %d patches' % (
        name, len(rom) // 1024, len(gfx_rom) // 1024, os.path.getsize(os.path.join(BUILD, 'runtime.bin')), len(patches)))


if __name__ == '__main__':
    main()
