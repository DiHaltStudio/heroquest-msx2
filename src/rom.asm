; HeroQuest MSX2 - ROM segment 0: cartridge header and boot (stage A).
; Assemble with sjasm 0.42c. See MSX2/doc/DESIGN.md.
;
; The BIOS calls rom_init with page 1 = this cartridge. Stage A sets SCREEN 5
; with the BIOS, finds the RAM slot, selects RAM in pages 0, 2 and 3 (page 1
; stays on the cartridge), copies the runtime to 0000h and jumps to it. The
; BIOS is never used again.

        include "layout.inc"
        include "../build/rt_syms.inc"

CHGMOD          equ 0x005F
RG8SAV          equ 0xFFE7
RG9SAV          equ 0xFFE8
FORCLR          equ 0xF3E9      ; then BAKCLR
BDRCLR          equ 0xF3EB

        org 0x4000
        db "AB"
        dw rom_init
        dw 0, 0, 0
        ds 6,0

rom_init:
        ld hl,0x0C0F            ; text colour 15, background 12 (black)
        ld (FORCLR),hl
        ld a,12
        ld (BDRCLR),a
        ld a,5
        call CHGMOD             ; SCREEN 5, 212 lines, VRAM cleared to black
        di
        ld a,(RG8SAV)
        or 0x20                 ; TP: colour 0 comes from the palette
        and 0xFD                ; sprites on (the pointer)
        out (VDP_CTRL),a
        ld a,0x88
        out (VDP_CTRL),a
        ld a,0x62               ; display on, vertical interrupt, 16 x 16 sprites
        out (VDP_CTRL),a
        ld a,0x81
        out (VDP_CTRL),a
        ld a,12
        out (VDP_CTRL),a
        ld a,0x87               ; border colour: black
        out (VDP_CTRL),a
        xor a
        out (VDP_CTRL),a
        ld a,0x90               ; palette pointer = 0
        out (VDP_CTRL),a
        ld hl,ROM_RUNTIME+rt_palette-RT_BASE     ; the palette inside the runtime image
        ld b,32
set_palette:
        ld a,(hl)
        inc hl
        out (VDP_PAL),a
        djnz set_palette

; ---- find the RAM slot: write test in page 2 over the primary slots
        in a,(PPI_SLOT)
        ld e,a                  ; E = slot register as the BIOS left it
        ld b,0
find_ram:
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,e
        and 0xCF
        or c
        out (PPI_SLOT),a        ; page 2 = candidate slot
        ld a,(0x8000)
        cpl
        ld l,a
        ld (0x8000),a
        ld a,(0x8000)
        cp l
        jr z,ram_found
        inc b
        ld a,b
        cp 4
        jr nz,find_ram
; no primary slot answers: the RAM is in an expanded slot, the one of page 3
        ld a,e
        rlca
        rlca
        and 3
        ld b,a
ram_found:
        ld a,b                  ; A = RAM primary slot
        add a,a
        add a,a
        or b
        ld c,a
        rlca
        rlca
        rlca
        rlca
        or c
        ld c,a                  ; C = RAM slot in all four pages
        ld a,e
        and 0x0C                ; cartridge slot bits of page 1
        ld b,a
        ld a,c
        and 0xF3
        or b
        ld b,a                  ; B = RAM everywhere, page 1 = cartridge
        out (PPI_SLOT),a
; Expanded RAM slot: FFFFh is its secondary slot register and reads back
; complemented. Give pages 0-2 the sub-slot that page 3 already has.
        ld a,(0xFFFF)
        cpl
        ld h,a
        ld (0xFFFF),a
        ld a,(0xFFFF)
        cpl
        cp h
        jr nz,not_expanded      ; plain RAM at FFFFh: not a secondary slot register
        ld a,h
        rlca
        rlca
        and 3                   ; sub-slot of page 3
        ld l,a
        add a,a
        add a,a
        or l
        ld l,a
        rlca
        rlca
        rlca
        rlca
        or l
        ld (0xFFFF),a           ; same sub-slot in the four pages
not_expanded:
        push bc
        ld hl,ROM_RUNTIME
        ld de,RT_BASE
        ld bc,runtime_size
        ldir
        pop bc
        ld a,b
        ld (rt_slot_rom1),a
        ld a,c
        ld (rt_slot_ram),a
        ld a,(RG9SAV)           ; RAM is in page 3 on every path above
        cpl
        and 2                   ; R#9 bit 1: 1 = 50 Hz
        ld (rt_60hz),a
        jp RT_BASE

        assert $ <= ROM_RUNTIME
        ds ROM_RUNTIME-$,0xFF
runtime_image:
        incbin "../build/runtime.bin"
runtime_size    equ $-runtime_image
        assert $ <= 0x8000
