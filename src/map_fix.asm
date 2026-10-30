; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; map_fix - (load_race, at the load, after flag_build) the map's own colour
; fixes (XH_MFIX): Mode 8 words over the bitmap, in runs: word n, n x (word
; bitmap line, byte byte in the line (even), byte words, the words). a5 = the
; race's BUILD blob. Never over a box another part rewrites (the build leaves
; those out: sprites, the flags, the animated cells, the maze, the water, the
; pistons), so nothing later puts the plain pixels back. No frame time.
; Assembled only when the data has map fixes (MAP_FIX, data/map_fix_on.inc:
; without them the program is byte-identical). Placed after mobj.asm, out of
; the frame code's way (a PC-relative far call, as anim_afix).
;=============================================================================
map_fix:
        movem.l d0-d2/a0-a1,-(sp)
        move.l  XH_MFIX(a5),d0
        beq.s   .out
        lea     0(a5,d0.l),a0
        move.w  (a0)+,d2                ; runs
        bra.s   .rn
.r:     moveq   #0,d0
        move.w  (a0)+,d0                ; the bitmap line
        lsl.l   #7,d0                   ; x BPL
        moveq   #0,d1
        move.b  (a0)+,d1                ; the byte in the line
        add.l   d1,d0
        movea.l G_LIN(a6),a1
        adda.l  d0,a1
        moveq   #0,d1
        move.b  (a0)+,d1                ; words (1-64)
        bra.s   .wn
.w:     move.w  (a0)+,(a1)+
.wn:    dbra    d1,.w
.rn:    dbra    d2,.r
.out:   movem.l (sp)+,d0-d2/a0-a1
        rts
