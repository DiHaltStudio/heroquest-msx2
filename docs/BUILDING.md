# Building HeroQuest MSX2

The public source tree contains the MSX2 runtime, patch definitions, editable
converted graphics, translations and tools. It does not contain the original
commercial game tapes, a complete original disassembly, or original Amiga modules.
You must supply the original game data before building a ROM. Downloading a
release ROM and opening either manual does not require these source inputs.

## Requirements

| Component | Purpose |
| --- | --- |
| Python 3.10 or later, with `venv` and pip | Build scripts and isolated dependencies |
| Pillow, installed from `requirements.txt` | Graphics conversion and manual artwork |
| GNU Make | Build targets |
| Classic sjasm 0.42c, executable named `sjasm` | Z80 assembly; this is not sjasmplus |
| Original ZX Spectrum 128K tapes listed below | Base engine and adventure data |
| DejaVu Sans fonts | Manual artwork and cartridge label |
| pdfLaTeX or Tectonic | Rebuilding the PDF manuals |
| GCC and libm, optional | Converting the original Amiga music modules again |
| openMSX, optional | Playing a downloaded or locally built ROM |

The ROM is a 2 MiB ASCII16 MegaROM. The game requires MSX2, 64 KiB RAM and
128 KiB VRAM. MoonSound/OPL4 is optional; the internal PSG is supported.

## Original game inputs

The base data is from the Spanish Dro Soft 128K re-release of **Hero Quest**
(1991). The base TZX filename commonly identifies it as
`Hero Quest (1991)(Dro Soft)(es)[128K][re-release].tzx`; the filename itself is
not used to select the data. Its SHA-256 is
`a28518720319ac180c227c4d294efecd303e210d73ec1cf2846a75c243f30528`.
The expansion data comes from the English **Return of the Witch Lord**, side 1,
128K tape. A different edition may have different addresses and cannot be
substituted without adapting the patch definitions.

Keep these user-supplied originals outside the repository. By default the build
reads `../originals/ZX/orig/`. `ORIGINAL_DIR` selects the directory containing
`ZX/orig`; `HEROQUEST_ZX_ORIG` can select the payload directory directly.

Extract the supported data from your two tapes with:

```sh
python3 tools/prepare_originals.py '/path/to/Hero Quest.tzx' '/path/to/Return of the Witch Lord Side 1.tzx'
```

To select a different external destination:

```sh
ORIGINAL_DIR=/path/to/my-originals python3 tools/prepare_originals.py '/path/to/Hero Quest.tzx' '/path/to/Return of the Witch Lord Side 1.tzx'
make ORIGINAL_DIR=/path/to/my-originals
```

The importer recognizes payloads by SHA-256, strips the tape flag and XOR
checksum, and saves only the nine inputs needed by the build. It accepts TZX
standard-speed, turbo-speed and pure-data blocks containing the supported
payloads. It reports unsupported tape block formats or editions without saving
an incomplete set. If the payloads are already extracted, place them as follows:

| Relative to `ORIGINAL_DIR/ZX/orig/` | Bytes | Used for |
| --- | ---: | --- |
| `block05_flagFF.bin` | 39934 | Main program, tables and base font data |
| `block06_flag0B.bin` | 12286 | Base quest bank 1 |
| `block07_flag0C.bin` | 16382 | Base quest bank 3 |
| `block08_flag0D.bin` | 16382 | AY sound driver/data and bank 4 |
| `block09_flag0E.bin` | 16382 | Overlay and bank 6 |
| `block10_flag0F.bin` | 3392 | Bank 7 |
| `rotwl/bank1.bin` | 12286 | Expansion quest bank 1 |
| `rotwl/bank3.bin` | 16382 | Expansion quest bank 3 |
| `rotwl/bank6.bin` | 16382 | Expansion quest pointers and messages |

Exact payload hashes are listed in `tools/check_originals.py`. The `originals`
target checks these inputs before the ROM build. No files from the private
reverse-engineering project, no `ZX/src` directory and no `ZX/tools` directory
are needed.

## Quick start

```sh
git clone https://github.com/DiHaltStudio/heroquest-msx2.git
cd heroquest-msx2
python3 tools/prepare_originals.py '/path/to/Hero Quest.tzx' '/path/to/Return of the Witch Lord Side 1.tzx'
make
make release
```

`make` creates `.venv/`, installs Pillow, then writes `build/heroquest.rom`.
`make release` also builds the optional cheat ROM and both manuals, and packages
the deliverables in `release/`. The release contains the normal ROM, Spanish and
English manuals, loading instructions, SHA-256 sums and a downloadable ZIP.
The cheat ROM is an optional extra; normal play uses `heroquest.rom`.

## Targets

| Target | Result |
| --- | --- |
| `make`, `make build` | Build the normal ROM |
| `make originals` | Require the nine original payloads |
| `make cheat-rom` | Build the optional invulnerable-hero/guaranteed-victory ROM |
| `make manual` | Rebuild both manuals from `docs/manual/` |
| `make release VERSION=1.0` | Package the versioned release |
| `make run` | Play the normal ROM with the ASCII16 mapper |
| `make opl4` | Play with MoonSound |
| `make turbor` | Play using the configured turbo R machine |
| `make cheat`, `make cheat-opl4` | Play the optional cheat ROM |
| `make music` | Regenerate OPL4 streams from user-supplied Amiga modules |
| `make clean` | Remove generated build files |
| `make help` | Show the build and play commands |

The play targets prefer a downloaded ROM in `release/` and otherwise use the
locally built ROM in `build/`. They do not rebuild the game or require originals
when the appropriate ROM is already available. Emulator variables include
`OPENMSX`, `MACHINE_MSX2`, `MACHINE_TURBOR` and `OPENMSX_EXTRA`.

## What the build does

1. Require the supported original payloads.
2. Pack the editable PNG sheets into SCREEN 5 graphics and generate VRAM tables.
3. Assemble the intro, transient studio logo, runtime, menus and save-code code.
4. Adapt the original PSG driver using byte patches and relocation-word offsets.
   Only the MSX changes and offsets are stored in `tools/build_sound.py`; the
   driver bytes are read from the supplied bank 4. The Spectrum AY port writes
   become MSX PSG writes, and mixer register writes preserve the MSX I/O port
   directions. The unused bank tail is omitted.
5. Pack the introduction, game music, PSG/OPL4 logo fanfares, expansion quests and
   English text banks. The bilingual selector chooses the runtime language.
6. Apply the port patches and assemble the 128 segments of the ASCII16 ROM.
7. For `release`, build the PDF manuals and collect the distribution files.

## Graphics and music

The normal build uses the supplied editable MSX2 graphics and converted music
streams. It does not read a PC game installation or an Amiga disk image.
The graphics originate from the PC EGA artwork, with MSX2-specific sheets,
layout and colours; the intro and music originate from the Amiga edition.
The original commercial media are not distributed in this repository.

Optional music regeneration requires your original `hqgame.mod` and
`hqintro.mod` files. Place them in `ORIGINAL_DIR/Amiga/` (for example,
`../originals/Amiga/hqgame.mod` and `../originals/Amiga/hqintro.mod`).
The converter writes the MSX2 `.pcm` sample banks and `.mus` OPL4 streams used
by the ROM builder. The studio fanfares use the supplied DiHalt source data.

Manual source and language-specific screenshots live in `docs/manual/`.
Rebuilding the manuals uses the existing screenshots and does not launch an
emulator. The English and Spanish PDFs are also included directly in that
folder for reading without the build tools.
