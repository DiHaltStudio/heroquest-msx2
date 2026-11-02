; Native text windows. Reloaded into the hero-code work area per call.
; IX: original record x,row,inner width,inner height, then glyphs.
; Same record consumption and click geometry as DrawTextBox. The paper is
; drawn first; letters are recoloured in scratch VRAM then copied with
; transparency, so their empty pixels preserve the fibres underneath.
        include "../build/rt_all.inc"
        org SCROLL_BASE
scroll:
        ld a,(ix+0)
        ld (sc_x),a
        ld a,(ix+1)
        ld (sc_row),a
        ld a,(ix+2)
        add a,2
        ld (sc_w),a
        ld a,(ix+3)
        add a,2
        ld (sc_h),a

        ; Sample an interior cell's original colours, including inverse.
        ld a,(sc_row)
        add a,3
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(sc_x)
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld de,ZX_ATTRS
        add hl,de
        ld c,(hl)
        ld b,0
        ld a,(ZX_INVOP)
        cp 0x2F
        jr nz,sc_normal
        ld b,0x80
sc_normal:
        ld a,c
        call rt_attr_colours
        ld a,c
        ld hl,sc_families
        add a,l
        ld l,a
        jr nc,sc_family_found
        inc h
sc_family_found:
        ld a,(hl)
        ld (sc_family),a
        ld e,a
        ld d,0
        ld hl,sc_inks
        add hl,de
        ld a,(hl)               ; high-contrast ink for this paper
        ld (sc_ink_colour),a
        xor a
        ld (sc_r),a
sc_background_row:
        xor a
        ld (sc_c),a
sc_background_cell:
        call sc_destination
        ; Forget the old glyph: attribute-only recolouring must not erase
        ; the native artwork. A later ordinary glyph records itself again.
        ld (hl),0
        ld a,(sc_family)
        add a,a
        ld b,a
        ld a,(sc_r)
        ld c,a
        ld a,(sc_c)
        xor c
        and 1
        add a,b
        call sc_blit_tile       ; paper under both the letters and the rim
        ld a,(sc_r)
        or a
        jr z,sc_top
        ld a,(sc_h)
        dec a
        ld c,a
        ld a,(sc_r)
        cp c
        jr z,sc_bottom
        ld a,(sc_c)
        or a
        jr nz,sc_right
        ld b,23
        jr sc_tile
sc_right:
        ld a,(sc_w)
        dec a
        ld c,a
        ld a,(sc_c)
        cp c
        jr nz,sc_background_next
        ld b,24
        jr sc_tile
sc_top:
        ld b,21
        jr sc_corner
sc_bottom:
        ld b,26
sc_corner:
        ld a,(sc_c)
        or a
        jr nz,sc_corner_right
        dec b
        jr sc_tile
sc_corner_right:
        ld a,(sc_w)
        dec a
        ld c,a
        ld a,(sc_c)
        cp c
        jr nz,sc_tile
        inc b
sc_tile:
        ld a,b
        call sc_blit_tile
sc_background_next:
        ld hl,sc_c
        inc (hl)
        ld a,(sc_w)
        cp (hl)
        jp nz,sc_background_cell
        ld hl,sc_r
        inc (hl)
        ld a,(sc_h)
        cp (hl)
        jp nz,sc_background_row
        jp sc_text

sc_blit_tile:
        ld b,SCROLL_SY
sc_tile_row:
        cp 6
        jr c,sc_tile_column
        sub 6
        push af
        ld a,b
        add a,8
        ld b,a
        pop af
        jr sc_tile_row
sc_tile_column:
        add a,a
        add a,a
        add a,a
        add a,SCROLL_SX
        ld (sc_cmd),a
        ld a,b
        ld (sc_cmd+2),a
        ld a,2
        ld (sc_cmd+3),a
        ld a,VCMD_LMMM_TIMP
        jp sc_command
sc_text:
        inc ix
        inc ix
        inc ix
        inc ix
        ld a,1
        ld (sc_r),a
sc_text_row:
        ld a,1
        ld (sc_c),a
sc_text_cell:
        ld a,(ix+0)
        inc ix
        cp 0x5F
        jr z,sc_text_next
        sub 0x30
        cp 69
        jr nc,sc_text_next
        ld (sc_glyph),a
        ; Fill an 8x8 scratch tile with ink, AND it with the font mask.
        ld hl,SCROLL_SCRATCH_X
        ld (sc_cmd+4),hl
        ld hl,512+SCROLL_SCRATCH_Y
        ld (sc_cmd+6),hl
        ld a,(sc_ink_colour)
        ld (sc_cmd+12),a
        ld a,0x80               ; LMMV
        call sc_command
        ld a,(sc_glyph)
        and 31
        add a,a
        add a,a
        add a,a
        ld (sc_cmd),a
        ld a,(sc_glyph)
        srl a
        srl a
        srl a
        srl a
        srl a
        add a,a
        add a,a
        add a,a
        add a,FONT_SY
        ld (sc_cmd+2),a
        ld a,3
        ld (sc_cmd+3),a
        ld a,0x91               ; LMMM AND
        call sc_command
        call sc_destination
        ld hl,SCROLL_SCRATCH_X
        ld (sc_cmd),hl
        ld hl,512+SCROLL_SCRATCH_Y
        ld (sc_cmd+2),hl
        ld a,VCMD_LMMM_TIMP
        call sc_command
sc_text_next:
        ld hl,sc_c
        inc (hl)
        ld a,(sc_w)
        dec a
        cp (hl)
        jp nz,sc_text_cell
        ld hl,sc_r
        inc (hl)
        ld a,(sc_h)
        dec a
        cp (hl)
        jp nz,sc_text_row
        ret

; Set destination in composition page 1. Mark it for presentation. Return
; HL = its cell-map address. All dimensions remain the original cell grid.
sc_destination:
        ld a,(sc_x)
        ld b,a
        ld a,(sc_c)
        add a,b
        ld d,a
        ld a,(sc_row)
        ld b,a
        ld a,(sc_r)
        add a,b
        ld e,a
        add a,a
        add a,a
        add a,a
        push de
        ld e,a
        ld b,d
        ld c,d
        ld a,8
        call rt_mark_x
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (sc_cmd+4),a
        ld a,e
        add a,26
        ld (sc_cmd+6),a
        ld a,1
        ld (sc_cmd+7),a
        pop de
        ld a,e
        add a,2
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,d
        ld d,0
        add hl,de
        ld de,RT_CELLMAP
        add hl,de
        ret
sc_command:
        ld (sc_cmd+14),a
        ld hl,sc_cmd
        jp rt_vdp_cmd

sc_x:           db 0
sc_row:         db 0
sc_w:           db 0
sc_h:           db 0
sc_r:           db 0
sc_c:           db 0
sc_family:      db 0
sc_ink_colour:  db 12
sc_glyph:       db 0
sc_cmd:         dw 0,0,0,256,8,8
                db 0,0,0
        include "../build/scroll_styles.inc"

        assert $ <= SCROLL_BASE+SCROLL_SIZE
        ds SCROLL_BASE+SCROLL_SIZE-$,0
