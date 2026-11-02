; HeroQuest MSX2 - second part of the runtime, in page 1 RAM (4F00h)
; DiHalt Studio
;
; Code that never has to run while the cartridge is selected in page 1: the
; choice between the two music players and the set-up of the OPL4. Entered
; through the jump table at its start. Assembled after runtime.asm, whose
; labels come from build/rt_all.inc.

        include "../build/rt_all.inc"
        org RT2_BASE
        jp r2_snd_cmd
        jp r2_detect
        jp r2_menu
        jp r2_quest
        jp r2_qmenu
        jp r2_qfire
        jp r2_xexit
        jp r2_xevent
        jp r2_play
        jp r2_monnum
        jp r2_break
        jp r2_step
        jp r2_rock
        jp r2_keylabel
        jp r2_mist_turn
        jp r2_map_mist
        jp r2_code_save
        jp r2_code_load
        jp r2_ctrl
        jp r2_dir
        jp r2_dirwait
        jp r2_step5
        jp r2_quick
        jp r2_shopscr
        jp r2_shopexit
        jp r2_classprint
        jp r2_afteritem
        jp r2_afterhero
        jp r2_jump

; r2_menu: replaces the call to DrawMenuPage of the main menu (5B03h): the
; menu, then the credits under it. In: HL = menu text.
r2_menu:
        call ZX_DRAWMENUPAGE
        ld ix,r2_credits
        call ZX_PRINTSTRING
        call ZX_BLIT
        ld hl,rt_cmd            ; the boot leaves the display off: it comes on
        call rt_vdp_cmd         ; here, once the copy of the menu has ended
        di                      ; (rt_vdp_cmd waits for it; the command it
        ld a,0x62               ; then runs is the same copy again)
        out (VDP_CTRL),a
        ld a,0x81
        out (VDP_CTRL),a
        ei
        ret
r2_credits:                     ; PrintString stream: FBh colour, FFh column row, glyphs (5Fh = space), FAh end
        db 0xFB,5, 0xFF,9,12, 0x4A,0x55,0x45,0x47,0x4F,0x5F,0x4F,0x52,0x49,0x47,0x49,0x4E,0x41,0x4C    ; JUEGO ORIGINAL
        db 0xFB,6, 0xFF,5,13, 0x47,0x52,0x45,0x4D,0x4C,0x49,0x4E,0x5F,0x47,0x52,0x41,0x50,0x48,0x49,0x43,0x53,0x5F,0x31,0x39,0x39,0x31    ; GREMLIN GRAPHICS 1991
        db 0xFB,5, 0xFF,11,15, 0x50,0x4F,0x52,0x54,0x5F,0x4D,0x53,0x58,0x32    ; PORT MSX2
        db 0xFB,6, 0xFF,10,16, 0x44,0x49,0x48,0x41,0x4C,0x54,0x5F,0x32,0x30,0x32,0x36    ; DIHALT 2026
        db 0xFF,10,17, 0x56,0x45,0x52,0x53,0x49,0x4F,0x4E,0x5F,0x31,0x3A,0x30    ; VERSION 1.0
        db 0xFA

; ---- the quests of the expansion (14-23) -------------------------------------------
; r2_quest: replaces the choice of bank and pointer in the quest loader
; (5B50h). Out: DE = address of the quest data, B = value "paged" for it:
; the base quests are in Spectrum banks 1 and 3, the expansion quests in
; two more ROM segments reached as banks 2 and 5 (rt_bank_segs).
r2_quest:
        xor a
        ld (r2_keys),a          ; keys of Agrain found (quest 17)
        ld (r2_witch_dead),a
        call r2_monsters
        ld a,(ZX_QUESTINDEX)
        cp BASE_QUESTS
        jr nc,r2_quest_x
        ld b,0x11
        cp 7
        jr c,r2_quest_base
        ld b,0x13
r2_quest_base:
        ld hl,ZX_QUESTPTRS
        jp ZX_GETTABLEWORD
r2_quest_x:
        sub BASE_QUESTS
        ld b,0x12
        cp 5
        jr c,r2_quest_ptr
        ld b,0x15
r2_quest_ptr:
        ld hl,r2_xquest_ptrs
        jp ZX_GETTABLEWORD

; r2_xexit: replaces "ld a,(QuestIndex)" where HeroReachesExit indexes its
; table of 14 handlers (8EAFh). The expansion quests have no rule for the
; exit: they use the entry of a base quest that has none (quest 2).
r2_xexit:
        ld a,(ZX_QUESTINDEX)
        cp BASE_QUESTS
        ret c
        ld a,2
        ret

; r2_xevent: replaces the look-up of the search event handler in
; RunRoomSpecial (827Dh). In: A = event 1-29. Out: DE = handler. Events
; 1-18 are those of the base game; 19-29 are the eleven of the expansion
; (the quest data of the expansion is stored with its events 1-11 + 18).
; A handler gets IX = address of the room's event byte (the byte of the
; other search table of the room is 43 bytes away), IY = hero.
r2_xevent:
        dec a
        ld hl,ZX_SEARCHTAB
        cp 18
        jr c,r2_xevent_get
        sub 18
        ld hl,r2_xevents
r2_xevent_get:
        jp ZX_GETTABLEWORD
r2_xevents:
        dw ZX_GOLD200           ; 19: 200 coins (the base window says the same)
        dw r2_ev_gold300        ; 20
        dw r2_ev_potion100      ; 21
        dw r2_ev_trap           ; 22
        dw r2_ev_disarm         ; 23
        dw r2_ev_key            ; 24
        dw r2_ev_gold400        ; 25
        dw r2_ev_gold350        ; 26
        dw r2_ev_gold250        ; 27
        dw r2_ev_gold500        ; 28
        dw r2_ev_potions2       ; 29

r2_ev_gold250:
        ld de,250
        ld hl,XBOX_GOLD250
        ld bc,XBOX_GOLD250_N
        jr r2_ev_gold
r2_ev_gold300:
        ld de,300
        ld hl,XBOX_GOLD300
        ld bc,XBOX_GOLD300_N
        jr r2_ev_gold
r2_ev_gold350:
        ld de,350
        ld hl,XBOX_GOLD350
        ld bc,XBOX_GOLD350_N
        jr r2_ev_gold
r2_ev_gold400:
        ld de,400
        ld hl,XBOX_GOLD400
        ld bc,XBOX_GOLD400_N
        jr r2_ev_gold
r2_ev_gold500:
        ld de,500
        ld hl,XBOX_GOLD500
        ld bc,XBOX_GOLD500_N
r2_ev_gold:                     ; the event is used up; DE coins and the window at HL
        ld (ix+0),0xFF
        call r2_xbox
        jp ZX_GIVEGOLD
r2_ev_potion100:                ; a healing potion and 100 coins
        ld (ix+0),0xFF
        ld de,100
        ld hl,XBOX_POTION100
        ld bc,XBOX_POTION100_N
        call r2_xbox
        jp ZX_GIVEPOTION
r2_ev_potions2:                 ; two healing potions
        ld (ix+0),0xFF
        set 2,(iy+HERO_POTIONS)
        set 3,(iy+HERO_POTIONS)
        ld hl,XBOX_POTIONS2
        ld bc,XBOX_POTIONS2_N
        call r2_xbox
        jp ZX_SHOWBOX
r2_ev_trap:                     ; treasure search: the trap of the chest goes off
        ld (ix+0),0xFF
        ld (ix+43),0xFF
        ld ix,ZX_BOX_TRAP
        call ZX_SHOWBOX
        ld iy,(ZX_CURHERO)
r2_ev_trap_damage:
        ld a,(iy+HERO_BODY)
        cp 1
        jp z,ZX_TRAPKILLS
        dec (iy+HERO_BODY)
        jp ZX_BODYHUD
r2_ev_disarm:                   ; trap search: the trap is disarmed (and the chest is spent)
        ld (ix+0),0xFF
        ld (ix-43),0xFF
        ld ix,ZX_BOX_DISARM
        jp ZX_SHOWBOX
r2_ev_key:                      ; a key of Agrain: 100 coins; the fourth one uses the event up
        push ix
        ld hl,XBOX_KEY
        ld bc,XBOX_KEY_N
        call r2_xbox
        call ZX_SHOWBOX
        ld iy,(ZX_CURHERO)
        ld de,100
        call ZX_ADDGOLD
        call ZX_GOLDHUD
        ld iy,(ZX_CURHERO)
        set 6,(iy+HERO_QFLAGS)
        pop ix
        ld hl,r2_keys
        inc (hl)
        ld a,(hl)
        cp 4
        ret nz
        ld (ix+0),0xFF
        ret
r2_keys:        db 0

; r2_xbox: fetch BC bytes of expansion text at HL (address in the second
; expansion bank image, read like a Spectrum bank) into RT2_BUF.
; Out: IX = RT2_BUF. Keeps DE, IY. Interrupts enabled on return.
r2_xbox:
        push de
        di
        ld a,5
        ld (rt_bank),a
        ld de,RT2_BUF
        rst 0x08
        ld a,0x10
        ld (rt_bank),a
        ei
        pop de
        ld ix,RT2_BUF
        ret

; r2_monsters: the monster kinds and types 8-15 are different in the base
; game and in the expansion. The tables indexed by them are filled here, at
; every quest set-up, with the set of the quest: names, death pictures and
; map glyphs (tables of this part of the runtime, which the game code now
; uses instead of its own), statistics and death handlers (rows 8-15 of
; MonsterTypeTable), figures (frames 08h, 0Ch and 0Fh of the frame table).
; The type that only the Spirit Blade harms and no spell reaches is 11-12
; in the base game and 14 in the expansion: the two tests are rewritten.
r2_monsters:
        ld hl,r2_mset_base
        ld bc,0x0C3C            ; base: "inc a / and FEh / cp 0Ch"
        ld e,0xFE
        ld a,(ZX_QUESTINDEX)
        cp BASE_QUESTS
        jr c,r2_monsters_set
        ld hl,r2_mset_x
        ld bc,0x0E00            ; expansion: "nop / and FFh / cp 0Eh"
        ld e,0xFF
r2_monsters_set:
        ld a,c
        ld (ZX_IMMUNE1),a
        ld (ZX_IMMUNE2),a
        ld a,e
        ld (ZX_IMMUNE1+2),a
        ld (ZX_IMMUNE2+2),a
        ld a,b
        ld (ZX_IMMUNE1+4),a
        ld (ZX_IMMUNE2+4),a
        ld de,RT2_MNAMES+16
        ld bc,16
        ldir
        ld de,RT2_MPICS+24
        ld bc,24
        ldir
        ld de,RT2_MGLYPHS+16
        ld bc,16
        ldir
        ld de,ZX_TYPETAB+40
        ld bc,40
        ldir
        ld de,ZX_FRAMETABLE+4*0x08
        ld bc,4
        ldir
        ld de,ZX_FRAMETABLE+4*0x0C
        ld c,4
        ldir
        ld de,ZX_FRAMETABLE+4*0x0F
        ld c,4
        ldir
        ret

; the two sets for kinds / types 8-15: 8 name pointers, 8 death pictures,
; 8 map glyphs, 8 type rows, the frames 08h, 0Ch and 0Fh
r2_mset_base:
        dw 0xB59B,0xB5A5,0xB5AF,0xB5B9,0xB5B9,0xB5B9,0xB5B9,0xB5B9      ; ULAG, GRAK, BALUR, GRANBRUJO
        db 0x80,0xE8,0x14, 0x80,0xE8,0x14, 0x82,0xF3,0x13, 0x82,0xF3,0x13
        db 0x82,0xF3,0x13, 0x80,0xE8,0x14, 0x80,0xE8,0x14, 0x80,0xE8,0x14
        dw 0xB2A0,0xB2A0,0xB2A0,0xB2A0,0xB2A0,0xB2A0,0xB2A0,0xB2A0
        db 0x0A,0x04,0x05,0x02,0x76, 0x08,0x04,0x04,0x25,0x9A, 0x08,0x02,0x05,0x08,0x76, 0x01,0x02,0x06,0x25,0x9A
        db 0x0A,0x05,0x06,0x25,0x9A, 0x06,0x03,0x05,0x25,0x9A, 0x0A,0x02,0x01,0x1E,0x76, 0x08,0x03,0x02,0x24,0x76
        db 0x18,0x28,0xB3,0xE3, 0x18,0x28,0xB3,0xE3, 0x18,0x28,0xB3,0xE3         ; the sorcerer's figure
r2_mset_x:
        dw r2_xnames,r2_xnames+10,r2_xnames+20,r2_xnames+30,r2_xnames+40,r2_xnames+50,r2_xnames+60,r2_xnames+70
        db 0x82,0xF3,0x13, 0x80,0xE8,0x14, 0x80,0xE8,0x14, 0x80,0xE8,0x14     ; spirit: the skeleton's picture
        db 0xC0,0xC8,0x17, 0x80,0xE8,0x14, 0x80,0xE8,0x14, 0x80,0xE8,0x14     ; doomguard: the chaos warrior's
        dw 0xB288,0xB2A0,0xB2A0,0xB2A0,0xB280,0xB2A0,0xB2A0,0xB270            ; skeleton, sorcerer, chaos warrior, orc glyphs
        db 8,4,3
        dw ZX_NODEATH           ; 8 spirit: move, attack, defend
        db 6,4,3
        dw ZX_NODEATH           ; 9 death mist (never fights)
        db 6,4,6
        dw r2_death_bellthor    ; 10 Bellthor
        db 8,5,6
        dw ZX_NODEATH           ; 11 Skulmar
        db 6,4,6
        dw ZX_NODEATH           ; 12 doomguard
        db 6,4,6
        dw ZX_NODEATH           ; 13 Kessandra
        db 10,5,6
        dw r2_death_witch       ; 14 the Witch Lord
        db 8,3,2
        dw ZX_NODEATH           ; 15 the orcs that break weapons
        db 0x18,0x28,0x4B,0xE2, 0x18,0x28,0xD3,0xE1, 0x18,0x26,0xE9,0xE0         ; skeleton, chaos warrior, orc figures
r2_xnames:                      ; 9 characters and 00h each
        db 0x45,0x53,0x50,0x49,0x52,0x49,0x54,0x55,0x5F,0    ; ESPIRITU
        db 0x5F,0x4E,0x49,0x45,0x42,0x4C,0x41,0x5F,0x5F,0    ;  NIEBLA
        db 0x42,0x45,0x4C,0x4C,0x54,0x48,0x4F,0x52,0x5F,0    ; BELLTHOR
        db 0x5F,0x53,0x4B,0x55,0x4C,0x4D,0x41,0x52,0x5F,0    ;  SKULMAR
        db 0x47,0x55,0x41,0x52,0x44,0x49,0x41,0x4E,0x5F,0    ; GUARDIAN
        db 0x4B,0x45,0x53,0x53,0x41,0x4E,0x44,0x52,0x41,0    ; KESSANDRA
        db 0x53,0x52,0x3A,0x42,0x52,0x55,0x4A,0x4F,0x5F,0    ; SR.BRUJO
        db 0x5F,0x45,0x53,0x54,0x41,0x54,0x55,0x41,0x5F,0    ;  ESTATUA

; r2_death_bellthor: death handler of Bellthor (quest 18): the table next
; to him becomes the stairs, the only way out of the quest.
r2_death_bellthor:
        xor a
        ld (ZX_OBJECTS+7*26+13),a
        ld (ZX_OBJECTS+8*26+13),a
        ld a,0x38
        ld (ZX_OBJECTS+7*26+14),a
        inc a
        ld (ZX_OBJECTS+8*26+14),a
        inc a
        ld (ZX_OBJECTS+7*26+15),a
        inc a
        ld (ZX_OBJECTS+8*26+15),a
        ld a,1
        ld (ZX_REDRAW),a
        ret

; r2_death_witch: death handler of the Witch Lord (quest 23): the epilogue
; is shown when the quest ends.
r2_death_witch:
        ld a,1
        ld (r2_witch_dead),a
        ret
r2_witch_dead:  db 0

; r2_play: replaces "call PlayQuest" in the main loop (6D84h): the quest,
; then the two pages of the epilogue if the Witch Lord died in it. The text
; is fetched from ROM in chunks (r2_epilogue).
r2_play:
        ld a,(ZX_QUESTINDEX)
        cp 16
        jr nz,r2_play_quest
        xor a                   ; quest 16: the Death Mist starts its round, and the
        ld (r2_mist_state),a    ; bottom corridor, where it starts, is on the map
        ld hl,ZX_ROOMLAYER+18*26
        ld b,25
r2_play_row:
        set 7,(hl)
        set 6,(hl)
        inc hl
        djnz r2_play_row
r2_play_quest:
        call ZX_PLAYQUEST
        ld a,(r2_witch_dead)
        or a
        ret z
        xor a
        ld (r2_witch_dead),a
        ld hl,r2_epilogue
r2_play_page:
        push hl
        call ZX_CLEARALL
        pop hl
r2_play_chunk:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,d
        or e
        jr z,r2_play_shown
        push hl
        ex de,hl
        call r2_xbox
        call ZX_PRINTSTRING
        pop hl
        jr r2_play_chunk
r2_play_shown:
        push bc
        push hl
        call ZX_BLIT
        call ZX_WAITFIRE
        pop hl
        pop bc
        ld a,c
        or a
        jr z,r2_play_page
        ret

; ---- rules of the expansion quests ------------------------------------------------
; r2_monnum: replaces "ld a,25 / sub b / inc a" in the quest set-up (5C9Ah):
; A = number of the monster record at IX for the object layer. The Death
; Mist (MON_FLAGS bit 7) is not put on the board: it occupies no cell.
r2_monnum:
        bit 7,(ix+6)
        jr nz,r2_monnum_skip
        ld a,32
        sub b
        inc a
        ret
r2_monnum_skip:
        pop af
        jp ZX_SETUP_NEXT

; r2_break: replaces "ld ix,<attack failed text>" in ActionAttack (73D1h).
; In: IX = the monster attacked. A monster with MON_FLAGS bit 6 (the four
; orcs of quest 23) destroys the weapon and the magic blades in use.
r2_break:
        bit 6,(ix+6)
        jr z,r2_break_done
        ld b,0
        ld iy,(ZX_CURHERO)
        ld a,(iy+17)            ; weapon in use
        or a
        jr z,r2_break_blades
        xor (iy+14)             ; out of the weapons owned
        ld (iy+14),a
        ld (iy+17),0
        inc b
r2_break_blades:
        ld a,(iy+18)            ; artifacts in use: Orc's Bane, Spirit Blade
        and 0x18
        jr z,r2_break_any
        xor (iy+13)
        ld (iy+13),a
        res 3,(iy+18)
        res 4,(iy+18)
        inc b
r2_break_any:
        ld a,b
        or a
        jr z,r2_break_done
        ld ix,r2_txt_broke
        call ZX_PRINTSTRING
r2_break_done:
        ld ix,ZX_TXT_FAILED
        ret
r2_txt_broke:
        db 0xFB,5, 0xFF,8,14, 0x48,0x41,0x53,0x5F,0x52,0x4F,0x54,0x4F,0x5F,0x54,0x55,0x5F,0x41,0x52,0x4D,0x41, 0    ; HAS ROTO TU ARMA

; r2_step: replaces "or a / jp nz,RequestRoomRedraw" in FinishStep (855Eh):
; a hero has stepped into another room. In: A = the new room, IY = hero.
; Quest 15: leaving room 1Fh puts the hero on one of four corridor cells
; around it, chosen with a die.
r2_step:
        ld c,a
        ld a,(ZX_QUESTINDEX)
        cp 15
        jr z,r2_step_15
        ld a,c
        or a
        ret z                   ; room 0: the base game goes on (teleport of quest 9)
r2_step_redraw:
        pop hl
        jp ZX_REDRAWROOM
r2_step_15:
        ld a,(iy+HERO_ROOM)
        cp 0x1F
        jr nz,r2_step_redraw
        call ZX_RANDOM6
        ld a,c
        add a,a
        add a,a
        add a,c                 ; 5 bytes per entry
        ld e,a
        ld d,0
        ld hl,r2_teleports
        add hl,de
        ld a,(hl)
        ld (iy+HERO_ROOM),a
        inc hl
        ld c,(hl)
        ld (iy+1),c
        inc hl
        ld b,(hl)
        ld (iy+2),b
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call ZX_MAPCELLAT
        pop de
        inc h
        inc h
        ld (iy+4),l
        ld (iy+5),h
        ld (ZX_LASTDOOR),de
        jr r2_step_redraw
r2_teleports:                   ; room, x, y, wall-layer cell kept as the last door
        db 0x07, 9, 9
        dw 0x64F4
        db 0x07, 9, 9
        dw 0x64F4
        db 0x08, 13, 6
        dw 0x64C3
        db 0x0D, 12, 12
        dw 0x652A
        db 0x0D, 12, 12
        dw 0x652A
        db 0x09, 16, 9
        dw 0x64FA

; r2_rock: replaces "ld a,(QuestIndex)" in the falling rock of
; HandleTrapEvent (A188h). In the expansion quests the rock lands on the
; cell east of the hero who set it off; a hero standing there is hit.
r2_rock:
        ld a,(ZX_QUESTINDEX)
        cp BASE_QUESTS
        ret c
        pop hl
        ld iy,(ZX_CURHERO)
        ld e,(iy+1)
        inc e
        ld d,(iy+2)
        call ZX_MAPCELLOFF
        ld de,ZX_OBJECTS
        add hl,de
        push hl
        ld d,(iy+2)
        ld e,(iy+1)
        inc e
        ld a,(ZX_HEROINDEX)
        ld (ZX_TARGETHERO),a
        call ZX_PROBECELL
        pop hl
        cp 1
        jp z,ZX_ROCKONHERO
        ld (hl),0x31
        ret

; r2_keylabel: replaces "ld ix,<ORO MAGNUS>" in the hero sheet (95D5h): in
; quest 17 the same flag of the hero means a key of Agrain.
r2_keylabel:
        ld ix,ZX_TXT_MAGNUS
        ld a,(ZX_QUESTINDEX)
        cp 17
        ret nz
        ld ix,r2_txt_key
        ret
r2_txt_key:
        db 0xFB,6, 0xFF,20,18, 0x4C,0x4C,0x41,0x56,0x45,0x5F,0x41,0x47,0x52,0x41,0x49,0x4E, 0xFA    ; LLAVE AGRAIN

; r2_mist_turn: replaces "bit 0,(iy+MON_FLAGS) / ret z" at the start of
; MonsterTakeTurn (9D73h). IY = monster record. The Death Mist of quest 16
; (MON_FLAGS bit 7) walks six cells of its round per turn of Morcar; every
; step reveals what it sees and is shown on the map; a hero on its cell
; loses a body point.
r2_mist_turn:
        bit 0,(iy+6)
        ret nz                  ; an ordinary monster
        pop hl                  ; no turn for the others
        bit 7,(iy+6)
        ret z
        ld a,(ZX_QUESTINDEX)
        cp 16
        ret nz
        ld b,6
r2_mist_step:
        push bc
        ld a,(r2_mist_state)    ; three bytes per leg: field of the record, step, last value
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,r2_mist_legs
        add hl,de
        ld e,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        push iy
        pop hl
        add hl,de               ; x or y of the record
        ld a,(hl)
        add a,c
        ld (hl),a
        cp b
        jr nz,r2_mist_show
        ld a,(r2_mist_state)    ; end of the leg
        inc a
        cp 6
        jr c,r2_mist_next
        xor a
r2_mist_next:
        ld (r2_mist_state),a
r2_mist_show:
        push iy
        call ZX_REVEAL
        ld ix,ZX_TXT_MORCAR
        call ZX_PRINTSTRING
        call ZX_DRAWMAP
        pop iy
        push iy
        call r2_mist_contact
        call ZX_COLOURMAP
        ld b,30
        call ZX_WAITFRAMES
        pop iy
        pop bc
        djnz r2_mist_step
        ret
r2_mist_legs:                   ; west along row 18, north, east to column 15, back, south, east to column 24
        db 1,-1,0, 2,-1,0, 1,1,15, 1,-1,0, 2,1,18, 1,1,24
r2_mist_state:  db 0

; r2_mist_contact: a hero on the cell of the mist (IY) loses a body point,
; or dies with his last one; only the first hero found. Then the map is
; presented.
r2_mist_contact:
        xor a
r2_mc_hero:
        push af
        call ZX_GETHERO
        ld a,(ix+0)
        or a
        jr z,r2_mc_next
        ld a,(ix+1)
        cp (iy+1)
        jr nz,r2_mc_next
        ld a,(ix+2)
        cp (iy+2)
        jr nz,r2_mc_next
        ld a,(ix+HERO_BODY)
        cp 2
        jr c,r2_mc_dies
        dec a
        ld (ix+HERO_BODY),a
        pop af
        ld ix,r2_txt_mist
        call ZX_PRINTBLIT
        ld b,100
        jp ZX_WAITFRAMES
r2_mc_next:
        pop af
        inc a
        cp 4
        jr nz,r2_mc_hero
        jp ZX_BLIT
r2_mc_dies:
        pop af
        ld (ZX_TARGETID),a
        call ZX_KILLHERO
        call ZX_CLEARBITMAP
        jp ZX_COLOURMAP
r2_txt_mist:
        db 0xFB,3, 0xFF,2,20, 0x4C,0x41,0x5F,0x4E,0x49,0x45,0x42,0x4C,0x41,0x5F,0x44,0x45,0x5F,0x4C,0x41,0x5F,0x4D,0x55,0x45,0x52,0x54,0x45,0x5F,0x41,0x54,0x41,0x43,0x41    ; LA NIEBLA DE LA MUERTE ATACA
        db 0xFF,3,21, 0x41,0x4C,0x5F,0x4A,0x55,0x47,0x41,0x44,0x4F,0x52,0x3A,0x5F,0x50,0x49,0x45,0x52,0x44,0x45,0x5F,0x31,0x5F,0x50,0x55,0x4E,0x54,0x4F, 0xFA    ; AL JUGADOR. PIERDE 1 PUNTO

; r2_map_mist: replaces the end of DrawBoardMap (931Ah, "pop ix / ret"): in
; quest 16 the Death Mist (monster record 1) is marked on the map, with a
; dot in the plan of the line-of-sight test.
r2_map_mist:
        ld a,(ZX_QUESTINDEX)
        cp 16
        jr nz,r2_map_mist_done
        ld ix,XMONSTERS+10
        ld h,(ix+2)
        inc h
        ld l,0                  ; buffer row y + 1
        ld a,(ix+1)
        add a,3                 ; column x + 3
        ld e,a
        ld d,0
        add hl,de
        ld de,0xE700
        add hl,de
        push hl
        exx
        ld hl,ZX_MISTGLYPH
        ld a,(ZX_MAPPLAIN)
        or a
        jr z,r2_map_mist_glyph
        ld hl,ZX_MAPDOT
r2_map_mist_glyph:
        pop de
        call ZX_ORMAPGLYPH
r2_map_mist_done:
        pop ix
        ret

; r2_code_save, r2_code_load: replace the tape save and load of a hero
; (5F02h, 5F61h): the hero code program (src/savecode.asm) is copied from
; ROM to the work area of the quest loader and entered.
r2_code_load:
        ld a,3
        jr r2_code
r2_code_save:
        xor a
r2_code:
        ld hl,CODE_ROM
        ld bc,CODE_SIZE
        jr r2_module
; r2_ctrl: replaces the controls menu (5D3Fh) by the options menu of
; src/ctrlmenu.asm, loaded the same way.
r2_ctrl:
        xor a
        ld hl,CTRL_ROM
        ld bc,CTRL_SIZE
; r2_module: copy BC bytes of a menu program from HL (second expansion bank
; image) to CODE_BASE and enter it at offset A.
r2_module:
        push af
        di
        ld a,5
        ld (rt_bank),a
        ld de,CODE_BASE
        rst 0x08
        ld a,0x10
        ld (rt_bank),a
        ei
        pop af
        ld l,a
        ld h,CODE_BASE/256
        jp (hl)

; The hero lists of the character menu and of the shop only stepped down.
; r2_dir (5E3Ah) and r2_dirwait (62F6h) keep the direction pressed (input
; bits 2 down, 3 up); r2_step5 moves a cursor of five lines that way.
r2_dirwait:
        ld (r2_dir_bits),a
        jp r2_quick
; TEMPORARY: in the shop lists the wait for the key to be released before
; moving is replaced by one frame, so that a held key repeats and a tap does
; not wait. Undo: restore backups or remove the patches marked TEMPORARY.
r2_quick:
        ret                     ; the step is made at once; the release is waited for afterwards
; r2_jump: the pointer is over letter B of the alphabet line (name editor or
; hero code): the highlight goes there at once, and the name editor shows the
; letter in the field as its own loop does after a step. Keeps IX, BC.
r2_jump:
        push ix
        push bc
        call ZX_LETTERCUR
        pop bc
        ld a,b
        ld (GAME_MENUCURSOR),a
        push bc
        call ZX_LETTERCUR
        ld a,(rt_incode)
        or a
        jr nz,r2_jump_blit
        ld a,(ZX_NAMELEN)
        ld e,a
        ld d,0
        ld hl,ZX_NAMEFIELD+5
        add hl,de
        ld a,(GAME_MENUCURSOR)
        add a,0x41
        ld (hl),a
        ld ix,ZX_NAMEFIELD
        call ZX_PRINTSTRING
r2_jump_blit:
        call ZX_BLIT
        pop bc
        pop ix
        ret
; r2_afteritem / r2_afterhero: the end of a step in the two lists of the shop:
; a key held down does not go on to the next line, it has to be pressed again.
r2_afteritem:
        call ZX_WAITRELEASE
        jp 0x6339               ; the item input loop
r2_afterhero:
        call 0x643E             ; ToggleShopHeroBar: the bar on its new line
        call ZX_WAITRELEASE
        jp 0x62EB               ; the hero input loop (HeroInput)
r2_dir:                         ; Out: NZ if up or down is pressed; A kept
        ld c,a
        and 0x0C
        ld (r2_dir_bits),a
        ld a,c
        ret
r2_step5:                       ; A = cursor 0-4 -> the next or the previous one
        ld c,a
        ld a,(r2_dir_bits)
        and 8
        ld a,c
        jr nz,r2_step5_up
        inc a
        cp 5
        ret c
        xor a
        ret
r2_step5_up:
        or a
        jr nz,r2_step5_dec
        ld a,5
r2_step5_dec:
        dec a
        ret
r2_dir_bits:    db 0

; r2_qmenu: replaces "ld hl,TxtQuestMenu / call DrawMenuPage" (6166h). The
; quest menu has two pages: the 14 quests of the base game and a line MAS,
; and the ten of the expansion and a line VOLVER. The menu loop of the
; original is used for both: its line count is set here, in its code and in
; the table of the pointer.
r2_qmenu:
        ld a,(r2_qpage)
        or a
        jr nz,r2_qmenu_2
        ld a,BASE_QUESTS+1
        call r2_qmenu_lines
        ld hl,ZX_TXTQUESTMENU
        call ZX_DRAWMENUPAGE
        ld ix,r2_txt_more
        jr r2_qmenu_print
r2_qmenu_2:
        ld a,11
        call r2_qmenu_lines
        ld hl,r2_txt_page2
        call ZX_DRAWMENUPAGE
        ld ix,r2_txt_pack
r2_qmenu_print:
        call ZX_PRINTSTRING
        jp ZX_BLIT
r2_qmenu_lines:
        ld (ZX_QMENU_COUNT),a
        ld (rt_menu_quest_rows),a
        dec a
        ld (ZX_QMENU_LAST),a
        ret

; r2_qfire: replaces the end of the quest menu (617Bh): fire on a line.
; MAS and VOLVER change the page; a quest line sets QuestIndex and returns
; to the caller of the menu, as the original does.
r2_qfire:
        call ZX_WAITRELEASE
        ld a,(GAME_MENUCURSOR)
        ld b,a
        ld a,(r2_qpage)
        or a
        ld a,b
        jr nz,r2_qfire_2
        cp BASE_QUESTS
        jr z,r2_qfire_page
        ld (ZX_QUESTINDEX),a
        ret
r2_qfire_2:
        cp 10
        jr z,r2_qfire_page
        add a,BASE_QUESTS
        ld (ZX_QUESTINDEX),a
        xor a
        ld (r2_qpage),a
        ret
r2_qfire_page:
        ld a,(r2_qpage)
        xor 1
        ld (r2_qpage),a
        jp ZX_QMENU_REDRAW
r2_qpage:       db 0
r2_txt_more:                    ; line 15 of the first page
        db 0xFB,0x42, 0xFF,14,18, 0x4D,0x41,0x53,0x5F, 0xFA    ; MAS (space for NEXT in English)
r2_txt_pack:                    ; name of the expansion over the second page
        db 0xFB,0x46, 0xFF,3,2, 0x45,0x4C,0x5F,0x52,0x45,0x54,0x4F,0x52,0x4E,0x4F,0x5F,0x44,0x45,0x4C,0x5F,0x53,0x45,0x4E,0x4F,0x52,0x5F,0x42,0x52,0x55,0x4A,0x4F, 0xFA    ; EL RETORNO DEL SENOR BRUJO
r2_txt_page2:
        db 0xFB,0x42
        db 0xFF,3,4, 0x4C,0x41,0x5F,0x50,0x55,0x45,0x52,0x54,0x41,0x5F,0x44,0x45,0x5F,0x4C,0x41,0x5F,0x50,0x45,0x52,0x44,0x49,0x43,0x49,0x4F,0x4E    ; LA PUERTA DE LA PERDICION
        db 0xFF,8,5, 0x4C,0x41,0x53,0x5F,0x53,0x41,0x4C,0x41,0x53,0x5F,0x46,0x52,0x49,0x41,0x53    ; LAS SALAS FRIAS
        db 0xFF,3,6, 0x4C,0x4F,0x53,0x5F,0x50,0x41,0x53,0x41,0x44,0x49,0x5A,0x4F,0x53,0x5F,0x53,0x49,0x4C,0x45,0x4E,0x43,0x49,0x4F,0x53,0x4F,0x53    ; LOS PASADIZOS SILENCIOSOS
        db 0xFF,5,7, 0x4C,0x41,0x53,0x5F,0x53,0x41,0x4C,0x41,0x53,0x5F,0x44,0x45,0x5F,0x4C,0x41,0x5F,0x56,0x49,0x53,0x49,0x4F,0x4E    ; LAS SALAS DE LA VISION
        db 0xFF,5,8, 0x4C,0x41,0x5F,0x50,0x55,0x45,0x52,0x54,0x41,0x5F,0x44,0x45,0x5F,0x42,0x45,0x4C,0x4C,0x54,0x48,0x4F,0x52    ; LA PUERTA DE BELLTHOR
        db 0xFF,4,9, 0x4C,0x41,0x53,0x5F,0x53,0x41,0x4C,0x41,0x53,0x5F,0x44,0x45,0x5F,0x4C,0x4F,0x53,0x5F,0x4D,0x55,0x45,0x52,0x54,0x4F,0x53    ; LAS SALAS DE LOS MUERTOS
        db 0xFF,7,10, 0x4C,0x41,0x5F,0x4C,0x45,0x47,0x49,0x4F,0x4E,0x5F,0x4F,0x4C,0x56,0x49,0x44,0x41,0x44,0x41    ; LA LEGION OLVIDADA
        db 0xFF,6,11, 0x4C,0x41,0x5F,0x43,0x49,0x55,0x44,0x41,0x44,0x5F,0x50,0x52,0x4F,0x48,0x49,0x42,0x49,0x44,0x41    ; LA CIUDAD PROHIBIDA
        db 0xFF,8,12, 0x4C,0x41,0x5F,0x55,0x4C,0x54,0x49,0x4D,0x41,0x5F,0x50,0x55,0x45,0x52,0x54,0x41    ; LA ULTIMA PUERTA
        db 0xFF,4,13, 0x4C,0x41,0x5F,0x43,0x4F,0x52,0x54,0x45,0x5F,0x44,0x45,0x4C,0x5F,0x53,0x45,0x4E,0x4F,0x52,0x5F,0x42,0x52,0x55,0x4A,0x4F    ; LA CORTE DEL SENOR BRUJO
        db 0xFF,13,14, 0x56,0x4F,0x4C,0x56,0x45,0x52    ; VOLVER
        db 0xFA

; r2_detect: looks for an OPL4 (MoonSound): something answers at the FM
; status port and the wave part gives the device number 1 of the YMF278.
; Sets rt_opl. Called once at boot with interrupts disabled.
r2_detect:
        xor a
        ld (rt_opl),a
        ld (rt_opl_play),a
        dec a
        ld (rt_opl_tune),a
        in a,(OPL4_FM)
        inc a
        ret z                   ; FFh: no chip
        ld de,0x0305            ; FM bank 1, register 5 = 3: OPL4 mode, wave part on
        ld c,OPL4_FM2
        call rt_opl_write
        ld a,2
        out (OPL4_WAVE),a
        in a,(OPL4_WAVE+1)      ; wave register 2: device number in bits 7-5
        and 0xE0
        cp 0x20
        ret nz
        ld a,1
        ld (rt_opl),a
        ret

; r2_snd_cmd: replaces the call to the sound driver in SoundCommand (7BD3h).
; In: A = function (2 start tune D, 3 fade out, 4 start effect E, 5 stop),
; interrupts disabled. Without an OPL4 everything goes to the PSG driver in
; page 0. With one, the tunes are played by the OPL4 (D = 1 the game tune,
; 2 the menu and intro tune, 3 the logo fanfare, anything else silence) and the driver only gets
; the effects.
r2_snd_cmd:
        ld b,a
        ld a,(rt_opl)
        or a
        ld a,b
        jp z,SOUND_ENTRY
        cp 2
        jr z,r2_start
        cp 4
        jp z,SOUND_ENTRY
        push af
        call r2_stop
        pop af
        cp 5
        ret nz
        jp SOUND_ENTRY          ; stop: the effects too

; r2_stop: stop the OPL4 tune: key off on the 24 wave voices.
; Clobbers AF, BC, DE.
r2_stop:
        xor a
        ld (rt_opl_play),a
        ld de,0x0068            ; registers 68h-7Fh = 0
        ld b,24
r2_stop_voice:
        ld c,OPL4_WAVE
        call rt_opl_write
        inc e
        djnz r2_stop_voice
        ret

; r2_start: start tune D on the OPL4. If its samples are not the ones in the
; wave RAM they are sent first (about a second, in silence). Runs on the
; small music stack: the game's stack may be in page 1, which rt_copy
; replaces with the cartridge.
r2_start:
        ld (rt_msp),sp
        ld sp,RT_MSTACK
        push de
        call r2_stop
        pop de
        ld a,d
        dec a
        cp MUSIC_TUNES
        jp nc,r2_start_done     ; no such tune: silence
        ld l,a
        add a,a
        add a,a
        add a,l
        add a,a                 ; 10 bytes per tune
        ld l,a
        ld h,0
        ld bc,r2_tunes
        add hl,bc
        push hl
        pop ix
        ld a,(rt_opl_tune)
        cp d
        jp z,r2_start_stream
        ld a,d
        ld (rt_opl_tune),a
        ld de,0x0305            ; OPL4 mode, wave part on
        ld c,OPL4_FM2
        call rt_opl_write
        ld de,0x1102            ; wave register 2 = 11h: headers at 200000h, memory access
        call r2_wave
        ld de,0x2003            ; memory address 200000h
        call r2_wave
        ld de,0x0004
        call r2_wave
        ld de,0x0005
        call r2_wave
        ld a,6                  ; register 6: memory data
        out (OPL4_WAVE),a
        ld a,(ix+0)
        ld (rt_seg),a
        ld hl,0x4000
        ld c,(ix+1)             ; 256-byte pieces: sent as two of 128 bytes
        ld b,(ix+2)
        sla c
        rl b
r2_upload:
        push bc
        ld de,RT2_BUF
        ld bc,128
        call rt_copy            ; HL moves on
        bit 7,h
        jr z,r2_upload_send
        ld hl,rt_seg            ; next segment of the samples
        inc (hl)
        ld hl,0x4000
r2_upload_send:
        push hl
        ld hl,RT2_BUF
        ld b,128
r2_upload_byte:
        in a,(OPL4_FM)
        rrca
        jr c,r2_upload_byte
        ld a,(hl)
        out (OPL4_WAVE+1),a
        inc hl
        djnz r2_upload_byte
        pop hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,r2_upload
        ld de,0x1002            ; back to sound generation
        call r2_wave
r2_start_stream:
        ld a,(ix+3)
        ld (rt_opl_seg),a
        ld l,(ix+4)
        ld h,(ix+5)
        ld (rt_opl_ptr),hl
        ld a,(ix+6)
        ld (rt_opl_lseg),a
        ld l,(ix+7)
        ld h,(ix+8)
        ld (rt_opl_lptr),hl
        xor a
        ld (rt_opl_wait),a
        inc a
        ld (rt_opl_play),a
r2_start_done:
        ld sp,(rt_msp)
        ret

; r2_wave: wave register E = D.
r2_wave:
        ld c,OPL4_WAVE
        jp rt_opl_write

        include "../build/music.inc"

; ---- tables at fixed addresses (the game code is patched to use them) ---------------
        assert $ <= RT2_MNAMES
        ds RT2_MNAMES-$,0
        dw 0xB54B,0xB555,0xB55F,0xB569,0xB573,0xB57D,0xB587,0xB591      ; kinds 0-7: DUENDE ... HECHICERO
        dw 0xB59B,0xB5A5,0xB5AF,0xB5B9,0xB5B9,0xB5B9,0xB5B9,0xB5B9      ; kinds 8-15: set by r2_monsters
        assert $ == RT2_MPICS
        db 0x80,0xE8,0x14, 0x80,0xE8,0x14, 0x02,0xF8,0x13, 0xC0,0xC8,0x17
        db 0x82,0xF3,0x13, 0x00,0xE4,0x14, 0x00,0xE4,0x14, 0x80,0xE8,0x14
        ds 24,0
        assert $ == RT2_MGLYPHS
        dw 0xB268,0xB270,0xB278,0xB280,0xB288,0xB290,0xB298,0xB2A0
        ds 16,0
        assert $ <= RT2_ROOMS
        ds RT2_ROOMS-$,0
        ds 86,0                 ; the tables of search events of the quest

        assert $ <= 0x56E8
        ds 0x56E8-$,0

; ---- VOLVER instead of FINAL ------------------------------------------------------------
; The three menu lines FINAL cannot grow in the overlay (six letters in
; five bytes): their text is printed from here.
; r2_shopscr: replaces "ld ix,TxtShopScreen / call PrintString" (62D7h). The
; string of the shop screen is cut where its line FINAL was (that part is now
; one FAh); VOLVER is printed, then the rest of the string.
r2_shopscr:
        ld ix,0x69E2
        call ZX_PRINTSTRING
        ld ix,r2_v_hero
        call ZX_PRINTSTRING
        ld ix,0x6A18
        call ZX_PRINTSTRING     ; the rest, up to where the item-list FINAL was
        ld ix,r2_v_exit
        jp ZX_PRINTSTRING
; r2_shopexit: the line of the item list: the original is replaced.
r2_shopexit:
        ld ix,r2_v_exit
        jp ZX_PRINTNORMAL
; r2_classprint: replaces "call PrintThenNormal" of DrawHeroClassList (612Ch)
; of the character menu; B = line. The fifth one (FINAL) prints VOLVER and
; leaves IX at the end of the string it replaces.
r2_classprint:
        ld a,b
        cp 4
        jp nz,ZX_PRINTNORMAL
        push ix
        ld ix,r2_v_class
        call ZX_PRINTNORMAL
        pop ix
        ld de,10
        add ix,de
        ret
r2_v_hero:      db 0xFB,0x42, 0xFF,0,6, 0x56,0x4F,0x4C,0x56,0x45,0x52, 0xFA
r2_v_exit:      db 0xFB,5, 0xFF,17,19, 0x56,0x4F,0x4C,0x56,0x45,0x52, 0xFA
r2_v_class:     db 0xFB,7, 0xFF,4,16, 0x56,0x4F,0x4C,0x56,0x45,0x52, 0xFA

        assert $ <= RT2_BUF
        ds RT2_BASE+RT2_SIZE-$,0
