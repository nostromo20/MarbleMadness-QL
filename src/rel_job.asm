; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
; rel_job.asm - the release as one QDOS job: EXEC_W mdv1_mm (tools/mk_release.py).
; The file is this stub + the ZX0-packed release code
; (mmr: src/proto.asm with -DRELB=1). EXEC_W loads the whole file at the job's base and gives it DATASPACE
; bytes more (its QDOS header), so the job's area is
;   [stub][packed code][dataspace ...][QDOS's job stack, A7 at entry]
; and the game's memory is all in it, from DEST (the packed code's place):
;   the code (CODE_A), the race area, the bitmap, the marble bank, mm_dat
; (the regions mmr_bas RESPRs). The stub:
;   1. checks the area starts at $30000 or above (the takeover's second screen is
;      $28000-$2FFFF) and reaches the end of mm_dat + STACK_KEEP (else "out of
;      memory");
;   2. MODE 8 (MT.DMODE: the screen cleared, as mmr_bas's MODE 8 : CLS); done
;      between the two checks of 1, before A4 is set: the JS ROM's MT.DMODE
;      does not preserve A4;
;   3. copies the packed code past the code's end (no overlap: asserted below) and
;      unpacks it to DEST;
;   4. CALLs it once with G_TLOGO = 1: the loading screen (src/frontend.asm
;      fe_loadlogo), up while mm_dat loads;
;   5. loads mm_dat (IO.OPEN, FS.HEADR: its length must be DSZ, FS.LOAD), from the
;      settings' device, else the first that works of: the default directory
;      (Toolkit II; without it the name fails at once), mdv1_, win1_, win2_, flp1_,
;      mdv2_
;      (none: the first error from a file that opened, else "not found");
;   6. the sprite cache: the largest free block (MT.FREE) less CC_SPARE (left to
;      QDOS), allocated (MT.ALCHP); only its part at $30000 and up is used (the
;      takeover's second screen is $28000-$2FFFF), whole KB, none under 4 KB;
;   7. the settings' cache readout (+34 = 1): the cache, the largest free block and
;      the slinkies' need printed in a con_ window, then a key (or 30 s);
;   8. the globals as mmr_bas pokes them (release takeover: G_TAKE 3), and the game;
;   9. back only if the takeover was refused: MT.FRJOB with "not complete" (EXEC_W
;      prints it); the release otherwise ends in the ROM reset (ESC).
; Assembled with -I <build folder>/rel (rel_eq.inc and mmr.zx0, tools/mk_release.py).

MT_FRJOB        equ     5
MT_FREE         equ     6
MT_DMODE        equ     $10
MT_ALCHP        equ     $18
IO_OPEN         equ     1
IO_CLOSE        equ     2
IO_FBYTE        equ     1
IO_SSTRG        equ     7
FS_HEADR        equ     $47
FS_LOAD         equ     $48
ERR_NC          equ     -1              ; not complete (the takeover refused)
ERR_OM          equ     -3              ; out of memory
ERR_BP          equ     -15             ; bad parameter (mm_dat is not this build's)
STACK_KEEP      equ     1024            ; below A7: QDOS's job stack + the stub's

        include "rel_eq.inc"

        org     0
base:
        bra.w   start                   ; +0
        dc.w    0                       ; +4
        dc.w    $4AFB                   ; +6 job header tag
        dc.w    2                       ; +8 job name
        dc.b    "MM"
        dc.b    0,0,0,0                 ; +12
; +16: the settings (patchable in the file)
cfg:    dc.b    "MMCF"                  ; +16 tag
cfg_aud:
        dc.b    0                       ; +20 sound: 0 find the AY board (none: the
                                        ;     beeper), 1 none, 5 the beeper
cfg_fps:
        dc.b    2                       ; +21 frame rate: 2 12.5 fps, 1 10 fps,
                                        ;     0 adaptive 10 / 12.5 fps
cfg_dev:
        dc.w    0                       ; +22 mm_dat's device (QDOS string, e.g.
        ds.b    10                      ;     "mdv1_"; empty: the list below)
cfg_rep:
        dc.b    0                       ; +34 1: show the sprite cache before the game
        dc.b    0                       ; +35

start:
        lea     base(pc),a0             ; (the takeover's second screen is
        cmpa.l  #$30000,a0              ;  $28000-$2FFFF: the area must be above it)
        blo     .om
        moveq   #MT_DMODE,d0            ; MODE 8 (before A4 is set: the JS ROM's
        moveq   #8,d1                   ;  MT.DMODE returns with A4 changed)
        moveq   #-1,d2
        trap    #1
        lea     dest(pc),a4             ; A4 = the code
        move.l  a4,d0
        add.l   #NEED+STACK_KEEP,d0
        cmp.l   sp,d0
        bhi     .om
        movea.l a4,a0                   ; the packed code past the code's end
        movea.l a4,a1
        adda.l  #CODE_A,a1
        move.w  #(PACKED_LEN+3)/4-1,d0
.mv:    move.l  (a0)+,(a1)+
        dbra    d0,.mv
        movea.l a4,a0
        adda.l  #CODE_A,a0
        movea.l a4,a1
        bsr     zx0_decompress
        cmpi.w  #$6000,(a4)             ; (bra.w init)
        bne     .bp
        move.w  #1,O_TLOGO(a4)          ; the loading screen
        jsr     (a4)
        bsr     load_dat
        tst.l   d0
        bne     .err
        bsr     cache                   ; -> a0 base, d1 size (0: none), d5 free
        move.l  a0,O_CCH(a4)
        move.l  d1,O_CSZ(a4)
        move.b  cfg_rep(pc),d0          ; (no tst d16(pc) on the 68000)
        beq.s   .nrep
        bsr     report
.nrep:
        movea.l a4,a0
        adda.l  #CODE_A,a0
        move.l  a0,O_RBUF(a4)
        adda.l  #AREA_A,a0
        move.l  a0,O_LIN(a4)
        adda.l  #LIN_A,a0
        move.l  a0,O_SPRB(a4)
        adda.l  #SPR_A,a0
        move.l  a0,O_DAT(a4)
        clr.l   O_SAVE(a4)
        move.w  #3,O_TAKE(a4)           ; the release's takeover
        moveq   #0,d0
        move.b  cfg_aud(pc),d0
        move.w  d0,O_TAUD(a4)
        move.b  cfg_fps(pc),d0
        move.w  d0,O_TFPS(a4)
        jsr     (a4)                    ; the game
        moveq   #0,d0
        tst.w   O_TKERR(a4)
        beq.s   .err
        moveq   #ERR_NC,d0
        bra.s   .err
.om:    moveq   #ERR_OM,d0
        bra.s   .err
.bp:    moveq   #ERR_BP,d0
.err:   move.l  d0,d3                   ; MT.FRJOB: this job, its error to EXEC_W
        moveq   #MT_FRJOB,d0
        moveq   #-1,d1
        trap    #1
.hang:  bra.s   .hang

; load_dat - mm_dat to O_DAT's place -> d0 = 0 or the QDOS error
DAT_NAME        equ     6               ; "mm_dat"
load_dat:
        lea     -80(sp),sp              ; the name (+0, 32 B), the header (+16..+80)
        lea     cfg_dev+1(pc),a3        ; (its length's low byte: an entry as below)
        tst.b   (a3)
        bne.s   .one
        lea     devs(pc),a3
        moveq   #-7,d5                  ; ("not found" if no device has it)
.next:  bsr.s   .try
        beq.s   .ok
        tst.w   d4                      ; any failure: the next device; the error
        beq.s   .nx                     ; kept is the first from a file that opened
        cmpi.l  #-7,d5                  ; (e.g. a stale mm_dat in Toolkit II's
        bne.s   .nx                     ;  default directory: the right one may be
        move.l  d0,d5                   ;  on mdv1_)
.nx:    moveq   #0,d1
        move.b  (a3),d1
        lea     1(a3,d1.w),a3
        tst.b   (a3)
        bpl.s   .next
        move.l  d5,d0
        bra.s   .ok
.one:   bsr.s   .try
.ok:    lea     80(sp),sp
        rts
; .try - the device entry at (a3) (a length byte, the characters): open, check the
; length, load, close -> d0 (flags), d4 = 1 if the file opened
.try:   moveq   #0,d4
        lea     4+2(sp),a1              ; the name's characters (past this call's return)
        moveq   #0,d1
        move.b  (a3),d1
        lea     1(a3),a0
        bra.s   .c1
.c0:    move.b  (a0)+,(a1)+
.c1:    dbra    d1,.c0
        lea     dat_name(pc),a0
        moveq   #DAT_NAME-1,d1
.c2:    move.b  (a0)+,(a1)+
        dbra    d1,.c2
        moveq   #DAT_NAME,d1
        add.b   (a3),d1
        move.w  d1,4(sp)
        lea     4(sp),a0
        moveq   #IO_OPEN,d0
        moveq   #-1,d1
        moveq   #1,d3                   ; old, shared
        trap    #2
        tst.l   d0
        bne.s   .tr
        moveq   #1,d4
        lea     4+16(sp),a1             ; the header
        moveq   #FS_HEADR,d0
        moveq   #64,d2
        moveq   #-1,d3
        trap    #3
        tst.l   d0
        bne.s   .cl
        move.l  4+16(sp),d1             ; its length: DSZ (+ 64 where it counts itself)
        sub.l   #DSZ,d1
        beq.s   .ld
        moveq   #64,d0
        cmp.l   d0,d1
        beq.s   .ld
        moveq   #ERR_BP,d0
        bra.s   .cl
.ld:    movea.l a4,a1
        adda.l  #CODE_A+AREA_A+LIN_A+SPR_A,a1
        move.l  #DSZ,d2
        moveq   #FS_LOAD,d0
        moveq   #-1,d3
        trap    #3
.cl:    move.l  d0,-(sp)
        moveq   #IO_CLOSE,d0
        trap    #2
        move.l  (sp)+,d0
.tr:    tst.l   d0
        rts

; cache - the sprite cache -> a0 = its base, d1 = its size (0, a0 = 0: none);
; d5 = the largest free block (MT.FREE)
cache:  moveq   #MT_FREE,d0
        trap    #1
        move.l  d1,d5
        sub.l   #CC_SPARE,d1
        ble.s   .no
        move.l  d1,d4
        moveq   #MT_ALCHP,d0
        moveq   #-1,d2
        trap    #1
        tst.l   d0
        bne.s   .no
        move.l  a0,d2                   ; [base + 16, base + size), from $30000 up
        add.l   d2,d4
        addi.l  #16,d2
        cmpi.l  #$30000,d2
        bhs.s   .b
        move.l  #$30000,d2
.b:     addq.l  #3,d2
        andi.w  #$FFFC,d2
        move.l  d4,d1
        sub.l   d2,d1
        andi.w  #$FC00,d1               ; whole KB
        cmpi.l  #4096,d1
        blt.s   .no
        movea.l d2,a0
        rts
.no:    suba.l  a0,a0
        moveq   #0,d1
        rts

; report - (cfg_rep) the cache (O_CCH / O_CSZ) and d5 = the largest free block, in a
; con_ window over the loading screen; then a key, or 30 s
report: lea     -128(sp),sp             ; the text (+2: a QDOS string's characters)
        lea     2(sp),a1
        lea     rp_t1(pc),a0
        bsr.s   .str
        move.l  O_CSZ(a4),d1
        bsr.s   .num
        lea     rp_t2(pc),a0
        bsr.s   .str
        move.l  O_CCH(a4),d1
        bsr.s   .num
        lea     rp_t3(pc),a0
        bsr.s   .str
        move.l  d5,d1
        bsr.s   .num
        lea     rp_t4(pc),a0
        bsr.s   .str
        move.l  a1,d6
        sub.l   sp,d6
        subq.l  #2,d6                   ; the text's length
        lea     rp_con(pc),a0
        moveq   #IO_OPEN,d0
        moveq   #-1,d1
        moveq   #0,d3
        trap    #2
        tst.l   d0
        bne.s   .o
        move.l  a0,d7
        lea     2(sp),a1
        move.w  d6,d2
        moveq   #IO_SSTRG,d0
        moveq   #-1,d3
        trap    #3
        movea.l d7,a0
        moveq   #IO_FBYTE,d0
        move.w  #30*50,d3               ; (30 s)
        trap    #3
        movea.l d7,a0
        moveq   #IO_CLOSE,d0
        trap    #2
.o:     lea     128(sp),sp
        rts
.str:   move.b  (a0)+,(a1)+             ; a 0-ended text
        bne.s   .str
        subq.l  #1,a1
        rts
.num:   lea     12(a1),a2               ; d1.l unsigned, in decimal (a1 past it)
        movea.l a2,a3
.dg:    moveq   #0,d0                   ; d1 / 10, two divu steps
        swap    d1
        move.w  d1,d0
        divu    #10,d0
        move.w  d0,d1
        swap    d1
        move.w  d1,d0
        divu    #10,d0
        move.w  d0,d1
        swap    d0
        addi.b  #'0',d0
        move.b  d0,-(a2)
        tst.l   d1
        bne.s   .dg
.cp:    move.b  (a2)+,(a1)+
        cmpa.l  a3,a2
        blo.s   .cp
        rts
rp_con: dc.w    16
        dc.b    "con_512x50a0x196"
rp_t1:  dc.b    "sprite cache ",0
rp_t2:  dc.b    " bytes at ",0
rp_t3:  dc.b    10,"free block ",0
rp_t4:  dc.b    10,"slinkies need 41628",10,"press a key",0
        even

dat_name:
        dc.b    "mm_dat"
        even
devs:   dc.b    0                       ; the default directory (Toolkit II)
        dc.b    5,"mdv1_"               ; (a length byte, the characters)
        dc.b    5,"win1_"
        dc.b    5,"win2_"
        dc.b    5,"flp1_"
        dc.b    5,"mdv2_"
        dc.b    -1                      ; (the end)
        even

        include "unzx0_68000.s"         ; Emmanuel Marty, zlib licence (unchanged)

        cnop    0,4
dest:                                   ; the code is unpacked here
packed:
        incbin  "mmr.zx0"
packed_end:
        even

        if      (packed_end-packed)>CODE_A
        fail    "the packed code is longer than the code: the copy would overlap"
        endif
        if      (packed_end-packed)<>PACKED_LEN
        fail    "PACKED_LEN is not mmr.zx0's length"
        endif
