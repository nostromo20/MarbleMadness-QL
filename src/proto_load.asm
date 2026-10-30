; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; proto_load.asm - the data of all six races: data/mm_dat (layout
; src/mm_dat.inc), ZX0-compressed, resident; expanded at the start
; (shared) and at each race start (the race), in the buffers the loader made:
;   G_DAT   mm_dat as loaded              G_LIN   the race's bitmap
;   G_RBUF  the race area: at a race start the BUILD blob, SHARED (G_SHB) and
;           the work area (G_WORK: tile states + cell cache); then the PLAY
;           blob over all of it (its GEO2 is the logic's G_PGEO)
;   G_SPRB  the marble bank (pre-shifted at start from the marble's frames)
;=============================================================================

; dat_unpack - blob d0.w of mm_dat to (a1); out a1 = just past it, even (from
; the directory's unpacked size). Uses d0-d1/a0-a1.
dat_unpack:
        move.l  a1,-(sp)
        movea.l G_DAT(a6),a0
        move.w  d0,d1
        mulu.w  #DAT_DIRSZ,d1
        move.l  DAT_DIR+8(a0,d1.w),-(sp)        ; its unpacked size
        bsr.s   .go
        move.l  (sp)+,d0
        movea.l (sp)+,a1
        addq.l  #1,d0
        andi.w  #$FFFE,d0
        adda.l  d0,a1
        rts
.go:
        movea.l G_DAT(a6),a0
        mulu.w  #DAT_DIRSZ,d0
        move.l  DAT_DIR(a0,d0.w),d0     ; its offset
        adda.l  d0,a0
        bra     zx0_decompress

;-----------------------------------------------------------------------------
; boot_data - once: the shared blob, then the marble bank from its frames
;-----------------------------------------------------------------------------
boot_data:
        movem.l d0-d7/a0-a5,-(sp)
        moveq   #0,d0
        movea.l G_RBUF(a6),a1           ; (the race area, free at start)
        move.l  a1,G_SHB(a6)
        bsr     dat_unpack
        bsr     marble_bank
        movem.l (sp)+,d0-d7/a0-a5
        rts

;-----------------------------------------------------------------------------
; marble_bank - G_SPRB = the marble bank: a table
; of $35 longs (frame record offset, 0 = none), then per frame (in frame order):
; word nw, word xoff, 4 x (word data offset, word span offset) from the record;
; per shift s: 16 rows x nw x (mask, data) words, then 16 spans (screen byte
; offset of the first ink word, its data offset, words - 1 or -1). The pixels
; come from the 2-plane tiles (SH_MARB), the marble's own colours (1 -> 5 cyan,
; 2 -> 1 blue, 3 -> 0 black; 0 transparent), xoff -4 for the 24-px frames.
; The frame's pixels go to 16 padded rows (in G_LIN, free at the start: 4 clear,
; 24, 4 clear); shift s reads 4 x nw from 4 - s of a row, a (mask, data) long a
; pixel from mbpat; the spans come from the masks just written.
;-----------------------------------------------------------------------------
MB_FP           equ     0               ; locals: the frame list pointer
MB_SIZE         equ     4

marble_bank:
        lea     -MB_SIZE(sp),sp
        movea.l G_SPRB(a6),a2           ; a2 = the bank
        movea.l a2,a0
        move.w  #$35-1,d0
.clr:   clr.l   (a0)+
        dbra    d0,.clr
        movea.l a0,a3                   ; a3 = the next record
        lea     mb_frames(pc),a0
        move.l  a0,MB_FP(sp)
.frame: movea.l MB_FP(sp),a0
        moveq   #0,d7
        move.b  (a0)+,d7                ; frame id ($FF = end)
        move.l  a0,MB_FP(sp)
        cmpi.b  #$FF,d7
        beq     .done
        move.l  a3,d0
        sub.l   a2,d0
        move.w  d7,d1
        add.w   d1,d1
        add.w   d1,d1
        move.l  d0,0(a2,d1.w)           ; table[f] = the record's offset
        movea.l G_SHB(a6),a0
        lea     SH_WIDE(a0),a1
        moveq   #0,d6
        move.b  0(a1,d7.w),d6           ; wide?
        move.w  d7,d0
        mulu.w  #96,d0
        adda.l  d0,a0
        lea     SH_MARB(a0),a0          ; the frame's tiles
        movea.l G_LIN(a6),a1
        bsr     mb_pixels
        moveq   #5,d5                   ; nw = (w + 3) / 4 + 1
        moveq   #16,d4                  ; w
        moveq   #0,d0
        tst.b   d6
        beq.s   .nar
        moveq   #7,d5
        moveq   #24,d4
        moveq   #-4,d0
.nar:   move.w  d5,(a3)
        move.w  d0,2(a3)
        lea     20(a3),a4               ; a4 = the body
        moveq   #0,d3                   ; shift s
.shift: move.l  a4,d0                   ; data offset
        sub.l   a3,d0
        move.w  d3,d1
        lsl.w   #2,d1
        move.w  d0,4(a3,d1.w)
        movea.l a4,a1                   ; (the masks, for the spans)
        moveq   #4,d4                   ; the row's pixels from 4 - s
        sub.w   d3,d4
        lea     mbpat+128(pc),a5
        moveq   #0,d2                   ; y
.drow:  movea.l G_LIN(a6),a0
        adda.w  d4,a0
        move.w  d5,d1
        subq.w  #1,d1
.dw:    moveq   #15,d0                  ; (clear $FF -> 15: entries 8-15)
        and.b   (a0)+,d0
        lsl.w   #2,d0
        move.l  -128(a5,d0.w),d6        ; mask:data
        moveq   #15,d0
        and.b   (a0)+,d0
        lsl.w   #2,d0
        or.l    -64(a5,d0.w),d6
        moveq   #15,d0
        and.b   (a0)+,d0
        lsl.w   #2,d0
        or.l    0(a5,d0.w),d6
        moveq   #15,d0
        and.b   (a0)+,d0
        lsl.w   #2,d0
        or.l    64(a5,d0.w),d6
        move.l  d6,(a4)+
        dbra    d1,.dw
        addi.w  #32,d4
        addq.w  #1,d2
        cmpi.w  #16,d2
        blo.s   .drow
        ; the spans, from the masks just written (a1 = this shift's data)
        move.l  a4,d0
        sub.l   a3,d0
        move.w  d3,d1
        lsl.w   #2,d1
        move.w  d0,6(a3,d1.w)
        moveq   #0,d2                   ; y
.srow:  moveq   #-1,d7                  ; first ink word
        moveq   #0,d6                   ; last
        moveq   #0,d1
.sw:    cmpi.w  #$FFFF,(a1)
        beq.s   .sn
        tst.w   d7
        bpl.s   .sl
        move.w  d1,d7
.sl:    move.w  d1,d6
.sn:    addq.l  #4,a1
        addq.w  #1,d1
        cmp.w   d5,d1
        blo.s   .sw
        tst.w   d7
        bmi.s   .snone
        move.w  d7,d0
        add.w   d0,d0
        move.w  d0,(a4)+                ; f0 * 2
        move.w  d2,d0
        mulu.w  d5,d0
        add.w   d7,d0
        lsl.w   #2,d0
        move.w  d0,(a4)+                ; y * nw * 4 + f0 * 4
        move.w  d6,d0
        sub.w   d7,d0
        move.w  d0,(a4)+                ; n - 1
        bra.s   .snext
.snone: clr.l   (a4)+
        move.w  #-1,(a4)+
.snext: addq.w  #1,d2
        cmpi.w  #16,d2
        blo.s   .srow
        addq.w  #1,d3
        cmpi.w  #4,d3
        blo     .shift
        movea.l a4,a3                   ; (all sizes even: no pad)
        bra     .frame
.done:  lea     MB_SIZE(sp),sp
        rts

; mb_pixels - the frame's 2-plane tiles at (a0) -> the colour rows at (a1): 16
; rows x 32 (4 clear, 24, 4 clear), wide d6 (6 tiles: 3 over 3, else 4: TL TR
; BL BR)
mb_pixels:
        movem.l d0-d7/a0-a3,-(sp)
        movea.l a1,a2
        move.w  #16*32/4-1,d0
        moveq   #-1,d1
.f:     move.l  d1,(a2)+
        dbra    d0,.f
        lea     mb_pos4(pc),a2
        moveq   #4-1,d7
        tst.b   d6
        beq.s   .t
        lea     mb_pos6(pc),a2
        moveq   #6-1,d7
.t:     moveq   #0,d4
        move.b  (a2)+,d4                ; ox
        moveq   #0,d5
        move.b  (a2)+,d5                ; oy
        lsl.w   #5,d5
        add.w   d4,d5                   ; the tile's first pixel
        addq.w  #4,d5
        moveq   #0,d1                   ; y
.y:     move.b  (a0,d1.w),d2            ; plane 0
        move.b  8(a0,d1.w),d3           ; plane 1
        lea     0(a1,d5.w),a3
        moveq   #8-1,d6
.x:     moveq   #0,d0
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0                   ; plane 1 bit << 1 | plane 0 bit
        move.b  mb_col(pc,d0.w),(a3)+   ; the marble's QL colour ($FF = clear)
        dbra    d6,.x
        addi.w  #32,d5
        addq.w  #1,d1
        cmpi.w  #8,d1
        blo.s   .y
        subi.w  #8*32,d5
        lea     16(a0),a0
        dbra    d7,.t
        movem.l (sp)+,d0-d7/a0-a3
        rts
        include "proto_mbcol.inc"       ; mb_col: tile colour -> the marble's QL colour
mb_pos4:
        dc.b    0,0, 8,0, 0,8, 8,8
mb_pos6:
        dc.b    0,0, 8,0, 16,0, 0,8, 8,8, 16,8
mb_frames:                              ; the marble's frames, in order
        dc.b    $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        dc.b    $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        dc.b    $20,$21,$22,$23,$24,$25,$26,$27,$2B,$2C,$2D,$2E,$2F,$30,$31,$32
        dc.b    $33,$34,$FF
        even

; marble_bank: mbpat[p][c] = (mask, data) for colour c (0-7; 8-15 clear) at pixel p
mbpat:
q       set     0
        rept    4
c       set     0
        rept    16
        ifge    c-8
        dc.w    $C0C0>>(2*q),0
        else
        dc.w    0,(((c>>2)&1)<<15|((c>>1)&1)<<7|(c&1)<<6)>>(2*q)
        endc
c       set     c+1
        endr
q       set     q+1
        endr

; Mode 8: pixel p (0-3) of a word; pixpat[c][p] = colour c's bits there
pixmask:
        dc.w    $C0C0,$3030,$0C0C,$0303
pixpat:
c       set     0
        rept    8
        dc.w    ((c>>2)&1)<<15|((c>>1)&1)<<7|(c&1)<<6
        dc.w    ((c>>2)&1)<<13|((c>>1)&1)<<5|(c&1)<<4
        dc.w    ((c>>2)&1)<<11|((c>>1)&1)<<3|(c&1)<<2
        dc.w    ((c>>2)&1)<<9|((c>>1)&1)<<1|(c&1)<<0
c       set     c+1
        endr

;-----------------------------------------------------------------------------
; load_race - race d0.w (0-5) in the race area G_RBUF: its BUILD blob, SHARED
; and the work area, the tile states and the bitmap (expand_bitmap); then its
; PLAY blob over all of that (G_PGEO = its GEO2, PH_START the marble's start).
; Also the slope table. The race time is the race flow's business.
;-----------------------------------------------------------------------------
load_race:
        movem.l d0-d7/a0-a5,-(sp)
        move.w  d0,G_RACE(a6)
        move.w  d0,d1
        mulu.w  #2*N_SLOPE,d1
        lea     slp_tab0(pc),a0
        adda.l  d1,a0
        move.l  a0,G_SLTAB(a6)
        lea     slp_tabo0(pc),a0
        adda.l  d1,a0
        move.l  a0,G_SLTABO(a6)
        add.w   d0,d0
        addq.w  #1,d0                   ; the BUILD blob
        move.w  d0,-(sp)
        movea.l G_RBUF(a6),a1
        bsr     dat_unpack
        move.l  a1,G_SHB(a6)            ; SHARED after it
        moveq   #0,d0
        bsr     dat_unpack
        move.l  a1,G_WORK(a6)           ; the work area after that
        movea.l G_RBUF(a6),a5           ; a5 = the BUILD blob
        move.w  XH_LINES(a5),G_LINL(a6)
        bsr     tile_states
        bsr     expand_bitmap
        bsr     flag_build              ; the goal flags' wave frames (anim_update)
        ifne    MAP_FIX                 ; the map's colour fixes (XH_MFIX):
        movea.l G_RBUF(a6),a5           ; src/map_fix.asm, after mobj.asm (a PC-relative
        move.l  a0,-(sp)                ; far call, as anim_afix)
.mfx:   lea     .mfx(pc),a0
        adda.l  #map_fix-.mfx,a0
        jsr     (a0)
        movea.l (sp)+,a0
        endc
        move.w  (sp)+,d0
        addq.w  #1,d0                   ; the PLAY blob over all of it
        movea.l G_RBUF(a6),a1
        bsr     dat_unpack
        move.l  a1,G_OSPR(a6)           ; the object sprites after it
        clr.l   G_OSTY(a6)              ; (none built yet in this race's areas)
        clr.w   G_OSTY+4(a6)
        lea     6*OSPR_SLOT(a1),a1
        move.l  a1,G_RSPR(a6)           ; the race-wide pictures after those
        movea.l G_RBUF(a6),a5
        move.l  PH_OFRM(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,G_OFRM(a6)
        move.l  PH_RFRM(a5),d0
        lea     0(a5,d0.l),a0
        bsr     rspr_build              ; (pre-shifted now: this race's set only)
        bsr     mx_load                 ; the held marble's pictures (MX store)
        bsr     maze_play               ; Ultimate's goal maze: its lists (store)
        bsr     piston_load             ; Aerial's pistons: their backgrounds
        move.l  PH_GEO(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,G_PGEO(a6)
        bsr     geo_fill                ; (its shared tables and the occluder maps)
        clr.w   G_OCV(a6)               ; (occ_build's caches: a new GEO blob)
        move.l  PH_SPAWN(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,G_SPAWN(a6)
        bsr     slink_load              ; the slinkies' pictures: the sprite cache
        movem.l (sp)+,d0-d7/a0-a5
        rts

; geo_fill - G_PGEO's parts the PLAY blob ships zeroed: the race-independent
; tables (the GEOFIX blob, unpacked past the race's object sprite area's start,
; then copied in) and the occluder maps built from its lists:
; per course row a long, bit c = column c; KMAP where an entry covering the row
; (start < row < end) has a kill code (bit 7) among the 3 shape codes from the
; row, OMAP where one has a non-zero code without bit 7. Uses d0.
geo_fill:
        movem.l d1-d7/a0-a4,-(sp)
        movea.l G_OSPR(a6),a1           ; (the slots' area: empty until the play)
        move.l  a1,-(sp)
        moveq   #DAT_GEOFIX,d0
        bsr     dat_unpack
        movea.l (sp)+,a0
        movea.l G_PGEO(a6),a4
        lea     GEO_ROLL(a4),a1
        moveq   #256/4-1,d0
.r:     move.l  (a0)+,(a1)+
        dbra    d0,.r
        lea     GEO_OPAT(a4),a1
        move.w  #1024/4-1,d0
.p:     move.l  (a0)+,(a1)+
        dbra    d0,.p
        lea     GEO_FUNNEL(a4),a1
        moveq   #72/4-1,d0
.f:     move.l  (a0)+,(a1)+
        dbra    d0,.f
        lea     GEO_KMAP(a4),a3
        lea     GEO_OMAP(a4),a2
        moveq   #0,d7                   ; column
.col:   move.w  d7,d0
        add.w   d0,d0
        lea     GEO_OCOL(a4),a0
        move.w  0(a0,d0.w),d0
        lea     0(a4,d0.w),a0           ; the column's list (offsets from the blob)
        moveq   #3,d6
        move.w  d7,d0
        lsr.w   #3,d0
        sub.w   d0,d6                   ; d6 = the column's byte in a row's long
        moveq   #7,d5
        and.w   d7,d5                   ; d5 = its bit
.ent:   moveq   #0,d4
        move.b  (a0),d4                 ; end
        moveq   #0,d3
        move.b  1(a0),d3                ; type
        cmpi.b  #$FF,d3
        beq.s   .ncol
        moveq   #3,d2                   ; the entry's length
        tst.b   d3
        bmi.s   .len
        btst    #5,2(a0)
        beq.s   .len
        moveq   #4,d2
.len:   adda.w  d2,a0
        andi.w  #$7F,d3
        lea     GEO_OHGT(a4),a1
        moveq   #0,d0
        move.b  0(a1,d3.w),d0           ; h
        add.w   d3,d3
        lea     GEO_OSHP(a4),a1
        move.w  0(a1,d3.w),d1
        lea     0(a4,d1.w),a1           ; the shape (h + 2 codes)
        move.w  d4,d2
        sub.w   d0,d2
        andi.w  #$FF,d2                 ; start = (end - h) & $FF
        addq.w  #1,d2                   ; row = start + 1
        moveq   #1,d3                   ; k = row - start
.row:   cmp.w   d4,d2
        bhs.s   .ent                    ; while row < end
        move.w  d2,d1
        add.w   d1,d1
        add.w   d1,d1
        add.w   d6,d1                   ; the row's byte
        move.b  0(a1,d3.w),d0           ; the 3 codes from k
        or.b    1(a1,d3.w),d0
        or.b    2(a1,d3.w),d0
        beq.s   .nrow
        bpl.s   .nk
        bset    d5,0(a3,d1.w)           ; a kill code
.nk:    move.b  0(a1,d3.w),d0
        beq.s   .h1
        bpl.s   .hs
.h1:    move.b  1(a1,d3.w),d0
        beq.s   .h2
        bpl.s   .hs
.h2:    move.b  2(a1,d3.w),d0
        beq.s   .nrow
        bmi.s   .nrow
.hs:    bset    d5,0(a2,d1.w)           ; a hide code
.nrow:  addq.w  #1,d3
        addq.w  #1,d2
        bra.s   .row
.ncol:  addq.w  #1,d7
        cmpi.w  #32,d7
        blo     .col
        movem.l (sp)+,d1-d7/a0-a4
        rts

; tile_states - G_WORK: state k = (BG 4 KB, sprites 4 KB, palettes 32 B); state 0
; from the shared BG set + the race's patches, its sprite table and palettes;
; state k = state k-1 + its zone's data (addresses < $2000: the tile patterns,
; >= $3F00: the palettes). a5 = the race blob.
tile_states:
        movea.l G_WORK(a6),a1
        movea.l G_SHB(a6),a0
        lea     SH_BG0(a0),a0
        move.w  #4096/4-1,d0
.c0:    move.l  (a0)+,(a1)+
        dbra    d0,.c0
        move.l  XH_SPRTAB(a5),d0        ; the sprite table: 256 tiles of the
        lea     0(a5,d0.l),a2           ; shared store (SH_SPRS)
        movea.l G_SHB(a6),a3
        lea     SH_SPRS(a3),a3
        move.w  #256-1,d1
.c1:    move.w  (a2)+,d0
        lsl.w   #4,d0
        lea     0(a3,d0.w),a0
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        dbra    d1,.c1
        move.l  XH_PAL(a5),d0
        lea     0(a5,d0.l),a0
        moveq   #32/4-1,d0
.c2:    move.l  (a0)+,(a1)+
        dbra    d0,.c2
        ; the race's BG tiles over the shared set
        movea.l G_WORK(a6),a1
        move.l  XH_PATCH(a5),d0
        lea     0(a5,d0.l),a0
        move.w  (a0)+,d1
        bra.s   .pn
.pt:    moveq   #0,d0
        move.b  (a0)+,d0
        lsl.w   #4,d0
        lea     0(a1,d0.w),a2
        moveq   #16-1,d2
.pb:    move.b  (a0)+,(a2)+
        dbra    d2,.pb
.pn:    dbra    d1,.pt
        ; states 1..n-1
        move.l  XH_ZONES(a5),d0
        lea     0(a5,d0.l),a3           ; a3 = the zone lists
        movea.l G_WORK(a6),a1           ; a1 = state k-1
        moveq   #1,d7
.st:    cmp.w   XH_NSTATE(a5),d7
        bhs.s   .out
        lea     ST_BYTES(a1),a2         ; state k = a copy
        movea.l a1,a0
        move.w  #ST_BYTES/4-1,d0
.cp:    move.l  (a0)+,(a2)+
        dbra    d0,.cp
        lea     ST_BYTES(a1),a1
        move.w  (a3)+,d6                ; chunks
        bra.s   .cn
.ch:    move.w  (a3)+,d2                ; address
        move.w  (a3)+,d3                ; length
        move.w  d3,d5
        bra.s   .bn
.bt:    move.b  (a3)+,d4
        cmpi.w  #$2000,d2
        bhs.s   .pal
        move.b  d4,0(a1,d2.w)
        bra.s   .bx
.pal:   cmpi.w  #$3F00,d2
        blo.s   .bx
        moveq   #$1F,d0
        and.w   d2,d0
        addi.w  #8192,d0
        move.b  d4,0(a1,d0.w)
.bx:    addq.w  #1,d2
.bn:    dbra    d3,.bt
        btst    #0,d5                   ; (4 + len) even
        beq.s   .cn
        addq.l  #1,a3
.cn:    dbra    d6,.ch
        addq.w  #1,d7
        bra.s   .st
.out:   rts

;-----------------------------------------------------------------------------
; expand_bitmap - G_LIN: LIN_TOP lines of row 0's backdrop, then the map rows:
; each 8x8 cell from the cache (one Mode 8 cell per state, tile and palette
; number, built once), then the sprites last to first (an earlier sprite wins
; its pixels; one behind the BG shows the BG where it is not colour 0).
; a5 = the race blob.
;-----------------------------------------------------------------------------
EB_CMAP         equ     0               ; locals: the colour map
EB_MAP          equ     4
EB_ATTR         equ     8
EB_RST          equ     12
EB_OVR          equ     16              ; next override (row.w, col.b, state.b), or 0
EB_OVRN         equ     20
EB_INDEX        equ     24              ; cache index: nstate x 1024 words
EB_SLOTS        equ     28              ; cache cells (32 B each)
EB_NSLOT        equ     32
EB_SIZE         equ     34

expand_bitmap:
        lea     -EB_SIZE(sp),sp
        move.l  XH_COLMAP(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,EB_CMAP(sp)
        move.l  XH_MAP(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,EB_MAP(sp)
        move.l  XH_ATTR(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,EB_ATTR(sp)
        move.l  XH_RSTATE(a5),d0
        lea     0(a5,d0.l),a0
        move.l  a0,EB_RST(sp)
        move.l  XH_OVR(a5),d0
        lea     0(a5,d0.l),a0
        move.w  (a0)+,EB_OVRN(sp)
        move.l  a0,EB_OVR(sp)
        ; the cache after the states: index (2 KB a state, cleared), then the cells
        move.w  XH_NSTATE(a5),d0
        mulu.w  #ST_BYTES,d0
        movea.l G_WORK(a6),a0
        adda.l  d0,a0
        move.l  a0,EB_INDEX(sp)
        move.w  XH_NSTATE(a5),d0
        mulu.w  #1024/2,d0              ; longs to clear
        subq.w  #1,d0
.ci:    clr.l   (a0)+
        dbra    d0,.ci
        move.l  a0,EB_SLOTS(sp)
        clr.w   EB_NSLOT(sp)
        ; the top lines: row 0's backdrop (state of cell 0,0: palette colour 0)
        moveq   #0,d0                   ; row
        moveq   #0,d1                   ; col
        bsr     eb_state                ; a0 = the state
        moveq   #0,d4
        move.b  8192(a0),d4
        andi.w  #$3F,d4
        lsl.w   #2,d4                   ; colour x 4
        movea.l EB_CMAP(sp),a1          ; ((locals: 4 bytes deeper inside the bsr)
        movea.l G_LIN(a6),a2
        moveq   #LIN_TOP-1,d7
.tl:    moveq   #1,d5
        and.w   d7,d5                   ; (LIN_TOP - 1 - line) & 1 = line & 1 (even TOP)
        eori.w  #1,d5
        add.w   d5,d5                   ; parity y x 2
        move.w  d4,d0
        add.w   d5,d0
        moveq   #0,d2
        move.b  0(a1,d0.w),d2           ; even x
        moveq   #0,d3
        move.b  1(a1,d0.w),d3           ; odd x
        bsr     eb_pairword             ; d0 = the line's word
        moveq   #64-1,d6
.tw:    move.w  d0,(a2)+
        dbra    d6,.tw
        dbra    d7,.tl
        ; the map rows (a2 = the cell's place in the bitmap, a3 / a4 = the map /
        ; palette-select bytes, d5 = the row's state x 2048 (the cache index))
        movea.l EB_MAP(sp),a3
        movea.l EB_ATTR(sp),a4
        moveq   #0,d6                   ; row
.row:   cmp.w   XH_ROWS(a5),d6
        bhs     .rows_done
        moveq   #0,d0
        move.w  d6,d0
        lsl.l   #3,d0
        addi.l  #LIN_TOP,d0
        lsl.l   #7,d0                   ; x BPL
        movea.l G_LIN(a6),a2
        adda.l  d0,a2
        moveq   #0,d7                   ; col
.col:   move.w  d6,d0
        move.w  d7,d1
        bsr     eb_state_i              ; d2 = state index
        moveq   #0,d3
        move.b  (a3)+,d3                ; tile
        moveq   #0,d4
        move.b  (a4)+,d4                ; palette
        ; the cache: index[state][tile x 4 + palette] = slot + 1
        moveq   #0,d0
        move.w  d2,d0
        moveq   #11,d1
        lsl.l   d1,d0                   ; state x 2048
        move.w  d3,d1
        lsl.w   #3,d1
        add.w   d4,d1
        add.w   d4,d1                   ; (tile x 4 + palette) x 2
        add.l   d1,d0
        movea.l EB_INDEX(sp),a0
        move.w  0(a0,d0.l),d0
        beq.s   .new
        subq.w  #1,d0
        moveq   #0,d1
        move.w  d0,d1
        lsl.l   #5,d1
        movea.l EB_SLOTS(sp),a0
        adda.l  d1,a0
        bra.s   .put
.new:   bsr     eb_cell                 ; a0 = the Mode 8 cell (8 x 4 B)
.put:   movea.l a2,a1
        move.l  (a0)+,(a1)
        move.l  (a0)+,BPL(a1)
        move.l  (a0)+,2*BPL(a1)
        move.l  (a0)+,3*BPL(a1)
        move.l  (a0)+,4*BPL(a1)
        move.l  (a0)+,5*BPL(a1)
        move.l  (a0)+,6*BPL(a1)
        move.l  (a0)+,7*BPL(a1)
        addq.l  #4,a2
        addq.w  #1,d7
        cmpi.w  #32,d7
        blo.s   .col
        addq.w  #1,d6
        bra     .row
.rows_done:
        clr.w   G_SPTAG(a6)             ; the map's sprites (the flags: flag_build)
        bsr     eb_sprites
        ; the animated cells (XH_ANIM; Beginner's bridge): each group's variants rendered
        ; into the race area's top (cells as above: the same cache), the runtime
        ; descriptors G_ANG (anim_update patches the bitmap from them)
        clr.w   G_ANN(a6)
        move.l  XH_ANIM(a5),d0
        beq     .an_x
        lea     0(a5,d0.l),a3           ; a3 = the group headers
        move.w  (a3)+,d7
        move.w  d7,G_ANN(a6)
        move.w  d7,d0
        mulu.w  #16,d0
        lea     0(a3,d0.w),a1           ; a1 = the variants' tiles
        lea     G_ANG(a6),a4
        subq.w  #1,d7
.ag:    moveq   #0,d0                   ; the box in the bitmap
        move.w  (a3),d0
        lsl.l   #3,d0
        addi.l  #LIN_TOP,d0
        move.w  d0,AN_Y(a4)
        lsl.l   #7,d0
        moveq   #0,d1
        move.w  2(a3),d1
        lsl.w   #2,d1
        add.l   d1,d0
        add.l   G_LIN(a6),d0
        move.l  d0,AN_LIN(a4)
        move.l  12(a3),d0               ; the store: bit 31 the bitmap's tail, else
        bclr    #31,d0                  ; the race area
        beq.s   .ag_r
        add.l   G_LIN(a6),d0
        bra.s   .ag_s
.ag_r:  add.l   G_RBUF(a6),d0
.ag_s:  move.l  d0,AN_STORE(a4)
        movea.l d0,a2                   ; a2 = this variant's store
        move.w  6(a3),d0
        lsl.w   #2,d0
        move.w  d0,AN_LB(a4)            ; bytes a line
        move.w  4(a3),d1
        lsl.w   #3,d1
        move.w  d1,AN_LINES(a4)
        mulu.w  d1,d0
        move.w  d0,AN_VB(a4)            ; bytes a variant
        move.w  10(a3),AN_SEL(a4)
        move.w  #-1,AN_SHOWN(a4)        ; (the bitmap: none of them known)
        clr.l   AN_CODE(a4)             ; (copied whole: LB x LINES)
        move.w  8(a3),d6
        subq.w  #1,d6                   ; variants - 1
.av:    moveq   #0,d5                   ; row in the box
.ar:    clr.w   G_ANC(a6)               ; col in the box
.ac:    move.w  (a3),d0
        add.w   d5,d0                   ; map row
        movea.l EB_RST(sp),a0
        moveq   #0,d2
        move.b  0(a0,d0.w),d2           ; its state
        moveq   #0,d3
        move.b  (a1)+,d3                ; the variant's tile
        mulu.w  #32,d0
        add.w   2(a3),d0
        add.w   G_ANC(a6),d0
        movea.l EB_ATTR(sp),a0
        moveq   #0,d4
        move.b  0(a0,d0.l),d4           ; the map's palette there
        moveq   #0,d0                   ; the cache (as .col)
        move.w  d2,d0
        moveq   #11,d1
        lsl.l   d1,d0
        move.w  d3,d1
        lsl.w   #3,d1
        add.w   d4,d1
        add.w   d4,d1
        add.l   d1,d0
        movea.l EB_INDEX(sp),a0
        move.w  0(a0,d0.l),d0
        beq.s   .an_new
        subq.w  #1,d0
        moveq   #0,d1
        move.w  d0,d1
        lsl.l   #5,d1
        movea.l EB_SLOTS(sp),a0
        adda.l  d1,a0
        bra.s   .an_put
.an_new:
        bsr     eb_cell
.an_put:
        move.w  d5,d0                   ; its place: (row x 8 lines) x LB + col x 4
        lsl.w   #3,d0
        mulu.w  AN_LB(a4),d0
        move.w  G_ANC(a6),d1
        lsl.w   #2,d1
        add.l   d1,d0
        moveq   #0,d1
        move.w  AN_LB(a4),d1
        moveq   #8-1,d2
.al:    move.l  (a0)+,0(a2,d0.l)
        add.l   d1,d0
        dbra    d2,.al
        addq.w  #1,G_ANC(a6)
        move.w  G_ANC(a6),d0
        cmp.w   6(a3),d0
        blo     .ac
        addq.w  #1,d5
        cmp.w   4(a3),d5
        blo     .ar
        adda.w  AN_VB(a4),a2            ; the next variant
        dbra    d6,.av
        move.l  a1,d0                   ; (the next group's tiles: even)
        addq.l  #1,d0
        andi.w  #$FFFE,d0
        movea.l d0,a1
        lea     16(a3),a3
        lea     AN_SIZE(a4),a4
        dbra    d7,.ag
        ; a group's own pixels in their own colours (XH_AFIX: Aerial's
        ; catapult): anim_afix (src/anim_afix.asm, after mobj.asm,
        ; out of the frame code's way: a PC-relative far call)
        tst.l   XH_AFIX(a5)
        beq     .an_x
        move.l  a0,-(sp)
.afx:   lea     .afx(pc),a0
        adda.l  #anim_afix-.afx,a0
        jsr     (a0)
        movea.l (sp)+,a0
        ; Ultimate's goal maze (XH_MAZE): its K pictures rendered
        ; into the store (race area top; cells as above: the same cache), then copied
        ; there: the literal ones (the cells under a flag: 4 frames each), the cells'
        ; bitmap addresses, the map's picture per cell (also what each shows), the
        ; flag bytes and the flag cells' list, the states' lists; last, the map's
        ; pictures put in every maze cell
.an_x:  clr.l   G_MZST(a6)
        move.l  XH_MAZE(a5),d0
        beq     .mz_x
        lea     0(a5,d0.l),a3           ; a3 = the header
        move.l  MZ_STORE(a3),d0         ; (bit 31: in the bitmap's tail, else the
        bclr    #31,d0                  ; race area)
        beq.s   .mz_ra
        add.l   G_LIN(a6),d0
        bra.s   .mz_sb
.mz_ra: add.l   G_RBUF(a6),d0
.mz_sb: move.l  d0,G_MZST(a6)
        movea.l d0,a2                   ; a2 = the pictures (K x 32 B)
        lea     MZ_HSIZE(a3),a1         ; a1 = K x (state, tile, palette, 0)
        move.w  MZ_K(a3),d7
        subq.w  #1,d7
        bmi.s   .mz_l0
.mz_k:  moveq   #0,d2
        move.b  (a1)+,d2
        moveq   #0,d3
        move.b  (a1)+,d3
        moveq   #0,d4
        move.b  (a1)+,d4
        addq.l  #1,a1
        moveq   #0,d0                   ; the cache (as .col)
        move.w  d2,d0
        moveq   #11,d1
        lsl.l   d1,d0
        move.w  d3,d1
        lsl.w   #3,d1
        add.w   d4,d1
        add.w   d4,d1
        add.l   d1,d0
        movea.l EB_INDEX(sp),a0
        move.w  0(a0,d0.l),d0
        beq.s   .mz_new
        subq.w  #1,d0
        moveq   #0,d1
        move.w  d0,d1
        lsl.l   #5,d1
        movea.l EB_SLOTS(sp),a0
        adda.l  d1,a0
        bra.s   .mz_put
.mz_new:
        bsr     eb_cell                 ; (keeps a1 / a2)
.mz_put:
        moveq   #8-1,d0
.mz_c:  move.l  (a0)+,(a2)+
        dbra    d0,.mz_c
        dbra    d7,.mz_k
.mz_l0: move.w  MZ_KL(a3),d7            ; the literal pictures: KL x 4 x 32 B
        lsl.w   #5,d7
        subq.w  #1,d7
        bmi.s   .mz_o0
.mz_lt: move.l  (a1)+,(a2)+
        dbra    d7,.mz_lt
.mz_o0: movea.l a1,a3                   ; the MP_ part: the lists etc. (maze_lists)
        lea     MP_HSIZE(a3),a1
        bsr     maze_lists
.mz_x:  ; Intermediate's water (XH_WAVE): its K pictures rendered into the store
        ; (the bitmap's tail; through the same cache) and its L literal ones after
        ; them, then the cells' bitmap
        ; addresses, the picture each has and shows (the map's: the bitmap is built
        ; calm, as the map is), no flags, the list empty, the patches' lists and
        ; their compatibility rows; no patch written yet
        clr.l   G_WVST(a6)
        move.l  XH_WAVE(a5),d0
        beq     .wv_x
        lea     0(a5,d0.l),a3           ; a3 = the header
        move.l  WV_STORE(a3),d0
        bclr    #31,d0
        add.l   G_LIN(a6),d0
        move.l  d0,G_WVST(a6)
        movea.l d0,a2
        lea     WV_HSIZE(a3),a1         ; K x (state, tile, palette, 0)
        move.w  WV_K(a3),d7
        subq.w  #1,d7
.wv_k:  moveq   #0,d2
        move.b  (a1)+,d2
        moveq   #0,d3
        move.b  (a1)+,d3
        moveq   #0,d4
        move.b  (a1)+,d4
        addq.l  #1,a1
        moveq   #0,d0                   ; the cache (as .col)
        move.w  d2,d0
        moveq   #11,d1
        lsl.l   d1,d0
        move.w  d3,d1
        lsl.w   #3,d1
        add.w   d4,d1
        add.w   d4,d1
        add.l   d1,d0
        movea.l EB_INDEX(sp),a0
        move.w  0(a0,d0.l),d0
        beq.s   .wv_new
        subq.w  #1,d0
        moveq   #0,d1
        move.w  d0,d1
        lsl.l   #5,d1
        movea.l EB_SLOTS(sp),a0
        adda.l  d1,a0
        bra.s   .wv_put
.wv_new:
        bsr     eb_cell                 ; (keeps a1 / a2)
.wv_put:
        moveq   #8-1,d0
.wv_c:  move.l  (a0)+,(a2)+
        dbra    d0,.wv_c
        dbra    d7,.wv_k
        move.w  WV_L(a3),d7             ; the literal pictures (under scenery sprites)
        lsl.w   #3,d7
        bra.s   .wv_in
.wv_i:  move.l  (a1)+,(a2)+
.wv_in: dbra    d7,.wv_i
        move.l  a2,G_WVOF(a6)           ; the cells' addresses
        move.w  WV_N(a3),d7
        subq.w  #1,d7
.wv_o:  moveq   #0,d0
        move.w  (a1)+,d0                ; row x 32 + col
        moveq   #31,d1
        and.w   d0,d1
        lsl.w   #2,d1                   ; col x 4
        lsr.w   #5,d0
        lsl.w   #3,d0
        addi.w  #LIN_TOP,d0
        lsl.l   #7,d0                   ; (LIN_TOP + 8 row) x BPL
        add.l   d1,d0
        add.l   G_LIN(a6),d0
        move.l  d0,(a2)+
        dbra    d7,.wv_o
        move.w  WV_N(a3),d6             ; d6 = N, even
        addq.w  #1,d6
        andi.w  #$FFFE,d6
        move.l  a2,G_WVTG(a6)           ; target, shown, base: the map's
        lea     0(a2,d6.w),a0
        move.l  a0,G_WVCU(a6)
        move.w  d6,d7
        subq.w  #1,d7
.wv_b:  move.b  (a1),(a0)+
        move.b  (a1)+,(a2)+
        dbra    d7,.wv_b
        move.l  a0,G_WVBS(a6)
        movea.l G_WVTG(a6),a2
        move.w  d6,d7
        subq.w  #1,d7
.wv_s:  move.b  (a2)+,(a0)+
        dbra    d7,.wv_s
        movea.l a0,a2
        move.l  a2,G_WVFL(a6)           ; the flags: none
        move.w  d6,d7
        subq.w  #1,d7
.wv_f:  clr.b   (a2)+
        dbra    d7,.wv_f
        move.l  a2,G_WVDL(a6)           ; the list: empty
        move.l  a2,G_WVDP(a6)
        adda.w  d6,a2
        move.l  a2,G_WVLI(a6)           ; the lists
        move.w  WV_LB(a3),d7
        lsr.w   #1,d7
        subq.w  #1,d7
.wv_l:  move.w  (a1)+,(a2)+
        dbra    d7,.wv_l
        move.l  a2,G_WVCM(a6)           ; the compatibility rows
        move.w  #46*WV_CMPB/2-1,d7
.wv_m:  move.w  (a1)+,(a2)+
        dbra    d7,.wv_m
        move.l  a2,G_WVRW(a6)           ; the cells' rows
        adda.w  d6,a2
        move.l  a2,G_WVRS(a6)           ; each row's first cell
        movea.l G_WVRW(a6),a2
        move.w  WV_NR(a3),d7            ; (N even + NR + 1 even, in words)
        addq.w  #2,d7
        andi.w  #$FFFE,d7
        add.w   d6,d7
        lsr.w   #1,d7
        subq.w  #1,d7
.wv_r:  move.w  (a1)+,(a2)+
        dbra    d7,.wv_r
        move.w  WV_R0(a3),G_WVR0(a6)
        move.w  WV_NR(a3),G_WVNR(a6)
        move.w  #$8000,G_WVW(a6)        ; (no window seen yet)
        move.w  WV_Y0(a3),G_WVY0(a6)
        move.w  WV_Y1(a3),G_WVY1(a6)
        move.w  #-1,G_WVL1(a6)          ; (no patch written)
        move.w  #-1,G_WVL2(a6)
.wv_x:  lea     EB_SIZE(sp),sp
        rts

;-----------------------------------------------------------------------------
; flag_build - the goal flags (XH_FLAGS; frame id 4 + (fc >> 3 & 3),
; 8 logic steps each): after the map (expand_bitmap, which paints the sprites
; tagged 0), per flag k: its put code generated from its spans into its store
; (a "move.l / move.w (a0)+,d16(a1)" per span part, rts), the map's bytes of
; the spans kept in the scratch variant, then for each wave frame v its sprites
; (tag 1 + 4k + v) painted over the map, the spans' bytes kept as variant v and
; the map's put back; last, the frame the map was built with (FL_INIT). Each
; flag becomes one more anim_update group (selector 2, AN_CODE = the put code).
; a5 = the BUILD blob.
;-----------------------------------------------------------------------------
flag_build:
        clr.l   G_GSCH(a6)
        move.w  G_ANN(a6),G_ANCN(a6)    ; (anim_update: the cells' groups, the range)
        move.w  #$FFFF,G_ANL0(a6)
        clr.w   G_ANL1(a6)
        clr.l   G_FLL0(a6)              ; (G_FLL0, G_FLL1: no flags)
        move.l  XH_FLAGS(a5),d0
        beq     .x
        move.w  #$7FFF,G_FLL0(a6)
        lea     0(a5,d0.l),a3           ; a3 = the descriptors
        move.w  (a3)+,d7
        beq     .x
        move.w  d7,d0
        mulu.w  #FL_SIZE,d0
        lea     0(a3,d0.w),a2           ; a2 = flag 0's spans
        movea.l a2,a0                   ; the opaque bits: after every flag's spans
        movea.l a3,a1
        move.w  d7,d1
        subq.w  #1,d1
.sp:    move.w  FL_NSPAN(a1),d0
        lsl.w   #2,d0
        adda.w  d0,a0
        lea     FL_SIZE(a1),a1
        dbra    d1,.sp
        move.l  a0,G_FLM(a6)
        move.w  G_ANN(a6),d0            ; a4 = its anim_update group (after the cells')
        mulu.w  #AN_SIZE,d0
        lea     G_ANG(a6),a4
        adda.w  d0,a4
        moveq   #0,d6                   ; k
        subq.w  #1,d7
.f:     moveq   #0,d0                   ; the box
        move.w  FL_LINE(a3),d0
        move.w  d0,AN_Y(a4)
        lsl.l   #7,d0                   ; x BPL
        moveq   #0,d1
        move.w  FL_XB(a3),d1
        add.l   d1,d0
        add.l   G_LIN(a6),d0
        move.l  d0,AN_LIN(a4)
        move.w  FL_LINES(a3),AN_LINES(a4)
        move.w  FL_VB(a3),AN_VB(a4)
        moveq   #2,d0                   ; selector 2: a flag, 3: the GOAL text (no cover)
        add.w   FL_KIND(a3),d0
        move.w  d0,AN_SEL(a4)
        clr.w   AN_LB(a4)
        move.l  FL_STORE(a3),d0         ; the store: the bitmap's tail or the race area
        bclr    #31,d0
        beq.s   .ra
        add.l   G_LIN(a6),d0
        bra.s   .sb
.ra:    add.l   G_RBUF(a6),d0
.sb:    move.l  d0,AN_CODE(a4)
        movea.l d0,a0
        moveq   #0,d1
        move.w  FL_CODE(a3),d1
        add.l   d1,d0
        move.l  d0,AN_STORE(a4)
        movea.l a2,a1                   ; the put code
        move.w  FL_NSPAN(a3),d5
        subq.w  #1,d5
        bmi.s   .g4                     ; (none: Ultimate's, its box all goal maze cells)
.g:     move.w  (a1)+,d1                ; disp
        move.w  (a1)+,d2                ; words
.g2:    cmpi.w  #2,d2
        blo.s   .g1
        move.w  #$2358,(a0)+            ; move.l (a0)+,d16(a1)
        move.w  d1,(a0)+
        addq.w  #4,d1
        subq.w  #2,d2
        bra.s   .g2
.g1:    tst.w   d2
        beq.s   .g3
        move.w  #$3358,(a0)+            ; move.w (a0)+,d16(a1)
        move.w  d1,(a0)+
.g3:    dbra    d5,.g
.g4:    move.w  #$4E75,(a0)+            ; rts
        tst.w   FL_KIND(a3)             ; (the flags' line range: flag_cover)
        bne.s   .l1
        btst    #0,G_TFLOFF+1(a6)
        bne.s   .l1
        move.w  FL_BOXL(a3),d0
        cmp.w   G_FLL0(a6),d0
        bhs.s   .l0
        move.w  d0,G_FLL0(a6)
.l0:    addi.w  #FL_BOXH,d0
        cmp.w   G_FLL1(a6),d0
        bls.s   .l1
        move.w  d0,G_FLL1(a6)
.l1:    move.w  FL_BOXL(a3),AN_BOXL(a4) ; the cover data (flag_cover): after the scratch
        move.w  FL_XB(a3),d0            ; variant, as the data lays out the
        lsr.w   #1,d0                   ; store (code + variants, rounded up to 4)
        move.w  d0,AN_WC(a4)
        moveq   #FL_NVAR+1,d0
        mulu.w  FL_VB(a3),d0
        add.w   FL_CODE(a3),d0
        addq.l  #3,d0
        andi.w  #$FFFC,d0
        add.l   AN_CODE(a4),d0
        move.l  d0,AN_HIDE(a4)
        moveq   #FL_NVAR,d0             ; the map's span bytes -> the scratch variant
        bsr     .vaddr
        bsr     fl_get
        moveq   #0,d4                   ; v
.v:     clr.l   G_GSCH(a6)              ; (the GOAL text: its own colours)
        tst.w   FL_KIND(a3)
        beq.s   .v0
        move.l  XH_GSCHEME(a5),d0
        beq.s   .v0
        add.l   a5,d0
        move.l  d0,G_GSCH(a6)
.v0:    move.w  d6,d0                   ; frame v's sprites over the map
        lsl.w   #2,d0
        add.w   d4,d0
        addq.w  #1,d0
        move.w  d0,G_SPTAG(a6)
        movem.l d4-d7/a2-a4,-(sp)
        bsr     eb_sprites
        movem.l (sp)+,d4-d7/a2-a4
        clr.l   G_GSCH(a6)
        move.w  d4,d0                   ; their span bytes -> variant v
        bsr     .vaddr
        bsr     fl_get
        tst.w   FL_KIND(a3)
        bne.s   .nc
        bsr     .cover                  ; its cover data (the flags)
.nc:
        moveq   #FL_NVAR,d0             ; the map's back
        bsr     .vaddr
        bsr     .put
        addq.w  #1,d4
        cmpi.w  #FL_NVAR,d4
        blo     .v
        move.w  FL_INIT(a3),d0          ; the frame the map was built with
        move.w  d0,AN_SHOWN(a4)
        bsr     .vaddr
        bsr     .put
        move.w  FL_KIND(a3),d0
        bne.s   .k1
        addi.l  #FL_NVAR*FL_BOXH*2,G_FLM(a6)   ; (the next flag's opaque bits)
.k1:    move.w  G_TFLOFF(a6),d1         ; (test loader: bit kind set = still, as baked:
        btst    d0,d1                   ; the group not kept)
        bne.s   .k2
        move.w  FL_LINE(a3),d0          ; (the groups' line range: anim_update)
        cmp.w   G_ANL0(a6),d0
        bhs.s   .m0
        move.w  d0,G_ANL0(a6)
.m0:    add.w   FL_LINES(a3),d0
        cmp.w   G_ANL1(a6),d0
        bls.s   .m1
        move.w  d0,G_ANL1(a6)
.m1:    lea     AN_SIZE(a4),a4
        addq.w  #1,G_ANN(a6)
.k2:    move.w  FL_NSPAN(a3),d0         ; the next one
        lsl.w   #2,d0
        adda.w  d0,a2
        lea     FL_SIZE(a3),a3
        addq.w  #1,d6
        dbra    d7,.f
        clr.w   G_SPTAG(a6)
.x:     rts
; a0 = variant d0's bytes, a1 = the box (d0-d1)
.vaddr: mulu.w  FL_VB(a3),d0
        movea.l AN_STORE(a4),a0
        adda.l  d0,a0
        movea.l AN_LIN(a4),a1
        rts
; frame d4's cover data: per box word a long (the bitmap's word AND m, NOT m), m =
; the Mode 8 mask of its opaque pixels (hide_lut[15 - their nibble]); the bitmap
; holds frame d4 now
.cover: movem.l d4-d5/a2/a5,-(sp)
        move.w  d4,d0
        mulu.w  #FL_HIDEB,d0
        movea.l AN_HIDE(a4),a0
        adda.l  d0,a0
        move.w  d4,d0
        mulu.w  #FL_BOXH*2,d0
        movea.l G_FLM(a6),a1
        adda.l  d0,a1                   ; its opaque bits
        moveq   #0,d0
        move.w  FL_BOXL(a3),d0
        lsl.l   #7,d0
        add.w   FL_XB(a3),d0
        add.l   G_LIN(a6),d0
        movea.l d0,a5                   ; the box in the bitmap
        lea     hide_lut(pc),a2
        move.w  #FL_BOXH-1,d5
.cl:    move.w  (a1)+,d1
        moveq   #4-1,d3
.cw:    rol.w   #4,d1
        moveq   #15,d0
        and.w   d1,d0
        eori.w  #15,d0
        add.w   d0,d0
        move.w  0(a2,d0.w),d2           ; m
        move.w  (a5)+,d0
        and.w   d2,d0
        swap    d0                      ; (the flag's colours)
        move.w  d2,d0
        not.w   d0                      ; (keep)
        move.l  d0,(a0)+
        dbra    d3,.cw
        lea     BPL-8(a5),a5
        dbra    d5,.cl
        movem.l (sp)+,d4-d5/a2/a5
        rts
; the put code: a0 (variant) -> a1 (box)
.put:   move.l  a2,-(sp)
        movea.l AN_CODE(a4),a2
        jsr     (a2)
        movea.l (sp)+,a2
        rts

; fl_get - a flag's span bytes from the box a1 into a0 (a2 = the spans, a3 = its
; descriptor)
fl_get:
        movem.l d0-d2/a0-a3,-(sp)
        move.w  FL_NSPAN(a3),d0
        subq.w  #1,d0
        bmi.s   .z
.s:     move.w  (a2)+,d1                ; disp
        move.w  (a2)+,d2                ; words
        subq.w  #1,d2
        movea.l a1,a3
        adda.w  d1,a3
.w:     move.w  (a3)+,(a0)+
        dbra    d2,.w
        dbra    d0,.s
.z:     movem.l (sp)+,d0-d2/a0-a3
        rts

;-----------------------------------------------------------------------------
; maze_lists - (expand_bitmap) Ultimate's goal maze after its pictures in the store
; (a2): from the MP_ part of XH_MAZE (a3; a1 past its header) the cells' bitmap
; addresses, the map's picture per cell (also what each shows: the bitmap is the
; map's), the flag bytes and the flag cells' list, the states' lists
;-----------------------------------------------------------------------------
maze_lists:
.a0:    move.l  a2,G_MZOF(a6)           ; the cells' bitmap offsets: as addresses
        move.w  MP_N(a3),d7
        subq.w  #1,d7
.ad:    move.l  (a1)+,d0
        add.l   G_LIN(a6),d0
        move.l  d0,(a2)+
        dbra    d7,.ad
        move.l  a2,G_MZBA(a6)           ; the map's pictures (N words: picture x 32)
        move.w  MP_N(a3),d7
        subq.w  #1,d7
.b:     move.w  (a1)+,(a2)+
        dbra    d7,.b
        move.l  a2,G_MZCU(a6)           ; what each shows: the same
        move.w  MP_N(a3),d7
        add.w   d7,d7
        suba.w  d7,a1
        lsr.w   #1,d7
        subq.w  #1,d7
.u:     move.w  (a1)+,(a2)+
        dbra    d7,.u
        move.l  a2,G_MZFL(a6)           ; the flag bytes (N, even), then the flag
        move.w  MP_N(a3),d0             ; cells' list
        addq.w  #1,d0
        andi.w  #$FFFE,d0
        adda.w  d0,a2
        move.l  a2,G_MZFC(a6)
        suba.w  d0,a2
        move.w  MP_FB(a3),d7
        lsr.w   #1,d7
        subq.w  #1,d7
.f:     move.w  (a1)+,(a2)+
        dbra    d7,.f
        move.l  a2,G_MZLI(a6)           ; the 23 states' list offsets and the lists
        move.w  MP_LB(a3),d7
        lsr.w   #1,d7
        subq.w  #1,d7
.l:     move.w  (a1)+,(a2)+
        dbra    d7,.l
        move.w  MP_N(a3),G_MZN(a6)
        move.w  MP_FL0(a3),G_MZY0(a6)
        move.w  MP_FL1(a3),G_MZY1(a6)
        move.w  MP_FINIT(a3),G_MZFI(a6)
        move.w  #-1,G_MZLS(a6)          ; (none of the states' patches applied)
        move.w  #-1,G_MZRI(a6)
        clr.w   G_MZPD(a6)
        clr.w   G_MZEI(a6)
        clr.w   G_MZCT(a6)
        rts

; maze_play - at the race's play: the maze's cells under the goal flags get their
; pictures for the frame flag_build left the flags in
maze_play:
        tst.l   G_MZST(a6)
        beq.s   .o
        movem.l d0-d7/a0-a5,-(sp)
        move.w  G_MZFI(a6),d5
        bsr     maze_flags
        movem.l (sp)+,d0-d7/a0-a5
.o:     rts

; eb_pairword - d2 / d3 = the colours of even / odd pixels -> d0 = a Mode 8 word
eb_pairword:
        movem.l d1-d3/a0,-(sp)
        lea     pixpat(pc),a0
        lsl.w   #3,d2                   ; colour x 8 (4 words)
        lsl.w   #3,d3
        move.w  0(a0,d2.w),d0
        or.w    2(a0,d3.w),d0
        or.w    4(a0,d2.w),d0
        or.w    6(a0,d3.w),d0
        movem.l (sp)+,d1-d3/a0
        rts

; eb_state_i - d2.w = the tile state of cell (row d0, col d1): an override (the
; sorted list, consumed in order) or the row's. Uses d2; the locals at 4(sp).
eb_state_i:
        move.l  a0,-(sp)
        tst.w   8+EB_OVRN(sp)
        beq.s   .row
        movea.l 8+EB_OVR(sp),a0
        cmp.w   (a0),d0
        bne.s   .row
        cmp.b   2(a0),d1
        bne.s   .row
        moveq   #0,d2
        move.b  3(a0),d2
        addq.l  #4,8+EB_OVR(sp)
        subq.w  #1,8+EB_OVRN(sp)
        movea.l (sp)+,a0
        rts
.row:   movea.l 8+EB_RST(sp),a0
        moveq   #0,d2
        move.b  0(a0,d0.w),d2
        movea.l (sp)+,a0
        rts

; eb_state - a0 = the tile state of cell (row d0, col d1) (for the top lines;
; no override consumed). The locals at 4(sp).
eb_state:
        movea.l 4+EB_RST(sp),a0
        moveq   #0,d2
        move.b  0(a0,d0.w),d2
        mulu.w  #ST_BYTES,d2
        movea.l G_WORK(a6),a0
        adda.l  d2,a0
        rts

; eb_cell - a0 = the Mode 8 cell of (state d2, tile d3, palette d4), BUILT now
; into the next cache slot (the caller found none). First a table of the 64
; words a pixel can contribute: [line parity][value 0-3][x parity][position in
; the word]; then each line's 8 pixels, unrolled. The locals at 4(sp).
EC_TAB          equ     0               ; (locals of eb_cell: 128 B)
EC_SIZE         equ     128

eb_cell:
        movem.l d1-d7/a1-a4,-(sp)
        lea     -EC_SIZE(sp),sp
        ; the index entry -> slot + 1
        moveq   #0,d0
        move.w  d2,d0
        moveq   #11,d1
        lsl.l   d1,d0
        move.w  d3,d1
        lsl.w   #3,d1
        add.w   d4,d1
        add.w   d4,d1
        add.l   d1,d0
        movea.l EC_SIZE+48+EB_INDEX(sp),a1
        move.w  EC_SIZE+48+EB_NSLOT(sp),d1
        addq.w  #1,EC_SIZE+48+EB_NSLOT(sp)
        addq.w  #1,d1
        move.w  d1,0(a1,d0.l)
        subq.w  #1,d1
        moveq   #0,d5
        move.w  d1,d5
        lsl.l   #5,d5
        movea.l EC_SIZE+48+EB_SLOTS(sp),a2
        adda.l  d5,a2                   ; a2 = the cell
        move.w  d2,d0
        mulu.w  #ST_BYTES,d0
        movea.l G_WORK(a6),a3
        adda.l  d0,a3                   ; the state
        lea     8192(a3),a4             ; its palettes
        lsl.w   #4,d3
        adda.w  d3,a3                   ; a3 = the tile's planes
        ; the table: for py, v: source colour (v = 0: palette colour 0), xpar, p
        movea.l EC_SIZE+48+EB_CMAP(sp),a1
        lea     EC_TAB(sp),a0
        lsl.w   #2,d4                   ; palette x 4
        moveq   #0,d7                   ; py
.tpy:   moveq   #0,d6                   ; v
.tv:    moveq   #0,d0
        tst.w   d6
        beq.s   .tv0
        move.w  d6,d0
        add.w   d4,d0
.tv0:   moveq   #0,d1
        move.b  0(a4,d0.w),d1
        andi.w  #$3F,d1
        lsl.w   #2,d1                   ; source colour x 4
        add.w   d7,d1
        add.w   d7,d1                   ; + py x 2
        moveq   #0,d2                   ; x parity 0, then 1
.txp:   moveq   #0,d3
        move.b  0(a1,d1.w),d3           ; the QL colour
        lsl.w   #3,d3
        lea     pixpat(pc),a1
        move.l  0(a1,d3.w),(a0)+        ; p 0, 1
        move.l  4(a1,d3.w),(a0)+        ; p 2, 3
        movea.l EC_SIZE+48+EB_CMAP(sp),a1
        addq.w  #1,d1
        addq.w  #1,d2
        cmpi.w  #2,d2
        blo.s   .txp
        addq.w  #1,d6
        cmpi.w  #4,d6
        blo.s   .tv
        addq.w  #1,d7
        cmpi.w  #2,d7
        blo.s   .tpy
        ; the 8 lines: word index (v x 16 + xpar x 8 + p x 2) in this line parity's
        ; 64 bytes; pixel x: xpar = x & 1, p = x & 3
        moveq   #0,d7                   ; y
.ly:    lea     EC_TAB(sp),a0
        btst    #0,d7
        beq.s   .even
        lea     64(a0),a0
.even:  move.b  (a3,d7.w),d2            ; plane 0
        move.b  8(a3,d7.w),d3           ; plane 1
        moveq   #0,d5                   ; the two words
        moveq   #0,d6
        moveq   #0,d0                   ; (the unrolled pixels, with their offsets)
        add.b   d3,d3                   ; - x 0: p 0, xpar 0 -> word 0
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    0(a0,d0.w),d5
        moveq   #0,d0                   ; x 1: p 1, xpar 1
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    8+2(a0,d0.w),d5
        moveq   #0,d0                   ; x 2: p 2, xpar 0
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    4(a0,d0.w),d5
        moveq   #0,d0                   ; x 3: p 3, xpar 1
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    8+6(a0,d0.w),d5
        moveq   #0,d0                   ; x 4: p 0, xpar 0 -> word 1
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    0(a0,d0.w),d6
        moveq   #0,d0                   ; x 5
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    8+2(a0,d0.w),d6
        moveq   #0,d0                   ; x 6
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    4(a0,d0.w),d6
        moveq   #0,d0                   ; x 7
        add.b   d3,d3
        addx.b  d0,d0
        add.b   d2,d2
        addx.b  d0,d0
        lsl.w   #4,d0
        or.w    8+6(a0,d0.w),d6
        move.w  d5,(a2)+
        move.w  d6,(a2)+
        addq.w  #1,d7
        cmpi.w  #8,d7
        blo     .ly
        lea     -32(a2),a0              ; the cell just built
        lea     EC_SIZE(sp),sp
        movem.l (sp)+,d1-d7/a1-a4
        rts

; eb_sprites - the sprite list, last to first: the entries tagged G_SPTAG (0: the
; map's; 1 + 4k + v: goal flag k's wave frame v, flag_build). a5 = the BUILD blob.
eb_sprites:
        movem.l a0-a2,-(sp)             ; (a0 the count, a1 yy, a2 xx: eb_plot and
        move.l  XH_SPRITES(a5),d0       ;  eb_bgpix keep them; d6 / d7 = X / Y)
        lea     0(a5,d0.l),a3
        move.w  (a3)+,d0                ; n
        movea.w d0,a0
        lsl.w   #3,d0
        adda.w  d0,a3                   ; past the last
.spr:   move.w  a0,d0
        subq.w  #1,d0
        bmi     .out
        movea.w d0,a0
        subq.l  #8,a3
        move.b  3(a3),d0
        cmp.b   G_SPTAG+1(a6),d0
        bne.s   .spr
        moveq   #0,d0
        move.b  (a3),d0                 ; state
        mulu.w  #ST_BYTES,d0
        movea.l G_WORK(a6),a4
        adda.l  d0,a4                   ; a4 = the state
        moveq   #0,d5
        move.b  2(a3),d5                ; tile
        lsl.w   #4,d5
        suba.l  a1,a1                   ; yy
.yy:    move.w  a1,d0
        btst    #7,1(a3)                ; v flip
        beq.s   .nv
        moveq   #7,d0
        sub.w   a1,d0
.nv:    add.w   d5,d0
        addi.w  #4096,d0
        move.b  0(a4,d0.w),d1           ; plane 0 of the sprite tile row
        move.b  8(a4,d0.w),d2           ; plane 1
        move.w  6(a3),d7
        add.w   a1,d7                   ; Y = y + yy
        bmi     .nrow                   ; (a row off the map: none of it drawn)
        move.w  XH_ROWS(a5),d0
        lsl.w   #3,d0
        cmp.w   d0,d7
        bhs     .nrow
        suba.l  a2,a2                   ; xx
.xx:    moveq   #7,d0
        sub.w   a2,d0                   ; bit 7 - tx
        btst    #6,1(a3)                ; h flip
        beq.s   .nh
        move.w  a2,d0
.nh:    moveq   #0,d3
        btst    d0,d1
        beq.s   .p0
        moveq   #1,d3
.p0:    btst    d0,d2
        beq.s   .p1
        addq.w  #2,d3
.p1:    tst.w   d3
        beq.s   .nx                     ; transparent
        move.w  4(a3),d6
        add.w   a2,d6                   ; X
        cmpi.w  #255,d6
        bhi.s   .nx
        ; the colour: behind the BG and the BG not 0 there -> the BG's, else ours
        btst    #5,1(a3)
        beq.s   .ours
        move.w  d1,d4
        bsr     eb_bgpix                ; d0 = BG source colour, d1 = its value
        exg     d1,d4                   ; (plane 0 back)
        tst.w   d4
        bne.s   .put
.ours:  moveq   #3,d0
        and.b   1(a3),d0
        lsl.w   #2,d0
        add.w   d3,d0
        tst.l   G_GSCH(a6)              ; (the GOAL text: palette x 4 + value indexes
        bne.s   .put                    ;  its own colour table, eb_plot)
        addi.w  #8192+16,d0
        move.b  0(a4,d0.w),d0
        andi.w  #$3F,d0
.put:   bsr     eb_plot                 ; source colour d0 at (d6, d7)
.nx:    addq.w  #1,a2
        cmpa.w  #8,a2
        blo.s   .xx
.nrow:  addq.w  #1,a1
        cmpa.w  #8,a1
        blo     .yy
        bra     .spr
.out:   movem.l (sp)+,a0-a2
        rts

; eb_bgpix - the background at map pixel (X d6, Y d7): d0 = source colour, d1 = the
; tile's value (0-3). The expand_bitmap locals are deeper on the stack: this
; uses the race blob (a5) directly instead.
eb_bgpix:
        movem.l d2-d7/a0-a2,-(sp)
        move.w  d7,d0
        lsr.w   #3,d0                   ; row
        move.w  d6,d1
        lsr.w   #3,d1                   ; col
        bsr     eb_cellstate            ; d2 = the cell's state
        mulu.w  #ST_BYTES,d2
        movea.l G_WORK(a6),a2
        adda.l  d2,a2
        move.w  d0,d3
        lsl.w   #5,d3
        add.w   d1,d3                   ; row x 32 + col
        move.l  XH_MAP(a5),d4
        lea     0(a5,d4.l),a0
        moveq   #0,d4
        move.b  0(a0,d3.w),d4           ; tile
        move.l  XH_ATTR(a5),d5
        lea     0(a5,d5.l),a0
        moveq   #0,d5
        move.b  0(a0,d3.w),d5           ; palette
        lsl.w   #4,d4
        moveq   #7,d3
        and.w   d7,d3
        add.w   d3,d4
        move.b  0(a2,d4.w),d2           ; plane 0
        move.b  8(a2,d4.w),d3           ; plane 1
        moveq   #7,d0
        and.w   d6,d0
        eori.w  #7,d0                   ; bit 7 - (X & 7)
        moveq   #0,d1
        btst    d0,d2
        beq.s   .b0
        moveq   #1,d1
.b0:    btst    d0,d3
        beq.s   .b1
        addq.w  #2,d1
.b1:    moveq   #0,d0
        tst.w   d1
        beq.s   .c0
        lsl.w   #2,d5
        move.w  d1,d0
        add.w   d5,d0
.c0:    addi.w  #8192,d0
        move.b  0(a2,d0.w),d0
        andi.w  #$3F,d0
        movem.l (sp)+,d2-d7/a0-a2
        rts

; eb_cellstate - d2 = the state of cell (row d0, col d1): an override (searched
; in the list) or the row's
eb_cellstate:
        movem.l d3/a0,-(sp)
        move.l  XH_OVR(a5),d2
        lea     0(a5,d2.l),a0
        move.w  (a0)+,d3
        bra.s   .n
.l:     cmp.w   (a0),d0
        bne.s   .x
        cmp.b   2(a0),d1
        bne.s   .x
        moveq   #0,d2
        move.b  3(a0),d2
        movem.l (sp)+,d3/a0
        rts
.x:     addq.l  #4,a0
.n:     dbra    d3,.l
        move.l  XH_RSTATE(a5),d2
        lea     0(a5,d2.l),a0
        moveq   #0,d2
        move.b  0(a0,d0.w),d2
        movem.l (sp)+,d3/a0
        rts

; eb_plot - source colour d0 (0-$3F) at map pixel (X d6, Y d7) into the bitmap (the race's
; colour map, the dither parity of the bitmap line LIN_TOP + Y)
eb_plot:
        movem.l d0-d3/a0-a1,-(sp)
        move.l  G_GSCH(a6),d1           ; (the GOAL text's colour table: d0 = palette
        bne.s   .sch                    ;  x 4 + value, the same layout as the map's)
        move.l  XH_COLMAP(a5),d1
        lea     0(a5,d1.l),a0
        bra.s   .cm
.sch:   movea.l d1,a0
.cm:
        lsl.w   #2,d0
        moveq   #1,d1
        and.w   d7,d1                   ; (LIN_TOP even: the same parity)
        add.w   d1,d1
        add.w   d1,d0
        moveq   #1,d1
        and.w   d6,d1
        add.w   d1,d0
        moveq   #0,d2
        move.b  0(a0,d0.w),d2           ; QL colour
        lsl.w   #2,d2
        moveq   #3,d1
        and.w   d6,d1
        add.w   d1,d2
        add.w   d2,d2
        lea     pixpat(pc),a0
        move.w  0(a0,d2.w),d2           ; the pixel's bits
        add.w   d1,d1
        lea     pixmask(pc),a0
        move.w  0(a0,d1.w),d3
        not.w   d3
        moveq   #0,d0
        move.w  d7,d0
        addi.w  #LIN_TOP,d0
        lsl.l   #7,d0                   ; x BPL
        movea.l G_LIN(a6),a1
        adda.l  d0,a1
        move.w  d6,d0
        lsr.w   #2,d0
        add.w   d0,d0
        adda.w  d0,a1
        and.w   d3,(a1)
        or.w    d2,(a1)
        movem.l (sp)+,d0-d3/a0-a1
        rts
