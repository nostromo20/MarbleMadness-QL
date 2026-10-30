; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; mlogic.asm - Marble Madness QL: the marble's logic, one logic step per call.
;
; The course comes from precomputed tables (the geo blob) instead of a walk
; over the course's shells, the slope pushes come from op lists, and positions
; are 32-bit longs.
;
; marble_frame runs one 60 Hz logic step; the QL calls it 6 times per 10 fps
; frame (logic_qlframe). Registers on entry: a6 = globals, a4 = marble block
; (M_* fields), G_PGEO(a6) = geo blob. Uses d0-d7/a0-a3/a5, preserves a4/a6.
;
; Units: positions 24-bit (hi:lo.frac, as a long $00HHLLFF),
; velocities sign + magnitude 8.8 (word) with the sign in the low byte of a
; separate word, depth Z with $8000 = 0. Byte-wide variables live in the
; LOW byte of a word field (accessed as FIELD+1 with .b) and the high byte
; stays 0, so word compares work too.
;=============================================================================

;=============================================================================
; marble_frame - one logic step of everything that touches player 1's marble:
; the state handler, the camera, its screen y and the behind-scenery kill
; check.
;=============================================================================
marble_frame:
        addq.b  #1,M_FC+1(a4)
        tst.w   M_ZCD(a4)               ; each step: Intermediate's zone-2 load
        beq.s   .nz                     ; ends -> the waves start (M_F9B = 0,
        subq.w  #1,M_ZCD(a4)            ; M_FBB = 0)
        bne.s   .nz
        clr.w   M_F9B(a4)
        clr.w   M_FBB(a4)
.nz:
        clr.w   M_DRAWN(a4)
        bsr     freeze_event            ; (the main loop's, before the objects)
        bsr     objects_pre             ; slots 7-2 (src/mobj.asm)
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_ROLL,d0
        bne     .n1
        bsr     st_roll
        bra     .after
.n1:    cmpi.w  #ST_BROKEN,d0
        bne     .n7
        bsr     st_broken
        bra     .after
.n7:    cmpi.w  #ST_SINK,d0
        bne     .n8
        bsr     st_sink
        bra     .after
.n8:    cmpi.w  #ST_DEAD,d0
        bne     .n9
        bsr     st_dead
        bra     .after
.n9:    cmpi.w  #ST_WAIT,d0
        bne     .n26
        bsr     st_wait
        bra     .after
.n26:   cmpi.w  #ST_CARRIED,d0          ; carried off by a bird (src/mobj.asm)
        bne     .n11
        bsr     st_carried
        bra     .after
.n11:   cmpi.w  #ST_OFFTOP,d0
        bne     .n1e
        bsr     st_offtop
        bra     .after
.n1e:   cmpi.w  #ST_FUNNEL,d0
        bne     .n1b
        bsr     st_funnel
        bra     .after
.n1b:   cmpi.w  #ST_FUNNEL2,d0
        bne     .n0c
        bsr     st_funnel2
        bra     .after
.n0c:   cmpi.w  #ST_INACID,d0           ; in an acid pool (src/mobj.asm)
        bne     .n2a
        bsr     st_inacid
        bra     .after
.n2a:   cmpi.w  #ST_INVAC,d0            ; caught by a vacuum (src/mobj.asm)
        bne     .after
        bsr     st_invac
.after: tst.b   M_F5CB+1(a4)            ; no camera while frozen
        bne.s   .cdone
        bsr     camera
.cdone: ; screen y of a drawn marble: S = (X+Y)/2 + Z - (scroll - $C0)
        tst.w   M_DRAWN(a4)
        bne.s   .scr
        bsr     kill_check
        bsr     f7ed_timer
        bra     objects_post
.scr:   move.l  M_X(a4),d0
        add.l   M_Y(a4),d0
        lsr.l   #8,d0
        lsr.w   #1,d0                   ; (the carry out of bit 15 drops)
        move.l  M_Z(a4),d1
        lsr.l   #8,d1
        add.w   d1,d0
        sub.w   M_SCROLL(a4),d0
        addi.w  #$C0,d0
        move.w  d0,M_S(a4)
        btst    #0,M_FC+1(a4)           ; the fragments (state $0B / $26, frame id $30): on
        bne.s   .nf                     ; the frames with (frame & 1) = 0 the drawer
        move.w  M_STATE(a4),d0          ; runs: its inputs kept for draw_marble
        cmpi.w  #ST_WAIT,d0
        beq.s   .fr
        cmpi.w  #ST_CARRIED,d0
        bne.s   .nf
.fr:    bsr     marble_sx
        move.w  d0,M_FRAX(a4)
        moveq   #0,d0
        move.b  M_S+1(a4),d0
        move.w  d0,M_FRAY(a4)
        move.w  M_T400(a4),M_FRT(a4)
        move.w  M_VXS(a4),M_FRM(a4)
        move.w  M_VYS(a4),M_FRR(a4)
        move.w  #1,M_FRON(a4)
.nf:    bsr     kill_check
        bsr     f7ed_timer
        bra     objects_post

; marble_sx - d0.w = M_SX, the marble's screen x: (X - Y) + $80, its low byte
; (with the fraction's borrow). a4 = the marble block.
marble_sx:
        move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        lsr.w   #8,d0
        addi.b  #$80,d0
        andi.w  #$FF,d0
        rts

;-----------------------------------------------------------------------------
; motion core
;-----------------------------------------------------------------------------
; grow - magnitude at (a0) += d1.w, then the speed cap: once the integer part
; is non-zero, |v| <= 1.0 when M_E2 and not M_FB, else the fraction <= $7F.
grow:
        move.w  (a0),d0
        add.w   d1,d0
        cmpi.w  #$FF,d0
        bls     .st
        tst.b   M_SLOT+1(a4)            ; an object: the fraction cleared
        bne.s   .c10
        tst.b   M_E2+1(a4)
        beq     .c7f
        tst.b   M_FB+1(a4)
        bne     .c7f
.c10:   clr.b   d0                      ; cap 1.0
        bra     .st
.c7f:   tst.b   d0
        bpl     .st
        move.b  #$7F,d0                 ; cap 1.$7F
.st:    move.w  d0,(a0)
        rts

; accel_pos / accel_neg - d1.w towards + / - on the axis whose magnitude is at
; (a0) and sign word at (a1). Growing adds; braking subtracts and, crossing
; zero, flips the sign and leaves the velocity at exactly 0.
accel_pos:
        tst.b   1(a1)
        beq     grow
        bra     shrink
accel_neg:
        tst.b   1(a1)
        bne     grow
shrink: move.w  (a0),d0
        sub.w   d1,d0
        bcc     .st
        eori.b  #1,1(a1)
        moveq   #0,d0
.st:    move.w  d0,(a0)
        rts

; damp - magnitude at (a0) -= d1.w, floored at 0, sign kept
damp:   move.w  (a0),d0
        sub.w   d1,d0
        bcc     .st
        moveq   #0,d0
.st:    move.w  d0,(a0)
        rts

; gravity - d1.w towards "down" on vz; vz >= 3.0 clears the fraction
gravity:
        lea     M_VZ(a4),a0
        tst.b   M_VZS+1(a4)
        beq     .down
        lea     M_VZS(a4),a1
        bra     shrink
.down:  move.w  (a0),d0
        add.w   d1,d0
        cmpi.w  #$300,d0
        blo     .st
        clr.b   d0
.st:    move.w  d0,(a0)
        rts

; integrate - Z, then X and Y. X/Y moving negative clamp at 0
; when the high byte goes negative.
integrate:
        moveq   #0,d0
        move.w  M_VZ(a4),d0
        tst.b   M_VZS+1(a4)
        bne     .zup
        add.l   d0,M_Z(a4)
        bra     integrate_xy
.zup:   sub.l   d0,M_Z(a4)
integrate_xy:
        moveq   #0,d0
        move.w  M_VX(a4),d0
        move.l  M_X(a4),d1
        tst.b   M_VXS+1(a4)
        bne     .xn
        add.l   d0,d1
        bra     .xs
.xn:    sub.l   d0,d1
        bmi     .x0
        btst    #23,d1
        beq     .xs
.x0:    moveq   #0,d1
.xs:    move.l  d1,M_X(a4)
        move.w  M_VY(a4),d0
        move.l  M_Y(a4),d1
        tst.b   M_VYS+1(a4)
        bne     .yn
        add.l   d0,d1
        bra     .ys
.yn:    sub.l   d0,d1
        bmi     .y0
        btst    #23,d1
        beq     .ys
.y0:    moveq   #0,d1
.ys:    move.l  d1,M_Y(a4)
        rts

; helpers of the generated slope code (data/proto_slope.inc)
; slope_goal / slope_goalx - the goal line, d1 = 1 for the entry that damps vy by 8 first
slope_goal:
        tst.w   d1
        beq.s   .g1
        lea     M_VY(a4),a0
        moveq   #8,d1
        bsr     damp
.g1:    tst.b   M_VYS+1(a4)
        beq.s   .g2
        subq.b  #1,M_VYS+1(a4)
.g2:    lea     M_VY(a4),a0
        moveq   #3,d1
        bsr     damp
        tst.b   M_RACING+1(a4)
        beq.s   .o
        subq.b  #1,M_RACING+1(a4)
        move.b  #1,M_VY(a4)             ; integer byte = 1, fraction kept
        bset    #EV_GOAL,M_EVENTS+1(a4)
        bsr     goal_pts                ; the race's points (time_event)
        move.w  #2,G_WR95(a6)           ; G_WR95 = 2 | player (the static objects'
        move.w  M_FC(a4),G_FC95(a6)     ;  palette from now on), and in which frame
.o:     rts
slope_goalx:
        tst.w   d1
        beq.s   .x1
        lea     M_VY(a4),a0
        moveq   #8,d1
        bsr     damp
.x1:    tst.b   M_VXS+1(a4)
        beq.s   .x2
        subq.b  #1,M_VXS+1(a4)
.x2:    lea     M_VX(a4),a0
        moveq   #3,d1
        bsr     damp
        tst.b   M_RACING+1(a4)
        beq.s   .o
        subq.b  #1,M_RACING+1(a4)
        move.w  #$140,M_VX(a4)
        bset    #EV_GOAL,M_EVENTS+1(a4)
        bsr     goal_pts                ; the race's points (time_event)
        move.w  #2,G_WR95(a6)           ; G_WR95 = 2 | player (the static objects'
        move.w  M_FC(a4),G_FC95(a6)     ;  palette from now on), and in which frame
.o:     rts
; slope_pad - landing pads $32-$35, d1 = their time_event number (2-5): points
slope_pad:
        tst.b   M_GND+1(a4)
        bne.s   .o
        tst.b   M_EC+1(a4)
        bne.s   .o
        clr.w   M_AIR(a4)
        addq.b  #1,M_EC+1(a4)
        movem.l d0-d2/a0,-(sp)
        move.w  d1,d0
        bsr     time_event
        movem.l (sp)+,d0-d2/a0
.o:     rts

; goal_pts - the goal: time_event with d0 = the race ((race + 1) x 1,000 points)
goal_pts:
        movem.l d0-d2/a0,-(sp)
        move.w  G_RACE(a6),d0
        bsr     time_event
        movem.l (sp)+,d0-d2/a0
        rts

        include "proto_slope.inc"

; the ridges' lift by Y & 7 (the generated slope code of code $3D reads it)
slope_fdtab:
        dc.b    0,1,2,3,0,0,1,2

;-----------------------------------------------------------------------------
; geo_cell - the course under the marble.
; Out: d0 = 0 found / -1 beyond the race's shells; when found:
;      d2.w = surface depth D, or -1 (bit 16 set) when the shape says "no
;      surface" (d3.b = GEO_NONE); d4.b = cell code, d5.b = push byte
;      (bits 0-6 slope code, bit 7 = M_BC cleared), d6.b = link, d7.b = the
;      shape's steer byte (GEO_SHCODE +1).
; Side effects: M_BC = 1 (then 0 if the shape clears it).
;-----------------------------------------------------------------------------
GEO_CELL macro
        move.w  #1,M_F5CE(a4)
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; the player only
        bne.s   .g0
        endc
        move.w  #1,M_BC(a4)
        clr.w   M_FD(a4)                ; the ridges' lift (code $3D's push sets it)
        move.w  #$FF,M_CF(a4)           ; (M_CF: a piston cell sets it)
        move.w  M_F6(a4),M_F8(a4)       ; M_F8 = M_F6, M_F6 = 1
        move.w  #1,M_F6(a4)
.g0:    movea.l G_PGEO(a6),a5
        ifeq    \1
        move.l  M_X(a4),d0
        lsr.l   #8,d0                   ; X (16-bit integer part)
        move.l  M_Y(a4),d1
        lsr.l   #8,d1
        endc
        move.w  d0,d2
        lsr.w   #3,d2
        andi.w  #$FF,d2                 ; tx
        move.w  d1,d3
        lsr.w   #3,d3
        andi.w  #$FF,d3                 ; ty
        move.w  GEO_LIMIT(a5),d4
        cmp.w   d4,d2
        bhs     .off
        cmp.w   d4,d3
        bhs     .off
        move.w  d3,d4                   ; the same cell as last time: its values
        lsl.w   #8,d4                   ; from the block's cache
        or.w    d2,d4
        addq.w  #1,d4
        cmp.w   M_GCKEY(a4),d4
        bne.s   .miss
        moveq   #0,d2
        move.w  M_GCBASE(a4),d2
        move.w  M_GCKD1(a4),M_KD1(a4)
        move.w  M_GCLINK(a4),d6
        move.w  M_GCCODE(a4),d4
        move.w  M_GCSHP(a4),d3          ; a static code: its shape and steer byte cached
        bmi.s   .hdyn
        move.w  M_GCE6(a4),d7
        moveq   #0,d5                   ; (as .dyn leaves it)
        lea     GEO_SHAPES(a5),a1
        adda.w  d3,a1
        bra     .frac
.hdyn:  move.w  M_GCALT(a4),d7
        move.w  M_GCSH(a4),d3
        lea     GEO_SHCODE(a5),a1
        bra     .dyn
.miss:  move.w  d4,M_GCKEY(a4)
        ; GEO2 rows are trimmed (GEO_RB: x0, x1, left/right kind, left/right
        ; base): outside [x0, x1) a cell is the row's left / right default
        move.w  d3,d4
        lsl.w   #3,d4
        lea     GEO_RB(a5),a0
        adda.w  d4,a0
        moveq   #0,d6
        cmp.b   (a0),d2
        blo.s   .left
        cmp.b   1(a0),d2
        bhs.s   .right
        add.w   d3,d3
        add.w   d3,d3
        move.l  GEO_ROWS(a5,d3.w),d3    ; the row's cell 0 (index, signed)
        ext.l   d2
        add.l   d2,d3                   ; + tx
        movea.l a5,a0
        adda.l  GEO_KOFF(a5),a0
        move.b  0(a0,d3.l),d6           ; the cell's kind
        lea     GEO_BASE(a5),a0
        add.l   d3,d3
        moveq   #0,d2
        move.w  0(a0,d3.l),d2           ; base depth
        bra.s   .kd
.left:  move.b  2(a0),d6
        moveq   #0,d2
        move.w  4(a0),d2
        bra.s   .kd
.right: move.b  3(a0),d6
        moveq   #0,d2
        move.w  6(a0),d2
.kd:
        lea     GEO_KD1(a5),a1
        move.b  0(a1,d6.w),M_KD1+1(a4)  ; Ultimate's maze floor (bit 7: none)
        lea     GEO_KPIST(a5),a1
        clr.b   M_GCPIST(a4)
        move.b  0(a1,d6.w),M_GCPIST+1(a4)   ; Aerial's piston number ($FF none)
        lea     GEO_KALT(a5),a1
        moveq   #0,d7
        move.b  0(a1,d6.w),d7           ; the kind's other shape (dynamic cells)
        lea     GEO_KINDS(a5),a0
        add.w   d6,d6
        moveq   #0,d3
        move.b  0(a0,d6.w),d3           ; shape
        move.b  1(a0,d6.w),d6           ; link
        lea     GEO_SHCODE(a5),a1
        add.w   d3,d3
        moveq   #0,d4
        move.b  0(a1,d3.w),d4           ; cell code (the same for both shapes)
        move.w  d2,M_GCBASE(a4)         ; (into the cache)
        move.w  M_KD1(a4),M_GCKD1(a4)
        move.w  d7,M_GCALT(a4)
        move.w  d3,M_GCSH(a4)
        andi.w  #$FF,d6
        move.w  d6,M_GCLINK(a4)
        move.w  d4,M_GCCODE(a4)
        moveq   #$7F,d5                 ; (the codes .dyn reads race state for:
        and.b   d4,d5                   ;  never a cached shape)
        subi.b  #$11,d5
        cmpi.b  #2,d5
        bls.s   .cdyn
        moveq   #0,d5
        move.b  1(a1,d3.w),d5
        move.w  d5,M_GCE6(a4)
        move.w  d3,d5
        lsl.w   #6,d5
        move.w  d5,M_GCSHP(a4)
        bra.s   .dyn
.cdyn:  move.w  #-1,M_GCSHP(a4)
.dyn:
        ; some cells read race state: code $12 and $11 on its usual
        ; path clear M_F6; $11 takes its other path when M_F9D bit 6 and M_F8
        ; are set; $13 when M_F9D = 0 and Z low = $70 (then M_E4 = 0, M_F9D = 1)
        moveq   #$7F,d5
        and.b   d4,d5
        cmpi.b  #$12,d5
        beq.s   .f6z
        cmpi.b  #$11,d5
        bne.s   .c13
        btst    #6,M_F9D+1(a4)
        beq.s   .f6z
        tst.b   M_F8+1(a4)
        beq.s   .f6z
        bra.s   .alt
.c13:   cmpi.b  #$13,d5
        bne.s   .stat
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; (an object there: not modelled)
        bne.s   .stat
        endc
        tst.b   M_F9D+1(a4)
        bne.s   .stat
        cmpi.b  #$70,M_Z+2(a4)
        bne.s   .stat
        clr.w   M_E4(a4)
        move.w  #1,M_F9D(a4)
.alt:   cmpi.b  #$FF,d7
        beq.s   .stat
        move.w  d7,d3
        add.w   d3,d3
        bra.s   .stat
.f6z:
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; the player only
        bne.s   .stat
        endc
        clr.w   M_F6(a4)
.stat:  move.b  1(a1,d3.w),d7           ; steer byte
        lsl.w   #6,d3                   ; shape * 128
        lea     GEO_SHAPES(a5),a1
        adda.w  d3,a1
.frac:  andi.w  #7,d1
        lsl.w   #3,d1
        andi.w  #7,d0
        add.w   d0,d1                   ; fraction index (Y&7)*8 + (X&7)
        move.b  64(a1,d1.w),d5          ; push byte (GEO2: bit 7 = M_BC cleared)
        btst    #7,d5
        beq     .bc
        ifeq    \1
        tst.b   M_SLOT+1(a4)
        bne     .bc
        endc
        clr.w   M_BC(a4)
.bc:    moveq   #0,d3
        move.b  0(a1,d1.w),d3           ; offset
        cmpi.b  #GEO_NONE,d3
        beq     .none
        sub.w   d3,d2                   ; D = base - offset
        tst.b   M_GCPIST+1(a4)          ; an Aerial piston cell, for the
        bmi.s   .r                      ; player on the ground (M_GND) and not a depth-only
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; lookup (M_NOE9): D - .ph[G_WP6D7[n]], M_CF = n
        bne.s   .r
        endc
        tst.b   M_GND+1(a4)
        beq.s   .r
        tst.w   M_NOE9(a4)
        bne.s   .r
        moveq   #0,d3
        move.b  M_GCPIST+1(a4),d3
        move.w  d3,M_CF(a4)
        lea     G_WP6D7(a6),a1
        move.b  0(a1,d3.w),d3
        andi.w  #$0F,d3
        move.b  .ph(pc,d3.w),d3
        sub.w   d3,d2
.r:     moveq   #0,d0
        rts
.none:  moveq   #-1,d2
        moveq   #0,d0
        rts
.off:   moveq   #-1,d0
        rts
.ph:    dc.b    $00,$04,$08,$0C,$10,$14,$18,$18,$18,$18,$18,$14,$10,$0C,$08,$04   ; lift by phase
        endm

geo_cell:
        GEO_CELL 0
; geo_cell_p - the player's copy (surface_p): a4 = G_MB, d0.w / d1.w = X / Y
; integer parts on entry; the slot tests left out
geo_cell_p:
        GEO_CELL 1

; slope_k - slope (d0 = the code): the marble once; an object twice (30 Hz: a run is
; two logic steps, each with its push)
slope_k:
        tst.b   M_SLOT+1(a4)
        beq     slope
        move.w  d0,-(sp)
        bsr     slope
        move.w  (sp)+,d0
        bra     slope

;-----------------------------------------------------------------------------
; surface - the lookup and its consequences
; Out: d0 = 0 on a surface (after its slope push), 1 in the air.
;-----------------------------------------------------------------------------
SURFACE macro
        move.w  #$FF,M_CODE(a4)
        move.w  #1,M_F5CE(a4)
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; (objects: not the off-screen test)
        bne     .look
        endc
        ; racing, airborne and below the screen bottom: dead
        tst.b   M_RACING+1(a4)
        beq     .look
        tst.b   M_GND+1(a4)
        bne     .look
        cmpi.b  #$81,M_S(a4)
        blo     .look
        move.w  #1,M_BC(a4)
        move.w  #ST_DEAD,M_STATE(a4)
        bset    #EV_OFF-8,M_EVENTS(a4)
        moveq   #1,d0
        rts
.look:
        ifeq    \1
        bsr     geo_cell
        else
        bsr     geo_cell_p
        endc
        tst.w   d0
        beq     .on
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; an object: just in the air
        bne     .air
        endc
        move.w  #ST_DEAD,M_STATE(a4)    ; beyond the shells
        bset    #EV_OFF-8,M_EVENTS(a4)
        moveq   #1,d0
        rts
.on:
        ifeq    \1
        cmpi.w  #4,M_SLOT(a4)           ; slot 4's M_E2 is this lookup's steer byte
        bne.s   .n4
        moveq   #0,d0
        move.b  d7,d0
        move.w  d0,M_E2(a4)
        endc
.n4:    btst    #16,d2                  ; no surface in this shape
        bne     .air
        move.l  M_Z(a4),d0
        lsr.l   #8,d0                   ; Z integer part (16-bit)
        move.w  d2,d1
        sub.w   d0,d1                   ; dz = D - Z
        bpl     .air                    ; at or above the surface: airborne
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; the player only
        bne.s   .e2
        endc
        moveq   #0,d0
        move.b  d7,d0
        move.w  d0,M_E2(a4)             ; M_E2 = the steer byte (marble below the surface)
.e2:
        move.w  d1,d0
        lsr.w   #8,d0
        cmpi.b  #$FF,d0
        bne     .deep
        cmp.b   M_DD+1(a4),d1
        blo     .deep
        moveq   #0,d0
        move.b  d4,d0
        move.w  d0,M_CODE(a4)
        tst.b   d4
        bmi     .air                    ; no floor: falls through
        tst.b   M_KD1+1(a4)             ; a maze-floor cell, its window open
        bmi.s   .nomz
        moveq   #0,d0
        move.b  M_KD1+1(a4),d0
        bsr     maze_open
        moveq   #1,d3                   ; (not a wall)
        tst.w   d0
        bne     .f54
.nomz:  moveq   #0,d0
        move.w  d2,d0
        lsl.l   #8,d0
        move.l  d0,M_Z(a4)              ; snap: Z = D, fraction 0
        tst.b   M_GND+1(a4)
        beq     .nolink
        tst.b   d6
        bmi     .nolink
        moveq   #0,d0
        move.b  d6,d0
        move.w  d0,M_CKPT(a4)           ; the respawn point follows the course
.nolink:
        moveq   #$7F,d0
        and.w   d5,d0
        ifeq    \1
        bsr     slope_k
        else
        bsr     slope
        endc
        moveq   #0,d0
        rts
.deep:  tst.b   M_KD1+1(a4)             ; too far below the surface
        bmi.s   .deep0
        moveq   #0,d0                   ; a maze-floor cell: open = the floor;
        move.b  M_KD1+1(a4),d0          ; closed = a wall AND the floor (M_F5CE = 0)
        bsr     maze_open
        move.w  d0,d3
        bne.s   .f54
        clr.w   M_F5CE(a4)
        bra.s   .f54
.deep0: tst.b   d4
        bmi     .air
.wall:  bsr     wall_bounce             ; = a wall
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; an object always "on the ground"
        bne.s   .wz
        endc
        tst.b   M_GND+1(a4)
        beq     .air
.wz:    subi.l  #$400,M_Z(a4)           ; undo this frame's 4-px ground fall
        ifeq    \1
        tst.b   M_SLOT+1(a4)            ; (an object, 30 Hz: two frames' fall)
        beq.s   .wz1
        subi.l  #$400,M_Z(a4)
        endc
.wz1:   moveq   #0,d0
        rts
.air:   moveq   #1,d0
        rts
; code 3, the floor at Z $8054: below it the marble lands there (slope 3)
.f54:   move.w  #3,M_CODE(a4)
        move.l  M_Z(a4),d0
        lsr.l   #8,d0
        cmpi.w  #$8054,d0
        bhi.s   .f54l
        tst.w   d3
        beq     .wall                   ; (the closed window: a wall)
        bra.s   .air
.f54l:  move.l  #$805400,M_Z(a4)
        tst.b   M_GND+1(a4)
        beq.s   .f54n
        tst.b   d6
        bmi.s   .f54n
        moveq   #0,d0
        move.b  d6,d0
        move.w  d0,M_CKPT(a4)
.f54n:  moveq   #3,d0
        ifeq    \1
        bsr     slope_k
        else
        bsr     slope
        endc
        moveq   #0,d0
        rts
        endm

surface:
        SURFACE 0
; surface_p - the player's copy (st_roll): a4 = G_MB, d0.w / d1.w = X / Y integer
; parts on entry; the slot tests left out
surface_p:
        SURFACE 1

; maze_open - d0.w = the cell's GEO_KD1 (0-20); out d0.w = 1 when M_F9B is in the
; cell's window [lo, hi) (circular), else 0. Uses d1/d3.
maze_open:
        move.b  .lo(pc,d0.w),d1
        move.b  .hi(pc,d0.w),d0
        move.b  M_F9B+1(a4),d3
        cmp.b   d1,d0
        blo.s   .wrap                   ; hi < lo
        cmp.b   d1,d3
        blo.s   .c
        cmp.b   d0,d3
        bhs.s   .c
.o:     moveq   #1,d0
        rts
.wrap:  cmp.b   d1,d3
        bhs.s   .o
        cmp.b   d0,d3
        blo.s   .o
.c:     moveq   #0,d0
        rts
.lo:    dc.b    $00,$06,$0C,$11,$01,$07,$0D,$12,$02,$08,$0E,$14,$03,$09,$0F,$15,$04,$0A,$10,$16,$05
.hi:    dc.b    $06,$0C,$11,$00,$07,$0D,$12,$01,$08,$0E,$13,$03,$09,$0F,$14,$04,$0A,$10,$16,$05,$0B
        even

;-----------------------------------------------------------------------------
; wall_bounce: which axis crossed into a new cell decides which
; velocity sign flips; then back to the position before the move.
;-----------------------------------------------------------------------------
wall_bounce:
        bset    #EV_WALL,M_EVENTS+1(a4)
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_PX(a4),d1
        lsr.l   #8,d1
        andi.w  #$FFF8,d1
        sub.w   d1,d0                   ; X - (prevX & ~7)
        moveq   #0,d2                   ; ix: 0 lower cell, 1 same, 2 higher
        tst.w   d0
        bmi     .y
        moveq   #1,d2
        cmpi.b  #8,d0
        blo     .y
        moveq   #2,d2
.y:     move.l  M_Y(a4),d0
        lsr.l   #8,d0
        move.l  M_PY(a4),d1
        lsr.l   #8,d1
        andi.w  #$FFF8,d1
        sub.w   d1,d0
        tst.w   d0
        bmi     .t
        addq.w  #3,d2
        cmpi.b  #8,d0
        blo     .t
        addq.w  #3,d2
.t:     move.b  .tab(pc,d2.w),d0
        beq     .fy                     ; 0: Y changed cell
        bpl     .fx                     ; 1: X changed cell
        cmpi.b  #$FE,d0
        beq     .both                   ; same cell: both
        move.w  M_VX(a4),d0             ; diagonal: the faster axis keeps
        cmp.w   M_VY(a4),d0
        bhs     .fy
.fx:    eori.b  #1,M_VXS+1(a4)
        bra     restore_prev
.both:  eori.b  #1,M_VXS+1(a4)
.fy:    eori.b  #1,M_VYS+1(a4)
        bra     restore_prev
.tab:   dc.b    $FF,$00,$FF,$01,$FE,$01,$FF,$00,$FF,0
        even

restore_prev:
        move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
        rts

;-----------------------------------------------------------------------------
; st_roll - state 1
;-----------------------------------------------------------------------------
; STEER - st_roll's steering on one axis, accel_pos / accel_neg + grow / shrink inline
; for the player (M_E2 set, slot 0): \1 the magnitude, \2 its sign word, \3 beq (+) /
; bne (-): growing when the sign agrees. d1.w = the step (9). Uses d0.
STEER   macro
        tst.b   \2+1(a4)
        \3.s    .g\@
        move.w  \1(a4),d0               ; braking: crossing 0 flips the sign, v = 0
        sub.w   d1,d0
        bcc.s   .s\@
        eori.b  #1,\2+1(a4)
        moveq   #0,d0
        bra.s   .s\@
.g\@:   move.w  \1(a4),d0               ; growing: the cap (M_E2 set: 1.0 unless M_FB)
        add.w   d1,d0
        cmpi.w  #$FF,d0
        bls.s   .s\@
        tst.b   M_FB+1(a4)
        bne.s   .f\@
        clr.b   d0
        bra.s   .s\@
.f\@:   tst.b   d0
        bpl.s   .s\@
        move.b  #$7F,d0
.s\@:   move.w  d0,\1(a4)
        endm

st_roll:
        tst.b   M_F5CB+1(a4)            ; frozen (freeze_event): frame id only
        bne     .fid
        move.b  M_S(a4),d0              ; b451(S high) >= 0: above the screen top
        cmpi.w  #4,G_RACE(a6)           ; (Silly: below the bottom: S high > $80)
        beq.s   .sil
        tst.b   d0
        bmi     .top_ok
        bra.s   .offtop
.sil:   cmpi.b  #$80,d0
        bls     .top_ok
.offtop:                                ; state $1E, -5 s (as time_event 6)
        move.b  M_TIME+1(a4),d0
        subq.b  #5,d0
        bcc.s   .t5
        moveq   #0,d0
.t5:    move.b  d0,M_TIME+1(a4)
        clr.w   M_F0(a4)
        clr.w   M_F2(a4)
        move.w  #$FF,M_F4(a4)
        move.w  #ST_OFFTOP,M_STATE(a4)
        clr.w   M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        bset    #EV_OFFTOP-8,M_EVENTS(a4)
        rts
.top_ok:
        tst.b   M_E4+1(a4)              ; M_E4 = 0: riding the piston
        bne.s   .nopist
        bsr     piston
        bra     .fid
.nopist:
        ; steering: on the ground, racing, not too dizzy, M_E2 set
        tst.b   M_GND+1(a4)
        beq     .nosteer
        tst.b   M_RACING+1(a4)
        beq     .nosteer
        cmpi.b  #$50,M_DIZZY+1(a4)
        bhs     .nosteer
        tst.b   M_E2+1(a4)
        beq     .nosteer
        ; control type 0 (90 deg): Down +X+Y, Up -X-Y, Left -X+Y, Right +X-Y
        moveq   #15,d2
        and.w   M_PAD(a4),d2
        move.b  .stab(pc,d2.w),d3       ; the four requests
        bne.s   .acc
        bra     .nosteer
; .stab[M_PAD & 15]: Down (4) = +X+Y (3), Up (8) = -X-Y ($C), Left (2) = -X+Y (9),
; Right (1) = +X-Y (6); bits: 0 +Y, 1 +X, 2 -Y, 3 -X
.stab:  dc.b    $0,$6,$9,$F,$3,$7,$B,$F,$C,$E,$D,$F,$F,$F,$F,$F
.acc:   moveq   #9,d1                   ; order: +Y, +X, -Y, -X
        btst    #0,d3
        beq.s   .a1
        STEER   M_VY,M_VYS,beq
.a1:    btst    #1,d3
        beq.s   .a2
        STEER   M_VX,M_VXS,beq
.a2:    btst    #2,d3
        beq.s   .a3
        STEER   M_VY,M_VYS,bne
.a3:    btst    #3,d3
        beq.s   .nosteer
        STEER   M_VX,M_VXS,bne
.nosteer:
        ; vertical speed: falling = gravity 10 (25 while moving up), window -3;
        ; on the ground = fall 4 px a frame and snap back, window -8
        tst.b   M_GND+1(a4)
        bne     .ground
        tst.b   M_VZS+1(a4)
        beq     .g10
        moveq   #$19,d1
        bsr     gravity
        tst.b   M_VZS+1(a4)
        bne     .gdd
        move.b  #$F0,M_VZ+1(a4)
        bra     .gdd
.g10:   moveq   #$0A,d1
        bsr     gravity
.gdd:   move.w  #$FD,M_DD(a4)
        bra     .move
.ground:
        move.w  #$400,M_VZ(a4)
        clr.w   M_VZS(a4)
        move.w  #$F8,M_DD(a4)
.move:  move.l  M_X(a4),M_PX(a4)
        move.l  M_Y(a4),M_PY(a4)
        bsr     integrate
        ; the speed-up key held: a second X/Y move on even frames
        tst.b   M_PAD+1(a4)
        bpl     .side
        tst.b   M_E2+1(a4)
        beq     .side
        tst.b   M_F7ED+1(a4)
        bne     .a_ok
        tst.b   M_GND+1(a4)
        beq     .side
.a_ok:  btst    #0,M_FC+1(a4)
        bne     .side
        bsr     integrate_xy
.side:  ; screen edges (X - Y near +-128): bounce off with the speeds swapped
        move.l  M_X(a4),d0              ; (X / Y kept for surface_p)
        move.l  M_Y(a4),d1
        move.l  d0,d2
        sub.l   d1,d2
        lsr.l   #8,d2
        subi.b  #$80,d2
        cmpi.b  #8,d2
        blo.s   .sb
        cmpi.b  #$F9,d2
        bhs.s   .sb
        lsr.l   #8,d0
        lsr.l   #8,d1
        bra.s   .look
.sb:    bsr     side_bounce
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_Y(a4),d1
        lsr.l   #8,d1
.look:  bsr     surface_p
        tst.w   d0
        bne     .inair
        tst.b   M_GND+1(a4)
        bne     .c3eb
        ; landing
        move.w  #1,M_GND(a4)
        cmpi.b  #$18,M_AIR+1(a4)
        blo     .dizzy
        moveq   #$7F,d0                 ; the race start's drop-in (M_E7 & $7F = 3)
        and.b   M_E7+1(a4),d0           ; lands dizzy, unless M_E7 bit 7 and Z low
        cmpi.b  #3,d0                   ; in $75-$FF but not $80
        bne.s   .brk
        tst.b   M_E7+1(a4)
        bpl.s   .drop
        move.b  M_Z+2(a4),d0
        cmpi.b  #$80,d0
        beq.s   .drop
        cmpi.b  #$75,d0
        bhs.s   .brk
.drop:  addq.b  #1,M_E7+1(a4)
        tst.b   M_X+1(a4)               ; X high = 0: the set speeds
        bne.s   .dz2
        move.w  #DROP_VX<<8,M_VX(a4)
        move.w  #DROP_VY<<8,M_VY(a4)
.dz2:   move.b  #$19+$46,M_DIZZY+1(a4)
        bset    #EV_DROP-8,M_EVENTS(a4)
        bra     .c3eb
.brk:   clr.w   M_T400(a4)              ; 24+ frames in the air: broken
        clr.w   M_DIZZY(a4)
        move.w  #ST_BROKEN,M_STATE(a4)
        bset    #EV_BREAK,M_EVENTS+1(a4)
        bra     .fid
.dizzy: move.b  M_AIR+1(a4),d0
        addi.b  #$46,d0
        move.b  d0,M_DIZZY+1(a4)
        bset    #EV_LAND,M_EVENTS+1(a4)
.c3eb:  tst.b   M_CF+1(a4)              ; on an Aerial piston cell whose piston
        bmi     .fid                    ; has just started (G_WP6D7 = 1): thrown up
        moveq   #0,d0
        move.b  M_CF+1(a4),d0
        lea     G_WP6D7(a6),a0
        cmpi.b  #1,0(a0,d0.w)
        bne     .fid
        move.w  #1,M_VZS(a4)
        move.w  #$340,M_VZ(a4)
        clr.w   M_GND(a4)
        lea     .pv(pc),a0              ; speed / sign by the position in the cell
        moveq   #7,d0
        and.b   M_X+2(a4),d0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_VX(a4)
        move.b  8(a0,d0.w),d1
        move.w  d1,M_VXS(a4)
        moveq   #7,d0
        and.b   M_Y+2(a4),d0
        move.b  0(a0,d0.w),d1
        move.w  d1,M_VY(a4)
        move.b  8(a0,d0.w),d1
        move.w  d1,M_VYS(a4)
        move.w  #$83,M_E7(a4)
        bra     .fid
.pv:    dc.b    $30,$28,$20,$18,$1C,$24,$2C,$34,1,1,1,1,0,0,0,0
.inair: tst.b   M_GND+1(a4)
        bne     .takeoff
        addq.b  #1,M_AIR+1(a4)          ; frames airborne, saturating
        bne.s   .ia
        subq.b  #1,M_AIR+1(a4)
.ia:    cmpi.w  #5,G_RACE(a6)           ; Ultimate tests the funnel cells
        beq.s   .fck                    ;  in the air too (its holes are chutes)
        bra     .fid
.takeoff:                               ; left the ground
        bsr     takeoff_check           ; the race's check (it may clamp vx / vy)
        tst.w   d0
        beq.s   .tkn
        tst.b   M_PAD+1(a4)             ; and the speed-up key held: a special jump
        bpl.s   .tkn
        move.w  #$20,M_F7ED(a4)
        move.w  #1,M_VZS(a4)
        cmpi.w  #5,G_RACE(a6)
        beq.s   .tk5
        move.w  #$83,M_E7(a4)
.tk5:   subi.l  #$400,M_Z(a4)
        bset    #EV_SPECIAL-8,M_EVENTS(a4)
        bra.s   .tkc
.tkn:   subi.l  #$300,M_Z(a4)
.tkc:   move.w  #$80,M_VZ(a4)
        clr.w   M_AIR(a4)
        clr.w   M_GND(a4)
        bset    #EV_TAKEOFF,M_EVENTS+1(a4)
        ; off a funnel cell ($A8 / $B6 / $B7): state $1B, record 0 / 8 / $10
        ; past the race's base (M_GND = 1: from the take-off's 0, or in the air's 0)
.fck:   move.w  M_CODE(a4),d0
        moveq   #0,d1
        cmpi.w  #$A8,d0
        beq.s   .fn
        moveq   #8,d1
        cmpi.w  #$B6,d0
        beq.s   .fn
        moveq   #$10,d1
        cmpi.w  #$B7,d0
        bne     .fid
.fn:    movea.l G_PGEO(a6),a5
        add.b   GEO_FUNNEL+72(a5),d1
        andi.w  #$FF,d1
        move.w  d1,M_E0(a4)
        move.w  #1,M_DE(a4)
        move.w  #ST_FUNNEL,M_STATE(a4)
        move.w  #1,M_GND(a4)
        bset    #EV_FUNNEL-8,M_EVENTS(a4)
.fid:   ; frame id; dizziness counts down and ends on fc & 3 = 1
        move.w  #1,M_DRAWN(a4)
        tst.b   M_DIZZY+1(a4)
        bne     .dz
        move.w  #1,M_FID(a4)
        rts
.dz:    move.w  #8,M_FID(a4)
        subq.b  #1,M_DIZZY+1(a4)
        bne     .out
        moveq   #3,d0
        and.b   M_FC+1(a4),d0
        cmpi.b  #1,d0
        beq     .out
        addq.b  #1,M_DIZZY+1(a4)
.out:   rts

; side_bounce: back to the previous position, vx' = vy/2,
; vy' = vx/2, and the faster axis's sign flips
side_bounce:
        bset    #EV_SIDE,M_EVENTS+1(a4)
        bsr     restore_prev
        move.w  M_VX(a4),d0
        move.w  M_VY(a4),d1
        move.w  d0,d2
        lsr.w   #8,d2
        move.w  d1,d3
        lsr.w   #8,d3
        cmp.b   d1,d0                   ; fraction borrow
        bhs     .nb
        addq.b  #1,d3
.nb:    sub.b   d3,d2                   ; N of (VXI - VYI - borrow)
        lsr.w   #1,d1
        move.w  d1,M_VX(a4)
        lsr.w   #1,d0
        move.w  d0,M_VY(a4)
        tst.b   d2
        bmi     .fy
        eori.b  #1,M_VXS+1(a4)
        rts
.fy:    eori.b  #1,M_VYS+1(a4)
        rts

;-----------------------------------------------------------------------------
; st_broken - state 7: 10 redraw ticks, then state 8
;-----------------------------------------------------------------------------
st_broken:
        moveq   #3,d0
        and.b   M_FC+1(a4),d0
        bne     .t
        addq.b  #1,M_T400+1(a4)
.t:     cmpi.b  #10,M_T400+1(a4)
        bne     .stay
        move.w  #ST_SINK,M_STATE(a4)
        clr.w   M_T400(a4)
        clr.w   M_T6CF(a4)
        moveq   #0,d0
        bra     sink_fid
.stay:  moveq   #1,d0
        cmpi.b  #8,M_T400+1(a4)
        blo     .f
        moveq   #8,d0
.f:     move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        bsr     surface
        tst.b   M_F5CE+1(a4)            ; on a closed maze floor: dead
        bne.s   .o
        move.w  #ST_DEAD,M_STATE(a4)
.o:     rts

;-----------------------------------------------------------------------------
; st_sink - state 8: 27 redraw ticks, then dead
;-----------------------------------------------------------------------------
st_sink:
        addq.b  #1,M_T6CF+1(a4)
        moveq   #3,d0
        and.b   M_FC+1(a4),d0
        bne     .f
        addq.b  #1,M_T400+1(a4)
        cmpi.b  #$1B,M_T400+1(a4)
        bne     .f
        move.w  #ST_DEAD,M_STATE(a4)
        rts
.f:     moveq   #0,d0
        move.b  M_T400+1(a4),d0
sink_fid:                               ; d0 = timer: frame id $0F/$10/0
        lsr.w   #2,d0
        moveq   #0,d1
        cmpi.w  #9,d0
        bhs     .s
        move.b  .tab(pc,d0.w),d1
.s:     move.w  d1,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.tab:   dc.b    $0F,$10,$10,$10,$10,0,0,0,0,0
        even

;-----------------------------------------------------------------------------
; st_dead - state 9: place the marble on its respawn point
; (reposition), then wait (state B) a random 48-79 + frames
;-----------------------------------------------------------------------------
st_dead:
        cmpi.b  #$14,M_DEATHS+1(a4)
        beq     .d
        addq.b  #1,M_DEATHS+1(a4)
.d:     bsr     reposition
        bra     to_wait

; reposition - the marble at its checkpoint (X, Y = n*8+4), Z = the
; surface there (M_NOE9 = 1, the depth only)
reposition:
        movea.l G_PGEO(a6),a5
        move.w  M_CKPT(a4),d0
        add.w   d0,d0
        lea     GEO_RESP(a5),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1           ; X / 8
        lsl.l   #3,d1
        addq.l  #4,d1
        lsl.l   #8,d1
        move.l  d1,M_X(a4)              ; X = n*8+4, fraction 0
        moveq   #0,d1
        move.b  1(a0,d0.w),d1
        lsl.l   #3,d1
        addq.l  #4,d1
        lsl.l   #8,d1
        move.l  d1,M_Y(a4)
        clr.b   M_Z+3(a4)
        move.w  #1,M_NOE9(a4)
        bsr     geo_cell                ; depth only
        clr.w   M_NOE9(a4)
        tst.w   d0
        beq     .f
        move.w  #ST_DEAD,M_STATE(a4)
        moveq   #0,d2
.f:     btst    #16,d2
        beq     .z
        moveq   #0,d2
.z:     andi.l  #$FFFF,d2
        lsl.l   #8,d2
        move.l  d2,M_Z(a4)
        rts

; to_wait - one player: state B with the two random timers
to_wait:
        move.w  #ST_WAIT,M_STATE(a4)
        bsr     rand
        andi.w  #$1F,d0
        addi.w  #$30,d0
        move.w  d0,M_VXS(a4)            ; the sign bytes are the wait timers
        addq.w  #8,d0
        move.w  d0,M_VYS(a4)
        rts

;-----------------------------------------------------------------------------
; st_offtop - state $1E: above the screen top (below in Silly).
; Off the screen: count; back one checkpoint (the race's table GEO_PREV)
; and there, drawn as nothing. On the screen again (the camera
; follows): save its screen y / checkpoint, then wait and respawn (to_wait).
;-----------------------------------------------------------------------------
st_offtop:
        move.b  M_S(a4),d0
        bsr     b451
        tst.b   d0
        bmi     .on
        addq.b  #1,M_F0+1(a4)
        cmpi.b  #4,M_F0+1(a4)
        blo.s   .back
        tst.b   M_F4+1(a4)
        bmi.s   .back
        move.w  M_F4(a4),M_CKPT(a4)
        bsr     reposition
        bra     to_wait
.back:  movea.l G_PGEO(a6),a5
        move.w  M_CKPT(a4),d0
        lea     GEO_PREV(a5),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_CKPT(a4)
        bsr     reposition
        clr.w   M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.on:    move.b  M_S+1(a4),d0            ; screen y low
        tst.b   M_F4+1(a4)
        bmi.s   .upd
        cmpi.w  #4,G_RACE(a6)
        beq.s   .sil
        cmp.b   M_F2+1(a4),d0           ; below the saved one: keep it
        blo     to_wait
        bra.s   .upd
.sil:   cmp.b   M_F2+1(a4),d0           ; (Silly): the other way
        bhs     to_wait
.upd:   move.b  d0,M_F2+1(a4)
        move.b  M_CKPT+1(a4),M_F4+1(a4)
        bra     to_wait

; b451 - d0.b = a screen y high byte as the off-the-top tests
; see it (Silly flips it: < $80 -> $81, $80 -> $80, > $80 -> $7F)
b451:
        cmpi.w  #4,G_RACE(a6)
        bne.s   .o
        cmpi.b  #$80,d0
        beq.s   .o
        bhi.s   .h
        move.b  #$81,d0
        rts
.h:     moveq   #$7F,d0
.o:     rts

;-----------------------------------------------------------------------------
; freeze_event - every logic step BEFORE the objects: the
; random freeze. Races 2-5, at most once a race (M_F5CD) and 3 times a game
; (M_F5CC): a random draw of $52 on a step with fc & $1F = $0D while rolling
; starts it; it lasts 127 steps (no rolling, camera or timer) and gives +10 s
; when it ends.
;-----------------------------------------------------------------------------
; RAND_STEP - rand's body: d0.b = the new M_RNG byte 0. Uses d0-d2, a0.
RAND_STEP macro
        lea     M_RNG(a4),a0
        move.b  (a0),d0
        andi.b  #$48,d0
        addi.b  #$38,d0
        add.b   d0,d0                   ; bit 7 = bit 6: the carry into byte 2
        move.l  (a0),d2                 ; bytes 0:1:2:3
        move.b  d0,d2
        add.l   d2,d2                   ; rol bytes 2 / 1 / 0; X = old bit 7 of byte 0
        subx.b  d1,d1                   ; (X kept: $FF / 0)
        move.b  3(a0),d2                ; (byte 3 unchanged)
        move.l  d2,(a0)
        addq.b  #1,(a0)
        move.b  (a0),d0
        add.b   d1,d1                   ; X = the carry again
        move.b  M_PAD+1(a4),d1
        addx.b  d1,d0
        move.b  M_PADNEW+1(a4),d1
        addx.b  d1,d0
        move.b  3(a0),d1
        addx.b  d1,d0
        move.b  4(a0),d1
        addx.b  d1,d0
        move.b  5(a0),d1
        addx.b  d1,d0
        move.b  M_FC+1(a4),d1
        addx.b  d1,d0
        moveq   #$0D,d1
        addx.b  d1,d0
        move.b  d0,(a0)
        endm

freeze_event:
        move.b  M_F5CB+1(a4),d0
        beq.s   .chk
        addq.b  #1,d0
        andi.b  #$7F,d0
        move.b  d0,M_F5CB+1(a4)
        bne.s   .chk
        moveq   #10,d0                  ; over: +10 s
        bsr     add_time
.chk:   move.w  G_RACE(a6),d0
        beq     .o
        cmpi.w  #5,d0
        beq     .o
        tst.b   M_F5CD+1(a4)
        beq     .o
        tst.b   M_F5CC+1(a4)
        beq.s   .o
        RAND_STEP                       ; (rand, inline)
        cmpi.b  #$52,d0
        bne.s   .o
        moveq   #$1F,d0
        and.b   M_FC+1(a4),d0
        cmpi.b  #$0D,d0
        bne.s   .o
        cmpi.w  #ST_ROLL,M_STATE(a4)
        bne.s   .o
        move.w  #1,M_F5CB(a4)
        subq.b  #1,M_F5CC+1(a4)
        subq.b  #1,M_F5CD+1(a4)
        bset    #EV_FREEZE-8,M_EVENTS(a4)
.o:     rts

; add_time - + d0.b seconds, at most 99
add_time:
        add.b   M_TIME+1(a4),d0
        cmpi.b  #99,d0
        bls.s   .s
        moveq   #99,d0
.s:     move.b  d0,M_TIME+1(a4)
        rts

;-----------------------------------------------------------------------------
; timer - after the objects: M_T43 counts logic steps; a second goes
; once it has reached 70 on a step with fc & 7 = 0 (~70 steps a second),
; not while frozen, during the intro (M_T51) or before the start (M_T48 bit 7);
; never below 0. At 0 the player is out (time out): M_PRESENT = M_RACING = 0.
;-----------------------------------------------------------------------------
timer:
        tst.b   M_F5CB+1(a4)
        bne.s   .o
        tst.b   M_T51+1(a4)
        bne.s   .o
        tst.b   M_T48+1(a4)
        bpl.s   .o
        addq.b  #1,M_T43+1(a4)
        cmpi.b  #70,M_T43+1(a4)
        blo.s   .o
        moveq   #7,d0
        and.b   M_FC+1(a4),d0
        bne.s   .o
        subi.b  #70,M_T43+1(a4)
        tst.w   G_TIMOFF(a6)            ; key C: the countdown frozen (no time out)
        bne.s   .o
        tst.b   M_RACING+1(a4)
        beq.s   .z
        tst.b   M_TIME+1(a4)
        beq.s   .z
        subq.b  #1,M_TIME+1(a4)
.z:     tst.b   M_TIME+1(a4)
        bne.s   .o
        tst.b   M_PRESENT+1(a4)
        beq.s   .o
        clr.w   M_PRESENT(a4)
        clr.w   M_RACING(a4)
        bset    #EV_TIMEOUT-8,M_EVENTS(a4)
.o:     rts

;-----------------------------------------------------------------------------
; takeoff_check - Practice / Aerial / Ultimate,
; called at the take-off: d0.w = 1 at the race's take-off point (a
; special jump if the speed-up key is held), else 0. Practice's also clamps vx / vy in two
; windows. Uses d0-d3.
;-----------------------------------------------------------------------------
takeoff_check:
        move.w  G_RACE(a6),d0
        beq.s   .r0
        cmpi.w  #3,d0
        beq     .r3
        cmpi.w  #5,d0
        beq     .r5
.no:    moveq   #0,d0
        rts
.yes:   moveq   #1,d0
        rts
.r0:    cmpi.b  #1,M_X+1(a4)            ; X high 1, Y high 1
        bne     .no
        cmpi.b  #1,M_Y+1(a4)
        bne     .no
        move.b  M_X+2(a4),d1            ; X low
        move.b  M_Y+2(a4),d2            ; Y low
        cmpi.b  #$98,d1
        blo     .no
        cmpi.b  #$A4,d1
        blo.s   .b4f3
        cmpi.b  #$D0,d1
        blo     .no
        cmpi.b  #$F0,d1
        blo.s   .b517
        cmpi.b  #$F4,d1
        bhs     .no
        cmpi.b  #$A8,d2
        blo     .no
        cmpi.b  #$C0,d2
        bhs     .no
        tst.b   M_VX(a4)                ; vx high
        bne     .yes
        tst.b   M_VX+1(a4)
        bmi     .yes
        bra     .no
.b4f3:  cmpi.b  #$38,d2
        blo     .no
        cmpi.b  #$5C,d2
        bhs     .no
        tst.b   M_VX(a4)
        bne.s   .c3f
        cmpi.b  #$40,M_VX+1(a4)
        blo.s   .b522
.c3f:   move.w  #$3F,M_VX(a4)
        bra.s   .b522
.b517:  cmpi.b  #$A8,d2
        bhs     .no
        cmpi.b  #$A4,d2
        blo     .no
.b522:  tst.b   M_VY(a4)
        bne.s   .c7f
        tst.b   M_VY+1(a4)
        bpl     .no
.c7f:   move.w  #$7F,M_VY(a4)
        bra     .no
.r3:    cmpi.b  #2,M_X+1(a4)            ; X high 2, Y high 2
        bne     .no
        cmpi.b  #2,M_Y+1(a4)
        bne     .no
        move.b  M_X+2(a4),d1
        move.b  M_Y+2(a4),d2
        cmpi.b  #$30,d1
        blo     .no
        cmpi.b  #$34,d1
        blo.s   .b4a0
        cmpi.b  #$A0,d1
        blo     .no
        cmpi.b  #$B0,d1
        bhs     .no
        tst.b   M_VY(a4)
        bne     .yes
        tst.b   M_VY+1(a4)
        bpl     .no
        cmpi.b  #$78,d2
        blo     .no
        cmpi.b  #$7C,d2
        bhs     .no
        bra     .yes
.b4a0:  cmpi.b  #$20,d2
        blo     .no
        cmpi.b  #$38,d2
        bhs     .no
        tst.b   M_VX(a4)
        bne     .yes
        tst.b   M_VX+1(a4)
        bmi     .yes
        bra     .no
.r5:    tst.b   M_X+1(a4)               ; X high 0, X low $A8-$AB,
        bne     .no                     ; Y high 0, Y low $88-$97, Z low < $18
        move.b  M_X+2(a4),d1
        cmpi.b  #$A8,d1
        blo     .no
        cmpi.b  #$AC,d1
        bhs     .no
        tst.b   M_Y+1(a4)
        bne     .no
        move.b  M_Y+2(a4),d2
        cmpi.b  #$88,d2
        blo     .no
        cmpi.b  #$98,d2
        bhs     .no
        cmpi.b  #$18,M_Z+2(a4)
        bhs     .no
        bra     .yes

;-----------------------------------------------------------------------------
; st_funnel - state $1B: into the funnel: state $1C at the
; exit of record M_E0 (GEO_FUNNEL: X/8, Y/8, Z/4, vx, vy, delay, time event,
; checkpoint), fractions and high speeds 0, vx sign 1 from record $18 on.
; st_funnel2 - state $1C: the delay; then rolling at the exit with its
; checkpoint and its time event (time_event). Not drawn meanwhile (frame id 0).
;-----------------------------------------------------------------------------
st_funnel:
        move.w  #ST_FUNNEL2,M_STATE(a4)
        movea.l G_PGEO(a6),a5
        lea     GEO_FUNNEL(a5),a0
        adda.w  M_E0(a4),a0             ; the record
        moveq   #0,d0
        move.b  (a0),d0
        lsl.l   #3,d0
        addq.l  #4,d0
        lsl.l   #8,d0
        move.l  d0,M_X(a4)              ; X = n*8+4, fraction 0
        moveq   #0,d0
        move.b  1(a0),d0
        lsl.l   #3,d0
        addq.l  #4,d0
        lsl.l   #8,d0
        move.l  d0,M_Y(a4)
        moveq   #0,d0
        move.b  2(a0),d0
        lsl.w   #2,d0
        andi.w  #$3FF,d0
        ori.w   #$8000,d0
        lsl.l   #8,d0
        move.l  d0,M_Z(a4)              ; Z = $8000 | n*4
        moveq   #0,d0
        move.b  3(a0),d0
        move.w  d0,M_VX(a4)
        move.b  4(a0),d0
        move.w  d0,M_VY(a4)
        clr.w   M_VXS(a4)
        cmpi.w  #$18,M_E0(a4)
        blo.s   .s
        move.w  #1,M_VXS(a4)
.s:     clr.w   M_VYS(a4)
        move.b  5(a0),d0
        move.w  d0,M_DE(a4)
        clr.w   M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

st_funnel2:
        subq.b  #1,M_DE+1(a4)
        bne.s   .w
        move.w  #ST_ROLL,M_STATE(a4)
        movea.l G_PGEO(a6),a5
        lea     GEO_FUNNEL(a5),a0
        adda.w  M_E0(a4),a0
        moveq   #0,d0
        move.b  7(a0),d0
        move.w  d0,M_CKPT(a4)
        move.b  6(a0),d0
        bsr     time_event
.w:     clr.w   M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

; time_event - d0.b: 6: -5 s; 8: +3 s; 7 or >= 9: +10 s; < 6:
; points, (d0 + 1) x 10 (10, 20 .. 60) into the middle (x 100) byte
time_event:
        cmpi.b  #6,d0
        blo.s   .pts
        bne.s   .n6
        move.b  M_TIME+1(a4),d0
        subq.b  #5,d0
        bcc.s   .t
        moveq   #0,d0
.t:     move.b  d0,M_TIME+1(a4)
.o:     rts
.pts:   andi.w  #$FF,d0
        addq.w  #1,d0
        mulu.w  #10,d0
        moveq   #1,d1
        bra     add_score
.n6:    cmpi.b  #8,d0
        bne.s   .t10
        moveq   #3,d0
        bra     add_time
.t10:   moveq   #10,d0
        bra     add_time

; f7ed_timer - M_F7ED counts down to 0 every frame; then the timer
f7ed_timer:
        tst.b   M_F7ED+1(a4)
        beq.s   .m
        subq.b  #1,M_F7ED+1(a4)
.m:     bsr     machinery
        bsr     timer
        moveq   #3,d0                   ; the score's two tests inline (most frames
        and.b   M_FC+1(a4),d0           ;  end here): speed_pts on (frame & 3) = 0,
        bne.s   .g                      ;  goal_bonus's counting only while M_C2 runs
        bsr     speed_pts
.g:     tst.b   M_C2+1(a4)
        bne     goal_bonus
        tst.b   M_RACING+1(a4)
        bne.s   .r
        tst.b   M_CA+1(a4)
        bne.s   .r
        move.w  #6,M_C2(a4)             ; (no player racing, no bonus yet)
.r:     rts

;-----------------------------------------------------------------------------
; The score: 3 base-100 bytes, high .. low (M_SCORE+1..+3).
; add_score - d0.b points (0-99) into byte d1.w (0 high, 1, 2 low), carrying on
; up; a carry out of the high byte is lost. Uses d0-d2/a0.
;-----------------------------------------------------------------------------
add_score:
        lea     M_SCORE+1(a4),a0
        adda.w  d1,a0
.l:     add.b   (a0),d0                 ; (at most 99 + 99)
        moveq   #0,d2
.c:     cmpi.b  #100,d0
        blo.s   .s
        subi.b  #100,d0
        addq.b  #1,d2
        bra.s   .c
.s:     move.b  d0,(a0)
        tst.b   d2
        beq.s   .o
        subq.w  #1,d1
        bmi.s   .o
        subq.l  #1,a0
        move.b  d2,d0
        bra.s   .l
.o:     rts

; speed_pts - after the timer: on frames with (frame & 3) = 0
; (one player: X = (frame >> 1) & 1 = 0; f7ed_timer tests it), a player racing,
; in play and rolling adds ((max(|vx| high, |vy| high) << 3 | 1) << 2) (8 bits)
; to M_C5; each carry out is +10 points
speed_pts:
        tst.b   M_RACING+1(a4)
        beq.s   .o
        tst.b   M_PRESENT+1(a4)
        beq.s   .o
        cmpi.w  #1,M_STATE(a4)
        bne.s   .o
        move.b  M_VX(a4),d0             ; (the high bytes)
        cmp.b   M_VY(a4),d0
        bhs.s   .m
        move.b  M_VY(a4),d0
.m:     lsl.b   #3,d0
        ori.b   #1,d0
        lsl.b   #2,d0
        add.b   d0,M_C5+1(a4)
        bcc.s   .o
        moveq   #10,d0
        moveq   #2,d1
        bra     add_score
.o:     rts

; goal_bonus - no player racing and no bonus yet (M_CA = 0): M_C2 =
; 6 (f7ed_timer); then (here) on frames with (frame & 15) = 0 it counts down,
; and at 0 the time left gives seconds x 100 points and M_CA = 50 (the
; tally)
goal_bonus:
        moveq   #15,d0
        and.b   M_FC+1(a4),d0
        bne.s   .o
        subq.b  #1,M_C2+1(a4)
        bne.s   .o
        move.w  #50,M_CA(a4)
        move.b  M_TIME+1(a4),d0
        moveq   #1,d1
        bra     add_score
.o:     rts

;-----------------------------------------------------------------------------
; piston - Aerial: M_E4 = 0 (a code $13 cell) and the marble
; rides the piston: X = $1xx00 (.px[M_F9D >> 3]), Y = $1BF00, Z high $80 and
; low .pz[..] (fraction kept), vx $180 -, vz $380 up, vy 0, airborne. At
; step 2 it is let go: M_E4 = 3, M_E7 = 3 (drop-in landing), checkpoint $0B.
;-----------------------------------------------------------------------------
piston:
        moveq   #0,d0
        move.b  M_F9D+1(a4),d0
        lsr.b   #3,d0
        moveq   #1,d1
        swap    d1
        move.b  .px(pc,d0.w),d1
        lsl.w   #8,d1                   ; $0001xx00
        move.l  d1,M_X(a4)
        move.l  #$1BF00,M_Y(a4)
        move.l  #$800000,d1
        move.b  .pz(pc,d0.w),d1
        lsl.w   #8,d1
        move.b  M_Z+3(a4),d1
        move.l  d1,M_Z(a4)
        move.w  #$180,M_VX(a4)
        clr.w   M_VY(a4)
        move.w  #$380,M_VZ(a4)
        move.w  #1,M_VXS(a4)
        move.w  #1,M_VZS(a4)
        clr.w   M_GND(a4)
        cmpi.b  #2,d0
        bne.s   .o
        move.w  #3,M_E4(a4)
        move.w  #3,M_E7(a4)
        move.w  #$0B,M_CKPT(a4)
.o:     rts
.px:    dc.b    $E8,$DF,$D4             ; X low by step
.pz:    dc.b    $6C,$60,$52             ; Z low by step

;-----------------------------------------------------------------------------
; machinery - the main loop's per-race state after the objects: Beginner's
; counters + the whirlpools (whirl), Aerial's piston phase + the fan (updraft),
; Ultimate's goal maze.
;-----------------------------------------------------------------------------
machinery:
        move.w  G_RACE(a6),d0
        subq.w  #1,d0
        beq.s   .beg
        subq.w  #1,d0
        beq.s   .int
        subq.w  #1,d0
        beq     .aer
        subq.w  #2,d0
        beq     .ult
        rts
.int:   tst.b   M_F9B+1(a4)             ; Intermediate's waves (src/mobj.asm waves:
        bpl.s   .wv                     ; a PC-relative far call), only while they run
        tst.b   M_FB+1(a4)              ; or a lift is left (M_FB: then Z - M_FB)
        beq.s   .wx
.wv:    lea     .wv(pc),a0
        adda.l  #waves-.wv,a0
        jmp     (a0)
.wx:    rts
.beg:   addq.b  #1,M_F9B+1(a4)          ; M_F9B: 0-$2F
        cmpi.b  #$30,M_F9B+1(a4)
        blo.s   .b1
        clr.b   M_F9B+1(a4)
.b1:    moveq   #3,d0
        and.b   M_FC+1(a4),d0
        cmpi.b  #3,d0
        bne     whirl
        addq.b  #1,M_F9D+1(a4)
        bra     whirl
.aer:   move.b  M_F9D+1(a4),d0
        beq     updraft
        cmpi.b  #6,d0
        bhs.s   .a1
        moveq   #3,d1
        and.b   M_FC+1(a4),d1
        bne     updraft
.a1:    addq.b  #1,d0
        andi.b  #$1F,d0
        move.b  d0,M_F9D+1(a4)
        bra     updraft
.ult:   cmpi.w  #$343,M_SCROLL(a4)
        bne.s   .uo
        move.b  M_F9B+1(a4),d0
        moveq   #0,d1
        cmpi.b  #5,d0
        beq.s   .hold
        moveq   #1,d1
        cmpi.b  #$0B,d0
        beq.s   .hold
        moveq   #2,d1
        cmpi.b  #$10,d0
        beq.s   .hold
        moveq   #3,d1
        cmpi.b  #$16,d0
        beq.s   .hold
.step:  addq.b  #1,d0
        bra.s   .u1
.hold:  move.w  d1,M_F7F1(a4)
        moveq   #$1F,d1
        and.b   M_FC+1(a4),d1
        beq.s   .step
.u1:    cmpi.b  #$17,d0
        blo.s   .u2
        moveq   #0,d0
.u2:    move.b  M_F9B+1(a4),d1          ; (the state written this frame: d0; counted
        move.b  d0,M_F9B+1(a4)          ; when it is a new one, and the first: M_MZK,
        tst.w   M_MZK(a4)               ; the count maze_update follows)
        beq.s   .k1
        cmp.b   d0,d1
        beq.s   .uo
        cmpi.w  #$17,M_MZK(a4)
        bhs.s   .uo
.k1:    addq.w  #1,M_MZK(a4)
.uo:    rts

; whirl - Beginner: the four 40x40 whirlpools at X $358-$3A7,
; Y $348-$397 push vx / vy by .wamt[d] * 2 + (M_RNG byte 1 & 3) in the quadrant's
; directions (d: a distance from the fractions); the player's drop (first 0,
; then .wdrop[d] where it pushes: the marble drawn lower) in G_WHD
whirl:
        lea     G_MB(a6),a2
        cmpa.l  a2,a4
        bne.s   .np
        clr.w   G_WHD(a6)
.np:    cmpi.b  #3,M_X+1(a4)            ; X, Y high bytes 3 (the usual exit)
        bne     .o
        cmpi.b  #3,M_Y+1(a4)
        bne     .o
        lea     .wx(pc),a2
        move.l  M_X(a4),d0
        lsr.l   #8,d0                   ; X
        move.l  M_Y(a4),d1
        lsr.l   #8,d1                   ; Y
        cmpi.b  #$48,d1
        blo     .o
        cmpi.b  #$98,d1
        bhs     .o
        cmpi.b  #$58,d0
        blo     .o
        cmpi.b  #$A8,d0
        bhs     .o
        moveq   #0,d2                   ; quadrant
        cmpi.b  #$70,d1
        blo.s   .q1
        moveq   #2,d2
.q1:    cmpi.b  #$80,d0
        blo.s   .q2
        addq.w  #1,d2
.q2:    move.b  .wy-.wx(a2,d2.w),d3
        sub.b   d3,d1                   ; fy
        move.b  .wx-.wx(a2,d2.w),d3
        sub.b   d3,d0                   ; fx
        add.w   d2,d2
        cmp.b   d1,d0
        blo.s   .q3
        addq.w  #1,d2                   ; i = 2q + (fx >= fy)
.q3:    cmpi.w  #3,d2
        beq     .o
        cmpi.w  #4,d2
        beq     .o
        andi.w  #$FF,d0
        andi.w  #$FF,d1
        move.b  .wsel-.wx(a2,d2.w),d3
        beq.s   .dfx
        bmi.s   .dab
        move.w  d1,d0                   ; fy
        bra.s   .dfx
.dab:   sub.w   d1,d0                   ; |fy - fx|
        bpl.s   .dfx
        neg.w   d0
.dfx:   move.b  .wrev-.wx(a2,d2.w),d3
        bne.s   .d1
        neg.w   d0
        addi.w  #$27,d0
.d1:    lea     G_MB(a6),a0
        cmpa.l  a0,a4
        bne.s   .nd
        move.b  .wdrop-.wx(a2,d0.w),G_WHD+1(a6)
.nd:    move.b  .wamt-.wx(a2,d0.w),d1
        add.b   d1,d1
        moveq   #3,d0
        and.b   M_RNG+1(a4),d0
        or.b    d0,d1
        andi.w  #$FF,d1
        move.w  d1,-(sp)
        move.w  d2,-(sp)
        move.b  .wdx-.wx(a2,d2.w),d0
        bmi.s   .ny
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr.s   .acc
.ny:    move.w  (sp)+,d2
        move.w  (sp)+,d1
        move.b  .wdy-.wx(a2,d2.w),d0
        bmi.s   .o
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
.acc:   tst.b   d0
        bne     accel_neg
        bra     accel_pos
.o:     rts
.wx:    dc.b    $58,$80,$58,$80
.wy:    dc.b    $48,$48,$70,$70
.wsel:  dc.b    $00,$01,$FF,$00,$00,$FF,$01,$00
.wrev:  dc.b    $01,$01,$01,$01,$01,$01,$00,$00
.wdx:   dc.b    $00,$FF,$01,$FF,$FF,$00,$FF,$01
.wdy:   dc.b    $FF,$00,$00,$FF,$FF,$01,$01,$00
.wamt:  dc.b    $01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02
        dc.b    $03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02,$02
        dc.b    $01,$01,$01,$01,$01,$01,$01,$01
.wdrop: dc.b    0,0,0,0,0,0,0,0,0,0,1,1,2,2,3,3,4,5,6,7,8,9,10,11
        dc.b    12,12,13,13,14,14,15,15,16,16,16,16,16,16,16,16
        even

; updraft - Aerial: the fan at X $298-$2B7, Y $248-$277. In
; it (state 1): M_F7EF = hi(.lift[x] * (y + 1)), vy 3 towards -, vx .push[x]
; (bit 7: towards -). Outside: Z drops by the last M_F7EF, M_F7EF = 0.
updraft:
        cmpi.b  #2,M_X+1(a4)            ; (X $298-$2B7: high byte 2)
        bne.s   .out
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        subi.w  #$298,d0
        cmpi.w  #$20,d0
        bhs.s   .out
        move.l  M_Y(a4),d1
        lsr.l   #8,d1
        subi.w  #$248,d1
        cmpi.w  #$30,d1
        bhs.s   .out
        cmpi.w  #ST_ROLL,M_STATE(a4)
        bne.s   .out
        moveq   #0,d2
        move.b  .lift(pc,d0.w),d2
        addq.w  #1,d1
        mulu    d1,d2
        lsr.w   #8,d2
        move.w  d2,M_F7EF(a4)
        move.w  d0,-(sp)
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        moveq   #3,d1
        bsr     accel_neg
        move.w  (sp)+,d0
        moveq   #0,d1
        move.b  .push(pc,d0.w),d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bclr    #7,d1
        bne     accel_neg
        bra     accel_pos
.out:   tst.w   M_F7EF(a4)              ; (no lift and Z's top byte 0: nothing
        bne.s   .out1                   ;  changes, the usual case)
        tst.b   M_Z(a4)
        bne.s   .out1
        rts
.out1:  move.l  M_Z(a4),d0
        moveq   #0,d1
        move.b  M_F7EF+1(a4),d1
        lsl.l   #8,d1
        sub.l   d1,d0
        andi.l  #$FFFFFF,d0
        move.l  d0,M_Z(a4)
        clr.w   M_F7EF(a4)
        rts
.lift:  dc.b    $55,$55,$5A,$5A,$60,$60,$65,$65,$6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
        dc.b    $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A,$65,$65,$60,$60,$5A,$5A,$55,$55
.push:  dc.b    $02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$00,$00
        dc.b    $00,$00,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02
        even

; rand - Out: d0.b. Mixes in the input bytes and the frame counter.
rand:
        RAND_STEP
        rts

;-----------------------------------------------------------------------------
; st_wait - state B: the two timers count down; respawn at $0B
;-----------------------------------------------------------------------------
st_wait:
        subq.b  #1,M_VYS+1(a4)
        subq.b  #1,M_VXS+1(a4)
        cmpi.b  #$0C,M_VXS+1(a4)
        blo     respawn
        move.w  #$30,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        btst    #0,M_FC+1(a4)
        bne     .o
        subq.b  #3,M_T400+1(a4)         ; its drawer's counter
.o:     rts

; respawn - back to rolling, the motion state reset
respawn:
        move.w  #ST_ROLL,M_STATE(a4)
        clr.w   M_FRON(a4)              ; (no fragments)
        moveq   #1,d0
        move.w  d0,M_BC(a4)
        move.w  d0,M_GND(a4)
        move.w  d0,M_E2(a4)
        moveq   #0,d0
        move.w  d0,M_FB(a4)
        move.w  d0,M_FD(a4)
        move.w  d0,M_DIZZY(a4)
        move.w  d0,M_VXS(a4)
        move.w  d0,M_VYS(a4)
        move.w  d0,M_VZS(a4)
        move.w  d0,M_VX(a4)
        move.w  d0,M_VY(a4)
        move.w  d0,M_VZ(a4)
        move.w  d0,M_T400(a4)
        move.w  d0,M_F7ED(a4)
        move.w  d0,M_F7EF(a4)
        move.w  d0,M_E7(a4)
        move.w  #$FF,M_CF(a4)
        bset    #EV_RESPAWN,M_EVENTS+1(a4)
        rts

;-----------------------------------------------------------------------------
; camera (one player): while the marble rolls (or waits)
; and races, keep its screen y in [$40, $90): one line a frame. The view never
; goes above scroll $F8. Uses S from the previous frame.
;-----------------------------------------------------------------------------
camera:
        cmpi.w  #5,G_RACE(a6)           ; Ultimate from scroll $02D6: down
        bne.s   .a0                     ; every frame (to the goal maze)
        cmpi.w  #$2D6,M_SCROLL(a4)
        bhs     scroll_down
.a0:    tst.b   M_RACING+1(a4)
        beq     .out
        tst.b   M_GND+1(a4)
        beq     .out
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_ROLL,d0
        beq     .act
        cmpi.w  #ST_WAIT,d0
        beq     .act
        cmpi.w  #ST_OFFTOP,d0
        beq.s   .act
        cmpi.w  #ST_FUNNEL,d0           ; (and $1B / $1C, the funnel)
        beq.s   .act
        cmpi.w  #ST_FUNNEL2,d0
        bne     .out
.act:   move.w  M_S(a4),d0
        cmpi.w  #4,G_RACE(a6)
        beq.s   .sil
        cmpi.w  #$8090,d0
        bhs     scroll_down
        cmpi.w  #$8040,d0
        blo     scroll_up
.out:   rts
.sil:   ; Silly tests a MIRRORED screen y: high $80: low = $FF - low; else
        ; both bytes negated separately (the high byte's +1 takes the low's carry)
        move.w  d0,d1
        lsr.w   #8,d1
        cmpi.b  #$80,d1
        bne.s   .neg
        not.b   d0
        bra.s   .t4
.neg:   moveq   #0,d2
        tst.b   d0
        bne.s   .nz
        moveq   #1,d2
.nz:    neg.b   d0
        not.b   d1
        addq.b  #1,d1
        add.b   d2,d1
        lsl.w   #8,d1
        move.b  d0,d1
        move.w  d1,d0
.t4:    cmpi.w  #$8090,d0               ; the directions swapped
        bhs     scroll_up
        cmpi.w  #$8040,d0
        blo     scroll_down
        rts

; scroll_down / scroll_up - the race's trigger list; at an
; entry EQUAL to the scroll whose zone has bit 7: stop (the scroll limit); else
; move one line (a zone start there needs nothing: the QL's
; bitmap has the zones built in). Up never goes above $F8.
scroll_down:
        movea.l G_PGEO(a6),a5
        lea     GEO_TDN(a5),a0
        bsr.s   trig
        bne.s   .o
        addq.w  #1,M_SCROLL(a4)
.o:     rts
scroll_up:
        movea.l G_PGEO(a6),a5
        lea     GEO_TUP(a5),a0
        bsr.s   trig
        bne.s   .o
        move.w  M_SCROLL(a4),d0
        subq.w  #1,d0
        cmpi.w  #$F8,d0
        bhs.s   .st
        move.w  #$F8,d0
.st:    move.w  d0,M_SCROLL(a4)
.o:     rts
; trig - Z clear = move; Z set (ne) = stop here. a0 = the list (word, zone, 0)
trig:   move.w  M_SCROLL(a4),d0
.w:     cmp.w   (a0),d0
        blo.s   .mv
        beq.s   .eq
        addq.l  #4,a0
        bra.s   .w
.eq:    tst.b   2(a0)
        bmi.s   .st
        cmpi.b  #WV_ZONE,2(a0)          ; Intermediate's zone 2: its load's end
        bne.s   .mv                     ; starts the waves (WV_DELAY steps on)
        cmpi.w  #2,G_RACE(a6)
        bne.s   .mv
        move.w  #WV_DELAY,M_ZCD(a4)
.mv:    moveq   #0,d0
        rts
WV_ZONE         equ     2
WV_DELAY        equ     38              ; zone 2's load time + 2
.st:    moveq   #1,d0
        rts

;-----------------------------------------------------------------------------
; screen_h - d0.w = (X + Y) / 2 (with the fractions' carry)
;-----------------------------------------------------------------------------
screen_h:
        move.l  M_X(a4),d0
        add.l   M_Y(a4),d0
        lsr.l   #8,d0
        andi.l  #$FFFF,d0
        lsr.w   #1,d0
        rts

;-----------------------------------------------------------------------------
; kill_check - behind-scenery death: on even
; frames (1 player) the occluder lists of the marble's screen columns are
; walked like the masking code does; a mask code with bit 7 kills it. Columns
; 0-2 (narrow) / 0-3 (dizzy, wide); the third 8-line band only when the sprite
; is not band-aligned.
;-----------------------------------------------------------------------------
KC_ROW          equ     0               ; locals on the stack (words)
KC_X8           equ     2
KC_Y8           equ     4
KC_Z            equ     6
KC_NROW         equ     8
KC_SIZE         equ     10

kill_check:
        ifeq    RELB
        tst.w   G_NOKILL(a6)            ; (LAB only: timing without the check)
        bne     .out
        endc
        btst    #0,M_FC+1(a4)
        bne     .out
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_ROLL,d0
        beq     .go
        cmpi.w  #ST_BROKEN,d0
        beq     .go
        cmpi.w  #ST_SINK,d0
        bne     .out
.go:    ; quick test (GEO_KMAP): can any of the marble's columns kill at its row?
        ; (X+Y)/2 + Z = S + scroll - $C0: S was set just before, for this frame
        move.w  M_S(a4),d1
        add.w   M_SCROLL(a4),d1
        subi.w  #$C0+$7F3F,d1
        lsr.w   #1,d1
        andi.w  #$FF<<2,d1              ; row (8-line band) x 4
        movea.l G_PGEO(a6),a0
        adda.l  #GEO_KMAP,a0            ; (past 32 KB: not a displacement)
        move.l  0(a0,d1.w),d1           ; the columns where this row can kill
        beq.s   .none                   ; (the usual case)
        moveq   #8,d3
        moveq   #7,d4                   ; 3 columns
        move.w  M_FID(a4),d0
        cmpi.w  #3,d0
        blo.s   .qn
        cmpi.w  #10,d0
        bhs.s   .qn
        moveq   #$0C,d3
        moveq   #15,d4                  ; 4 columns
.qn:    move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        lsr.l   #8,d0
        subi.b  #$80,d0
        sub.b   d3,d0
        andi.w  #$FF,d0
        lsr.w   #3,d0                   ; first column
        ror.l   d0,d1
        and.l   d4,d1
        bne.s   .walk
.none:  rts
.walk:  lea     -KC_SIZE(sp),sp
        move.l  M_Z(a4),d1
        lsr.l   #8,d1
        bsr     screen_h
        add.w   d1,d0
        subi.w  #$7F3F,d0
        moveq   #2,d1
        moveq   #7,d2
        and.w   d0,d2
        beq     .r2
        moveq   #3,d1
.r2:    move.w  d1,KC_NROW(sp)
        lsr.w   #3,d0
        andi.w  #$FF,d0
        move.w  d0,KC_ROW(sp)
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        lsr.w   #3,d0
        andi.w  #$FF,d0
        move.w  d0,KC_X8(sp)
        move.l  M_Y(a4),d0
        lsr.l   #8,d0
        lsr.w   #3,d0
        andi.w  #$FF,d0
        move.w  d0,KC_Y8(sp)
        moveq   #0,d0
        move.b  M_Z+2(a4),d0
        move.w  d0,KC_Z(sp)
        ; first column: ((X - Y)lo - $80 - w) >> 3, w = 8 (12 if dizzy-wide)
        moveq   #8,d6
        moveq   #3,d7                   ; columns
        move.w  M_FID(a4),d0
        cmpi.w  #3,d0
        blo     .nar
        cmpi.w  #10,d0
        bhs     .nar
        moveq   #$0C,d6
        moveq   #4,d7
.nar:   move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        lsr.l   #8,d0
        subi.b  #$80,d0
        sub.b   d6,d0
        andi.w  #$FF,d0
        lsr.w   #3,d0
        move.w  d0,d6                   ; column
        movea.l G_PGEO(a6),a5
        lea     GEO_OHGT(a5),a2
        lea     GEO_OSHP(a5),a3
        subq.w  #1,d7
.col:   andi.w  #31,d6
        move.w  d6,d0
        add.w   d0,d0
        lea     GEO_OCOL(a5),a0
        move.w  0(a0,d0.w),d0
        lea     0(a5,d0.w),a0           ; the column's list
        bsr     col_codes               ; a1 = 3 codes or 0
        move.l  a1,d0
        beq     .nc
        move.w  KC_NROW(sp),d0
        subq.w  #1,d0
.cd:    tst.b   (a1)+
        bmi     .kill
        dbra    d0,.cd
.nc:    addq.w  #1,d6
        dbra    d7,.col
        lea     KC_SIZE(sp),sp
.out:   rts
.kill:  lea     KC_SIZE(sp),sp
        move.w  #ST_DEAD,M_STATE(a4)
        move.w  #9,M_GND(a4)
        bset    #EV_KILL,M_EVENTS+1(a4)
        rts

; col_codes - one column's occluder walk. In: a0 = list,
; a5 = geo, a2 = type heights, a3 = type shapes, locals at 4(sp).
; Out: a1 = the 3 mask codes, or 0 (none).
; Uses d0-d5.
col_codes:
        move.w  4+KC_ROW(sp),d5         ; row (0-255)
.ent:   move.b  1(a0),d1                ; type
        cmpi.b  #$FF,d1
        beq     .none
        cmp.b   (a0),d5                 ; end
        blo.s   .hit
        tst.b   d1                      ; ends above the marble: the next entry
        bmi.s   .s3                     ; (3 B, or 4 with a parameter)
        btst    #5,2(a0)
        beq.s   .s3
        addq.w  #1,a0
.s3:    addq.w  #3,a0
        bra.s   .ent
.hit:   moveq   #0,d0
        move.b  (a0),d0
        andi.w  #$FF,d1
        moveq   #3,d4                   ; entry length
        tst.b   d1
        bmi.s   .len
        btst    #5,2(a0)
        beq.s   .len
        moveq   #4,d4
.len:   andi.w  #$7F,d1
        moveq   #0,d2
        move.b  0(a2,d1.w),d2
        sub.b   d2,d0                   ; start (8-bit)
        cmp.b   d5,d0
        bhs     .none                   ; sorted: nothing covers it
        move.w  d0,d3                   ; start
        btst    #7,1(a0)
        beq     .norm
        tst.b   M_GND+1(a4)             ; special entry: only while airborne
        bne     .skip
        move.b  2(a0),d0                ; param
        bra     .param
.norm:  move.b  2(a0),d2                ; flags
        bmi     .f80
        btst    #6,d2
        beq     .f1e
        tst.b   M_BC+1(a4)
        bne     .skip
        bra     .f80
.f1e:   tst.b   M_GND+1(a4)
        bne     .skip
.f80:   moveq   #$1F,d0
        and.b   d2,d0
        beq     .flagok
        cmpi.b  #1,d0
        bne.s   .f2
        btst    #6,M_F9D+1(a4)          ; low 1: only when M_F9D bit 6
        beq     .skip
        bra     .flagok
.f2:    cmpi.b  #6,d0
        bhs     .f6
        subq.b  #2,d0                   ; low 2..5: only when M_F7F1 = low-2
        cmp.b   M_F7F1+1(a4),d0
        bne     .skip
        bra     .f1f
.f6:    subq.b  #6,d0                   ; low >= 6: not when M_F7F1 = low-6
        cmp.b   M_F7F1+1(a4),d0
        beq     .skip
.f1f:   tst.b   M_GND+1(a4)
        beq     .flagok
        cmpi.w  #$54,4+KC_Z(sp)
        bne     .skip
.flagok:
        btst    #5,d2
        beq     .use
        move.b  3(a0),d0                ; param
.param: tst.b   d0
        bmi     .py
        cmp.b   4+KC_X8+1(sp),d0
        bls     .skip                   ; not in front of the marble
        bra     .use
.py:    andi.b  #$7F,d0
        cmp.b   4+KC_Y8+1(sp),d0
        bls     .skip
.use:   move.w  d5,d0
        sub.w   d3,d0                   ; row - start
        andi.w  #$FF,d0
        add.w   d1,d1
        movea.l a5,a1
        adda.w  0(a3,d1.w),a1
        adda.w  d0,a1
        rts
.skip:  adda.w  d4,a0
        bra     .ent
.none:  suba.l  a1,a1
        rts
