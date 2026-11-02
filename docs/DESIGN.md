# HeroQuest MSX2 architecture

HeroQuest MSX2 combines the ZX Spectrum 128K game's logic with an MSX2 SCREEN 5 renderer, direct MSX input and sound, and a 2 MiB ASCII16 cartridge. The target has 64 KB RAM and 128 KB VRAM. The port uses the existing game records, maps, event tables and depth ordering rather than replacing the game rules.

For dependencies and commands, see [Building](BUILDING.md). For controls and rules, see the [English manual](manual/manual-en.pdf) or [Spanish manual](manual/manual-es.pdf).

## RAM and cartridge mapping

The original program contains absolute addresses and self-modifying code, so the resident game runs from RAM at its original addresses. The cartridge supplies its initial images and banked data.

| Z80 address range | Purpose |
|---|---|
| `0000h–3FFFh` | MSX runtime, interrupt entry at `0038h`, ROM transfer helpers and relocated PSG driver |
| `4000h–5AFFh` | Runtime and work space formerly used by the Spectrum screen |
| `5B00h–6CEDh` | Original overlay and work RAM |
| `6CEEh–BFFFh` | Resident game code and data with MSX patches |
| `C000h–FFFDh` | Original bank 0 tables, sprite data and working buffers |

Boot code finds the RAM slot and copies the runtime and game images into RAM. RAM occupies all four Z80 pages while the game runs; the BIOS is switched out. The image ends at `FFFDh`, leaving the expanded-slot register at `FFFFh` alone.

The ROM has 128 segments of 16 KiB. Its first segments contain the boot code, resident game image, sound image and original banked data. Later segments contain packed graphics, the animated introduction, OPL4 music, expansion data, English variants and the logo program. `tools/build_rom.py` assigns the variable-length sections and emits their tables and assembly includes under `build/`.

The page-0 ROM helper temporarily selects the cartridge in pages 1 and 2. Copies targeting those pages use a bounce buffer before RAM is restored. The original game's bank-copy operations call this helper instead of accessing Spectrum paging hardware.

## SCREEN 5 rendering

`tools/pack_assets.py` packs editable images into 4-bit tiles, sprite sheets, fonts and picture rectangles. The runtime uploads them to VRAM and uses VDP copy commands for composition.

- Page 0 holds the displayed game picture.
- Page 1 is the composition page.
- Pages 2 and 3 hold reusable graphic sheets.

The room is rebuilt from the background, floor, walls and doors. Heroes, monsters and furniture follow the original game's depth ordering. Logical transparent copies replace the Spectrum's sprite masking and save/restore work. The completed composition is copied to the display page.

Text is drawn with 4-bit font tiles. The Options menu selects Gothic or plain lettering. The pointer is an MSX hardware sprite, independent of the room composition. Parchment-style dialogs use the styles and images under `assets/`.

## Runtime and input

`src/runtime.asm` supplies the interrupt, video, input and ROM-transfer functions. `src/runtime2.asm` adds menus, expansion behavior and sound support. The patch manifest in `src/patches.py` connects the game's original entry points to these functions.

The runtime installs IM 1 handling at `0038h`, acknowledges the VDP interrupt and advances the game and music clocks. Keyboard, joystick and mouse are read directly because the BIOS is unavailable during play.

Cursor keys or a joystick in port 1 move the pointer; SPACE or fire performs the action. The mouse reader accepts an MSX mouse in port 1 or 2, with the left button as action. Menus also support up/down navigation without a visible pointer.

## Sound and startup

The original AY driver is relocated into page-0 RAM and adapted to MSX PSG ports `A0h/A1h`. Mixer register writes preserve the MSX I/O direction bits. With an OPL4 device present, the runtime uses the converted sample and event streams for music.

Startup proceeds through the DiHalt logo, opening illustration, language selector, animated introduction and main menu. The temporary program in `src/logo.asm` shares the introduction's RAM area. It plays the complete fanfare, stops the sound devices and jumps through `rt_boot_intro`, which loads the introduction program.

The logo lasts 9.42 seconds with PSG, including its silent tail, or 10 seconds with OPL4, plus sample-upload time. It does not read skip input. The opening waits for action; the narrative can be skipped with SPACE, ESC or the right mouse button. Music and introduction delays use 50 Hz ticks; the 60 Hz path omits one tick in six.

## Two languages in one ROM

`rt_language` holds `0` for Spanish and `1` for English until reset. Spanish is selected initially. The selector prepares each highlight state on a separate VRAM page and changes the displayed page during vertical blank, keeping the display enabled.

Game logic, artwork, animation, music and hero-code format are shared. English has separate resident-game and data segments for translated text. The boot stage selects the appropriate bank table and installs the corresponding native text variants before the introduction begins. Segment assignments are written to `build/languages.json`.

Translation sources are:

| Source | Content |
|---|---|
| `assets/intro/texts_*.txt` | Intro narrative |
| `assets/lang/base_en.json` | Original-game English string replacements |
| `assets/lang/briefings_en.txt` | Original adventure briefings |
| `assets/expansion/*_*.txt` | Expansion briefings, dialogs and ending |
| `tools/localize_runtime.py` | English variants of native runtime text |

String replacements preserve dynamic number fields and the pointers used by the game. Adventure localization replaces briefing text while retaining maps, monsters, objects and event records. The fourteen original adventures and ten expansion adventures share the same rules in both languages.

## Hero codes

`src/savecode.asm` replaces tape-based character persistence with sixteen-letter codes. Each code stores a hero's name, gold, body points, equipment and quest treasures. Codes represent characters rather than the current dungeon state and are independent of the selected language. The cartridge has no battery-backed save memory.

## Build and editing

The build reads separately supplied original inputs, applies a patch manifest and assembles the MSX routines with sjasm. Each patch specifies its address, expected source bytes and replacement; a source-byte mismatch stops the build. Builders generate the graphics tables, sound data, language variants and banked cartridge layout.

`assets/` is the editing surface for graphics, palettes and translations. `src/` contains the MSX-specific assembly and patch definitions. Generated files belong in `build/`, not in the source tree. ROMs and distribution archives belong in release downloads; both manual PDFs are kept with their LaTeX sources under `docs/manual/`.
