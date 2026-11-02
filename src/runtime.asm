; HeroQuest MSX2 - runtime, copied to page 0 RAM (0000h) by the boot code.
; Assemble with sjasm 0.42c. See MSX2/doc/DESIGN.md.
;
; Holds everything the Spectrum code needs from the machine: reset and
; interrupt entries, the ROM access behind the Spectrum bank paging, the
; input readers and the SCREEN 5 renderer. Nothing is drawn by writing pixels
; from the CPU: the scene is built in VRAM page 1 with VDP commands from the
; graphics sheets in pages 2 and 3, and only the part that changed is copied
; to the visible page 0.

        include "layout.inc"

        org RT_BASE
        di
        jp rt_boot

; ---- RST 08h: LDIR that honours the Spectrum bank "paged" by the game.
; Every LDIR that the original executes with a RAM bank paged in is patched
; to RST 08h + NOP. In: HL, DE, BC as for LDIR. Out: as LDIR.
        ds 0x0008-$,0
        jp rt_ldir

; ---- IM 1 interrupt entry
        ds 0x0038-$,0
rt_irq:
        push af
        in a,(VDP_CTRL)         ; acknowledge the vertical blank interrupt
        call rt_frame
        pop af
        jp GAME_IRQ_JP          ; the game's own handler ends with EI / RETI
        assert $ <= RT_VARS

        ds 0x0066-$,0
        retn                    ; NMI: not used on MSX

        ds 0x0100-$,0

; ---- rt_boot: copy the Spectrum image from ROM to RAM and start the game.
; Entered from the boot code with page 1 = cartridge and the rest RAM.
rt_boot:
        ld sp,RT_STACK
        xor a
        ld (rt_bank),a
        ld a,(rt_slot_ram)      ; all RAM while the memory is prepared
        out (PPI_SLOT),a
        xor a
        ld hl,ZX_SCREEN         ; clear the Spectrum screen image and the work
        ld de,ZX_SCREEN+1       ; RAM below the game image
        ld bc,GAME_START-ZX_SCREEN-1
        ld (hl),a
        ldir
        ld hl,RT_CELLMAP        ; no glyph anywhere, every attribute 0
        ld bc,0x0600
        call rt_zero
        ld hl,0
        ld (rt_tick),hl         ; rt_tick, rt_mouse_port
        ld (rt_mouse_try),hl    ; rt_mouse_try, rt_mouse_miss
        xor a
        ld (rt_mouse_btn),a
        ld (rt_mouse_btn2),a
        ld (rt_music_skip),a
        ld (rt_mouse_click),a
        ld (rt_incode),a
        ld (rt_opl_once),a
        ld hl,rt_logo_palette   ; studio logo
        call rt_set_palette
        ld a,LOGO_BORDER
        call rt_set_border
        ld hl,rt_blob_logo
        call rt_load_blob_boot
        ld a,SEG_SOUND          ; sound driver -> page 0 RAM
        ld (rt_seg),a
        ld hl,SOUND_ROM
        ld de,SOUND_BASE
        ld bc,SOUND_SIZE
        call rt_copy
        xor a                   ; second part of the runtime -> page 1 RAM
        ld (rt_seg),a
        ld hl,RT2_ROM
        ld de,RT2_BASE
        ld bc,RT2_SIZE
        call rt_copy
        call RT2_DETECT         ; is there an OPL4?
        ld a,SEG_LOGO           ; one-shot fanfare player -> 8000h
        ld de,INTRO_BASE
        ld bc,0x4000
        call rt_copy_seg
        jp INTRO_BASE
rt_boot_intro:                  ; the fanfare has stopped; replace its program
        ld a,SEG_INTRO
        ld de,INTRO_BASE
        ld bc,0x4000
        call rt_copy_seg
        jp INTRO_BASE           ; the intro; it uses the loaders, which run on
rt_boot_game:                   ; this stack, so it comes back with a jump,
        ld sp,RT_STACK          ; with the display and the interrupts off
                                ; sprite tables of the pointer (the opening uses that VRAM)
        ld hl,rt_cursor_patterns
        ld de,SPR_PATTERNS
        ld b,64
        call rt_vram_write
        ld hl,rt_cursor_colours
        ld de,SPR_COLOURS
        ld b,32
        call rt_vram_write
        ld hl,rt_sprite_end
        ld de,SPR_ATTRS+8       ; the pointer uses sprites 0 and 1
        ld b,1
        call rt_vram_write
        ld hl,rt_palette        ; game palette, black border
        call rt_set_palette
        ld a,12
        call rt_set_border
        ld hl,rt_cmd_clear1     ; native scene page: black
        call rt_vdp_cmd
        ld hl,rt_blob_sheet3    ; graphics sheets -> VRAM pages 3 and 2
        call rt_load_blob_boot
        ld hl,rt_blob_sheet2
        call rt_load_blob_boot
rt_game_segment0:               ; operands selected by the language menu
        ld a,SEG_GAME           ; 6400h-FFFDh: 39934 bytes in three segments
        ld de,GAME_START
        ld bc,0x4000
        call rt_copy_seg
rt_game_segment1:
        ld a,SEG_GAME+1
        ld bc,0x4000
        call rt_copy_seg
rt_game_segment2:
        ld a,SEG_GAME+2
        ld bc,39934-0x8000
        call rt_copy_seg
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        ld hl,rt_cmd_clear0
        call rt_vdp_cmd
        jp GAME_START           ; the display stays off until the main menu is drawn (r2_menu)

; rt_set_palette: load the 16 palette entries at HL. Interrupts disabled.
; Clobbers AF, B, HL.
rt_set_palette:
        xor a
        out (VDP_CTRL),a
        ld a,0x90               ; R#16: palette pointer = 0
        out (VDP_CTRL),a
        ld b,32
rt_sp_next:
        ld a,(hl)
        inc hl
        out (VDP_PAL),a
        djnz rt_sp_next
        ret

; rt_set_border: border colour A (R#7). Interrupts disabled. Clobbers AF.
rt_set_border:
        out (VDP_CTRL),a
        ld a,0x87
        out (VDP_CTRL),a
        ret

; ---- rt_copy_seg: copy BC bytes from the start of ROM segment A to DE.
; Out: DE advanced. Uses the runtime stack; call only from rt_boot.
rt_copy_seg:
        ld (rt_seg),a
        ld hl,0x4000
        jr rt_copy

; ---- rt_ldir: see RST 08h.
rt_ldir:
        push af
        ld a,(rt_bank)
        and 7
        jr nz,rt_ldir_bank
        pop af
        ldir
        ret
rt_ldir_bank:
        push hl
        ld hl,rt_bank_segs
        add a,l
        ld l,a
        ld a,(hl)
        ld (rt_seg),a
        pop hl
        pop af
        ld a,d                  ; copies that the native renderer takes over
        cp 0x69
        jr nz,rt_ldir_notfurn
        ld a,e
        or a
        jr nz,rt_ldir_copy
        call rt_furniture       ; to 6900h: the furniture graphic of the room
        jr rt_ldir_skip
rt_ldir_notfurn:
        cp 0x5E
        jr nz,rt_ldir_copy
        ld a,e
        or a
        jr nz,rt_ldir_copy
        ld a,b
        cp 4
        jr nz,rt_ldir_copy
        call rt_picture         ; 400h bytes to 5E00h: a combat picture
rt_ldir_skip:
        add hl,bc               ; leave the registers as LDIR would
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,0
        ret
rt_ldir_copy:
        ld (rt_sp),sp           ; the game stack is in page 1: not reachable
        ld sp,RT_STACK          ; while the cartridge is selected there
        res 7,h                 ; C000h-FFFFh -> 4000h-7FFFh, the ROM window
        call rt_copy
        set 7,h
        ld sp,(rt_sp)
        ret

; ---- rt_copy: copy BC bytes from HL (4000h-7FFFh of ROM segment rt_seg) to
; DE (anywhere in RAM) through the bounce buffer. Out: HL, DE advanced, BC = 0.
; Leaves all four pages on RAM.
rt_copy:
        ld a,b
        or c
        jr z,rt_copy_done
        push bc                 ; bytes left
        ld a,b
        cp RT_BOUNCE_SIZE/256
        jr c,rt_copy_chunk
        ld bc,RT_BOUNCE_SIZE
rt_copy_chunk:
        push bc                 ; this chunk
        push de
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        ld a,(rt_seg)
        ld (ASCII16_PAGE1),a
        ld de,RT_BOUNCE
        ldir
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        pop de
        pop bc
        push bc
        push hl
        ld hl,RT_BOUNCE
        ldir
        pop hl
        pop bc                  ; this chunk
        ex (sp),hl              ; HL = bytes left, stack = source
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr rt_copy
rt_copy_done:
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        ret

; ROM segment of each Spectrum RAM bank (index = low 3 bits of the 7FFDh value)
        ds ((($+7)/8)*8)-$,0    ; keep the table inside one 256-byte page
rt_bank_segs:
        db 0, SEG_BANK1, SEG_XBANK1, SEG_BANK3, SEG_BANK4, SEG_XBANK3, SEG_BANK6, SEG_BANK7

; Text windows use a transient renderer in the same work RAM as the hero
; code screen. Reload it for each window: saving a hero may overwrite it.
; This loader fits the unused space before the tape ROM entry points.
rt_scroll:
        call rt_iff
        push af
        di
        xor a
        ld (rt_seg),a
        ld hl,SCROLL_ROM
        ld de,SCROLL_BASE
        ld bc,SCROLL_SIZE
        call rt_copy
        pop af
        jp po,SCROLL_BASE
        ei
        jp SCROLL_BASE

; Coloured HUD symbols use spare sheet space. Restrict this to their three
; actual HUD cells: the same font codes elsewhere still honour text colour,
; inverse video and the selected font as usual. Lives in the tape-entry gap.
rt_cell_draw:
        ld a,d
        or a
        jp nz,rt_cell_mono
        ld a,c
        cp 12                   ; the icon artwork has a black background
        jp nz,rt_cell_mono
        ld a,(rt_g_index)
        cp 0x3C-0x30            ; money bag, HUD row 2
        jr z,rt_hud_gold
        cp 0x5C-0x30            ; footprint, HUD row 3
        jr z,rt_hud_moves
        cp 0x5D-0x30            ; heart, HUD row 1
        jp nz,rt_cell_mono
        ld a,e
        cp 8
        jp nz,rt_cell_mono
        ld hl,512+HUD_ICON_Y+16
        jr rt_hud_draw
rt_hud_gold:
        ld a,e
        cp 16
        jp nz,rt_cell_mono
        ld hl,512+HUD_ICON_Y
        jr rt_hud_draw
rt_hud_moves:
        ld a,e
        cp 24
        jp nz,rt_cell_mono
        ld hl,512+HUD_ICON_Y+8
rt_hud_draw:
        push hl
        call rt_cell_dest
        pop hl
        ld (rt_cmd+2),hl
        ld hl,HUD_ICON_X
        ld (rt_cmd),hl
        ld a,0xD0               ; HMMM: preserve all palette colours, incl. 0
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        jp rt_vdp_cmd

; Front-end menus keep a keyboard highlight; only a detected mouse needs
; the hardware pointer there. The dungeon still needs its keyboard pointer.
rt_front_menu:
        ld a,1
        ld (rt_pointer_menu),a
        jp RT2_MENU
rt_pointer_y:
        ld a,(rt_mouse_port)
        or a
        jr nz,rt_pointer_y_show
        ld a,(rt_pointer_menu)
        or a
        ld a,216                ; sprite-list terminator: hide both planes
        ret nz
rt_pointer_y_show:
        ld a,(GAME_CURSOR_Y)
        add a,24
        ret
rt_pointer_menu: db 1

; Full-width lines erase the previous chooser's longer prompt. The game's
; font uses 5Fh for a space. Both prompts sit above the four spell groups.
rt_spell_prompt_wizard:
        db 0xFB,6,0xFF,0,0
        db 0x5F,0x48,0x45,0x43,0x48,0x49,0x43,0x45,0x52,0x4F,0x5F,0x53,0x45,0x4C,0x45,0x43,0x43,0x49,0x4F,0x4E,0x41,0x5F,0x48,0x45,0x43,0x48,0x49,0x5A,0x4F,0x53,0x5F,0x5F
        db 0xFA
rt_spell_prompt_elf:
        db 0xFB,6,0xFF,0,0
        db 0x5F,0x5F,0x5F,0x44,0x55,0x45,0x4E,0x44,0x45,0x5F,0x53,0x45,0x4C,0x45,0x43,0x43,0x49,0x4F,0x4E,0x41,0x5F,0x48,0x45,0x43,0x48,0x49,0x5A,0x4F,0x53,0x5F,0x5F,0x5F
        db 0xFA

; Jump to a pointed quest in one input call. Toggle both attribute rows
; before presenting, so no intermediate selection is displayed. BC keeps
; the target in B and the input bits in C; IX identifies the current menu.
rt_menu_jump:
        ld a,(ix+0)
        cp 0x6F
        jp nz,RT2_JUMP           ; alphabet/name editor keeps its own redraw
        push ix
        push bc
        call rt_quest_toggle
        pop bc
        ld a,b
        ld (GAME_MENUCURSOR),a
        push bc
        call rt_quest_toggle
        call rt_present
        pop bc
        pop ix
        ret
rt_quest_toggle:
        ld a,(GAME_MENUCURSOR)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ZX_ATTRS+6*32
        add hl,de
        ld b,32
rt_quest_toggle_cell:
        ld a,(hl)
        xor 7
        ld (hl),a
        inc hl
        djnz rt_quest_toggle_cell
        ret

; Hero-code messages live in the unused tape-entry gap.
sc_txt_save:
        db 0xFB,6, 0xFF,8,4, 0x43,0x4F,0x44,0x49,0x47,0x4F,0x5F,0x44,0x45,0x4C,0x5F,0x48,0x45,0x52,0x4F,0x45    ; CODIGO DEL HEROE
        db 0xFB,5, 0xFF,7,14, 0x41,0x50,0x55,0x4E,0x54,0x41,0x5F,0x45,0x53,0x54,0x45,0x5F,0x43,0x4F,0x44,0x49,0x47,0x4F    ; APUNTA ESTE CODIGO
        db 0xFF,4,15, 0x43,0x4F,0x4E,0x5F,0x43,0x41,0x52,0x47,0x41,0x52,0x5F,0x4C,0x4F,0x5F,0x52,0x45,0x43,0x55,0x50,0x45,0x52,0x41,0x53    ; CON CARGAR LO RECUPERAS
        db 0xFB,3, 0xFF,10,20, 0x50,0x55,0x4C,0x53,0x41,0x5F,0x46,0x55,0x45,0x47,0x4F    ; PULSA FUEGO
        db 0xFA
sc_txt_load:
        db 0xFB,6, 0xFF,2,4, 0x45,0x53,0x43,0x52,0x49,0x42,0x45,0x5F,0x45,0x4C,0x5F,0x43,0x4F,0x44,0x49,0x47,0x4F,0x5F,0x44,0x45,0x4C,0x5F,0x48,0x45,0x52,0x4F,0x45    ; ESCRIBE EL CODIGO DEL HEROE
        db 0xFB,5, 0xFF,3,14, 0x46,0x49,0x4E,0x5F,0x42,0x4F,0x52,0x52,0x41,0x5F,0x4C,0x41,0x5F,0x55,0x4C,0x54,0x49,0x4D,0x41,0x5F,0x4C,0x45,0x54,0x52,0x41    ; FIN BORRA LA ULTIMA LETRA
        db 0xFA
sc_txt_bad:
        db 0xFB,2, 0xFF,7,17, 0x43,0x4F,0x44,0x49,0x47,0x4F,0x5F,0x49,0x4E,0x43,0x4F,0x52,0x52,0x45,0x43,0x54,0x4F    ; CODIGO INCORRECTO
        db 0xFA
sc_txt_end:


; ---- entries of the 48K ROM that the tape routines of the game call. Tape
; is not supported: they return at once. (04C6h SA-BYTES, 0556h LD-BYTES,
; 0562h LD-BYTES entry used by the bank loader.)
        assert $ <= 0x04C6
        ds 0x04C6-$,0
        ret
        ds 0x0556-$,0
        ret
        ds 0x0562-$,0
        ret

; ---- keyboard ---------------------------------------------------------------
; rt_keyrow: A = MSX keyboard matrix row -> A = its bits (0 = pressed).
rt_keyrow:
        push bc
        ld b,a
        in a,(PPI_ROW)
        and 0xF0
        or b
        out (PPI_ROW),a
        in a,(PPI_KEYS)
        pop bc
        ret

; rt_read_input: replaces the four Spectrum control readers. Sets the bits of
; InputBits for the cursor keys and SPACE, the joystick in port 1 and the
; left mouse button. In: nothing. Clobbers AF, B, HL.
rt_read_input:
        ld hl,GAME_INPUT
        ld a,8                  ; row 8: 0 SPACE, 4 LEFT, 5 UP, 6 DOWN, 7 RIGHT
        call rt_keyrow
        bit 0,a
        jr nz,rt_ri_left
        set 4,(hl)
rt_ri_left:
        bit 4,a
        jr nz,rt_ri_right
        set 1,(hl)
rt_ri_right:
        bit 7,a
        jr nz,rt_ri_up
        set 0,(hl)
rt_ri_up:
        bit 5,a
        jr nz,rt_ri_down
        set 3,(hl)
rt_ri_down:
        bit 6,a
        jr nz,rt_ri_mouse
        set 2,(hl)
rt_ri_mouse:
        ld a,(rt_mouse_btn)
        or a
        jr z,rt_ri_joy
        set 4,(hl)
rt_ri_joy:
        ld a,(rt_mouse_port)
        dec a
        ret z                   ; a mouse in port 1: no joystick there
        call rt_iff
        push af
        di                      ; the interrupt entry uses the PSG too
        ld a,14
        out (PSG_ADDR),a
        in a,(PSG_READ)         ; joystick port 1: 0 up, 1 down, 2 left, 3 right, 4 trigger A
        ld b,a
        pop af
        jp po,rt_ri_joy_bits
        ei
rt_ri_joy_bits:
        ld a,b
        bit 0,a
        jr nz,rt_ri_jdown
        set 3,(hl)
rt_ri_jdown:
        bit 1,a
        jr nz,rt_ri_jleft
        set 2,(hl)
rt_ri_jleft:
        bit 2,a
        jr nz,rt_ri_jright
        set 1,(hl)
rt_ri_jright:
        bit 3,a
        jr nz,rt_ri_jfire
        set 0,(hl)
rt_ri_jfire:
        bit 4,a
        ret nz
        set 4,(hl)
        ret

; rt_test_key: replaces the Spectrum key test at 9F80h.
; In: B = Spectrum keyboard half-row select (one bit clear), C = key mask.
; Out: A = half-row bits AND C, Z set if the key is pressed. Keeps HL, DE, BC.
rt_test_key:
        push hl
        push de
        ld d,b
        ld e,0
rt_tk_find:
        rr d
        jr nc,rt_tk_row
        inc e
        bit 3,e
        jr z,rt_tk_find
        ld a,c                  ; no half-row selected: nothing pressed
        or a
        jr rt_tk_exit
rt_tk_row:
        ld a,e                  ; 10 bytes per half-row
        add a,a
        ld l,a
        add a,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,rt_key_table
        add hl,de
        ld de,0x0001            ; D = result, E = bit being built
rt_tk_key:
        ld a,(hl)
        inc hl
        call rt_keyrow
        and (hl)
        inc hl
        jr z,rt_tk_pressed
        ld a,d
        or e
        ld d,a
rt_tk_pressed:
        sla e
        bit 5,e
        jr z,rt_tk_key
        ld a,d
        and c
rt_tk_exit:
        pop de
        pop hl
        ret

; Spectrum half-rows (select bit 0..7 = FEh, FDh, FBh, F7h, EFh, DFh, BFh,
; 7Fh), keys bit 0..4, as MSX matrix row, mask (international layout).
rt_key_table:
        db 6,0x01, 5,0x80, 5,0x20, 3,0x01, 5,0x08   ; CAPS SHIFT=SHIFT Z X C V
        db 2,0x40, 5,0x01, 3,0x02, 3,0x08, 3,0x10   ; A S D F G
        db 4,0x40, 5,0x10, 3,0x04, 4,0x80, 5,0x02   ; Q W E R T
        db 0,0x02, 0,0x04, 0,0x08, 0,0x10, 0,0x20   ; 1 2 3 4 5
        db 0,0x01, 1,0x02, 1,0x01, 0,0x80, 0,0x40   ; 0 9 8 7 6
        db 4,0x20, 4,0x10, 3,0x40, 5,0x04, 5,0x40   ; P O I U Y
        db 7,0x80, 4,0x02, 4,0x01, 3,0x80, 3,0x20   ; ENTER=RETURN L K J H
        db 8,0x01, 6,0x02, 4,0x04, 4,0x08, 2,0x80   ; SPACE SYMBOL SHIFT=CTRL M N B

; ---- per-frame work in the interrupt -----------------------------------------
; rt_frame: pointer sprite and mouse. Keeps every register but AF.
rt_frame:
        jp rt_pointer

; ---- sound --------------------------------------------------------------------
; rt_music_tick: called by the game's interrupt handler (6FAEh) instead of
; paging RAM bank 4 and calling its driver. Runs the two per-frame functions
; of the driver, which now lives in page 0. The driver was written for the
; 50 Hz interrupt of the Spectrum: on a 60 Hz machine one interrupt in six
; is skipped so that the music keeps its tempo. Clobbers what the driver does.
rt_music_tick:
        ld a,(rt_60hz)
        or a
        jr z,rt_mt_play
        ld a,(rt_music_skip)
        inc a
        cp 6
        jr c,rt_mt_count
        xor a
        ld (rt_music_skip),a
        ret
rt_mt_count:
        ld (rt_music_skip),a
rt_mt_play:
        ld a,(rt_opl_play)
        or a
        call nz,rt_opl_tick     ; the tune on the OPL4
        xor a
        call SOUND_ENTRY        ; music frame (with an OPL4, only the effects)
        ld a,1
        jp SOUND_ENTRY          ; modulation frame

; rt_opl_tick: one 50 Hz tick of the OPL4 tune. The tune is a stream of
; register writes stored in ROM (tools/build_music.py): n, then n times
; address port, register, value; FEh n = n ticks without writes; FFh = go on
; at the loop point. The cartridge is in page 1 while it is read, so this
; runs on its own stack with interrupts disabled. Clobbers AF, BC, DE, HL.
rt_opl_tick:
        ld (rt_msp),sp
        ld sp,RT_MSTACK
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        ld a,(rt_opl_seg)
        ld (ASCII16_PAGE1),a
        ld hl,rt_opl_wait
        ld a,(hl)
        or a
        jr z,rt_ot_read
        dec (hl)
        jr rt_ot_exit
rt_ot_read:
        ld hl,(rt_opl_ptr)
rt_ot_cmd:
        call rt_opl_get
        cp 0xFE
        jr c,rt_ot_writes
        jr z,rt_ot_idle
        ld a,(rt_opl_once)      ; FFh: the end
        or a
        jr nz,rt_ot_stop
        ld a,(rt_opl_lseg)      ; back to the loop point
        ld (rt_opl_seg),a
        ld (ASCII16_PAGE1),a
        ld hl,(rt_opl_lptr)
        jr rt_ot_cmd
rt_ot_idle:
        call rt_opl_get
        dec a                   ; this tick is the first of them
        ld (rt_opl_wait),a
        jr rt_ot_save
rt_ot_writes:
        ld b,a
rt_ot_write:
        call rt_opl_get
        ld c,a
        call rt_opl_get
        ld e,a
        call rt_opl_get
        ld d,a
        call rt_opl_write
        djnz rt_ot_write
rt_ot_save:
        ld (rt_opl_ptr),hl
rt_ot_exit:
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        ld sp,(rt_msp)
        ret
rt_ot_stop:                     ; played once: silence, key off on the 24 voices
        xor a
        ld (rt_opl_play),a
        ld de,0x0068
        ld b,24
rt_ot_off:
        ld c,OPL4_WAVE
        call rt_opl_write
        inc e
        djnz rt_ot_off
        jr rt_ot_exit

; rt_opl_get: A = next byte of the stream at HL, which moves on to the next
; ROM segment after 7FFFh. Keeps BC, DE.
rt_opl_get:
        ld a,(hl)
        inc hl
        bit 7,h
        ret z
        push af
        ld a,(rt_opl_seg)
        inc a
        ld (rt_opl_seg),a
        ld (ASCII16_PAGE1),a
        pop af
        ld hl,0x4000
        ret

; rt_opl_write: OPL4 register E of the part with address port C = D. Waits
; for the chip before each of the two writes. Clobbers AF, C.
rt_opl_write:
        in a,(OPL4_FM)          ; status: bit 0 = busy
        rrca
        jr c,rt_opl_write
        out (c),e
        inc c
rt_ow_data:
        in a,(OPL4_FM)
        rrca
        jr c,rt_ow_data
        out (c),d
        ret

; ---- menus --------------------------------------------------------------------
; rt_attr_bar: tail of ToggleAttrBar (64E7h). The original toggles the
; highlight of a menu line in the attribute file, which the Spectrum shows at
; once; here the change has to be presented.
; In: HL = first attribute, B = cells. Clobbers AF, BC, DE, HL.
rt_attr_bar:
        ld a,(hl)
        xor 7
        ld (hl),a
        inc hl
        djnz rt_attr_bar
        push ix
        call rt_present
        pop ix
        ret

; rt_spell: replaces "bit 0,a / jr z / ld a,(MenuCursor) / inc a / and 3" in
; the choice of spell group (625Bh), which only stepped to the right. The
; four groups are two rows of two: right and left step through them, up
; and down change row. In: A = input bits. Out: carry and A = the new group
; if a direction is pressed, no carry if not. Clobbers BC.
rt_spell:
        ld c,a
        and 0x0F
        ret z
        ld a,(GAME_MENUCURSOR)
        bit 0,c
        jr z,rt_spell_left
        inc a
rt_spell_left:
        bit 1,c
        jr z,rt_spell_row
        dec a
rt_spell_row:
        ld b,a
        ld a,c
        and 0x0C
        ld a,b
        jr z,rt_spell_done
        xor 2
rt_spell_done:
        and 3
        scf
        ret

; rt_menu_input: replaces the calls to ReadInput (9F89h) of the menu loops,
; so that the pointer works in the menus. The menu is found by the return
; address. When the tip of the pointer moves to another character cell, or
; the mouse button goes down, the option under it becomes the target; the
; routine selects it directly in the quest and letter menus; other menus
; step their own cursor towards it, one step per call. A click is delivered
; as fire once the option is reached. A click outside every option does nothing. The keys and
; the joystick work as before.
; Out: A = input bits like ReadInput. Clobbers AF, BC, HL.
rt_menu_input:
        pop hl
        push hl
        push ix
        push de
        ld a,l
        ld ix,rt_menus
rt_mi_find:
        cp (ix+0)
        jr z,rt_mi_found
        ld e,(ix+2)             ; skip the header and its rectangles
        ld d,0
        inc ix
        inc ix
        inc ix
        add ix,de
        jr rt_mi_find           ; (every patched call is in the table)
rt_mi_found:
        call ZX_READINPUT
        ld c,a                  ; C = input bits
        ld a,(GAME_CURSOR_X)
        sub 12
        jr nc,rt_mi_col
        xor a
rt_mi_col:
        rrca
        rrca
        rrca
        and 31
        ld e,a                  ; E = column of the tip
        ld a,(GAME_CURSOR_Y)
        add a,15
        rrca
        rrca
        rrca
        and 31
        ld d,a                  ; D = row
        ld hl,(rt_mi_cell)
        ld (rt_mi_cell),de
        or a
        sbc hl,de               ; Z: the tip is in the same cell
        push af
        ld a,(rt_mouse_btn)
        or a
        jr z,rt_mi_latch
        res 4,c                 ; the mouse button is fire only as a click
rt_mi_latch:
        ld hl,rt_mouse_click    ; a press since the last call (latched by the
        ld b,(hl)               ; interrupt: the press may come while the menu
        ld (hl),0               ; is busy moving its bar)
        pop af
        jr nz,rt_mi_aim         ; the tip moved
        inc b
        dec b
        jr z,rt_mi_steer
rt_mi_aim:
        call rt_mi_option
        ld (rt_mi_target),a
        ld a,16
        ld (rt_mi_budget),a
        inc b
        dec b
        jr z,rt_mi_steer
        ld a,1                  ; button just pressed
        ld (rt_mi_click),a
rt_mi_steer:
        ld a,(rt_mi_target)
        ld b,a
        inc a
        jr z,rt_mi_none
        ld hl,GAME_MENUCURSOR
        bit 7,(ix+1)
        jr z,rt_mi_var
        dec hl                  ; HeroSlotCursor
rt_mi_var:
        ld a,(hl)
        cp b
        jr z,rt_mi_reached
        bit 5,(ix+1)
        jr z,rt_mi_stepwise
        call rt_menu_jump       ; direct mouse selection: quests or letters
        jr rt_mi_reached
rt_mi_stepwise:
        ld hl,rt_mi_budget
        dec (hl)
        jr z,rt_mi_none         ; an option this menu cannot reach
        ld a,(ix+1)
        jr c,rt_mi_fwd          ; cursor below the target: forwards
        bit 6,a
        jr z,rt_mi_fwd          ; the menu only steps forwards
        add a,a                 ; back is the next higher input bit
rt_mi_fwd:
        and 0x1F
        jr rt_mi_exit
rt_mi_reached:
        ld hl,rt_mi_click
        ld a,(hl)
        or a
        jr z,rt_mi_none
        set 4,c
rt_mi_none:
        xor a
        ld (rt_mi_click),a
        dec a
        ld (rt_mi_target),a
        ld a,c
rt_mi_exit:
        pop de
        pop ix
        ret

; rt_mi_option: A = option under the cell D (row), E (column) in the menu at
; IX, FFh if none. Keeps BC, DE, IX; the flags of the caller are lost.
rt_mi_option:
        push ix
        push bc
        ld a,(ix+2)
rt_op_rect:
        or a
        jr z,rt_op_none
        push af
        ld a,d
        sub (ix+3)              ; row0
        cp (ix+4)               ; rows
        jr nc,rt_op_next
        ld b,a
        ld a,e
        sub (ix+5)              ; col0
        cp (ix+6)               ; columns
        jr nc,rt_op_next
        ld c,(ix+8)             ; pitch: 0 = one option per row
        inc c
        dec c
        jr z,rt_op_got
        ld b,0xFF               ; one option every C columns
rt_op_div:
        inc b
        sub c
        jr nc,rt_op_div
rt_op_got:
        pop af
        ld a,b
        add a,(ix+7)            ; first option of the rectangle
        jr rt_op_exit
rt_op_next:
        ld bc,6
        add ix,bc
        pop af
        sub 6
        jr rt_op_rect
rt_op_none:
        dec a
rt_op_exit:
        pop bc
        pop ix
        ret

; The menus: low byte of the return address of the patched call; flags
; (bits 0-4 = input bit that steps forwards, bit 5 = direct mouse selection,
; bit 6 = the next higher bit
; steps back, bit 7 = the cursor is HeroSlotCursor); size of the rectangles
; that follow, 6 bytes each: first row, rows, first column, columns, first
; option, columns per option (0 = one option per row).
rt_menus:
        db 0x09, 0x44, 6        ; main menu (5B06h): down, up
        db 6,4, 0,32, 0, 0
        db 0x6F, 0x64, 6        ; quest menu (616Ch): direct mouse selection
        db 6
rt_menu_quest_rows:             ; lines of the quest menu page (set by r2_qmenu)
        db 14, 0,32, 0, 0
        db 0x21, 0x44, 6        ; options menu (src/ctrlmenu.asm, call at 401Eh): down, up
        db 6,3, 0,32, 0, 0
        db 0x3A, 0xC4, 30       ; hero slots (5E37h): down, up
        db 6,1, 4,20, 0, 0
        db 9,1, 4,20, 1, 0
        db 12,1, 4,20, 2, 0
        db 15,1, 4,20, 3, 0
        db 18,1, 4,20, 4, 0
        db 0xA1, 0x41, 18       ; hero submenu (5E9Eh): right, left
        db 23,1, 0,14, 0, 0
        db 23,1, 16,6, 1, 0
        db 23,1, 24,7, 2, 0
        db 0x18, 0x61, 12       ; name letters (6015h, and the code letters): right, left, direct
        db 23,1, 0,26, 0, 1
        db 23,1, 27,3, 26, 3
        db 0x57, 0x41, 12       ; spell groups (6254h): right, left
        db 6,5, 0,32, 0, 16
        db 14,5, 0,32, 2, 16
        db 0xEE, 0x44, 6        ; shop, heroes (62EBh): down, up
        db 4,5, 0,10, 0, 0
        db 0x3C, 0x44, 24       ; shop, items (6339h): down, up
        db 15,7, 1,15, 0, 0
        db 15,4, 17,15, 7, 0
        db 19,1, 17,15, 11, 0
        db 21,1, 17,15, 12, 0


; ---- pointer: hardware sprite and mouse ---------------------------------------
; rt_pointer: called from the interrupt. Polls the mouse (a poll costs about
; 10000 T-states) every second frame, or every 16th while none is known,
; and puts the two sprites of the pointer at the game's cursor position. The
; tip of the arrow (top-left pixel of the sprite) goes where the tip of the
; Spectrum pointer is: 12 pixels left of CursorX, on the line above CursorY.
; Keeps every register but AF.
rt_pointer:
        push bc
        push de
        push hl
        ld a,(rt_tick)
        inc a
        ld (rt_tick),a
        ld b,a
        ld a,(rt_mouse_port)
        or a
        ld a,1                  ; a known mouse: every second frame
        jr nz,rt_ptr_rate
        ld a,15                 ; looking for one: every 16th frame
rt_ptr_rate:
        and b
        call z,rt_mouse_poll
        call rt_pointer_y       ; hidden in menus without a detected mouse
        ld d,a                  ; the VDP shows a sprite one line below its Y
        ld a,(GAME_CURSOR_X)
        sub 12
        jr nc,rt_ptr_x
        xor a
rt_ptr_x:
        ld e,a
        ld a,SPR_ATTRS/16384
        out (VDP_CTRL),a
        ld a,0x8E
        out (VDP_CTRL),a
        ld a,SPR_ATTRS & 255
        out (VDP_CTRL),a
        ld a,((SPR_ATTRS/256) & 0x3F) | 0x40
        out (VDP_CTRL),a
        ld a,d
        out (VDP_DATA),a
        ld a,e
        out (VDP_DATA),a
        xor a                   ; pattern 0
        out (VDP_DATA),a
        out (VDP_DATA),a
        ld a,d
        out (VDP_DATA),a
        ld a,e
        out (VDP_DATA),a
        ld a,4                  ; pattern 4
        out (VDP_DATA),a
        xor a
        out (VDP_DATA),a
        pop hl
        pop de
        pop bc
        ret

rt_sprite_end:
        db 216                  ; Y = 216: no more sprites

; rt_mouse_poll: reads an MSX mouse in joystick port 1 or 2 by direct PSG
; access (the BIOS is not available). A port is taken as "mouse" once it
; answers (0,0), which a joystick cannot produce, and dropped after 8 polls
; answering (FFh,FFh), which is what an empty port or an idle joystick
; gives. While no mouse is known the two ports are polled in turn. Movement
; is added to the game's cursor inside its limits; the left button is kept
; in rt_mouse_btn. Clobbers AF, BC, DE, HL.
; MOUSE NOTE: the offsets are taken as negated movement (the cursor moves by
; minus the offset). This has not been checked with a real or emulated mouse
; being moved; if the pointer goes the wrong way, remove the two NEGs below.
rt_mouse_poll:
        ld a,(rt_mouse_port)
        or a
        jr nz,rt_mp_port
        ld a,(rt_mouse_try)
        xor 1
        ld (rt_mouse_try),a
        inc a
rt_mp_port:
        ld c,a                  ; C = port polled, 1 or 2
        ld de,0x1310            ; port 1: pins 6-7 high, pin 8 high; toggle mask
        dec a
        jr z,rt_mp_read
        ld de,0x6C20            ; port 2
rt_mp_read:
        push bc
        call rt_gtmous          ; H = x offset, L = y offset
        pop bc
        ld (rt_mouse_raw),hl
        ld a,14
        out (PSG_ADDR),a
        in a,(PSG_READ)
        cpl
        and 0x30                ; trigger A = left button, trigger B = right button
        ld b,a
        ld a,15                 ; back to joystick port 1, pin 8 low
        out (PSG_ADDR),a
        in a,(PSG_READ)
        and 0x80
        or 0x0F
        out (PSG_WRITE),a
        ld a,h
        and l
        inc a
        jr z,rt_mp_absent       ; FFh, FFh
        ld a,h
        or l
        jr nz,rt_mp_moved
        ld a,c                  ; 0, 0: this is a mouse
        ld (rt_mouse_port),a
        xor a
        ld (rt_mouse_miss),a
        jr rt_mp_button
rt_mp_moved:
        ld a,(rt_mouse_port)
        cp c
        ret nz                  ; not confirmed as a mouse yet
        xor a
        ld (rt_mouse_miss),a
        push bc
        ld a,h
        neg                     ; the mouse reports the movement negated (MOUSE NOTE below)
        ld b,a
        ld a,(GAME_CURSOR_X)
        ld de,CURSOR_MIN_X*256+CURSOR_MAX_X
        call rt_add_clamp
        ld (GAME_CURSOR_X),a
        ld a,l
        neg
        ld b,a
        ld a,(GAME_CURSOR_Y)
        ld de,CURSOR_MIN_Y*256+CURSOR_MAX_Y
        call rt_add_clamp
        ld (GAME_CURSOR_Y),a
        pop bc
rt_mp_button:
        ld a,b
        and 0x10
        ld hl,rt_mouse_btn
        cp (hl)
        ld (hl),a
        jr z,rt_mp_button2
        or a
        jr z,rt_mp_button2
        ld (rt_mouse_click),a   ; just pressed (a menu may be busy and miss the press)
rt_mp_button2:
        ld a,b
        and 0x20
        ld (rt_mouse_btn2),a
        ret
rt_mp_absent:
        ld a,(rt_mouse_port)
        cp c
        ret nz
        ld a,(rt_mouse_miss)
        inc a
        ld (rt_mouse_miss),a
        cp 8
        ret c
        xor a
        ld (rt_mouse_port),a
        ld (rt_mouse_btn),a
        ret

; rt_add_clamp: A = A + B (B signed), kept inside D..E. Clobbers F.
rt_add_clamp:
        bit 7,b
        jr nz,rt_ac_neg
        add a,b
        jr c,rt_ac_max
        cp e
        ret c
rt_ac_max:
        ld a,e
        ret
rt_ac_neg:
        add a,b
        jr nc,rt_ac_min
        cp d
        ret nc
rt_ac_min:
        ld a,d
        ret

; rt_gtmous: the standard MSX mouse read. In: D = PSG register 15 value with
; pin 8 high, E = pin 8 bit. Out: H = x offset, L = y offset (FFh, FFh when
; nothing answers). The mouse sends four nibbles, one per edge of pin 8,
; and needs a pause after each edge. Clobbers AF, BC, D.
rt_gtmous:
        ld b,30                 ; long pause before the first nibble
        call rt_gm_nibble
        and 0x0F
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld b,10
        call rt_gm_nibble
        and 0x0F
        or c
        ld h,a
        ld b,10
        call rt_gm_nibble
        and 0x0F
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld b,10
        call rt_gm_nibble
        and 0x0F
        or c
        ld l,a
        ret
rt_gm_nibble:
        ld a,15
        out (PSG_ADDR),a
        in a,(PSG_READ)
        and 0x80                ; keep the kana LED bit
        or d
        out (PSG_WRITE),a
        xor e                   ; next edge of pin 8
        ld d,a
        ld a,b                  ; pause: 9 x B loops
rt_gm_wait1:
        djnz rt_gm_wait1
        rlca
        rlca
        ld b,a
rt_gm_wait2:
        djnz rt_gm_wait2
        ld b,a
rt_gm_wait3:
        djnz rt_gm_wait3
        ld a,14
        out (PSG_ADDR),a
        in a,(PSG_READ)
        ret

; rt_vram_write: copy B bytes from HL (page 0 RAM) to VRAM address DE (below
; 8000h). Interrupts must be disabled. Clobbers AF, BC, HL.
rt_vram_write:
        ld a,d
        rlca
        rlca
        and 3
        out (VDP_CTRL),a
        ld a,0x8E
        out (VDP_CTRL),a
        ld a,e
        out (VDP_CTRL),a
        ld a,d
        and 0x3F
        or 0x40
        out (VDP_CTRL),a
        ld c,VDP_DATA
        otir
        ret

; ---- VDP access ---------------------------------------------------------------
; Every sequence of writes to the VDP control port runs with interrupts
; disabled: the interrupt entry reads the status port, which resets the
; address/register latch.

; rt_iff: are interrupts enabled? Out: parity even (PE) if they are, parity
; odd (PO) if not; the callers push AF, disable interrupts and later restore
; them with "pop af / jp po". LD A,I alone is not enough: if an interrupt is
; accepted during it, the flag says "disabled". In that case the interrupt
; has overwritten the zero byte left just below the stack pointer, which is
; checked. Clobbers AF.
rt_iff:
        xor a
        push af
        pop af                  ; (SP-1) = 0
        ld a,i
        jp pe,rt_iff_on
        dec sp
        dec sp
        pop af                  ; A = (SP-1)
        or a
        jr nz,rt_iff_on
        inc a
        or a                    ; PO
        ret
rt_iff_on:
        xor a                   ; PE
        ret

; rt_vdp_cmd: run a VDP command. In: HL -> 15 bytes for R#32-R#46 (SX, SY, DX,
; DY, NX, NY as words, colour, argument, command). Waits for the previous
; command to end first. Clobbers AF, BC, HL.
rt_vdp_cmd:
        call rt_iff
        push af
        di
        ld a,2
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 2: status register 2
        out (VDP_CTRL),a
        in a,(VDP_CTRL)
        ld b,a
        xor a
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 0 again for the interrupt entry
        out (VDP_CTRL),a
        bit 0,b                 ; CE: a command is still running
        jr z,rt_vc_go
        pop af                  ; wait with the interrupts as they were, so
        jp po,rt_vdp_cmd        ; that the music does not stall
        ei
        jp rt_vdp_cmd
rt_vc_go:
        ld a,32
        out (VDP_CTRL),a
        ld a,0x91               ; R#17 = 32, auto increment
        out (VDP_CTRL),a
        ld bc,15*256+VDP_REGS
        otir
        pop af
        ret po
        ei
        ret

; rt_load_blob: copy a graphics blob from ROM to VRAM. In: HL -> descriptor
; (see build/gfx.inc). The data is sent in pieces of up to 256 bytes; for
; each one the cartridge replaces page 1 with interrupts disabled, and in
; between RAM is back and interrupts are as the caller had them, so the
; music keeps playing. Runs on the runtime stack. Clobbers AF, BC, DE, HL.
rt_load_blob:
        ld (rt_sp),sp
        ld sp,RT_STACK
        call rt_load_blob_boot
        ld sp,(rt_sp)
        ret

; rt_load_blob_boot: the same for callers already on the runtime stack.
rt_load_blob_boot:
        ld a,(hl)
        inc hl
        rrca
        rrca
        and 1
        ld (rt_lr_hi),a         ; VRAM address bit 16
        dec hl
        ld a,(hl)
        inc hl
        rrca
        rrca
        and 0xC0
        ld d,a                  ; bits 15-14
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        or d
        ld d,a
        ld (rt_lr_addr),de
        ld b,(hl)               ; pieces
        inc hl
rt_lb_piece:
        push bc
        ld a,(hl)
        inc hl
        ld (rt_lb_seg),a
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = address in the ROM window
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = length
        inc hl
        push hl
        ex de,hl
rt_lb_chunk:
        ld a,b
        or a
        ld d,0                  ; D = bytes in this chunk (0 = 256)
        jr nz,rt_lb_send
        ld d,c
rt_lb_send:
        push bc
        call rt_iff
        push af
        di
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        ld a,(rt_lb_seg)
        ld (ASCII16_PAGE1),a
        push de
        ld de,(rt_lr_addr)
        ld a,(rt_lr_hi)
        add a,a
        add a,a
        ld c,a
        ld a,d
        rlca
        rlca
        and 3
        or c
        out (VDP_CTRL),a
        ld a,0x8E               ; R#14: VRAM address bits 16-14
        out (VDP_CTRL),a
        ld a,e
        out (VDP_CTRL),a
        ld a,d
        and 0x3F
        or 0x40                 ; write
        out (VDP_CTRL),a
        pop de
        ld b,d
        ld c,VDP_DATA
        otir                    ; B = 0 sends 256 bytes
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        pop af
        jp po,rt_lb_next
        ei
rt_lb_next:
        pop bc
        push hl
        ld hl,(rt_lr_addr)      ; next VRAM address
        ld a,d
        or a
        jr nz,rt_lb_part
        inc h                   ; + 256
        jr nz,rt_lb_addr
        ld a,1
        ld (rt_lr_hi),a
        jr rt_lb_addr
rt_lb_part:
        add a,l
        ld l,a
        jr nc,rt_lb_addr
        inc h
        jr nz,rt_lb_addr
        ld a,1
        ld (rt_lr_hi),a
rt_lb_addr:
        ld (rt_lr_addr),hl
        pop hl
        ld a,d                  ; bytes left
        or a
        jr nz,rt_lb_last
        dec b
        ld a,b
        or c
        jp nz,rt_lb_chunk
        jr rt_lb_done
rt_lb_last:
rt_lb_done:
        pop hl
        pop bc
        dec b
        jp nz,rt_lb_piece
        ret

; rt_load_rect: copy a graphic from ROM to a rectangle of VRAM, line by line.
; In: HL -> ROM segment, address in the ROM window; rt_lr_addr / rt_lr_hi =
; VRAM address of the first line (bits 15-0, bit 16); rt_lr_lines,
; rt_lr_width (bytes per line). Interrupts are disabled only while a line is
; sent. Clobbers AF, BC, DE, HL.
rt_load_rect:
        ld (rt_sp),sp
        ld sp,RT_STACK
        ld a,(hl)
        inc hl
        ld (rt_lb_seg),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = source
        ld a,(rt_lr_lines)
        ld b,a
rt_lr_line:
        push bc
        call rt_iff
        push af
        di
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        ld a,(rt_lb_seg)
        ld (ASCII16_PAGE1),a
        ld de,(rt_lr_addr)
        ld a,(rt_lr_hi)
        add a,a
        add a,a
        ld c,a
        ld a,d
        rlca
        rlca
        and 3
        or c
        out (VDP_CTRL),a
        ld a,0x8E
        out (VDP_CTRL),a
        ld a,e
        out (VDP_CTRL),a
        ld a,d
        and 0x3F
        or 0x40
        out (VDP_CTRL),a
        ex de,hl
        ld bc,128
        add hl,bc
        ld (rt_lr_addr),hl
        jr nc,rt_lr_same64k
        ld a,1
        ld (rt_lr_hi),a
rt_lr_same64k:
        ex de,hl
        ld a,(rt_lr_width)
        ld b,a
        ld c,VDP_DATA
        otir
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        pop af
        jp po,rt_lr_next
        ei
rt_lr_next:
        pop bc
        djnz rt_lr_line
        ld sp,(rt_sp)
        ret

; rt_furniture: the game is copying a furniture graphic (HL, bank 6) to its
; buffer at 6900h. Load the piece into its place in the sheet (page 2, x 0,
; y 200, 48 x 48, bottom aligned) unless it is there already. Keeps every
; register.
rt_furniture:
        push af
        push bc
        push de
        push hl
        ex de,hl                ; DE = graphic address
        ld hl,rt_furn_addrs
        ld b,17
        ld c,0
rt_fu_find:
        ld a,(hl)
        inc hl
        cp e
        jr nz,rt_fu_other
        ld a,(hl)
        cp d
        jr z,rt_fu_found
rt_fu_other:
        inc hl
        inc c
        djnz rt_fu_find
        jr rt_fu_done           ; not a known piece
rt_fu_found:
        ld a,(rt_furn_cur)
        cp c
        jr z,rt_fu_done
        ld a,c
        ld (rt_furn_cur),a
        ld b,a
        add a,a
        add a,b                 ; 3 bytes per entry
        ld e,a
        ld d,0
        ld hl,rt_rect_furn
        add hl,de
        ld de,200*128           ; page 2, line 200
        ld (rt_lr_addr),de
        ld a,1
        ld (rt_lr_hi),a
        ld a,48
        ld (rt_lr_lines),a
        ld a,24
        ld (rt_lr_width),a
        call rt_load_rect
rt_fu_done:
        pop hl
        pop de
        pop bc
        pop af
        ret

; rt_picture: the game is copying a combat picture (HL, bank rt_bank) to its
; work buffer. Load it into the native scene where the game puts it: buffer
; column 8, line 0, 128 x 64. Keeps every register.
rt_picture:
        push af
        push bc
        push de
        push hl
        ex de,hl                ; DE = picture address
        ld a,(rt_bank)
        and 7
        ld c,a
        ld hl,rt_pic_ids
        ld b,0                  ; picture number
rt_pi_find:
        ld a,(hl)
        inc hl
        cp c
        jr nz,rt_pi_other
        ld a,(hl)
        cp e
        jr nz,rt_pi_other
        inc hl
        ld a,(hl)
        dec hl
        cp d
        jr z,rt_pi_found
rt_pi_other:
        inc hl
        inc hl
        inc b
        ld a,b
        cp 10
        jr nz,rt_pi_find
        jr rt_pi_done
rt_pi_found:
        ld a,b
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,rt_rect_pic
        add hl,de
        ld de,0x8000+26*128+32  ; page 1, line 26, x = 64
        ld (rt_lr_addr),de
        xor a
        ld (rt_lr_hi),a
        ld a,64
        ld (rt_lr_lines),a
        ld (rt_lr_width),a
        call rt_load_rect
        ld hl,RT_CELLMAP+2*32+8 ; no glyphs under the picture: rows 2-9, columns 8-23
        ld b,8
rt_pi_cells:
        push bc
        push hl
        ld bc,16
        call rt_zero
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz rt_pi_cells
        ld e,0
        ld a,64
        call rt_mark
rt_pi_done:
        pop hl
        pop de
        pop bc
        pop af
        ret

; ---- native drawing (stage 2): the scene is built in VRAM page 1 --------------
; rt_bufpos: In: HL = address in the Spectrum back buffer (E700h, 32 bytes
; per line). Out: D = byte column 0..31, E = line 0..175. Clobbers AF.
rt_bufpos:
        ld a,l
        and 31
        ld d,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        ld e,a
        ld a,h
        sub 0xE7
        add a,a
        add a,a
        add a,a
        or e
        ld e,a
        ret

; rt_draw: copy a graphic from the sheet in page 3 to the scene, colour 0
; transparent. In: B = sheet x, C = sheet y, H = width, L = height, D = byte
; column, E = line (as rt_bufpos). A graphic at column 31 belongs to the next
; line with its first 8 pixels cut off (the Spectrum code does the same for
; view cell 10). Buffer line n is screen line n + 16; the Spectrum picture
; starts 10 lines down. Clobbers AF, BC, DE, HL.
rt_draw:
        ld a,d
        cp 31
        jr nz,rt_draw_cmd
        ld a,b
        add a,8
        ld b,a
        ld a,h
        sub 8
        ld h,a
        ld d,0
        inc e
rt_draw_cmd:
        ld a,l
        call rt_mark
        push hl
        ld hl,rt_cmd
        ld (hl),b               ; SX
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c               ; SY: page 3
        inc hl
        ld (hl),3
        inc hl
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (hl),a               ; DX
        inc hl
        ld (hl),0
        inc hl
        ld a,e
        add a,26
        ld (hl),a               ; DY: page 1
        inc hl
        ld (hl),1
        inc hl
        pop bc
        ld (hl),b               ; NX
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c               ; NY
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0               ; colour
        inc hl
        ld (hl),0               ; argument
        inc hl
        ld (hl),VCMD_LMMM_TIMP
        ld hl,rt_cmd
        jp rt_vdp_cmd

; rt_floor: hook in DrawCellFloor (8B8Ch), replaces ld (ViewCellBufferPtr),hl.
; In: HL = buffer address of the view cell, DE = Spectrum tile graphic.
; Draws the tile in the native scene. Keeps every register.
rt_floor:
        ld (ZX_VIEWCELLPTR),hl
        push af
        push bc
        push de
        push hl
        push hl
        ld hl,rt_floor_addrs    ; tile number from the graphic address
        ld bc,7*256
rt_floor_find:
        ld a,(hl)
        inc hl
        cp e
        jr nz,rt_floor_other
        ld a,(hl)
        cp d
        jr z,rt_floor_found
rt_floor_other:
        inc hl
        inc c
        djnz rt_floor_find
        ld c,0                  ; unknown graphic: plain floor
rt_floor_found:
        ld a,c
        add a,a
        ld c,a
        ld b,0
        ld hl,rt_floor_pos
        add hl,bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        pop hl
        call rt_bufpos
        ld hl,48*256+24
        call rt_draw
        pop hl
        pop de
        pop bc
        pop af
        ret

rt_floor_addrs:                 ; Spectrum floor tile graphics (ZX/doc/analysis/gfx_index.md)
        dw 0xE4A8, 0xE520, 0xE598, 0xE610, 0xE688, 0xFF01, 0xFF79

; rt_wall: hook in BlitWallStrip (8B46h), replaces ld hl,(ViewCellBufferPtr).
; In: DE = Spectrum graphic (wall strip or north/west door, 24 x 50),
; BC = offset from the view cell. Draws it in the native scene.
; Out: HL = (ViewCellBufferPtr). Keeps every other register.
rt_wall:
        ld hl,(ZX_VIEWCELLPTR)
        push af
        push bc
        push de
        push hl
        add hl,bc
        push hl
        ex de,hl
        ld de,0x10000-0xC5BF    ; first wall graphic, 150 bytes each
        add hl,de
        ld de,0x10000-150
        ld a,0xFF
rt_wall_div:
        inc a
        add hl,de
        jr c,rt_wall_div
        ld b,a                  ; sheet x = 24 * number
        add a,a
        add a,b
        add a,a
        add a,a
        add a,a
        ld b,a
        ld c,WALL_SY
        pop hl
        call rt_bufpos
        ld hl,24*256+50
        call rt_draw
        pop hl
        pop de
        pop bc
        pop af
        ret

; rt_room: hook in BuildRoomView (8722h), replaces ld (ViewOriginCell),hl,
; right after SelectRoom has set RoomAttribute. Paints the room window of the
; native scene: the 17 runs of ViewAttrRuns filled with black (the Spectrum
; gives every room its own paper colour; the PC art is drawn for a dark
; background), then the edge art of the frame over them. Keeps every register.
rt_room:
        ld (ZX_VIEWORIGIN),hl
        push af
        push bc
        push de
        push hl
        push ix
        ld a,0xCC               ; black; the original used the paper colour of the room
        ld (rt_cmd+12),a        ; fill byte: the colour in both pixels
        xor a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld a,VCMD_HMMV
        ld (rt_cmd+14),a
        ld ix,ZX_VIEWATTRRUNS
        ld b,17
rt_room_run:
        push bc
        ld l,(ix+0)             ; attribute address of the first cell
        ld h,(ix+1)
        push hl                 ; the window replaces any text in these cells
        ld a,h
        sub ZX_ATTRS/256
        add a,RT_CELLMAP/256
        ld h,a
        ld c,(ix+2)
        ld b,0
        inc bc
        call rt_zero
        pop hl
        ld a,l
        and 31
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+4),a         ; DX
        xor a
        ld (rt_cmd+5),a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        ld e,a
        ld a,h
        sub ZX_ATTRS/256
        add a,a
        add a,a
        add a,a
        or e                    ; character row
        add a,a
        add a,a
        add a,a
        add a,10
        ld (rt_cmd+6),a         ; DY: page 1
        ld a,1
        ld (rt_cmd+7),a
        ld a,(ix+2)
        inc a                   ; cells in the run
        cp 33
        jr c,rt_room_one
        rrca                    ; several full rows: 256 x (cells / 32 * 8)
        rrca
        and 0x3F
        ld (rt_cmd+10),a
        xor a
        ld (rt_cmd+8),a
        inc a
        ld (rt_cmd+9),a
        jr rt_room_fill
rt_room_one:
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+8),a         ; NX (32 cells = 256)
        ld a,0
        jr nz,rt_room_nx
        inc a
rt_room_nx:
        ld (rt_cmd+9),a
        ld a,8
        ld (rt_cmd+10),a
rt_room_fill:
        ld hl,rt_cmd
        call rt_vdp_cmd
        inc ix
        inc ix
        inc ix
        pop bc
        dec b
        jp nz,rt_room_run
        ld a,2                  ; the whole picture has to be shown again
        ld (rt_dirty),a
        ld ix,rt_edge_tab
        ld b,EDGE_COUNT
rt_room_edge:
        push bc
        ld d,(ix+0)             ; column
        ld a,(ix+1)             ; character row -> buffer line
        add a,a
        add a,a
        add a,a
        sub 16
        ld e,a
        ld b,(ix+2)
        ld c,(ix+3)
        ld a,(ix+4)
        add a,a
        add a,a
        add a,a
        ld h,a
        ld l,8
        call rt_draw_cmd
        ld bc,5
        add ix,bc
        pop bc
        djnz rt_room_edge
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret

; rt_showbackdrop: replaces ShowBackdrop (9C02h). Loads the frame picture
; into the native scene. The original also copied the picture to the display
; file and to its buffer; of that only the attributes are still needed (they
; give the colours of the texts printed over the frame), and only when the
; game asks for the long copy (1B00h). Leaves interrupts enabled.
rt_showbackdrop:
        xor a
        ld (rt_pointer_menu),a
        ld a,(ZX_BACKDROPLEN+1)
        cp 0x1B
        jr nz,rt_sb_picture
        call ZX_PAGEBANK6       ; "pages" bank 6 for rt_ldir (disables interrupts)
        ld hl,0xD800
        ld de,ZX_ATTRS
        ld bc,0x0300
        call rt_ldir
        call ZX_PAGEBANK0
rt_sb_picture:
        ld hl,rt_blob_frame
rt_sb_blob:                     ; HL = blob of a picture for the whole scene
        push hl
        ld hl,RT_CELLMAP        ; the picture replaces every text
        ld bc,768
        call rt_zero
        pop hl
        call rt_load_blob
        ld a,2
        ld (rt_dirty),a
        ei
        ret

; rt_clear_buffer: the original ClearBackBuffer, for the line-of-sight test,
; which draws the board plan into the game's buffer and reads it back.
rt_clear_buffer:
        ld hl,0xE700
        ld de,0xE701
        ld bc,0x15FF
        ld (hl),0
        ldir
        ret

; ---- dirty band ----------------------------------------------------------------
; rt_mark: the scene lines E .. E+A-1 (buffer lines 0..175) changed, over
; the whole width. Keeps every register but AF.
rt_mark:
        push bc
        ld bc,0x001F
        call rt_mark_x
        pop bc
        ret

; rt_mark_x: the same for the character columns B .. C only (0..31).
; Keeps every register but AF.
rt_mark_x:
        push hl
        push de
        ld d,a                  ; height
        ld a,(rt_dirty)
        or a
        jr nz,rt_mark_grow
        inc a
        ld (rt_dirty),a
        ld a,e
        ld (rt_dy0),a
        add a,d
        dec a
        ld (rt_dy1),a
        ld a,b
        ld (rt_dx0),a
        ld a,c
        ld (rt_dx1),a
        jr rt_mark_done
rt_mark_grow:
        ld a,(rt_dy0)
        cp e
        jr c,rt_mark_low
        ld a,e
        ld (rt_dy0),a
rt_mark_low:
        ld a,e
        add a,d
        dec a
        ld h,a
        ld a,(rt_dy1)
        cp h
        jr nc,rt_mark_left
        ld a,h
        ld (rt_dy1),a
rt_mark_left:
        ld a,(rt_dx0)
        cp b
        jr c,rt_mark_right
        ld a,b
        ld (rt_dx0),a
rt_mark_right:
        ld a,(rt_dx1)
        cp c
        jr nc,rt_mark_done
        ld a,c
        ld (rt_dx1),a
rt_mark_done:
        pop de
        pop hl
        ret

; ---- text ----------------------------------------------------------------------
; rt_glyph: replaces PlotGlyph (8E6Fh). In: HL = glyph in the game's font
; (8 bytes), HL' = cursor in the back buffer, DE' = 32. Draws the glyph cell
; in the native scene with three VDP commands (fill with ink xor paper, AND
; with the white-on-0 glyph of the font sheet, XOR with paper) and then does
; what the original did to the game's buffer. The colours are those of
; TextAttr while the game is painting attributes, else those of the cell in
; the game's attribute table; inverse video swaps them.
; Out: as PlotGlyph (HL + 8, HL' 8 lines down, B = 0).
rt_glyph:
        push hl
        push de
        push bc
        ld de,0x10000-ZX_FONT
        add hl,de               ; offset inside the font
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        jp nz,rt_glyph_buffer   ; not a glyph of the font
        ld a,l
        cp 69
        jp nc,rt_glyph_buffer
        ld (rt_g_index),a
        exx
        push hl
        exx
        pop hl
        call rt_bufpos          ; D = column, E = line
        ld hl,(ZX_ATTRCALL)
        ld bc,0x10000-ZX_PAINTATTR
        add hl,bc
        ld a,e                  ; cell number = (row + 2) * 32 + column
        rrca
        rrca
        rrca
        and 31
        add a,2
        ld c,l
        ld b,h                  ; BC = 0 while the game paints attributes
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a                  ; HL = cell number
        push hl
        ld a,b
        or c
        jr nz,rt_glyph_cell
        ld a,(ZX_TEXTATTR)
        jr rt_glyph_attr
rt_glyph_cell:
        ld a,h
        or ZX_ATTRS/256
        ld h,a
        ld a,(hl)               ; the attribute the cell has now
rt_glyph_attr:
        pop hl
        ld c,a                  ; C = attribute
        push hl
        ld a,(ZX_INVOP)
        cp 0x2F                 ; CPL: inverse video
        ld a,(rt_g_index)
        jr nz,rt_glyph_record
        or 0x80
rt_glyph_record:
        inc a
        ld b,a                  ; B = glyph + 1, bit 7 = inverse
        ld a,h
        add a,RT_CELLMAP/256
        ld h,a
        ld a,(hl)
        cp b
        jr nz,rt_glyph_new
        ld a,h
        add a,(RT_ATTRSHADOW-RT_CELLMAP)/256
        ld h,a
        ld a,(hl)
        cp c
        jr z,rt_glyph_same      ; the cell already shows this glyph in these colours
        ld a,h
        sub (RT_ATTRSHADOW-RT_CELLMAP)/256
        ld h,a
rt_glyph_new:
        ld (hl),b
        ld a,h
        add a,(RT_ATTRSHADOW-RT_CELLMAP)/256
        ld h,a
        ld (hl),c               ; drawn with this attribute
        ld a,c
        call rt_attr_colours    ; B = ink, C = paper
        call rt_cell_draw
rt_glyph_same:
        pop hl                  ; the cell number
        pop bc                  ; drawn: leave the registers as PlotGlyph does,
        pop de                  ; without writing the glyph into the game's buffer
        pop hl
        ld a,l
        add a,8
        ld l,a
        jr nc,rt_glyph_cursor
        inc h
rt_glyph_cursor:
        exx
        inc h                   ; cursor 8 lines down (8 x 32 bytes)
        exx
        ld b,0
        ret

; rt_attr_colours: In: A = Spectrum attribute, B bit 7 = inverse video.
; Out: B = ink, C = paper in the game palette. Clobbers AF, HL.
rt_attr_colours:
        push de
        ld e,b                  ; inverse flag
        ld c,a
        and 7
        ld b,a                  ; ink
        ld a,c
        rrca
        rrca
        rrca
        and 7
        bit 6,c
        jr z,rt_ac_map
        or 8
        set 3,b
rt_ac_map:
        ld hl,rt_zx2game
        add a,l
        ld l,a
        ld c,(hl)               ; paper
        ld hl,rt_zx2game
        ld a,l
        add a,b
        ld l,a
        ld b,(hl)               ; ink
        bit 7,e
        jr z,rt_ac_done
        ld a,b
        ld b,c
        ld c,a
rt_ac_done:
        pop de
        ret

; rt_cell_mono: draw glyph rt_g_index in a character cell of the native scene
; with three VDP commands: fill with ink xor paper, AND with the white glyph
; of the font sheet, XOR with paper. In: D = column, E = buffer line of the
; cell (row * 8, F0h and F8h for the two screen rows above the buffer),
; B = ink, C = paper. Clobbers AF, BC, HL.
rt_cell_mono:
        ld a,e
        cp 0xF0
        jr c,rt_cd_band
        ld a,2                  ; above the buffer lines: show the whole picture
        ld (rt_dirty),a
        jr rt_cd_fill
rt_cd_band:
        push bc
        ld b,d
        ld c,d
        ld a,8
        call rt_mark_x
        pop bc
rt_cd_fill:
        ld hl,rt_cmd+4
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (hl),a               ; DX
        inc hl
        ld (hl),0
        inc hl
        ld a,e
        add a,26
        ld (hl),a               ; DY: page 1
        inc hl
        ld (hl),1
        inc hl
        ld (hl),8               ; NX
        inc hl
        ld (hl),0
        inc hl
        ld (hl),8               ; NY
        inc hl
        ld (hl),0
        inc hl
        ld a,b
        xor c
        ld (hl),a               ; colour: ink xor paper
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0x80            ; LMMV
        push bc
        ld hl,rt_cmd
        call rt_vdp_cmd
        ld a,(rt_g_index)
        and 0x7F
        ld b,a
        and 31
        add a,a
        add a,a
        add a,a
        ld (rt_cmd),a           ; SX
        xor a
        ld (rt_cmd+1),a
        ld a,b
        rlca
        rlca
        rlca
        and 7                   ; glyph / 32
        add a,a
        add a,a
        add a,a
        add a,FONT_SY
        ld (rt_cmd+2),a         ; SY: page 3
        ld a,3
        ld (rt_cmd+3),a
        ld a,0x91               ; LMMM, AND
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        call rt_vdp_cmd
        pop bc
        ld a,c
        ld (rt_cmd+12),a        ; colour: paper
        ld a,0x83               ; LMMV, XOR
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        jp rt_vdp_cmd

; rt_cell_plain: fill a character cell with one colour. In: D = column,
; E = line, B = colour. Clobbers AF, BC, HL.
rt_cell_plain:
        call rt_cell_dest
        ld a,b
        ld (rt_cmd+12),a
        ld a,0x80               ; LMMV
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        jp rt_vdp_cmd

; rt_cell_dest: DX, DY, NX, NY of rt_cmd for the cell D = column, E = line,
; and the dirty mark. Clobbers AF, HL.
rt_cell_dest:
        ld a,e
        cp 0xF0
        jr c,rt_cdest_band
        ld a,2
        ld (rt_dirty),a
        jr rt_cdest_set
rt_cdest_band:
        push bc
        ld b,d
        ld c,d
        ld a,8
        call rt_mark_x
        pop bc
rt_cdest_set:
        ld hl,rt_cmd+4
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        ld a,e
        add a,26
        ld (hl),a
        inc hl
        ld (hl),1
        inc hl
        ld (hl),8
        inc hl
        ld (hl),0
        inc hl
        ld (hl),8
        inc hl
        ld (hl),0
        inc hl
        inc hl
        ld (hl),0
        ret

; rt_cell_number: In: D = column, E = buffer line. Out: HL = cell number
; (screen row * 32 + column). Clobbers AF.
rt_cell_number:
        ld a,e
        add a,16
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ret

; rt_gfx_lookup: In: DE = Spectrum graphic address. Out: HL -> sheet page,
; x, y of that graphic; carry set if it is not in the sheets. Clobbers AF.
rt_gfx_lookup:
        ld hl,rt_gfx_tab
rt_gl_next:
        ld a,(hl)
        inc hl
        or (hl)
        scf
        ret z                   ; end of the table
        ld a,(hl)
        dec hl
        cp d
        jr nz,rt_gl_other
        ld a,(hl)
        cp e
        jr nz,rt_gl_other
        inc hl
        inc hl
        or a
        ret
rt_gl_other:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        jr rt_gl_next

; rt_portrait: replaces DrawFrameInverted (A3FBh), the hero and monster
; figures of the combat screen. In: A = frame number, HL = buffer address
; of the line below the figure, at its left edge. Draws the frame from the
; sheet in the native scene. Clobbers AF, BC, DE, HL like the original.
rt_portrait:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,ZX_FRAMETABLE
        add hl,bc
        ld c,(hl)               ; width
        inc hl
        ld b,(hl)               ; height
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        call rt_gfx_lookup
        jr c,rt_po_done
        ld a,(hl)
        ld (rt_cmd+3),a         ; sheet page
        inc hl
        ld a,(hl)
        ld (rt_cmd),a           ; SX
        inc hl
        ld a,(hl)
        ld (rt_cmd+2),a         ; SY
        pop hl
        push hl
        push bc
        call rt_bufpos          ; D = column, E = line below the figure
        pop bc
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+4),a         ; DX
        ld a,e
        sub b
        ld e,a                  ; top line
        add a,26
        ld (rt_cmd+6),a         ; DY: page 1
        ld a,1
        ld (rt_cmd+7),a
        ld a,c
        ld (rt_cmd+8),a         ; NX
        ld a,b
        ld (rt_cmd+10),a        ; NY
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+12),a
        ld (rt_cmd+13),a
        ld a,VCMD_LMMM_TIMP
        ld (rt_cmd+14),a
        ld a,b
        call rt_mark
        ld hl,rt_cmd
        call rt_vdp_cmd
rt_po_done:
        pop hl
        ret

; rt_los_plot: hook at 7F65h, replaces ld a,c / or (hl) / ld (hl),a: the
; line-of-sight test marks each point of its line on the board plan. Draws
; the point in the native scene (XOR, so that it shows on any colour).
; Keeps every register but A.
rt_los_plot:
        ld a,c
        or (hl)
        ld (hl),a
        push af
        push bc
        push de
        push hl
        ld a,(ZX_LOSX)
        add a,24                ; the plan starts at column 3
        ld (rt_cmd+4),a
        ld a,(ZX_LOSY)
        add a,8                 ; and at character row 1 of the buffer
        ld e,a
        add a,26
        ld (rt_cmd+6),a
        ld a,1
        ld (rt_cmd+7),a         ; page 1
        call rt_mark
        xor a
        ld (rt_cmd+5),a
        ld (rt_cmd+13),a
        ld a,15
        ld (rt_cmd+12),a
        ld a,0x53               ; PSET, XOR
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        call rt_vdp_cmd
        pop hl
        pop de
        pop bc
        pop af
        ret

; ---- overview map ------------------------------------------------------------
; The map is made of character cells: a base tile (CopyMapTile) and glyphs
; ORed over it (OrMapGlyph, large furniture marks). The original keeps
; drawing them into its buffer, which the line-of-sight test reads; the
; hooks add the native cells. Colours come from the attribute table, like
; text.

; ---- overview map, PC style ------------------------------------------------------
; The original draws the board plan into its buffer (the line-of-sight test
; reads it back from there) and these hooks draw it in the native scene with
; coloured tiles of the sheet: the floor of the room, the walls and doors
; over it, then the markers and the furniture marks. The cells are not
; recorded in the cell maps: the attribute colours the Spectrum gives the
; map are not used.
; The two glyph hooks replace "ld b,8 / push de": the return address is
; taken off the stack so that DE can be pushed under it.
; rt_maptile: hook in CopyMapTile (9449h). In: HL = wall tile, DE = buffer
; cell, HL' = the cell in the wall plane (its flags are 200h below).
rt_maptile:
        ex (sp),hl
        ld (rt_map_jp+1),hl
        pop hl
        push de
        push af
        push bc
        push de
        push hl
        call rt_map_glyph_id
        jr c,rt_map_done
        push af
        ex de,hl
        call rt_bufpos          ; D = column, E = line
        exx
        dec h
        dec h
        ld a,(hl)               ; flags: bit 6 explored, bits 0-5 room
        inc h
        inc h
        exx
        bit 6,a
        jr z,rt_mt_walls        ; not explored: only its walls, on the parchment
        and 0x3F
        cp 40
        jr c,rt_mt_room
        xor a
rt_mt_room:
        ld c,MAPFLOOR_SY
        cp 32
        jr c,rt_mt_floor
        sub 25
        ld c,MAPGLYPH_SY+8
rt_mt_floor:
        push de
        call rt_map_draw
        pop de
rt_mt_walls:
        pop af
        cp 1                    ; tile 1 has no walls
        call nz,rt_map_glyph
rt_map_done:
        pop hl
        pop de
        pop bc
        pop af
        ld b,8
rt_map_jp:
        jp 0                    ; operand: back into the hooked routine

; rt_mapglyph: hook in OrMapGlyph (945Ch). In: HL = glyph, DE = buffer cell.
rt_mapglyph:
        ex (sp),hl
        ld (rt_map_jp+1),hl
        pop hl
        push de
        push af
        push bc
        push de
        push hl
        call rt_map_glyph_id
        jr c,rt_map_done
        push af
        ex de,hl
        call rt_bufpos
        jr rt_mt_walls

; rt_map_glyph: draw map glyph A (0..32) at column D, line E.
; rt_map_draw: draw the 8 x 8 tile at cell A of sheet row C there.
; Clobber AF, BC, DE, HL.
rt_map_glyph:
        add a,5
        ld c,MAPGLYPH_SY
        cp 32
        jr c,rt_map_draw
        ld c,MAPGLYPH_SY+8
rt_map_draw:
        add a,a
        add a,a
        add a,a
        ld b,a
        ld hl,0x0808
        jp rt_draw

; rt_map_glyph_id: In: HL = address of an 8-byte map glyph. Out: A = its
; number 0..33, carry set if it is not one of them. Clobbers HL.
rt_map_glyph_id:
        push de
        ld de,0x10000-ZX_MAPGLYPHS
        add hl,de
        pop de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp 34
        ccf
        ret

; rt_mapobj: hook at 9410h, in the large map object code, replaces
; call PageBank6. In: IX = record of the object, top of the stack (under
; the return address) = buffer address of its top-left cell. Draws the mark
; natively. The original then copies the bitmap from the bank and ORs it
; into its buffer as before.
rt_mapobj:
        pop hl                  ; return address
        pop de                  ; top-left cell
        push de
        push hl
        push ix
        pop hl
        ld bc,0x10000-ZX_MAPOBJTAB
        add hl,bc               ; 8 bytes per record -> 4 per entry
        srl l
        ld bc,rt_mapobj_tab
        add hl,bc
        ld b,(hl)               ; sheet x
        inc hl
        ld c,(hl)               ; sheet y
        inc hl
        ld a,(hl)               ; width
        inc hl
        ld l,(hl)               ; height
        ld h,a
        push hl
        ex de,hl
        call rt_bufpos
        pop hl
        call rt_draw
        jp ZX_PAGEBANK6         ; the replaced call

; rt_map_plan: replaces the call to ClearBackBuffer of DrawBoardPlan (750Bh):
; the line-of-sight test needs the game's buffer cleared.
; rt_map_show: replaces the call to ClearScreenAndBuffer of ShowBoardMap
; (A3C8h). Both then put the parchment in the scene, under the map.
rt_map_plan:
        call rt_clear_buffer
        jr rt_map_parch
rt_map_show:
        call ZX_CLEARALL
rt_map_parch:
        ld hl,rt_blob_parch
        jp rt_sb_blob

; rt_attr_scan: redraw the glyph cells whose attribute changed since they
; were drawn (menu highlights and every other colour change the game makes
; only in its attribute table). Called by rt_present. Clobbers AF, BC, DE, HL.
rt_attr_scan:
        ld hl,ZX_ATTRS
        ld de,RT_ATTRSHADOW
        ld bc,768
rt_as_next:
        ld a,(de)
        cp (hl)
        jr nz,rt_as_changed
rt_as_cont:
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,rt_as_next
        ret
rt_as_changed:
        ld a,(hl)
        ld (de),a
        push hl
        push de
        push bc
        ld c,a                  ; new attribute
        ld a,h
        sub ZX_ATTRS/256
        ld d,a                  ; cell number in D:L
        add a,RT_CELLMAP/256
        ld h,a
        ld a,(hl)
        or a
        jr z,rt_as_skip         ; no glyph in this cell
        dec a
        ld (rt_g_index),a       ; bit 7 = inverse (rt_cell_draw masks it)
        ld b,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        ld e,a
        ld a,d
        add a,a
        add a,a
        add a,a
        or e                    ; screen row
        add a,a
        add a,a
        add a,a
        sub 16
        ld e,a                  ; buffer line
        ld a,l
        and 31
        ld d,a                  ; column
        ld a,c
        call rt_attr_colours
        call rt_cell_draw
rt_as_skip:
        pop bc
        pop de
        pop hl
        jp rt_as_cont

; rt_zero: fill BC bytes from HL with 0. Clobbers AF, BC, DE, HL.
rt_zero:
        ld (hl),0
        ld d,h
        ld e,l
        inc de
        dec bc
        ld a,b
        or c
        ret z
        ldir
        ret

rt_glyph_buffer:                ; not a font glyph: the original plot, into the buffer
        pop bc
        pop de
        pop hl
        ld a,(ZX_INVOP)
        cp 0x2F
        ld b,8
        jr z,rt_glyph_inv
rt_glyph_plain:
        ld a,(hl)
        inc hl
        exx
        ld (hl),a
        add hl,de
        exx
        djnz rt_glyph_plain
        ret
rt_glyph_inv:
        ld a,(hl)
        cpl
        inc hl
        exx
        ld (hl),a
        add hl,de
        exx
        djnz rt_glyph_inv
        ret

; ---- clearing --------------------------------------------------------------------
; rt_clear_scene: hook in ClearBackBuffer (9C4Dh), replaces ld hl,BackBuffer.
; Blacks out the 176 buffer lines of the native scene. Out: HL = E700h.
rt_clear_scene:
        push af
        push bc
        push de
        ld hl,rt_cmd_clear_buf
        call rt_vdp_cmd
        ld hl,RT_CELLMAP+64     ; no glyphs left in rows 2-23
        ld bc,768-64
        call rt_zero
        ld e,0
        ld a,176
        call rt_mark
        pop de
        pop bc
        pop af
        ld hl,0xE700
        ret

; rt_clear_all: hook in ClearScreenBitmap (9C3Fh), replaces ld hl,4000h.
; Blacks out the whole native scene. Out: HL = 4000h.
rt_clear_all:
        push af
        push bc
        push de
        ld hl,rt_cmd_clear1
        call rt_vdp_cmd
        ld hl,RT_CELLMAP
        ld bc,768
        call rt_zero
        pop de
        ld a,2
        ld (rt_dirty),a
        pop bc
        pop af
        ld hl,0x4000
        ret

; ---- sprites and presentation ---------------------------------------------------
; rt_spr_mark: replaces the body of DrawSpritesByDepth (A539h, after its
; SpritesFrozen test). The sprites are drawn by rt_present.
rt_spr_mark:
        ld a,1
        ld (rt_spr_pending),a
        ret

; rt_spr_unmark: replaces RestoreSprites (A8DEh). The original took the
; sprites out of its buffer here, after the blit of the pass; a blit that
; comes later (a text screen, the next turn) shows none. So a request that
; was not presented (the pass skips its blit when the turn has just ended)
; must not survive the pass.
rt_spr_unmark:
        xor a
        ld (rt_spr_pending),a
        ret

; rt_present: replaces BlitBackBuffer (8D03h). Shows what changed:
; - if the scene changed, the changed band (or the whole picture) is copied
;   from page 1 to the visible page 0;
; - the sprites the game asked for since the last call are drawn on page 0 in
;   depth order, but only if they differ from what is already there; the old
;   ones are first erased with copies of their rectangles from page 1.
; Clobbers AF, BC, DE, HL, IX like the original.
rt_present:
        call rt_attr_scan
        ld a,(rt_dirty)
        or a
        jp z,rt_pr_sprites
        cp 2
        jr nz,rt_pr_band
        xor a                   ; whole picture: it overwrites every sprite
        ld (rt_spr_shown),a
        ld (rt_dx0),a
        ld a,31
        ld (rt_dx1),a
        ld bc,10*256+192        ; lines 10..201
        jr rt_pr_copy
rt_pr_band:
        ld a,(rt_dy0)
        ld b,a
        ld a,(rt_dy1)
        sub b
        inc a
        ld c,a                  ; C = lines
        ld a,b
        add a,26
        ld b,a                  ; B = first screen line
        ld a,(rt_spr_shown)
        or a
        jr z,rt_pr_copy
        ld a,(rt_spr_pending)
        or a
        jr nz,rt_pr_band_keep
        push bc                 ; no sprites wanted any more: take them off
        call rt_spr_erase
        pop bc
        xor a
        ld (rt_spr_shown),a
        jr rt_pr_copy
rt_pr_band_keep:
        ; The sprites stay on the screen. Only if the changed rectangle
        ; crosses one of them does the list have to be drawn again (the copy
        ; overwrites that part): the list is then forgotten, so that
        ; rt_spr_update redraws it.
        ld hl,rt_cache_old
        ld a,(hl)
        or a
        jr z,rt_pr_copy
        ld d,a                  ; D = sprites
        inc hl
        ld a,b
        add a,c
        dec a
        ld e,a                  ; E = last line of the band
rt_pr_cross:
        push de
        ld d,(hl)               ; D = left of the sprite
        inc hl
        ld a,e
        cp (hl)                 ; band ends above the sprite?
        jr c,rt_pr_cross_next
        ld a,(hl)
        inc hl
        inc hl
        add a,(hl)
        dec a                   ; last line of the sprite
        dec hl
        dec hl
        cp b                    ; sprite ends above the band?
        jr c,rt_pr_cross_next
        ld a,(rt_dx1)           ; right edge of the band in pixels
        add a,a
        add a,a
        add a,a
        or 7
        cp d                    ; band ends left of the sprite?
        jr c,rt_pr_cross_next
        inc hl
        ld a,d
        add a,(hl)
        dec a
        ld d,a                  ; D = right of the sprite
        dec hl
        ld a,(rt_dx0)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,d
        cp e                    ; sprite ends left of the band?
        jr c,rt_pr_cross_next
        pop de
        xor a
        ld (rt_cache_old),a     ; they cross
        jr rt_pr_copy
rt_pr_cross_next:
        ld de,6
        add hl,de
        pop de
        dec d
        jr nz,rt_pr_cross
rt_pr_copy:
        ld a,(rt_dx0)
        add a,a
        add a,a
        add a,a
        ld (rt_cmd),a           ; SX
        ld (rt_cmd+4),a         ; DX
        ld e,a
        ld a,(rt_dx1)
        add a,a
        add a,a
        add a,a
        add a,8
        sub e                   ; width in pixels, 0 = 256
        ld (rt_cmd+8),a         ; NX
        ld a,0
        jr nz,rt_pr_nx
        inc a
rt_pr_nx:
        ld (rt_cmd+9),a
        ld a,b
        ld (rt_cmd+2),a         ; SY: page 1
        ld (rt_cmd+6),a         ; DY: page 0
        ld a,c
        ld (rt_cmd+10),a        ; NY
        ld a,1
        ld (rt_cmd+3),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+7),a
        ld (rt_cmd+11),a
        ld (rt_cmd+12),a
        ld (rt_cmd+13),a
        ld a,0xD0               ; HMMM
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        call rt_vdp_cmd
        xor a
        ld (rt_dirty),a
rt_pr_sprites:
        ld a,(rt_spr_pending)
        or a
        jr z,rt_pr_none
        xor a
        ld (rt_spr_pending),a
        call rt_spr_collect
        ld a,(rt_spr_shown)
        or a
        jr nz,rt_pr_compare
        ld (rt_cache_old),a     ; nothing on the screen
        inc a
        ld (rt_spr_shown),a
        jr rt_pr_changed
rt_pr_compare:
        ld hl,rt_cache_new      ; same sprites as on screen: nothing to do
        ld de,rt_cache_old
        ld a,(de)
        cp (hl)
        jr nz,rt_pr_changed
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b                   ; 7 bytes per entry
        jr z,rt_pr_same
        ld b,a
rt_pr_cmp:
        inc hl
        inc de
        ld a,(de)
        cp (hl)
        jr nz,rt_pr_changed
        djnz rt_pr_cmp
rt_pr_same:
        ret
rt_pr_changed:
        call rt_spr_update      ; without flicker when the change is small
        ret nc
        call rt_spr_erase
rt_pr_draw:
        ld hl,rt_cache_new
        ld de,rt_cache_old
        ld bc,1+14*7
        ldir
        call rt_spr_draw
        ld a,1
        ld (rt_spr_shown),a
        ret
rt_pr_none:
        ld a,(rt_spr_shown)
        or a
        ret z
        xor a
        ld (rt_spr_shown),a
        ld (rt_cache_new),a     ; no sprites wanted
        call rt_spr_update
        ret nc
        call rt_spr_erase
        xor a
        ld (rt_cache_old),a
        ret

; rt_spr_update: change the sprites on the screen from rt_cache_old to
; rt_cache_new without a visible erase. Only when the rectangles that
; appear, disappear or change fit in 44 lines: their bounding box is copied
; from the scene to a
; scratch area (the hidden lines of page 1), the sprites that touch it are
; drawn there clipped, and the box is copied to the screen in one go.
; Out: carry set if it could not be done this way (nothing drawn).
rt_spr_update:
        ld hl,0x00FF            ; box: x0 = y0 = 255, x1 = y1 = 0
        ld (rt_bb_x0),hl        ; x0, x1
        ld (rt_bb_y0),hl        ; y0, y1
        ld hl,rt_cache_old      ; rectangles that are on the screen and not wanted
        ld de,rt_cache_new
        call rt_su_diff
        ld hl,rt_cache_new      ; and wanted but not on the screen
        ld de,rt_cache_old
        call rt_su_diff
        ld a,(rt_bb_x1)
        ld b,a
        ld a,(rt_bb_x0)
        cp b
        jr c,rt_su_box
        jr z,rt_su_box
        or a                    ; nothing differs
        ret
rt_su_box:
        and 0xFE                ; byte-aligned box for the fast copies
        ld (rt_bb_x0),a
        ld a,b
        or 1
        ld (rt_bb_x1),a
        ld a,(rt_bb_y0)
        ld b,a
        ld a,(rt_bb_y1)
        sub b
        cp 44
        ccf
        ret c                   ; taller than the scratch area
        inc a
        ld (rt_cmd+10),a        ; NY
        ld a,(rt_bb_x0)
        ld b,a
        ld (rt_cmd),a           ; SX
        ld (rt_cmd+4),a         ; DX
        ld a,(rt_bb_x1)
        sub b
        inc a
        ld (rt_cmd+8),a         ; NX (0 = 256)
        ld a,0
        jr nz,rt_su_nx
        inc a
rt_su_nx:
        ld (rt_cmd+9),a
        ld a,(rt_bb_y0)
        ld (rt_cmd+2),a         ; SY: scene, page 1
        ld a,212
        ld (rt_cmd+6),a         ; DY: scratch, hidden lines of page 1
        ld a,1
        ld (rt_cmd+3),a
        ld (rt_cmd+7),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+11),a
        ld (rt_cmd+12),a
        ld (rt_cmd+13),a
        ld a,0xD0               ; HMMM
        ld (rt_cmd+14),a
        ld hl,(rt_cmd+8)
        push hl                 ; NX
        ld hl,rt_cmd
        call rt_vdp_cmd
        ld ix,rt_cache_new+1    ; the sprites, clipped to the box, onto the scratch
        ld a,(rt_cache_new)
        or a
        jr z,rt_su_drawn        ; none wanted: the box is just the scene
        ld b,a
rt_su_draw:
        push bc
        call rt_su_clip
        ld bc,7
        add ix,bc
        pop bc
        djnz rt_su_draw
rt_su_drawn:
        pop hl
        ld (rt_cmd+8),hl        ; NX of the box again
        ld a,(rt_bb_y0)
        ld b,a
        ld (rt_cmd+6),a         ; DY: screen
        ld a,(rt_bb_y1)
        sub b
        inc a
        ld (rt_cmd+10),a
        ld a,(rt_bb_x0)
        ld (rt_cmd),a
        ld (rt_cmd+4),a
        ld a,212
        ld (rt_cmd+2),a         ; SY: scratch
        ld a,1
        ld (rt_cmd+3),a
        xor a
        ld (rt_cmd+7),a         ; page 0
        ld (rt_cmd+11),a
        ld a,0xD0               ; HMMM
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        call rt_vdp_cmd
        ld hl,rt_cache_new
        ld de,rt_cache_old
        ld bc,1+14*7
        ldir
        or a
        ret

; rt_su_diff: add to the box every rectangle of the list at HL that is not,
; identical, in the list at DE. Clobbers AF, BC, DE, HL.
rt_su_diff:
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
rt_sdf_entry:
        push bc
        push de
        ld a,(de)
        or a
        jr z,rt_sdf_missing
        ld c,a
        inc de
rt_sdf_search:
        push hl
        push de
        ld b,7
rt_sdf_cmp:
        ld a,(de)
        cp (hl)
        jr nz,rt_sdf_other
        inc hl
        inc de
        djnz rt_sdf_cmp
        pop de
        pop hl
        jr rt_sdf_next          ; found: unchanged
rt_sdf_other:
        pop de
        pop hl
        ld a,e
        add a,7
        ld e,a
        jr nc,rt_sdf_more
        inc d
rt_sdf_more:
        dec c
        jr nz,rt_sdf_search
rt_sdf_missing:
        call rt_bb_add
rt_sdf_next:
        ld bc,7
        add hl,bc
        pop de
        pop bc
        djnz rt_sdf_entry
        ret

; rt_bb_add: grow the box with the rectangle at HL (left, top, width,
; height). Keeps BC, DE, HL.
rt_bb_add:
        push hl
        push de
        ld e,(hl)               ; left
        inc hl
        ld d,(hl)               ; top
        inc hl
        ld a,(rt_bb_x0)
        cp e
        jr c,rt_bb_1
        ld a,e
        ld (rt_bb_x0),a
rt_bb_1:
        ld a,e
        add a,(hl)
        dec a                   ; right
        ld e,a
        ld a,(rt_bb_x1)
        cp e
        jr nc,rt_bb_2
        ld a,e
        ld (rt_bb_x1),a
rt_bb_2:
        inc hl
        ld a,(rt_bb_y0)
        cp d
        jr c,rt_bb_3
        ld a,d
        ld (rt_bb_y0),a
rt_bb_3:
        ld a,d
        add a,(hl)
        dec a                   ; bottom
        ld d,a
        ld a,(rt_bb_y1)
        cp d
        jr nc,rt_bb_4
        ld a,d
        ld (rt_bb_y1),a
rt_bb_4:
        pop de
        pop hl
        ret

; rt_su_clip: draw the part of the sprite at IX (cache entry) that lies in
; the box onto the scratch area, colour 0 transparent. Clobbers AF, BC, DE, HL.
rt_su_clip:
        ld a,(ix+0)
        add a,(ix+2)
        dec a
        ld d,a                  ; D = right
        ld a,(rt_bb_x0)
        ld b,a
        cp d
        jr z,rt_sc_x0
        ret nc                  ; box starts right of the sprite
rt_sc_x0:
        ld a,(rt_bb_x1)
        ld c,a
        cp (ix+0)
        ret c                   ; box ends left of it
        ld a,(ix+0)
        cp b
        jr nc,rt_sc_left
        ld a,b
rt_sc_left:
        ld e,a                  ; E = first column drawn
        ld a,d
        cp c
        jr c,rt_sc_right
        ld a,c
rt_sc_right:
        sub e
        inc a
        ld (rt_cmd+8),a         ; NX
        ld a,e
        ld (rt_cmd+4),a         ; DX
        sub (ix+0)
        add a,(ix+5)
        ld (rt_cmd),a           ; SX
        ld a,(ix+1)
        add a,(ix+3)
        dec a
        ld d,a                  ; D = bottom
        ld a,(rt_bb_y0)
        ld b,a
        cp d
        jr z,rt_sc_y0
        ret nc
rt_sc_y0:
        ld a,(rt_bb_y1)
        ld c,a
        cp (ix+1)
        ret c
        ld a,(ix+1)
        cp b
        jr nc,rt_sc_top
        ld a,b
rt_sc_top:
        ld e,a                  ; E = first line drawn
        ld a,d
        cp c
        jr c,rt_sc_bottom
        ld a,c
rt_sc_bottom:
        sub e
        inc a
        ld (rt_cmd+10),a        ; NY
        ld a,e
        sub b
        add a,212
        ld (rt_cmd+6),a         ; DY in the scratch
        ld a,e
        sub (ix+1)
        add a,(ix+6)
        ld (rt_cmd+2),a         ; SY
        ld a,(ix+4)
        ld (rt_cmd+3),a         ; sheet page
        ld a,1
        ld (rt_cmd+7),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld a,VCMD_LMMM_TIMP
        ld (rt_cmd+14),a
        ld hl,rt_cmd
        jp rt_vdp_cmd

rt_bb_x0:       db 0            ; box of the rectangles that change: x0, x1
rt_bb_x1:       db 0
rt_bb_y0:       db 0            ; y0, y1 (screen lines)
rt_bb_y1:       db 0

; rt_bake: replaces the two calls to DrawSpritesByDepth that are followed by
; "sprites frozen" (SearchCommand 8060h, RebuildSceneBuffer 8DC8h). The
; original drew the sprites into its buffer there and left them in it while
; a menu or a message box was up, the box drawn over them. Here the sprites
; are drawn into the scene (page 1) for the same effect; the next rebuild of
; the room removes them. Clobbers AF, BC, DE, HL, IX.
rt_bake:
        ld a,(ZX_FROZEN)
        or a
        ret nz
        ld (rt_spr_pending),a
        call rt_spr_collect
        ld a,1
        ld (rt_draw_page),a
        ld hl,rt_cache_new
        call rt_spr_draw_list
        xor a
        ld (rt_draw_page),a
        ld a,2                  ; show the whole picture again
        ld (rt_dirty),a
        ret

; rt_spr_collect: list the active sprites in depth order in rt_cache_new:
; count, then 7 bytes each: left, top (screen), width, height, sheet page,
; sheet x, sheet y.
rt_spr_collect:
        ld de,rt_cache_new+1
        ld c,0
        ld hl,ZX_DEPTHTAB
        ld b,90
rt_sc_scan:
        ld a,(hl)
        cp 0xFF
        jr z,rt_sc_next
        push hl
        push bc
        ld ix,ZX_SLOTS
        ld bc,18
        or a
rt_sc_find:
        jr z,rt_sc_found
        add ix,bc
        dec a
        jr rt_sc_find
rt_sc_found:
        call rt_spr_entry
        pop bc
        pop hl
        jr c,rt_sc_next
        inc c
        ld a,c
        cp 14
        jr z,rt_sc_end
rt_sc_next:
        inc l
        djnz rt_sc_scan
rt_sc_end:
        ld a,c
        ld (rt_cache_new),a
        ret

; rt_spr_entry: In: IX = sprite record, DE = where to write. Out: carry set
; if the graphic is not in the sheets (nothing written).
rt_spr_entry:
        ld l,(ix+10)
        ld h,(ix+11)            ; Spectrum graphic address
        push de
        ex de,hl
        ld a,d
        cp 0x69
        jr nz,rt_se_table
        ld a,e
        or a
        jr nz,rt_se_table
        ld a,248                ; the furniture buffer: the piece loaded by
        sub (ix+5)              ; rt_furniture, bottom aligned in its 48 x 48 cell
        ld (rt_furn_entry+2),a
        ld hl,rt_furn_entry-2
        jr rt_se_found
rt_se_table:
        ld hl,rt_gfx_tab
rt_se_find:
        ld a,(hl)
        inc hl
        or (hl)
        jr z,rt_se_missing      ; end of the table
        ld a,(hl)
        dec hl
        cp d
        jr nz,rt_se_other
        ld a,(hl)
        cp e
        jr z,rt_se_found
rt_se_other:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        jr rt_se_find
rt_se_missing:
        pop de
        scf
        ret
rt_se_found:
        inc hl
        inc hl                  ; HL -> page, x, y
        pop de
        ld a,(ix+4)
        srl a
        ld b,a
        ld a,(ix+2)
        sub b
        ld (de),a               ; left = centre - width / 2
        inc de
        ld a,(ix+3)
        sub (ix+5)
        add a,26
        ld (de),a               ; top = line below - height, as a screen line
        inc de
        ld a,(ix+4)
        ld (de),a
        inc de
        ld a,(ix+5)
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        or a
        ret

; rt_spr_erase: copy the rectangle of every sprite in rt_cache_old from the
; scene (page 1) to the screen (page 0).
rt_spr_erase:
        ld hl,rt_cache_old
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
rt_sx_next:
        push bc
        ld de,rt_cmd
        ld a,(hl)
        ld (de),a               ; SX = left
        ld (rt_cmd+4),a         ; DX
        inc hl
        ld a,(hl)
        ld (rt_cmd+2),a         ; SY: page 1
        ld (rt_cmd+6),a         ; DY: page 0
        inc hl
        ld a,(hl)
        ld (rt_cmd+8),a         ; NX
        inc hl
        ld a,(hl)
        ld (rt_cmd+10),a        ; NY
        inc hl
        inc hl
        inc hl
        inc hl
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+7),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+12),a
        ld (rt_cmd+13),a
        inc a
        ld (rt_cmd+3),a
        ld a,0x90               ; LMMM
        ld (rt_cmd+14),a
        push hl
        ld hl,rt_cmd
        call rt_vdp_cmd
        pop hl
        pop bc
        djnz rt_sx_next
        ret

; rt_spr_draw: draw every sprite of rt_cache_old on the screen (page 0) from
; its sheet, colour 0 transparent, in the order of the list (back to front).
rt_spr_draw:
        ld hl,rt_cache_old
rt_spr_draw_list:               ; the same for the list at HL, onto page rt_draw_page
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
rt_sd_next:
        push bc
        ld a,(hl)
        ld (rt_cmd+4),a         ; DX = left
        inc hl
        ld a,(hl)
        ld (rt_cmd+6),a         ; DY = top, page 0
        inc hl
        ld a,(hl)
        ld (rt_cmd+8),a         ; NX
        inc hl
        ld a,(hl)
        ld (rt_cmd+10),a        ; NY
        inc hl
        ld a,(hl)
        ld (rt_cmd+3),a         ; sheet page
        inc hl
        ld a,(hl)
        ld (rt_cmd),a           ; SX
        inc hl
        ld a,(hl)
        ld (rt_cmd+2),a         ; SY
        inc hl
        ld a,(rt_draw_page)
        ld (rt_cmd+7),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+12),a
        ld (rt_cmd+13),a
        ld a,VCMD_LMMM_TIMP
        ld (rt_cmd+14),a
        push hl
        ld hl,rt_cmd
        call rt_vdp_cmd
        pop hl
        pop bc
        djnz rt_sd_next
        ret

rt_cmd_clear_buf:               ; fill the 176 buffer lines of page 1 with colour 12
        dw 0,0, 0,256+26, 256,176
        db 0xCC,0,VCMD_HMMV

rt_furn_entry:  db 2,0,200      ; sheet page, x, y of the furniture piece
rt_furn_cur:    db 0xFF         ; piece loaded in the sheet
rt_lb_seg:      db 0            ; rt_load_blob: ROM segment of the piece
rt_lr_addr:     dw 0            ; rt_load_rect / rt_load_blob: next VRAM address
rt_lr_hi:       db 0
rt_lr_lines:    db 0
rt_lr_width:    db 0
rt_draw_page:   db 0            ; page the sprite list is drawn on: 0 screen, 1 scene
rt_dirty:       db 0            ; 0 nothing, 1 the band rt_dy0..rt_dy1, 2 the whole picture
rt_dy0:         db 0            ; first and last buffer line changed in the scene
rt_dy1:         db 0
rt_dx0:         db 0            ; first and last character column changed
rt_dx1:         db 31
rt_spr_pending: db 0            ; the game drew its sprites since the last rt_present
rt_spr_shown:   db 0            ; rt_cache_old is on the screen
rt_g_index:     db 0
rt_mi_cell:     dw 0            ; character cell under the tip of the pointer (column, row)
rt_mi_target:   db 0xFF         ; option the pointer asks for, FFh = none
rt_mi_budget:   db 0            ; steps left to reach it
rt_mi_click:    db 0            ; a click waits for the option to be reached

rt_cmd: ds 15,0                 ; VDP command being built

rt_cmd_clear0:                  ; fill page 0 (256 x 212) with colour 12
        dw 0,0, 0,0, 256,212
        db 0xCC,0,VCMD_HMMV

rt_cmd_clear1:                  ; fill page 1 (256 x 212) with colour 12
        dw 0,0, 0,256, 256,212
        db 0xCC,0,VCMD_HMMV

        ds ((($+15)/16)*16)-$,0 ; keep the table inside one 256-byte page
rt_zx2game:                     ; Spectrum colours 0-7, bright 0-7 in the game palette
        db 12,1,4,5,2,3,14,7, 12,9,0,13,10,11,14,15

        include "../build/gfx.inc"
        include "../build/snd.inc"

        assert $ <= RT_CODE_END
rt_end:
