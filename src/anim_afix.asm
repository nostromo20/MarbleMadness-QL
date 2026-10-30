; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; anim_afix - (expand_bitmap, at the load) an animated group's own pixels in
; their own colours (XH_AFIX: Aerial's
; catapult): the listed Mode 8 words over
; each variant's store, and over the bitmap's box for the variant the bitmap
; starts with. a5 = the race blob, G_ANG filled. Not in the frame code: placed
; after mobj.asm so that nothing in the frame code moves out of bsr reach.
;=============================================================================
anim_afix:
        movem.l d0-d7/a0-a4,-(sp)
        move.l  XH_AFIX(a5),d0
        lea     0(a5,d0.l),a0
        move.w  (a0)+,d7                ; groups
        lea     G_ANG(a6),a4
        bra.s   .gn
.g:     move.w  (a0)+,d6                ; its variants (0: nothing for it)
        move.w  (a0)+,d5                ; the bitmap's variant (-1 none)
        movea.l AN_STORE(a4),a2
        moveq   #0,d4                   ; variant
        bra.s   .vn
.v:     move.w  (a0)+,d3                ; words
        bra.s   .wn
.w:     moveq   #0,d0
        move.b  (a0)+,d0                ; line in the box
        moveq   #0,d1
        move.b  (a0)+,d1                ; byte in the line
        move.w  (a0)+,d2                ; the word
        cmp.w   d4,d5
        bne.s   .s
        move.l  d0,-(sp)
        mulu.w  #BPL,d0
        add.l   d1,d0
        movea.l AN_LIN(a4),a1
        move.w  d2,0(a1,d0.l)           ; (the bitmap's box)
        move.l  (sp)+,d0
.s:     mulu.w  AN_LB(a4),d0
        add.l   d1,d0
        move.w  d2,0(a2,d0.l)           ; (the variant)
.wn:    dbra    d3,.w
        adda.w  AN_VB(a4),a2
        addq.w  #1,d4
.vn:    cmp.w   d6,d4
        blo.s   .v
        lea     AN_SIZE(a4),a4
.gn:    dbra    d7,.g
        movem.l (sp)+,d0-d7/a0-a4
        rts
