; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; frontend.asm - the game over and the HIGH ROLLERS table. Included after
; mobj.asm:
; nothing here runs in a racing frame (fe_gameover runs while play is stopped:
; after the time out's wait, or after Ultimate), so the frame code stays in bsr
; reach of what it calls. Calls into the main code are PC-relative far calls
; (FARCALL: a0 is clobbered). Also steelie_pts (src/mobj.asm: the score, far).
;
; The table: G_HI, 10 x (6 ASCII name bytes, 3 base-100 score bytes high first),
; the defaults (hi_default, data/fe_gen.inc) copied by fe_init at the
; start; kept for the session (the program's globals; the release loader's
; ESC resets the machine, and the table with it).
;=============================================================================

HI_N            equ     10
HI_SZ           equ     9
FE_CY           equ     16              ; text rows at scale 2 (14 lines + 2)
KRB_ENTER       equ     0               ; KEYROW row 1 bits
KRB_LEFT        equ     1
KRB_UP          equ     2
KRB_ESC         equ     3
KRB_RIGHT       equ     4
KRB_SPACE       equ     6
KRB_DOWN        equ     7

; steelie_pts - (src/mobj.asm, the steelie knocked off) the score for the
; player in play: +1,000
steelie_pts:
        tst.b   G_MB+M_PRESENT+1(a6)
        beq.s   .o
        movem.l d0-d2/a0/a4,-(sp)
        lea     G_MB(a6),a4
        moveq   #10,d0
        moveq   #1,d1
        FARCALL add_score
        movem.l (sp)+,d0-d2/a0/a4
.o:     rts

; fe_init - the table = the defaults
fe_init:
        lea     hi_default(pc),a0
        lea     G_HI(a6),a1
        move.w  #HI_N*HI_SZ-1,d0
.c:     move.b  (a0)+,(a1)+
        dbra    d0,.c
        rts

;-----------------------------------------------------------------------------
; fe_gameover - d0.w = 1: the time out (the OUT OF TIME / GAME OVER box on the
; screen as it is, 4 s), 0: after Ultimate. Then a score that ranks enters a
; name (the letter grid, or typed), and the HIGH ROLLERS table shows until
; SPACE / fire / ENTER / a typed key. ESC: G_QUIT (the caller then quits).
; Demo and benchmark runs skip it all. Leaves the panel to be redrawn whole.
;-----------------------------------------------------------------------------
fe_gameover:
        movem.l d0-d7/a0-a5,-(sp)
        ifeq    RELB
        tst.w   G_DEMO(a6)
        bne     .x
        tst.w   G_BENCH(a6)
        bne     .x
        endc
        move.w  d0,d7
        ifne    MUS_ON
        FARCALL mus_silence
        endc
        move.w  #-1,G_FERANK(a6)
        tst.w   d7
        beq.s   .nobox
        bsr     fe_box
        move.w  #200,d0                 ; 4 s
        bsr     fe_wait
        tst.w   G_QUIT(a6)
        bne     .end
.nobox: bsr     fe_rank                 ; d0 = the rank 0-9, or -1
        move.w  d0,G_FERANK(a6)
        bmi.s   .tab
        bsr     fe_entry                ; the name
        tst.w   G_QUIT(a6)
        bne     .end
        bsr     fe_insert
.tab:   bsr     fe_table
        bsr     fe_tabled               ; (a test hook)
        bsr     fe_release
        move.w  #1000,G_FETO(a6)        ; (20 s, then on by itself)
.w:     bsr     fe_frame
        tst.w   G_QUIT(a6)
        bne.s   .end
        tst.w   d0                      ; a press (SPACE / fire / ENTER / a key)
        beq.s   .w
        bsr     fe_start                ; the start screen
.end:   bsr.s   fe_done
.x:     movem.l (sp)+,d0-d7/a0-a5
        rts

; fe_done - after the screens: both black, and the game's screen state reset
; (it redraws everything)
fe_done:
        bsr     fe_cls                  ; (the game redraws everything)
        ifeq    RELB
        lea     G_SHAD0(a6),a0          ; the panel: unknown on both screens
        move.w  #2*TEXT_LEN-1,d0
.s:     move.b  #$FF,(a0)+
        dbra    d0,.s
        move.w  #3,G_TDIRTY(a6)
        endc
        move.l  #-1,G_SCSHOWN(a6)
        move.w  #$FFFD,G_TSHOWN(a6)     ; (the time: shown again)
        FARCALL hud_reset               ; (the HUD too)
        FARCALL get_tick
        move.w  d0,G_FT0(a6)            ; (the frame pacing from now)
        rts

fe_tabled:                              ; (the table is up: a test hook)
        rts

;-----------------------------------------------------------------------------
; The start screen: the loading screen's MARBLE MADNESS logo, the keys,
; PRESS SPACE TO START. Before the first race (fe_title) and after the high
; scores (fe_gameover). SPACE or fire starts; ESC sets G_QUIT. The test build
; shows it only when the loader asks (G_TSTART: the game's loaders); the
; release always.
;-----------------------------------------------------------------------------
fe_title:
        movem.l d0-d7/a0-a5,-(sp)
        ifeq    RELB
        tst.w   G_TEND(a6)              ; (mme_bas: straight to the ending)
        bne.s   .o
        endc
        bsr.s   fe_start
        tst.w   d0
        beq.s   .o
        bsr     fe_done
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts

; fe_start - d0.w = 1 when shown (then a2 and the screens are the caller's to
; restore: fe_done)
fe_start:
        moveq   #0,d0
        ifeq    RELB
        tst.w   G_TSTART(a6)
        beq.s   .o
        tst.w   G_DEMO(a6)
        bne.s   .o
        tst.w   G_BENCH(a6)
        bne.s   .o
        endc
        movem.l d1-d7/a0-a5,-(sp)
        bsr     fe_cls
        lea     SCREEN,a2
        bsr     fe_logo
        lea     txt_start(pc),a1
        bsr     fe_strs
        bsr.s   fe_started              ; (a test hook)
        bsr     fe_release
        clr.w   G_FETO(a6)              ; (no time-out: it waits)
.w:     bsr     fe_frame
        tst.w   G_QUIT(a6)
        bne.s   .y
        tst.w   d0
        beq.s   .w
        tst.w   d1                      ; (a typed key or the time-out: not SPACE,
        bpl.s   .w                      ;  which the KEYROW input reads)
        btst    #KRB_SPACE,d2
        beq.s   .w
.y:     movem.l (sp)+,d1-d7/a0-a5
        moveq   #1,d0
.o:     rts

fe_started:                             ; (the screen is up: a test hook)
        rts

; fe_logo - the logo (data/mm_logo.inc: 1 bit a
; pixel, the left one in bit 7) in its colour, LOGO_TOP down, at its x on the
; loading screen; a2 = the screen
LOGO_TOP        equ     24
fe_logo:
        movem.l d0-d7/a0-a4,-(sp)
        lea     mm_logo(pc),a0
        lea     LOGO_TOP*BPL+LOGO_X/2(a2),a3
        moveq   #LOGO_COL,d7
        move.w  #LOGO_H-1,d6
.r:     movea.l a3,a4
        moveq   #LOGO_WB-1,d5
.b:     moveq   #0,d1
        move.b  (a0)+,d1
        move.w  d1,d3
        lsr.w   #4,d1                   ; the left 4 pixels
        bsr     fe_word
        move.w  d0,(a4)+
        move.w  d3,d1
        andi.w  #15,d1                  ; the right 4
        bsr     fe_word
        move.w  d0,(a4)+
        dbra    d5,.b
        lea     BPL(a3),a3
        bsr     fe_poll
        dbra    d6,.r
        movem.l (sp)+,d0-d7/a0-a4
        rts

; fe_loadlogo - the loading screen (G_TLOGO, the loader's first CALL): the
; title screen as data/mm_scr has it, composed: the screen cleared, the logo where
; the title has it, then its text (fe_ltext)
LOAD_TOP        equ     95
fe_loadlogo:
        lea     SCREEN,a2
        move.w  #32768/4-1,d0
.c:     clr.l   (a2)+
        dbra    d0,.c
        lea     SCREEN+(LOAD_TOP-LOGO_TOP)*BPL,a2
        bsr     fe_logo
; fe_ltext - the title's text (data/mm_title.inc): per
; string its 8x8 glyphs, each row's halves masked out of the string's colour word
; for that line (two words: the 2x2 pattern)
fe_ltext:
        movem.l d0-d7/a0-a5,-(sp)
        lea     mm_title(pc),a0
        lea     tt_glyphs(pc),a3
        lea     tt_mask(pc),a5
.s:     move.w  (a0)+,d0                ; line x BPL + byte (-1: the end)
        bmi.s   .o
        lea     SCREEN,a1
        adda.w  d0,a1
        move.w  (a0)+,d4                ; the first line's colour word
        move.w  (a0)+,d5                ; the next line's
        move.w  (a0)+,d6                ; cells - 1
.g:     moveq   #0,d0
        move.b  (a0)+,d0
        lsl.w   #3,d0
        lea     0(a3,d0.w),a2
        movea.l a1,a4
        moveq   #8-1,d7
.r:     moveq   #0,d1
        move.b  (a2)+,d1
        move.w  d1,d2
        lsr.w   #4,d2                   ; the left 4 pixels
        add.w   d2,d2
        move.w  0(a5,d2.w),d3
        and.w   d4,d3
        move.w  d3,(a4)
        andi.w  #15,d1                  ; the right 4
        add.w   d1,d1
        move.w  0(a5,d1.w),d3
        and.w   d4,d3
        move.w  d3,2(a4)
        exg     d4,d5
        lea     BPL(a4),a4
        dbra    d7,.r
        addq.l  #4,a1
        dbra    d6,.g
        move.l  a0,d0                   ; (even)
        addq.l  #1,d0
        andi.w  #$FFFE,d0
        movea.l d0,a0
        bra.s   .s
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts
        include "mm_title.inc"          ; (generated: mm_title, tt_glyphs, tt_mask)

; fe_rank - d0.w = where the score goes in the table (0-9), -1 if it does not
; rank (it must beat the entry: an equal score goes below it)
fe_rank:
        move.l  G_MB+M_SCORE(a6),d1
        andi.l  #$FFFFFF,d1
        lea     G_HI+6(a6),a0
        moveq   #0,d0
.l:     moveq   #0,d2
        move.b  (a0),d2
        swap    d2
        move.b  1(a0),d2
        lsl.w   #8,d2
        move.b  2(a0),d2
        cmp.l   d2,d1
        bhi.s   .o
        lea     HI_SZ(a0),a0
        addq.w  #1,d0
        cmpi.w  #HI_N,d0
        blo.s   .l
        moveq   #-1,d0
.o:     rts

; fe_insert - the entry G_FEN / the score at rank G_FERANK, the rest down one
fe_insert:
        move.w  G_FERANK(a6),d0
        lea     G_HI+HI_N*HI_SZ(a6),a1  ; the table's end
        lea     -HI_SZ(a1),a0           ; (the last entry falls off)
        move.w  #HI_N-1,d1
        sub.w   d0,d1
        mulu.w  #HI_SZ,d1
        bra.s   .n
.m:     move.b  -(a0),-(a1)
.n:     dbra    d1,.m
        mulu.w  #HI_SZ,d0
        lea     G_HI(a6),a1
        adda.w  d0,a1
        lea     G_FEN(a6),a0
        moveq   #6-1,d1
.c:     move.b  (a0)+,(a1)+
        dbra    d1,.c
        move.b  G_MB+M_SCORE+1(a6),(a1)+
        move.b  G_MB+M_SCORE+2(a6),(a1)+
        move.b  G_MB+M_SCORE+3(a6),(a1)+
        rts

;-----------------------------------------------------------------------------
; Screens
;-----------------------------------------------------------------------------
; fe_cls - both screens black (screen 1 only with dual screens), screen 0 shown
fe_cls:
        lea     SCREEN,a2
        bsr     fe_clr
        tst.w   G_DUAL(a6)
        beq.s   .s
        lea     SCREEN1,a2
        bsr     fe_clr
.s:     moveq   #0,d0
        FARCALL flip_to
        ; the frame drawing goes on in step with the screen shown (as sync_end and
        ; apply_sync keep them): double buffering (G_SEFF 2) draws into the screen
        ; not shown, SCREEN1; one screen (FREE / VSYNC, or no dual) into SCREEN. A
        ; game over runs inside a frame: G_DEST must match the screen shown, or
        ; the rest of the frame draws onto the shown screen and sync_end then
        ; shows the cleared one (the next race's box over a blank playfield)
        move.l  #SCREEN,G_DEST(a6)
        cmpi.w  #2,G_SEFF(a6)
        bne.s   .o
        move.l  #SCREEN1,G_DEST(a6)
.o:     rts

fe_clr: move.w  #32-1,d1                ; 32 x 1 KB, a poll after each
.k:     moveq   #256/4-1,d0
.l:     clr.l   (a2)+
        clr.l   (a2)+
        clr.l   (a2)+
        clr.l   (a2)+
        dbra    d0,.l
        bsr     fe_poll
        dbra    d1,.k
        rts

fe_poll:
        tst.b   G_TKON+1(a6)
        beq.s   .o
        movem.l d0-d4/a0,-(sp)
        FARCALL tk_poll
        movem.l (sp)+,d0-d4/a0
.o:     rts

; fe_box - the OUT OF TIME / GAME OVER box over
; the screen shown (both screens with dual screens)
fe_box:
        lea     SCREEN,a2
        bsr.s   fe_box1
        tst.w   G_DUAL(a6)
        beq.s   .o
        lea     SCREEN1,a2
        bsr.s   fe_box1
.o:     rts
fe_box1:
        lea     100*BPL+32(a2),a1       ; x 64-191, lines 100-163: black
        moveq   #64-1,d1
.r:     moveq   #64/4-1,d0
        movea.l a1,a4
.c:     clr.l   (a4)+
        dbra    d0,.c
        lea     BPL(a1),a1
        dbra    d1,.r
        bsr     fe_poll
        lea     txt_out(pc),a1
        bra     fe_strs

; fe_table - the HIGH ROLLERS screen (after the game over): the
; title, the 10 entries (the new one in white), and how to go on
fe_table:
        bsr     fe_cls
        lea     SCREEN,a2
        lea     txt_hi(pc),a1
        bsr     fe_strs
        moveq   #0,d6                   ; rank
        lea     G_HI(a6),a3
.e:     lea     G_FELINE(a6),a1         ; "#nn NAME.. sss,sss"
        move.b  #'#',(a1)+
        move.w  d6,d0
        addq.w  #1,d0
        cmpi.w  #10,d0
        blo.s   .u
        move.b  #'1',(a1)+
        moveq   #0,d0
.u:     addi.b  #'0',d0
        move.b  d0,(a1)+
        cmpi.w  #9,d6
        beq.s   .nm
        move.b  #' ',(a1)+
.nm:    move.b  #' ',(a1)+
        moveq   #6-1,d1
.n:     move.b  (a3)+,(a1)+
        dbra    d1,.n
        move.b  #' ',(a1)+
        bsr     fe_score                ; (a3)+ 3 bytes -> 7 characters at (a1)+
        clr.b   (a1)
        moveq   #6,d2                   ; yellow
        cmp.w   G_FERANK(a6),d6
        bne.s   .col
        moveq   #7,d2                   ; the new entry: white
.col:   move.w  d6,d1
        mulu.w  #FE_CY,d1
        addi.w  #64,d1
        moveq   #(56/2),d0              ; x 56 px
        moveq   #2,d3
        lea     G_FELINE(a6),a1
        bsr     fe_text
        addq.w  #1,d6
        cmpi.w  #HI_N,d6
        blo.s   .e
        rts

; fe_score - (a3)+ 3 base-100 bytes -> "ddd,ddd" at (a1)+ (7 characters):
; leading zeros as spaces, the comma only after a digit, "0" for 0
fe_score:
        movem.l d0-d3/a0,-(sp)
        subq.l  #6,sp
        movea.l sp,a0                   ; the 6 digits
        moveq   #3-1,d2
.b:     moveq   #0,d0
        move.b  (a3)+,d0
        divu.w  #10,d0
        move.b  d0,(a0)+
        swap    d0
        move.b  d0,(a0)+
        dbra    d2,.b
        movea.l sp,a0
        moveq   #0,d3                   ; a digit written yet
        moveq   #0,d2
.d:     cmpi.w  #3,d2
        bne.s   .nc
        moveq   #' ',d1
        tst.w   d3
        beq.s   .pc
        moveq   #',',d1
.pc:    move.b  d1,(a1)+
.nc:    move.b  (a0)+,d0
        tst.w   d3
        bne.s   .dg
        tst.b   d0
        bne.s   .st
        cmpi.w  #5,d2
        beq.s   .st
        move.b  #' ',(a1)+
        bra.s   .nx
.st:    moveq   #1,d3
.dg:    addi.b  #'0',d0
        move.b  d0,(a1)+
.nx:    addq.w  #1,d2
        cmpi.w  #6,d2
        blo.s   .d
        addq.l  #6,sp
        movem.l (sp)+,d0-d3/a0
        rts

;-----------------------------------------------------------------------------
; fe_entry - "PLAYER 1 / ENTER YOUR NAME." and the letter grid (A-Z, RUB, END):
; arrows / joystick move, SPACE / fire picks; typed letters go in directly,
; ENTER ends. 6 letters at most.
;-----------------------------------------------------------------------------
fe_entry:
        bsr     fe_cls
        lea     SCREEN,a2
        lea     txt_ent(pc),a1
        bsr     fe_strs
        lea     G_FEN(a6),a0
        moveq   #6-1,d0
.sp:    move.b  #' ',(a0)+
        dbra    d0,.sp
        clr.w   G_FENL(a6)
        clr.w   G_FECUR(a6)
        lea     G_FELINE(a6),a1         ; "SCORE  sss,sss"
        lea     txt_sc(pc),a0
.cs:    move.b  (a0)+,(a1)+
        bne.s   .cs
        subq.l  #1,a1
        lea     G_MB+M_SCORE+1(a6),a3
        bsr     fe_score
        clr.b   (a1)
        lea     G_FELINE(a6),a1
        moveq   #(72/2),d0
        move.w  #224,d1
        moveq   #5,d2                   ; cyan
        moveq   #2,d3
        bsr     fe_text
        bsr     fe_grid
        bsr     fe_name
        bsr     fe_release
        move.w  #3000,G_FETO(a6)        ; (60 s, then as END)
.loop:  bsr     fe_frame                ; d0 = 1 press, d1 = typed key, d2 = KEYROW edges
        tst.w   G_QUIT(a6)
        bne     .o
        tst.w   d0
        beq.s   .loop
        tst.w   d1
        bmi.s   .pad
        cmpi.b  #10,d1                  ; ENTER: done
        beq     .o
        cmpi.b  #'A',d1
        blo.s   .loop
        cmpi.b  #'Z',d1
        bhi.s   .loop
        bsr     fe_add
        bra.s   .loop
.pad:   move.w  G_FECUR(a6),d3
        btst    #KRB_LEFT,d2
        beq.s   .nl
        subq.w  #1,d3
        bpl.s   .mv
        moveq   #27,d3
        bra.s   .mv
.nl:    btst    #KRB_RIGHT,d2
        beq.s   .nr
        addq.w  #1,d3
        cmpi.w  #28,d3
        blo.s   .mv
        moveq   #0,d3
        bra.s   .mv
.nr:    btst    #KRB_UP,d2
        beq.s   .nu
        subq.w  #7,d3
        bpl.s   .mv
        addi.w  #28,d3
        bra.s   .mv
.nu:    btst    #KRB_DOWN,d2
        beq.s   .nd
        addq.w  #7,d3
        cmpi.w  #28,d3
        blo.s   .mv
        subi.w  #28,d3
        bra.s   .mv
.nd:    btst    #KRB_SPACE,d2
        beq     .loop
        cmpi.w  #26,d3                  ; RUB
        bne.s   .nrub
        tst.w   G_FENL(a6)
        beq     .loop
        subq.w  #1,G_FENL(a6)
        move.w  G_FENL(a6),d0
        lea     G_FEN(a6),a0
        move.b  #' ',0(a0,d0.w)
        bsr     fe_name
        bra     .loop
.nrub:  cmpi.w  #27,d3                  ; END
        beq.s   .o
        move.w  d3,d1
        addi.b  #'A',d1
        bsr     fe_add
        bra     .loop
.mv:    move.w  d3,G_FECUR(a6)
        bsr     fe_grid
        bra     .loop
.o:     rts

fe_add: cmpi.w  #6,G_FENL(a6)
        bhs.s   .o
        move.w  G_FENL(a6),d0
        lea     G_FEN(a6),a0
        move.b  d1,0(a0,d0.w)
        addq.w  #1,G_FENL(a6)
        bsr     fe_name
.o:     rts

; fe_grid - the letter grid, the cursor's item yellow
fe_grid:
        lea     SCREEN,a2
        moveq   #0,d6                   ; item 0-27
.i:     lea     G_FELINE(a6),a1
        cmpi.w  #26,d6
        blo.s   .let
        lea     txt_rub(pc),a0
        beq.s   .cp
        lea     txt_end(pc),a0
.cp:    move.b  (a0)+,(a1)+
        bne.s   .cp
        bra.s   .dr
.let:   move.b  d6,d0
        addi.b  #'A',d0
        move.b  d0,(a1)+
        clr.b   (a1)
.dr:    moveq   #0,d0
        move.w  d6,d0
        divu.w  #7,d0                   ; row, col
        move.w  d0,d1
        mulu.w  #24,d1
        addi.w  #96,d1                  ; lines 96, 120, 144, 168
        swap    d0
        mulu.w  #24/2,d0                ; 3 characters (24 px) a column
        addi.w  #40/2,d0                ; x 40 px
        cmpi.w  #27,d6                  ; (END: a space after RUB)
        bne.s   .x
        addq.w  #8/2,d0
.x:
        moveq   #7,d2                   ; white
        cmp.w   G_FECUR(a6),d6
        bne.s   .w
        moveq   #6,d2                   ; the cursor: yellow
.w:     moveq   #2,d3
        lea     G_FELINE(a6),a1
        bsr     fe_text
        addq.w  #1,d6
        cmpi.w  #28,d6
        blo.s   .i
        rts

; fe_name - the name so far, "-" for the places left ("------")
fe_name:
        lea     SCREEN,a2
        lea     G_FELINE(a6),a1
        lea     G_FEN(a6),a0
        moveq   #0,d0
.c:     move.b  (a0)+,d1
        cmp.w   G_FENL(a6),d0
        blo.s   .p
        moveq   #'-',d1
.p:     move.b  d1,(a1)+
        addq.w  #1,d0
        cmpi.w  #6,d0
        blo.s   .c
        clr.b   (a1)
        lea     G_FELINE(a6),a1
        moveq   #(104/2),d0
        move.w  #198,d1
        moveq   #7,d2
        moveq   #2,d3
        bra     fe_text

;-----------------------------------------------------------------------------
; Input and time
;-----------------------------------------------------------------------------
; fe_frame - wait for the next tick, then the input: d0.w = 1 when something
; was pressed: a typed key (d1.w = its code, upper case) or a new KEYROW row 1
; press (d1.w = -1, d2.w = the new bits); ESC sets G_QUIT
fe_frame:
fe_tick:                                ; (global: a test hook)
        addq.l  #1,G_FETICK(a6)
        moveq   #1,d0
        bsr     fe_wait
        subq.w  #1,G_FETO(a6)           ; the screen's time up: as ENTER
        bne.s   .t
        moveq   #10,d1
        moveq   #1,d0
        rts
.t:
        bsr     fe_getkey               ; a typed key?
        tst.l   d0
        bne.s   .pad
        cmpi.b  #K_ESC,d1
        bne.s   .k
        move.w  #1,G_QUIT(a6)
        moveq   #1,d0
        rts
.k:     cmpi.b  #$80,d1                 ; (QDOS: the cursor keys' codes; the KEYROW
        bhs.s   .pad                    ;  input reads them)
        cmpi.b  #' ',d1
        beq.s   .pad
        cmpi.b  #'a',d1
        blo.s   .up
        subi.b  #$20,d1
.up:    andi.w  #$FF,d1
        moveq   #1,d0
        rts
.pad:   FARCALL read_arrow_row
        move.w  G_FEPAD(a6),d2
        move.w  d0,G_FEPAD(a6)
        not.w   d2
        and.w   d0,d2                   ; the new presses
        andi.w  #(1<<KRB_LEFT)|(1<<KRB_UP)|(1<<KRB_RIGHT)|(1<<KRB_SPACE)|(1<<KRB_DOWN),d2
        moveq   #-1,d1
        moveq   #0,d0
        tst.w   d2
        beq.s   .o
        moveq   #1,d0
.o:     rts

; fe_release - the held KEYROW keys count as already pressed (no stray press)
fe_release:
        FARCALL read_arrow_row
        move.w  d0,G_FEPAD(a6)
.d:     bsr     fe_getkey               ; and the typed keys dropped
        tst.l   d0
        beq.s   .d
        rts

; fe_getkey - the next typed key: d1.w (d0 = 0), or d0 = -1 (as read_input)
fe_getkey:
        tst.w   G_TKON(a6)
        beq.s   .qd
        movem.l d2-d6/a0,-(sp)
        FARCALL tk_keys
        FARCALL tk_getkey
        movem.l (sp)+,d2-d6/a0
        rts
.qd:    move.l  G_CON(a6),d0
        beq.s   .none
        movem.l d2-d3/a0-a1,-(sp)
        movea.l d0,a0
        moveq   #IO_FBYTE,d0
        moveq   #0,d3
        trap    #3
        movem.l (sp)+,d2-d3/a0-a1
        tst.l   d0
        bne.s   .none
        andi.w  #$FF,d1
        rts
.none:  moveq   #-1,d0
        rts

; fe_wait - d0.w ticks (the frame clock: spin_to, as the game's frames)
fe_wait:
        move.w  #$FF,G_KRPREV(a6)       ; (the game's ENTER / \ : a key held from a
        movem.l d1-d5/a0,-(sp)          ;  screen counts once released)
        move.w  d0,d3
        bra.s   .n
.l:     addq.l  #1,G_FETICK(a6)         ; (the screens' ticks: a test clock)
        FARCALL get_tick
        move.w  d0,d1
        addq.w  #1,d1
        move.l  G_K(a6),d4
        add.l   d4,d4
        bne.s   .s
        move.l  #100000,d4
.s:     FARCALL spin_to
.n:     dbra    d3,.l
        movem.l (sp)+,d1-d5/a0
        rts

;-----------------------------------------------------------------------------
; Text: the panel's font (4 x 7 Mode 8 pixels a glyph, white), coloured and at
; scale 1 or 2 (8 x 14). fe_text - a1 = ASCII, 0 ends; d0.w = x in bytes
; (even: 4 pixels a word), d1.w = line, d2.w = colour 0-7, d3.w = scale, a2 =
; the screen. Characters the font lacks show as spaces. A poll a character.
;-----------------------------------------------------------------------------
fe_text:
        movem.l d0-d7/a0-a5,-(sp)
        mulu.w  #BPL,d1
        add.w   d0,d1
        lea     0(a2,d1.l),a3           ; the first glyph's place
        move.w  d2,d7                   ; colour
.fnt:   lea     .fnt(pc),a5             ; the font (proto_font.inc: out of a pc
        adda.l  #font-.fnt,a5           ;  displacement's reach)
.ch:    moveq   #0,d0
        move.b  (a1)+,d0
        beq     .x
        bsr     fe_glyph                ; d0 = the glyph code
        lsl.w   #4,d0
        lea     0(a5,d0.w),a0
        movea.l a3,a4
        moveq   #7-1,d6                 ; 7 rows
.row:   move.w  (a0)+,d0
        bsr     fe_mask                 ; d1 = the 4 pixels' mask (bit 3 = left)
        cmpi.w  #2,d3
        beq.s   .two
        bsr     fe_word                 ; d0 = the coloured word
        move.w  d0,(a4)
        lea     BPL(a4),a4
        bra.s   .nr
.two:   move.w  d1,d4
        lsr.w   #2,d1                   ; left 2 pixels doubled
        bsr     fe_dbl
        bsr     fe_word
        move.w  d0,(a4)
        move.w  d0,BPL(a4)
        move.w  d4,d1
        andi.w  #3,d1                   ; right 2
        bsr     fe_dbl
        bsr     fe_word
        move.w  d0,2(a4)
        move.w  d0,BPL+2(a4)
        lea     2*BPL(a4),a4
.nr:    dbra    d6,.row
        addq.l  #2,a3
        cmpi.w  #2,d3
        bne.s   .p
        addq.l  #2,a3
.p:     bsr     fe_poll
        bra     .ch
.x:     movem.l (sp)+,d0-d7/a0-a5
        rts

; fe_mask - d0.w a font word (white) -> d1.w its 4 pixels (bit 3 = the left one)
fe_mask:
        moveq   #0,d1
        moveq   #4-1,d2
.b:     add.w   d1,d1
        btst    #15,d0                  ; (the green bit of each pixel: 15, 13, 11, 9)
        beq.s   .z
        addq.w  #1,d1
.z:     lsl.w   #2,d0
        dbra    d2,.b
        rts

; fe_dbl - d1.w 2 pixels (bit 1 = left) -> 4 (each twice)
fe_dbl: moveq   #0,d0
        btst    #1,d1
        beq.s   .r
        moveq   #%1100,d0
.r:     btst    #0,d1
        beq.s   .o
        ori.w   #%0011,d0
.o:     move.w  d0,d1
        rts

; fe_word - d1.w 4 pixels (bit 3 = left), colour d7 -> d0.w the Mode 8 word
; (high byte: green and flash, low byte: red and blue, two bits a pixel)
fe_word:
        movem.l d1-d2,-(sp)
        moveq   #0,d0
        moveq   #4-1,d2
.p:     lsl.w   #2,d0                   ; (the pixel's two bits in each byte)
        btst    #3,d1
        beq.s   .n
        btst    #2,d7                   ; green
        beq.s   .g
        bset    #9,d0
.g:     btst    #1,d7                   ; red
        beq.s   .r
        bset    #1,d0
.r:     btst    #0,d7                   ; blue
        beq.s   .n
        bset    #0,d0
.n:     add.w   d1,d1
        dbra    d2,.p
        movem.l (sp)+,d1-d2
        rts

; fe_glyph - d0.b ASCII -> d0.w the font's glyph (FONT_ORDER), a space if none
fe_glyph:
        cmpi.b  #':',d0
        bne.s   .np
        moveq   #CH_COLON,d0
        rts
.np:    cmpi.b  #'+',d0
        bne.s   .nq
        moveq   #CH_PLUS,d0
        rts
.nq:
        cmpi.b  #'0',d0
        blo.s   .s
        cmpi.b  #'9',d0
        bhi.s   .a
        subi.b  #'0',d0
        rts
.a:     cmpi.b  #'A',d0
        blo.s   .s
        cmpi.b  #'Z',d0
        bhi.s   .s
        subi.b  #'A'-CH_A,d0
        rts
.s:     cmpi.b  #'.',d0
        bne.s   .1
        moveq   #CH_DOT,d0
        rts
.1:     cmpi.b  #'-',d0
        bne.s   .2
        moveq   #CH_DASH,d0
        rts
.2:     cmpi.b  #',',d0
        bne.s   .3
        moveq   #CH_COMMA,d0
        rts
.3:     cmpi.b  #'#',d0
        bne.s   .4
        moveq   #CH_HASH,d0
        rts
.4:     cmpi.b  #'!',d0
        bne.s   .5
        moveq   #CH_EXCL,d0
        rts
.5:     cmpi.b  #'/',d0
        bne.s   .6
        moveq   #CH_SLASH,d0
        rts
.6:     cmpi.b  #$5C,d0                 ; (a backslash)
        bne.s   .7
        moveq   #CH_BSL,d0
        rts
.7:     moveq   #CH_SPC,d0
        rts

; fe_strs - a list: (word x px, word line, byte colour, byte scale, ASCII, 0,
; even) ..., word -1. a2 = the screen.
fe_strs:
        movem.l d0-d3/a1,-(sp)
.l:     move.w  (a1)+,d0
        bmi.s   .o
        lsr.w   #1,d0                   ; px -> bytes
        move.w  (a1)+,d1
        moveq   #0,d2
        move.b  (a1)+,d2
        moveq   #0,d3
        move.b  (a1)+,d3
        bsr     fe_text
.e:     tst.b   (a1)+
        bne.s   .e
        move.l  a1,d0
        addq.l  #1,d0
        andi.w  #$FFFE,d0
        movea.l d0,a1
        bra.s   .l
.o:     movem.l (sp)+,d0-d3/a1
        rts

; the texts (x px, multiple of 4; line; colour; scale; ASCII)
txt_out:                                ; the box (lines 100-163, x 64-191)
        dc.w    104,108
        dc.b    5,2,'OUT OF',0
        even
        dc.w    112,124
        dc.b    5,2,'TIME',0
        even
        dc.w    92,144
        dc.b    7,2,'GAME OVER',0
        even
        dc.w    -1
txt_hi:
        dc.w    72,12
        dc.b    5,2,'MARBLE MADNESS',0
        even
        dc.w    80,36
        dc.b    7,2,'HIGH ROLLERS',0
        even
        dc.w    40,236
        dc.b    7,2,'PRESS SPACE OR FIRE',0
        even
        dc.w    -1
txt_ent:
        dc.w    96,24
        dc.b    5,2,'PLAYER 1',0
        even
        dc.w    64,48
        dc.b    7,2,'ENTER YOUR NAME.',0
        even
        dc.w    -1
txt_start:                              ; (below the logo: lines 24-83)
        dc.w    32,112
        dc.b    6,2,'ARROW KEYS',0
        even
        dc.w    128,112
        dc.b    7,2,'MOVE',0
        even
        dc.w    32,132
        dc.b    6,2,'SPACE',0
        even
        dc.w    128,132
        dc.b    7,2,'SPEED UP',0
        even
        dc.w    32,152
        dc.b    6,2,'ENTER',0
        even
        dc.w    128,152
        dc.b    7,2,'PAUSE',0
        even
        dc.w    32,172
        dc.b    6,2,$5C,0               ; (a backslash)
        even
        dc.w    128,172
        dc.b    7,2,'SOUND ON/OFF',0
        even
        dc.w    32,192
        dc.b    6,2,'ESC',0
        even
        dc.w    128,192
        dc.b    7,2,'QUIT',0
        even
        dc.w    48,228
        dc.b    7,2,'PRESS SPACE TO START',0
        even
        dc.w    -1
txt_sc: dc.b    'SCORE ',0
        even
txt_rub:
        dc.b    'RUB',0
        even
txt_end:
        dc.b    'END',0
        even

;-----------------------------------------------------------------------------
; The race boxes (with play stopped; no frame time in play):
; fe_intro - a race's "TIME TO FINISH / <RACE> RACE: nn" box once its screen
; shows (G_INTRO, set by goto_race and at the start), the time counting up in
; 5 s steps to the race's time; then the logic clock starts again from now
; fe_bonus - after the goal, once the time bonus is given: "TIME /
; BONUS / s,s00" for 3.3 s; d0 = 1 when shown (0: demo, benchmark, G_TNOBOX)
;-----------------------------------------------------------------------------
fe_skip:                                ; d0 = 1 when the boxes are off
        moveq   #1,d0
        ifeq    RELB
        tst.w   G_DEMO(a6)
        bne.s   .o
        tst.w   G_BENCH(a6)
        bne.s   .o
        tst.w   G_TNOBOX(a6)
        bne.s   .o
        endc
        moveq   #0,d0
.o:     rts

fe_intro:
        movem.l d0-d7/a0-a5,-(sp)
        bsr     fe_skip
        tst.w   d0
        bne     .x
        ; the box with the time still to add shown 80 logic steps, then every
        ; 16 steps that - 5 and the race timer + 5, to 0; the race starts 58
        ; steps later. In 50 Hz ticks: 67, 13.33 (13, 13, 14), 48. The timer
        ; rises in the HUD's TIME (or the panel's).
        moveq   #0,d6
        move.b  G_MB+M_TIME+1(a6),d6    ; d6 = the race's time with what was carried
        movea.l G_RBUF(a6),a0
        move.w  PH_TIME(a0),d7          ; d7 = still to add: this race's own (at most
        cmp.w   d6,d7                   ;  what the 99 cap let in)
        bls.s   .s
        move.w  d6,d7
.s:     lea     SCREEN,a2
        bsr     fe_ibox
        tst.w   G_DUAL(a6)
        beq.s   .c0
        lea     SCREEN1,a2
        bsr     fe_ibox
.c0:    bsr     .show
        moveq   #67,d0                  ; 80 logic steps
        bsr     fe_wait
        moveq   #0,d5                   ; (the steps' 13 / 13 / 14 ticks)
.c:     tst.w   d7
        beq.s   .h
        subq.w  #5,d7                   ; a step
        bcc.s   .p
        moveq   #0,d7
.p:     bsr     .show
        tst.w   d7
        beq.s   .h
        moveq   #13,d0
        addq.w  #1,d5
        cmpi.w  #3,d5
        blo.s   .w
        moveq   #0,d5
        moveq   #14,d0
.w:     bsr     fe_wait
        bra.s   .c
.h:     clr.w   G_HTOVR(a6)             ; (the timer's own again: the same value)
        moveq   #48,d0                  ; 58 logic steps to the start
        bsr     fe_wait
        bsr     fe_introd
        FARCALL logic_resync            ; (the box's time is not game time)
        FARCALL get_tick
        move.w  d0,G_FT0(a6)
.x:     movem.l (sp)+,d0-d7/a0-a5
        rts

; (fe_intro's) the time still to add in the box, the timer (the time less it)
; in the top band
.show:  move.w  d7,d0
        bsr     fe_inum
        move.w  d6,d0
        sub.w   d7,d0
        bra     fe_itime

fe_introd:                              ; (the box is complete: a test hook)
        rts

; fe_itime - d0.w (0-99), the race timer as it rises during the TIME TO FINISH
; count: shown at once in the top band's TIME on both screens (the HUD's
; timer at the top; or the debug panel's), G_HTOVR until the count ends
fe_itime:
        move.w  d0,G_HTOVR(a6)
        bset    #7,G_HTOVR(a6)
        FARCALL top_now
        rts

; fe_ibox - the box on the screen at a2: black over x 24-231, the playfield's
; lines 56-91; "TIME TO FINISH" (yellow), "<RACE> RACE:" (+ from Intermediate
; on; cyan); the number's frame (blue round black); Silly's second line
fe_ibox:
        move.w  G_PTOP(a6),d5
        moveq   #24/2,d0
        move.w  d5,d1
        addi.w  #56,d1
        moveq   #208/2,d2
        moveq   #36,d3
        moveq   #0,d4
        bsr     fe_fill
        moveq   #196/2,d0               ; the number's frame
        move.w  d5,d1
        addi.w  #71,d1
        moveq   #32/2,d2
        moveq   #20,d3
        move.w  #$0055,d4               ; (blue)
        bsr     fe_fill
        moveq   #200/2,d0
        move.w  d5,d1
        addi.w  #73,d1
        moveq   #24/2,d2
        moveq   #16,d3
        moveq   #0,d4
        bsr     fe_fill
        lea     txt_tfin(pc),a1
        moveq   #64/2,d0
        move.w  d5,d1
        addi.w  #57,d1
        moveq   #6,d2
        moveq   #2,d3
        bsr     fe_text
        move.w  G_RACE(a6),d0           ; "<RACE> RACE:" (+ from Intermediate on)
        add.w   d0,d0
        lea     txt_rnames(pc),a1
        adda.w  0(a1,d0.w),a1
        moveq   #32/2,d0
        move.w  d5,d1
        addi.w  #74,d1
        moveq   #5,d2
        moveq   #2,d3
        bsr     fe_text
        cmpi.w  #4,G_RACE(a6)           ; Silly: "EVERYTHING YOU KNOW IS WRONG"
        bne.s   .o
        moveq   #8/2,d0
        move.w  d5,d1
        addi.w  #150,d1
        moveq   #240/2,d2
        moveq   #18,d3
        moveq   #0,d4
        bsr     fe_fill
        lea     txt_silly(pc),a1
        moveq   #16/2,d0
        move.w  d5,d1
        addi.w  #152,d1
        moveq   #5,d2
        moveq   #2,d3
        bsr     fe_text
.o:     rts

; fe_inum - d0.w (0-99) as 2 digits in the number's frame, on the screen(s)
fe_inum:
        movem.l d0-d3/a1-a2,-(sp)
        lea     G_FELINE(a6),a1
        andi.l  #$FF,d0
        divu.w  #10,d0
        addi.b  #'0',d0
        move.b  d0,(a1)+
        swap    d0
        addi.b  #'0',d0
        move.b  d0,(a1)+
        clr.b   (a1)
        lea     SCREEN,a2
        bsr.s   .one
        tst.w   G_DUAL(a6)
        beq.s   .o
        lea     SCREEN1,a2
        bsr.s   .one
.o:     movem.l (sp)+,d0-d3/a1-a2
        rts
.one:   lea     G_FELINE(a6),a1
        moveq   #204/2,d0
        move.w  G_PTOP(a6),d1
        addi.w  #74,d1
        moveq   #7,d2
        moveq   #2,d3
        bra     fe_text

fe_bonus:
        movem.l d1-d7/a0-a5,-(sp)
        bsr     fe_skip
        tst.w   d0
        bne.s   .no
        lea     SCREEN,a2
        bsr.s   fe_bbox
        tst.w   G_DUAL(a6)
        beq.s   .w
        lea     SCREEN1,a2
        bsr.s   fe_bbox
.w:     FARCALL top_now                 ; (the score with the bonus, in the top band)
        bsr     fe_bonusd
        move.w  #167,d0                 ; 3.3 s (200 logic steps)
        bsr     fe_wait
        moveq   #1,d0
        bra.s   .o
.no:    moveq   #0,d0
.o:     movem.l (sp)+,d1-d7/a0-a5
        rts

fe_bonusd:                              ; (the box is up: a test hook)
        rts

; fe_bbox - the TIME BONUS box on the screen at a2: black over x 24-119, the
; playfield's lines 56-111; "TIME", "BONUS", the seconds left x 100 (cyan)
fe_bbox:
        move.w  G_PTOP(a6),d5
        moveq   #24/2,d0
        move.w  d5,d1
        addi.w  #56,d1
        moveq   #96/2,d2
        moveq   #56,d3
        moveq   #0,d4
        bsr     fe_fill
        lea     txt_time2(pc),a1
        moveq   #56/2,d0
        move.w  d5,d1
        addi.w  #60,d1
        moveq   #5,d2
        moveq   #2,d3
        bsr     fe_text
        lea     txt_bonus(pc),a1
        moveq   #52/2,d0
        move.w  d5,d1
        addi.w  #76,d1
        moveq   #5,d2
        moveq   #2,d3
        bsr     fe_text
        lea     G_FELINE+8(a6),a3       ; the amount: 3 base-100 bytes 0, s, 0
        clr.b   (a3)
        move.b  G_MB+M_TIME+1(a6),1(a3)
        clr.b   2(a3)
        lea     G_FELINE(a6),a1
        bsr     fe_score                ; (7 characters)
        clr.b   (a1)
        lea     G_FELINE(a6),a1
        moveq   #36/2,d0
        move.w  d5,d1
        addi.w  #92,d1
        moveq   #5,d2
        moveq   #2,d3
        bra     fe_text

; fe_fill - d4.w (a Mode 8 word) over d2.w bytes (even) x d3.w lines at x d0.w
; bytes, line d1.w of the screen at a2
fe_fill:
        movem.l d0-d3/a0,-(sp)
        mulu.w  #BPL,d1
        add.w   d0,d1
        lea     0(a2,d1.l),a0
        lsr.w   #1,d2
        subq.w  #1,d2
        subq.w  #1,d3
.r:     move.w  d2,d0
        movea.l a0,a1
.c:     move.w  d4,(a1)+
        dbra    d0,.c
        lea     BPL(a0),a0
        dbra    d3,.r
        bsr     fe_poll
        movem.l (sp)+,d0-d3/a0
        rts

;-----------------------------------------------------------------------------
; fe_ending - the ending after Ultimate, with play stopped: CONGRATULATIONS,
; the bonus (20 + the seconds left - the deaths) x 1,000 added 200 points a
; logic step (TOTAL counting down, FINAL SCORE up), CONGRATULATIONS and FINAL
; SCORE in a colour cycle (a step every 4 logic steps), 9-32 balls bouncing
; over and behind the text; 800 logic steps, by the clock (6 for each 5
; ticks). ESC
; quits (G_QUIT). Off in demo, benchmark and G_TNOBOX runs (fe_skip).
; Memory: the race area (free after Ultimate; a new game loads Practice): the
; screen without the balls (EN_B, 32 KB), the balls' pictures pre-shifted, the
; balls and the rectangles each screen last drew them in.
;-----------------------------------------------------------------------------
EN_B            equ     -$8000          ; (a5 = the race area + 32 KB) the screen copy
EN_V            equ     0               ; the variables:
EN_OLD          equ     $20             ; per screen 32 x (offset.w, words.w)
EN_BALL         equ     EN_OLD+2*32*4   ; 32 balls x 16 B
EN_PIC          equ     EN_BALL+32*16   ; 12 looks x 4 shifts x 16 rows x 5 (op, data)
EN_LOOK         equ     4*16*5*4        ; a look's 4 shifts: 1,280 B
EN_SHIFT        equ     16*5*4          ; a shift: 320 B
EN_GLY          equ     EN_PIC+12*EN_LOOK       ; "0123456789,- " at scale 2, as masks:
                                        ;  13 x 14 lines x 4 B
EN_W            equ     EN_GLY+13*14*4  ; CONGRATULATIONS' and FINAL SCORE's lines as
                                        ;  masks (2 x 14 lines x 128 B: en_recol)
EN_NZ           equ     EN_W+2*14*BPL   ; the screen copy's black pixels (32 KB:
                                        ;  behind balls show only there)
EV_NOLD         equ     0               ;  2 words: rectangles kept, per screen
EV_SEED         equ     4
EV_N            equ     6               ;  the balls
EV_DIRTY        equ     8               ;  2 words: bands to copy, per screen
EV_CYC          equ     12              ;  the colour cycle's step
EV_NESF         equ     14              ;  logic steps since the start
EV_CNT          equ     16              ;  the bonus still to add (hundreds)
EV_ACC          equ     18              ;  ticks x 6 not yet a logic step
EV_TLAST        equ     20
EV_N_           equ     22
BX              equ     0               ; a ball: x, y (8.8), their speeds, their
BY              equ     2               ; directions (1 +, 0 -), its picture (the
BVX             equ     4               ; look's offset), 1 = behind the text
BVY             equ     6
BDX             equ     8
BDY             equ     10
BPIC            equ     12
BBEH            equ     14
EN_LINES        equ     14              ; the text's height (scale 2)
EN_FIGX         equ     184/2           ; the figures' x (bytes): columns 23-29
L_TITLE         equ     20
L_SEC           equ     138
L_DIED          equ     158
L_TOT           equ     178
L_FIN           equ     206

fe_ending:
        movem.l d0-d7/a0-a5,-(sp)
        bsr     fe_skip
        tst.w   d0
        bne     .x
        ifne    MUS_ON
        FARCALL mus_silence
        endc
        bsr     fe_cls
        movea.l G_RBUF(a6),a5           ; a5: the race area + 32 KB (16-bit offsets
        adda.l  #$8000,a5               ;  both ways)
        lea     EN_B(a5),a2
        bsr     fe_clr                  ; the screen without the balls: black
        lea     EN_V(a5),a0
        moveq   #EV_N_/2-1,d0
.cv:    clr.w   (a0)+
        dbra    d0,.cv
        FARCALL get_tick
        ori.w   #1,d0
        move.w  d0,EN_V+EV_SEED(a5)
        lea     EN_B(a5),a2
        lea     txt_endg(pc),a1
        bsr     fe_strs
        bsr     en_gly
        bsr     en_wmask
        move.w  G_MB+M_TIME(a6),d6      ; the seconds left
        move.w  G_MB+M_DEATHS(a6),d5    ; the deaths (at most 20)
        moveq   #0,d4
        moveq   #20,d0
        move.w  #118,d1
        bsr     en_k                    ; 20,000
        move.w  d6,d0
        move.w  #L_SEC,d1
        bsr     en_k                    ; seconds,000
        moveq   #1,d4
        move.w  d5,d0
        move.w  #L_DIED,d1
        bsr     en_k                    ; -deaths,000
        move.w  d6,d0
        moveq   #16/2,d3
        move.w  #L_SEC,d1
        bsr     en_n3                   ; "nn SEC LEFT"
        move.w  d5,d0
        moveq   #32/2,d3
        move.w  #L_DIED,d1
        bsr     en_n3                   ; "DIED nn TIMES"
        moveq   #20,d0                  ; the count: (20 - deaths + seconds) x 10
        sub.w   d5,d0
        add.w   d6,d0
        mulu.w  #10,d0
        move.w  d0,EN_V+EV_CNT(a5)
        bsr     en_figs
        bsr     en_nzall
        bsr     en_build
        bsr     en_init
        lea     SCREEN,a1               ; both screens = it
        bsr     en_all
        tst.w   G_DUAL(a6)
        beq.s   .t
        lea     SCREEN1,a1
        bsr     en_all
.t:     FARCALL get_tick
        move.w  d0,EN_V+EV_TLAST(a5)
.f:     bsr     en_steps
        moveq   #0,d7                   ; the screen to draw: the one not shown
        tst.w   G_DUAL(a6)
        beq.s   .s
        move.w  G_SHOWN(a6),d7
        eori.w  #1,d7
.s:     bsr     en_screen
        move.w  d7,d0
        FARCALL flip_to
        FARCALL read_arrow_row
        btst    #KRB_ESC,d0
        bne.s   .esc
        bsr     fe_getkey
        tst.l   d0
        bne.s   .nk
        cmpi.b  #K_ESC,d1
        beq.s   .esc
.nk:    cmpi.w  #800,EN_V+EV_NESF(a5)
        bhs.s   .x
        bsr     fe_etick
        bra.s   .f
.esc:   move.w  #1,G_QUIT(a6)
.x:     movem.l (sp)+,d0-d7/a0-a5
        rts

fe_etick:                               ; (a frame's wait: a test hook)
        moveq   #1,d0
        bra     fe_wait

; en_steps - the logic steps due by the clock: each the count (200 points) and
; the balls' moves; then the colour cycle's step and the figures, if changed
en_steps:
        FARCALL get_tick
        move.w  d0,d1
        sub.w   EN_V+EV_TLAST(a5),d1
        move.w  d0,EN_V+EV_TLAST(a5)
        mulu.w  #6,d1
        add.w   EN_V+EV_ACC(a5),d1
        divu.w  #5,d1
        swap    d1
        move.w  d1,EN_V+EV_ACC(a5)
        swap    d1
        move.w  d1,d7
        cmpi.w  #12,d7                  ; (a stall: logic time lost, as the game's cap)
        bls.s   .c
        moveq   #12,d7
.c:     moveq   #0,d6                   ; d6: the figures changed
        bra.s   .n
.l:     addq.w  #1,EN_V+EV_NESF(a5)
        tst.w   EN_V+EV_CNT(a5)
        beq.s   .m
        subq.w  #2,EN_V+EV_CNT(a5)
        lea     G_MB(a6),a4
        moveq   #2,d0
        moveq   #1,d1
        FARCALL add_score               ; +200
        moveq   #1,d6
.m:     bsr     en_move
        bsr     fe_poll
.n:     dbra    d7,.l
        move.w  EN_V+EV_NESF(a5),d0
        lsr.w   #2,d0
        andi.w  #7,d0
        cmp.w   EN_V+EV_CYC(a5),d0
        beq.s   .nc
        move.w  d0,EN_V+EV_CYC(a5)
        tst.w   d6
        beq.s   .rc
        bsr     en_figs                 ; (the final figure in the new colour)
        moveq   #0,d6
.rc:    bsr     en_recol
.nc:    tst.w   d6
        beq.s   .o
        bsr     en_figs
.o:     rts

; en_figs - TOTAL (what is still to add) and FINAL SCORE's figure into the
; screen without the balls; their bands to copy on both screens
en_figs:
        movem.l d0-d4/a3,-(sp)
        moveq   #0,d0
        move.w  EN_V+EV_CNT(a5),d0
        divu.w  #100,d0
        lea     G_FELINE+20(a6),a3
        move.b  d0,(a3)
        swap    d0
        move.b  d0,1(a3)
        clr.b   2(a3)
        move.w  #L_TOT,d1
        moveq   #6,d2
        moveq   #0,d4
        bsr     en_fig
        lea     G_MB+M_SCORE+1(a6),a3
        move.w  #L_FIN,d1
        bsr     en_cyc
        bsr     en_fig
        ori.w   #6,EN_V+EV_DIRTY(a5)
        ori.w   #6,EN_V+EV_DIRTY+2(a5)
        movem.l (sp)+,d0-d4/a3
        rts

; en_nzall - EN_NZ = the screen copy's black pixels (en_nz inverted), all of it
en_nzall:
        movem.l d0-d4/a0-a1,-(sp)
        lea     EN_B(a5),a0
        lea     EN_NZ(a5),a1
        move.w  #256-1,d3
.r:     moveq   #64-1,d4                ; (en_nz uses d2)
.w:     move.w  (a0)+,d0
        bne.s   .n
        move.w  #-1,(a1)+
        dbra    d4,.w
        bra.s   .p
.n:     bsr     en_nz
        not.w   d1
        move.w  d1,(a1)+
        dbra    d4,.w
.p:     bsr     fe_poll
        dbra    d3,.r
        movem.l (sp)+,d0-d4/a0-a1
        rts

; en_gly - EN_GLY: "0123456789,- " drawn white at scale 2 (in EN_NZ, not yet
; made), each glyph's 14 lines x 4 bytes kept: its pixels' mask
en_gly:
        movem.l d0-d4/a0-a2,-(sp)
        lea     EN_NZ(a5),a2
        lea     en_gtxt(pc),a1
        moveq   #0,d0
        moveq   #0,d1
        moveq   #7,d2
        moveq   #2,d3
        bsr     fe_text
        lea     EN_NZ(a5),a0
        lea     EN_GLY(a5),a1
        moveq   #13-1,d4
.g:     movea.l a0,a2
        moveq   #EN_LINES-1,d3
.l:     move.l  (a2),(a1)+
        lea     BPL(a2),a2
        dbra    d3,.l
        addq.l  #4,a0
        dbra    d4,.g
        movem.l (sp)+,d0-d4/a0-a2
        rts
en_gtxt:
        dc.b    '0123456789,- ',0
        even

; en_wmask - EN_W: bands 0 and 1 of the screen copy (the texts there) as masks
en_wmask:
        movem.l d0-d6/a0-a2,-(sp)
        lea     en_bands(pc),a2
        lea     EN_W(a5),a1
        moveq   #2-1,d6
.b:     move.w  4(a2),d0
        mulu.w  #BPL,d0
        add.w   (a2),d0
        lea     EN_B(a5),a0
        adda.l  d0,a0
        move.l  a1,-(sp)
        adda.w  (a2),a1
        moveq   #EN_LINES-1,d4
.r:     move.w  2(a2),d3
        lsr.w   #1,d3
        subq.w  #1,d3
        movem.l a0-a1,-(sp)
.w:     move.w  (a0)+,d0
        bsr     en_nz
        move.w  d1,(a1)+
        dbra    d3,.w
        movem.l (sp)+,a0-a1
        lea     BPL(a0),a0
        lea     BPL(a1),a1
        bsr     fe_poll
        dbra    d4,.r
        movea.l (sp)+,a1
        lea     EN_LINES*BPL(a1),a1
        addq.l  #6,a2
        dbra    d6,.b
        movem.l (sp)+,d0-d6/a0-a2
        rts

; en_cyc - d2.w = the colour cycle's colour now
en_cyc:
        move.l  a0,-(sp)
        lea     end_cycle(pc),a0
        move.w  EN_V+EV_CYC(a5),d2
        move.b  0(a0,d2.w),d2
        ext.w   d2
        movea.l (sp)+,a0
        rts

; en_k - d0.w thousands, line d1.w, d4.w 1 = negative: "ddd,000" (yellow)
en_k:
        movem.l d0/d2/a3,-(sp)
        ext.l   d0
        divu.w  #10,d0
        lea     G_FELINE+20(a6),a3
        move.b  d0,(a3)
        swap    d0
        mulu.w  #10,d0
        move.b  d0,1(a3)
        clr.b   2(a3)
        moveq   #6,d2
        bsr     en_fig
        movem.l (sp)+,d0/d2/a3
        rts

; en_fig - (a3) 3 base-100 bytes at the figures' x, line d1.w, colour d2.w;
; d4.w 1: a "-" before it (not before a 0). From the glyph masks: the screen
; copy (mask & colour), its black pixels (~mask), and on FINAL SCORE's line
; the band's mask too (en_recol)
en_fig:
        movem.l d0-d7/a0-a4,-(sp)
        lea     G_FELINE(a6),a1
        bsr     fe_score
        clr.b   (a1)
        tst.w   d4
        beq.s   .t
        lea     G_FELINE(a6),a1
.s:     cmpi.b  #' ',(a1)+
        beq.s   .s
        cmpi.b  #'0',-1(a1)
        bne.s   .m
        tst.b   (a1)
        beq.s   .t                      ; (a lone 0)
.m:     move.b  #'-',-2(a1)
.t:     lea     en_cw(pc),a0
        add.w   d2,d2
        move.w  0(a0,d2.w),d5           ; d5.l: the colour's word, twice
        move.w  d5,d6
        swap    d5
        move.w  d6,d5
        moveq   #0,d7
        cmpi.w  #L_FIN,d1
        seq     d7                      ; d7.b: FINAL SCORE's line
        mulu.w  #BPL,d1
        addi.w  #EN_FIGX,d1             ; d1: the first character's offset
        lea     G_FELINE(a6),a1
        moveq   #7-1,d6
.c:     move.b  (a1)+,d3
        moveq   #12,d0                  ; (a space)
        cmpi.b  #',',d3
        bne.s   .n1
        moveq   #10,d0
.n1:    cmpi.b  #'-',d3
        bne.s   .n2
        moveq   #11,d0
.n2:    subi.b  #'0',d3
        cmpi.b  #9,d3
        bhi.s   .g
        moveq   #0,d0
        move.b  d3,d0
.g:     mulu.w  #EN_LINES*4,d0
        lea     EN_GLY(a5),a2
        adda.w  d0,a2
        lea     EN_B(a5),a0
        adda.w  d1,a0
        lea     EN_NZ(a5),a3
        adda.w  d1,a3
        lea     EN_W+EN_LINES*BPL(a5),a4
        adda.w  d1,a4
        suba.w  #L_FIN*BPL,a4
        moveq   #EN_LINES-1,d4
.r:     move.l  (a2)+,d0
        move.l  d0,d2
        and.l   d5,d2
        move.l  d2,(a0)
        tst.b   d7
        beq.s   .nw
        move.l  d0,(a4)
.nw:    not.l   d0
        move.l  d0,(a3)
        lea     BPL(a0),a0
        lea     BPL(a3),a3
        lea     BPL(a4),a4
        dbra    d4,.r
        bsr     fe_poll
        addq.w  #4,d1
        dbra    d6,.c
        movem.l (sp)+,d0-d7/a0-a4
        rts

; en_n3 - d0.w (0-99) as 3 characters (" nn") at x d3.w bytes, line d1.w (yellow)
en_n3:
        movem.l d0-d3/a1-a2,-(sp)
        lea     G_FELINE(a6),a1
        move.b  #' ',(a1)
        ext.l   d0
        divu.w  #10,d0
        moveq   #' ',d2
        tst.w   d0
        beq.s   .z
        moveq   #'0',d2
        add.b   d0,d2
.z:     move.b  d2,1(a1)
        swap    d0
        addi.b  #'0',d0
        move.b  d0,2(a1)
        clr.b   3(a1)
        move.w  d3,d0
        moveq   #6,d2
        moveq   #2,d3
        lea     EN_B(a5),a2
        bsr     fe_text
        movem.l (sp)+,d0-d3/a1-a2
        rts

; en_nz - d0.w a Mode 8 word -> d1.w its pixels that are not black (both bits
; of a pixel in both bytes). Uses d2.
en_nz:
        move.w  d0,d1
        lsr.w   #8,d1
        or.b    d0,d1
        move.b  d1,d2
        lsr.b   #1,d2
        or.b    d2,d1
        andi.w  #$55,d1
        move.w  d1,d2
        add.w   d2,d2
        or.w    d2,d1
        move.w  d1,d2
        lsl.w   #8,d2
        or.w    d2,d1
        rts

; en_recol - CONGRATULATIONS' and FINAL SCORE's lines (bands 0, 1) in the cycle's
; colour now (their masks, EN_W, and the colour), in the screen copy; to copy on
; both screens
en_recol:
        movem.l d0-d6/a0-a2,-(sp)
        bsr     en_cyc
        add.w   d2,d2
        lea     en_cw(pc),a0
        move.w  0(a0,d2.w),d5           ; d5: the colour's word
        lea     en_bands(pc),a2
        lea     EN_W(a5),a1
        moveq   #2-1,d6
.b:     move.w  4(a2),d0
        mulu.w  #BPL,d0
        add.w   (a2),d0
        lea     EN_B(a5),a0
        adda.l  d0,a0
        move.l  a1,-(sp)
        adda.w  (a2),a1
        moveq   #EN_LINES-1,d4
.r:     move.w  2(a2),d3
        lsr.w   #1,d3
        subq.w  #1,d3
        movem.l a0-a1,-(sp)
.w:     move.w  (a1)+,d0
        and.w   d5,d0
        move.w  d0,(a0)+
        dbra    d3,.w
        movem.l (sp)+,a0-a1
        lea     BPL(a0),a0
        lea     BPL(a1),a1
        bsr     fe_poll
        dbra    d4,.r
        movea.l (sp)+,a1
        lea     EN_LINES*BPL(a1),a1
        addq.l  #6,a2
        dbra    d6,.b
        ori.w   #3,EN_V+EV_DIRTY(a5)
        ori.w   #3,EN_V+EV_DIRTY+2(a5)
        movem.l (sp)+,d0-d6/a0-a2
        rts

en_cw:  dc.w    $0000,$0055,$00AA,$00FF,$AA00,$AA55,$AAAA,$AAFF
en_bands:                               ; x bytes, width bytes, line
        dc.w    64/2,120/2,L_TITLE      ; 0 CONGRATULATIONS
        dc.w    72/2,168/2,L_FIN        ; 1 FINAL SCORE: and its figure
        dc.w    EN_FIGX,56/2,L_TOT      ; 2 TOTAL's figure

; en_move - a logic step of the balls' moves (x, then y)
en_move:
        movem.l d0/d7/a0/a3,-(sp)
        lea     EN_BALL(a5),a3
        move.w  EN_V+EV_N(a5),d7
        subq.w  #1,d7
.b:     movea.l a3,a0
        bsr     .ax
        lea     BY(a3),a0
        bsr     .ax
        lea     16(a3),a3
        dbra    d7,.b
        movem.l (sp)+,d0/d7/a0/a3
        rts
.ax:    move.w  (a0),d0                 ; (a0): the position, 4(a0) the speed,
        tst.w   8(a0)                   ; 8(a0) the direction
        beq.s   .ng
        add.w   4(a0),d0
        cmpi.w  #$F000,d0
        blo.s   .s
        move.w  #$F000,d0               ; at 240: stopped there, back
        clr.w   8(a0)
        bra.s   .s
.ng:    sub.w   4(a0),d0
        bcc.s   .s
        moveq   #0,d0                   ; below 0: at 0, back
        move.w  #1,8(a0)
.s:     move.w  d0,(a0)
        rts

; en_rnd - d0.w the next of a 16-bit xorshift. Uses d1.
en_rnd:
        move.w  EN_V+EV_SEED(a5),d0
        move.w  d0,d1
        lsl.w   #7,d1
        eor.w   d1,d0
        move.w  d0,d1
        lsr.w   #8,d1
        lsr.w   #1,d1
        eor.w   d1,d0
        move.w  d0,d1
        lsl.w   #8,d1
        eor.w   d1,d0
        move.w  d0,EN_V+EV_SEED(a5)
        rts

; en_init - the balls: (random & 31) | 8 + 1 of them; each at a random
; place (at most 240), x speed 2-5 + (random | 8) / 256, y speed 5 - that's
; whole part + ((0 - its fraction) | 8) / 256 (so about 6 - the x speed),
; random directions, a random colouring (from 0 1 2 0), the palette its
; index & 3, half behind the text
en_init:
        movem.l d0-d7/a0/a3,-(sp)
        bsr     en_rnd
        andi.w  #31,d0
        ori.w   #8,d0
        move.w  d0,d7
        addq.w  #1,d0
        move.w  d0,EN_V+EV_N(a5)
        lea     EN_BALL(a5),a3
        moveq   #0,d6                   ; the index
.b:     bsr     .pos
        move.w  d0,BX(a3)
        bsr     .pos
        move.w  d0,BY(a3)
        bsr     en_rnd
        ori.b   #8,d0
        andi.w  #$FF,d0
        move.w  d0,d2                   ; x fraction
        bsr     en_rnd
        andi.w  #3,d0
        addq.w  #2,d0
        move.w  d0,d3                   ; x whole
        lsl.w   #8,d0
        or.w    d2,d0
        move.w  d0,BVX(a3)
        moveq   #0,d0
        sub.b   d2,d0
        ori.b   #8,d0
        andi.w  #$FF,d0
        moveq   #5,d1
        sub.w   d3,d1
        lsl.w   #8,d1
        or.w    d1,d0
        move.w  d0,BVY(a3)
        bsr     en_rnd
        andi.w  #1,d0
        move.w  d0,BDX(a3)
        bsr     en_rnd
        lsr.w   #3,d0
        andi.w  #1,d0
        move.w  d0,BDY(a3)
        bsr     en_rnd
        andi.w  #3,d0
        lea     .col(pc),a0
        move.b  0(a0,d0.w),d0           ; the colouring
        ext.w   d0
        add.w   d0,d0
        add.w   d0,d0
        moveq   #3,d1
        and.w   d6,d1
        add.w   d1,d0                   ; look = colouring x 4 + palette
        mulu.w  #EN_LOOK,d0
        move.w  d0,BPIC(a3)
        bsr     en_rnd
        andi.w  #$20,d0
        move.w  d0,BBEH(a3)
        bsr     fe_poll
        lea     16(a3),a3
        addq.w  #1,d6
        dbra    d7,.b
        movem.l (sp)+,d0-d7/a0/a3
        rts
.pos:   bsr     en_rnd                  ; 0-240, whole
        andi.w  #$FF,d0
        cmpi.w  #240,d0
        bls.s   .p
        move.w  #240,d0
.p:     lsl.w   #8,d0
        rts
.col:   dc.b    0,1,2,0
        even

; en_build - the 12 looks' pictures, each at the 4 shifts: per row 5 words of
; (opaque pixels, their colours)
en_build:
        movem.l d0-d7/a0-a4,-(sp)
        lea     EN_PIC(a5),a2
        moveq   #0,d7                   ; look
.lk:    move.w  d7,d0
        andi.w  #3,d0
        mulu.w  #6,d0
        lea     end_cols(pc),a3
        adda.w  d0,a3                   ; a3: its 3 colours' words
        move.w  d7,d0
        lsr.w   #2,d0
        lsl.w   #6,d0                   ; x 64 (16 longs)
        lea     end_shapes(pc),a1
        adda.w  d0,a1                   ; a1: the colouring's rows
        moveq   #0,d6                   ; shift
.sh:    movea.l a1,a0
        moveq   #16-1,d5                ; rows
.rw:    moveq   #10-1,d0
        movea.l a2,a4
.cl:    clr.w   (a4)+
        dbra    d0,.cl
        move.l  (a0)+,d4                ; the row's 16 pixels
        moveq   #0,d3                   ; the pixel
.px:    rol.l   #2,d4
        moveq   #3,d0
        and.w   d4,d0
        beq.s   .np
        add.w   d0,d0
        move.w  -2(a3,d0.w),d0          ; its colour's word
        move.w  d3,d1
        add.w   d6,d1                   ; the position
        move.w  d1,d2
        lsr.w   #2,d2                   ; the word
        move.b  en_wo(pc,d2.w),d2       ; its opaque bits' place (the colours': + 4,
        ext.w   d2                      ;  the 5th's + 2)
        andi.w  #3,d1
        add.w   d1,d1
        move.w  en_pm(pc,d1.w),d1       ; the pixel's bits
        or.w    d1,0(a2,d2.w)
        and.w   d1,d0
        cmpi.w  #16,d2
        bne.s   .d4
        or.w    d0,18(a2)
        bra.s   .np
.d4:    or.w    d0,4(a2,d2.w)
.np:    addq.w  #1,d3
        cmpi.w  #16,d3
        blo.s   .px
        not.l   (a2)                    ; the opaque bits inverted (the drawing ANDs
        not.l   8(a2)                   ;  them in)
        not.w   16(a2)
        lea     20(a2),a2
        bsr     fe_poll
        dbra    d5,.rw
        addq.w  #1,d6
        cmpi.w  #4,d6
        blo.s   .sh
        addq.w  #1,d7
        cmpi.w  #12,d7
        blo     .lk
        movem.l (sp)+,d0-d7/a0-a4
        rts
en_pm:  dc.w    $C0C0,$3030,$0C0C,$0303
en_wo:  dc.b    0,2,8,10,16
        even

; en_all - the screen without the balls to the screen at a1 (32 KB)
en_all:
        movem.l d0-d1/a0-a1,-(sp)
        lea     EN_B(a5),a0
        moveq   #32-1,d1
.k:     move.w  #256/4-1,d0
.l:     move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        dbra    d0,.l
        bsr     fe_poll
        dbra    d1,.k
        movem.l (sp)+,d0-d1/a0-a1
        rts

; en_screen - the screen d7.w (0, 1): the balls it showed rubbed out (from the
; screen without them), its bands due copied, the balls drawn (behind ones on
; black only), their rectangles kept
en_screen:
        movem.l d0-d7/a0-a4,-(sp)
        lea     SCREEN,a1
        tst.w   d7
        beq.s   .s0
        lea     SCREEN1,a1
.s0:    move.w  d7,d6
        add.w   d6,d6                   ; d6: the screen's word index
        lea     EN_OLD(a5),a3
        move.w  d7,d0
        lsl.w   #7,d0
        adda.w  d0,a3                   ; a3: its rectangles
        move.w  EN_V+EV_NOLD(a5,d6.w),d5
        bra.s   .rn
.r:     move.w  (a3)+,d0                ; offset
        move.w  (a3)+,d4                ; words (4, 5)
        lea     EN_B(a5),a0
        adda.w  d0,a0
        lea     0(a1,d0.w),a2
        moveq   #16-1,d3
        cmpi.w  #5,d4
        beq.s   .r5
.r4:    move.l  (a0)+,(a2)+
        move.l  (a0)+,(a2)+
        lea     BPL-8(a0),a0
        lea     BPL-8(a2),a2
        dbra    d3,.r4
        bra.s   .rp
.r5:    move.l  (a0)+,(a2)+
        move.l  (a0)+,(a2)+
        move.w  (a0),(a2)
        lea     BPL-8(a0),a0
        lea     BPL-8(a2),a2
        dbra    d3,.r5
.rp:    bsr     fe_poll
.rn:    dbra    d5,.r
        move.w  EN_V+EV_DIRTY(a5,d6.w),d5       ; the bands due
        clr.w   EN_V+EV_DIRTY(a5,d6.w)
        lea     en_bands(pc),a4
        moveq   #3-1,d4
.bd:    lsr.w   #1,d5
        bcc.s   .bn
        move.w  4(a4),d0
        mulu.w  #BPL,d0
        add.w   (a4),d0
        lea     EN_B(a5),a0
        adda.l  d0,a0
        lea     0(a1,d0.l),a2
        moveq   #EN_LINES-1,d3
.bl:    move.w  2(a4),d2
        lsr.w   #2,d2
        subq.w  #1,d2
        move.l  a0,-(sp)
        move.l  a2,-(sp)
.bw:    move.l  (a0)+,(a2)+
        dbra    d2,.bw
        movea.l (sp)+,a2
        movea.l (sp)+,a0
        lea     BPL(a0),a0
        lea     BPL(a2),a2
        dbra    d3,.bl
        bsr     fe_poll
.bn:    addq.l  #6,a4
        dbra    d4,.bd
        lea     EN_OLD(a5),a3           ; the balls, their rectangles
        move.w  d7,d0
        lsl.w   #7,d0
        adda.w  d0,a3
        lea     EN_BALL(a5),a4
        move.w  EN_V+EV_N(a5),d5
        move.w  d5,EN_V+EV_NOLD(a5,d6.w)
        subq.w  #1,d5
.ball:  moveq   #0,d0
        move.b  BX(a4),d0               ; x
        moveq   #3,d1
        and.w   d0,d1                   ; shift
        lsr.w   #2,d0
        add.w   d0,d0                   ; the word's byte
        moveq   #0,d2
        move.b  BY(a4),d2
        lsl.w   #7,d2
        add.w   d2,d0                   ; the offset
        moveq   #4,d4
        tst.w   d1
        beq.s   .w4
        moveq   #5,d4
.w4:    move.w  d0,(a3)+
        move.w  d4,(a3)+
        lea     EN_PIC(a5),a2
        adda.w  BPIC(a4),a2
        mulu.w  #EN_SHIFT,d1
        adda.w  d1,a2                   ; a2: the picture
        lea     0(a1,d0.w),a0           ; a0: the screen, d0: the offset
        moveq   #16-1,d3
        cmpi.w  #4,d4                   ; (d4: the words)
        seq     d2                      ; d2.b: $FF = 4 words (shift 0)
        tst.w   BBEH(a4)
        bne.s   .bh
.fl:    move.l  (a2)+,d4                ; in front: (screen & ~opaque) | colours
        move.l  (a2)+,d1
        and.l   d4,(a0)
        or.l    d1,(a0)+
        move.l  (a2)+,d4
        move.l  (a2)+,d1
        and.l   d4,(a0)
        or.l    d1,(a0)+
        move.w  (a2)+,d4
        move.w  (a2)+,d1
        tst.b   d2
        bne.s   .f4
        and.w   d4,(a0)
        or.w    d1,(a0)
.f4:    lea     BPL-8(a0),a0
        dbra    d3,.fl
        bra.s   .bx
.bh:    move.l  a3,-(sp)                ; behind: opaque only where the screen copy
        lea     EN_NZ(a5),a3            ;  is black ((a3): its black pixels)
        adda.w  d0,a3
.hl:    rept    2
        move.l  (a2)+,d4
        move.l  (a2)+,d1
        move.l  (a3)+,d0
        and.l   d0,d1
        not.l   d0
        or.l    d0,d4
        and.l   d4,(a0)
        or.l    d1,(a0)+
        endr
        move.w  (a2)+,d4
        move.w  (a2)+,d1
        tst.b   d2
        bne.s   .h4
        move.w  (a3),d0
        and.w   d0,d1
        not.w   d0
        or.w    d0,d4
        and.w   d4,(a0)
        or.w    d1,(a0)
.h4:    lea     BPL-8(a0),a0
        lea     BPL-8(a3),a3
        dbra    d3,.hl
        movea.l (sp)+,a3
.bx:
        bsr     fe_poll
        lea     16(a4),a4
        dbra    d5,.ball
        movem.l (sp)+,d0-d7/a0-a4
        rts

txt_endg:                               ; (8 px text rows, lines spaced for
        dc.w    64,L_TITLE              ;  the 14-line font)
        dc.b    5,2,'CONGRATULATIONS',0
        even
        dc.w    88,44
        dc.b    7,2,'LEFT PLAYER',0
        even
        dc.w    56,70
        dc.b    5,2,'YOU HAVE COMPLETED',0
        even
        dc.w    56,86
        dc.b    5,2,'THE ULTIMATE RACE!',0
        even
        dc.w    16,118
        dc.b    5,2,'BONUS FOR FINISHING',0
        even
        dc.w    48,L_SEC
        dc.b    5,2,'SEC LEFT X 1000',0
        even
        dc.w    0,L_DIED
        dc.b    5,2,'DIED',0
        even
        dc.w    64,L_DIED
        dc.b    5,2,'TIMES X -1000',0
        even
        dc.w    128,L_TOT
        dc.b    5,2,'TOTAL',0
        even
        dc.w    72,L_FIN
        dc.b    5,2,'FINAL SCORE:',0
        even
        dc.w    -1

txt_tfin:
        dc.b    'TIME TO FINISH',0
        even
txt_time2:
        dc.b    'TIME',0
        even
txt_bonus:
        dc.b    'BONUS',0
        even
txt_silly:
        dc.b    'EVERYTHING YOU KNOW IS WRONG',0
        even
txt_rnames:
        dc.w    .r0-txt_rnames,.r1-txt_rnames,.r2-txt_rnames,.r3-txt_rnames
        dc.w    .r4-txt_rnames,.r5-txt_rnames
.r0:    dc.b    'PRACTICE RACE:',0
.r1:    dc.b    'BEGINNER RACE:',0
.r2:    dc.b    'INTERMEDIATE RACE:+',0
.r3:    dc.b    'AERIAL RACE:+',0
.r4:    dc.b    'SILLY RACE:+',0
.r5:    dc.b    'ULTIMATE RACE:+',0
        even

        include "fe_gen.inc"            ; (generated: hi_default, the default table)
        include "fe_end.inc"            ; (generated: the ending's balls, colours)
        include "mm_logo.inc"           ; (generated: the start screen's logo)
