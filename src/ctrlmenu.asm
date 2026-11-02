; HeroQuest MSX2 - options menu
; DiHalt Studio
;
; Replaces the controls menu of the original (keys 1, 2, 3, 0: Kempston
; joystick, music, font, exit). The Kempston option makes no sense on MSX
; and is gone; the others are lines of a menu like the main one: up and
; down and the action, or the pointer.
; - MUSICA: on or off (MusicOn and StartTune, as the original).
; - LETRA: the game has two fonts. The text is drawn from the font cells of
;   the VRAM sheet, so the other font is loaded over them from ROM (the
;   original copied it over its font in RAM, which the cartridge does not
;   use for drawing).
; - VOLVER: back to the main menu.
; Assembled at 4000h and loaded on demand by r2_ctrl, like the hero codes.

        include "../build/rt_all.inc"

        org CODE_BASE
        jp cm_start

        ds 0x401E-$,0
; rt_menu_input knows the menus by the low byte of the return address: 21h
; is the entry of this menu in rt_menus (three lines from screen row 6).
cm_input:
        call rt_menu_input
        ret

cm_start:
        xor a
        ld (GAME_MENUCURSOR),a
cm_draw:
        call ZX_CLEARALL
        ld ix,cm_txt_title
        call ZX_PRINTSTRING
        ld ix,cm_txt_music_on
        ld a,(ZX_MUSICON)
        or a
        jr nz,cm_draw_music
        ld ix,cm_txt_music_off
cm_draw_music:
        call ZX_PRINTSTRING
        ld ix,cm_txt_font0
        ld a,(ZX_FONTFLAG)
        or a
        jr z,cm_draw_font
        ld ix,cm_txt_font1
cm_draw_font:
        call ZX_PRINTSTRING
        ld ix,cm_txt_exit
        call ZX_PRINTSTRING
        call ZX_TOGGLEBAR
        call ZX_BLIT
        call ZX_WAITRELEASE
cm_loop:
        call cm_input
        bit 3,a
        jr nz,cm_up
        bit 2,a
        jr nz,cm_down
        bit 4,a
        jr z,cm_loop
        call ZX_WAITRELEASE
        ld a,(GAME_MENUCURSOR)
        or a
        jr z,cm_music
        dec a
        jr z,cm_font
        jp ZX_MAINMENU
cm_up:
        call ZX_TOGGLEBAR
        ld a,(GAME_MENUCURSOR)
        or a
        jr nz,cm_up_dec
        ld a,3
cm_up_dec:
        dec a
        jr cm_move
cm_down:
        call ZX_TOGGLEBAR
        ld a,(GAME_MENUCURSOR)
        inc a
        cp 3
        jr c,cm_move
        xor a
cm_move:
        ld (GAME_MENUCURSOR),a
        call ZX_TOGGLEBAR
        call ZX_WAITRELEASE
        jr cm_loop

cm_music:
        ld a,(ZX_MUSICON)
        xor 1
        ld (ZX_MUSICON),a
        ld d,2                  ; the tune of the menus
        jr nz,cm_music_set
        ld d,0                  ; silence
cm_music_set:
        call ZX_STARTTUNE
        jp cm_draw

cm_font:
        ld a,(ZX_FONTFLAG)
        xor 1
        ld (ZX_FONTFLAG),a
        ld hl,cm_font_rects
        jr z,cm_font_load
        ld hl,cm_font_rects+6
cm_font_load:
        push hl
        ld hl,0xD400            ; VRAM page 3, line 168: glyphs 0-63, two rows of 32
        ld (rt_lr_addr),hl
        ld a,1
        ld (rt_lr_hi),a
        ld a,16
        ld (rt_lr_lines),a
        ld a,128
        ld (rt_lr_width),a
        pop hl
        push hl
        call rt_load_rect
        ld hl,0xDC00            ; line 184: glyphs 64-68 (the map glyphs follow them)
        ld (rt_lr_addr),hl
        ld a,8
        ld (rt_lr_lines),a
        ld a,20
        ld (rt_lr_width),a
        pop hl
        inc hl
        inc hl
        inc hl
        call rt_load_rect
        jp cm_draw

cm_txt_title:
        db 0xFB,6, 0xFF,12,0, 0x4F,0x50,0x43,0x49,0x4F,0x4E,0x45,0x53, 0xFA    ; OPCIONES
cm_txt_music_on:
        db 0xFB,3, 0xFF,11,4, 0x4D,0x55,0x53,0x49,0x43,0x41,0x5F,0x53,0x49, 0xFA    ; MUSICA SI
cm_txt_music_off:
        db 0xFB,3, 0xFF,11,4, 0x4D,0x55,0x53,0x49,0x43,0x41,0x5F,0x4E,0x4F, 0xFA    ; MUSICA NO
cm_txt_font0:
        db 0xFB,3, 0xFF,10,5, 0x4C,0x45,0x54,0x52,0x41,0x5F,0x47,0x4F,0x54,0x49,0x43,0x41, 0xFA    ; LETRA GOTICA
cm_txt_font1:
        db 0xFB,3, 0xFF,10,5, 0x4C,0x45,0x54,0x52,0x41,0x5F,0x4E,0x4F,0x52,0x4D,0x41,0x4C, 0xFA    ; LETRA NORMAL
cm_txt_exit:
        db 0xFB,3, 0xFF,13,6, 0x56,0x4F,0x4C,0x56,0x45,0x52, 0xFA    ; VOLVER

        include "../build/menu.inc"

        assert $ <= CODE_BASE+CTRL_SIZE
