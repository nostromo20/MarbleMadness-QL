; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; mobj.asm - Marble Madness QL: the course objects in slots 2-7 (the steelie,
; the falling object, the static flags / rails / GOAL text) and the spawn
; walker.
;
; Each object has a block in the marble block's layout (M_*, G_OBJ + (slot -
; 2) * M_SIZE) with M_SLOT = its slot, so the marble's own routines (accel,
; integrate, side_bounce, wall_bounce, surface, slope) run on it unchanged;
; they skip the player-only parts when M_SLOT is not 0 (slots 0-1 = players).
; Shared state (frame counter, scroll, M_F9D/M_F9B/M_F8, the freeze, M_F5CE)
; lives in the player's block and is copied in before an object runs; an
; object's M_E2 ALIASES one of the player's bytes (obj_frame).
; The slots run 7 -> 0: objects before the player.
;=============================================================================

ST_STEELIE      equ     $18
ST_FALL1        equ     $2B
ST_FALL2        equ     $2C

; OBJ_TOP - d7.w = slot bits (2-7, high byte 0): d6 = the highest slot, a4 = its
; block, d7.b shifted so that slot's bit is bit 7 (then a walk down the blocks,
; add.b d7,d7 per slot). Uses d0/a0.
OBJ_TOP macro
        lea     obj_hibit(pc),a0
        move.b  0(a0,d7.w),d6
        andi.w  #7,d6
        moveq   #7,d0
        sub.w   d6,d0
        lsl.b   d0,d7
        move.w  d6,d0
        add.w   d0,d0
        lea     obj_boff(pc),a0
        move.w  0(a0,d0.w),d0
        lea     0(a6,d0.w),a4
        endm

;-----------------------------------------------------------------------------
; objects_pre - the object slots 7-2, from marble_frame after the freeze
; event. Only for the real marble (not the measuring ghosts) and when the
; race has objects (G_OBJON). Preserves a4.
;-----------------------------------------------------------------------------
objects_pre:
        lea     G_MB(a6),a0
        cmpa.l  a0,a4
        bne     .o
        tst.w   G_OBJON(a6)
        beq     .o
        ifeq    RELB
        cmpi.w  #8,G_MODE(a6)           ; measuring mode 8: no objects
        beq     .o
        endc
        tst.b   M_FC+1(a4)              ; G_WF7DD + 4 when the frame counter wraps
        bne.s   .f
        addq.w  #4,G_WF7DD(a6)
        andi.w  #$0C,G_WF7DD(a6)
.f:     clr.w   G_RANM(a6)
        moveq   #3,d0               ; 30 Hz: the slots due this frame (G_DUE by
        and.b   M_FC+1(a4),d0           ; frame & 3, obj_mark: the slot's parity, odd
        lea     G_DUE(a6),a0            ; frames, or 15 Hz)
        moveq   #0,d7
        move.b  0(a0,d0.w),d0
.du:    move.b  G_MOVM+1(a6),d7         ; the slots with logic (obj_mark): the
        and.b   d0,d7
        andi.b  #$FC,d7                 ; (slots 2-7 only)
        beq     .o                      ; steelie, the falling object (the statics are
        move.b  d7,G_RANM+1(a6)         ; baked into the bitmap; their frame and
        move.l  a4,-(sp)                ; attribute are display only: not kept)
        OBJ_TOP                         ; the highest slot first (7 -> 2): a walk
.s:     add.b   d7,d7                   ; (this slot's bit out)
        bcc.s   .nx
.run:   movem.w d6-d7,-(sp)
        bsr     obj_frame
        movem.w (sp)+,d6-d7
        tst.w   M_DRAWN(a4)             ; drawn: its screen y's base (X + Y) / 2 + Z
        beq.s   .skip                   ; (objects_post: - (scroll - $C0) every frame)
        move.l  M_X(a4),d0
        add.l   M_Y(a4),d0
        lsr.l   #8,d0
        lsr.w   #1,d0
        move.l  M_Z(a4),d1
        lsr.l   #8,d1
        add.w   d1,d0
        move.w  d0,M_SB(a4)
.skip:
.nx:    lea     -M_SIZE(a4),a4
        subq.w  #1,d6
        tst.b   d7
        bne.s   .s
        movea.l (sp)+,a4
.o:     rts

; obj_odd - per state, its rate class: 0 = 30 Hz on its slot's parity, 2 = 30 Hz on
; the odd frames (acid pools: their own logic is on odd frames), 4 = 15 Hz (mini
; marbles: one run a 4-frame block, on frame & 3 = 1: the touch-test frame)
obj_odd:
        dc.b    0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0     ; $00-$0F ($0A acid pool)
        dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,4     ; $10-$1F ($1D, $1F)
        dc.b    4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; $20-$2F ($20, $21)
        even
; obj_rate - per rate class + slot parity: the frames (& 3) it runs on, bit per frame
obj_rate:
        dc.b    %0101,%1010             ; 30 Hz, its slot's parity (even, odd slot)
        dc.b    %1010,%1010             ; 30 Hz, odd frames
        dc.b    %0010,%0010             ; 15 Hz
        even

; obj_boff - the block of slot n (from a6); obj_hibit - the highest set bit
obj_boff:
        dc.w    0,0,G_OBJ,G_OBJ+M_SIZE,G_OBJ+2*M_SIZE,G_OBJ+3*M_SIZE,G_OBJ+4*M_SIZE,G_OBJ+5*M_SIZE
obj_hibit:
n       set     0
        rept    256
b       set     0
        ifne    n&$80
b       set     7
        else
        ifne    n&$40
b       set     6
        else
        ifne    n&$20
b       set     5
        else
        ifne    n&$10
b       set     4
        else
        ifne    n&$08
b       set     3
        else
        ifne    n&$04
b       set     2
        else
        ifne    n&$02
b       set     1
        endc
        endc
        endc
        endc
        endc
        endc
        endc
        dc.b    b
n       set     n+1
        endr

; obj_mark - G_MOVM's bit for the object at a4: set for the types with logic
; (an entry in obj_jt)
obj_mark:
        move.w  M_SLOT(a4),d0
        move.w  M_STATE(a4),d1
        cmpi.w  #$30,d1
        bhs.s   .clr
        add.w   d1,d1
        lea     obj_jt(pc),a0
        tst.w   0(a0,d1.w)
        beq.s   .clr
        bset    d0,G_MOVM+1(a6)
        lsr.w   #1,d1                   ; (its rate class: G_DUE's bit for each
        lea     obj_odd(pc),a0          ;  frame & 3)
        move.b  0(a0,d1.w),d1
        btst    #0,d0
        beq.s   .ev
        addq.b  #1,d1
.ev:    lea     obj_rate(pc),a0
        move.b  0(a0,d1.w),d1
        lea     G_DUE(a6),a0
        bclr    d0,(a0)
        lsr.b   #1,d1
        bcc.s   .r1
        bset    d0,(a0)
.r1:    bclr    d0,1(a0)
        lsr.b   #1,d1
        bcc.s   .r2
        bset    d0,1(a0)
.r2:    bclr    d0,2(a0)
        lsr.b   #1,d1
        bcc.s   .r3
        bset    d0,2(a0)
.r3:    bclr    d0,3(a0)
        lsr.b   #1,d1
        bcc.s   .r4
        bset    d0,3(a0)
.r4:    rts
.clr:   bclr    d0,G_MOVM+1(a6)
        rts

; obj_frame - one object (a4): its handler by state (obj_jt). The types with
; a surface lookup (negative entries) get the player's shared state copied in
; and M_F5CE copied back; the others share only the frame counter.
obj_frame:
        lea     G_MB(a6),a3             ; (the shared state an object's code reads)
        move.w  M_FC(a3),M_FC(a4)
        clr.w   M_DRAWN(a4)
        move.w  M_STATE(a4),d0
        add.w   d0,d0
        lea     obj_jt(pc),a0
        move.w  0(a0,d0.w),d1
        bmi.s   .look
        jmp     0(a0,d1.w)              ; (returns to objects_pre)
.look:  neg.w   d1
        move.w  M_F9D(a3),M_F9D(a4)     ; (the lookup reads these)
        move.w  M_F9B(a3),M_F9B(a4)
        move.w  M_F8(a3),M_F8(a4)
        move.w  M_F5CE(a3),M_F5CE(a4)   ; (written back after: kept if no lookup)
        cmpi.w  #2*ST_STEELIE,d0
        bne.s   .g
        ; M_E2 for an object (the surface code reads it unguarded): it aliases
        ; a per-slot byte of the shared state
        move.w  M_SLOT(a4),d0
        subq.w  #2,d0
        beq.s   .e4                     ; slot 2: player 1's M_E4
        subq.w  #1,d0
        beq.s   .e5                     ; 3: G_WE5 (player 2's, as at the start)
        subq.w  #2,d0
        beq.s   .e7                     ; 5: player 1's M_E7
        subq.w  #1,d0
        beq.s   .e8                     ; 6: G_WE8
        bmi.s   .g                      ; 4: the last lookup's (surface)
        move.w  #$FF,M_E2(a4)           ; 7: the lookup flag
        bra.s   .g
.e4:    move.w  M_E4(a3),M_E2(a4)
        bra.s   .g
.e5:    move.w  G_WE5(a6),M_E2(a4)
        bra.s   .g
.e7:    move.w  M_E7(a3),M_E2(a4)
        bra.s   .g
.e8:    move.w  G_WE8(a6),M_E2(a4)
.g:     cmpi.w  #ST_STEELIE,M_STATE(a4) ; (the other lookup types: a slinky off its
        bne.s   .two                    ; path)
        jsr     0(a0,d1.w)
.wb:    lea     G_MB(a6),a3             ; (M_F5CE: every lookup writes it)
        move.w  M_F5CE(a4),M_F5CE(a3)
        rts
; a slinky off its path (lunge, jump, fall, rest) at 30 Hz runs both logic steps
; of its pair, one after the other: frame fc & ~1, then fc | 1, each by its state
; then (its frame tests, counters, the jump's aim / integration / gravity per
; step); the touch test on frame & 3 = 1 (G_OSUB).
.two:   move.w  M_FC(a4),-(sp)
        move.w  #1,G_OSUB(a6)
        andi.w  #$FE,M_FC(a4)
        jsr     0(a0,d1.w)
        ori.w   #1,M_FC(a4)
        move.w  M_STATE(a4),d0
        bsr     slink_state
        bne.s   .t2
        clr.w   M_DRAWN(a4)
        add.w   d0,d0
        lea     obj_jt(pc),a0
        move.w  0(a0,d0.w),d1
        bpl.s   .t3                     ; (walking again: no lookup)
        neg.w   d1
.t3:    jsr     0(a0,d1.w)
.t2:    clr.w   G_OSUB(a6)
        move.w  (sp)+,M_FC(a4)
        bra.s   .wb

; obj_jt - per state $00-$2F: 0 no logic (statics, types not modelled); the
; handler's offset from obj_jt; negated: a handler that looks up the surface
JT      macro
        dc.w    \1-obj_jt
        endm
JTL     macro
        dc.w    obj_jt-\1
        endm
obj_jt: dc.w    0,0,0,0,0,0,0,0,0,0     ; $00-$09
        JT      st_acid                 ; $0A acid pool
        dc.w    0,0,0,0,0               ; $0B-$0F
        JT      st_slinky               ; $10 slinky (walking: no lookup, so none
                                        ; of the shared lookup state)
        JTL     st_sljump               ; $11
        JTL     st_slfall               ; $12
        JTL     st_slrest               ; $13
        dc.w    0,0,0,0                 ; $14-$17
        JTL     st_steelie              ; $18 steelie
        dc.w    0                       ; $19
        JTL     st_sllunge              ; $1A
        dc.w    0,0                     ; $1B-$1C
        JT      st_acidhas              ; $1D acid pool holding the player
        dc.w    0                       ; $1E
        JT      st_mini                 ; $1F-$21 mini marbles
        JT      st_mini
        JT      st_mini
        JT      st_birdc0b4             ; $22 bird coming in
        JT      st_bird                 ; $23 flying
        JT      st_birdturn             ; $24 turning
        JT      st_birdc0b4             ; $25 going out
        dc.w    0,0                     ; $26-$27 (a piston: display only)
        JT      st_hammer               ; $28 hammer
        JT      st_vacuum               ; $29 vacuum
        dc.w    0                       ; $2A
        JT      st_ofall                ; $2B-$2C falling
        JT      st_ofall
        JT      st_pistons              ; $2D the piston group (once)
        dc.w    0,0                     ; $2E-$2F

;-----------------------------------------------------------------------------
; st_steelie - the steelie: off the top it goes for good; with a home
; (M_O6CF) it goes (and may come back) when not on the screen. Every 8
; frames it aims: at the nearest player near its home and level with it
; (obj_target), else at its home (obj_home); it accelerates by 12 + race.
; It is always "on the ground" (vz $400 down, window $F8), moves (and a
; second X/Y move on every 4th frame), bounces off the screen edges; on a
; surface or a wall it stays; in the air it is held up and turned back, unless
; it was hit in the last 16 frames (M_O5C1): then it falls (state $2B). Then
; the collision with player 1 (obj_collide): a hit sets M_O5C1 = 16.
;-----------------------------------------------------------------------------
st_steelie:
        move.b  M_S(a4),d0              ; the screen y's high byte
        bpl     .gone                   ; above the screen top
        tst.b   M_O6CF+1(a4)
        beq.s   .ok
        cmpi.b  #$80,d0
        bne     .away                   ; (off the screen, with a home)
.ok:    move.b  M_O5C1+1(a4),d0         ; (30 Hz: two frames a run)
        subq.b  #2,d0
        bcc.s   .c0
        moveq   #0,d0
.c0:    move.b  d0,M_O5C1+1(a4)
.c:     moveq   #$0C,d7
        add.w   G_RACE(a6),d7           ; d7 = 12 + race
        moveq   #6,d0                   ; aim every 8 frames
        and.b   M_FC+1(a4),d0
        bne.s   .keep
        bsr     obj_target
        tst.b   d0
        bpl.s   .t
        bsr     obj_home
.t:     andi.w  #$FF,d0
        move.w  d0,M_T400(a4)
.keep:  move.w  M_T400(a4),d6           ; the first frame's push (d7 = 12 + race)
        btst    #0,d6
        beq.s   .a1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        move.w  d7,d1
        bsr     accel_pos       ; +Y
.a1:    btst    #1,d6
        beq.s   .a2
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        move.w  d7,d1
        bsr     accel_pos       ; +X
.a2:    btst    #2,d6
        beq.s   .a3
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        move.w  d7,d1
        bsr     accel_neg       ; -Y
.a3:    btst    #3,d6
        beq.s   .a4
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        move.w  d7,d1
        bsr     accel_neg       ; -X
.a4:    move.w  #$400,M_VZ(a4)          ; always "on the ground"
        clr.w   M_VZS(a4)
        move.w  #$F0,M_DD(a4)           ; (the 8-px snap window $F8, doubled for the two
                                        ;  steps' falls before this one lookup at 30
                                        ;  Hz: 16 px. With 8 a steelie climbs nothing:
                                        ;  every rise is a wall; Beginner's, which starts
                                        ;  4 px under its ramp, would bounce on the spot)
        move.l  M_X(a4),M_PX(a4)
        move.l  M_Y(a4),M_PY(a4)
        bsr     integrate
        btst    #1,M_FC+1(a4)
        bne.s   .two
        bsr     integrate_xy            ; an extra move every 4 frames (frame & 3 =
                                        ;  0: the pair's first)
.two:                                   ; (30 Hz: the second frame's push and move after
                                        ;  the first's: with both pushes first it runs a
                                        ;  push ahead and drifts off its 60 Hz path, so
                                        ;  its next aim comes out another way)
        btst    #0,d6
        beq.s   .b1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        move.w  d7,d1
        bsr     accel_pos       ; +Y
.b1:    btst    #1,d6
        beq.s   .b2
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        move.w  d7,d1
        bsr     accel_pos       ; +X
.b2:    btst    #2,d6
        beq.s   .b3
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        move.w  d7,d1
        bsr     accel_neg       ; -Y
.b3:    btst    #3,d6
        beq.s   .b4
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        move.w  d7,d1
        bsr     accel_neg       ; -X
.b4:    bsr     integrate
.side:  move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        lsr.l   #8,d0
        subi.b  #$80,d0
        cmpi.b  #8,d0
        blo.s   .sb
        cmpi.b  #$F9,d0
        blo.s   .look
.sb:    bsr     side_bounce
.look:  bsr     surface                 ; (a wall: bounced and Z - 4 there)
        tst.w   d0
        beq.s   .tail
        tst.b   M_O5C1+1(a4)            ; in the air
        bne.s   .fall
        subi.l  #$800,M_Z(a4)           ; (30 Hz: two frames' fall)
        bsr     wall_bounce             ; turned back
        bra.s   .tail
.fall:  subi.l  #$700,M_Z(a4)           ; knocked off: it falls (30 Hz: + 4)
        move.w  #$80,M_VZ(a4)
        move.w  #ST_FALL1,M_STATE(a4)
        clr.w   M_T400(a4)
        bset    #1,G_MSFX+3(a6)         ; (effect 1: off the course; src/music.asm)
        bsr     steelie_pts             ; +1,000 to the player in play
.tail:  move.w  #1,M_ATTR(a4)
        bsr     obj_collide
        tst.w   d0
        beq.s   .f
        move.w  #$10,M_O5C1(a4)
.f:     move.w  #$44,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.gone:  moveq   #-1,d0
        bra.s   obj_despawn
.away:  moveq   #0,d0
; obj_despawn - state 0; its spawn entry: d0.b ($FF never again, 0 again)
obj_despawn:
        move.w  M_O5B9(a4),d1
        lea     G_WA5A9(a6),a0
        move.b  d0,0(a0,d1.w)
        clr.w   M_STATE(a4)
        move.w  M_SLOT(a4),d0
        bclr    d0,G_MOVM+1(a6)
        rts

;-----------------------------------------------------------------------------
; st_ofall - a falling object (states $2B / $2C): a counter (M_O6CF);
; every 16 frames a step (M_T400) of frames $69-$6C; at step 5 the
; next state; from step 10 nothing shows and after $70 frames it is gone.
;-----------------------------------------------------------------------------
st_ofall:
        addq.b  #2,M_O6CF+1(a4)         ; (30 Hz: two frames a run)
        moveq   #$0E,d0
        and.b   M_FC+1(a4),d0           ; every 16 frames
        bne.s   .a
        addq.b  #1,M_T400+1(a4)
        cmpi.b  #5,M_T400+1(a4)
        bne.s   .a
        addq.w  #1,M_STATE(a4)
        clr.w   M_O6CF(a4)
.a:     moveq   #0,d0
        move.b  M_T400+1(a4),d0
        cmpi.b  #$0A,d0
        bhs.s   .b
        move.b  .tab(pc,d0.w),d0
        bra.s   .fid
.b:     cmpi.b  #$70,M_O6CF+1(a4)
        bhs.s   .gone
        moveq   #0,d0
.fid:   move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.gone:  moveq   #-1,d0
        bra.s   obj_despawn
.tab:   dc.b    $69,$69,$69,$69,$6A,$6B,$6C,$6C,$6C,$6C
        even

;-----------------------------------------------------------------------------
; obj_target - the steering bits towards player 1 if it rolls
; (state 1 or $2A) on the ground, not frozen, within $30 (X + Y distance) of
; the object's HOME point and level with the object (or at most 8 below);
; else d0.b = $FF. obj_home - the bits towards the home point.
; obj_dirbits - from d0.w = dx, d2.w = dy (object - target): X: 8 (-) if dx
; >= 0 else 2 (+); Y: 4 (-) if dy >= 0 else 1 (+); code 2: Y only.
;-----------------------------------------------------------------------------
obj_target:
        lea     G_MB(a6),a3
        bsr     obj_homexy              ; d4 / d5 = home X / Y
        tst.b   M_F5CB+1(a3)
        bne     .none
        move.w  M_STATE(a3),d0
        cmpi.w  #1,d0
        beq.s   .e
        cmpi.w  #$2A,d0
        bne     .none
.e:     tst.b   M_GND+1(a3)
        beq     .none
        move.l  M_X(a3),d0
        lsr.l   #8,d0
        move.w  d4,d1
        sub.w   d0,d1
        bcc.s   .x1
        neg.w   d1
.x1:    move.l  M_Y(a3),d0
        lsr.l   #8,d0
        move.w  d5,d2
        sub.w   d0,d2
        bcc.s   .y1
        neg.w   d2
.y1:    add.w   d2,d1
        bcc.s   .s1
        ori.w   #$FF00,d1
.s1:    cmpi.w  #$30,d1
        bhs.s   .none
        move.l  M_Z(a4),d0
        lsr.l   #8,d0
        move.l  M_Z(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        beq.s   .zok
        cmpi.w  #$FFF8,d0
        blo.s   .none
.zok:   move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_X(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        move.l  M_Y(a4),d2
        lsr.l   #8,d2
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d2
        bra.s   obj_dirbits
.none:  moveq   #-1,d0
        rts

obj_home:
        bsr     obj_homexy
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        sub.w   d4,d0
        move.l  M_Y(a4),d2
        lsr.l   #8,d2
        sub.w   d5,d2
obj_dirbits:
        moveq   #8,d1
        tst.w   d0
        bpl.s   .x
        moveq   #2,d1
.x:     moveq   #4,d0
        tst.w   d2
        bpl.s   .y
        moveq   #1,d0
.y:     cmpi.w  #2,M_CODE(a4)
        beq.s   .o
        or.b    d1,d0
.o:     rts

; obj_homexy - d4.w / d5.w = the home point numbered by M_O6CF (& 3)
obj_homexy:
        moveq   #3,d0
        and.w   M_O6CF(a4),d0
        moveq   #0,d4
        move.b  .xh(pc,d0.w),d4
        lsl.w   #8,d4
        move.b  .xl(pc,d0.w),d4
        moveq   #0,d5
        move.b  .yh(pc,d0.w),d5
        lsl.w   #8,d5
        move.b  .yl(pc,d0.w),d5
        rts
.xl:    dc.b    $DC,$08,$5C,$60
.xh:    dc.b    $00,$02,$01,$02
.yl:    dc.b    $94,$A8,$B8,$50
.yh:    dc.b    $00,$01,$01,$02

;-----------------------------------------------------------------------------
; obj_collide - (G_DC = 0; the obj_collideNN entries set other modes): on
; frames with frame & 3 = 1 (player 1's turn), player 1 rolling, not frozen:
; a hit when |dZ| < 12, |dX| < 8 and 2|dY| < 8. Then both get a push of the
; angle table (.ang): the
; object away from the player and the player the other way (twice for the
; player), each axis's sign then forced. Out: d0.w = 1 on a hit.
;-----------------------------------------------------------------------------
obj_collide1:
        move.w  #1,G_DC(a6)
        bra.s   obj_coll
obj_collideFE:
        move.w  #$FE,G_DC(a6)
        bra.s   obj_coll
obj_collide80:
        move.w  #$80,G_DC(a6)
        bra.s   obj_coll
obj_collideFF:
        move.w  #$FF,G_DC(a6)
        bra.s   obj_coll
obj_collide:
        clr.w   G_DC(a6)
obj_coll:
        lea     G_MB(a6),a3
        tst.b   M_F5CB+1(a3)
        bne     .no
        tst.w   G_OSUB(a6)              ; (a slinky's logic step: frame & 3 = 1)
        bne.s   .sub
        btst    #1,M_FC+1(a4)           ; (30 Hz: frame & 2 = 0; at 60 Hz: frame & 3 = 1)
        bne     .no
        bra.s   .ph
.sub:   moveq   #3,d0
        and.b   M_FC+1(a4),d0
        subq.b  #1,d0
        bne     .no
.ph:
        cmpi.w  #1,M_STATE(a3)
        bne     .no
        moveq   #0,d3                   ; d3: bit 0 dX < 0, bit 1 dY < 0
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_X(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        cmpi.w  #$100,d0
        blo.s   .xo
        tst.w   d0
        bpl     .no
        neg.w   d0
        cmpi.w  #$100,d0
        bhs     .no
        addq.w  #1,d3
.xo:    move.l  M_Y(a4),d2
        lsr.l   #8,d2
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d2
        cmpi.w  #$100,d2
        blo.s   .yo
        tst.w   d2
        bpl     .no
        neg.w   d2
        cmpi.w  #$100,d2
        bhs     .no
        addq.w  #2,d3
.yo:    cmpi.b  #$80,G_DC+1(a6)         ; (G_DC = $80: dY not doubled)
        beq.s   .y1
        add.w   d2,d2
.y1:    cmpi.w  #8,d0
        bhs     .no
        cmpi.w  #8,d2
        bhs     .no
        move.l  M_Z(a4),d1              ; (the depths last: every test only rejects)
        lsr.l   #8,d1
        move.l  M_Z(a3),d4
        lsr.l   #8,d4
        sub.w   d4,d1
        bpl.s   .z
        neg.w   d1
.z:     cmpi.w  #$0C,d1
        bhs     .no
        move.w  d0,G_C14(a6)            ; (|dX| / |dY| kept)
        move.w  d2,G_C15(a6)
        lsl.w   #3,d2
        add.w   d0,d2
        moveq   #0,d4
        move.b  .ang(pc,d2.w),d4        ; the angle
        cmpi.w  #$0A,M_STATE(a4)        ; (an acid pool, or G_DC = $FE: no push)
        beq     .hit
        tst.b   G_DC+1(a6)
        bmi     .hit
        cmpi.w  #1,d3
        beq.s   .fl
        cmpi.w  #2,d3
        bne.s   .nf
.fl:    moveq   #$3F,d0
        sub.b   d4,d0
        move.b  d0,d4
.nf:    bset    #3,G_MSFX+3(a6)         ; (effect 3: a bump)
        add.b   d4,d4
        add.b   d4,d4
        addq.b  #3,d4                   ; a = angle x 4 + 3
        moveq   #-1,d5
        sub.b   d4,d5
        andi.w  #$FF,d5                 ; b = $FF - a
        add.w   d3,d3
        add.w   d3,d3
        jmp     .case(pc,d3.w)
.case:  bra.w   .c0
        bra.w   .c1
        bra.w   .c2
        bra.w   .c3
.hit:   moveq   #1,d0
        rts
.no:    moveq   #0,d0
        rts
.ang:   dc.b    $1F,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$00,$1F,$2B,$31,$34,$36,$37,$38
        dc.b    $00,$12,$1F,$26,$2B,$2F,$31,$33,$00,$0C,$17,$1F,$24,$28,$2B,$2E
        dc.b    $00,$09,$12,$19,$1F,$23,$26,$29,$00,$07,$0F,$15,$1A,$1F,$22,$25
        dc.b    $00,$06,$0C,$12,$17,$1B,$1F,$22,$00,$05,$0A,$0F,$14,$18,$1C,$1F
; the pushes: a4 = the object, a3 = the player; d4 = a, d5 = b
.c0:    move.w  d4,d1
        bsr     .oxp
        move.w  d5,d1
        bsr     .oyp
        move.w  d4,d1
        bsr     .pxn
        move.w  d5,d1
        bsr     .pyn
        bra     .hit
.c1:    move.w  d5,d1
        bsr     .oxn
        move.w  d4,d1
        bsr     .oyp
        move.w  d5,d1
        bsr     .pxp
        move.w  d4,d1
        bsr     .pyn
        bra     .hit
.c2:    move.w  d5,d1
        bsr     .oxp
        move.w  d4,d1
        bsr     .oyn
        move.w  d5,d1
        bsr     .pxn
        move.w  d4,d1
        bsr     .pyp
        bra     .hit
.c3:    move.w  d4,d1
        bsr     .oxn
        move.w  d5,d1
        bsr     .oyn
        move.w  d4,d1
        bsr     .pxp
        move.w  d5,d1
        bsr     .pyp
        bra     .hit
; object pushes (once), player pushes (twice); then the sign forced
.oxp:   lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
        clr.w   M_VXS(a4)
        rts
.oxn:   lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
        move.w  #1,M_VXS(a4)
        rts
.oyp:   lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     accel_pos
        clr.w   M_VYS(a4)
        rts
.oyn:   lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     accel_neg
        move.w  #1,M_VYS(a4)
        rts
; the player: both pushes first, then the sign (twice only with G_DC = 0)
.pxp:   lea     M_VX(a3),a0
        lea     M_VXS(a3),a1
        bsr.s   .twice_p
        clr.w   M_VXS(a3)
        rts
.pxn:   lea     M_VX(a3),a0
        lea     M_VXS(a3),a1
        bsr.s   .twice_n
        move.w  #1,M_VXS(a3)
        rts
.pyp:   lea     M_VY(a3),a0
        lea     M_VYS(a3),a1
        bsr.s   .twice_p
        clr.w   M_VYS(a3)
        rts
.pyn:   lea     M_VY(a3),a0
        lea     M_VYS(a3),a1
        bsr.s   .twice_n
        move.w  #1,M_VYS(a3)
        rts
; (accel on the player's block: grow reads M_SLOT / M_E2 / M_FB through a4)
.twice_p:
        movem.l d1/a0-a1/a4,-(sp)
        movea.l a3,a4
        bsr     accel_pos
        tst.w   G_DC(a6)                ; (twice only with G_DC = 0)
        bne.s   .tp
        movem.l (sp),d1/a0-a1
        bsr     accel_pos
.tp:
        movem.l (sp)+,d1/a0-a1/a4
        rts
.twice_n:
        movem.l d1/a0-a1/a4,-(sp)
        movea.l a3,a4
        bsr     accel_neg
        tst.w   G_DC(a6)
        bne.s   .tn
        movem.l (sp),d1/a0-a1
        bsr     accel_neg
.tn:
        movem.l (sp)+,d1/a0-a1/a4
        rts

;-----------------------------------------------------------------------------
; objects_post - after the timer (from marble_frame, the real marble only):
; the drawn objects' screen y (with the player's scroll now; a shrinking
; object, state $2C, has its frame id spent: $FF); then on even frames the
; spawn walker.
;-----------------------------------------------------------------------------
objects_post:
        lea     G_MB(a6),a3
        cmpa.l  a3,a4
        bne     .o
        tst.w   G_OBJON(a6)
        beq     .o
        ifeq    RELB
        cmpi.w  #8,G_MODE(a6)
        beq     .o
        endc
        move.l  a4,-(sp)
        moveq   #0,d7
        move.b  G_RANM+1(a6),d7         ; (the objects that ran this frame)
        beq.s   .nd
        OBJ_TOP                         ; (a walk down from the highest)
.s:     add.b   d7,d7
        bcc.s   .n
        tst.w   M_DRAWN(a4)
        beq.s   .n
        move.w  M_SB(a4),d0             ; (its base, from its last run)
        sub.w   M_SCROLL(a3),d0
        addi.w  #$C0,d0
        move.w  d0,M_S(a4)
        cmpi.w  #ST_FALL2,M_STATE(a4)
        bne.s   .n
        tst.b   M_FID+1(a4)
        bmi.s   .n
        move.w  #$FF,M_FID(a4)
.n:     lea     -M_SIZE(a4),a4
        tst.b   d7
        bne.s   .s
.nd:    movea.l (sp)+,a4
        cmpi.w  #3,G_RACE(a6)           ; Aerial: the piston field,
        bne.s   .w                      ; (30 Hz: on the odd frames)
        btst    #0,M_FC+1(a4)
        beq.s   .w
        bsr     pistons
.w:     btst    #0,M_FC+1(a4)
        bne.s   .o
        bsr     walker
.o:     rts

;-----------------------------------------------------------------------------
; walker - one spawn entry: G_WD8 = entry, G_WD7 = its byte offset in a
; packed (6-8 byte per entry) form of the list. Window rows
; [scroll/8, scroll/8 + $1C): an entry not spawned whose rows overlap it is
; spawned (walker_spawn); a spawned one that no longer overlaps goes (state
; 0); G_WA5A9 = $FF: never again. Silly: its mini marbles stay. G_SPAWN: word n,
; n x (type, first, last, X/8, Y/8, Z/4, extra 1, extra 2).
;-----------------------------------------------------------------------------
walker:
        move.l  a4,-(sp)
        lea     G_MB(a6),a3
        move.w  M_SCROLL(a3),d4
        lsr.w   #3,d4
        andi.w  #$FF,d4                 ; d4 = the window's top row
        move.w  d4,d5
        addi.b  #$1C,d5                 ; d5 = its bottom (top + $1C)
        movea.l G_SPAWN(a6),a0
        move.w  G_WD8(a6),d1
        cmp.w   (a0),d1
        bhs     .reset
        lea     2(a0),a1
        move.w  d1,d2
        lsl.w   #3,d2
        adda.w  d2,a1                   ; the entry
        lea     G_WA5A9(a6),a2
        move.b  0(a2,d1.w),d2
        bmi     .next
        bne.s   .sp
        move.b  1(a1),d3                ; not spawned: first < bottom, last >= top
        cmp.b   d5,d3
        bhs     .next
        move.b  2(a1),d3
        cmp.b   d4,d3
        blo     .next
        bsr     walker_spawn
        bra     .next
.sp:    lea     G_WA565(a6),a2          ; spawned: its slot's block
        moveq   #0,d0
        move.b  0(a2,d1.w),d0
        subq.w  #2,d0
        mulu.w  #M_SIZE,d0
        lea     G_OBJ(a6),a4
        adda.l  d0,a4
        move.b  1(a1),d3
        cmp.b   d5,d3
        bhs.s   .un                     ; first >= bottom: gone
        move.b  2(a1),d3
        cmp.b   d4,d3
        blo.s   .past
        cmpi.w  #4,G_RACE(a6)           ; in the window (Silly: an emptied slot
        bne.s   .next                   ; frees its entry)
        tst.w   M_STATE(a4)
        bne.s   .next
        lea     G_WA5A9(a6),a2
        clr.b   0(a2,d1.w)
        bra.s   .next
.past:  cmpi.w  #4,G_RACE(a6)           ; passed (Silly: the mini marbles stay)
        bne.s   .un
        move.w  M_STATE(a4),d0
        cmpi.w  #$1F,d0
        blo.s   .un
        cmpi.w  #$22,d0
        blo.s   .next
.un:    lea     G_WA5A9(a6),a2
        clr.b   0(a2,d1.w)
        clr.w   M_STATE(a4)
        move.w  M_SLOT(a4),d0
        bclr    d0,G_MOVM+1(a6)
.next:  addq.w  #1,G_WD8(a6)
        moveq   #0,d0
        move.b  (a1),d0
        moveq   #6,d1
        cmpi.b  #$18,d0
        beq.s   .x2
        cmpi.b  #$0A,d0
        beq.s   .x2
        cmpi.b  #$10,d0
        beq.s   .x2
        cmpi.b  #$29,d0
        beq.s   .x1
        cmpi.b  #$1F,d0
        blo.s   .x0
        cmpi.b  #$23,d0
        bhs.s   .x0
.x1:    addq.w  #1,d1
        bra.s   .x0
.x2:    addq.w  #2,d1
.x0:    add.w   d1,G_WD7(a6)
        movea.l (sp)+,a4
        rts
.reset: clr.w   G_WD7(a6)
        clr.w   G_WD8(a6)
        movea.l (sp)+,a4
        rts

; walker_spawn - entry d1.w (a1) into the first free slot
walker_spawn:
        lea     G_OBJ(a6),a4
        moveq   #5,d0
.f:     tst.w   M_STATE(a4)
        beq.s   .free
        lea     M_SIZE(a4),a4
        dbra    d0,.f
        rts                             ; (no free slot)
.free:  moveq   #0,d0
        move.b  (a1),d0
        move.w  d0,M_STATE(a4)
        move.b  #$80,M_S(a4)
        clr.w   M_DRAWN(a4)             ; (not drawn until its first run: the slot's
        clr.w   M_T400(a4)              ;  last object left it set, with its M_SB)
        clr.w   M_VXS(a4)
        clr.w   M_VYS(a4)
        clr.w   M_VX(a4)
        clr.w   M_VY(a4)
        clr.w   M_VZ(a4)
        moveq   #0,d2
        move.b  3(a1),d2
        lsl.l   #3,d2
        lsl.l   #8,d2
        move.l  d2,M_X(a4)
        move.l  d2,M_PX(a4)
        moveq   #0,d2
        move.b  4(a1),d2
        lsl.l   #3,d2
        lsl.l   #8,d2
        move.l  d2,M_Y(a4)
        move.l  d2,M_PY(a4)
        moveq   #0,d2
        move.b  5(a1),d2
        lsl.w   #2,d2
        addi.w  #$8000,d2
        lsl.l   #8,d2
        move.l  d2,M_Z(a4)
        cmpi.b  #ST_STEELIE,d0
        bne.s   .e0
        move.b  6(a1),M_O6CF+1(a4)
        move.b  7(a1),M_CODE+1(a4)
        bra.s   .e
.e0:    cmpi.b  #$0A,d0                 ; acid pool, slinky: X, Y
        beq.s   .ea                     ; + 4, the extras, frame 0
        cmpi.b  #$10,d0
        bne.s   .e1
.ea:    ori.b   #4,M_X+2(a4)
        ori.b   #4,M_Y+2(a4)
        ori.b   #4,M_PX+2(a4)
        ori.b   #4,M_PY+2(a4)
        move.l  M_X(a4),d2              ; home (M_HX / M_HY), G_WZ79 = Z
        lsr.l   #8,d2
        move.w  d2,M_HX(a4)
        move.l  M_Y(a4),d2
        lsr.l   #8,d2
        move.w  d2,M_HY(a4)
        move.l  M_Z(a4),d2
        lsr.l   #8,d2
        move.w  d2,G_WZ79(a6)
        moveq   #0,d2
        move.b  6(a1),d2
        move.w  d2,M_O6CF(a4)
        move.w  d2,M_PATH0(a4)
        move.b  7(a1),M_CODE+1(a4)
        clr.w   M_FID(a4)
        bra.s   .e
.e1:    cmpi.b  #$29,d0
        beq.s   .e2
        cmpi.b  #$1F,d0
        blo.s   .e
        cmpi.b  #$23,d0
        bhs.s   .e
.e2:    move.b  6(a1),M_O6CF+1(a4)
.e:     move.w  d1,M_O5B9(a4)
        lea     G_WA565(a6),a2
        move.b  M_SLOT+1(a4),0(a2,d1.w)
        lea     G_WA5A9(a6),a2
        addq.b  #1,0(a2,d1.w)
        movem.l d0-d1,-(sp)
        bsr     obj_mark
        movem.l (sp)+,d0-d1
        bra     obj_sprites             ; its pictures, pre-shifted (once, now)

;-----------------------------------------------------------------------------
; Object sprites. The PLAY blob's frame list (PH_OFRM: word n, n x (byte
; type, byte frame id, word w, h, xoff, yoff, w x h colour bytes, $FF =
; clear; even)) holds each object type's pictures; when an object spawns (or
; is there at the race start) its type's frames are pre-shifted into its
; slot's area (G_OSPR + (slot - 2) * OSPR_SLOT): word n, n x (word frame id,
; word record offset), then the records (spr_build). Only while it is there.
;-----------------------------------------------------------------------------
OSPR_SLOT       equ     2048

; obj_sprites - the slot area of the object at a4 from its type's frames
obj_sprites:
        movem.l d0-d7/a0-a5,-(sp)
        move.w  M_SLOT(a4),d0
        subq.w  #2,d0
        lea     G_OSTY(a6),a0           ; the area already holds this type's pictures
        move.b  M_STATE+1(a4),d1        ; (built the same way from the same frames:
        cmp.b   0(a0,d0.w),d1           ;  the race's, since its load): kept
        beq.s   .o
        move.b  d1,0(a0,d0.w)
        mulu.w  #OSPR_SLOT,d0
        movea.l G_OSPR(a6),a2
        adda.l  d0,a2                   ; a2 = the slot area
        clr.w   (a2)
        movea.l G_OFRM(a6),a0
        move.w  (a0)+,d7                ; frames in the list
        beq.s   .o
        lea     2+4*4(a2),a1            ; records after a directory of up to 4
        subq.w  #1,d7
.f:     move.b  (a0),d0                 ; type
        cmp.b   M_STATE+1(a4),d0
        bne.s   .n
        move.w  (a2),d1                 ; directory entry n
        cmpi.w  #4,d1
        bhs.s   .n
        lsl.w   #2,d1
        moveq   #0,d0
        move.b  1(a0),d0
        move.w  d0,2(a2,d1.w)           ; frame id
        move.l  a1,d0
        sub.l   a2,d0
        move.w  d0,4(a2,d1.w)           ; record offset
        addq.w  #1,(a2)
        movem.l d7/a0/a2,-(sp)
        addq.l  #2,a0
        bsr     spr_build               ; a1 = past the record
        movem.l (sp)+,d7/a0/a2
.n:     move.w  2(a0),d0                ; next: 10 + w x h, even
        mulu.w  4(a0),d0
        addi.l  #10+1,d0
        andi.w  #$FFFE,d0
        adda.l  d0,a0
        dbra    d7,.f
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts

;-----------------------------------------------------------------------------
; rspr_build - the race-wide pictures (a0 = the PLAY blob's PH_RFRM list) pre-
; shifted into G_RSPR at the race load: 256 words by frame id (the offset of
; its first record, 0 none), then per picture: word attribute, word next (the
; offset of the frame id's next record, 0 none), the spr_build record.
;-----------------------------------------------------------------------------
rspr_build:
        movem.l d0-d7/a0-a5,-(sp)
        movea.l G_RSPR(a6),a2
        bra.s   rspr_b
; rspr_build_a2 - the same into a2 (the slinkies' set: the sprite cache)
rspr_build_a2:
        movem.l d0-d7/a0-a5,-(sp)
rspr_b: movea.l a2,a1
        move.w  #255,d0
.c:     clr.w   (a1)+
        dbra    d0,.c
        move.w  (a0)+,d7
        beq.s   .o
        subq.w  #1,d7
.p:     moveq   #0,d0
        move.b  (a0),d0                 ; frame id
        moveq   #$7F,d1
        and.b   1(a0),d1                ; attribute (bit 7: generated code wanted)
        move.w  d1,(a1)
        add.w   d0,d0
        move.w  0(a2,d0.w),2(a1)        ; next = the directory's
        move.l  a1,d2
        sub.l   a2,d2
        move.w  d2,0(a2,d0.w)           ; the directory: this one
        addq.l  #4,a1
        movem.l d7/a0/a2,-(sp)
        movea.l a1,a3                   ; (the record)
        addq.l  #2,a0
        bsr     spr_build               ; a1 = past the record
        movem.l (sp)+,d7/a0/a2
        tst.b   1(a0)
        bpl.s   .nc
        moveq   #0,d3                   ; its four shifts' code after it
.cg:    bsr     spr_code
        addq.w  #1,d3
        cmpi.w  #4,d3
        blo.s   .cg
.nc:    move.w  2(a0),d0                ; next: 10 + w x h, even
        mulu.w  4(a0),d0
        addi.l  #10+1,d0
        andi.w  #$FFFE,d0
        adda.l  d0,a0
        dbra    d7,.p
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts

;-----------------------------------------------------------------------------
; The slinkies' pictures (Beginner, Intermediate) are kept in the SPRITE CACHE (G_CCH,
; the takeover loader's leftover QDOS memory), not the race area: the PLAY
; blob's PH_SFRM list (as PH_RFRM: frame id, variant, w, h, xoff, yoff, pixels)
; is pre-shifted x4 there at the race load (rspr_build_a2: a directory by
; frame id at the cache's start, chains by variant), PH_SSPR bytes. One set a
; race (every slinky of a race is drawn with the same pictures and colours).
; The set sits at the cache's top, the pictures in the build's order:
; the rarest first, the walking ones (about 94% of the slinkies drawn) last, so they
; are in the fast expansion RAM when the cache straddles $40000 (its low part is
; motherboard RAM, slowed by the screen's fetches).
; With no cache (QDOS mode) or one too small for the set (Q-emuLator
; Minerva F3: 27 KB) the race's slinkies are OFF: they never spawn (their spawn
; entries' first row $FF, as a type not enabled) and the start image's are
; emptied (slink_slots_off): G_SLOFF.
;-----------------------------------------------------------------------------
SL_RESTF        equ     $26             ; the frame at rest: 7 pictures by M_T400
SL_RESTN        equ     7

; slink_load - at the race load (a5 = the PLAY blob, G_SPAWN set)
slink_load:
        movem.l d0-d1/a0/a2,-(sp)
        clr.w   G_SLON(a6)
        clr.w   G_SLOFF(a6)
        clr.l   G_CUSE(a6)
        move.l  PH_SFRM(a5),d0
        lea     0(a5,d0.l),a0
        tst.w   (a0)
        beq.s   .o                      ; (no slinkies in this race)
        move.l  PH_SSPR(a5),d1
        move.l  G_CCH(a6),d0
        beq.s   .off
        cmp.l   G_CSZ(a6),d1
        bhi.s   .off
        add.l   G_CSZ(a6),d0            ; at the cache's TOP (sl_base): the top is the
        sub.l   d1,d0                   ; fast RAM (>= $40000) when it straddles it, and
        movea.l d0,a2                   ; the most drawn pictures come last (the build)
        bsr     rspr_build_a2
        move.w  #1,G_SLON(a6)
        move.l  d1,G_CUSE(a6)
        cmp.l   G_CMAX(a6),d1
        bls.s   .o
        move.l  d1,G_CMAX(a6)
.o:     movem.l (sp)+,d0-d1/a0/a2
        rts
.off:   move.w  #1,G_SLOFF(a6)          ; the spawn list: slinkies never spawn
        movea.l G_SPAWN(a6),a0
        move.w  (a0)+,d0
        beq.s   .o
        subq.w  #1,d0
.e:     cmpi.b  #ST_SLINKY,(a0)
        bne.s   .n
        st      1(a0)                   ; first row $FF
.n:     addq.l  #8,a0
        dbra    d0,.e
        bra.s   .o

; slink_slots_off - (restart, slinkies off) the start image's slinkies emptied:
; a slot holding one gets state 0, and the spawn entries spawned into it
; (G_WA5A9 = 1, G_WA565 = the slot) go back to 0
slink_slots_off:
        tst.w   G_SLOFF(a6)
        beq.s   .x
        movem.l d0-d2/a0-a2,-(sp)
        lea     G_OBJ(a6),a0
        moveq   #2,d1                   ; slot
.s:     move.w  M_STATE(a0),d0
        bsr.s   slink_state
        bne.s   .n
        clr.w   M_STATE(a0)
        movea.l G_SPAWN(a6),a1
        move.w  (a1),d2                 ; entries
        lea     G_WA5A9(a6),a1
        lea     G_WA565(a6),a2
        subq.w  #1,d2
        bmi.s   .n
.e:     cmpi.b  #1,(a1)
        bne.s   .en
        cmp.b   (a2),d1
        bne.s   .en
        clr.b   (a1)
.en:    addq.l  #1,a1
        addq.l  #1,a2
        dbra    d2,.e
.n:     lea     M_SIZE(a0),a0
        addq.w  #1,d1
        cmpi.w  #8,d1
        blo.s   .s
        movem.l (sp)+,d0-d2/a0-a2
.x:     rts

; slink_state - Z set when d0.w is a slinky's state ($10-$13, $1A)
slink_state:
        cmpi.w  #ST_SLLUNGE,d0
        beq.s   .o
        cmpi.w  #ST_SLINKY,d0
        blo.s   .no
        cmpi.w  #ST_SLREST,d0
        bhi.s   .no
        cmp.w   d0,d0
.o:     rts
.no:    andi.b  #$FB,ccr
        rts

;-----------------------------------------------------------------------------
; spr_code - generated code for shift d3 of the record at a3, written at a1 (a1 =
; past it; its offset from the record into the header's word 24 + 2 x shift): per
; row, per pair of words: all clear nothing; all ink move.l #data,d16(a1); else
; move.l d16(a1),d0 / andi.l #mask,d0 / ori.l #data,d0 / move.l d0,d16(a1); d16 =
; row x 128 + the pair's byte offset; then rts. Drawn with a1 = the picture's top
; left screen word when no row or word of it is clipped.
;-----------------------------------------------------------------------------
spr_code:
        movem.l d0-d7/a0/a2,-(sp)
        move.l  a1,d0
        sub.l   a3,d0
        move.w  d3,d1
        add.w   d1,d1
        move.w  d0,24(a3,d1.w)
        add.w   d1,d1
        movea.l a3,a0
        adda.w  8(a3,d1.w),a0           ; this shift's data
        movea.l a3,a2
        adda.w  10(a3,d1.w),a2          ; its spans
        move.w  2(a3),d6                ; rows
        moveq   #0,d7                   ; the row's displacement
.row:   movem.w (a2)+,d2/d4             ; the span: first pair's byte offset, pairs - 1
        tst.w   d4
        bmi.s   .nr
        add.w   d7,d2
.pr:    move.l  (a0)+,d0                ; mask
        move.l  (a0)+,d1                ; data
        moveq   #-1,d3
        cmp.l   d3,d0
        beq.s   .np                     ; all clear
        tst.l   d0
        bne.s   .pt
        move.w  #$237C,(a1)+            ; move.l #data,d16(a1)
        move.l  d1,(a1)+
        move.w  d2,(a1)+
        bra.s   .np
.pt:    move.w  #$2029,(a1)+            ; move.l d16(a1),d0
        move.w  d2,(a1)+
        move.w  #$0280,(a1)+            ; andi.l #mask,d0
        move.l  d0,(a1)+
        move.w  #$0080,(a1)+            ; ori.l #data,d0
        move.l  d1,(a1)+
        move.w  #$2340,(a1)+            ; move.l d0,d16(a1)
        move.w  d2,(a1)+
.np:    addq.w  #4,d2
        dbra    d4,.pr
.nr:    addi.w  #BPL,d7
        subq.w  #1,d6
        bne.s   .row
        move.w  #$4E75,(a1)+            ; rts
        movem.l (sp)+,d0-d7/a0/a2
        rts

;-----------------------------------------------------------------------------
; spr_build - a pre-shifted record from a picture: a0 = word w, h, xoff, yoff,
; then w x h colour bytes ($FF clear); a1 = the record: word nw, h, xoff,
; yoff, 4 x (word data offset, word span offset), 4 code offsets; per shift
; each row's span of word pairs (mask, mask, data, data: 8 B a pair), row after
; row, then h spans of 4 B (byte offset of the first pair, pairs - 1 or -1).
; Out: a1 just past it. (Built as rows of nw words, then compacted.)
;-----------------------------------------------------------------------------
SB_LINE         equ     0               ; locals: a shifted row (48 bytes)
SB_END          equ     48              ; the last shift + 1
SB_SIZE         equ     50

spr_build:
        moveq   #0,d3                   ; all four shifts
        moveq   #4,d0
        bra.s   spr_b
; spr_build1 - the same, shift d3.w only (the others' offsets are not set)
spr_build1:
        moveq   #1,d0
        add.w   d3,d0
spr_b:  lea     -SB_SIZE(sp),sp
        move.w  d0,SB_END(sp)
        movea.l a1,a3                   ; a3 = the record
        move.w  (a0),d4                 ; w
        move.w  d4,d5
        addq.w  #3,d5
        lsr.w   #2,d5
        addq.w  #2,d5                   ; nw = (w + 3) / 4 + 1, rounded up to even
        andi.w  #$FFFE,d5                ; (the rows go in pairs of words)
        move.w  d5,(a3)
        move.w  2(a0),2(a3)             ; h
        move.w  4(a0),4(a3)             ; xoff
        move.w  6(a0),6(a3)             ; yoff
        lea     8(a0),a2                ; a2 = the pixels
        clr.l   24(a3)                  ; (no generated code: rspr_build adds it)
        clr.l   28(a3)
        lea     32(a3),a4               ; a4 = the body
.shift: move.l  a4,d0
        sub.l   a3,d0
        move.w  d3,d1
        lsl.w   #2,d1
        move.w  d0,8(a3,d1.w)           ; data offset
        movea.l a4,a1                   ; (for the spans)
        moveq   #0,d2                   ; y
.drow:  lea     SB_LINE(sp),a0
        moveq   #-1,d0
        move.w  d5,d1                   ; (nw longs: the 4 x nw bytes the words read)
        subq.w  #1,d1
.cl:    move.l  d0,(a0)+
        dbra    d1,.cl
        lea     SB_LINE(sp),a0
        adda.w  d3,a0
        move.w  d2,d0
        mulu.w  d4,d0
        lea     0(a2,d0.l),a5
        move.w  d4,d0
        subq.w  #1,d0
.cpy:   move.b  (a5)+,(a0)+
        dbra    d0,.cpy
        lea     SB_LINE(sp),a0
        lea     mbpat+128(pc),a5            ; (colours 0-7, $FF clear: entries 8-15)
        move.w  d5,d1
        subq.w  #1,d1
.dw:    moveq   #15,d0
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
        addq.w  #1,d2
        cmp.w   2(a3),d2
        blo     .drow
        move.l  a4,d0                   ; the spans
        sub.l   a3,d0
        move.w  d3,d1
        lsl.w   #2,d1
        move.w  d0,10(a3,d1.w)
        moveq   #0,d2
.srow:  moveq   #-1,d7
        moveq   #0,d6
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
        andi.w  #$FFFE,d7               ; the first ink word's pair .. the last's
        ori.w   #1,d6
        move.w  d7,d0
        add.w   d0,d0
        move.w  d0,(a4)+                ; its screen byte offset
        move.w  d2,d0
        mulu.w  d5,d0
        add.w   d7,d0
        lsl.w   #2,d0
        move.w  d0,(a4)+                ; its data offset
        move.w  d6,d0
        sub.w   d7,d0
        lsr.w   #1,d0
        move.w  d0,(a4)+                ; pairs - 1
        bra.s   .snext
.snone: clr.l   (a4)+
        move.w  #-1,(a4)+
.snext: addq.w  #1,d2
        cmp.w   2(a3),d2
        blo.s   .srow
        ; the rows' words into pairs: (mask, data, mask, data) -> (mask, mask, data,
        ; data), so the drawer takes two screen words a long at a time
        move.w  d3,d1
        lsl.w   #2,d1
        movea.l a3,a0
        adda.w  8(a3,d1.w),a0           ; this shift's data
        move.w  2(a3),d0
        mulu.w  d5,d0
        lsr.w   #1,d0
        subq.w  #1,d0                   ; pairs in it - 1
.pr:    move.w  2(a0),d1
        move.w  4(a0),2(a0)
        move.w  d1,4(a0)
        addq.l  #8,a0
        dbra    d0,.pr
        ; compact: only each row's span pairs, row after row; the spans become
        ; (screen byte offset, pairs - 1) (the drawers step through the data)
        move.w  d3,d1
        lsl.w   #2,d1
        movea.l a3,a5
        adda.w  8(a3,d1.w),a5           ; the full rows (in place: copied downwards)
        movea.l a5,a0
        movea.l a3,a1
        adda.w  10(a3,d1.w),a1          ; the 6-byte spans
        move.l  a1,d7
        move.w  2(a3),d6
        subq.w  #1,d6
.c1:    move.w  4(a1),d2                ; pairs - 1
        bmi.s   .c1n
        move.w  2(a1),d0                ; their data offset in the full rows
        lea     0(a5,d0.w),a4
.cc:    move.l  (a4)+,(a0)+
        move.l  (a4)+,(a0)+
        dbra    d2,.cc
.c1n:   addq.l  #6,a1
        dbra    d6,.c1
        move.l  a0,d0                   ; the 4-byte spans after the compact data
        sub.l   a3,d0
        move.w  d0,10(a3,d1.w)
        movea.l d7,a1
        movea.l a0,a4
        move.w  2(a3),d6
        subq.w  #1,d6
.c2:    move.w  (a1),(a4)+
        move.w  4(a1),(a4)+
        addq.l  #6,a1
        dbra    d6,.c2
        addq.w  #1,d3
        cmp.w   SB_END(sp),d3
        blo     .shift
        movea.l a4,a1
        lea     SB_SIZE(sp),sp
        rts

;-----------------------------------------------------------------------------
; draw_objects - the drawn objects (slots 7-2) into the hidden screen, under the
; marble (drawn after them), no occlusion (they are never masked by the
; course). Position as the marble's: x = X - Y + 120 + xoff,
; top = S - $8000 + 1 + yoff on the course, clipped to the playfield.
;-----------------------------------------------------------------------------
draw_objects:
        tst.w   G_OBJON(a6)
        beq.s   .o
        moveq   #0,d7
        move.b  G_MOVM+1(a6),d7         ; (only the slots with logic draw: 7 -> 2)
        andi.b  #$FC,d7
        beq.s   .o
        OBJ_TOP                         ; (a walk down from the highest)
.s:     add.b   d7,d7
        bcc.s   .n
        tst.w   M_DRAWN(a4)
        beq.s   .n
        movem.l d7/a4,-(sp)
        bsr.s   obj_draw1
        movem.l (sp)+,d7/a4
.n:     lea     -M_SIZE(a4),a4
        tst.b   d7
        bne.s   .s
.o:     rts

; obj_dcls - obj_draw1's way by state: 0 its slot's area (then the race-wide
; pictures), 1 a slinky (the sprite cache's set), 2 a mini marble (straight to
; the race-wide pictures, drawn by spr_puts)
obj_dcls:
        dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; $00-$0F
        dc.b    1,1,1,1,0,0,0,0,0,0,1,0,0,0,0,2     ; $10-$1F (slinkies $10-$13, $1A)
        dc.b    2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; $20-$2F (minis $1F-$21)
        dc.b    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; $30-$3F
        even

; obj_draw1 - the object at a4, if its frame id has a record in its area. A
; falling object (state $2B / $2C, frame not $44) shows a prepared picture
; (by M_T400 in state $2B, by M_O6CF in $2C); only the one
; shift it needs is built, into its area, when the picture changes.
obj_draw1:
        move.w  M_STATE(a4),d1          ; its way (obj_dcls: one look-up in place of
        move.b  obj_dcls(pc,d1.w),d2    ;  the slinky range's three tests)
        bne     .k
.ns:    move.w  M_SLOT(a4),d0
        subq.w  #2,d0
        mulu.w  #OSPR_SLOT,d0
        movea.l G_OSPR(a6),a5
        adda.l  d0,a5
        move.w  M_FID(a4),d0
        move.w  M_STATE(a4),d1
        cmpi.w  #ST_FALL1,d1
        blo.s   .look
        cmpi.w  #ST_FALL2,d1
        bhi.s   .look
        cmpi.w  #$44,d0
        beq.s   .look
        bsr     obj_fallpic             ; d0 = its key, the record built
        bmi     .none
.look:  move.w  (a5),d1
        beq     .race
        subq.w  #1,d1
        lea     2(a5),a0
.f:     cmp.w   (a0),d0
        beq.s   .got
        addq.l  #4,a0
        dbra    d1,.f
        bra     .race                   ; (not in its slot's: a race-wide picture)
.got:   adda.w  2(a0),a5                ; the record
.gotr:  move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        asr.l   #8,d0
        addi.w  #120,d0
        add.w   4(a5),d0                ; xoff
        move.w  M_SB(a4),d1             ; (S - $8000 + 1 + scroll = the base + $C1 - $8000:
        addi.w  #$C1-$8000,d1           ; the scroll now, also between the object's runs)
        subi.w  #VIEW_SCROLL,d1
        sub.w   G_VIEW(a6),d1
        add.w   6(a5),d1                ; yoff
        bra     spr_put                 ; (the record a5 at x d0, top d1)

; (obj_draw1) a race-wide picture: G_RSPR's directory by frame id, then the
; chain for the object's attribute; a slinky's: the sprite cache's (slink_load)
.race:  move.w  M_STATE(a4),d1
        cmpi.w  #ST_SLLUNGE,d1
        beq.s   .sl
        cmpi.w  #ST_SLINKY,d1
        blo.s   .rw
        cmpi.w  #ST_SLREST,d1
        bls.s   .sl
.rw:    movea.l G_RSPR(a6),a5
        move.w  M_ATTR(a4),d2
.rd:    andi.w  #$FF,d0
        add.w   d0,d0
        moveq   #0,d1
        move.w  0(a5,d0.w),d1
        beq     .none
.rl:    lea     0(a5,d1.l),a0
        cmp.w   (a0),d2
        beq.s   .rg
        moveq   #0,d1
        move.w  2(a0),d1
        bne.s   .rl
        bra     .none
.rg:    lea     4(a0),a5
        bra     .gotr
; a slinky: chained by variant: frame $26 (at rest) by M_T400 (0-6), the others 0.
; (Its attribute is not used: every slinky of a race has the same pictures.)
; None when the race's set is not in the cache.
.sl:    tst.w   G_SLON(a6)
        beq     .none
        move.l  G_CCH(a6),d1            ; sl_base: the set's directory, at the
        add.l   G_CSZ(a6),d1            ; cache's top - G_CUSE
        sub.l   G_CUSE(a6),d1
        movea.l d1,a5
        moveq   #0,d2
        cmpi.b  #SL_RESTF,d0
        bne.s   .rd
        move.w  M_T400(a4),d2
        cmpi.w  #SL_RESTN-1,d2
        bls.s   .rd
        moveq   #SL_RESTN-1,d2
        bra.s   .rd

.none:  rts

; (obj_draw1) a slinky (1): the cache's set; a mini marble (2): the race-wide
; picture by frame id and attribute, at once (no slot area to search: it has
; none), drawn by spr_puts
.k:     move.w  M_FID(a4),d0
        subq.b  #1,d2
        beq     .sl
        movea.l G_RSPR(a6),a5
        move.w  M_ATTR(a4),d2
        andi.w  #$FF,d0
        add.w   d0,d0
        moveq   #0,d1
        move.w  0(a5,d0.w),d1
        beq.s   .none
.ml:    lea     0(a5,d1.l),a0
        cmp.w   (a0),d2
        beq.s   .mg
        moveq   #0,d1
        move.w  2(a0),d1
        bne.s   .ml
        rts
.mg:    lea     4(a0),a5
        move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        asr.l   #8,d0
        addi.w  #120,d0
        add.w   4(a5),d0                ; xoff
        move.w  M_SB(a4),d1
        addi.w  #$C1-$8000,d1
        subi.w  #VIEW_SCROLL,d1
        sub.w   G_VIEW(a6),d1
        add.w   6(a5),d1                ; yoff
        bra     spr_puts

;-----------------------------------------------------------------------------
; spr_put - a pre-shifted record (spr_build: a5) with its left x d0 and top line
; d1 (the playfield: x 0-255, line 0 = G_PTOP; xoff / yoff already added) into
; G_DEST: clipped to the playfield; generated code when there is some and nothing
; is clipped. Uses d0-d7 / a0-a4.
;-----------------------------------------------------------------------------
spr_put:
        ifeq    RELB
        addq.w  #1,G_TSPR(a6)           ; (telemetry: sprites drawn)
        endc
        ; clip (as draw_marble): words [wlo, whi), rows [r0, rows)
        moveq   #3,d2
        and.w   d0,d2                   ; shift
        asr.w   #2,d0
        move.w  d0,d7                   ; wx
        moveq   #0,d6
        tst.w   d7
        bpl.s   .wl
        move.w  d7,d6
        neg.w   d6
.wl:    moveq   #64,d5
        sub.w   d7,d5
        cmp.w   (a5),d5
        ble.s   .wh
        move.w  (a5),d5
.wh:    cmp.w   d5,d6
        bge     .none
        moveq   #0,d3
        tst.w   d1
        bpl.s   .r0
        move.w  d1,d3
        neg.w   d3
.r0:    move.w  G_LINES(a6),d4
        sub.w   d1,d4
        cmp.w   2(a5),d4
        ble.s   .r1
        move.w  2(a5),d4
.r1:    sub.w   d3,d4
        ble     .none
        subq.w  #1,d4
        add.w   d2,d2
        add.w   d2,d2
        movea.l a5,a3
        adda.w  8(a5,d2.w),a3           ; this shift's data
        movea.l a5,a2
        adda.w  10(a5,d2.w),a2          ; its spans
        move.w  d3,d0                   ; rows clipped at the top: their spans and
        beq.s   .t0                     ; their data skipped
        move.w  d1,-(sp)
        subq.w  #1,d0
.tk:    move.w  2(a2),d1
        bmi.s   .tn
        addq.w  #1,d1
        lsl.w   #3,d1
        adda.w  d1,a3
.tn:    addq.l  #OSPN_ROWB,a2
        dbra    d0,.tk
        move.w  (sp)+,d1
.t0:
        movea.l G_DEST(a6),a4
        move.w  G_PTOP(a6),d0
        lsl.w   #7,d0
        adda.w  d0,a4
        move.w  d1,d0
        add.w   d3,d0
        lsl.w   #7,d0
        adda.w  d0,a4
        move.w  d7,d0
        add.w   d0,d0
        adda.w  d0,a4
        tst.w   d6                      ; not clipped left or right: the rows as
        bne.s   .clip                   ; they are (the usual case)
        cmp.w   (a5),d5
        bne.s   .clip
        tst.w   d3                      ; no row clipped either, and generated code:
        bne.s   .fast                   ; jump to it
        move.w  d4,d0
        addq.w  #1,d0
        cmp.w   2(a5),d0
        bne.s   .fast
        move.w  d2,d0
        lsr.w   #1,d0
        move.w  24(a5,d0.w),d0
        beq.s   .fast
        movea.l a4,a1
        jmp     0(a5,d0.w)
.fast:  movem.w (a2)+,d0/d3             ; a row: first pair's byte offset, pairs - 1
        tst.w   d3                      ; (-1: none); its data: next at a3
        bmi.s   .fn
        lea     0(a4,d0.w),a1
.fw:    move.l  (a1),d0                 ; two screen words: (mask, mask), (data, data)
        and.l   (a3)+,d0
        or.l    (a3)+,d0
        move.l  d0,(a1)+
        dbra    d3,.fw
.fn:    lea     BPL(a4),a4
        dbra    d4,.fast
        rts
; CLIP: trim each row's span to [wlo, whi), word by word within the pairs
.clip:  movem.w (a2)+,d0/d3             ; first pair's byte offset, pairs - 1
        tst.w   d3
        bmi.s   .nc
        move.w  d3,d1                   ; its data at a3; the next row's after it
        addq.w  #1,d1
        lsl.w   #3,d1
        movea.l a3,a0
        adda.w  d1,a3
        move.w  d0,d2
        lsr.w   #1,d2                   ; its first word
        move.w  d2,d7
        addq.w  #1,d3
        add.w   d3,d3
        add.w   d2,d3                   ; the span's end word
        cmp.w   d6,d2
        bge.s   .ca
        move.w  d6,d2
.ca:    cmp.w   d5,d3
        ble.s   .cb
        move.w  d5,d3
.cb:    sub.w   d2,d3
        ble.s   .nc
        subq.w  #1,d3
        sub.w   d2,d7
        neg.w   d7                      ; words skipped from the span's first
        move.w  d7,d0
        lsr.w   #1,d0
        lsl.w   #3,d0
        adda.w  d0,a0                   ; their pairs
        andi.w  #1,d7                   ; the word within its pair
        beq.s   .c0
        addq.l  #2,a0
.c0:    add.w   d2,d2
        lea     0(a4,d2.w),a1
.wc:    move.w  (a1),d0
        and.w   (a0),d0
        or.w    4(a0),d0
        move.w  d0,(a1)+
        bchg    #0,d7
        bne.s   .w1
        addq.l  #2,a0                   ; the pair's second word
        dbra    d3,.wc
        bra.s   .nc
.w1:    addq.l  #6,a0                   ; the next pair's first
        dbra    d3,.wc
.nc:    lea     BPL(a4),a4
        dbra    d4,.clip
.none:  rts

; spr_puts - spr_put for a small data-way record (the mini marbles: obj_draw1)
; wholly inside the playfield: no clip arithmetic, the rows as spr_put's .fast;
; anything that would be clipped goes to spr_put. The same pixels. Uses d0-d4 /
; a1-a4.
spr_puts:
        tst.w   d0
        bmi     spr_put
        tst.w   d1
        bmi     spr_put
        move.w  d0,d2                   ; the last word inside: x / 4 + words <= 64
        asr.w   #2,d2
        add.w   (a5),d2
        cmpi.w  #64,d2
        bgt     spr_put
        move.w  d1,d2                   ; the last row inside: top + rows <= lines
        add.w   2(a5),d2
        cmp.w   G_LINES(a6),d2
        bgt     spr_put
        ifeq    RELB
        addq.w  #1,G_TSPR(a6)           ; (telemetry: sprites drawn)
        endc
        moveq   #3,d2
        and.w   d0,d2                   ; the shift's data and spans
        add.w   d2,d2
        add.w   d2,d2
        movea.l a5,a3
        adda.w  8(a5,d2.w),a3
        movea.l a5,a2
        adda.w  10(a5,d2.w),a2
        movea.l G_DEST(a6),a4
        move.w  G_PTOP(a6),d2
        lsl.w   #7,d2
        adda.w  d2,a4
        lsl.w   #7,d1
        adda.w  d1,a4
        asr.w   #2,d0
        add.w   d0,d0
        adda.w  d0,a4
        move.w  2(a5),d4
        subq.w  #1,d4
.r:     move.w  (a2)+,d0                ; a row: first pair's byte offset, pairs - 1
        move.w  (a2)+,d3                ; (-1: none); its data: next at a3
        bmi.s   .n
        lea     0(a4,d0.w),a1
.p:     move.l  (a1),d0                 ; two screen words: (mask, mask), (data, data)
        and.l   (a3)+,d0
        or.l    (a3)+,d0
        move.l  d0,(a1)+
        dbra    d3,.p
.n:     lea     BPL(a4),a4
        dbra    d4,.r
        rts

; obj_fallpic - a falling object's picture (a4, its area a5): the index ($2B:
; min(M_T400, 4); $2C: 5 + min(M_O6CF / 4, 27)) through the map (frame $FF of
; type $2B), the picture's key $100 + picture x 4 + shift; if the area does
; not hold it, the area is made to hold just it (one shift). Out: d0 = the key,
; N set when there is nothing to show. Keeps a4 / a5.
obj_fallpic:
        movem.l d1-d7/a0-a3,-(sp)
        moveq   #0,d0
        cmpi.w  #ST_FALL1,M_STATE(a4)
        bne.s   .c
        move.b  M_T400+1(a4),d0
        cmpi.b  #4,d0
        bls.s   .i
        moveq   #4,d0
        bra.s   .i
.c:     move.b  M_O6CF+1(a4),d0
        lsr.b   #2,d0
        cmpi.b  #27,d0
        bls.s   .c1
        moveq   #27,d0
.c1:    addq.w  #5,d0
.i:     move.w  d0,d6                   ; the index
        moveq   #-1,d0
        bsr     .find                   ; the map
        beq     .no
        moveq   #0,d7
        move.b  10(a0,d6.w),d7          ; the picture
        move.w  d7,d0
        bsr     .find
        beq     .no
        tst.w   2(a0)                   ; (an empty picture)
        beq     .no
        movea.l a0,a3                   ; a3 = the picture's entry
        move.l  M_X(a4),d0              ; its shift: x = X - Y + 120 + xoff
        sub.l   M_Y(a4),d0
        asr.l   #8,d0
        addi.w  #120,d0
        add.w   6(a3),d0
        moveq   #3,d3
        and.w   d0,d3
        move.w  d7,d0
        lsl.w   #2,d0
        add.w   d3,d0
        addi.w  #$100,d0                ; the key
        cmpi.w  #1,(a5)
        bne.s   .build
        cmp.w   2(a5),d0
        beq.s   .yes
.build: move.w  M_SLOT(a4),d1           ; (its slot's area no longer holds a type's
        subq.w  #2,d1                   ;  pictures: obj_sprites builds them again)
        lea     G_OSTY(a6),a0
        clr.b   0(a0,d1.w)
        move.w  d0,-(sp)
        move.w  #1,(a5)
        move.w  d0,2(a5)
        move.w  #6,4(a5)
        lea     2(a3),a0
        lea     6(a5),a1
        movem.l a4-a5,-(sp)
        bsr     spr_build1
        movem.l (sp)+,a4-a5
        move.w  (sp)+,d0
.yes:   tst.w   d0
        movem.l (sp)+,d1-d7/a0-a3
        rts
.no:    moveq   #-1,d0
        movem.l (sp)+,d1-d7/a0-a3
        rts
; .find - the type $2B entry with frame d0.b in the picture list: a0 (Z clear),
; or Z set when there is none
.find:  movea.l G_OFRM(a6),a0
        move.w  (a0)+,d1
        beq.s   .fz
        subq.w  #1,d1
.fl:    cmpi.b  #ST_FALL1,(a0)
        bne.s   .fn
        cmp.b   1(a0),d0
        beq.s   .ff
.fn:    move.w  2(a0),d2
        mulu.w  4(a0),d2
        addi.l  #10+1,d2
        andi.w  #$FFFE,d2
        adda.l  d2,a0
        dbra    d1,.fl
.fz:    moveq   #0,d1                   ; Z set
        rts
.ff:    moveq   #1,d1                   ; Z clear
        rts

;-----------------------------------------------------------------------------
; Intermediate's (and Beginner's / Ultimate's) acid pools and slinkies.
; Both walk a path from the path table (obj_path) in steps (obj_step).
;-----------------------------------------------------------------------------
ST_ACID         equ     $0A
ST_ACIDHAS      equ     $1D
ST_SLINKY       equ     $10
ST_SLJUMP       equ     $11
ST_SLFALL       equ     $12
ST_SLREST       equ     $13
ST_SLLUNGE      equ     $1A
ST_INACID       equ     $0C             ; the player, in a pool

; obj_bc95 - the frame d0.b on the object's phase frames (frame & 3 = M_CODE),
; the attribute by race and phase (obj_bcbc)
obj_bc95:
        bsr.s   bc95_attr
        move.b  M_FC+1(a4),d1           ; (sl_phase)
        move.b  M_CODE+1(a4),d2
        eor.b   d2,d1
        tst.w   G_OSUB(a6)
        bne.s   .e
        andi.b  #2,d1
        bne.s   .k
        bra.s   .f
.e:     andi.b  #3,d1
        bne.s   .k
.f:     andi.w  #$FF,d0
        move.w  d0,M_FID(a4)
.k:     move.w  #1,M_DRAWN(a4)
        rts
; obj_bc95f - the same on the frame-test frame (known); obj_bc95a - off it
obj_bc95f:
        bsr.s   bc95_attr
        andi.w  #$FF,d0
        move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
obj_bc95a:
        bsr.s   bc95_attr
        move.w  #1,M_DRAWN(a4)
        rts
bc95_attr:
        move.w  G_RACE(a6),d1
        add.w   d1,d1
        add.w   d1,d1
        add.w   M_CODE(a4),d1
        andi.w  #$FF,d1
        lea     obj_bcbc(pc),a0
        moveq   #0,d2
        move.b  0(a0,d1.w),d2
        move.w  d2,M_ATTR(a4)
        rts

; sl_phase - Z set on a slinky's frame-test frame: frame & 3 = M_CODE; at 30 Hz
; walking (run once a pair, not G_OSUB): in its pair, frame & 2 = M_CODE & 2.
; Uses d1 / d2.
sl_phase:
        move.b  M_FC+1(a4),d1
        move.b  M_CODE+1(a4),d2
        eor.b   d2,d1
        tst.w   G_OSUB(a6)
        bne.s   .e
        andi.b  #2,d1
        rts
.e:     andi.b  #3,d1
        rts

;-----------------------------------------------------------------------------
; st_acid - the acid pool. On odd frames it wobbles by a table
; offset for the touch test (then back): a touch dissolves player 1 (state
; $0C, drawn to the pool's X / Y), the pool holds it (state $1D). Every 1 or 4
; frames by its phase (the slot), a step along its path (limit 6).
;-----------------------------------------------------------------------------
st_acid:
        moveq   #1,d1                   ; (30 Hz, odd frames: the even frame's step
        move.w  M_VXS(a4),d0            ; first: .step's test with frame - 1)
        beq.s   .em
        cmpi.w  #3,d0
        bhs.s   .em
        moveq   #3,d1
.em:    move.b  M_FC+1(a4),d0
        subq.b  #1,d0
        and.b   d1,d0
        and.b   M_SLOT+1(a4),d1
        cmp.b   d1,d0
        bne.s   .odd
        moveq   #6,d0
        bsr     obj_step
.odd:   btst    #1,M_FC+1(a4)           ; (frame & 2: no touch test, so no wobble)
        bne     .step
        move.l  M_X(a4),M_PX(a4)
        move.l  M_Y(a4),M_PY(a4)
        move.w  M_VXS(a4),d0            ; (an exact early miss: the wobble below
        subq.w  #1,d0                   ;  moves X and Y 0-8 px up, $0780 at most
        cmpi.w  #3,d0                   ;  for directions 1-4 and M_T400 0-5, and
        bhi.s   .wob                    ;  obj_coll then needs |dX| < 8, |dY| < 4,
        cmpi.w  #5,M_T400(a4)           ;  M_F5CB 0 and the player rolling)
        bhi.s   .wob
        lea     G_MB(a6),a3
        tst.b   M_F5CB+1(a3)
        bne.s   .rej
        cmpi.w  #1,M_STATE(a3)
        bne.s   .rej
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_X(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        addi.w  #7+8,d0                 ; dX in [-15, 7]
        cmpi.w  #14+8,d0
        bhi.s   .rej
        move.l  M_Y(a4),d0
        lsr.l   #8,d0
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        addi.w  #3+8,d0                 ; dY in [-11, 3]
        cmpi.w  #6+8,d0
        bls.s   .wob
.rej:   move.w  #1,G_DC(a6)             ; (as obj_collide1 leaves it)
        bra     .step
.wob:   move.w  M_VXS(a4),d0            ; y = direction x 6 + M_T400
        mulu.w  #6,d0
        add.w   M_T400(a4),d0
        andi.w  #$FF,d0
        lea     obj_bdce(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        lsl.w   #8,d1
        lea     obj_bde6(pc),a0
        move.b  0(a0,d0.w),d1
        add.l   d1,M_X(a4)
        andi.l  #$FFFFFF,M_X(a4)
        lea     obj_bdfe(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        lsl.w   #8,d1
        lea     obj_be16(pc),a0
        move.b  0(a0,d0.w),d1
        add.l   d1,M_Y(a4)
        andi.l  #$FFFFFF,M_Y(a4)
        bsr     obj_collide1
        tst.w   d0
        beq.s   .miss
        lea     G_MB(a6),a3             ; the player dissolves
        clr.w   M_VZS(a4)               ; (M_VZS: the player held = player 1)
        clr.w   M_T400(a3)
        clr.w   M_DIZZY(a3)
        move.w  #ST_INACID,M_STATE(a3)
        bset    #0,G_MSFX+1(a6)         ; (effect 16: acid)
        move.w  #ST_ACIDHAS,M_STATE(a4)
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.w  d0,M_POOLX(a3)
        move.l  M_Y(a4),d0
        lsr.l   #8,d0
        move.w  d0,M_POOLY(a3)
        move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
        bra.s   acid_frame
.miss:  move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
.step:  moveq   #1,d1                   ; the phase mask, 3 on directions 1, 2
        move.w  M_VXS(a4),d0
        beq.s   .m
        cmpi.w  #3,d0
        bhs.s   .m
        moveq   #3,d1
.m:     move.b  M_FC+1(a4),d0
        and.b   d1,d0
        and.b   M_SLOT+1(a4),d1
        cmp.b   d1,d0
        bne.s   acid_frame
        moveq   #6,d0
        bsr     obj_step
; acid_frame - attribute 1, the frame from M_T400 and the direction
acid_frame:
        move.w  #1,M_ATTR(a4)
        move.w  M_VXS(a4),d1
        move.w  M_T400(a4),d0
        cmpi.w  #4,d1                   ; (directions 0-4, M_T400 0-5, as a pool has
        bhi.s   .f                      ;  them: obj_acidf, built from both tables)
        cmpi.w  #5,d0
        bhi.s   .f
        lsl.w   #3,d1
        add.w   d1,d0
        lea     obj_acidf(pc),a0
        bra.s   .a1
.f:     tst.w   d1
        beq.s   .t
        cmpi.w  #3,d1
        bhs.s   .t
        neg.w   d0
        addq.w  #5,d0
.t:     andi.w  #$FF,d0
        cmpi.w  #2,d1
        beq.s   .b
        cmpi.w  #3,d1
        bne.s   .a
.b:     addq.w  #6,d0                   ; (the second table, obj_bf25 + 6)
.a:     lea     obj_bf25(pc),a0
.a1:    moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

; st_acidhas - while player 1 is in this pool (state $0C), else back to $0A
st_acidhas:
        lea     G_MB(a6),a3
        tst.w   M_VZS(a4)
        bne.s   .back
        cmpi.w  #ST_INACID,M_STATE(a3)
        beq.s   acid_frame
.back:  move.w  #ST_ACID,M_STATE(a4)
        bra.s   acid_frame

;-----------------------------------------------------------------------------
; obj_step - a step along the path: d0 = the
; step's length in frames. Speeds $0800; the direction in M_VXS:
; 1 -X, 2 -Y, 3 +Y, 4 +X. A pool moves at the start of a step for 1 / 2 and
; at its end for 3 / 4; a slinky the other way round.
;-----------------------------------------------------------------------------
obj_step:
        move.w  #1,M_ATTR(a4)
        move.w  #$800,M_VX(a4)
        move.w  #$800,M_VY(a4)
        move.w  M_VXS(a4),d1
        beq.s   .new
        addq.b  #1,M_T400+1(a4)
        cmpi.w  #ST_SLINKY,M_STATE(a4)
        bne.s   .c
        cmpi.b  #$FF,M_O6CF+1(a4)
        bne.s   .c
        addq.b  #1,M_T400+1(a4)
.c:     cmp.b   M_T400+1(a4),d0
        bhi.s   .o
        clr.w   M_T400(a4)
        cmpi.w  #ST_ACID,M_STATE(a4)
        bne.s   .sl
        cmpi.w  #3,d1
        bne.s   .a4
        bsr     move_yp
        bra.s   .new
.a4:    cmpi.w  #4,d1
        bne.s   .new
        bsr     move_xp
        bra.s   .new
.sl:    cmpi.w  #1,d1
        bne.s   .s2
        bsr     move_xn
        bra.s   .new
.s2:    cmpi.w  #2,d1
        bne.s   .new
        bsr     move_yn
.new:   bsr     obj_pathdir             ; d0 = the new direction
        move.w  d0,M_VXS(a4)
        move.w  M_STATE(a4),d1
        cmpi.w  #ST_ACID,d1
        bne.s   .ns
        cmpi.w  #1,d0
        beq     move_xn
        cmpi.w  #2,d0
        beq     move_yn
.o:     rts
.ns:    cmpi.w  #ST_SLINKY,d1
        bne.s   .o
        cmpi.w  #4,d0
        beq     move_xp
        cmpi.w  #3,d0
        beq     move_yp
        rts

; move_xn / move_yn: - the speed, 0 if it goes below; move_xp /
; move_yp: +
move_xn:
        lea     M_X(a4),a0
        move.w  M_VX(a4),d1
        bra.s   mv_n
move_yn:
        lea     M_Y(a4),a0
        move.w  M_VY(a4),d1
mv_n:   andi.l  #$FFFF,d1
        move.l  (a0),d2
        sub.l   d1,d2
        bmi.s   .z
        btst    #23,d2
        beq.s   .s
.z:     moveq   #0,d2
.s:     move.l  d2,(a0)
        rts
move_xp:
        lea     M_X(a4),a0
        move.w  M_VX(a4),d1
        bra.s   mv_p
move_yp:
        lea     M_Y(a4),a0
        move.w  M_VY(a4),d1
mv_p:   andi.l  #$FFFF,d1
        add.l   d1,(a0)
        andi.l  #$FFFFFF,(a0)
        rts

; obj_pathdir - the next direction from the path (M_O6CF the index, $FF
; jumps to the next byte); M_O6CF = $FF: home, first to the middle of the
; cell; X first unless M_RNG bit 3 (then Y); home: 0 and the path again from
; its start (state $10)
obj_pathdir:
        lea     obj_path(pc),a0
        moveq   #0,d1
        move.b  M_O6CF+1(a4),d1
        cmpi.b  #$FF,d1
        beq.s   .home
.l:     moveq   #0,d0
        move.b  0(a0,d1.w),d0
        cmpi.b  #$FF,d0
        beq.s   .j
        addq.b  #1,M_O6CF+1(a4)
        rts
.j:     move.b  1(a0,d1.w),d1
        move.b  d1,M_O6CF+1(a4)
        cmpi.b  #$FF,d1                 ; (a jump to $FF: home)
        beq.s   .home
        bra.s   .l
.home:  move.l  M_X(a4),d0
        andi.l  #$FFF800,d0
        ori.w   #$400,d0
        move.l  d0,M_X(a4)
        lsr.l   #8,d0
        move.l  M_Y(a4),d1
        andi.l  #$FFF800,d1
        ori.w   #$400,d1
        move.l  d1,M_Y(a4)
        lsr.l   #8,d1
        moveq   #0,d2                   ; dx (careful: moveq clears C)
        cmp.w   M_HX(a4),d0
        beq.s   .yc
        bhi.s   .x1
        moveq   #4,d2
        bra.s   .yc
.x1:    moveq   #1,d2
.yc:    cmp.w   M_HY(a4),d1
        beq.s   .ye
        bhi.s   .y2
        moveq   #3,d0
        bra.s   .y3
.y2:    moveq   #2,d0
.y3:    tst.w   d2
        beq.s   .r
        btst    #3,G_MB+M_RNG+1(a6)     ; (M_RNG: the shared random bytes)
        bne.s   .r
        move.w  d2,d0
.r:     rts
.ye:    move.w  d2,d0
        bne.s   .r
        clr.w   M_T400(a4)
        move.w  M_PATH0(a4),M_O6CF(a4)
        move.w  #ST_SLINKY,M_STATE(a4)
        rts

;-----------------------------------------------------------------------------
; The slinky: it walks its path; a touch catches player
; 1 (stopped, dizzy $78) and it lunges; near player 1 (X + Y < $24) with the
; random bits clear it lunges too; it jumps at the player and a landing on it
; crushes it (state 9); then it settles and walks home.
;-----------------------------------------------------------------------------
st_slinky:
        clr.b   M_VX(a4)                ; (the speeds' high bytes = 0)
        clr.b   M_VY(a4)
        cmpi.b  #$80,M_S(a4)
        beq.s   .on
        clr.w   M_FID(a4)               ; off the screen
        move.w  #1,M_DRAWN(a4)
        rts
.on:    bsr     sl_catch
        bne     .done
        bsr     sl_phase
        bne     obj_bc95a               ; (not its frame: the attribute only)
        tst.b   M_O6CF+1(a4)
        bpl.s   .near
        move.b  G_MB+M_RNG+2(a6),d0
        andi.b  #$30,d0
        bne.s   .st
.near:  bsr     obj_nearself            ; d1 = the X + Y distance, or $FFFF
        cmpi.w  #$24,d1
        bhs.s   .st
        move.b  G_MB+M_RNG+1(a6),d0
        andi.b  #$30,d0
        bne.s   .st
        bra     sl_lunge_at
.st:    moveq   #8,d0
        bsr     obj_step
.fr:    move.w  M_VXS(a4),d1
        move.w  M_T400(a4),d0
        cmpi.w  #3,d1
        blo.s   .a
        neg.w   d0
        addq.w  #7,d0
.a:     andi.w  #$FF,d0
        beq.s   .17
        cmpi.w  #1,d1
        beq.s   .1e
        cmpi.w  #4,d1
        bne.s   .17
.1e:    addi.w  #$1E,d0
        bra     obj_bc95f
.17:    addi.w  #$17,d0
        bra     obj_bc95f
.done:  rts

; obj_nearself - player 1's X + Y distance from the object
; (rolling or $2A, on the ground, not frozen), else $FFFF: d1
obj_nearself:
        lea     G_MB(a6),a3
        move.w  #$FFFF,d1
        tst.b   M_F5CB+1(a3)
        bne.s   .o
        move.w  M_STATE(a3),d0
        cmpi.w  #1,d0
        beq.s   .e
        cmpi.w  #$2A,d0
        bne.s   .o
.e:     tst.b   M_GND+1(a3)
        beq.s   .o
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        move.l  M_X(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d0
        bcc.s   .x
        neg.w   d0
.x:     move.l  M_Y(a4),d2
        lsr.l   #8,d2
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        sub.w   d1,d2
        bcc.s   .y
        neg.w   d2
.y:     move.w  d0,d1
        add.w   d2,d1
        bcc.s   .o
        ori.w   #$FF00,d1
.o:     rts

; sl_catch - a touch (G_DC = 1) catches player 1 (stopped, dizzy $78) and
; the slinky lunges (sl_lunge_at). Out: Z clear when it did (the handler ends)
sl_catch:
        bsr     obj_collide1
        tst.w   d0
        beq.s   .o
        lea     G_MB(a6),a3
        clr.w   M_VX(a3)
        clr.w   M_VY(a3)
        move.w  #$78,M_DIZZY(a3)
        bsr.s   sl_lunge_at
        moveq   #1,d0
.o:     rts

; sl_lunge_at - at player 1: M_O6CF = 0, M_T400 = 0, vz $0400 up, state $1A,
; then the jump state's code (st_sljump)
sl_lunge_at:
        clr.w   M_O6CF(a4)
        clr.w   M_T400(a4)
        move.w  #$400,M_VZ(a4)
        move.w  #1,M_VZS(a4)
        move.w  #ST_SLLUNGE,M_STATE(a4)
        bra     st_sljump

; st_sllunge - while it has speed: damped by 5, a move, back if the
; depth there is not its home's; then state $11
st_sllunge:
        tst.w   M_VX(a4)
        bne.s   .mv
        tst.w   M_VY(a4)
        bne.s   .mv
        move.w  #ST_SLJUMP,M_STATE(a4)
        bra     st_sljump
.mv:    lea     M_VX(a4),a0
        moveq   #5,d1
        bsr     damp
        lea     M_VY(a4),a0
        moveq   #5,d1
        bsr     damp
        move.l  M_X(a4),M_PX(a4)
        move.l  M_Y(a4),M_PY(a4)
        bsr     integrate_xy
        bsr     sl_home_z
        beq.s   .f
        move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
        clr.w   M_VX(a4)
        clr.w   M_VY(a4)
.f:     moveq   #$17,d0
        bra     obj_bc95

; sl_home_z - the depth under it (Z fraction 0, geo_cell) = G_WZ79
; and its code has a floor: Z set when so
sl_home_z:
        clr.b   M_Z+3(a4)
        bsr     geo_cell
        tst.w   d0
        bne.s   .no
        btst    #16,d2
        bne.s   .no
        cmp.w   G_WZ79(a6),d2
        bne.s   .no
        tst.b   d4
        bmi.s   .no
        moveq   #0,d0                   ; (Z set)
        rts
.no:    moveq   #1,d0
        rts

; st_sljump - M_T400 counts to $18 (crouching); then the jump: with
; M_O6CF a player, 1/32 of the way to it a frame (sl_aim) and a move (back on
; its parity frames if the depth there is not home), else just Z; gravity
; $20; falling, a touch crushes the player; below home: home, state $12
st_sljump:
        cmpi.b  #$18,M_T400+1(a4)
        bhs.s   .jump
        addq.b  #1,M_T400+1(a4)
        moveq   #$17,d0
        move.b  M_T400+1(a4),d1
        cmpi.b  #$10,d1
        blo.s   .f
        moveq   #$27,d0
        cmpi.b  #$18,d1
        blo.s   .f
        moveq   #$37,d0
.f:     bra     obj_bc95
.jump:  tst.b   M_O6CF+1(a4)
        bpl.s   .aim
        moveq   #0,d0                   ; Z only
        move.w  M_VZ(a4),d0
        tst.b   M_VZS+1(a4)
        bne.s   .zu
        add.l   d0,M_Z(a4)
        bra.s   .g
.zu:    sub.l   d0,M_Z(a4)
        bra.s   .g
.aim:   bsr     sl_aim
        move.l  M_X(a4),M_PX(a4)
        move.l  M_Y(a4),M_PY(a4)
        bsr     integrate
        moveq   #1,d0
        and.b   M_SLOT+1(a4),d0
        moveq   #1,d1
        and.b   M_FC+1(a4),d1
        cmp.b   d1,d0
        bne.s   .g
        bsr     sl_home_z
        beq.s   .g
        move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
.g:     moveq   #$20,d1
        bsr     gravity
        tst.b   M_VZS+1(a4)
        beq.s   .down
        moveq   #$28,d0
        cmpi.b  #2,M_VZ(a4)
        blo.s   .f
        moveq   #$37,d0
        bra.s   .f
.down:  bsr     obj_collideFE           ; landing on the player crushes it
        tst.w   d0
        beq.s   .nc
        lea     G_MB(a6),a3
        move.w  #ST_DEAD,M_STATE(a3)
        bset    #5,G_MSFX+2(a6)         ; (effect 13: caught by the slinky)
        move.w  #$FF,M_O6CF(a4)
.nc:    move.l  M_Z(a4),d0
        lsr.l   #8,d0
        cmp.w   G_WZ79(a6),d0
        bhi.s   .home
        moveq   #$38,d0
        cmpi.b  #2,M_VZ(a4)
        blo     .f
        moveq   #$29,d0
        bra     .f
.home:  moveq   #0,d0
        move.w  G_WZ79(a6),d0
        lsl.l   #8,d0
        move.l  d0,M_Z(a4)
        clr.w   M_T400(a4)
        move.w  #ST_SLFALL,M_STATE(a4)
        bra.s   st_slfall

; sl_aim - per axis the low:fraction difference to player 1 (the high
; byte only for the sign) >> 5; sign 1 when the slinky is ahead
sl_aim:
        lea     G_MB(a6),a3
        lea     M_X(a4),a0
        lea     M_X(a3),a1
        bsr.s   .ax
        move.w  d1,M_VX(a4)
        move.w  d2,M_VXS(a4)
        lea     M_Y(a4),a0
        lea     M_Y(a3),a1
        bsr.s   .ax
        move.w  d1,M_VY(a4)
        move.w  d2,M_VYS(a4)
        rts
.ax:    move.b  3(a0),d1                ; fraction
        sub.b   3(a1),d1
        move.b  2(a0),d0                ; low (its own borrow only)
        sub.b   2(a1),d0
        move.b  1(a0),d3                ; high, with the low's borrow
        move.b  1(a1),d2
        subx.b  d2,d3
        lsl.w   #8,d0
        move.b  d1,d0
        moveq   #1,d2
        tst.b   d3
        bpl.s   .p
        neg.w   d0
        moveq   #0,d2
.p:     moveq   #0,d1
        move.w  d0,d1
        lsr.w   #5,d1
        rts

; st_slfall - settling, M_T400 to $17: then state $10 (M_O6CF was a
; player) or $13 (it was not), M_O6CF = $FF; frame $29 + M_T400 / 8
st_slfall:
        bsr     sl_catch
        bne.s   .o
        addq.b  #1,M_T400+1(a4)
        moveq   #0,d0
        move.b  M_T400+1(a4),d0
        cmpi.b  #$17,d0
        bne.s   .f
        tst.b   M_O6CF+1(a4)
        bmi.s   .r
        move.w  #ST_SLINKY,M_STATE(a4)
        clr.w   M_VXS(a4)
        bra.s   .z
.r:     move.w  #ST_SLREST,M_STATE(a4)
        move.w  #1,M_VXS(a4)
.z:     clr.w   M_T400(a4)
        move.w  #$FF,M_O6CF(a4)
.f:     lsr.b   #3,d0
        addi.b  #$29,d0
        bra     obj_bc95
.o:     rts

; st_slrest - on even frames M_T400 steps by M_VXS between 0 and 6,
; turning there; turned back positive: state $10
st_slrest:
        bsr     sl_catch
        bne.s   .o
        btst    #0,M_FC+1(a4)
        bne.s   .f
        move.b  M_VXS+1(a4),d0
        add.b   d0,M_T400+1(a4)
        move.b  M_T400+1(a4),d1
        beq.s   .t
        cmpi.b  #6,d1
        bne.s   .f
.t:     neg.b   d0
        move.b  d0,M_VXS+1(a4)
        bmi.s   .f
        move.w  #ST_SLINKY,M_STATE(a4)
        clr.w   M_VXS(a4)
        clr.w   M_T400(a4)
.f:     moveq   #$26,d0
        bra     obj_bc95
.o:     rts

; st_inacid - the player in a pool: every 4th frame one pixel
; towards the pool's X / Y; M_T400 counts; at $28 dead; frame obj_bd77[M_T400 / 8]
st_inacid:
        moveq   #3,d0
        and.b   M_FC+1(a4),d0
        bne.s   .c
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        cmp.w   M_POOLX(a4),d0
        beq.s   .y
        bhs.s   .xd
        addi.l  #$100,M_X(a4)
        bra.s   .y
.xd:    subi.l  #$100,M_X(a4)
.y:     move.l  M_Y(a4),d0
        lsr.l   #8,d0
        cmp.w   M_POOLY(a4),d0
        beq.s   .c
        bhs.s   .yd
        addi.l  #$100,M_Y(a4)
        bra.s   .c
.yd:    subi.l  #$100,M_Y(a4)
.c:     addq.b  #1,M_T400+1(a4)
        moveq   #0,d0
        move.b  M_T400+1(a4),d0
        cmpi.b  #$28,d0
        blo.s   .f
        move.w  #ST_DEAD,M_STATE(a4)
        rts
.f:     lsr.b   #3,d0
        lea     obj_bd77(pc),a0
        move.b  0(a0,d0.w),d0
        move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

;=============================================================================
; Aerial: the vacuums ($29), the hammers ($28), the piston group ($2D -> $27)
;=============================================================================
ST_VACUUM       equ     $29
ST_HAMMER       equ     $28
ST_PISTONS      equ     $2D             ; the group (once), then $27
ST_PISTON       equ     $27             ; a piston (its frame: display only)
ST_INVAC        equ     $2A             ; the player, caught by a vacuum

;-----------------------------------------------------------------------------
; st_vacuum - a vacuum. Its position is moved for the tests
; ($10 along its mouth, then 8 back per probe) and restored at the end
; (M_PX / M_PY). t400: 0 idle until player 1 is within $1C (X + Y) on its
; phase frames; 1-$13 opening; $14-$1B sucking (cycling) while the player
; stays near: the probes (vac_catch), within $10 a pull (vac_pull), $10 frames
; without the player and it closes ($1C-$2F, then 0).
;-----------------------------------------------------------------------------
st_vacuum:
        ori.b   #4,M_X+2(a4)            ; (the middle of its cell)
        ori.b   #4,M_Y+2(a4)
        move.l  M_X(a4),M_PX(a4)        ; (kept: restored at the end)
        move.l  M_Y(a4),M_PY(a4)
        cmpi.w  #4,M_O6CF(a4)
        blo.s   .x
        move.w  #$41,M_ATTR(a4)         ; ($41 for 4 / 5, else 1)
        addi.l  #$1000,M_Y(a4)          ; ($10 along its mouth)
        andi.l  #$FFFFFF,M_Y(a4)
        bra.s   .t
.x:     move.w  #1,M_ATTR(a4)
        addi.l  #$1000,M_X(a4)
        andi.l  #$FFFFFF,M_X(a4)
.t:     move.w  M_T400(a4),d0
        bne.s   .t1
        bsr     vac_near                ; idle
        bmi.s   .rest
        moveq   #1,d0                   ; (30 Hz: with the test frame - frame & 3 =
        btst    #0,M_O6CF+1(a4)         ;  M_O6CF & 3 - the pair's first, its second
        bne.s   .i1                     ;  frame's step too: 2. Without it the vacuum
        moveq   #2,d0                   ;  falls a frame behind at each such set and
.i1:    move.w  d0,M_T400(a4)           ;  opens again up to 4 frames late)
.rest:  move.l  M_PX(a4),M_X(a4)
        move.l  M_PY(a4),M_Y(a4)
        rts
.t1:    cmpi.w  #$14,d0
        bhs.s   .t2
        addq.w  #2,d0                   ; opening (30 Hz: two frames a run)
        move.w  d0,M_T400(a4)
        clr.w   M_VYS(a4)
        bra.s   .done
.t2:    cmpi.w  #$1C,d0
        blo.s   .suck
        addq.w  #2,d0                   ; closing
        cmpi.w  #$30,d0
        blo.s   .t3
        beq.s   .t0                     ; (30 Hz: shut on the pair's first frame, the
        btst    #0,M_O6CF+1(a4)         ;  second idle: its near test when it is the
        beq.s   .t0                     ;  test frame)
        bsr     vac_near
        bmi.s   .t0
        moveq   #1,d0
        bra.s   .t3
.t0:    moveq   #0,d0
.t3:    move.w  d0,M_T400(a4)
        bra.s   .done
.suck:  addq.w  #2,d0                   ; sucking: $14-$1B, cycling
        andi.w  #7,d0
        addi.w  #$14,d0
        move.w  d0,M_T400(a4)
        bsr     vac_catch
        bsr     vac_near
        bpl.s   .near
        addq.b  #2,M_VYS+1(a4)
        moveq   #0,d0
        move.b  M_VYS+1(a4),d0
        subi.w  #$10,d0
        bcs.s   .done
        move.b  #$10,M_VYS+1(a4)        ; (30 Hz: reached on the first frame: the
        addi.w  #$1C,d0                 ;  second's closing step too, $1D)
        move.w  d0,M_T400(a4)
        bra.s   .done
.near:  cmpi.w  #$10,d1                 ; within $10: a pull
        bhs.s   .clr
        bsr     vac_pull
.clr:   moveq   #1,d0                   ; (30 Hz: the test frame the pair's first: the
        and.w   M_O6CF(a4),d0           ;  second counts on, 1)
        eori.w  #1,d0
        move.w  d0,M_VYS(a4)
.done:  move.l  M_PX(a4),M_X(a4)        ; (its position restored)
        move.l  M_PY(a4),M_Y(a4)
        move.w  M_T400(a4),d0
        lsr.w   #2,d0
        lea     obj_b972(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

; vac_near - on the phase frames (frame & 3 = M_O6CF & 3) player 1's X + Y
; distance (obj_nearself) when under $1C: d1, N clear; else N set
vac_near:
        moveq   #2,d0                   ; (30 Hz: frame & 2 = M_O6CF & 2)
        and.b   M_FC+1(a4),d0
        moveq   #2,d1
        and.b   M_O6CF+1(a4),d1
        cmp.b   d1,d0
        bne.s   .no
        bsr     obj_nearself
        cmpi.w  #$1C,d1
        bhs.s   .no
        tst.w   d1                      ; (N clear)
        rts
.no:    moveq   #-1,d0
        rts

; vac_catch - three probes along the mouth, the vacuum 8 further back
; each time (vac_back), G_DC = $80 (no push, |dY| not doubled). A touch at the
; first: pushed in; at the second: caught when within 4 across the mouth
; (state $2A, M_T6CF $02 / $42, t400 5), else pushed with the PLAYER's M_T6CF
; (the player's block is the one read there); at the third: pushed out.
vac_catch:
        bsr     obj_collide80
        tst.w   d0
        beq.s   .p2
        move.w  M_O6CF(a4),d6
        moveq   #0,d7
        bra     vac_push
.p2:    bsr.s   vac_back
        bsr     obj_collide80
        tst.w   d0
        beq.s   .p3
        lea     G_MB(a6),a3
        cmpi.w  #4,M_O6CF(a4)
        blo.s   .cx
        move.w  G_C15(a6),d0
        moveq   #$42,d1
        bra.s   .cc
.cx:    move.w  G_C14(a6),d0
        moveq   #$02,d1
.cc:    cmpi.w  #4,d0
        bhs.s   .np
        move.w  d1,M_T6CF(a3)           ; caught
        move.w  #ST_INVAC,M_STATE(a3)
        bset    #1,G_MSFX+2(a6)         ; (effect 9: the vacuum)
        move.w  #5,M_T400(a3)
        clr.w   M_VXS(a3)
        rts
.np:    move.w  M_T6CF(a3),d6
        moveq   #1,d7
        bra.s   vac_push
.p3:    bsr.s   vac_back
        bsr     obj_collide80
        tst.w   d0
        beq.s   .o
        move.w  M_O6CF(a4),d6
        moveq   #-1,d7
        bra.s   vac_push
.o:     rts

; vac_back - the vacuum 8 back (X for M_O6CF >= 4, else Y)
vac_back:
        cmpi.w  #4,M_O6CF(a4)
        blo.s   .y
        subi.l  #$800,M_X(a4)
        andi.l  #$FFFFFF,M_X(a4)
        rts
.y:     subi.l  #$800,M_Y(a4)
        andi.l  #$FFFFFF,M_Y(a4)
        rts

; vac_push - d6 = the M_O6CF / M_T6CF read, d7 = 0 (in), 1 (grown), -1 (out):
; across the mouth centred when within 3 / 4, $18 into it, then
; $50 along it
vac_push:
        move.l  a4,-(sp)
        lea     G_MB(a6),a3
        movea.l a3,a4                   ; (accel on the player's block)
        cmpi.w  #4,d6
        blo.s   .xa
        cmpi.w  #3,G_C15(a6)            ; within 3 across: centred
        bhs.s   .y1
        clr.w   M_VYS(a4)
        move.w  #$80,M_VY(a4)
.y1:    lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        moveq   #$18,d1
        bsr     accel_neg               ; -Y
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bra.s   .k
.xa:    cmpi.w  #4,G_C14(a6)            ; within 4 across: centred
        bhs.s   .x1
        clr.w   M_VXS(a4)
        move.w  #$80,M_VX(a4)
.x1:    lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        moveq   #$18,d1
        bsr     accel_neg               ; -X
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
.k:     moveq   #$50,d1
        tst.w   d7
        beq.s   .kn
        bmi.s   .kp
        bsr     grow                    ; (the speed grown, either sign)
        bra.s   .ko
.kn:    bsr     accel_neg               ; -X / -Y
        bra.s   .ko
.kp:    bsr     accel_pos               ; +X / +Y
.ko:    movea.l (sp)+,a4
        rts

; vac_pull - the player pulled by 2 (M_O6CF < 4) or 8, in Y towards the
; (moved) vacuum; in X the test compares with the X of the slot numbered by
; the player's M_VYS from before the Y push: itself (always >=: +) or
; player 2's
vac_pull:
        lea     G_MB(a6),a3
        moveq   #2,d5
        cmpi.w  #4,M_O6CF(a4)
        blo.s   .a
        moveq   #8,d5
.a:     move.w  M_VYS(a3),d4
        move.l  M_Y(a4),d0
        lsr.l   #8,d0
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        move.l  a4,-(sp)
        movea.l a3,a4
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        cmp.w   d1,d0
        bhs.s   .yp
        move.w  d5,d1
        bsr     accel_neg               ; -Y
        bra.s   .x
.yp:    move.w  d5,d1
        bsr     accel_pos               ; +Y
.x:     move.l  M_X(a4),d1
        lsr.l   #8,d1
        move.w  d1,d0
        tst.b   d4
        beq.s   .c
        move.w  G_WP2X(a6),d0
.c:     lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        cmp.w   d1,d0
        bhs.s   .xp
        move.w  d5,d1
        bsr     accel_neg               ; -X
        bra.s   .o
.xp:    move.w  d5,d1
        bsr     accel_pos               ; +X
.o:     movea.l (sp)+,a4
        rts

; st_invac - the player in a vacuum (from marble_frame): every 16 frames
; (counted in M_VXS) t400 down; below 0 dead. (The marble is not drawn
; while inside.)
st_invac:
        addq.b  #1,M_VXS+1(a4)
        cmpi.b  #$10,M_VXS+1(a4)
        blo.s   .f
        clr.w   M_VXS(a4)
        subq.b  #1,M_T400+1(a4)
        bpl.s   .f
        move.w  #ST_DEAD,M_STATE(a4)
.f:     move.w  #$67,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

;-----------------------------------------------------------------------------
; st_hammer - a hammer: idle until frame & $7F = its entry in
; obj_e9cf (by X and G_WF7DD) with the scroll's low byte >= $AF; then t400 counts to
; $38 (then idle). From $14 to $23 it also hits 8 further up. A touch (G_DC = 1:
; both pushed once) makes player 1 dizzy for $1E frames.
;-----------------------------------------------------------------------------
st_hammer:
        move.w  #1,M_ATTR(a4)
        ori.b   #4,M_X+2(a4)            ; (the middle of its cell)
        ori.b   #4,M_Y+2(a4)
        move.w  M_T400(a4),d1
        bne.s   .run
        move.b  M_X+2(a4),d0
        subi.b  #$E4,d0
        lsr.b   #4,d0
        or.b    G_WF7DD+1(a6),d0
        andi.w  #$FF,d0
        lea     obj_e9cf(pc),a0
        moveq   #$7E,d2                 ; (30 Hz: on the frames it runs)
        and.b   M_FC+1(a4),d2
        moveq   #$7E,d3
        and.b   0(a0,d0.w),d3
        cmp.b   d3,d2
        bne.s   .o
        lea     G_MB(a6),a3
        cmpi.b  #$AF,M_SCROLL+1(a3)
        blo.s   .o
.run:   addq.w  #2,d1
        cmpi.w  #$38,d1
        bne.s   .go
        clr.w   M_T400(a4)
.o:     rts
.go:    move.w  d1,M_T400(a4)
        cmpi.w  #$14,d1
        blo.s   .h
        cmpi.w  #$24,d1
        bhs.s   .h
        subi.l  #$800,M_Y(a4)           ; (8 up)
        andi.l  #$FFFFFF,M_Y(a4)
        bsr.s   .hit
        addi.l  #$800,M_Y(a4)           ; (and back)
        andi.l  #$FFFFFF,M_Y(a4)
.h:     bsr.s   .hit
        move.w  M_T400(a4),d0
        lsr.w   #2,d0
        lea     obj_e9df(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.hit:   bsr     obj_collide1
        tst.w   d0
        beq.s   .n
        lea     G_MB(a6),a3
        move.w  #$1E,M_DIZZY(a3)
.n:     rts

;-----------------------------------------------------------------------------
; st_pistons - the piston group, once: which piston by X ($80 0, $C0 1,
; else 2), then state $27 (a piston: display only, no logic)
;-----------------------------------------------------------------------------
st_pistons:
        move.b  M_X+2(a4),d0
        moveq   #0,d1
        cmpi.b  #$80,d0
        beq.s   .s
        moveq   #1,d1
        cmpi.b  #$C0,d0
        beq.s   .s
        moveq   #2,d1
.s:     move.w  d1,M_O6CF(a4)
        move.w  #ST_PISTON,M_STATE(a4)
        bra     obj_mark

;=============================================================================
; Silly: the birds ($22-$25) and the mini marbles ($1F-$21)
;=============================================================================
ST_BIRDIN       equ     $22             ; coming in
ST_BIRD         equ     $23             ; the flight
ST_BIRDTURN     equ     $24             ; turning
ST_BIRDOUT      equ     $25             ; going out
ST_CARRIED      equ     $26             ; the player, carried off (as $0B)
ST_MINI1        equ     $1F
ST_MINI2        equ     $20
ST_MINI3        equ     $21

;-----------------------------------------------------------------------------
; st_birdc0b4 - a bird coming in ($22) or going out ($25): attribute 3,
; $18 frames (frames $0A / $0B); then $22 -> $23, $25 -> gone (state 0; its
; spawn entry stays: the walker frees it)
;-----------------------------------------------------------------------------
st_birdc0b4:
        move.w  #3,M_ATTR(a4)
        addq.b  #2,M_T400+1(a4)         ; (30 Hz: two frames a run)
        cmpi.b  #$18,M_T400+1(a4)
        blo.s   .f
        clr.w   M_T400(a4)
        cmpi.w  #ST_BIRDIN,M_STATE(a4)
        bne.s   .gone
        move.w  #ST_BIRD,M_STATE(a4)
        rts
.gone:  clr.w   M_STATE(a4)
        bra     obj_mark
.f:     moveq   #0,d0
        move.b  M_T400+1(a4),d0
        lsr.b   #3,d0
        andi.w  #1,d0
        ori.w   #$0A,d0
        move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

;-----------------------------------------------------------------------------
; st_bird - the flight: X speed 1.xx towards -X, its fraction flipped
; by $F0 every 32 frames unless M_RNG & obj_eaa8[M_O6CF]; past its X limit
; (obj_eaae / obj_eab4) it turns ($24, run at once); off the screen (S high
; >= 0) it goes; a touch (G_DC = $FE: no push) carries player 1 off (state
; $26, M_VXS $0D, M_VYS $15)
;-----------------------------------------------------------------------------
st_bird:
        move.w  #1,M_ATTR(a4)
        move.b  #1,M_VX(a4)
        move.w  M_T400(a4),d0
        beq.s   .mv
        andi.b  #$1F,d0
        bne.s   .mv
        move.w  M_O6CF(a4),d1
        lea     obj_eaa8(pc),a0
        move.b  0(a0,d1.w),d2
        and.b   G_MB+M_RNG+1(a6),d2
        bne.s   .mv
        eori.b  #$F0,M_VX+1(a4)
.mv:    move.w  M_O6CF(a4),d1           ; d5 = its X limit
        lea     obj_eab4(pc),a0
        move.b  0(a0,d1.w),d5
        lsl.w   #8,d5
        lea     obj_eaae(pc),a0
        move.b  0(a0,d1.w),d5
        move.w  M_S(a4),d3              ; the first frame's screen y (the last run's)
        cmpi.w  #$8010,d3               ; (30 Hz: far from the top and from its X limit
        blo.s   .sl                     ;  no test can fire in the pair - two moves of
        move.l  M_X(a4),d0              ;  at most 1.94 px - so both moves, no tests)
        lsr.l   #8,d0
        sub.w   d5,d0
        cmpi.w  #4,d0
        blt.s   .sl
        bsr     move_xn
        bsr     move_xn
        bra.s   .c
.sl:    moveq   #1,d4                   ; (the pair's two frames, each with its own
.fr:    bsr     move_xn                 ;  tests)
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        cmp.w   d5,d0
        bhs.s   .on
        move.w  #ST_BIRDTURN,M_STATE(a4)
        moveq   #0,d0                   ; (turned on the second frame: one count of
        tst.w   d4                      ;  the turn there, not two: $FF + 2 = 1)
        bne.s   .tz
        move.w  #$FF,d0
.tz:    move.w  d0,M_T400(a4)
        bra.s   st_birdturn
.on:    tst.w   d3                      ; off the screen (its screen y's high bit 0)
        bmi.s   .nx
        clr.w   M_STATE(a4)             ; gone
        bra     obj_mark
.nx:    dbra    d4,.sc
        bra.s   .c
.sc:    cmpi.w  #$8010,d3               ; (only within 16 px of the top, where a frame's
        bhs.s   .fr                     ;  move and scroll can take it off: no cost)
        move.l  M_X(a4),d0              ; (30 Hz: the second frame's off-the-screen test
        add.l   M_Y(a4),d0              ;  reads the screen y as at the end of the
        lsr.l   #8,d0                   ;  first, from the bird moved once: with both
        lsr.w   #1,d0                   ;  moves before one test a bird leaves the top a
        move.l  M_Z(a4),d1              ;  frame late, by then past its X limit, and
        lsr.l   #8,d1                   ;  turns back where at 60 Hz it is gone)
        add.w   d1,d0
        sub.w   G_MB+M_SCROLL(a6),d0
        addi.w  #$C0,d0
        move.w  d0,d3
        bra.s   .fr
.c:     bsr     obj_collideFE
        tst.w   d0
        beq.s   .t
        lea     G_MB(a6),a3
        move.w  #ST_CARRIED,M_STATE(a3)
        move.w  #$0D,M_VXS(a3)
        move.w  #$15,M_VYS(a3)
.t:     addq.b  #2,M_T400+1(a4)
        moveq   #0,d0
        move.b  M_T400+1(a4),d0
        lsr.b   #3,d0
        andi.w  #1,d0
        addi.w  #$55,d0
        move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

; st_birdturn - $20 frames ($57 / $58), then going out ($25, at once)
st_birdturn:
        addq.b  #2,M_T400+1(a4)
        cmpi.b  #$20,M_T400+1(a4)
        blo.s   .f
        clr.w   M_T400(a4)
        move.w  #ST_BIRDOUT,M_STATE(a4)
        bra     st_birdc0b4
.f:     moveq   #0,d0
        move.b  M_T400+1(a4),d0
        lsr.b   #2,d0
        andi.w  #1,d0
        addi.w  #$57,d0
        move.w  d0,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts

; st_carried - the player carried off by a bird (state $26):
; both counters count UP; from $30 dead when M_RNG & 7 = 0, from $50 dead anyway
st_carried:
        addq.b  #1,M_VYS+1(a4)
        addq.b  #1,M_VXS+1(a4)
        move.b  M_VXS+1(a4),d0
        cmpi.b  #$30,d0
        blo.s   .f
        cmpi.b  #$50,d0
        bhs.s   .d
        moveq   #7,d1
        and.b   M_RNG+1(a4),d1
        bne.s   .f
.d:     move.w  #ST_DEAD,M_STATE(a4)
        rts
.f:     move.w  #$30,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        btst    #0,M_FC+1(a4)
        bne.s   .o
        subq.b  #3,M_T400+1(a4)         ; (as in st_wait)
.o:     rts

;-----------------------------------------------------------------------------
; st_mini - a mini marble ($1F-$21). Taken (t400 bit
; 7): only its taken frame; on its phase (frame bit 2 = slot bit 0) a touch
; (G_DC = $FF: no push) takes it: +3 s (time_event 8). Then the AI (mini_ai)
; and its frame by type.
;-----------------------------------------------------------------------------
st_mini:
        move.w  #1,M_ATTR(a4)
        move.w  M_STATE(a4),d0
        moveq   #$47,d7                 ; the taken frame: $1F $47, $20 $46, $21 $45
        sub.w   d0,d7
        addi.w  #$1F,d7
        tst.b   M_T400+1(a4)
        bmi.s   .took
        moveq   #0,d0
        move.b  M_FC+1(a4),d0
        lsr.b   #2,d0
        move.b  M_SLOT+1(a4),d1
        eor.b   d1,d0
        btst    #0,d0
        bne.s   .ai
        bsr     obj_collideFF
        tst.w   d0
        beq.s   .ai
        move.w  #$FF,M_T400(a4)
        move.l  a4,-(sp)
        lea     G_MB(a6),a4
        moveq   #8,d0
        bsr     time_event              ; +3 s
        movea.l (sp)+,a4
        bset    #0,G_MSFX+2(a6)         ; (effect 8: an enemy squashed; src/music.asm)
.took:  move.w  d7,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.ai:    bsr     mini_ai
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_MINI3,d0
        bne.s   .m2
        cmpi.w  #2,M_VZS(a4)            ; $21: by its facing
        blo.s   .m3x
        move.w  #1,M_ATTR(a4)
        move.l  M_Y(a4),d0
        bra.s   .m3
.m3x:   move.w  #$41,M_ATTR(a4)
        move.l  M_X(a4),d0
.m3:    lsr.l   #7,d0                   ; (middle byte << 1 | fraction >> 7)
        andi.w  #7,d0
        lea     obj_eaef(pc),a0
        bra.s   .fid
.m2:    cmpi.w  #ST_MINI2,d0
        bne.s   .m1
        cmpi.w  #2,M_VZS(a4)            ; $20: by its facing
        blo.s   .m2x
        move.w  #$41,M_ATTR(a4)
        move.b  M_Y+2(a4),d0
        bra.s   .m2a
.m2x:   move.b  M_X+2(a4),d0
.m2a:   andi.w  #3,d0
        lea     obj_eb1d(pc),a0
.fid:   moveq   #0,d1
        move.b  0(a0,d0.w),d1
        move.w  d1,M_FID(a4)
        move.w  #1,M_DRAWN(a4)
        rts
.m1:    move.w  #$48,M_FID(a4)          ; $1F: one frame
        move.w  #1,M_DRAWN(a4)
        rts

; mini_ai - 15 Hz: the AI for the block's two
; odd frames (b + 1, b + 3; b = frame & ~3). Only odd slots ever move (only
; on odd frames). A player at their level (rolling, Z middle byte $99-$A0):
; when frame & 7 = slot falls in the block ((b & 4) = (slot & 4)) it heads home
; (mini_home) and flees player 1 within $18 (X + Y, obj_nearself) on that frame: speed $80
; away on both axes, then maybe one axis only (mini_one). On b + 1 (slot & 3 = 1)
; before both moves, as one at twice the speed; on b + 3 after b + 1's move at the
; old speeds, then b + 3's. Else both frames' moves as one at twice the speed.
; Nobody there: the one frame b + (slot & 3): a random direction (mini_wander)
; when frame & $3F = slot ((frame & $3C) = (slot & 4)); one move.
mini_ai:
        btst    #0,M_SLOT+1(a4)
        beq     .o
        lea     G_MB(a6),a3
        cmpi.w  #1,M_STATE(a3)
        bne     .nob
        move.b  M_Z+2(a3),d0
        cmpi.b  #$99,d0
        blo     .nob
        cmpi.b  #$A1,d0
        bhs     .nob
        move.b  M_FC+1(a4),d0
        move.b  M_SLOT+1(a4),d1
        eor.b   d1,d0
        btst    #2,d0
        bne     mini_move2
        btst    #1,M_SLOT+1(a4)         ; (on b + 3: b + 1's move first)
        beq.s   .h
        bsr     mini_move
.h:     bsr     mini_home
        bsr     obj_nearself
        cmpi.w  #$18,d1
        bhs.s   .mv
        lea     G_MB(a6),a3
        moveq   #0,d0
        move.l  M_X(a4),d1
        lsr.l   #8,d1
        move.l  M_X(a3),d2
        lsr.l   #8,d2
        cmp.w   d2,d1
        bhs.s   .x
        moveq   #1,d0
.x:     move.w  d0,M_VXS(a4)
        moveq   #0,d0
        move.l  M_Y(a4),d1
        lsr.l   #8,d1
        move.l  M_Y(a3),d2
        lsr.l   #8,d2
        cmp.w   d2,d1
        bhs.s   .y
        moveq   #1,d0
.y:     move.w  d0,M_VYS(a4)
        move.w  #$80,M_VX(a4)
        move.w  #$80,M_VY(a4)
        bsr     mini_one
.mv:    btst    #1,M_SLOT+1(a4)         ; (the block's other move, or both)
        bne     mini_move
        bra     mini_move2
.nob:   moveq   #$3C,d0
        and.b   M_FC+1(a4),d0
        moveq   #4,d1
        and.b   M_SLOT+1(a4),d1
        cmp.b   d1,d0
        bne     mini_move
        bsr     mini_wander
        bra     mini_move
.o:     rts

; mini_home - $80 towards its home (obj_ec25 / obj_ec2b by M_O6CF, middle bytes)
; on each axis not there yet; at home in Y only the facing (M_VZS); else mini_one
mini_home:
        clr.w   M_VXS(a4)
        clr.w   M_VX(a4)
        clr.w   M_VYS(a4)
        clr.w   M_VY(a4)
        move.w  M_O6CF(a4),d1
        lea     obj_ec25(pc),a0
        move.b  M_X+2(a4),d0
        cmp.b   0(a0,d1.w),d0
        beq.s   .y
        bls.s   .x
        move.w  #1,M_VXS(a4)
.x:     move.w  #$80,M_VX(a4)
.y:     lea     obj_ec2b(pc),a0
        move.b  M_Y+2(a4),d0
        cmp.b   0(a0,d1.w),d0
        bne.s   .y1
        cmpi.w  #ST_MINI1,M_STATE(a4)   ; ($1F: no facing)
        beq.s   .o
        move.w  M_VXS(a4),d0
        eori.w  #1,d0
        move.w  d0,M_VZS(a4)
.o:     rts
.y1:    bls.s   .y2
        move.w  #1,M_VYS(a4)
.y2:    move.w  #$80,M_VY(a4)
; mini_one - (not $1F): moving in X, M_RNG bit 7 keeps X only (facing
; from vxs), else Y only (facing from vys)
mini_one:
        cmpi.w  #ST_MINI1,M_STATE(a4)
        beq.s   .o
        tst.b   M_VX+1(a4)
        bpl.s   .ys
        tst.b   G_MB+M_RNG+1(a6)
        bpl.s   .yo
        clr.w   M_VY(a4)                ; X only
        move.w  M_VXS(a4),d0
        eori.w  #1,d0
        move.w  d0,M_VZS(a4)
        rts
.yo:    clr.w   M_VX(a4)
.ys:    move.w  M_VYS(a4),d0
        eori.w  #3,d0
        move.w  d0,M_VZS(a4)
.o:     rts

; mini_wander - a random direction (rand & 3; kept when it equals obj_ec7a's
; entry for it): speeds obj_ec6a + 0 / + 4 (halved for $21), signs + 8 / + 12
mini_wander:
        move.l  a4,-(sp)
        moveq   #3,d0                   ; (15 Hz: the draw as on the 60 Hz frame
        and.b   M_SLOT+1(a4),d0         ;  b + (slot & 3): rand mixes in the frame)
        lea     G_MB(a6),a4
        move.w  M_FC(a4),-(sp)
        andi.b  #$FC,M_FC+1(a4)
        or.b    d0,M_FC+1(a4)
        bsr     rand
        move.w  (sp)+,M_FC(a4)
        movea.l (sp)+,a4
        andi.w  #3,d0
        lea     obj_ec7a(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        cmp.w   M_VZS(a4),d1
        bne.s   .k
        move.w  M_VZS(a4),d0
.k:     move.w  d0,M_VZS(a4)
        lea     obj_ec6a(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        moveq   #0,d2
        move.b  4(a0,d0.w),d2
        cmpi.w  #ST_MINI3,M_STATE(a4)
        bne.s   .h
        lsr.w   #1,d1
        lsr.w   #1,d2
.h:     move.w  d1,M_VX(a4)
        move.w  d2,M_VY(a4)
        moveq   #0,d1
        move.b  8(a0,d0.w),d1
        move.w  d1,M_VXS(a4)
        move.b  12(a0,d0.w),d1
        move.w  d1,M_VYS(a4)
        rts

; mini_move - speeds' high bytes 0; X moved, undone (middle and low
; bytes) where the obj_ed09 map forbids it; then Y the same. mini_move2: at twice the
; speed (15 Hz: a block's two moves as one). No speed: nothing moves (a move
; of 0, its undo the same), so nothing is done
mini_move2:
        moveq   #1,d3
        bra.s   mini_mv
mini_move:
        moveq   #0,d3
mini_mv:
        clr.b   M_VX(a4)
        clr.b   M_VY(a4)
        move.w  M_VX(a4),d0
        or.w    M_VY(a4),d0
        beq.s   .o
        move.w  M_X+2(a4),-(sp)
        lea     M_X(a4),a0
        move.w  M_VX(a4),d1
        lsl.w   d3,d1
        tst.w   M_VXS(a4)
        beq.s   .xp
        bsr     mv_n                    ; -X
        bra.s   .xc
.xp:    bsr     mv_p                    ; +X
.xc:    bsr.s   mini_blocked
        move.w  (sp)+,d1
        tst.b   d0
        beq.s   .y
        move.w  d1,M_X+2(a4)
.y:     move.w  M_Y+2(a4),-(sp)
        lea     M_Y(a4),a0
        move.w  M_VY(a4),d1
        lsl.w   d3,d1
        tst.w   M_VYS(a4)
        beq.s   .yp
        bsr     mv_n                    ; -Y
        bra.s   .yc
.yp:    bsr     mv_p                    ; +Y
.yc:    bsr.s   mini_blocked
        move.w  (sp)+,d1
        tst.b   d0
        beq.s   .o
        move.w  d1,M_Y+2(a4)
.o:     rts

; mini_blocked - d0.b = obj_ed09[((X - $70) >> 2) & $1E (+1 when the Y
; index >= 8)] & obj_ecf9[(Y - $70) >> 3] (middle bytes); non-zero: blocked
mini_blocked:
        move.b  M_X+2(a4),d1
        subi.b  #$70,d1
        lsr.b   #2,d1
        andi.w  #$1E,d1
        move.b  M_Y+2(a4),d2
        subi.b  #$70,d2
        lsr.b   #3,d2
        andi.w  #$FF,d2
        cmpi.b  #8,d2
        blo.s   .a
        addq.w  #1,d1
.a:     lea     obj_ed09(pc),a0
        move.b  0(a0,d1.w),d0
        lea     obj_ecf9(pc),a0
        and.b   0(a0,d2.w),d0
        rts

;-----------------------------------------------------------------------------
; pistons - Aerial's piston field, from objects_post after the
; objects' screen y: every frame, per piston object ($27, slots 7-2) its
; group's flag (G_WP7DA[M_O6CF]) = 0 while player 1 (rolling) is in the group's
; box (obj_pbox: X and Y ranges, Z middle byte below a limit), else 1. On
; odd frames every running cell (G_WP6D7 n > 0) steps on (& $0F: 1-15, then 0),
; then ONE group with the player inside runs its script (pis_group): frame
; bit 1 set: group 2, else 1 (group 0 is not looked at); clear: 0, 1, 2. The
; groups passed over have their delay cleared.
;-----------------------------------------------------------------------------
pistons:
        lea     G_WP6D7(a6),a0          ; (the cells before this frame's step: what
        lea     G_PSNAP(a6),a1          ; is shown after it: piston_draw)
        moveq   #9-1,d0
.sn:    move.l  (a0)+,(a1)+
        dbra    d0,.sn
        lea     G_MB(a6),a3
        move.l  M_X(a3),d0              ; player 1's X, Y (16-bit)
        lsr.l   #8,d0
        move.l  M_Y(a3),d1
        lsr.l   #8,d1
        move.b  M_Z+2(a3),d4            ; Z middle byte
        lea     G_OBJ+5*M_SIZE(a6),a2   ; slot 7 first
        moveq   #5,d7
.ob:    cmpi.w  #ST_PISTON,M_STATE(a2)
        bne.s   .nx
        move.w  M_O6CF(a2),d6
        moveq   #1,d5                   ; outside
        cmpi.w  #1,M_STATE(a3)
        bne.s   .set
        move.w  d6,d2                   ; obj_pbox: 5 words per group
        mulu.w  #10,d2
        lea     obj_pbox(pc),a0
        adda.w  d2,a0
        move.w  d0,d3                   ; X >= from (the difference's sign)
        sub.w   (a0)+,d3
        bmi.s   .set
        move.w  d0,d3                   ; X < to
        sub.w   (a0)+,d3
        bpl.s   .set
        move.w  d1,d3                   ; Y >= from
        sub.w   (a0)+,d3
        bmi.s   .set
        move.w  d1,d3                   ; Y < to
        sub.w   (a0)+,d3
        bpl.s   .set
        cmp.b   1(a0),d4                ; Z middle byte < the limit
        bhs.s   .set
        moveq   #0,d5
.set:   lea     G_WP7DA(a6),a0
        move.b  d5,0(a0,d6.w)
.nx:    lea     -M_SIZE(a2),a2
        dbra    d7,.ob
        btst    #0,M_FC+1(a3)
        beq.s   .o
        lea     G_WP6D7(a6),a0          ; the running cells step on (four at a
        moveq   #8,d0                   ; time: most are idle)
.c:     tst.l   (a0)+
        beq.s   .c1
        moveq   #3,d2
.c2:    move.b  -4(a0,d2.w),d1
        beq.s   .c3
        addq.b  #1,d1
        andi.b  #$0F,d1
        move.b  d1,-4(a0,d2.w)
.c3:    dbra    d2,.c2
.c1:    dbra    d0,.c
        lea     G_WP7DA(a6),a1
        btst    #1,M_FC+1(a3)
        beq.s   .asc
        moveq   #2,d6                   ; 2, then 1 (then 2 again)
        tst.b   2(a1)
        beq.s   pis_group
        clr.b   G_WPA1+2(a6)
        moveq   #1,d6
        tst.b   1(a1)
        beq.s   pis_group
        clr.b   G_WPA1+1(a6)
.o:     rts
.asc:   moveq   #0,d6                   ; 0, 1, 2
.as:    tst.b   0(a1,d6.w)
        beq.s   pis_group
        lea     G_WPA1(a6),a0
        clr.b   0(a0,d6.w)
        addq.w  #1,d6
        cmpi.w  #3,d6
        bne.s   .as
        rts

; pis_group - group d6's script (obj_pscr) a step: with no delay left, its
; bytes from its position: a cell to start (< $24: G_WP6D7[n] = 1), $50 + 4
; bytes (a display position: skipped), $7F restart, a loop start (count,
; start) and end ($7E), until a delay (bit 7: delay = n & $7F); then delay - 1.
; The group's bytes from G_WP7DA + d6: +0 the in-box flag, +3 the position,
; +6 the delay (G_WPA1), +9 the loop count, +12 the loop start.
pis_group:
        lea     G_WP7DA(a6),a0
        adda.w  d6,a0
        tst.b   6(a0)
        bne.s   .dec
        lea     obj_pscr(pc),a2
        moveq   #0,d0
        move.b  .soff(pc,d6.w),d0
        adda.w  d0,a2
        moveq   #0,d2
        move.b  3(a0),d2
        lea     G_WP6D7(a6),a1
.lp:    move.b  0(a2,d2.w),d0
        bmi.s   .delay
        cmpi.b  #$24,d0
        bhs.s   .n1
        andi.w  #$FF,d0
        move.b  #1,0(a1,d0.w)           ; a cell starts
        addq.b  #1,d2
        bra.s   .lp
.n1:    cmpi.b  #$50,d0                 ; a display position
        bne.s   .n2
        addq.b  #5,d2
        bra.s   .lp
.n2:    cmpi.b  #$7F,d0                 ; restart
        bne.s   .n3
        moveq   #0,d2
        bra.s   .lp
.n3:    cmpi.b  #$7E,d0                 ; a loop's end
        bne.s   .n4
        subq.b  #1,9(a0)
        beq.s   .n3a
        move.b  12(a0),d2
        bra.s   .lp
.n3a:   addq.b  #1,d2
        bra.s   .lp
.n4:    andi.b  #$3F,d0                 ; a loop's start
        move.b  d0,9(a0)
        addq.b  #1,d2
        move.b  d2,12(a0)
        bra.s   .lp
.delay: andi.b  #$7F,d0                 ; a delay: the position kept
        move.b  d0,6(a0)
        addq.b  #1,d2
        move.b  d2,3(a0)
.dec:   subq.b  #1,6(a0)                ; the delay counts down
        rts
.soff:  dc.b    $B04A-$B04A,$B0AE-$B04A,$B0DB-$B04A
        even

;=============================================================================
; The marble held by a vacuum, carried by a bird or waiting to respawn, and
; frozen: extra 8 x 8 sprites drawn with the player's slot, from the PLAY
; blob's PH_MX* sections; their tile pictures pre-shifted at the race load
; into the MX store (G_MXSPR: a directory by tile, chains by flips >> 6).
;=============================================================================

; mx_load - at the race load (a5 = the PLAY blob): the tile pictures pre-shifted
; into the store PH_MXAT (bit 31: in the bitmap's tail, else the race area)
mx_load:
        clr.l   G_MXSPR(a6)
        move.l  PH_MXFRM(a5),d0
        beq.s   .o
        movem.l d0-d7/a0-a5,-(sp)
        lea     0(a5,d0.l),a0
        move.l  PH_MXAT(a5),d0
        bclr    #31,d0
        beq.s   .ra
        add.l   G_LIN(a6),d0
        bra.s   .b
.ra:    add.l   G_RBUF(a6),d0
.b:     movea.l d0,a2
        move.l  d0,G_MXSPR(a6)
        bsr     rspr_build_a2
        movem.l (sp)+,d0-d7/a0-a5
.o:     rts

;-----------------------------------------------------------------------------
; mx_before - before the marble's own frame (these lie under it): held by a
; vacuum ($2A: the list by M_T400, M_VXS and the vacuum's side), the
; fragments (once the drawer has run: M_FRON set, any state, until the
; respawn), frozen (rolling, M_F5CB <> 0: the sparkle by M_F5CB >> 2).
; Lists: sprites from the anchor (M_SX, made here; M_S low), in priority
; order (drawn last first: the first one wins where they meet).
;-----------------------------------------------------------------------------
mx_before:
        tst.l   G_MXSPR(a6)
        beq     .o
        lea     G_MB(a6),a4
        bsr     marble_sx               ; (M_SX: the lists' anchor x)
        move.w  d0,M_SX(a4)
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_INVAC,d0
        beq.s   .vac
        tst.w   M_FRON(a4)
        bne     mx_frag
        cmpi.w  #ST_ROLL,d0
        bne     .o
        moveq   #0,d0
        move.b  M_F5CB+1(a4),d0
        beq     .o
        lsr.w   #2,d0
        cmpi.w  #31,d0
        bhi     .o
        movea.l G_RBUF(a6),a0
        move.l  PH_MXSPK(a0),d1
        beq     .o
        adda.l  d1,a0
        moveq   #0,d6                   ; (not mirrored)
        bra.s   .key
.vac:   movea.l G_RBUF(a6),a0
        move.l  PH_MXVAC(a0),d1
        beq     .o
        adda.l  d1,a0
        moveq   #0,d6                   ; the vacuum's side: $42 = the $02 lists mirrored
        btst    #6,M_T6CF+1(a4)         ; (x = M_SX - dx - 8, the other flip)
        beq.s   .v0
        moveq   #1,d6
.v0:    move.w  M_T400(a4),d0
        cmpi.w  #5,d0
        bhi     .o
        lsl.w   #4,d0
        moveq   #15,d1
        and.w   M_VXS(a4),d1
        add.w   d1,d0
.key:   add.w   d0,d0
        move.w  0(a0,d0.w),d1
        beq.s   .o
        adda.w  d1,a0
        moveq   #0,d7                   ; byte n, n x (tile, flips, dx, dy)
        move.b  (a0)+,d7
        beq.s   .o
        move.w  d7,d0
        lsl.w   #2,d0
        lea     0(a0,d0.w),a3           ; past the last
        subq.w  #1,d7
.l:     subq.l  #4,a3
        move.b  2(a3),d2                ; x = M_SX + dx, y = M_S + dy (8 bits)
        add.b   M_SX+1(a4),d2
        tst.w   d6
        beq.s   .nm
        move.b  M_SX+1(a4),d2           ; (mirrored: M_SX - 8 - dx)
        subq.b  #8,d2
        sub.b   2(a3),d2
.nm:    move.b  3(a3),d3
        add.b   M_S+1(a4),d3
        cmpi.b  #$EF,d3
        bhs.s   .n
        moveq   #0,d0
        move.b  (a3),d0
        moveq   #0,d1
        move.b  1(a3),d1
        eor.w   d6,d1                   ; (mirrored: the other horizontal flip)
        andi.w  #$FF,d2
        andi.w  #$FF,d3
        movem.l d6-d7/a3-a4,-(sp)
        bsr     mx_tile
        FARCALL tk_poll                 ; (takeover: a poll after each sprite; out of bsr
                                        ;  reach)
        movem.l (sp)+,d6-d7/a3-a4
.n:     dbra    d7,.l
.o:     rts

; mx_frag - the 8 fragments (player 1): y = 7; repeat: i = (y +
; frame) & 7, fragment i (pattern i; not if its y >= $D7), y = i - 1;
; until y < 0 (a multiplex: how many depends on the frame). Their positions:
; frag_pos, from the drawer's last inputs.
mx_frag:
        bsr     frag_pos
        lea     G_FRL(a6),a3            ; the fragments drawn, in priority order
        moveq   #0,d5
        moveq   #7,d6
.f:     move.b  M_FC+1(a4),d0
        add.b   d6,d0
        andi.w  #7,d0
        lea     G_FRX(a6),a0
        cmpi.b  #$D7,8(a0,d0.w)
        bhs.s   .s
        move.b  d0,(a3)+
        addq.w  #1,d5
.s:     move.w  d0,d6
        subq.w  #1,d6
        bpl.s   .f
        subq.w  #1,d5
        bmi.s   .o
        movea.l G_RBUF(a6),a0           ; the pattern: PH_MXTAB + 64
        move.l  PH_MXTAB(a0),d0
        lea     64(a0,d0.l),a2
.d:     moveq   #0,d4                   ; last first
        move.b  -(a3),d4
        lea     G_FRX(a6),a0
        moveq   #0,d2
        move.b  0(a0,d4.w),d2           ; x
        moveq   #0,d3
        move.b  8(a0,d4.w),d3           ; y
        add.w   d4,d4
        moveq   #0,d0
        move.b  0(a2,d4.w),d0           ; tile
        moveq   #0,d1
        move.b  1(a2,d4.w),d1           ; flips >> 6
        movem.l d5/a2-a3,-(sp)
        bsr     mx_tile
        FARCALL tk_poll                 ; (takeover: a poll after each sprite; out of bsr
        movem.l (sp)+,d5/a2-a3          ;  reach; a0 is reloaded)
        dbra    d5,.d
.o:     rts

; mx_tile - the tile picture d0 (flips >> 6 d1) at sprite x d2, y d3: on the
; QL x = x (the marble's own: sprite x = M_SX - 8 = X - Y + 120), top = y + 1
; + scroll - VIEW_SCROLL - view (screen line y + 1)
mx_tile:
        movea.l G_MXSPR(a6),a5
        add.w   d0,d0
        moveq   #0,d4
        move.w  0(a5,d0.w),d4
        beq.s   .x
.c:     lea     0(a5,d4.l),a0
        cmp.w   (a0),d1
        beq.s   .g
        moveq   #0,d4
        move.w  2(a0),d4
        bne.s   .c
.x:     rts
.g:     lea     4(a0),a5
        move.w  d2,d0
        add.w   4(a5),d0
        move.w  d3,d1
        addq.w  #1,d1
        add.w   G_MB+M_SCROLL(a6),d1
        subi.w  #VIEW_SCROLL,d1
        sub.w   G_VIEW(a6),d1
        add.w   6(a5),d1
        bra     spr_put

;-----------------------------------------------------------------------------
; frag_pos - for the marble (slot 0): from the drawer's last inputs
; (M_FRAX / M_FRAY: its anchor M_SX / M_S; M_FRT: the angle, the counter after
; its - 3; M_FRM: the scale m, M_FRR: the rise r) the 8 fragments' x and y into
; G_FRX / G_FRX+8 ($F8: none). Fragment k at angle + k x $20: y from the sine
; of the angle's quadrant (64 B, PH_MXTAB), / 4, x m via .mul, from M_FRAY +
; $10 less r / 2; x likewise / 2 from M_FRAX - 4; the 8-bit carries kept
; (8-bit screen wrap). .mul is (v x (m + 1)) >> 8 while its sums stay under
; 256 (m <= $80), else its own loop. a4 = the marble block. Uses d0-d7 / a0-a2.
;-----------------------------------------------------------------------------
frag_pos:
        movea.l G_RBUF(a6),a2
        move.l  PH_MXTAB(a2),d0
        adda.l  d0,a2                   ; a2 = the sine table
        lea     G_FRX(a6),a1
        moveq   #0,d5
        move.b  M_FRAX+1(a4),d5
        subq.b  #4,d5                   ; d5 = x0
        moveq   #0,d6
        move.b  M_FRAY+1(a4),d6
        addi.b  #$10,d6                 ; d6 = y0
        moveq   #0,d4
        move.b  M_FRR+1(a4),d4
        lsr.b   #1,d4                   ; d4 = r / 2
        moveq   #0,d3
        move.b  M_FRM+1(a4),d3          ; d3 = m
        moveq   #0,d2
        move.b  M_FRT+1(a4),d2          ; the angle
        moveq   #7,d7
.f:     ; y: quadrants 0 / 3: y0 - 2 m(s/4) - r/2; 1 / 2: y0 + 2 m(s/4) - r/2
        move.w  d2,d0
        cmpi.b  #$40,d0
        blo.s   .y03a
        cmpi.b  #$80,d0
        blo.s   .y1
        cmpi.b  #$C0,d0
        blo.s   .y2
        andi.w  #$3F,d0                 ; $C0-$FF: s[a & $3F]
        bra.s   .y03
.y03a:  eori.w  #$3F,d0                 ; $00-$3F: s[a ^ $3F]
.y03:   move.b  0(a2,d0.w),d0
        lsr.b   #2,d0
        bsr     .mul
        add.b   d0,d0
        move.b  d6,d1
        sub.b   d0,d1                   ; y0 - that: a borrow, none
        bcs     .off
        sub.b   d4,d1
        bcs     .off
        bra.s   .ys
.y1:    andi.w  #$3F,d0                 ; $40-$7F: s[a & $3F]
        bra.s   .y12
.y2:    eori.w  #$3F,d0                 ; $80-$BF: s[(a ^ $3F) - $80]
        subi.w  #$80,d0
.y12:   move.b  0(a2,d0.w),d0
        lsr.b   #2,d0
        bsr     .mul
        add.b   d0,d0
        add.b   d6,d0                   ; + y0: past 255 (carry set) then - r/2
        bcs.s   .ov                     ; with no borrow is none
        sub.b   d4,d0
        bcs     .off
        move.b  d0,d1
        bra.s   .ys
.ov:    sub.b   d4,d0
        bcc     .off
        move.b  d0,d1
.ys:    move.b  d1,8(a1)                ; y
        ; x: quadrants 0 / 1: x0 + 2 m(s/2) (past 255: none); 2 / 3: x0 - 2 m(s/2)
        move.w  d2,d0
        cmpi.b  #$40,d0
        blo.s   .x01
        cmpi.b  #$80,d0
        blo.s   .x1
        cmpi.b  #$C0,d0
        blo.s   .x2
        eori.w  #$7F,d0                 ; $C0-$FF: s[(a ^ $7F) - $80]
.x2:    subi.w  #$80,d0                 ; $80-$BF: s[a - $80]
        move.b  0(a2,d0.w),d0
        lsr.b   #1,d0
        bsr.s   .mul
        add.b   d0,d0
        move.b  d5,d1
        sub.b   d0,d1
        bcs.s   .off
        move.b  d1,(a1)+
        bra.s   .nx
.x1:    eori.w  #$7F,d0                 ; $40-$7F: s[a ^ $7F]
.x01:   move.b  0(a2,d0.w),d0
        lsr.b   #1,d0
        bsr.s   .mul
        add.b   d0,d0
        add.b   d5,d0
        bcs.s   .off
        move.b  d0,(a1)+
        bra.s   .nx
.off:   move.b  #$F8,8(a1)
        move.b  #$F8,(a1)+
.nx:    addi.b  #$20,d2
        dbra    d7,.f
        rts
; .mul - d0.b = the scaled value (v d0.b, m d3): A = 0; 8 x: v >> 1, a bit out:
; A = A + m + 1 (8 bits: the carry out lost); A >> 1. While A + m + 1 stays under 256
; (m < $80) that is (v x (m + 1)) >> 8. Uses d1.
.mul:   cmpi.w  #$7F,d3
        bhi.s   .ml
        andi.w  #$FF,d0
        move.w  d3,d1
        addq.w  #1,d1
        mulu.w  d1,d0
        lsr.w   #8,d0
        rts
.ml:    move.l  d2,-(sp)
        move.b  d0,d2
        moveq   #0,d1
        moveq   #8-1,d0
.mb:    lsr.b   #1,d2
        bcc.s   .mn
        add.b   d3,d1
        addq.b  #1,d1
.mn:    lsr.b   #1,d1
        dbra    d0,.mb
        moveq   #0,d0
        move.b  d1,d0
        move.l  (sp)+,d2
        rts

;=============================================================================
; Aerial's piston field drawn: each piston object ($27, a column 0-2 by
; M_O6CF) draws 36 entries (tile from the grid, x and y from fixed tables,
; palette 1) from a grid built from the cells G_WP6D7. The objects stay put,
; so the QL draws the entries into the bitmap:
; each one's background is kept at the load, and an entry whose tile changes
; gets its background back and its tile over it. A column's entries 0 and 1 of
; each row overlap: those 12 are its strip, redrawn whole (lower entries win).
; What shows after frame n is the grid of the cells as
; they were after frame n - 1 (the objects draw before the field's logic): the
; cells step only on odd frames, so after an odd frame the cells from before
; its step (G_PSNAP, kept by pistons).
;=============================================================================

; piston_load - at the race load (a5 = the PLAY blob): the strips' and entries'
; backgrounds into the store (PH_PPAT)
piston_load:
        clr.l   G_PPST(a6)
        move.l  PH_PIST(a5),d0
        beq     .o
        movem.l d0-d7/a0-a5,-(sp)
        lea     0(a5,d0.l),a3
        move.l  a3,G_PPDAT(a6)
        move.l  PH_PPAT(a5),d0
        bclr    #31,d0
        beq.s   .ra
        add.l   G_LIN(a6),d0
        bra.s   .b
.ra:    add.l   G_RBUF(a6),d0
.b:     move.l  d0,G_PPST(a6)
        movea.l d0,a2
        lea     PP_STRIP(a3),a0         ; the strips: 3 or 4 words x PP_STRIPL lines
        moveq   #0,d7                   ; (8 B a line kept)
.s:     movea.l G_LIN(a6),a1
        adda.l  (a0)+,a1
        moveq   #0,d5
        lea     PP_PAR(a3),a5
        move.b  0(a5,d7.w),d5
        lsr.w   #1,d5
        subq.w  #1,d5                   ; words - 1
        move.w  #PP_STRIPL-1,d6
.sl:    move.w  d5,d4
        movea.l a1,a4
        movea.l a2,a5
.sw:    move.w  (a4)+,(a5)+
        dbra    d4,.sw
        addq.l  #8,a2
        lea     BPL(a1),a1
        dbra    d6,.sl
        addq.w  #1,d7
        cmpi.w  #3,d7
        blo.s   .s
        lea     PP_ENT(a3),a0           ; the entries: 2 words x 8 lines
        moveq   #108-1,d7
.e:     movea.l G_LIN(a6),a1
        adda.l  (a0)+,a1
        moveq   #8-1,d6
.el:    move.l  (a1),(a2)+
        lea     BPL(a1),a1
        dbra    d6,.el
        dbra    d7,.e
        lea     G_PSHOWN(a6),a0         ; nothing drawn; the cells not known
        moveq   #108/4-1,d0
.c:     move.l  #$FFFFFFFF,(a0)+
        dbra    d0,.c
        move.w  #-1,G_PLMASK(a6)
        movem.l (sp)+,d0-d7/a0-a5
.o:     rts

;-----------------------------------------------------------------------------
; piston_draw - the field's entries into the bitmap when the cells shown (after
; an odd frame G_PSNAP, else G_WP6D7) or the columns present changed: the grid
; (G_PGRID), the tiles (PPT_B122), per column the entries whose tile changed (an
; absent column's: none); a strip's change redraws the strip. Polls the frame
; flag after each entry and strip.
;-----------------------------------------------------------------------------
piston_draw:
        tst.l   G_PPST(a6)
        beq     .x
        lea     G_MB(a6),a3
        lea     G_WP6D7(a6),a0
        btst    #0,M_FC+1(a3)
        beq.s   .cu
        lea     G_PSNAP(a6),a0
.cu:    moveq   #0,d4                   ; the columns present: bits
        lea     G_OBJ(a6),a2
        moveq   #6-1,d7
.ob:    cmpi.w  #ST_PISTON,M_STATE(a2)
        bne.s   .on
        move.w  M_O6CF(a2),d0
        bset    d0,d4
.on:    lea     M_SIZE(a2),a2
        dbra    d7,.ob
        move.w  G_PLMASK(a6),d5         ; (the columns present at the last draw)
        move.w  d4,G_PLMASK(a6)
        moveq   #0,d6                   ; column (its cells: 12 x column on, PPT_AC4D)
.col:   lea     G_PLAST(a6),a1
        moveq   #12,d0
        mulu.w  d6,d0
        adda.w  d0,a1
        movea.l a0,a2
        adda.w  d0,a2
        move.w  d5,d1                   ; present: the same as then?
        eor.w   d4,d1
        btst    d6,d1
        bne.s   .chg
        move.l  (a2)+,d0                ; its 12 cells the same as then?
        cmp.l   (a1)+,d0
        bne.s   .chg0
        move.l  (a2)+,d0
        cmp.l   (a1)+,d0
        bne.s   .chg1
        move.l  (a2)+,d0
        cmp.l   (a1)+,d0
        bne.s   .chg2
        bra     .next
.chg2:  subq.l  #4,a1
        subq.l  #4,a2
.chg1:  subq.l  #4,a1
        subq.l  #4,a2
.chg0:  subq.l  #4,a1
        subq.l  #4,a2
.chg:   move.l  (a2)+,(a1)+             ; kept
        move.l  (a2)+,(a1)+
        move.l  (a2)+,(a1)+
        movem.l d4-d6/a0,-(sp)
        bsr     pp_column
        movem.l (sp)+,d4-d6/a0
.next:  addq.w  #1,d6
        cmpi.w  #3,d6
        blo     .col
.x:     rts

; pp_column - column d6: its 36 grid entries ($60, then its 12 cells),
; their tiles (PPT_B122; the column absent: none); each changed entry redrawn
; (column 0's entries 0 and 1 of each row overlap: its strip, redrawn whole)
pp_column:
        lea     G_PGRID+12(a6),a1       ; (12 below the grid: room for the -6 / -12 writes)
        moveq   #36,d0
        mulu.w  d6,d0
        adda.w  d0,a1
        move.l  #$60606060,d0
        moveq   #9-1,d7
.gf:    move.l  d0,(a1)+
        dbra    d7,.gf
        lea     G_PGRID+12(a6),a1
        movea.l G_PPDAT(a6),a2
        lea     PP_TAB(a2),a2
        lea     G_PLAST(a6),a4          ; the cells
        moveq   #0,d2
        move.b  PPT_AC4D(a2,d6.w),d2    ; first cell
        moveq   #0,d3
        move.b  PPT_AE95(a2,d6.w),d3    ; base
        moveq   #12-1,d7
.gc:    moveq   #0,d0
        move.b  0(a4,d2.w),d0
        beq.s   .gn
        moveq   #0,d1
        move.b  PPT_AFF3(a2,d2.w),d1
        add.b   d3,d1                   ; yy
        move.b  PPT_B034(a2,d0.w),0(a1,d1.w)
        moveq   #0,d5
        move.b  PPT_B025(a2,d0.w),d5
        bmi.s   .g2
        or.b    -6(a1,d1.w),d5
        move.b  PPT_AEB3(a2,d5.w),-6(a1,d1.w)
.g2:    moveq   #0,d5
        move.b  PPT_B016(a2,d0.w),d5
        bmi.s   .gn
        or.b    -12(a1,d1.w),d5
        move.b  PPT_AEB3(a2,d5.w),-12(a1,d1.w)
.gn:    addq.w  #1,d2
        dbra    d7,.gc
        movea.l G_PPDAT(a6),a2
        moveq   #36,d0
        mulu.w  d6,d0
        adda.w  d0,a1                   ; its grid entries
        lea     G_PSHOWN(a6),a3
        adda.w  d0,a3                   ; its shown tiles
        moveq   #0,d2                   ; its parity: the second set of 12 tiles
        lea     PP_PAR(a2),a0
        btst    #0,0(a0,d6.w)
        beq.s   .p0
        move.w  #12*64,d2
.p0:    lea     PP_TAB+PPT_B122(a2),a4  ; (the tiles by the grid's values)
        moveq   #0,d5                   ; the strip changed
        moveq   #0,d4                   ; i mod 6
        moveq   #0,d7                   ; i
.ent:   moveq   #-1,d1                  ; (absent: none)
        btst    d6,G_PLMASK+1(a6)
        beq.s   .t
        moveq   #0,d0
        move.b  0(a1,d7.w),d0
        move.b  0(a4,d0.w),d1
.t:     cmp.b   0(a3,d7.w),d1
        beq.s   .en
        move.b  d1,0(a3,d7.w)
        tst.w   d6                      ; column 0's entries 0 and 1 of a row: its strip
        bne.s   .single
        cmpi.w  #2,d4
        bhs.s   .single
        moveq   #1,d5
        bra.s   .en
.single:
        movem.l d2/d4-d7/a1-a4,-(sp)
        moveq   #36,d0
        mulu.w  d6,d0
        add.w   d7,d0                   ; k
        bsr     pp_entry
        movem.l (sp)+,d2/d4-d7/a1-a4
.en:    addq.w  #1,d4
        cmpi.w  #6,d4
        blo.s   .e6
        moveq   #0,d4
.e6:    addq.w  #1,d7
        cmpi.w  #36,d7
        blo.s   .ent
        tst.w   d5
        beq.s   .cn
        bsr     pp_strip
.cn:    rts

; pp_entry - entry k (d0, not a strip's) back to its background, then its tile
; (d2 = its column's tiles: 0 or 12 x 64, by the parity)
pp_entry:
        movea.l G_PPDAT(a6),a2
        move.w  d0,d1
        lsl.w   #2,d1
        movea.l G_LIN(a6),a1
        adda.l  PP_ENT(a2,d1.w),a1
        movea.l G_PPST(a6),a0
        lea     3*8*PP_STRIPL(a0),a0
        move.w  d0,d1
        lsl.w   #5,d1
        adda.w  d1,a0
        movea.l a1,a4
        moveq   #8-1,d1
.r:     move.l  (a0)+,(a4)
        lea     BPL(a4),a4
        dbra    d1,.r
        bsr.s   pp_tile
        tst.b   G_TKON+1(a6)
        beq.s   .o
        FARCALL tk_poll                 ; (out of bsr reach from here)
.o:     rts

; pp_tile - entry d0's tile (G_PSHOWN; $FF none) over the bitmap at a1 (a2 = the
; data, d2 = its column's tiles: 0 or 12 x 64)
pp_tile:
        lea     G_PSHOWN(a6),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        cmpi.b  #$FF,d1
        beq.s   .o
        subi.w  #$20,d1
        lsl.w   #6,d1
        add.w   d2,d1
        lea     PP_PIC(a2),a0
        adda.w  d1,a0
        moveq   #8-1,d1
.l:     move.l  (a1),d0
        and.l   (a0)+,d0
        or.l    (a0)+,d0
        move.l  d0,(a1)
        lea     BPL(a1),a1
        dbra    d1,.l
.o:     rts

; pp_strip - column d6's strip: its background back, then its entries' tiles from
; the highest i to the lowest (the lowest wins)
pp_strip:
        movea.l G_PPDAT(a6),a2
        moveq   #0,d2
        lea     PP_PAR(a2),a0
        moveq   #0,d5                   ; (its words - 1)
        move.b  0(a0,d6.w),d5
        btst    #0,d5
        beq.s   .p0
        move.w  #12*64,d2
.p0:    lsr.w   #1,d5
        subq.w  #1,d5
        move.w  d6,d1
        lsl.w   #2,d1
        movea.l G_LIN(a6),a1
        lea     PP_STRIP(a2),a0
        adda.l  0(a0,d1.w),a1
        movea.l G_PPST(a6),a0
        move.w  d6,d1
        mulu.w  #8*PP_STRIPL,d1
        adda.w  d1,a0
        move.w  #PP_STRIPL-1,d1
.r:     move.w  d5,d4
        movea.l a1,a4
        movea.l a0,a5
.rw:    move.w  (a5)+,(a4)+
        dbra    d4,.rw
        addq.l  #8,a0
        lea     BPL(a1),a1
        dbra    d1,.r
        lea     .ord(pc),a3
        moveq   #12-1,d7
.e:     moveq   #36,d0
        mulu.w  d6,d0
        add.b   (a3)+,d0                ; k
        move.w  d0,d1
        lsl.w   #2,d1
        movea.l G_LIN(a6),a1
        adda.l  PP_ENT(a2,d1.w),a1
        movem.l d6-d7/a3,-(sp)
        bsr     pp_tile
        movem.l (sp)+,d6-d7/a3
        dbra    d7,.e
        tst.b   G_TKON+1(a6)
        beq.s   .o
.tkp:   lea     .tkp(pc),a0             ; (tk_poll: a PC-relative far call, out of bsr
        adda.l  #tk_poll-.tkp,a0        ;  reach from here)
        jsr     (a0)
.o:     rts
.ord:   dc.b    31,30,25,24,19,18,13,12,7,6,1,0

;=============================================================================
; waves - Intermediate's race routine, from machinery: Z -= the lift M_FB
; left from the last frame (d6: Z before, d7: that lift), M_FB = 0; then, the
; waves on (M_F9B bit 7 clear): M_F9B + 1 every 4th frame (mod 46), the first
; wave at step M_F9B, the second (M_FBB) at M_F9B + 22; on odd frames with no
; second wave yet and M_F9B = 22, it starts (M_FBB = 22, M_F9B = 0).
; wave_at: one wave over player 1 (in the channel, state 1: X $0228-$02D7,
; Y $0258-$0277): M_FB + 1, Z as before; within 32 px past the wave's front:
; the exits, the crest (carried: X + / - 1), else the lift; vx / vy pushed.
; a4 = the marble block.
;=============================================================================
waves:
        moveq   #-1,d6                  ; d6 = Z before (-1: Z as it is now, read when
        moveq   #0,d7                   ; needed); d7 = the lift left
        move.b  M_FB+1(a4),d7
        beq.s   .nl                     ; (none: Z unchanged)
        move.l  M_Z(a4),d0
        lsr.l   #8,d0
        moveq   #0,d6
        move.w  d0,d6
        sub.w   d7,d0
        bsr     wave_setz
        clr.w   M_FB(a4)
.nl:    tst.b   M_F9B+1(a4)
        bmi     .x
        moveq   #3,d0
        and.b   M_FC+1(a4),d0
        bne.s   .w1
        addq.b  #1,M_F9B+1(a4)
        cmpi.b  #WV_STEPS,M_F9B+1(a4)
        blo.s   .w1
        clr.b   M_F9B+1(a4)
.w1:    cmpi.w  #ST_ROLL,M_STATE(a4)    ; player 1 rolling in the channel (X $0228-
        bne.s   .w2                     ; $02D7, Y $0258-$0277)? else no wave touches it
        cmpi.b  #2,M_Y+1(a4)
        bne.s   .w2
        move.b  M_Y+2(a4),d1
        cmpi.b  #$58,d1
        blo.s   .w2
        cmpi.b  #$78,d1
        bhs.s   .w2
        cmpi.b  #2,M_X+1(a4)
        bne.s   .w2
        move.b  M_X+2(a4),d1
        cmpi.b  #$28,d1
        blo.s   .w2
        cmpi.b  #$D8,d1
        bhs.s   .w2
        moveq   #0,d0
        move.b  M_F9B+1(a4),d0
        bsr     wave_at
        tst.b   M_FBB+1(a4)
        beq.s   .w2
        moveq   #0,d0
        move.b  M_F9B+1(a4),d0
        addi.w  #22,d0
        cmpi.w  #WV_STEPS,d0
        blo.s   .w3
        subi.w  #WV_STEPS,d0
.w3:    bsr     wave_at
.w2:    btst    #0,M_FC+1(a4)
        beq.s   .wp
        tst.b   M_FBB+1(a4)
        bne.s   .wp
        cmpi.b  #22,M_F9B+1(a4)
        bne.s   .wp
        move.w  #22,M_FBB(a4)           ; the second wave
        clr.b   M_F9B+1(a4)
.wp:    bra.s   wave_patch              ; (the patch this frame)
.x:     rts
WV_STEPS        equ     46

;-----------------------------------------------------------------------------
; wave_patch - (waves, the waves on) the drawing of the water into the
; picture each water cell has (G_WVTG): the patch queued this frame, step
; (M_F9B + (0 or 22)) mod 46: + 22 on odd frames once the second wave runs
; (M_FBB), the merge with the course already applied (in the data), written
; only on the rows inside the builder's window [W, W + 28), W = (scroll -
; $100) / 8; when W changes, the water rows that come into the window are the
; map's again (wave_stream). A cell written goes on the list for wave_draw (once:
; its flag). A patch is skipped when it changes nothing (the one written last
; again, or the one before when the last agrees with it: G_WVCM); when step -
; 1's patch is still whole, only the entries that differ from it (first in the
; list). A clipped patch, or a new W, ends that: the next one whole. Player 1.
;-----------------------------------------------------------------------------
wave_patch:
        tst.l   G_WVST(a6)
        beq     .x
        lea     G_MB(a6),a0
        cmpa.l  a0,a4
        bne     .x
        movem.l d2-d7/a2-a3/a5,-(sp)
        move.w  M_SCROLL(a4),d4         ; d4 = W, the window's top row
        subi.w  #$100,d4
        lsr.w   #3,d4
        move.w  G_WVW(a6),d5
        cmp.w   d5,d4
        beq.s   .ws
        move.w  d4,G_WVW(a6)
        move.w  #-1,G_WVL1(a6)          ; (no patch whole any more)
        move.w  #-1,G_WVL2(a6)
        bsr     wave_stream
.ws:    moveq   #0,d0
        move.b  M_F9B+1(a4),d0
        btst    #0,M_FC+1(a4)
        beq.s   .p
        tst.b   M_FBB+1(a4)
        beq.s   .p
        addi.w  #22,d0
        cmpi.w  #WV_STEPS,d0
        blo.s   .p
        subi.w  #WV_STEPS,d0
.p:     move.w  G_WVL1(a6),d1
        cmp.w   d1,d0
        beq     .o                      ; (the last again)
        cmp.w   G_WVL2(a6),d0
        bne.s   .w                      ; (the one before it: unless the last disagrees)
        movea.l G_WVCM(a6),a0
        move.w  d0,d2
        mulu.w  #WV_CMPB,d2
        adda.w  d2,a0
        move.w  d1,d2
        lsr.w   #3,d2
        btst    d1,0(a0,d2.w)           ; (bit d1 & 7)
        bne     .o
.w:     move.w  G_WVL2(a6),d2           ; (the one before the last)
        move.w  d1,G_WVL2(a6)
        move.w  d0,G_WVL1(a6)
        move.w  d0,d3                   ; d3 = step - 1
        subq.w  #1,d3
        bpl.s   .q
        moveq   #WV_STEPS-1,d3
.q:     cmp.w   d1,d3
        beq.s   .dl                     ; (written last)
        cmp.w   d2,d3
        bne.s   .fu
        movea.l G_WVCM(a6),a0           ; (before the last: if the last agrees with it)
        move.w  d3,d2
        mulu.w  #WV_CMPB,d2
        adda.w  d2,a0
        move.w  d1,d2
        lsr.w   #3,d2
        btst    d1,0(a0,d2.w)
        beq.s   .fu
.dl:    moveq   #1,d3                   ; (the count of those that differ)
        bra.s   .go
.fu:    moveq   #0,d3                   ; (all of them)
.go:    movea.l G_WVLI(a6),a0
        add.w   d0,d0
        adda.w  0(a0,d0.w),a0
        movea.l G_WVTG(a6),a1
        movea.l G_WVFL(a6),a2
        movea.l G_WVDP(a6),a3
        moveq   #0,d6                   ; its rows [r0, r1) inside the window?
        move.b  2(a0),d6
        cmp.w   d4,d6
        blo.s   .clip
        move.b  3(a0),d6
        move.w  d4,d1
        addi.w  #WV_WINDOW,d1
        cmp.w   d1,d6
        bhi.s   .clip
        moveq   #0,d0
        moveq   #0,d7
        move.b  0(a0,d3.w),d7
        addq.l  #4,a0
        bra.s   .n
.l:     move.b  (a0)+,d0                ; cell
        move.b  (a0)+,0(a1,d0.w)        ; its picture (mostly a change: no test)
        tst.b   0(a2,d0.w)              ; (on the list already)
        bne.s   .n
        st      0(a2,d0.w)
        move.b  d0,(a3)+
.n:     dbra    d7,.l
        bra.s   .e
        ; part of it outside the window: every entry, its row tested; not whole after
.clip:  movea.l G_WVRW(a6),a5
        moveq   #0,d0
        moveq   #0,d7
        move.b  (a0),d7
        addq.l  #4,a0
        move.w  #-1,G_WVL1(a6)
        move.w  #-1,G_WVL2(a6)
        bra.s   .cn
.cl:    move.b  (a0)+,d0                ; cell
        move.b  (a0)+,d1                ; picture
        move.b  0(a5,d0.w),d6           ; its row - W in [0, 28)?
        sub.b   d4,d6
        cmpi.b  #WV_WINDOW,d6
        bhs.s   .cn
        move.b  d1,0(a1,d0.w)
        tst.b   0(a2,d0.w)
        bne.s   .cn
        st      0(a2,d0.w)
        move.b  d0,(a3)+
.cn:    dbra    d7,.cl
.e:     move.l  a3,G_WVDP(a6)
.o:     movem.l (sp)+,d2-d7/a2-a3/a5
.x:     rts

; wave_stream - (wave_patch) the window's top row changed from d5 to d4: the water
; rows inside the new window and not the old one are the map's again (the rows
; that come into view are fresh); their cells go on the list. Keeps d4.
wave_stream:
        movea.l G_WVRS(a6),a0           ; each row's first cell
        movea.l G_WVTG(a6),a1
        movea.l G_WVFL(a6),a2
        movea.l G_WVDP(a6),a3
        movea.l G_WVBS(a6),a5
        move.w  G_WVR0(a6),d2           ; d2 = the row
        move.w  G_WVNR(a6),d7
        subq.w  #1,d7
        moveq   #0,d0
        moveq   #0,d1
.r:     move.b  (a0)+,d0                ; [d0, d1): its cells
        move.b  (a0),d1
        move.w  d2,d6                   ; in the new window?
        sub.w   d4,d6
        cmpi.w  #WV_WINDOW,d6
        bhs.s   .nx
        move.w  d2,d6                   ; and not in the old one?
        sub.w   d5,d6
        cmpi.w  #WV_WINDOW,d6
        blo.s   .nx
        bra.s   .cn
.c:     move.b  0(a5,d0.w),0(a1,d0.w)
        tst.b   0(a2,d0.w)
        bne.s   .ci
        st      0(a2,d0.w)
        move.b  d0,(a3)+
.ci:    addq.w  #1,d0
.cn:    cmp.w   d1,d0
        blo.s   .c
.nx:    addq.w  #1,d2
        dbra    d7,.r
        move.l  a3,G_WVDP(a6)
        rts

; wave_setz - Z's middle and high bytes = d0.w (its fraction kept)
wave_setz:
        moveq   #0,d1
        move.w  d0,d1
        lsl.l   #8,d1
        move.b  M_Z+3(a4),d1
        move.l  d1,M_Z(a4)
        rts

; wave_at - the wave at step d0.w (d6 = Z before, d7 = the lift then)
wave_at:
        cmpi.w  #ST_ROLL,M_STATE(a4)    ; (still in the channel: a wave before may have
        bne     .x                      ; moved the marble out)
        cmpi.b  #2,M_Y+1(a4)
        bne     .x
        move.b  M_Y+2(a4),d1
        cmpi.b  #$58,d1
        blo     .x
        cmpi.b  #$78,d1
        bhs     .x
        cmpi.b  #2,M_X+1(a4)
        bne     .x
        move.b  M_X+2(a4),d1
        cmpi.b  #$28,d1
        blo     .x
        cmpi.b  #$D8,d1
        bhs     .x
        tst.l   d6                      ; (d6 < 0: Z as it is, no lift this frame)
        bpl.s   .zk
        move.l  M_Z(a4),d1
        lsr.l   #8,d1
        moveq   #0,d6
        move.w  d1,d6
.zk:    moveq   #3,d2
        and.b   M_FC+1(a4),d2           ; frame & 3
        cmpi.w  #3,d0
        bhs.s   .f3
        move.w  #$0230,d4               ; rising: the front still, the height by
        lsl.w   #2,d0                   ; step x 4 + frame & 3
        add.w   d2,d0
        lea     obj_a97c(pc),a0
        moveq   #0,d5
        move.b  0(a0,d0.w),d5           ; d5 = the height
        bra.s   .p
.f3:    lsl.w   #2,d0                   ; the front: $0224 + (4 s | frame & 3)
        or.w    d2,d0
        addi.w  #$0224,d0
        move.w  d0,d4
        lea     obj_a97c(pc),a0
        moveq   #0,d5
        move.b  12(a0),d5
.p:     move.l  M_Y(a4),d3
        lsr.l   #8,d3                   ; d3 = Y
        move.l  M_X(a4),d2
        lsr.l   #8,d2                   ; d2 = X
        addq.b  #1,M_FB+1(a4)
        move.w  d6,d0
        bsr     wave_setz               ; (Z as before: the lift not kept inside)
        move.w  d2,d1
        sub.w   d4,d1                   ; d1 = d = X - front
        bcs     .x
        cmpi.w  #$20,d1
        bhs     .x
        lea     obj_a98c(pc),a0
        moveq   #0,d0
        move.b  0(a0,d1.w),d0           ; d0 = t
        cmpi.b  #$77,d3                 ; the exits: Y low $77, X low $56-$69 or
        bne.s   .ne                     ; $B6-$C9, no lift last frame, t >= 2
        cmpi.b  #$56,d2
        blo.s   .ne
        cmpi.b  #$6A,d2
        blo.s   .xa
        cmpi.b  #$B6,d2
        blo.s   .ne
        cmpi.b  #$CA,d2
        bhs.s   .ne
.xa:    tst.w   d7
        bne.s   .ne
        cmpi.b  #2,d0
        bhs.s   .out
.ne:    tst.b   d0
        bpl.s   .lift
        move.l  M_X(a4),d2              ; the crest: carried with it
        cmpi.w  #$11,d1
        blo.s   .back
        addi.l  #$100,d2
        clr.w   M_VXS(a4)
        bra.s   .cx
.back:  subi.l  #$100,d2
        move.w  #1,M_VXS(a4)
.cx:    andi.l  #$FFFFFF,d2
        move.l  d2,M_X(a4)
        moveq   #$17,d0
        sub.b   d5,d0
        bra.s   .set
.lift:  sub.b   d5,d0                   ; the lift t - height: none if it borrows
        bcs.s   .x
.set:   andi.w  #$FF,d0
        move.w  d0,M_FB(a4)
        lsl.b   #2,d0                   ; vx by the lift x 4 (8 bits): toward - for
        andi.w  #$FF,d0                 ; d < $10, else toward +
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        cmpi.w  #$10,d1
        bhs.s   .vp
        move.w  d0,d1
        bsr     accel_neg
        bra.s   .vy
.vp:    move.w  d0,d1
        bsr     accel_pos
        bra.s   .vy
.out:   move.l  M_Y(a4),d0              ; thrown out: Y low $78, vy 0, vy + $20
        andi.l  #$FFFF00FF,d0
        ori.l   #$7800,d0
        move.l  d0,M_Y(a4)
        clr.w   M_VYS(a4)
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        moveq   #$20,d1
        bsr     accel_pos
.vy:    lea     M_VY(a4),a0             ; vy by 3 toward -
        lea     M_VYS(a4),a1
        moveq   #3,d1
        bsr     accel_neg
.x:     rts

;-----------------------------------------------------------------------------
; wave_draw - Intermediate's water: the cells on
; wave_patch's list whose picture is not the one the bitmap shows are copied, if
; their lines meet the view (else they stay on the list, for when they come into
; it); a frame-flag poll after every 8 copies. So the bitmap in the view is
; the map with every wave patch written since the waves started.
;-----------------------------------------------------------------------------
wave_draw:
        tst.l   G_WVST(a6)
        beq     .x
        movea.l G_WVDL(a6),a0           ; a0: the list (read), a1: (kept)
        cmpa.l  G_WVDP(a6),a0
        beq     .x
        move.w  G_VIEW(a6),d0           ; the cells' lines in the view at all?
        cmp.w   G_WVY1(a6),d0
        bhs     .x
        add.w   G_LINES(a6),d0
        cmp.w   G_WVY0(a6),d0
        bls     .x
        movem.l d2-d7/a2-a5,-(sp)
        movea.l G_WVTG(a6),a2           ; a2: the target pictures, a3: the shown ones
        movea.l G_WVCU(a6),a3
        move.l  G_WVOF(a6),d3           ; d3: the cells' addresses - a3
        sub.l   a3,d3
        move.l  G_WVFL(a6),d7           ; d7: the flags - a3
        sub.l   a3,d7
        moveq   #8,d6                   ; (copies to the next poll)
        moveq   #0,d0
        move.w  G_VIEW(a6),d1           ; all the water's lines in the view?
        cmp.w   G_WVY0(a6),d1
        bhi     .part
        add.w   G_LINES(a6),d1
        cmp.w   G_WVY1(a6),d1
        blo     .part
        ; --- all of it in the view: every cell on the list is drawn (or dropped)
        move.l  G_WVST(a6),d4           ; d4: the pictures
        move.l  G_WVDP(a6),d5           ; d5: the list's end
        move.l  a0,G_WVDP(a6)           ; (the list: empty after)
        movea.l G_WVFL(a6),a1           ; a1: the flags
        moveq   #0,d1
.f:     move.b  (a0)+,d0
        clr.b   0(a1,d0.w)              ; off the list
        move.b  0(a2,d0.w),d1
        cmp.b   0(a3,d0.w),d1
        beq.s   .fd                     ; (back to what it shows)
        move.b  d1,0(a3,d0.w)           ; shown = the target
        move.w  d0,d2
        lsl.w   #2,d2
        add.w   d3,d2
        movea.l 0(a3,d2.w),a4           ; the cell's top line
        move.w  d1,d2
        lsl.w   #5,d2
        movea.l d4,a5
        adda.w  d2,a5
        move.l  (a5)+,(a4)
        move.l  (a5)+,BPL(a4)
        move.l  (a5)+,2*BPL(a4)
        move.l  (a5)+,3*BPL(a4)
        move.l  (a5)+,4*BPL(a4)
        move.l  (a5)+,5*BPL(a4)
        move.l  (a5)+,6*BPL(a4)
        move.l  (a5)+,7*BPL(a4)
        subq.w  #1,d6
        bne.s   .fd
        moveq   #8,d6
        tst.b   G_TKON+1(a6)
        beq.s   .fd
.tf:    lea     .tf(pc),a4              ; (tk_poll: a PC-relative far call)
        adda.l  #tk_poll-.tf,a4
        jsr     (a4)
.fd:    cmpa.l  d5,a0
        blo.s   .f
        movem.l (sp)+,d2-d7/a2-a5
        rts
        ; --- part of it: the cells whose lines miss the view stay on the list
.part:  move.w  G_VIEW(a6),d4           ; d4/d5: a cell's top line's address meets the
        ext.l   d4                      ; view if d4 <= it < d5
        subq.l  #7,d4
        lsl.l   #7,d4
        add.l   G_LIN(a6),d4
        moveq   #0,d5
        move.w  G_VIEW(a6),d5
        add.w   G_LINES(a6),d5
        lsl.l   #7,d5
        add.l   G_LIN(a6),d5
        movea.l a0,a1                   ; a1: the cells kept
.l:     move.b  (a0)+,d0
        move.b  0(a2,d0.w),d1
        cmp.b   0(a3,d0.w),d1
        beq.s   .drop                   ; (back to what it shows)
        move.w  d0,d2
        lsl.w   #2,d2
        add.w   d3,d2
        movea.l 0(a3,d2.w),a4           ; the cell's top line
        cmpa.l  d4,a4
        blo.s   .keep
        cmpa.l  d5,a4
        bhs.s   .keep
        move.b  d1,0(a3,d0.w)           ; shown = the target
        moveq   #0,d2
        move.b  d1,d2
        lsl.w   #5,d2
        movea.l G_WVST(a6),a5
        adda.w  d2,a5
        move.l  (a5)+,(a4)
        move.l  (a5)+,BPL(a4)
        move.l  (a5)+,2*BPL(a4)
        move.l  (a5)+,3*BPL(a4)
        move.l  (a5)+,4*BPL(a4)
        move.l  (a5)+,5*BPL(a4)
        move.l  (a5)+,6*BPL(a4)
        move.l  (a5)+,7*BPL(a4)
        subq.w  #1,d6
        bne.s   .drop
        moveq   #8,d6
        tst.b   G_TKON+1(a6)
        beq.s   .drop
.tp:    lea     .tp(pc),a4              ; (tk_poll: a PC-relative far call)
        adda.l  #tk_poll-.tp,a4
        jsr     (a4)
.drop:  move.w  d0,d2                   ; off the list: its flag cleared
        add.w   d7,d2
        clr.b   0(a3,d2.w)
        bra.s   .n
.keep:  move.b  d0,(a1)+
.n:     cmpa.l  G_WVDP(a6),a0
        blo.s   .l
        move.l  a1,G_WVDP(a6)
        movem.l (sp)+,d2-d7/a2-a5
.x:     rts

        include "proto_objtab.inc"
