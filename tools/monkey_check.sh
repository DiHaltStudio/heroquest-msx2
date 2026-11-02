#!/bin/sh
# Random-input runs with the sprite invariant check (tools/sprite_check.tcl).
#   tools/monkey_check.sh SEED [SECONDS] [MACHINE]
# Writes build/test/monkeySEED.txt: one line per anomaly and a final count.
cd "$(dirname "$0")/.."
mkdir -p build/test
SEED="${1:-1}"; SECS="${2:-420}"; MACHINE="${3:-Philips_NMS_8250}"
KEYS=$(python3 -c "
import random
r=random.Random($SEED)
k='18 space/0.5 21 space/0.5 24 space/0.5 26 right/0.5 28 space/0.5 30 space/0.5 32 right/0.5 34 space/0.5 36 space/0.5 39 space/0.5 42 space/0.5 47 space/0.5 51 space/0.5 55 space/0.5'
t=48.0
while t<$SECS-5:
    key=r.choice(['space','space','left','right','up','down','space'])
    hold=r.choice([0.2,0.3,0.5,0.8,1.2]) if key!='space' else 0.3
    k+=' %.1f %s/%.1f'%(t,key,hold); t+=hold+r.choice([0.3,0.6,1.0])
print(k)")
export HQ_OUT="$PWD/build/test/monkey$SEED.txt" HQ_SECS="$SECS" HQ_KEYS="$KEYS" HQ_SYM="$PWD/build/runtime.sym"
export DISPLAY=:99 SDL_AUDIODRIVER=dummy OPENMSX_USER_DATA="$HOME/.cache/openmsx-tests/share"
exec openmsx -machine "$MACHINE" -carta build/heroquest.rom -romtype ASCII16 -script tools/sprite_check.tcl
