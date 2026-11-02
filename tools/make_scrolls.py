#!/usr/bin/env python3
"""Create the editable, indexed scroll atlas (run manually).

48x40, six 8x8 tiles per row. Tiles 0-19: ten styles from scrolls.json,
two variations each. Tiles 20-27: TL,T,TR,L,R,BL,B,BR.
Tile 28 is runtime scratch; tile 29 is reserved. Uses the game palette.
"""
import json
from pathlib import Path
import random

from PIL import Image

ASSETS = Path(__file__).resolve().parents[1] / 'assets'


def main():
    im = Image.new('P', (48, 40))
    palette = json.loads((ASSETS / 'palette.json').read_text())['colours']
    im.putpalette([v for c in palette for v in c] + [0] * (768 - 48))
    px = im.load()
    # Base, light fibres, dark fibres/stains. Texture stays quieter than text.
    styles = json.loads((ASSETS / 'scrolls.json').read_text())['styles']
    for family, style in enumerate(styles):
        base, light, dark = style['colours']
        for variant in range(2):
            rng = random.Random(0x4851 + family * 31 + variant)
            tile = family * 2 + variant
            ox, oy = (tile % 6) * 8, (tile // 6) * 8
            for y in range(8):
                for x in range(8):
                    r = rng.randrange(style['grain'])
                    px[ox + x, oy + y] = light if r < 4 else dark if r == 4 else base
            # A short fibre instead of an isolated, uniformly repeated dot.
            x, y = rng.randrange(6), rng.randrange(8)
            px[ox + x, oy + y] = light
            px[ox + x + 1, oy + y] = light

    def put(tile, rows):
        colours = {'.': 0, 'k': 12, 'b': 6, 's': 8, 'g': 14, 'p': 0, 'w': 0}
        ox, oy = (tile % 6) * 8, (tile // 6) * 8
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                px[ox + x, oy + y] = colours[c]

    # Rolled corners, a bronze edge and a broken inner highlight. Colour 0
    # outside the outline is transparent so the room remains visible there.
    put(20, ['...kkk..', '..kgggkk', '.kgbbbgg', 'kgbssbbb', 'kgbspppp', 'kgbspppp', 'kgbspppp', 'kgbspppp'])
    put(21, ['........', 'kkkkkkkk', 'gggggggg', 'bbbbbbbb', 'ssssssss', 'pppppppp', 'pwppppwp', 'pppppppp'])
    put(22, ['..kkk...', 'kkgggk..', 'ggbbbbgk', 'bbbssbgk', 'ppppsbgk', 'ppppsbgk', 'ppppsbgk', 'ppppsbgk'])
    put(23, ['kgbspppp', 'kgbsppwp', 'kgbspppp', 'kgbspppp', 'kgbspppp', 'kgbspppp', 'kgbsppwp', 'kgbspppp'])
    put(24, ['ppppsbgk', 'pwppsbgk', 'ppppsbgk', 'ppppsbgk', 'ppppsbgk', 'ppppsbgk', 'pwppsbgk', 'ppppsbgk'])
    put(25, ['kgbspppp', 'kgbspppp', 'kgbspppp', 'kgbsssss', '.kgbbbbb', '..kggggg', '...kkkkk', '........'])
    put(26, ['pppppppp', 'ppwppppp', 'pppppppp', 'ssssssss', 'bbbbbbbb', 'gggggggg', 'kkkkkkkk', '........'])
    put(27, ['ppppsbgk', 'ppppsbgk', 'ppppsbgk', 'sssssbgk', 'bbbbbgk.', 'gggggk..', 'kkkkk...', '........'])
    im.save(ASSETS / 'scrolls.png')


if __name__ == '__main__':
    main()
