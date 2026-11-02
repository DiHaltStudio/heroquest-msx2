; HeroQuest MSX2 - hero codes
; DiHalt Studio
;
; The original saved a hero to tape (name and record) from the hero submenu
; of the character menu. The cartridge has no storage: GUARDAR shows a code
; of 16 letters instead and CARGAR asks for it. The code holds what a hero
; keeps from one quest to the next: the six letters of the name, the gold
; (in steps of 5 coins, as every amount of the game), the body points, the
; weapons, the armour and tool kit, and the quest treasures.
;
; The fields are the digits of one number in a mixed radix (27 six times,
; 2000, 8, 128, 32, 32); that number times 79 plus a value that depends on
; the hero class is written in base 26 with 14 digits, and each digit is
; shifted by the previous letter. A code typed wrong, or the code of another
; class, leaves another remainder modulo 79 almost always (78 of 79 times)
; and is refused. Two additional check letters cover the payload and class,
; detecting all single-letter substitutions. The 14-letter secret remains separate.
;
; This program is assembled at 4000h (the work area of the quest loader,
; free while the menus run). It is stored in ROM after the expansion texts
; and copied here by r2_code each time one of the two options is chosen.

        include "../build/rt_all.inc"

SC_SLOT         equ 0x65F0      ; HeroSlotCursor
SC_BANNERS      equ 0xA476      ; HeroBannerPtrs: name strings, the six letters at +3
SC_ALIVE        equ 0x8FE4      ; HeroAliveFlags
SC_INITHERO     equ 0x60E6      ; InitHeroRecord (slot HeroSlotCursor)
SC_MENU         equ 0x5DEC      ; CharacterMenuRedraw
SC_ALPHABET     equ 0x6B9B      ; TxtAlphabet: "A-Z FIN" on text row 21
SC_LETTERCUR    equ 0x60C4      ; ToggleLetterCursor (MenuCursor 0-26)
SC_MAXBODY      equ 0x7E4E      ; HeroMaxBody: body points of each class
SC_FIELDS       equ 11          ; fields of the code, then the check
SC_DATA_LETTERS equ 14
SC_LETTERS      equ 16

        org 0x4000
        jp sc_save
        jp sc_load

; sc_div5: HL / 5 -> DE (0-1999).
sc_div5:
        ld de,0
        ld bc,5
sc_div5_loop:
        or a
        sbc hl,bc
        ret c
        inc de
        jr sc_div5_loop

        ds 0x4015-$,0
; The pointer works in the letter line through rt_menu_input, which knows
; the menus by the low byte of the return address: 18h is the name editor.
sc_input:
        call rt_menu_input
        ret

; ---- arithmetic on sc_num, 9 bytes, low byte first ----------------------------------
; sc_muladd: sc_num = sc_num * DE + HL. Clobbers AF, BC, DE, HL.
sc_muladd:
        push hl
        push de
        ld hl,sc_num
        ld de,sc_tmp
        ld bc,9
        ldir
        ld hl,sc_num
        ld b,9
sc_ma_zero:
        ld (hl),0
        inc hl
        djnz sc_ma_zero
        pop de
        ld b,16
sc_ma_bit:
        push bc
        ld hl,sc_num            ; sc_num * 2
        ld b,9
        or a
sc_ma_shift:
        rl (hl)
        inc hl
        djnz sc_ma_shift
        sla e
        rl d
        jr nc,sc_ma_next
        push de
        ld hl,sc_num            ; + the old value
        ld de,sc_tmp
        ld b,9
        or a
sc_ma_add:
        ld a,(de)
        adc a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz sc_ma_add
        pop de
sc_ma_next:
        pop bc
        djnz sc_ma_bit
        pop de
        ld hl,sc_num
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ld b,7
sc_ma_carry:
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        djnz sc_ma_carry
        ret

; sc_divmod: sc_num = sc_num / DE, HL = remainder. Clobbers AF, BC.
sc_divmod:
        ld hl,0
        ld b,72
sc_dm_bit:
        push bc
        push hl
        ld hl,sc_num
        ld b,9
        or a
sc_dm_shift:
        rl (hl)
        inc hl
        djnz sc_dm_shift
        pop hl
        adc hl,hl
        or a
        sbc hl,de
        jr nc,sc_dm_one
        add hl,de
        jr sc_dm_next
sc_dm_one:
        ld a,(sc_num)
        or 1
        ld (sc_num),a
sc_dm_next:
        pop bc
        djnz sc_dm_bit
        ret

; sc_hero: IX = record of the hero of the slot, HL = its six name letters.
sc_hero:
        ld a,(SC_SLOT)
        call ZX_GETHERO
        ld a,(SC_SLOT)
        ld hl,SC_BANNERS
        call ZX_GETTABLEWORD
        ex de,hl
        inc hl
        inc hl
        inc hl
        ret

; sc_check: A = remainder a valid code of this hero class has modulo 79.
sc_check:
        ld a,(SC_SLOT)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,a
        add a,b                 ; 19 * slot
        add a,3
        ret

; ---- GUARDAR: show the code ------------------------------------------------------------
sc_save:
        call ZX_WAITRELEASE
        call sc_hero
        ld de,sc_val
        ld b,6
sc_sv_name:                     ; letters: 0 blank, 1-26 A-Z
        ld a,(hl)
        inc hl
        sub 0x40
        jr c,sc_sv_blank
        cp 27
        jr c,sc_sv_letter
sc_sv_blank:
        xor a
sc_sv_letter:
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        djnz sc_sv_name
        ld l,(ix+9)             ; gold / 5
        ld h,(ix+10)
        push de
        call sc_div5
        ld hl,1999
        or a
        sbc hl,de
        jr nc,sc_sv_gold
        ld de,1999
sc_sv_gold:
        ex de,hl
        pop de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,(ix+HERO_BODY)     ; body 1-8
        or a
        jr nz,sc_sv_body
        inc a
sc_sv_body:
        cp 9
        jr c,sc_sv_body2
        ld a,8
sc_sv_body2:
        dec a
        call sc_sv_put
        ld a,(ix+14)            ; weapons
        and 0x7F
        call sc_sv_put
        ld a,(ix+HERO_QFLAGS)   ; armour in bits 0-3, tool kit in bit 7
        ld b,a
        and 0x0F
        bit 7,b
        jr z,sc_sv_flags
        or 0x10
sc_sv_flags:
        call sc_sv_put
        ld a,(ix+13)            ; quest treasures
        and 0x1F
        call sc_sv_put
        call sc_check
        call sc_sv_put
        call sc_zero            ; the number: every field in turn
        ld ix,sc_val
        ld iy,sc_radix
        ld b,SC_FIELDS+1
sc_sv_field:
        push bc
        ld e,(iy+0)
        ld d,(iy+1)
        ld l,(ix+0)
        ld h,(ix+1)
        call sc_muladd
        ld bc,2
        add ix,bc
        add iy,bc
        pop bc
        djnz sc_sv_field
        ld hl,sc_code           ; 14 digits in base 26, the lowest first, each
        ld b,SC_DATA_LETTERS    ; one shifted by the letter before it
        ld c,7
sc_sv_digit:
        push bc
        push hl
        ld de,26
        call sc_divmod
        ld a,l
        pop hl
        pop bc
        add a,c
sc_sv_mod:
        sub 26
        jr nc,sc_sv_mod
        add a,26
        ld (hl),a
        inc hl
        add a,3
        ld c,a
        ld a,SC_DATA_LETTERS
        sub b
        add a,c
        ld c,a                  ; next shift: letter + position + 3
        djnz sc_sv_digit
        call sc_checksum
        ld a,c
        ld (sc_code+14),a
        ld a,l
        ld (sc_code+15),a
        call ZX_CLEARALL
        ld ix,sc_txt_save
        call ZX_PRINTSTRING
        ld a,SC_LETTERS
        call sc_show
        call ZX_WAITFIRE
sc_exit:
        xor a
        ld (rt_incode),a
        call ZX_CLEARALL
        jp SC_MENU
sc_sv_put:                      ; value A as the next field
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ret

sc_zero:
        ld hl,sc_num
        ld b,9
sc_zero_loop:
        ld (hl),0
        inc hl
        djnz sc_zero_loop
        ret

; sc_show: print the first A letters of sc_code in three groups (5, 5, 6)
; and present the screen. Clobbers everything.
sc_show:
        ld c,a
        ld hl,sc_code
        ld de,sc_line_letters
        ld b,0
sc_show_letter:
        ld a,b
        cp 5
        jr z,sc_show_gap
        cp 10
        jr nz,sc_show_put
sc_show_gap:
        inc de                  ; the space between two groups
sc_show_put:
        ld a,b
        cp c
        ld a,0x5F               ; not typed yet
        jr nc,sc_show_store
        ld a,(hl)
        add a,0x41
sc_show_store:
        ld (de),a
        inc hl
        inc de
        inc b
        ld a,b
        cp SC_LETTERS
        jr nz,sc_show_letter
        ld ix,sc_line
        call ZX_PRINTSTRING
        jp ZX_BLIT

; ---- CARGAR: ask for the code ---------------------------------------------------------
sc_load:
        ld a,1
        ld (rt_incode),a
        call ZX_WAITRELEASE
        call ZX_CLEARALL
        ld ix,sc_txt_load
        call ZX_PRINTSTRING
        ld ix,SC_ALPHABET
        call ZX_PRINTSTRING
        xor a
        ld (GAME_MENUCURSOR),a
        ld (sc_count),a
        call SC_LETTERCUR
sc_ld_show:
        ld a,(sc_count)
        call sc_show
sc_ld_input:
        call sc_key             ; a letter key of the keyboard
        cp 26
        jr c,sc_ld_typed
        call sc_input
        bit 1,a
        jr nz,sc_ld_left
        bit 0,a
        jr nz,sc_ld_right
        bit 4,a
        jr z,sc_ld_input
        call ZX_WAITRELEASE
        ld a,(GAME_MENUCURSOR)
        cp 26
        jr c,sc_ld_letter
        ld hl,sc_count          ; FIN: take the last letter back, or leave
        ld a,(hl)
        or a
        jp z,sc_exit
        dec (hl)
        jp sc_ld_show
sc_ld_typed:
        push af
sc_ld_keyup:
        halt
        call sc_key
        cp 26
        jr c,sc_ld_keyup
        pop af
sc_ld_letter:
        ld c,a
        ld hl,sc_count
        ld e,(hl)
        inc (hl)
        ld d,0
        ld hl,sc_code
        add hl,de
        ld (hl),c
        ld a,(sc_count)
        cp SC_DATA_LETTERS
        call z,sc_try_secret
        ld a,(sc_count)
        cp SC_LETTERS
        jr nz,sc_ld_show
        call sc_show
        jr sc_decode
sc_ld_left:
        call SC_LETTERCUR
        ld a,(GAME_MENUCURSOR)
        or a
        jr nz,sc_ld_dec
        ld a,27
sc_ld_dec:
        dec a
        jr sc_ld_move
sc_ld_right:
        call SC_LETTERCUR
        ld a,(GAME_MENUCURSOR)
        inc a
        cp 27
        jr c,sc_ld_move
        xor a
sc_ld_move:
        ld (GAME_MENUCURSOR),a
        call SC_LETTERCUR
        call ZX_BLIT
        ld b,8
        call ZX_WAITFRAMES
        jp sc_ld_input

sc_try_secret:
        ld hl,sc_code           ; the secret word: the hero of the slot, whatever
        ld de,sc_secret         ; his name, gets everything
        ld b,SC_DATA_LETTERS
sc_dc_secret:
        ld a,(de)
        sub 0x41
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz sc_dc_secret
        pop af                  ; discard sc_try_secret return address
        call sc_hero
        ld (ix+9),0x0B          ; 9995 coins
        ld (ix+10),0x27
        ld (ix+14),0x7F         ; the seven weapons
        ld (ix+HERO_QFLAGS),0x8F ; the four pieces of armour and the tool kit
        ld (ix+13),0x1F         ; the five quest treasures
        ld de,(SC_SLOT)
        ld d,0
        ld hl,SC_MAXBODY
        add hl,de
        ld a,(hl)
        ld (ix+HERO_BODY),a
        ld hl,SC_ALIVE
        add hl,de
        ld (hl),0xFF
        jp sc_exit
sc_secret:      db "MENTORLORETOME"

; the 14 letters are in sc_code: back to digits, to the number, to the fields
sc_decode:
        call sc_checksum        ; validate before changing input or any hero data
        ld a,(sc_code+14)
        cp c
        jp nz,sc_bad
        ld a,(sc_code+15)
        cp l
        jp nz,sc_bad
sc_dc_code:
        call sc_zero
        ld hl,sc_code           ; undo the shifts (the first letter first)
        ld b,SC_DATA_LETTERS
        ld c,7
sc_dc_unshift:
        ld a,(hl)
        ld e,a                  ; the letter
        add a,52                ; the shift is 41 at most
        sub c
sc_dc_mod:
        sub 26
        jr nc,sc_dc_mod
        add a,26
        ld (hl),a
        inc hl
        ld a,e
        add a,3
        ld c,a
        ld a,SC_DATA_LETTERS
        sub b
        add a,c
        ld c,a
        djnz sc_dc_unshift
        ld b,SC_DATA_LETTERS    ; the number, from the highest digit down
sc_dc_digit:
        push bc
        dec hl
        push hl
        ld l,(hl)
        ld h,0
        ld de,26
        call sc_muladd
        pop hl
        pop bc
        djnz sc_dc_digit
        ld ix,sc_val+2*SC_FIELDS
        ld iy,sc_radix+2*SC_FIELDS
        ld b,SC_FIELDS+1
sc_dc_field:
        push bc
        ld e,(iy+0)
        ld d,(iy+1)
        call sc_divmod
        ld (ix+0),l
        ld (ix+1),h
        dec ix
        dec ix
        dec iy
        dec iy
        pop bc
        djnz sc_dc_field
        ld hl,sc_num            ; nothing may be left
        ld b,9
        xor a
sc_dc_rest:
        or (hl)
        inc hl
        djnz sc_dc_rest
        jr nz,sc_bad
        call sc_check
        ld hl,sc_val+2*SC_FIELDS
        cp (hl)
        jr nz,sc_bad
        call SC_INITHERO        ; a new record, then what the code says
        call sc_hero
        ld de,sc_val
        ld b,6
sc_dc_name:
        ld a,(de)
        inc de
        inc de
        or a
        jr z,sc_dc_blank
        add a,0x40
        jr sc_dc_char
sc_dc_blank:
        ld a,0x5F
sc_dc_char:
        ld (hl),a
        inc hl
        djnz sc_dc_name
        ex de,hl
        ld e,(hl)               ; gold = 5 * field
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        ld (ix+9),l
        ld (ix+10),h
        pop hl
        ld a,(hl)
        inc a
        ld (ix+HERO_BODY),a
        inc hl
        inc hl
        ld a,(hl)
        ld (ix+14),a
        inc hl
        inc hl
        ld a,(hl)
        ld b,a
        and 0x0F
        bit 4,b
        jr z,sc_dc_flags
        or 0x80
sc_dc_flags:
        ld (ix+HERO_QFLAGS),a
        inc hl
        inc hl
        ld a,(hl)
        ld (ix+13),a
        ld a,(SC_SLOT)          ; the slot holds a hero
        ld e,a
        ld d,0
        ld hl,SC_ALIVE
        add hl,de
        ld (hl),0xFF
        jp sc_exit
sc_bad:
        ld ix,sc_txt_bad
        call ZX_PRINTSTRING
        call ZX_BLIT
        call ZX_WAITFIRE
        jp sc_load

; sc_key: A = 0-25 if a letter key of the keyboard is down, FFh if not.
; MSX matrix: row 2 bits 6-7 A B, row 3 C-J, row 4 K-R, row 5 S-Z.
sc_key:
        ld c,2
sc_key_row:
        ld a,c
        call rt_keyrow
        cpl
        or a
        jr nz,sc_key_bit
        inc c
        ld a,c
        cp 6
        jr nz,sc_key_row
sc_key_none:
        ld a,0xFF
        ret
sc_key_bit:
        ld b,0
sc_key_find:
        rrca
        jr c,sc_key_found
        inc b
        jr sc_key_find
sc_key_found:
        ld a,c
        sub 2
        add a,a
        add a,a
        add a,a
        add a,b
        sub 6
        jr c,sc_key_none
        cp 26
        jr nc,sc_key_none
        ret

; Two extra base-26 digits bind the payload to its class. Polynomial
; checksum modulo 676; single-letter substitutions always change it.
; Out: C = first check letter, L = second (both 0..25).
sc_checksum:
        ld a,(SC_SLOT)
        inc a
        ld l,a
        ld h,0
        ld ix,sc_code
        ld b,SC_DATA_LETTERS
sc_cs_letter:
        push bc
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; hash * 31
        ld e,(ix+0)
        ld d,0
        inc de
        add hl,de
        ld de,676
sc_cs_mod:
        or a
        sbc hl,de
        jr nc,sc_cs_mod
        add hl,de
        inc ix
        pop bc
        djnz sc_cs_letter
        ld de,26
        xor a
sc_cs_digit:
        or a
        sbc hl,de
        jr c,sc_cs_done
        inc a
        jr sc_cs_digit
sc_cs_done:
        add hl,de
        ld c,a
        ret

sc_radix:       dw 27,27,27,27,27,27, 2000, 8, 128, 32, 32, 79      ; (the first multiplication is of zero)
sc_val:         ds 2*SC_FIELDS+2,0
sc_num:         ds 9,0
sc_tmp:         ds 9,0
sc_count:       db 0
sc_code:        ds SC_LETTERS,0
sc_line:        db 0xFB,7, 0xFF,7,10
sc_line_letters:
                db 0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F,0x5F, 0xFA
        assert $ <= CODE_BASE+CODE_SIZE
sc_end:
