; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
; music.inc - equates of the race-tune player (src/music.asm)
;
; Board numbers (as the QL Lemmings port's AY layer's AB_*, plus a dummy for
; measuring): G_AUD.
AB_NONE         equ     0               ; no AY board: no music
AB_QSOUND       equ     1               ; QSound, $C2000/$C2002 latch + strobe, 0.75 MHz
AB_QGOLD        equ     2               ; QIMSI Gold, $1C440 + reg x 4, 2 MHz
AB_PISTORM      equ     3               ; QL PiStorm, $1C140 select / $1C141 data, 0.75 MHz
AB_AYCARD       equ     4               ; QLion / Next QL core, $800028 / $80002A, 2.5 MHz
AB_DUMMY        equ     5               ; (G_TAUD 2-4) the QSound protocol into G_MDUM
AB_BEEP         equ     6               ; no AY board (or G_TAUD 5): effects on the IPC beeper
; period classes (G_MCLS): which conversion of the ST's 2 MHz periods
MC_075          equ     0               ; x 3/8, rounded: (3p + 4) >> 3
MC_200          equ     1               ; as they are
MC_250          equ     2               ; x 5/4, rounded: (5p + 2) >> 2, at most 4095

; a voice (G_MVO, 4 of them; the ST's $33B5.. per-voice variables)
V_CLK           equ     0               ; long: the voice's clock (24-bit)
V_NXT           equ     4               ; long: the time of its next event (24-bit)
V_TEMPO         equ     8               ; long: added to the clock a tick (0: ended)
V_BASE          equ     12              ; long: its event bytes
V_POS           equ     16              ; word: offset of the next event
V_LEN           equ     18              ; word: bytes of events
V_DEPTH         equ     20              ; word: loops open (0-8)
V_TRANS         equ     22              ; byte: voice transpose ($A1)
V_INSTR         equ     23              ; byte: envelope offset ($81)
V_CNT           equ     24              ; DEPTH bytes: loop counts
V_CUR           equ     28              ; DEPTH bytes: the ENDLOOP(n) state
V_RET           equ     32              ; DEPTH words: loop starts
V_ALT           equ     40              ; DEPTH words: the place after an ENDLOOP(n)
V_CAT           equ     48              ; long: the clock when it is next due
V_DUE           equ     52              ; word: the tick it is due (G_MNOW)
V_NK            equ     54              ; word: the next event's duration d = k x tempo
V_NM            equ     56              ; word:  + m
V_PARK          equ     58              ; word: 1 = ended: never due (mus_due)
V_SIZE          equ     60
DEPTH           equ     4               ; loops open at most (the ST allows 8; the tunes
                                        ; use 2)
NVOICE          equ     4
SFX_N           equ     18              ; effects 1-18

; the tune (PLAY blob, PH_MUS)
TU_TEMPO        equ     0
TU_FLAGS        equ     2               ; bit 0: $8C restarts voices 0-2
TU_OFF          equ     4               ; 4 words: voice data offsets
TU_LEN          equ     12              ; 4 words: voice data lengths
TU_RST          equ     20              ; 3 words: restart positions
TU_DUR          equ     28              ; (word ndur at 26) n x (long d, word k, word m)
