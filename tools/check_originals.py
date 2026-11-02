#!/usr/bin/env python3
"""Require the supported original HeroQuest tape payloads before building."""
from hashlib import sha256
from original_paths import ZX_ORIG

# filename: (byte count, SHA-256 of unmodified tape payload)
EXPECTED = {
    'block05_flagFF.bin': (39934, 'ecdb2ffaa51b01080bd662576a8a35df88369aa3e535e1bbebcb63cf24df3dd2'),
    'block06_flag0B.bin': (12286, 'bb96ee0d950fa7f2551d2deafe74466058b27f9fea4447f1988c4fc74d35f54a'),
    'block07_flag0C.bin': (16382, 'da829ed7bd3c3b621ac941c759215f70c97cdbfe60d1b394e9d094a3ed5ff61e'),
    'block08_flag0D.bin': (16382, 'fa646b6998729255ba2db5b097d025376500ba3c92fe085091247127b3f0f2d6'),
    'block09_flag0E.bin': (16382, '558fcf75a7de69fb8b7bd557f5738de3e27124e5fec25743a243e798f809b058'),
    'block10_flag0F.bin': (3392, 'ce08421329f48d5700cd578a570f1c440b86c288c4b8d741e6c5edfc253759d5'),
    'rotwl/bank1.bin': (12286, '3da965a300672f73b883260a1b3cde2315a82484deef456b0da850f3f4f7aaf7'),
    'rotwl/bank3.bin': (16382, '6e015adf520b7114664ccaec0ca61280448dd8b80d6096f84f72d2f9cfb70b66'),
    'rotwl/bank6.bin': (16382, 'e58504e2e450c987027733e6d64bda84858c1f2e86a58bcbfe09a28f111d2a84'),
}


def main():
    errors = []
    for name, (length, digest) in EXPECTED.items():
        path = ZX_ORIG / name
        if not path.is_file():
            errors.append('missing: ' + str(path))
        else:
            data = path.read_bytes()
            if len(data) != length or sha256(data).hexdigest() != digest:
                errors.append('unsupported contents: ' + str(path))
    if errors:
        raise SystemExit('Original game files are required:\n  ' + '\n  '.join(errors) +
            '\nSee docs/BUILDING.md and tools/prepare_originals.py. '
            'Set ORIGINAL_DIR to the directory containing ZX/orig.')
    print('Required original game payloads are available.')


if __name__ == '__main__':
    main()
