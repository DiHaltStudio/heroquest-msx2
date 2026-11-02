#!/usr/bin/env python3
"""Dumps an openMSX savestate (.oms) of the game for inspection.

    oms_dump.py STATE.oms NAME

Writes build/test/NAME.vram, NAME.pal (the formats of tools/vram2png.py) and
NAME.mem (the 64 KiB the Z80 sees, built from the memory mapper segments),
then renders the VRAM pages with vram2png.
"""
import base64
import gzip
import os
import sys
import xml.etree.ElementTree as ET
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def blob(e):
    return zlib.decompress(base64.b64decode(''.join(e.text.split())))


def main():
    src, name = sys.argv[1], sys.argv[2]
    root = ET.fromstring(gzip.open(src).read())
    out = os.path.join(ROOT, 'build', 'test', name)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    vram = pal = None
    ram = None
    segs = [3, 2, 1, 0]
    for dev in root.iter('device'):
        t = dev.get('type', '')
        if t == 'VDP':
            vram = blob(dev.find('.//vram/data'))
            p = [int(i.text) for i in dev.find('.//palette').findall('item')]
            pal = bytearray()
            for v in p:                     # G << 8 | R << 4 | B
                pal += bytes([(v >> 4 & 7) << 4 | (v & 7), v >> 8 & 7])
        elif t.endswith('Ram') or t in ('MemoryMapper',):     # main RAM of any machine
            e = dev.find('.//ram/ram')
            if e is None:
                e = dev.find('.//ram')
            if e is not None and e.get('encoding'):
                r = blob(e)
                if ram is None or len(r) > len(ram):
                    ram = r
    for e in root.iter('registers'):        # memory mapper segment registers
        items = [int(i.text) for i in e.findall('item')]
        if len(items) == 4:
            segs = items
            break
    open(out + '.vram', 'wb').write(vram)
    open(out + '.pal', 'wb').write(bytes(pal))
    if len(ram) > 0x10000:
        mem = b''.join(ram[(s % (len(ram) // 0x4000)) * 0x4000:][:0x4000] for s in segs)
    else:
        mem = ram
    open(out + '.mem', 'wb').write(mem)
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import vram2png
    vram2png.render(name)
    print('%s: VRAM %d, RAM %d, mapper segments %s' % (name, len(vram), len(ram), segs))


if __name__ == '__main__':
    main()
