#!/usr/bin/env python3
"""Package the ROMs and manuals as GitHub release assets."""
from hashlib import sha256
from pathlib import Path
import os
import re
import shutil
from zipfile import ZipFile, ZIP_DEFLATED
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'release'
FILES = {
    'heroquest.rom': ROOT / 'build/heroquest.rom',
    'extras/heroquest-cheat.rom': ROOT / 'build/heroquest-cheat.rom',
    'manual-es.pdf': ROOT / 'docs/manual/manual-es.pdf',
    'manual-en.pdf': ROOT / 'docs/manual/manual-en.pdf',
    'README.txt': ROOT / 'docs/RELEASE.txt',
}
def main():
    version = os.environ.get('VERSION', '1.0')
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,2}', version):
        raise SystemExit('VERSION must be a numeric release version, e.g. 1.0')
    for name, source in FILES.items():
        if not source.is_file(): raise SystemExit(f'Missing input: {source}')
        if name.endswith('.rom'):
            data = source.read_bytes()
            if len(data) != 2 * 1024 * 1024 or data[:2] != b'AB':
                raise SystemExit(f'Invalid 2 MiB MSX ROM: {source}')
    for name, source in FILES.items():
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    archive = DEST / f'heroquest-msx2-v{version}.zip'
    with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
        for name in sorted(FILES): z.write(DEST / name, name)
    names = sorted([*FILES, archive.name])
    (DEST / 'SHA256SUMS').write_text(''.join(
        f'{sha256((DEST / name).read_bytes()).hexdigest()}  {name}\n' for name in names))
    print(f'Release assets: {DEST}')
if __name__ == '__main__': main()
