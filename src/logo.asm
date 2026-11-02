; DiHalt logo fanfare. Transient boot program at 8000h, before the intro.
; PSG: the Mad Mix 2 / Spy vs Spy 2 fanfare. OPL4: Xybots' dihalt34.
; Interrupts stay disabled. VDP vblank provides 50 Hz ticks (drop one in
; six on a 60 Hz machine), and no input can shorten either song.
        include "../build/rt_all.inc"
        include "../build/logo_music.inc"

        org INTRO_BASE
logo_start:
        di
        ld sp,0xBFF0
        xor a
        ld (logo_skip),a
        ld (logo_wait),a
        call logo_psg_stop
        ld hl,logo_music
        ld (logo_pointer),hl
        ld hl,LOGO_PSG_FRAMES
        ld (logo_remaining),hl
        ld a,(rt_opl)
        or a
        jr z,logo_ready
        ld a,1
        ld (rt_opl_once),a
        ld d,3                  ; shared OPL4 player, third tune = logo
        ld a,2
        call RT2_SNDCMD
        ld hl,LOGO_OPL_FRAMES
        ld (logo_remaining),hl
logo_ready:
        in a,(VDP_CTRL)         ; clear the pending vblank after sample loading
logo_frame:
        in a,(VDP_CTRL)
        rlca
        jr nc,logo_frame
        ld a,(rt_60hz)
        or a
        jr z,logo_tick
        ld a,(logo_skip)
        inc a
        cp 6
        jr c,logo_count
        xor a
        ld (logo_skip),a
        jr logo_frame
logo_count:
        ld (logo_skip),a
logo_tick:
        ld a,(rt_opl)
        or a
        jr z,logo_psg_tick
        call rt_opl_tick
        jr logo_next
logo_psg_tick:
        call logo_psg_play
logo_next:
        ld hl,(logo_remaining)
        dec hl
        ld (logo_remaining),hl
        ld a,h
        or l
        jr nz,logo_frame
        call logo_psg_stop
        ld a,(rt_opl)
        or a
        jr z,logo_finished
        ld a,5
        call RT2_SNDCMD
logo_finished:
        xor a
        ld (rt_opl_once),a
logo_done:
        ld sp,RT_STACK
        jp rt_boot_intro

; Stream: register,value pairs; 81h..FEh = wait 1..126 ticks; FFh = end.
logo_psg_play:
        ld a,(logo_wait)
        or a
        jr z,logo_psg_read
        dec a
        ld (logo_wait),a
        ret
logo_psg_read:
        ld hl,(logo_pointer)
logo_psg_next:
        ld a,(hl)
        cp 0xFF
        ret z
        inc hl
        bit 7,a
        jr nz,logo_psg_delay
        ld e,(hl)
        inc hl
        call logo_psg_write
        jr logo_psg_next
logo_psg_delay:
        and 0x7F
        dec a
        ld (logo_wait),a
        ld (logo_pointer),hl
        ret
logo_psg_stop:
        ld e,0
        ld a,8
        call logo_psg_write
        ld a,9
        call logo_psg_write
        ld a,10
        call logo_psg_write
        ld a,7
        ld e,0xBF
logo_psg_write:
        out (PSG_ADDR),a
        cp 7
        ld a,e
        jr nz,logo_psg_value
        and 0x3F
        or 0x80                 ; MSX port A input, B output (joystick selection)
logo_psg_value:
        out (PSG_WRITE),a
        ret
logo_skip:      db 0
logo_wait:      db 0
logo_pointer:   dw 0
logo_remaining: dw 0
logo_music:
        incbin "../build/logo_psg.bin"
        assert $ < 0xBF00
