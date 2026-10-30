; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; music.asm - the Atari ST version's race tunes on a QL AY board
;
; The ST's sound driver re-implemented: per 50 Hz tick the
; effect stream (channel C), the note timers, the software volume envelopes,
; then the 4-voice sequencer with the ST's channel allocation (a new note takes
; the channel with the least note time left; not C while an effect plays).
;
; The tune is in the race's PLAY blob (PH_MUS; built from the ST files), so it
; is in the race area while the race is played.
; Ticks: mus_tick, from the 50 Hz clock in both modes (QDOS: the poll task;
; takeover: tk_ack, the frame flag), while G_MON is set. No division at run time
; (durations come split by the tempo), the chip written only where a register
; changed.
;
; The board layer (detection, register writes, silence) follows the QL Lemmings
; port's AY layer (its audio init, register writer and stop); see mus_detect
; for the probes.
;=============================================================================
        ifne    MUS_ON

;-----------------------------------------------------------------------------
; mus_detect - the AY board: G_AUD, its period class G_MCLS and its writer
; G_MWR. Called once at init, in QDOS mode
; (before a takeover). G_TAUD (loader): 0 auto, 1 no music, 2-4 the dummy board
; with the 0.75 / 2 / 2.5 MHz periods (measuring and the emulator test).
; Probes (auto), all reads, in the Lemmings order:
;  1. QLion / Next: the word at $80001E = "L0" or "N1".."N3". A 68008 has a
;     20-bit bus: there it reads ROM byte $1E (no side effect).
;  2. PiStorm: the long at $1C0C8 = "QLPS" ($1C000-$1FFFF: no RAM on any QL).
;  3. QSound: SV.AYJMP (system variable $164) set by its ROM; refused if the RAM
;     reaches $C2000 (SV_RAMT > $C2000: an 896K QL, where RAM hides the board).
;  4. QIMSI Gold (only without a QSound vector, as Lemmings): the byte at $1C000
;     = 2 (the platform id), on 8 reads in a row.
;-----------------------------------------------------------------------------
SV_RAMT         equ     $20
SV_AYJMP        equ     $164

mus_detect:
        movem.l d0-d3/a0-a1,-(sp)
        clr.w   G_AUD(a6)
        move.w  G_TAUD(a6),d0
        beq.s   .auto
        cmpi.w  #5,d0                   ; 5: the beeper (even with a board)
        beq     .bp
        subq.w  #2,d0                   ; 1: off; 2-4: the dummy board
        bmi     .x
        cmpi.w  #3,d0
        bhs     .x
        move.w  d0,d1                   ; its period class
        moveq   #AB_DUMMY,d0
        bra.s   .set
.auto:  move.w  $80001E,d1              ; 1. QLion / Next QL core
        cmpi.w  #$4C30,d1               ; "L0"
        beq.s   .ay
        cmpi.w  #$4E31,d1               ; "N1".."N3"
        blo.s   .nay
        cmpi.w  #$4E33,d1
        bhi.s   .nay
.ay:    moveq   #AB_AYCARD,d0
        moveq   #MC_250,d1
        bra.s   .set
.nay:   cmpi.l  #$514C5053,$1C0C8       ; 2. PiStorm: "QLPS"
        bne.s   .nps
        moveq   #AB_PISTORM,d0
        moveq   #MC_075,d1
        bra.s   .set
.nps:   movea.l G_SYS(a6),a0            ; 3. QSound
        tst.l   SV_AYJMP(a0)
        beq.s   .nqs
        cmpi.l  #$C2000,SV_RAMT(a0)     ; (RAM over the board: no)
        bhi.s   .bp
        moveq   #AB_QSOUND,d0
        moveq   #MC_075,d1
        bra.s   .set
.nqs:   moveq   #7,d1                   ; 4. QIMSI Gold
.qg:    cmpi.b  #2,$1C000
        bne.s   .bp
        dbra    d1,.qg
        moveq   #AB_QGOLD,d0
        moveq   #MC_200,d1
.set:   move.w  d0,G_AUD(a6)
        move.w  d1,G_MCLS(a6)
        lea     mus_wrtab(pc),a0
        add.w   d0,d0
        move.w  -2(a0,d0.w),d0
        lea     0(a0,d0.w),a1
        move.l  a1,G_MWR(a6)
.x:     movem.l (sp)+,d0-d3/a0-a1
        rts
.bp:    move.w  #AB_BEEP,G_AUD(a6)      ; no AY board: the effects on the beeper
        bra.s   .x

; the boards' register writers: d0.b = register, d2.b = value; use a1, d3 only
mus_wrtab:
        dc.w    wr_qs-mus_wrtab,wr_qg-mus_wrtab,wr_ps-mus_wrtab,wr_ay-mus_wrtab
        dc.w    wr_dm-mus_wrtab

wr_qs:  lea     $C2000,a1               ; QSound: latch + strobe (data, control at +2)
wr_qs2: move.b  d0,(a1)
        move.b  #$0F,2(a1)
        move.b  #$0A,2(a1)
        move.b  d2,(a1)
        move.b  #$0E,2(a1)
        move.b  #$0A,2(a1)
        rts
wr_dm:  lea     G_MDUM(a6),a1           ; the dummy: QSound's protocol into the globals
        bra.s   wr_qs2
wr_qg:  lea     $1C440,a1               ; QIMSI Gold: register n at +4n
        moveq   #0,d3
        move.b  d0,d3
        add.w   d3,d3
        add.w   d3,d3
        move.b  d2,0(a1,d3.w)
        rts
wr_ps:  lea     $1C140,a1               ; PiStorm: select, data
        move.b  d0,(a1)
        move.b  d2,1(a1)
        rts
wr_ay:  lea     $800028,a1              ; QLion / Next: data port, control at +2
        move.b  d0,(a1)                 ; (move.b #0, not clr: clr reads first)
        move.b  #5,2(a1)                ; latch the register (5, 5, 0)
        move.b  #5,2(a1)
        move.b  #0,2(a1)
        move.b  d2,(a1)
        move.b  #4,2(a1)                ; write the value (4, 4, 0)
        move.b  #4,2(a1)
        move.b  #0,2(a1)
        rts

mus_wr: movea.l G_MWR(a6),a2
        jmp     (a2)

;-----------------------------------------------------------------------------
; mus_stop - at the exit: the last BEEP's 2 ticks waited (beep_wait), then
; mus_silence. mus_silence - the tune and its ticks off, the chip silent
; (volumes 0, mixer all off, as the Lemmings layer's mus_stop), whether a tune
; plays or not (after GAME OVER the sequencer is stopped but a note or effect 6's
; noise can still sound): every race change (goto_race: keys 1-6, the next race
; after the goal, Practice after a time out) and the exit. Nothing to write
; without an AY board (none, or the beeper: a BEEP ends by itself, 1.43 s at
; most). mus_halt - the ticks off, the chip left as it is (mus_race, which then
; sets the chip itself). G_MON is cleared FIRST: in QDOS mode the poll task's
; mus_tick then never writes the chip.
;-----------------------------------------------------------------------------
mus_halt:
        clr.w   G_MON(a6)
        rts

mus_stop:
        bsr     beep_wait
mus_silence:
        clr.w   G_MON(a6)
        tst.w   G_AUD(a6)
        beq.s   .o
        cmpi.w  #AB_BEEP,G_AUD(a6)
        beq.s   .o
        movem.l d0/d2-d3/a1-a2,-(sp)
        moveq   #8,d0
        moveq   #0,d2
.s:     bsr.s   mus_wr
        addq.w  #1,d0
        cmpi.w  #11,d0
        bne.s   .s
        moveq   #7,d0
        moveq   #-1,d2
        bsr.s   mus_wr
        movem.l (sp)+,d0/d2-d3/a1-a2
.o:     rts

;-----------------------------------------------------------------------------
; mus_race - the current race's tune from its start (the ST's start routine +
; $35E6), no effect playing: after a race load. Nothing without
; a board or a tune. The chip is set to R0-R5, R8-R10 = 0 and the mixer to
; tones on, noise off, I/O ports in (G_MOUT: what the chip has from now on).
;-----------------------------------------------------------------------------
mus_race:
        bsr.s   mus_halt
        tst.w   G_AUD(a6)
        beq     .o
        cmpi.w  #AB_BEEP,G_AUD(a6)
        beq     .o
        tst.l   G_DAT(a6)
        beq     .o
        movem.l d0-d3/a0-a3,-(sp)
        movea.l G_RBUF(a6),a0
        move.l  PH_MUS(a0),d0
        beq     .x
        adda.l  d0,a0                   ; the tune
        lea     G_MCLR(a6),a1           ; the player's state: 0 (G_MCLR..G_MCLRE)
        move.w  #(G_MCLRE-G_MCLR)/2-1,d1
.c:     clr.w   (a1)+
        dbra    d1,.c
        move.l  #$1F1F1F1F,G_MENVI(a6)  ; (the ST's start routine: $1F)
        move.b  #$F8,G_MREG+7(a6)       ; (the ST's mixer, as its notes set it)
        move.b  #$38,G_MOUT+7(a6)       ; (the chip's, below)
        move.w  #NVOICE,G_MNV(a6)
        move.w  #1,G_MCNT(a6)           ; (tick 0; the first pass at tick 1)
        move.w  #1,G_MCNT0(a6)
        moveq   #0,d1
        move.w  TU_TEMPO(a0),d1
        move.l  d1,G_MTEMPO(a6)
        moveq   #1,d2
        and.w   TU_FLAGS(a0),d2
        move.w  d2,G_MRST(a6)
        move.l  TU_RST(a0),G_MRP(a6)
        move.w  TU_RST+4(a0),G_MRP+4(a6)
        lea     TU_DUR(a0),a1
        move.l  a1,G_MDUR(a6)
        lea     G_MVO(a6),a2
        moveq   #0,d2
        moveq   #3,d3
.v:     move.l  d1,V_TEMPO(a2)          ; (clock and next event 0: due at the first
        move.l  d1,V_CAT(a2)            ;  tick, its clock then = tempo)
        move.w  #1,V_DUE(a2)
        move.w  TU_OFF(a0,d2.w),d0
        lea     0(a0,d0.w),a3
        move.l  a3,V_BASE(a2)
        move.w  TU_LEN(a0,d2.w),V_LEN(a2)
        lea     V_SIZE(a2),a2
        addq.w  #2,d2
        dbra    d3,.v
        moveq   #0,d0                   ; the chip: R0-R5, R8-R10 = 0
        moveq   #0,d2
.z:     bsr     mus_wr
        addq.w  #1,d0
        cmpi.w  #6,d0
        bne.s   .z1
        moveq   #8,d0
.z1:    cmpi.w  #11,d0
        bne.s   .z
        moveq   #7,d0                   ; the mixer: tones on, noise off, ports in
        moveq   #$38,d2
        bsr     mus_wr
        move.w  #1,G_MON(a6)            ; (last: the poll task may tick from now)
.x:     movem.l (sp)+,d0-d3/a0-a3
.o:     rts

;-----------------------------------------------------------------------------
; snd_mute - (\ in play, row_keys) the sound muted / back. An AY board: the tune
; and effects run on, silent: G_MWR becomes mus_wrm (R8-R10, the volumes, go to
; the chip as 0; G_MOUT keeps what the player set), the volumes 0 now; back: the
; board's writer and G_MOUT's volumes to the chip. G_MON is off meanwhile (QDOS:
; no poll-task tick between a register's select and its data). The beeper: no
; BEEPs while muted (mus_frame), the one sounding killed (G_BKILL, beep_mute).
; Preserves all registers.
;-----------------------------------------------------------------------------
snd_mute:
        movem.l d0-d3/a0-a2,-(sp)
        eori.w  #1,G_MUTE(a6)
        move.w  G_AUD(a6),d0
        beq.s   .x
        cmpi.w  #AB_BEEP,d0
        bne.s   .ay
        tst.w   G_MUTE(a6)
        beq.s   .x
        move.w  #1,G_BKILL(a6)
        bra.s   .x
.ay:    move.w  G_MON(a6),-(sp)
        clr.w   G_MON(a6)
        tst.w   G_MUTE(a6)
        beq.s   .un
        move.l  G_MWR(a6),G_MWRR(a6)
        lea     mus_wrm(pc),a0
        move.l  a0,G_MWR(a6)
        movea.l G_MWRR(a6),a2
        moveq   #8,d0
        moveq   #0,d2
.z:     jsr     (a2)
        addq.w  #1,d0
        cmpi.w  #11,d0
        bne.s   .z
        bra.s   .r
.un:    move.l  G_MWRR(a6),G_MWR(a6)
        movea.l G_MWRR(a6),a2
        lea     G_MOUT+8(a6),a0
        moveq   #8,d0
.u:     move.b  (a0)+,d2
        jsr     (a2)
        addq.w  #1,d0
        cmpi.w  #11,d0
        bne.s   .u
.r:     move.w  (sp)+,G_MON(a6)
.x:     movem.l (sp)+,d0-d3/a0-a2
        rts

; mus_wrm - the writer while muted: R8-R10 as 0, the rest as the board's
; (G_MWRR). d0.b = register, d2.b = value (kept); uses a1, d3 as the writers.
mus_wrm:
        cmpi.b  #8,d0
        blo.s   .r
        cmpi.b  #10,d0
        bhi.s   .r
        move.l  d2,-(sp)
        moveq   #0,d2
        bsr.s   .r
        move.l  (sp)+,d2
        rts
.r:     move.l  G_MWRR(a6),-(sp)
        rts

;-----------------------------------------------------------------------------
; mus_sfx - start effect d0.w (1-18) as the ST's $3E04: the one playing is not
; restarted; Practice plays 16 for 15, Aerial drops 15, Silly drops 3 (the id is
; kept, as on the ST); channel C's music envelope off and its note cut; the
; sweep cleared, the wait counter kept. Preserves all registers.
;-----------------------------------------------------------------------------
mus_sfx:
        tst.w   G_MON(a6)
        beq.s   .o
        cmp.w   G_FXCUR(a6),d0
        beq.s   .o
        movem.l d0/a0,-(sp)
        move.w  d0,G_FXCUR(a6)
        cmpi.w  #15,d0
        bne.s   .n15
        cmpi.w  #3,G_RACE(a6)           ; Aerial
        beq.s   .x
        tst.w   G_RACE(a6)              ; Practice
        bne.s   .n15
        moveq   #16,d0
.n15:   cmpi.w  #3,d0
        bne.s   .go
        cmpi.w  #4,G_RACE(a6)           ; Silly
        beq.s   .x
.go:    lea     .go(pc),a0              ; (the tables: past the PC-relative reach)
        adda.l  #mus_fxoff-.go,a0
        add.w   d0,d0
        move.w  -2(a0,d0.w),d0
        lea     .go(pc),a0
        adda.l  #mus_fx-.go,a0
        adda.w  d0,a0
        move.b  #$FF,G_MENVI+2(a6)
        clr.b   G_MTIM+2(a6)
        clr.w   G_FXSW(a6)
        move.l  a0,G_FXPTR(a6)          ; (last: in QDOS mode the poll task's tick
                                        ;  may play it from here on)
.x:     movem.l (sp)+,d0/a0
.o:     rts

; mus_sfxreq - the effects asked for this QL frame (G_MSFX: bit n = effect n,
; set by the logic, see mus_frame), started in turn (bit 1 first; so the highest
; wins, as the last $3E04 call does on the ST)
mus_sfxreq:
        move.l  G_MSFX(a6),d1
        beq.s   .o
        clr.l   G_MSFX(a6)
        moveq   #1,d0
.b:     btst    d0,d1
        beq.s   .n
        bsr.s   mus_sfx
.n:     addq.w  #1,d0
        cmpi.w  #SFX_N+1,d0
        bne.s   .b
.o:     rts

; mus_frame - after the logic of a QL frame (logic_qlframe): the real marble's
; events (M_EVENTS, then cleared) as effect requests, with the objects' (G_MSFX,
; set in src/mobj.asm); GAME OVER stops the sequencer (the ST's $35D8: the
; effects and envelopes go on). Uses d0-d1.
mus_frame:
        ifeq    RELB
        move.w  G_TBEEPN(a6),d0         ; (test loader: effect 3 every N frames; -N:
        beq.s   .tb                     ;  16 and 13 in turn, each over the other
        subq.w  #1,G_TBCNT(a6)          ;  still sounding)
        bgt.s   .tb
        tst.w   d0
        bpl.s   .t3
        neg.w   d0
        move.w  d0,G_TBCNT(a6)
        cmpi.w  #16,G_BCUR(a6)
        beq.s   .t13
        bset    #0,G_MSFX+1(a6)
        bra.s   .tb
.t13:   bset    #5,G_MSFX+2(a6)
        bra.s   .tb
.t3:    move.w  d0,G_TBCNT(a6)
        bset    #3,G_MSFX+3(a6)
        endc
.tb:    tst.w   G_MON(a6)
        bne.s   .go
        cmpi.w  #AB_BEEP,G_AUD(a6)
        bne     .o
        tst.w   G_MUTE(a6)              ; muted: no BEEPs
        bne     beep_mute
        moveq   #0,d0                  ; the beeper: nothing asked for, nothing due:
        move.w  G_MB+M_EVENTS(a6),d0    ; out at once (a frame without an effect costs
        or.w    G_BLEFT(a6),d0          ; as with no sound)
        or.l    G_MSFX(a6),d0           ; (last: Z from all 32 bits)
        bne.s   .go
        rts
.go:    move.w  G_MB+M_EVENTS(a6),d1    ; an AY board, nothing asked for: only the
        bne.s   .ev                     ; GAME OVER test below (as the full path)
        tst.l   G_MSFX(a6)
        bne.s   .ev
        cmpi.w  #AB_BEEP,G_AUD(a6)      ; (the beeper: its chain's later BEEPs)
        beq.s   .ev
        tst.b   G_MB+M_PRESENT+1(a6)
        bne.s   .q
        clr.w   G_MNV(a6)
.q:     rts
.ev:    clr.w   G_MB+M_EVENTS(a6)
        move.l  G_MSFX(a6),d0
        btst    #EV_OFF,d1              ; off the course: 1
        beq.s   .e1
        bset    #1,d0
.e1:    btst    #EV_RESPAWN,d1          ; back at the restart point: 2
        beq.s   .e2
        bset    #2,d0
.e2:    move.w  d1,-(sp)                ; a wall, a side, the drop-in landing: 3
        andi.w  #1<<EV_WALL|1<<EV_SIDE|1<<EV_DROP,d1
        beq.s   .e3
        bset    #3,d0
.e3:    move.w  (sp)+,d1
        btst    #EV_TIMEOUT,d1          ; time out: 6
        beq.s   .e6
        bset    #6,d0
.e6:    btst    #EV_GOAL,d1             ; goal: 10
        beq.s   .e10
        bset    #10,d0
.e10:   btst    #EV_BREAK,d1            ; broken by a long fall: 12
        bne.s   .b12
        btst    #EV_LAND,d1             ; landing dizzy (dizziness >= $50: the
        beq.s   .e12                    ; marble cannot steer): 12
        cmpi.b  #$50,G_MB+M_DIZZY+1(a6)
        blo.s   .e12
.b12:   bset    #12,d0
.e12:   btst    #EV_FUNNEL,d1           ; into a funnel: 14 (18 on Aerial)
        beq.s   .e14
        bset    #14,d0
        cmpi.w  #3,G_RACE(a6)
        bne.s   .e14
        bclr    #14,d0
        bset    #18,d0
.e14:   move.l  d0,G_MSFX(a6)
        cmpi.w  #AB_BEEP,G_AUD(a6)
        beq     beep_frame
        bsr     mus_sfxreq
        tst.b   G_MB+M_PRESENT+1(a6)    ; GAME OVER: no more notes
        bne.s   .f
        clr.w   G_MNV(a6)
.f:     rts
.o:     clr.l   G_MSFX(a6)
        clr.w   G_MB+M_EVENTS(a6)
        rts

;-----------------------------------------------------------------------------
; mus_tick - one 50 Hz tick (the ST's VBL routine $3F2C): the effect stream, the
; note timers and envelopes, the sequencer (mus_step), then the registers that
; changed to the chip (mus_out). a6 = globals. Preserves all registers.
;-----------------------------------------------------------------------------
MVOL    macro
        move.b  G_MREG+8+\1(a6),d2
        cmp.b   G_MOUT+8+\1(a6),d2
        beq.s   .v\@
        move.b  d2,G_MOUT+8+\1(a6)
        moveq   #8+\1,d0
        jsr     (a2)
.v\@:
        endm

mus_tick:
        tst.w   G_MON(a6)
        bne.s   .go
        rts
.go:    movem.l d0-d3/a0-a3,-(sp)
        bra     mus_step                ; (it ends the tick: no call, no return)

;-----------------------------------------------------------------------------
; mus_out - the tick's registers (G_MREG, the ST driver's) as the board's
; (G_MOUT: what the chip has), written where they changed. R0-R7 only when the
; step touched them (G_MDRT: notes, effect writes, the sweep): tone periods
; converted as 12-bit pairs (cached: G_MRAW), R6 likewise, R7 without the
; I/O-port bits (R8-R10: in mus_tick). In: a2 = the writer. Uses d0-d2, a0, a3
; (the writer a1, d3).
;-----------------------------------------------------------------------------

mus_out:
        movem.l d4-d5/a4,-(sp)
        clr.b   G_MDRT(a6)
        lea     G_MREG(a6),a0
        lea     G_MRAW(a6),a3
        lea     G_MOUT(a6),a4
        moveq   #0,d4
.p:     move.b  1(a0),d5                ; a tone pair: hi, lo
        lsl.w   #8,d5
        move.b  (a0),d5
        andi.w  #$0FFF,d5
        cmp.w   (a3),d5
        beq.s   .ps
        move.w  d5,(a3)
        move.w  d5,d0
        bsr     mus_conv
        move.w  d0,d5
        move.w  d5,2(a3)                ; its board value
        cmp.b   (a4),d5
        beq.s   .h
        move.b  d5,(a4)
        move.w  d4,d0
        move.b  d5,d2
        jsr     (a2)
.h:     move.w  d5,d2
        lsr.w   #8,d2
        cmp.b   1(a4),d2
        beq.s   .ps
        move.b  d2,1(a4)
        move.w  d4,d0
        addq.w  #1,d0
        jsr     (a2)
.ps:    addq.w  #2,a0
        addq.w  #4,a3
        addq.w  #2,a4
        addq.w  #2,d4
        cmpi.w  #6,d4
        bne.s   .p
        moveq   #31,d0                  ; R6: the noise period
        and.b   (a0)+,d0
        bsr     mus_convn
        cmp.b   (a4),d0
        beq.s   .r7
        move.b  d0,(a4)
        move.b  d0,d2
        moveq   #6,d0
        jsr     (a2)
.r7:    moveq   #$3F,d2                 ; R7: no port bits
        and.b   (a0),d2
        cmp.b   1(a4),d2
        beq.s   .o
        move.b  d2,1(a4)
        moveq   #7,d0
        jsr     (a2)
.o:     movem.l (sp)+,d4-d5/a4
        rts

; mus_conv - d0.w = an ST period (12 bits): the board's (as mm_qlplayer
; board_convert; the nearest in pitch, --check). mus_convn: d0.w = a noise
; period (5 bits), the same scaling, at most 31. Use d1.
mus_conv:
        move.w  G_MCLS(a6),d1
        cmpi.w  #MC_200,d1
        beq.s   .o
        tst.w   d1
        bne.s   .p25
        move.w  d0,d1                   ; 0.75 MHz: (3p + 4) >> 3
        add.w   d0,d0
        add.w   d1,d0
        addq.w  #4,d0
        lsr.w   #3,d0
.o:     rts
.p25:   move.w  d0,d1                   ; 2.5 MHz: (5p + 2) >> 2, at most 4095
        add.w   d0,d0
        add.w   d0,d0
        add.w   d1,d0
        addq.w  #2,d0
        lsr.w   #2,d0
        cmpi.w  #4095,d0
        bls.s   .o
        move.w  #4095,d0
        rts
mus_convn:
        move.w  G_MCLS(a6),d1
        cmpi.w  #MC_200,d1
        beq.s   .o
        tst.w   d1
        bne.s   .p25
        move.w  d0,d1
        add.w   d0,d0
        add.w   d1,d0
        addq.w  #4,d0
        lsr.w   #3,d0
.o:     rts
.p25:   move.w  d0,d1
        add.w   d0,d0
        add.w   d0,d0
        add.w   d1,d0
        addq.w  #2,d0
        lsr.w   #2,d0
        cmpi.w  #31,d0
        bls.s   .o
        moveq   #31,d0
        rts

;-----------------------------------------------------------------------------
; mus_step - one tick of the ST driver (VBL $3F2C) into G_MREG: the effect
; stream, the note timers and envelopes (channel C's not while an effect plays),
; the sequencer (G_MNV voices: 0 after GAME OVER). Uses d0-d7, a0-a4.
; Jumped to from mus_tick (not called): it ends the tick, the registers that
; changed to the chip (mus_out, MVOL) and mus_tick's saved registers back.
;-----------------------------------------------------------------------------
; MCHAN c - channel c: note timer ($4004: at its end the volume is 0) and the
; software envelope ($4058): byte >= 0 is the volume (step on unless 0); < 0:
; while the note lasts, jump back by it (sustain), after, step past it. An index
; >= $80 is not run (the ST's test); a 0 byte is the envelope's end, where the
; ST writes 0 each tick and never moves on: the index is set to $FF there (the
; same volumes, no work until the next note).
MCHAN   macro
        move.b  G_MENVI+\1(a6),d1
        bpl.s   .a\@
        tst.b   G_MTIM+\1(a6)           ; (idle: the timer only)
        beq.s   .n\@
        subq.b  #1,G_MTIM+\1(a6)
        bne.s   .n\@
        clr.b   G_MREG+8+\1(a6)
        bra.s   .n\@
.a\@:   tst.b   G_MTIM+\1(a6)
        beq.s   .l\@
        subq.b  #1,G_MTIM+\1(a6)
        bne.s   .l\@
        clr.b   G_MREG+8+\1(a6)         ; (the note's end: volume 0)
.l\@:   move.b  0(a3,d1.w),d0
        bpl.s   .p\@
        tst.b   G_MTIM+\1(a6)
        bne.s   .s\@
        addq.b  #1,d1
        bpl.s   .l\@
        bra.s   .t\@
.s\@:   add.b   d0,d1
        bra.s   .t\@
.p\@:   move.b  d0,G_MREG+8+\1(a6)
        bne.s   .i\@
        st      d1
        bra.s   .t\@
.i\@:   addq.b  #1,d1
.t\@:   move.b  d1,G_MENVI+\1(a6)
.n\@:
        endm
; MCHD c - the same for channels A and B (only the music drives their volume),
; with the volume written to the chip at once where it changed (a2 = the writer)
MCHD    macro
        move.b  G_MENVI+\1(a6),d1
        bpl.s   .a\@
        tst.b   G_MTIM+\1(a6)           ; (idle: the timer only)
        beq.s   .n\@
        subq.b  #1,G_MTIM+\1(a6)
        bne.s   .n\@
        moveq   #0,d2
        bra.s   .w\@
.a\@:   moveq   #-1,d2                  ; (d2 < 0: no volume yet)
        tst.b   G_MTIM+\1(a6)
        beq.s   .l\@
        subq.b  #1,G_MTIM+\1(a6)
        bne.s   .l\@
        moveq   #0,d2                   ; (the note's end: volume 0)
.l\@:   move.b  0(a3,d1.w),d0
        bpl.s   .p\@
        tst.b   G_MTIM+\1(a6)
        bne.s   .s\@
        addq.b  #1,d1
        bpl.s   .l\@
        bra.s   .t\@
.s\@:   add.b   d0,d1
.t\@:   move.b  d1,G_MENVI+\1(a6)
        tst.b   d2
        bmi.s   .n\@
        bra.s   .w\@
.p\@:   move.b  d0,d2
        bne.s   .i\@
        st      d1
        bra.s   .u\@
.i\@:   addq.b  #1,d1
.u\@:   move.b  d1,G_MENVI+\1(a6)
.w\@:   cmp.b   G_MOUT+8+\1(a6),d2
        beq.s   .n\@
        move.b  d2,G_MOUT+8+\1(a6)
        moveq   #8+\1,d0
        jsr     (a2)
.n\@:
        endm


mus_step:
        tst.w   G_FXCNT(a6)             ; an effect (waiting or not)
        bne.s   .fx
        tst.l   G_FXPTR(a6)
        beq.s   .nfx
.fx:    bsr     mus_fxstep
.nfx:   lea     .nfx(pc),a3             ; (the table: past the PC-relative reach)
        adda.l  #mus_env-.nfx,a3
        movea.l G_MWR(a6),a2
        moveq   #0,d1
        MCHD    0
        MCHD    1
        tst.l   G_FXPTR(a6)             ; an effect: C's timer only
        beq.s   .c2
        tst.b   G_MTIM+2(a6)
        beq.s   .c2x
        subq.b  #1,G_MTIM+2(a6)
        bne.s   .c2x
        clr.b   G_MREG+10(a6)
        bra.s   .c2x
.c2:    MCHAN   2
.c2x:   tst.w   G_MNV(a6)
        beq.s   .o
        subq.w  #1,G_MCNT(a6)           ; the sequencer ($36D2): one countdown to
        bne.s   .o                      ; the next voice due (mus_pass)
        bsr     mus_pass
.o:     movea.l G_MWR(a6),a2            ; (mus_tick's tail) the chip: R0-R7 when the
        tst.b   G_MDRT(a6)              ; step touched them, R10 where it changed (A,
        beq.s   .vol                    ; B: above)
        bsr     mus_out
.vol:   MVOL    2
        movem.l (sp)+,d0-d3/a0-a3       ; (mus_tick's)
        rts

; mus_fxstep - the effect stream ($3F58): a wait tick (and the sweep on C's
; period), or the stream read up to the next wait / its end. Uses d0-d1, a0-a1.
mus_fxstep:
        tst.w   G_FXCNT(a6)
        beq.s   .rd
        subq.w  #1,G_FXCNT(a6)
        move.w  G_FXSW(a6),d0
        beq.s   .o
        st      G_MDRT(a6)
        add.w   d0,G_FXSH(a6)
        move.w  G_FXSH(a6),d0
        move.b  d0,G_MREG+4(a6)
        lsr.w   #8,d0
        move.b  d0,G_MREG+5(a6)
.o:     rts
.rd:    move.l  G_FXPTR(a6),d0
        beq.s   .o
        st      G_MDRT(a6)
        movea.l d0,a0
        lea     G_MREG(a6),a1
.l:     moveq   #0,d0
        move.b  (a0)+,d0
        bmi.s   .c
        move.b  (a0)+,d1
        cmpi.w  #11,d0                  ; (R16 in effect 6: not a register)
        bhs.s   .l
        move.b  d1,0(a1,d0.w)
        cmpi.w  #4,d0                   ; (C's period: its shadow, for the sweep)
        bne.s   .s5
        move.b  d1,G_FXSH+1(a6)
        bra.s   .l
.s5:    cmpi.w  #5,d0
        bne.s   .l
        move.b  d1,G_FXSH(a6)
        bra.s   .l
.c:     cmpi.b  #$FF,d0
        beq.s   .end
        cmpi.b  #$FE,d0
        bne.s   .w
        move.b  (a0)+,d1
        ext.w   d1
        move.w  d1,G_FXSW(a6)
        bra.s   .l
.w:     andi.w  #$7F,d0
        move.w  d0,G_FXCNT(a6)
        move.l  a0,G_FXPTR(a6)
        rts
.end:   clr.l   G_FXPTR(a6)
        clr.w   G_FXCUR(a6)
        rts


;-----------------------------------------------------------------------------
; mus_pass - the countdown ran out: G_MNOW (the tick count) moves on by its
; length; the voices due now (V_DUE = G_MNOW, not parked) run in order 0-3
; (mus_due); then the countdown to the earliest V_DUE. For mus_tick only: uses
; d0-d3, a1-a3 (mus_tick saved them).
;-----------------------------------------------------------------------------
mus_pass:
        movem.l d6/a4,-(sp)
        move.w  G_MCNT0(a6),d0
        add.w   d0,G_MNOW(a6)
        lea     G_MVO(a6),a4
        moveq   #0,d6
.v:     tst.w   V_PARK(a4)
        bne.s   .n
        move.w  V_DUE(a4),d0
        cmp.w   G_MNOW(a6),d0
        bne.s   .n
        bsr.s   mus_due
.n:     lea     V_SIZE(a4),a4
        addq.w  #1,d6
        cmpi.w  #4,d6
        bne.s   .v
        lea     G_MVO(a6),a4
        moveq   #3,d6
        moveq   #-1,d1                  ; (none: $FFFF ticks, then looked at again)
.m:     tst.w   V_PARK(a4)
        bne.s   .mn
        move.w  V_DUE(a4),d0
        sub.w   G_MNOW(a6),d0
        cmp.w   d1,d0
        bhs.s   .mn
        move.w  d0,d1
.mn:    lea     V_SIZE(a4),a4
        dbra    d6,.m
        move.w  d1,G_MCNT(a6)
        move.w  d1,G_MCNT0(a6)
        movem.l (sp)+,d6/a4
        rts

;-----------------------------------------------------------------------------
; mus_due - voice a4 (number d6) is due: V_CAT is the ST's new clock then
; (clock + n x tempo - next). Its events until it is not due ($371C); then its
; next tick V_DUE = G_MNOW + n and the clock it will have then (V_CAT), from
; next - clock = k x tempo + (m - clock) (no division). A voice that ran off its
; end (tempo 0) is parked (V_PARK): the ST never runs it again, except after an
; Ultimate restart (clock = next = 0), which unparks every voice. Uses d0-d3,
; a1-a3 (mus_pass).
;-----------------------------------------------------------------------------
mus_due:
        movem.l d4-d5/d7/a0,-(sp)
        move.l  V_CAT(a4),d0
.f:     move.l  d0,V_CLK(a4)
        move.l  #$FFFFFF,V_NXT(a4)
        bsr     mus_events
        tst.w   d5
        bne.s   .park                   ; (the voice ended)
        move.l  V_TEMPO(a4),d1
        beq.s   .park                   ; (tempo 0, run after a restart: its clock
        moveq   #0,d0                   ;  never reaches the next event)
        move.w  V_NM(a4),d0
        sub.l   V_CLK(a4),d0            ; r = m - clock, q = k: next - clock =
        move.w  V_NK(a4),d2             ; q x tempo + r, made 0 <= r < tempo
.nl:    tst.l   d0
        bpl.s   .np
        add.l   d1,d0
        subq.w  #1,d2
        bra.s   .nl
.np:    tst.w   d2
        bmi.s   .now                    ; next < clock: due again now
        bne.s   .lat
        tst.l   d0
        beq.s   .now                    ; next = clock: due again now
.lat:   tst.l   d0
        beq.s   .ex                     ; r = 0: in q ticks, clock 0
        addq.w  #1,d2                   ; else in q + 1 ticks, clock tempo - r
        neg.l   d0
        add.l   d1,d0
.ex:    add.w   G_MNOW(a6),d2
        move.w  d2,V_DUE(a4)
        move.l  d0,V_CAT(a4)
        bra.s   .o
.now:   move.l  V_CLK(a4),d0
        sub.l   V_NXT(a4),d0
        bra.s   .f
.park:  move.w  #1,V_PARK(a4)
.o:     movem.l (sp)+,d4-d5/d7/a0
        rts


;-----------------------------------------------------------------------------
; mus_events - voice a4 (number d6) is due: its events up to the first note or
; rest that is not a chord ($376A); a note's period into G_MREG. Out:
; d5.w = 1 if the voice ran off its end (its tempo is then 0: it stops). Uses
; d0-d5, d7, a0-a3.
;-----------------------------------------------------------------------------
mus_events:
        moveq   #0,d5
.r:     move.w  V_POS(a4),d0
        cmp.w   V_LEN(a4),d0
        bhs     .end
        movea.l V_BASE(a4),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1           ; a: note, $80 rest, $81+ command
        move.b  1(a0,d0.w),d2           ; b
        addq.w  #2,V_POS(a4)
        cmpi.b  #$81,d1
        blo     .nr
        cmpi.b  #$81,d1
        beq.s   .ins
        cmpi.b  #$87,d1
        beq.s   .gtr
        cmpi.b  #$8B,d1
        beq.s   .lps
        cmpi.b  #$8C,d1
        beq.s   .lpe
        cmpi.b  #$A1,d1
        bne.s   .r                      ; (the others: ignored, as on the ST)
        add.b   d2,V_TRANS(a4)
        bra     .r
.ins:   move.b  d2,V_INSTR(a4)
        bra     .r
.gtr:   add.b   d2,G_MGTR+1(a6)
        bra     .r
.lps:   move.w  V_DEPTH(a4),d3          ; loop start ($3856)
        cmpi.w  #DEPTH,d3
        beq     .r
        move.b  d2,V_CNT(a4,d3.w)
        clr.b   V_CUR(a4,d3.w)
        add.w   d3,d3
        move.w  V_POS(a4),V_RET(a4,d3.w)
        addq.w  #1,V_DEPTH(a4)
        bra     .r
.lpe:   tst.w   G_MRST(a6)              ; loop end ($38B0)
        bne.s   .rst
        move.w  V_DEPTH(a4),d3
        beq     .r
        subq.w  #1,d3
        tst.b   d2
        beq.s   .lz
        move.b  V_CUR(a4,d3.w),d4       ; ENDLOOP(n): alternate endings
        bne.s   .lc
        move.b  d2,V_CUR(a4,d3.w)
        bra     .r
.lc:    cmp.b   d2,d4
        blo.s   .la
        move.b  d2,V_CUR(a4,d3.w)
        add.w   d3,d3
        move.w  V_POS(a4),V_ALT(a4,d3.w)
        move.w  V_RET(a4,d3.w),V_POS(a4)
        bra     .r
.la:    add.w   d3,d3
        move.w  V_ALT(a4,d3.w),V_POS(a4)
        bra     .r
.lz:    clr.b   V_CUR(a4,d3.w)          ; ENDLOOP(0): count down, 0 = forever
        move.b  V_CNT(a4,d3.w),d4
        beq.s   .lj
        subq.b  #1,d4
        move.b  d4,V_CNT(a4,d3.w)
        bne.s   .lj
        subq.w  #1,V_DEPTH(a4)
        bra     .r
.lj:    add.w   d3,d3
        move.w  V_RET(a4,d3.w),V_POS(a4)
        bra     .r
.rst:   lea     G_MVO(a6),a1            ; Ultimate: voices 0-2 from their restart
        lea     G_MRP(a6),a2            ; positions, every clock from 0
        moveq   #2,d3
.r1:    move.w  (a2)+,V_POS(a1)
        clr.w   V_DEPTH(a1)
        lea     V_SIZE(a1),a1
        dbra    d3,.r1
        lea     G_MVO(a6),a1
        moveq   #0,d3                   ; (voice u)
.r2:    clr.l   V_CLK(a1)
        clr.l   V_NXT(a1)
        clr.l   V_NK(a1)                ; (k, m: next = 0)
        move.l  V_TEMPO(a1),V_CAT(a1)   ; due with clock = tempo: the voices after
        clr.w   V_PARK(a1)              ; this one in this pass, the others at the
        move.w  G_MNOW(a6),d4           ; next tick (this one: mus_due sets it)
        cmp.w   d6,d3
        bhs.s   .r3
        addq.w  #1,d4
.r3:    move.w  d4,V_DUE(a1)
        lea     V_SIZE(a1),a1
        addq.w  #1,d3
        cmpi.w  #4,d3
        bne.s   .r2
        bra     .r
.nr:    moveq   #63,d3                  ; note or rest: next = min(next, d) ($39EC)
        and.b   d2,d3
        lsl.w   #3,d3
        movea.l G_MDUR(a6),a1
        move.l  0(a1,d3.w),d4
        cmp.l   V_NXT(a4),d4
        bhs.s   .nm
        move.l  d4,V_NXT(a4)
        move.l  4(a1,d3.w),V_NK(a4)     ; (its k and m: V_NK, V_NM)
.nm:    cmpi.b  #$80,d1
        beq     .ch                     ; (a rest)
        lea     G_MTIE(a6),a1           ; a tie held by this voice: no new note
        move.b  d6,d4                   ; ($3C86, $3CAC)
        addq.b  #1,d4
        moveq   #0,d7
        cmp.b   0(a1,d1.w),d4
        bne.s   .nh
        clr.b   0(a1,d1.w)
        moveq   #1,d7
.nh:    btst    #6,d2
        beq.s   .nt
        move.b  d4,0(a1,d1.w)
.nt:    tst.w   d7
        bne     .ch
        bsr     mus_len                 ; d0 = the note's ticks
        andi.w  #$FF,d0
        bne.s   .d
        moveq   #1,d0
.d:     move.b  d1,d3                   ; the note: + global and voice transpose
        add.b   G_MGTR+1(a6),d3
        add.b   V_TRANS(a4),d3
        andi.w  #$7F,d3
        lea     G_MTIM(a6),a1           ; the channel ($475E): least time left,
        moveq   #0,d4                   ; A before B before C on a tie
        move.b  (a1),d7
        cmp.b   1(a1),d7
        blo.s   .a1
        moveq   #1,d4
        move.b  1(a1),d7
.a1:    tst.l   G_FXPTR(a6)             ; (an effect holds channel C)
        bne.s   .a2
        cmp.b   2(a1),d7
        blo.s   .a2
        moveq   #2,d4
.a2:    move.b  d0,0(a1,d4.w)           ; its timer, its envelope
        move.b  V_INSTR(a4),G_MENVI-G_MTIM(a1,d4.w)
        add.w   d3,d3                   ; its period: the ST's (converted for the
.stp:   lea     .stp(pc),a2             ; board in mus_out; a PC-relative far
        adda.l  #mus_stper-.stp,a2      ;  reference: the tables are at the end)
        move.w  0(a2,d3.w),d3
        add.w   d4,d4
        lea     G_MREG(a6),a3
        move.b  d3,0(a3,d4.w)
        lsr.w   #8,d3
        move.b  d3,1(a3,d4.w)
        st      G_MDRT(a6)
        tst.l   G_FXPTR(a6)             ; the ST sets its mixer with each note, when
        bne.s   .ch                     ; no effect plays
        move.b  #$F8,7(a3)
.ch:    tst.b   d2                      ; b bit 7: a chord, the next event too
        bmi     .r
        rts
.end:   clr.l   V_TEMPO(a4)
        moveq   #1,d5
        rts

;-----------------------------------------------------------------------------
; mus_len - the ticks of note d1 (b = d2) of voice a4 ($3AB0): (d - clock) /
; tempo, and with b bit 6 (tie) the following events of the same note added
; ($3B12). Out: d0.w (0 if the note is already over). Preserves d1, d2, d5;
; uses d3, d4, a0, a1.
;-----------------------------------------------------------------------------
mus_len:
        movem.l d1-d2/d5,-(sp)
        move.w  d2,d3
        move.l  V_CLK(a4),d4
        bsr.s   .q
        bmi.s   .zero
        moveq   #0,d0
        move.w  d3,d0
        btst    #6,d2
        beq.s   .out
        moveq   #0,d5                   ; $3C2E: 1 with a chord
        btst    #7,d2
        beq.s   .s0
        moveq   #1,d5
.s0:    movea.l V_BASE(a4),a0
        move.w  V_POS(a4),d2
.sl:    cmp.w   V_LEN(a4),d2
        bhs.s   .out
        move.b  0(a0,d2.w),d3
        addq.w  #2,d2
        cmpi.b  #$81,d3
        bhs.s   .sl                     ; (commands: passed over)
        cmp.b   d1,d3
        bne.s   .nx
        move.b  -1(a0,d2.w),d3          ; the same note: its length from the
        bsr.s   .q                      ; remainder
        bmi.s   .zero
        add.w   d3,d0
        moveq   #1,d5
.nx:    tst.b   -1(a0,d2.w)
        bmi.s   .sl
        subq.w  #1,d5
        bpl.s   .sl
.out:   movem.l (sp)+,d1-d2/d5
        rts
.zero:  moveq   #0,d0
        bra.s   .out
; .q - d3 = duration index (bits 0-5), d4.l = c: d3.w = (d - c) / tempo (N: d < c),
; d4.l = the remainder. d = k x tempo + m, so (d - c) = k x tempo + (m - c).
.q:     andi.w  #63,d3
        lsl.w   #3,d3
        movea.l G_MDUR(a6),a1
        adda.w  d3,a1
        neg.l   d4
        moveq   #0,d3
        move.w  6(a1),d3
        add.l   d3,d4                   ; m - c
        move.w  4(a1),d3                ; k
.ql:    tst.l   d4
        bpl.s   .qo
        add.l   G_MTEMPO(a6),d4
        subq.w  #1,d3
        bra.s   .ql
.qo:    tst.w   d3
        rts


;-----------------------------------------------------------------------------
; The beeper (G_AUD = AB_BEEP: no AY board, or the loader's aud = 5): the ST's
; effects as IPC BEEPs (beep_tab, generated). A new effect
; replaces the one sounding (its BEEP cuts the last); the same effect is not
; restarted while it lasts; the ST's race remaps. The BEEPs go out in mus_frame,
; right after the logic: the next IPC read (read_input) comes a frame later,
; and read_input skips the IPC for 2 ticks after a BEEP (beep_quiet) whatever
; happens (Q-emuLator: a KEYROW soon after a BEEP can read garbage or hang).
;-----------------------------------------------------------------------------
; beep_frame - (from mus_frame, d0 = the effects asked for) started in turn as
; mus_sfxreq (bit 1 first, so the highest wins as the ST's last $3E04 call), then
; at most one BEEP of the effect playing goes out (a chain's later ones when
; their tick comes). A frame with nothing asked for and nothing due: no IPC.
beep_frame:
        clr.l   G_MSFX(a6)
        move.l  d0,d1
        beq.s   .send
        moveq   #1,d0
.f:     btst    d0,d1
        beq.s   .n
        bsr.s   beep_sfx
.n:     addq.w  #1,d0
        cmpi.w  #SFX_N+1,d0
        bne.s   .f
.send:  tst.w   G_BLEFT(a6)
        beq.s   .o
        movea.l G_TICKP(a6),a0          ; (the clock: G_PTICK, or SV_RAND)
        move.w  (a0),d1
        movea.l G_BPTR(a6),a0
        sub.w   G_BSTART(a6),d1
        moveq   #0,d0
        move.b  (a0)+,d0                ; its start tick
        cmp.w   d0,d1
        blo.s   .o
        bsr     tk_poll                 ; (takeover: the frame flag, before the IPC's
        bsr     beep_send               ;  ~7 ms of a BEEP; see the poll-gap rule)
        lea     8(a0),a0
        move.l  a0,G_BPTR(a6)
        subq.w  #1,G_BLEFT(a6)
.o:     rts

; beep_sfx - effect d0.w (1-18) on the beeper, as mus_sfx: the one sounding is
; not restarted; Practice plays 16 for 15, Aerial drops 15, Silly drops 3 (the
; id is kept: the one sounding goes on). Preserves all registers.
beep_sfx:
        movem.l d0-d1/a0-a1,-(sp)
        cmp.w   G_BCUR(a6),d0           ; the same, still sounding: not restarted
        bne.s   .new
        movea.l G_TICKP(a6),a0
        move.w  (a0),d1
        sub.w   G_BSTART(a6),d1
        cmp.w   G_BLEN(a6),d1
        blo.s   .x
.new:   move.w  d0,G_BCUR(a6)
        cmpi.w  #15,d0
        bne.s   .n15
        cmpi.w  #3,G_RACE(a6)           ; Aerial
        beq.s   .x
        tst.w   G_RACE(a6)              ; Practice
        bne.s   .n15
        moveq   #16,d0
.n15:   cmpi.w  #3,d0
        bne.s   .go
        cmpi.w  #4,G_RACE(a6)           ; Silly
        beq.s   .x
.go:    lea     .go(pc),a0              ; (the table: past the PC-relative reach)
        adda.l  #beep_tab-.go,a0
        add.w   d0,d0
        move.w  -2(a0,d0.w),d0
        beq.s   .x                      ; (an ST effect with no sound)
        adda.w  d0,a0
        movea.l G_TICKP(a6),a1
        move.w  (a1),G_BSTART(a6)
        moveq   #0,d0
        move.b  (a0)+,d0
        move.w  d0,G_BLEFT(a6)
        move.b  (a0)+,d0
        move.w  d0,G_BLEN(a6)
        move.l  a0,G_BPTR(a6)
.x:     movem.l (sp)+,d0-d1/a0-a1
        rts

; beep_mute - (mus_frame, the beeper muted) nothing asked for is kept; once
; after \ : the chain dropped and the BEEP sounding killed (IPC command 11, as a
; BEEP for the 2-tick rule: G_BLAST, G_BSENT)
beep_mute:
        clr.l   G_MSFX(a6)
        clr.w   G_MB+M_EVENTS(a6)
        tst.w   G_BKILL(a6)
        beq.s   .o
        clr.w   G_BKILL(a6)
        clr.w   G_BLEFT(a6)
        clr.w   G_BCUR(a6)              ; (back: the next effect starts afresh)
        movem.l d0-d5/a0-a3/a6,-(sp)
        movea.l G_TICKP(a6),a1
        move.w  (a1),G_BLAST(a6)
        move.w  #1,G_BSENT(a6)
        ifeq    RELB
        bset    #0,G_TFLG+1(a6)         ; (telemetry: an IPC sound command this frame)
        endc
        tst.w   G_TKON(a6)
        beq.s   .qd
        bsr     tk_poll                 ; (the frame flag, before the IPC)
        moveq   #11,d4
        moveq   #4,d1
        bsr     ipc_send
        bsr     tk_clri
        bra.s   .x
.qd:    lea     .blk(pc),a3
        movea.l G_SYS(a6),a6
        moveq   #MT_IPCOM,d0
        moveq   #0,d3
        trap    #1
.x:     movem.l (sp)+,d0-d5/a0-a3/a6
.o:     rts
.blk:   dc.b    $0B,0,0,0,0,0,1         ; kill sound: no parameters, no reply
        even

; beep_send - one IPC BEEP (SOUND, command 10), a0 = its 8 parameter bytes:
; takeover: the IPC's registers (as tk_row: the command nibble, then the bytes
; msb first); QDOS: MT.IPCOM (no reply). G_BLAST = its tick, G_BCNT + 1.
beep_send:
        movem.l d0-d5/a0-a3/a6,-(sp)
        movea.l G_TICKP(a6),a1
        move.w  (a1),G_BLAST(a6)
        move.w  #1,G_BSENT(a6)
        addq.l  #1,G_BCNT(a6)
        ifeq    RELB
        bset    #0,G_TFLG+1(a6)         ; (telemetry: a BEEP this frame)
        endc
        tst.w   G_TKON(a6)
        beq.s   .qd
        moveq   #10,d4
        moveq   #4,d1
        bsr     ipc_send
        moveq   #7,d5
.b:     moveq   #0,d4
        move.b  (a0)+,d4
        moveq   #8,d1
        bsr     ipc_send
        dbra    d5,.b
        bsr     tk_clri
        bra.s   .o
.qd:    lea     G_BBLK(a6),a3           ; $0A, 8, $0000AAAA, the 8 bytes, 1
        move.l  #$0A080000,(a3)
        move.w  #$AAAA,4(a3)
        lea     6(a3),a1
        moveq   #7,d0
.c:     move.b  (a0)+,(a1)+
        dbra    d0,.c
        move.b  #1,(a1)                 ; (reply 1: none; 0 would ask for 4 bits)
        movea.l G_SYS(a6),a6
        moveq   #MT_IPCOM,d0
        moveq   #0,d3
        trap    #1
.o:     movem.l (sp)+,d0-d5/a0-a3/a6
        rts

; beep_quiet - (read_input) Z clear while a BEEP went out less than 2 ticks
; ago: the IPC is then left alone this frame
beep_quiet:
        tst.w   G_BSENT(a6)
        beq.s   .o
        move.l  a0,-(sp)
        movea.l G_TICKP(a6),a0
        move.w  (a0),-(sp)
        move.w  G_BLAST(a6),d0
        sub.w   d0,(sp)
        cmpi.w  #2,(sp)+
        movea.l (sp)+,a0
        bhs.s   .clr
        moveq   #1,d0                   ; (Z clear; d0 not needed by the caller)
        rts
.clr:   clr.w   G_BSENT(a6)
.o:     cmp.w   d0,d0                   ; Z set
        rts

; beep_wait - (quit, before tk_exit's IPC reads) until 2 ticks after the last
; BEEP. Uses d0-d1/d4-d5/a0.
beep_wait:
        tst.w   G_BSENT(a6)
        beq.s   .o
        move.w  G_BLAST(a6),d1
        addq.w  #2,d1
        movea.l G_TICKP(a6),a0
        move.w  d1,d0
        sub.w   (a0),d0
        ble.s   .o                      ; (already past)
        cmpi.w  #2,d0
        bhi.s   .o                      ; (the clock wrapped: long past)
        move.l  #CAL_CAP,d4
        bsr     spin_to                 ; (to the tick d1, polling the flag in takeover)
.o:     clr.w   G_BSENT(a6)
        rts

; (the tables, generated: data/mus_tab.inc, are included at the end of proto.asm)

        endc
