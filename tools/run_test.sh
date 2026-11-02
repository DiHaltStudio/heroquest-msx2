#!/bin/sh
# Boots build/heroquest.rom in a private openMSX instance on the virtual
# display and writes build/test/<name>.png and .txt.
#   tools/run_test.sh NAME [SECONDS] [MACHINE] [KEYS]
# HQ_EXT: an openMSX extension to plug in (moonsound for the OPL4 music).
cd "$(dirname "$0")/.."
mkdir -p build/test
if [ -n "$4" ]; then export HQ_KEYS="$4"; fi
export HQ_OUT="$PWD/build/test/${1:-boot}" HQ_SECS="${2:-20}" HQ_SYM="$PWD/build/runtime.sym"
export DISPLAY=:99 SDL_AUDIODRIVER=dummy OPENMSX_USER_DATA="$HOME/.cache/openmsx-tests/share"
exec openmsx -machine "${3:-C-BIOS_MSX2_EU}" -carta build/heroquest.rom -romtype ASCII16 ${HQ_EXT:+-ext $HQ_EXT} \
    -script tools/boot_test.tcl
