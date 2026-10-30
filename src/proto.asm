; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
;=============================================================================
; proto.asm - Marble Madness QL: the game's main file (the frame loop)
;
; The six races on a QL in Mode 8: the marble logic in 68000
; (src/mlogic.asm), run at a 60 Hz logic rate (SUBSTEPS logic steps
; per 5 ticks: 6 per 10 fps frame, 4.8 per 12.5 fps frame), the objects
; (src/mobj.asm), the race data loaded and expanded from mm_dat
; (src/proto_load.asm), the title and score screens (src/frontend.asm) and the
; race tunes (src/music.asm). The display engine: LINEAR renderer, two screens
; flipped, a frame counter, busy-time measurement.
; Frame rate: fixed 12.5 fps, fixed 10 fps, or adaptive between the two.
;
; Frame:  input -> logic (the logic steps due) -> background copy -> objects
;         and the marble into the hidden screen -> HUD -> wait / flip
;
; Keys in play (KEYROW row 1): arrows steer, SPACE speed-up, ENTER
; pause, \ sound on/off, ESC quit. The test build (RELB = 0) also reads typed
; keys: 1-6 race, H height, V sync, T measuring mode, B benchmark, P pause,
; R restart, L the LAB, D demo, M occlusion, O debug panel / HUD, C race
; timer, F frame rate.
;
; Position independent RESPR code: mutable state in the globals block at
; code offset 4 (a6); the marble block is a4-relative. THE POLL HANDLER MUST
; NOT USE A3 (Minerva passes link-8 there).
;=============================================================================

        include "proto_gen.inc"         ; generated: geo/sprite layout, glyphs
        include "mlogic.inc"            ; the marble block (M_*)
        include "mm_dat.inc"            ; the layout of data/mm_dat
        include "mus_on.inc"            ; generated: MUS_ON (1 = the ST tunes are in)
        include "map_fix_on.inc"        ; generated: MAP_FIX (1 = map fixes are built in)
        include "music.inc"             ; the race-tune player (src/music.asm)
        ifnd    RELB                    ; the release build (mmr: -DRELB=1): the
RELB    equ     0                       ; measuring code left out; the test
        endc                            ; build (mmp): all of it

; FAR label - a PC-relative far call (bsr's 32 KB reach exceeded; a0 clobbered)
FARCALL macro
.f\@:   lea     .f\@(pc),a0
        adda.l  #\1-.f\@,a0
        jsr     (a0)
        endm

SCREEN          equ $20000
SCREEN1         equ $28000
MC_STAT         equ $18063
SV_MCSTA        equ $34
SV_RAND         equ $2E
BPL             equ 128
SCR_LINES       equ 256

MT_INF          equ $00
MT_DMODE        equ $10
MT_IPCOM        equ $11
MT_LPOLL        equ $1C
MT_RPOLL        equ $1D
IO_OPEN         equ $01
IO_CLOSE        equ $02
IO_FBYTE        equ $01

STAT_TICKS      equ 50
ACC_MAX_TICKS   equ 30000
CAL_CAP         equ $100000
POLL_CHECK      equ 3
N_MIN           equ 5                   ; VSYNC/DOUBLE: 10 fps (the display; the logic
                                        ; follows the ticks)
N_FAST          equ 4                   ; 12.5 fps: the adaptive step up (G_FPSM), never
                                        ; faster
UP_FRAMES       equ 20                  ; adaptive: 20 frames (2 s) in a row with a margin
                                        ; (the wait >= 1.25 ticks at 5: done 5 ms before
                                        ; the 4-tick deadline) -> 4 ticks
BOFF_BASE       equ 50                  ; adaptive: after a late frame at 4 ticks, 5 ticks
BOFF_MAX        equ 400                 ; for 50 frames (5 s), doubled on each failure up
BOFF_RESET      equ 250                 ; to 400 (40 s); 250 frames (20 s) clean at 4
                                        ; ticks: back to 50
N_MAX           equ 9
SLACK_FRAMES    equ 50
SLACK_COOL      equ -200
K_ESC           equ $1B
SUBSTEPS        equ 6                   ; logic steps per 5 ticks (one 10 fps frame)
STEP_CAP        equ 12                  ; at most 2 frames' worth of logic a frame
DT_CAP          equ 100                 ; (ticks: a longer gap counts as 100)
N_GHOST         equ 9                   ; mode 1: extra marbles
N_MODES         equ 7                   ; the benchmark: modes 0-5, then 8 (no objects)
N_TMODES        equ 9                   ; T: 0-5, 6 and 7 (the bare loop), 8 (no objects)
N_LAB           equ 18                  ; LAB items
LAB_STK         equ 512                 ; LAB's own stack (fast RAM, in the globals)
TK_STK          equ 1024                ; takeover: our supervisor stack (in the globals)
PC_INTRF        equ 8                   ; pc_intr: frame interrupt
PC_INTRI        equ 2                   ; pc_intr: IPC interface interrupt
BENCH_FRAMES    equ 80                  ; QL frames measured per benchmark mode
GOAL_WAIT       equ 180                 ; logic steps (3 s) after the goal, then restart

TEXT_W          equ 64                  ; glyphs a panel line (4 px each)
TEXT_LINES      equ 4
TEXT_LEN        equ TEXT_W*TEXT_LINES
PANEL_TOP       equ 0                   ; screen line of the top band's first text row
PANEL_BOT       equ 240                 ; ... and of the bottom band's
PANEL_STEP      equ 8                   ; lines between text rows (7-line glyphs)
; Screen layout: the playfield is centred, lines G_PTOP .. G_PTOP+LINES-1
; (H224: 16-239; H208: 24-231; H192: 32-223); the bands above and below hold
; the panel: TOP line 0 = status (MS FPS sync H mode SUB OC TK; columns 48-63
; kept free for the race timer), line 8 = the marble (X Y Z SC ST D GOAL, 1 Hz);
; BOTTOM line 240 = results (B: T0 CPY LOG SPR INP OCC, or the LAB's first
; line after L), line 248 = the LAB's second line. Text buffer lines L0-L3 ->
; screen lines 0, 240, 8, 248 (pan_rows).

;-----------------------------------------------------------------------------
; Globals (code offset 4), a6-relative. Words/longs only: every offset even.
;-----------------------------------------------------------------------------
; anim_update's descriptors (G_ANG)
AN_LIN          equ     0               ; long: the box's first byte in the bitmap
AN_STORE        equ     4               ; long: the variants (VB bytes each)
AN_LB           equ     8               ; bytes a line (a multiple of 4)
AN_LINES        equ     10
AN_VB           equ     12
AN_SEL          equ     14
AN_SHOWN        equ     16              ; the variant in the bitmap (-1 not known)
AN_Y            equ     18              ; the box's first bitmap line
AN_CODE         equ     20              ; long: 0 = copy LB x LINES; else the generated put
                                        ; code (a goal flag's spans: a0 = variant, a1 = box)
AN_HIDE         equ     24              ; long: a flag's cover masks (FL_NVAR x FL_HIDEB B)
AN_BOXL         equ     28              ; a flag's whole box: its first bitmap line
AN_WC           equ     30              ; and its first screen word
AN_SIZE         equ     32
AN_MAX          equ     4               ; Beginner: the bridge, its neighbour, 2 flags

                rsreset
G_LIN           rs.l    1               ; loader-poked: level bitmap (mm1_lin)
G_PGEO          rs.l    1               ; loader-poked: course logic (mm1_geo)
G_SPRB          rs.l    1               ; loader-poked: sprite bank (mm1_spr)
        ifeq    RELB
G_TFRAMES       rs.w    1               ; test loader: quit after N frames
G_TSYNC         rs.w    1               ; test loader: start sync + 1
G_THGT          rs.w    1               ; test loader: start height index + 1
G_TMODE         rs.w    1               ; test loader: start measuring mode + 1
G_TPAD          rs.w    1               ; test loader: input bits + 1 (no KEYROW)
G_TLAB          rs.w    1               ; test loader: 1 = run LAB at start, then quit
G_TDEMO         rs.w    1               ; test loader: 1 = demo input from the start
G_TRACE         rs.w    1               ; test loader: start race + 1 (0 = Practice)
G_TIMG          rs.l    1               ; test loader: a start image (G_MB..G_WEND) to use
                                        ; instead of the race's (a bench position), 0 none
        endc
G_TAKE          rs.w    1               ; loader: 1 = take the machine over (mmt_bas),
                                        ; 2 = the same on Minerva dual, no save buffer,
                                        ; 3 = RELEASE (mmr_bas): no save buffer on any ROM,
                                        ; ESC resets the machine (tk_reset)
G_SAVE          rs.l    1               ; loader: 32 KB buffer for $28000-$2FFFF
G_DAT           rs.l    1               ; loader: mm_dat (0 = the single-race mm1_* files)
G_SHB           rs.l    1               ; the shared blob (in the race area, at load)
G_RBUF          rs.l    1               ; loader: the race area (proto_load.asm)
G_WORK          rs.l    1               ; tile states + the cell cache (race area, load)
G_SPB           rs.l    1               ; BASIC's stack pointer at CALL (back at quit)
G_CCH           rs.l    1               ; loader (mmt_bas): the sprite cache, 0 = none: the
G_CSZ           rs.l    1               ;  QDOS free memory left at $30000+ (its size, bytes)
        ifeq    RELB
G_TCCHK         rs.w    1               ; test loader: 1 = fill the cache at takeover and
                                        ; check it at the exit (G_CCHK)
        endc
G_TAUD          rs.w    1               ; loader: music board, 0 auto, 1 none, 2-4 the dummy
                                        ; (0.75 / 2 / 2.5 MHz periods; src/music.asm), 5 the
                                        ; beeper (effects only, even with an AY board)
        ifeq    RELB
G_TBEEPN        rs.w    1               ; test loader: effect 3 every N frames (0 none)
        endc
G_TFLOFF        rs.w    1               ; test loader: still, as baked (no anim_update
                                        ; group, no flag_cover): bit 0 the goal flags,
                                        ; bit 1 the GOAL text
G_TFPS          rs.w    1               ; loader: the frame rate, 0 adaptive (10 / 12.5
                                        ; fps), 1 fixed 10 fps, 2 fixed 12.5 fps (G_FPSM)
        ifeq    RELB
G_TPANEL        rs.w    1               ; loader: the top band at start, 0 the HUD (the
                                        ; game's loaders), 1 the debug panel (test
                                        ; loaders, the emulator test), 2 nothing
G_TNOBOX        rs.w    1               ; test loader: 1 = no race boxes (TIME TO FINISH,
                                        ; TIME BONUS: src/frontend.asm), 0 = the game's
G_TELB          rs.l    1               ; loader: the telemetry buffer (0: none, no cost
G_TELN          rs.l    1               ;  but one test a frame), its size (tel_init)
G_TEND          rs.w    1               ; test loader (mme_bas): straight to the ending,
                                        ; the seconds left + 1 (0 = off)
G_TENDD         rs.w    1               ; mme_bas: the deaths
G_TENDS         rs.l    1               ; mme_bas: the score (M_SCORE's base-100 bytes)
G_TSTART        rs.w    1               ; loader: 1 = the start screen (the game's
                                        ; loaders; the release always), 0 = none
                                        ; (straight into Practice: the emulator test)
        endc
G_TLOGO         rs.w    1               ; loader: 1 = draw the loading screen and
                                        ; return (the first CALL: fe_loadlogo)
G_RUNTIME       rs.b    0               ; ---- cleared at init from here ----
        ifeq    RELB
G_TELP          rs.l    1               ; telemetry: the next record (0: not recording),
G_TELS          rs.l    1               ;  the first, one past the last (tel_init)
G_TELE          rs.l    1
        endc
G_AUD           rs.w    1               ; the AY board (AB_*), 0 = no music
G_MSFX          rs.l    1               ; effects asked for this frame (bit n: effect n)
G_BCNT          rs.l    1               ; the beeper: BEEPs sent
G_TBCNT         rs.w    1               ; (G_TBEEPN's countdown)
        ifne    MUS_ON
G_MON           rs.w    1               ; 1 = a tune plays (mus_tick runs each tick)
G_MCLS          rs.w    1               ; the board's period class (MC_*)
G_MWR           rs.l    1               ; the board's register writer
G_MTEMPO        rs.l    1               ; the tune's tempo
G_MDUR          rs.l    1               ; its duration entries
G_MRST          rs.w    1               ; 1 = $8C restarts voices 0-2 (Ultimate)
G_MRP           rs.w    3               ; their restart positions
G_MDUM          rs.w    2               ; the dummy board: data, control
G_BCUR          rs.w    1               ; the beeper: the effect sounding (as asked for)
G_BSTART        rs.w    1               ;  its start tick (G_PTICK)
G_BLEN          rs.w    1               ;  its length (ticks)
G_BLEFT         rs.w    1               ;  BEEPs still to send
G_BPTR          rs.l    1               ;  the next one (start tick, 8 bytes)
G_BLAST         rs.w    1               ;  the tick of the last BEEP
G_BSENT         rs.w    1               ;  1 = a BEEP lately (beep_quiet)
G_BBLK          rs.b    16              ;  QDOS mode: the MT.IPCOM block
G_MCLR          rs.b    0               ; ---- cleared at a tune start from here: ----
G_MGTR          rs.w    1               ; global transpose (low byte)
G_MNOW          rs.w    1               ; ticks since the tune's start (mod 65536)
G_MCNT          rs.w    1               ; ticks to the next voice due (mus_pass)
G_MCNT0         rs.w    1               ; that countdown's length
G_MNV           rs.w    1               ; voices run (4; 0 after GAME OVER)
G_FXPTR         rs.l    1               ; the effect stream (0: none)
G_FXCNT         rs.w    1               ; its wait ticks ($3F2A)
G_FXSW          rs.w    1               ; its sweep ($3DE2)
G_FXCUR         rs.w    1               ; the effect playing ($3CFA)
G_FXSH          rs.w    1               ; C's period as the effect set it ($3DE8)
G_MDRT          rs.w    1               ; (byte) the step touched R0-R7
G_MTIM          rs.b    4               ; channels A-C: note timers, envelope indices
G_MENVI         rs.b    4
G_MREG          rs.b    12              ; R0-R10 as the ST driver has them
G_MOUT          rs.b    12              ; R0-R10 as the chip has them (the board's)
G_MRAW          rs.w    6               ; per tone pair: raw period, its board value
G_MVO           rs.b    4*V_SIZE        ; the 4 voices
G_MTIE          rs.b    128             ; note -> voice + 1 holding a tie ($3332)
G_MCLRE         rs.b    0
        endc
G_CON           rs.l    1
G_SYS           rs.l    1
G_VER           rs.l    1
G_PLINK         rs.l    2               ; MT.LPOLL link: next, handler
G_PTICK         rs.w    1
G_DUAL          rs.w    1
G_DMODE         rs.w    1
G_MCSTA0        rs.w    1
G_SHOWN         rs.w    1
G_DEST          rs.l    1
G_SYNC          rs.w    1
G_SEFF          rs.w    1
G_NT            rs.w    1
G_LATE          rs.l    1               ; VSYNC/DOUBLE frames shown late (overruns)
G_PTOP          rs.w    1               ; playfield top line (256 - LINES) / 2
G_RACE          rs.w    1               ; race 0-5 (Practice .. Ultimate)
G_TSHOWN        rs.w    1               ; the time the panel shows ($FFFF GAME OVER,
                                        ; $FFFE TIMER OFF)
G_TIMOFF        rs.w    1               ; key C: the race timer frozen (play-testing; kept
                                        ; across restarts and race changes)
G_LINL          rs.w    1               ; lines of the race's bitmap
G_SLTAB         rs.l    1               ; the race's slope dispatch table (slp_tab<N>)
G_SLTABO        rs.l    1               ; the same for objects (slp_tabo<N>)
G_SPAWN         rs.l    1               ; the race's spawn list (PLAY blob, PH_SPAWN)
G_OBJON         rs.w    1               ; 1 = the object slots run (mm_dat races)
G_MOVM          rs.w    1               ; bit per slot: an object with logic there
G_RANM          rs.w    1               ; bit per slot: its object ran this logic step
G_DUE           rs.b    4               ; per frame & 3: a bit per slot whose object runs
                                        ; then (obj_mark, by obj_odd's rate class)
G_RSPR          rs.l    1               ; the race-wide object pictures (rspr_build)
G_SLON          rs.w    1               ; 1 = the race's slinky pictures are in the cache
G_OSUB          rs.w    1               ; 1 = a slinky runs one logic step of its pair
G_ANN           rs.w    1               ; animated cell groups (0 none; anim_update)
G_ANC           rs.w    1               ; (anim build: the column)
G_SPTAG         rs.w    1               ; (eb_sprites: the sprite list tag painted)
G_GSCH          rs.l    1               ; (eb_sprites: 0, or the GOAL text's colour table
                                        ;  used instead of the colour map: flag_build)
G_FLM           rs.l    1               ; (flag_build: the next flag's opaque bits)
G_ANCN          rs.w    1               ; anim_update: the cell groups (before the flags')
G_ANL0          rs.w    1               ; the flags' and GOAL's groups: bitmap lines
G_ANL1          rs.w    1               ; [ANL0, ANL1) (ANL1 = 0: none)
G_FC95          rs.w    1               ; the frame counter when G_WR95 was set (the GOAL
                                        ; text's handler ran before it that frame)
G_FLL0          rs.w    1               ; the goal flags' boxes: bitmap lines [FLL0, FLL1)
G_FLL1          rs.w    1               ; (0, 0: none; flag_cover's quick test)
G_MXSPR         rs.l    1               ; the held marble's tile pictures (mx_load; 0 none)
G_FRX           rs.b    16              ; (frag_pos: the fragments' x [8], y [8]; $F8 none)
G_FRL           rs.b    16              ; (mx_frag: the fragments drawn, in draw order)
G_MZST          rs.l    1               ; Ultimate's goal maze: the store (0 none): pictures,
G_MZOF          rs.l    1               ; the cells' bitmap addresses,
G_MZBA          rs.l    1               ; the map's picture per cell,
G_MZCU          rs.l    1               ; the picture each cell shows,
G_MZLI          rs.l    1               ; the states' lists
G_MZN           rs.w    1               ; the cells
G_MZLS          rs.w    1               ; the last state applied (-1 none)
G_MZFL          rs.l    1               ; the cells' flag bytes (0 none, else under flag k + 1)
G_MZFC          rs.l    1               ; the flag cells (word n, n x cell x 4)
G_MZVS          rs.w    1               ; the flags' frame x 32 their cells show
G_MZY0          rs.w    1               ; the flag cells' bitmap lines [Y0, Y1)
G_MZY1          rs.w    1
G_MZFI          rs.w    1               ; the flags' frame at the load x 32 (MZ_FINIT)
G_MZPD          rs.w    1               ; the states written, not yet applied
G_MZSS          rs.w    1               ; the maze state at the last maze_update
G_MZEI          rs.w    1               ; the next state's list: where its applying stopped
G_MZRI          rs.w    1               ; a reset (restart): its next cell (-1 none)
G_MZCT          rs.w    1               ; 1 = catching up (MZ_CAP cells a frame)
G_PPST          rs.l    1               ; Aerial's piston field: the store (0 none)
G_PPDAT         rs.l    1               ; its PLAY section (PH_PIST)
G_PLMASK        rs.w    1               ; the columns present (bits) at the last draw
G_PSNAP         rs.b    36              ; the cells before the last odd frame's step
G_PLAST         rs.b    36              ; the cells of the last draw
G_PGRID         rs.b    12+108          ; the grid (12 bytes below it: room for writes there)
G_PSHOWN        rs.b    108             ; the tile each entry shows ($FF none)
G_WVST          rs.l    1               ; Intermediate's water: the store (0 none): the
G_WVOF          rs.l    1               ; pictures, the cells' addresses,
G_WVTG          rs.l    1               ; the picture per cell the logic sets (bytes),
G_WVCU          rs.l    1               ; the one the bitmap shows,
G_WVFL          rs.l    1               ; the cells' flags (in the list: $FF),
G_WVDL          rs.l    1               ; the list of cells to look at (bytes),
G_WVLI          rs.l    1               ; the patches' lists by step,
G_WVCM          rs.l    1               ; their compatibility rows
G_WVDP          rs.l    1               ; the list's end
G_WVBS          rs.l    1               ; the map's picture per cell (bytes),
G_WVRW          rs.l    1               ; the cells' rows (bytes), each row's first cell
G_WVRS          rs.l    1
G_WVR0          rs.w    1               ; the cells' first row, their rows
G_WVNR          rs.w    1
G_WVW           rs.w    1               ; the window's top row last seen ($8000 none)
G_WVY0          rs.w    1               ; the cells' bitmap lines [Y0, Y1)
G_WVY1          rs.w    1
G_WVL1          rs.w    1               ; the last patch written (-1 none)
G_WVL2          rs.w    1               ; and the one before it
G_ANG           rs.b    AN_MAX*AN_SIZE  ; their descriptors (AN_*)
G_SLOFF         rs.w    1               ; 1 = the race has slinkies, but no room: off
G_CUSE          rs.l    1               ; bytes of the sprite cache in use (this race)
G_CMAX          rs.l    1               ; the most ever used (cache_check skips them)
G_DC            rs.w    1               ; obj_collide's result (0, 1, $80 or $FE)
G_C14           rs.w    1               ; obj_collide's |dX| and |dY| on a hit
G_C15           rs.w    1
G_OFRM          rs.l    1               ; the objects' pictures (PLAY blob, PH_OFRM)
G_OSPR          rs.l    1               ; the slots' pre-shifted sprites (race area)
G_OSTY          rs.b    6               ; per slot 2-7: the type whose pictures its area
                                        ; holds (obj_sprites; 0 none: a race load, or a
                                        ; falling object's picture built there)
G_LTICK         rs.w    1               ; tick at the last logic_qlframe
G_SACC          rs.w    1               ; logic clock: 6 x ticks not yet run (0-4)
G_STEPS         rs.w    1               ; logic steps run this QL frame
G_SCAP          rs.w    1               ; QL frames whose steps were capped
G_STOT          rs.l    1               ; logic steps run in all (game time)
G_TTOT          rs.l    1               ; ticks counted by the logic clock
G_SLOST         rs.l    1               ; steps dropped by the cap
G_FT0           rs.w    1
G_SLACK         rs.w    1
G_K             rs.l    1
G_WSPIN         rs.l    1
G_FPSM          rs.w    1               ; the frame rate: 0 adaptive, 1 fixed 10, 2 fixed
                                        ; 12.5 fps (G_TFPS at start; key F cycles it)
G_FSW           rs.w    1               ; adaptive: rate switches (both ways)
G_BOFF          rs.w    1               ; adaptive: frames left at 5 ticks before a retry
G_BOFFL         rs.w    1               ; adaptive: the next back-off (doubles on failure)
G_RUN125        rs.w    1               ; adaptive: on-time frames at 4 ticks in a row
G_F10           rs.l    1               ; frames shown at 10 fps (5 ticks)
G_F125          rs.l    1               ; frames shown at 12.5 fps (4 ticks)
G_VIEW          rs.w    1               ; bitmap row at screen line 0
G_OVL           rs.w    1               ; panel on
G_QUIT          rs.w    1
G_KRALIVE       rs.w    1
G_WFR           rs.w    1
G_WT0           rs.w    1
G_FPS10         rs.w    1
G_MS100         rs.w    1
G_TFR           rs.l    1
G_TB            rs.l    1
G_MS10W         rs.w    1
G_FRAMES        rs.l    1
G_TT            rs.l    1
G_TICKP         rs.l    1
G_POLLOK        rs.w    1
G_HGT           rs.w    1
G_LINES         rs.w    1
G_CLR0          rs.w    1
G_CLR1          rs.w    1
G_PAUSE         rs.w    1
        ifeq    RELB
G_MODE          rs.w    1               ; measuring mode 0-4
        endc
G_PAD           rs.w    1               ; input bits latched this QL frame
G_PPAD          rs.w    1               ; last frame's
G_PNEW          rs.w    1               ; newly pressed
G_KEYROW        rs.w    1               ; raw KEYROW row 1
        ifeq    RELB
G_BENCH         rs.w    1               ; 0 off, 1-5 = mode being measured + 1
G_BRES          rs.w    N_MODES         ; benchmark: MS x100 per mode
G_LDT           rs.w    8               ; test G_TLAB = 2: load ticks (start, races 1-6)
        endc
G_GOALT         rs.w    1               ; frames to the restart after the goal
G_SPX           rs.w    1               ; sprite drawn: screen x, y, frame (-1 none)
G_SPY           rs.w    1
G_SPF           rs.w    1
G_SPN           rs.w    1               ; draw_marble locals
G_SP0           rs.l    1               ; stack pointer at entry (where BASIC's stack is)
G_TKON          rs.w    1               ; takeover active
G_TKERR         rs.w    1               ; takeover refused / IPC timeouts
G_PCINT         rs.w    1               ; QDOS's pc_intr mask bits (sv_pcint)
G_SSP0          rs.l    1               ; QDOS's supervisor stack pointer
G_TKQN          rs.w    1               ; typed keys queued
G_TKQ           rs.b    8
        ifeq    RELB
G_CCHK          rs.w    1               ; cache check: 0 not run, else 1 + longs changed
        endc
G_TSTK          rs.b    TK_STK          ; our stack (user mode; takeover: supervisor)
        ifeq    RELB
G_NOKILL        rs.w    1               ; LAB: 1 = skip the behind-scenery kill check
G_DEMO          rs.w    1               ; 1 = input from the demo table, not KEYROW
G_DPOS          rs.w    1               ; demo: next QL frame
G_LABOK         rs.w    1               ; LAB results on the panel
G_LT0           rs.w    1               ; lab_time locals
G_LN            rs.w    1
G_LA2           rs.l    1
G_LSAV          rs.l    1               ; LAB: the caller's stack pointer
G_LPP           rs.w    1               ; LAB: previous demo input
G_LDP           rs.w    1               ; LAB: demo frame
G_LSCR          rs.l    1               ; LAB: code copy on screen line 255
G_LSKC          rs.l    1               ; LAB: code copy on the caller's stack
G_LAB           rs.l    N_LAB           ; LAB results (1/100 us per unit, see lab_run)
G_TDIRTY        rs.w    1               ; bit 0/1: screen 0/1's panel is out of date
G_GLYPHS        rs.l    1               ; panel glyphs drawn since the start
G_PANELS        rs.l    1               ; draw_panel calls
        endc
G_OCCON         rs.w    1               ; 1 = the marble is masked behind scenery (M)
G_HMASK         rs.w    1               ; this frame's marble has a hide mask
G_ONW           rs.w    1               ; occ_build locals: words a row, line in band,
G_OF            rs.w    1               ; first column, any code found
G_OC0           rs.w    1
G_OANY          rs.w    1
G_ONC           rs.w    1               ; columns: 3 (16-px frame) or 4 (24-px)
G_OBL           rs.w    1               ; lines left in the band - 1
G_OCP           rs.l    4               ; the 4 columns' code pointers (0 = none)
G_OPB           rs.l    12              ; per band and column: its pattern row (two
G_OPB2          rs.l    12              ;  buffers: G_OPBO = this frame's offset, the
G_OPBO          rs.w    1               ;  other the last hide words' rows)
G_HIDE          rs.b    16*16           ; hide words: 16 lines x 8 words
G_HRM           rs.w    1               ; occ_build: bit l = line l of G_HIDE not all clear
G_HRT           rs.w    1               ; draw_marble: G_HRM from the first row drawn
G_OCV           rs.w    1               ; occ_build: bit 1 = G_HIDE / G_HRM are those of
                                        ; G_HKX, G_HKW and the other G_OPB buffer (0 at a
                                        ; race load: a new GEO blob)
G_HKX           rs.l    1               ; the last hide words' G_OF and c, G_ONW (their
G_HKW           rs.w    1               ;  pattern rows: G_OPB / G_OPB2, the other one)
        ifeq    RELB
G_LSTK          rs.b    LAB_STK         ; LAB: a stack inside the globals
G_TEXT          rs.b    TEXT_LEN        ; glyph codes, 4 lines
G_SHAD0         rs.b    TEXT_LEN        ; what screen 0 shows ($FF = unknown)
G_SHAD1         rs.b    TEXT_LEN        ; what screen 1 shows
        endc
G_HUDT          rs.b    64              ; the HUD's line: glyph codes
G_HQN0          rs.w    1               ; screen 0: columns queued to draw (hud_draw)
G_HQ0           rs.b    64              ; ... the columns
G_HQN1          rs.w    1               ; screen 1 (dual): the same
G_HQ1           rs.b    64
G_HSCORE        rs.l    1               ; the score / time / race the HUD's text
G_HTIME         rs.w    1               ; holds (-1 / -3: unknown; time $FFFE OFF)
G_HRACE         rs.w    1
G_HFMTW         rs.w    1               ; byte 0: hud_fmt queued columns this frame
G_HCHG          rs.w    1               ; byte 0: the score or time changed (fmt_time)
G_HBUDS         rs.w    1               ; hud_draw: glyphs a call may draw (HUD_BUD;
                                        ; top_now: all)
G_HTOVR         rs.w    1               ; bit 15: show this time (the TIME TO FINISH
                                        ; count: src/frontend.asm fe_itime)
G_MB            rs.b    M_SIZE          ; the marble
G_OBJ           rs.b    M_SIZE*6        ; the object slots 2-7 (src/mobj.asm)
G_WD7           rs.w    1               ; the spawn walker: list byte offset
G_WD8           rs.w    1               ; entry index
G_WR95          rs.w    1               ; the static objects' attribute (the marble
                                        ; logic sets it to 2 at the goal line: mlogic)
G_WE5           rs.w    1               ; slot 3 / 6's object word (as at the start)
G_WE8           rs.w    1
G_WZ79          rs.w    1               ; the last acid pool / slinky spawn's Z
G_WF7DD         rs.w    1               ; the hammers' phase (+4 every 256 steps)
G_WP2X          rs.w    1               ; player 2's X (slot 1: read by the vacuum's pull)
G_WA5A9         rs.b    16              ; per entry: 0 / 1 spawned / $FF never again
G_WA565         rs.b    16              ; per entry: its slot
G_WP6D7         rs.b    36              ; Aerial's piston cells: 0 idle, 1-15 up/down
G_WP7DA         rs.b    3               ; per group: 1 = player 1 outside its box
G_WP9E          rs.b    3               ;  its script position
G_WPA1          rs.b    3               ;  delay
G_WPA4          rs.b    3               ;  loop count
G_WPA7          rs.b    3               ;  loop start
                rs.b    1
G_WEND          rs.b    0               ; (G_MB to here: the race's start image)
        ifeq    RELB
G_GHOST         rs.b    M_SIZE*N_GHOST  ; measuring mode 1
        endc
G_SCSHOWN       rs.l    1               ; the score the panel shows (-1 unknown)
G_FETICK        rs.l    1               ; (src/frontend.asm: its loops' ticks)
G_FENL          rs.w    1               ; the name entry: letters so far
G_FECUR         rs.w    1               ;  the grid's cursor (0-25 A-Z, 26 RUB, 27 END)
G_FEPAD         rs.w    1               ;  KEYROW row 1 last time (the new presses)
G_FERANK        rs.w    1               ;  the new entry's rank (-1 none)
G_FETO          rs.w    1               ;  ticks left on this screen (then as ENTER)
G_INTRO         rs.w    1               ; frames to the TIME TO FINISH box (0 none)
G_HI            rs.b    10*9            ; the HIGH ROLLERS table (src/frontend.asm)
G_FEN           rs.b    6               ; the name being entered (ASCII)
G_FELINE        rs.b    32              ; a line of text being made
G_KRPREV        rs.w    1               ; KEYROW row 1 last frame (ENTER, \: new presses
                                        ; only; $FF after a frontend screen, fe_wait)
G_MUTE          rs.w    1               ; \: the sound muted (AY volumes 0, no BEEPs)
G_MWRR          rs.l    1               ; muted: the board's own writer (G_MWR = mus_wrm)
G_BKILL         rs.w    1               ; the beeper: a kill-sound due (mute pressed)
        ifeq    RELB
G_TFLG          rs.w    1               ; telemetry: this frame's events (bit 0 a BEEP /
                                        ; kill sent, 3 the typed keys read, 5 the input
                                        ; skipped for a BEEP; cleared at each record)
G_TSPR          rs.w    1               ; telemetry: sprites drawn this frame (spr_put,
                                        ; spr_puts; the marble not counted)
G_TVIEW         rs.w    1               ; telemetry: G_VIEW at the last record
        endc
G_LFT           rs.w    1               ; the marble's drawn lift from the fan / the waves:
                                        ; the fan lift, else the wave lift, as before the
                                        ; last logic step (drawn before the race routine
                                        ; sets them)
G_WHD           rs.w    1               ; Beginner's bowl: the player's whirl depth (the
                                        ; marble drawn that much lower), this step's
G_DRP           rs.w    1               ; ... as before the last logic step (lift_save): drawn
G_KRSOLO        rs.w    1               ; row_keys: the key (bit 0 ENTER, 5 \) whose own
                                        ; action this hold did (undone by ENTER + \)
G_REL           rs.w    1               ; the release (G_TAKE 3): no typed keys read in
                                        ; play (ESC from KEYROW), no measuring keys
G_END           rs.b    0
        ifne    G_END&1
        fail    "globals block size must be even"
        endc
        ifne    M_SIZE&1
        fail    "marble block size must be even"
        endc

;=============================================================================
start:
        bra.w   init
globals:
        ds.b    G_END
        even

init:
        movem.l d1-d7/a0-a6,-(sp)
        lea     globals(pc),a6
        ; our own stack in both modes: the load path needs ~540 bytes and BASIC's
        ; stack has no promised room (on Minerva a deep CALL can corrupt BASIC,
        ; depending on the program's size); takeover keeps it as the supervisor stack
        move.l  sp,G_SPB(a6)
        lea     G_TSTK+TK_STK(a6),sp
        tst.w   G_TLOGO(a6)             ; the loader's first CALL: the loading
        beq.s   .game                   ; screen only (mm_dat loads under it)
        clr.w   G_TLOGO(a6)
        FARCALL fe_loadlogo
        movea.l G_SPB(a6),sp
        movem.l (sp)+,d1-d7/a0-a6
        moveq   #0,d0
        rts
.game:  lea     G_RUNTIME(a6),a0
        move.w  #(G_END-G_RUNTIME)/2-1,d0
.clr:   clr.w   (a0)+
        dbra    d0,.clr

        ifeq    RELB
        moveq   #2,d0                   ; the top band: G_TPANEL 0 the HUD, 1 the
        sub.w   G_TPANEL(a6),d0         ; panel, 2 nothing -> G_OVL 2, 1, 0
        bpl.s   .ov
        moveq   #2,d0
.ov:    move.w  d0,G_OVL(a6)
        else
        move.w  #2,G_OVL(a6)            ; (the HUD)
        endc
        bsr     hud_reset
        move.w  #1,G_OCCON(a6)
        move.w  #N_MIN,G_NT(a6)
        move.w  G_TFPS(a6),d0           ; the loader's frame rate: 0 adaptive, 1 fixed
        cmpi.w  #3,d0                   ; 10 fps, 2 fixed 12.5 fps
        blo.s   .fpm
        moveq   #0,d0
.fpm:   move.w  d0,G_FPSM(a6)
        move.w  #BOFF_BASE,G_BOFFL(a6)
        move.w  #$FF,G_KRPREV(a6)       ; (ENTER from the loader's key: once released)
        clr.w   G_KRSOLO(a6)
        clr.w   G_LFT(a6)
        clr.w   G_REL(a6)
        cmpi.w  #3,G_TAKE(a6)           ; the release: KEYROW only in play
        bne.s   .nrel
        move.w  #1,G_REL(a6)
.nrel:
        move.w  #-1,G_STEPS(a6)        ; (the panel shows the first count)
        move.w  #-2,G_TSHOWN(a6)        ; (and the first time)
        clr.w   G_RACE(a6)              ; Practice
        lea     slp_tab0(pc),a0
        move.l  a0,G_SLTAB(a6)
        move.w  #-1,G_DMODE(a6)
        move.w  #-1,G_SPF(a6)
        move.l  #SCREEN,G_DEST(a6)
        moveq   #0,d0                   ; H224
        ifeq    RELB
        move.w  G_THGT(a6),d1
        beq.s   .h0
        move.w  d1,d0
        subq.w  #1,d0
.h0:    cmpi.w  #3,d0
        blo.s   .h1
        moveq   #0,d0
.h1:    move.w  d0,G_HGT(a6)
        else
        move.w  d0,G_HGT(a6)
        endc
        bsr     set_height
        ifeq    RELB
        move.w  G_TMODE(a6),d0
        beq.s   .m0
        subq.w  #1,d0
.m0:    cmpi.w  #N_TMODES,d0
        blo.s   .m1
        moveq   #0,d0
.m1:    move.w  d0,G_MODE(a6)
        endc
        move.w  #LIN_LINES,G_LINL(a6)   ; (the single-race mm1_* files)
        tst.l   G_DAT(a6)
        beq.s   .old
        bsr     boot_data               ; mm_dat: the shared data, the marble bank,
        ifeq    RELB
        move.w  G_TRACE(a6),d0          ; then Practice (test loader: race + 1)
        beq.s   .trc
        subq.w  #1,d0
.trc:   FARCALL load_race               ; (the test build: past bsr's reach)
        else
        moveq   #0,d0                   ; then Practice
        bsr     load_race
        endc
.old:   bsr     restart
        ifeq    RELB
        bsr     ghosts_init
        endc

        moveq   #MT_INF,d0
        trap    #1
        move.l  a0,G_SYS(a6)
        move.l  d2,G_VER(a6)
        ifne    MUS_ON
        bsr     mus_detect              ; the AY board (QDOS still ours to ask)
        endc
        move.b  SV_MCSTA(a0),G_MCSTA0+1(a6)
        bsr     open_console
        bsr     poll_link
        bsr     clock_check
        bsr     detect_dual
        bsr     calibrate
        ifeq    RELB
        bsr     tel_init                ; (telemetry: the buffer's header, if any)
        endc
        tst.w   G_TAKE(a6)
        beq.s   .ntk
        bsr     tk_enter                ; the machine to ourselves
.ntk:
        ifeq    RELB
        move.w  G_TSYNC(a6),d0
        beq.s   .sd
        subq.w  #1,d0
        bra.s   .ss
        endc
.sd:    moveq   #1,d0
        tst.w   G_DUAL(a6)
        beq.s   .ss
        moveq   #2,d0
.ss:    cmpi.w  #3,d0
        blo.s   .sk
        moveq   #0,d0
.sk:    move.w  d0,G_SYNC(a6)

        move.l  sp,G_SP0(a6)
        ifeq    RELB
        bsr     text_init
        endc
        move.l  #-1,G_SCSHOWN(a6)
        FARCALL fe_init                 ; the HIGH ROLLERS table: its defaults
        bsr     apply_sync
        bsr     fmt_settings
        ifeq    RELB
        move.w  G_TDEMO(a6),d0          ; test loader: 1 = demo, 2 = the benchmark
        beq.s   .nd
        move.w  #1,G_DEMO(a6)
        bsr     demo_start
        cmpi.w  #2,G_TDEMO(a6)
        bne.s   .nd
        move.w  #1,G_BENCH(a6)
        moveq   #0,d0
        bsr     set_mode
        bsr     fmt_bench
.nd:    tst.w   G_TLAB(a6)
        beq.s   .nl
        cmpi.w  #2,G_TLAB(a6)
        bne.s   .lab
        tst.l   G_DAT(a6)
        beq.s   .lab
        bsr     load_times              ; test loader 2: the load times, then out
        bra     quit
.lab:   bsr     lab_run                 ; test loader: LAB, then straight out
        bra     quit
        endc
.nl:    FARCALL fe_title                ; the start screen (src/frontend.asm)
        tst.w   G_QUIT(a6)
        bne     quit
        ifne    MUS_ON
        bsr     mus_race                ; the race's tune
        endc
        bsr     stats_reset
        bsr     top_now                 ; (the top band whole now: not in a game frame)
        bsr     logic_resync            ; the logic clock starts now
        move.w  #2,G_INTRO(a6)          ; (the first race's box: after its first frame)
        ifeq    RELB
        tst.w   G_TEND(a6)              ; test loader (mme_bas): Ultimate's goal reached
        beq.s   main_loop               ; with these, so next_race: the ending, the high
        move.w  G_TEND(a6),d0           ; scores, then a new game
        subq.w  #1,d0
        move.w  d0,G_MB+M_TIME(a6)
        move.w  G_TENDD(a6),G_MB+M_DEATHS(a6)
        move.l  G_TENDS(a6),G_MB+M_SCORE(a6)
        move.w  #5,G_RACE(a6)
        bsr     next_race
        endc

;-----------------------------------------------------------------------------
main_loop:
        tst.w   G_INTRO(a6)             ; a race's TIME TO FINISH box, once its screen
        beq.s   .ml                     ; is shown (src/frontend.asm fe_intro)
        subq.w  #1,G_INTRO(a6)
        bne.s   .ml
        FARCALL fe_intro
.ml:
        ifeq    RELB
        moveq   #0,d0
        move.w  G_TFRAMES(a6),d0
        beq.s   .run
        cmp.l   G_FRAMES(a6),d0
        bls     quit
        endc
.run:   bsr     read_input
        tst.w   G_QUIT(a6)
        bne     quit
input_done:                             ; (global: the emulator test hooks it)
        bsr     tk_poll
        bsr     logic_qlframe
        ifne    MUS_ON
        bsr     mus_frame               ; its effects (started at the next tick)
        endc
logic_done:                             ; (global: the emulator test hooks it)
        bsr     tk_poll
        bsr     set_view
        bsr     anim_update             ; the bridge: its cells in the bitmap (in view)
        bsr     maze_update             ; Ultimate's goal maze
.farp:  lea     .farp(pc),a0            ; Aerial's pistons (src/mobj.asm: a PC-relative
        adda.l  #piston_draw-.farp,a0   ; far call)
        jsr     (a0)
.farw:  lea     .farw(pc),a0            ; Intermediate's water (src/mobj.asm)
        adda.l  #wave_draw-.farw,a0
        jsr     (a0)
        bsr     tk_poll
        bsr     clear_tail
        ifeq    RELB
        move.w  G_MODE(a6),d0
        cmpi.w  #2,d0
        beq.s   .nocopy
        cmpi.w  #6,d0                   ; 6, 7: the bare loop
        beq.s   .nocopy
        cmpi.w  #7,d0
        beq.s   .nocopy
        endc
        bsr     draw_linear
.nocopy:
frame_drawn:                            ; (global: the emulator test hooks it)
        bsr     tk_poll
        ifeq    RELB
        move.w  G_MODE(a6),d0
        cmpi.w  #3,d0
        beq.s   .nospr
        cmpi.w  #6,d0
        beq.s   .nospr
        cmpi.w  #7,d0
        beq.s   .nospr
        cmpi.w  #8,G_MODE(a6)           ; 8: no objects
        beq.s   .noobj
        endc
.far:   lea     .far(pc),a0             ; draw_objects (under the marble): past bsr
        adda.l  #draw_objects-.far,a0   ; reach (32 KB) from here, so a PC-relative
        jsr     (a0)                    ; far call (a bare bsr would turn absolute)
.noobj:
        bsr     draw_marble
        bsr     flag_cover              ; (the goal flags over it, where they overlap)
.nospr:
sprites_drawn:                          ; (global: the emulator test hooks it)
        bsr     tk_poll
        bsr     fmt_time
        ifeq    RELB
        move.w  G_OVL(a6),d0            ; the top band: 1 the panel, 2 the HUD
        beq.s   .no_ovl
        cmpi.w  #6,G_MODE(a6)           ; 6: not even the panel
        beq.s   .no_ovl
        subq.w  #1,d0
        bne.s   .hud
        bsr     draw_panel
        bra.s   .no_ovl
        endc
.hud:   tst.b   G_HCHG(a6)              ; (the score or time changed: fmt_time)
        beq.s   .hd
        sf      G_HCHG(a6)
        bsr     hud_fmt
.hd:    bsr     hud_draw
.no_ovl:
        bsr     sync_end
        bsr     stats_frame
        bra     main_loop

quit:
        ifne    MUS_ON
        bsr     mus_stop                ; (the chip silent)
        endc
        bsr     tk_exit                 ; (takeover: everything back as it was)
        ifeq    RELB
        bsr     cache_check             ; (test loader: the sprite cache untouched?)
        endc
        tst.w   G_SHOWN(a6)
        beq.s   .s0
        moveq   #0,d0
        bsr     flip_to
.s0:    lea     G_PLINK(a6),a0
        moveq   #MT_RPOLL,d0
        trap    #1
        move.l  G_CON(a6),d0
        beq.s   .nocon
        movea.l d0,a0
        moveq   #IO_CLOSE,d0
        trap    #2
.nocon:
        movea.l G_SPB(a6),sp            ; BASIC's stack again
        movem.l (sp)+,d1-d7/a0-a6
        moveq   #0,d0
        rts

;=============================================================================
; logic_qlframe - the logic steps of this QL frame, at 60 Hz on the 50 Hz
; clock: 6 logic steps per 5 ticks (G_SACC keeps the remainder), so a 10 fps
; frame runs 6 and a frame that overran to 6+ ticks catches up (7, 8, ...),
; at most STEP_CAP (G_SCAP counts the capped frames). The benchmark always
; runs 6. The same clock in QDOS mode (the poll task) and takeover (the frame
; flag). The input is latched once; "newly pressed" only on the first sub-step
; (a frame with 0 steps, in FREE, latches nothing). Mode 1 first runs the same
; on the 9 ghost marbles (identical copies, identical input -> identical cost).
;=============================================================================
logic_qlframe:
        bsr     get_tick
        move.w  d0,d1
        sub.w   G_LTICK(a6),d1          ; ticks since the last frame's logic
        move.w  d0,G_LTICK(a6)
        tst.w   G_PAUSE(a6)
        bne     .idle
        ifeq    RELB
        cmpi.w  #6,G_MODE(a6)           ; the bare loop: no logic
        beq     .idle
        cmpi.w  #7,G_MODE(a6)
        beq     .idle
        tst.w   G_BENCH(a6)             ; benchmark: exactly 6, off the clock
        beq.s   .clk                    ; (its figures stay comparable)
        moveq   #SUBSTEPS,d1
        bra.s   .n
        endc
.clk:   cmpi.w  #DT_CAP,d1
        bls.s   .dt
        moveq   #DT_CAP,d1
.dt:    moveq   #0,d0
        move.w  d1,d0
        add.l   d0,G_TTOT(a6)
        mulu.w  #SUBSTEPS,d1
        add.w   G_SACC(a6),d1
        divu.w  #5,d1                   ; steps, remainder
        swap    d1
        move.w  d1,G_SACC(a6)
        swap    d1
        cmpi.w  #STEP_CAP,d1
        bls.s   .tot
        moveq   #0,d0
        move.w  d1,d0
        subi.w  #STEP_CAP,d0
        add.l   d0,G_SLOST(a6)
        addq.w  #1,G_SCAP(a6)
        moveq   #STEP_CAP,d1
.tot:   moveq   #0,d0
        move.w  d1,d0
        add.l   d0,G_STOT(a6)
.n:     bsr     show_steps
        tst.w   d1
        beq     .out                    ; (FREE: no logic step due yet)
        move.w  G_PAD(a6),d0
        move.w  G_PPAD(a6),d1
        not.w   d1
        and.w   d0,d1
        move.w  d1,G_PNEW(a6)
        move.w  d0,G_PPAD(a6)
        ifeq    RELB
        cmpi.w  #1,G_MODE(a6)
        bne.s   .real
        lea     G_GHOST(a6),a4
        moveq   #N_GHOST-1,d0
.gh:    move.w  d0,-(sp)
        bsr     tk_poll
        bsr     run_steps
        lea     M_SIZE(a4),a4
        move.w  (sp)+,d0
        dbra    d0,.gh
        endc
.real:  bsr     tk_poll
        lea     G_MB(a6),a4
        bsr     run_steps
        ; after the goal or the time out: 3 s (of logic steps) later, the next race
        ; (Ultimate -> Practice) or, timed out, GAME OVER -> a new game at Practice
        tst.b   G_MB+M_RACING+1(a6)
        bne.s   .out
        tst.l   G_DAT(a6)               ; the time out: the game over now
        beq.s   .gw
        tst.b   G_MB+M_PRESENT+1(a6)
        beq.s   .over
        tst.b   G_MB+M_CA+1(a6)         ; the time bonus given: its box (play
        beq.s   .gw                     ; stopped), then the next race
        FARCALL fe_bonus
        tst.w   d0
        beq.s   .gw                     ; (no box: demo, benchmark, test loaders)
        tst.w   G_QUIT(a6)
        bne     .out
        bra     next_race
.gw:    tst.w   G_GOALT(a6)
        bne.s   .gt
        move.w  #GOAL_WAIT,G_GOALT(a6)
        bra.s   .out
.gt:    move.w  G_STEPS(a6),d0
        sub.w   d0,G_GOALT(a6)
        bgt.s   .out
        tst.l   G_DAT(a6)
        beq.s   .rs                     ; (the single-race mm1_* files: restart)
        tst.b   G_MB+M_PRESENT+1(a6)
        beq.s   .over
        bra     next_race
.over:  moveq   #1,d0                   ; OUT OF TIME / GAME OVER, the high scores
        FARCALL fe_gameover             ; (src/frontend.asm)
        tst.w   G_QUIT(a6)
        bne.s   .out
        moveq   #0,d0                   ; a new game
        bra     goto_race
.rs:    bsr     restart
        ifeq    RELB
        bsr     ghosts_init             ; (mode 1: the ghosts restart with it)
        endc
.out:   rts
.idle:  moveq   #0,d1                   ; paused / bare loop: the time is not owed
        bsr     show_steps
        move.w  G_PAD(a6),d0            ; (the input latched, as above)
        move.w  G_PPAD(a6),d1
        not.w   d1
        and.w   d0,d1
        move.w  d1,G_PNEW(a6)
        move.w  d0,G_PPAD(a6)
        rts

; show_steps - G_STEPS = d1.w, and on the panel (SUBn) when it changed
show_steps:
        cmp.w   G_STEPS(a6),d1
        beq.s   .o
        move.w  d1,G_STEPS(a6)
        ifeq    RELB
        movem.l d0-d1/a0,-(sp)
        lea     G_TEXT(a6),a0
        moveq   #CH_SPC,d0
        cmpi.w  #10,d1
        blo.s   .one
        subi.w  #10,d1
        move.b  d1,TX_SUB+1(a0)         ; 10-12: "1" + the units
        moveq   #1,d1
        bra.s   .w
.one:   move.b  d0,TX_SUB+1(a0)
.w:     move.b  d1,TX_SUB(a0)
        move.w  #3,G_TDIRTY(a6)
        movem.l (sp)+,d0-d1/a0
        endc
.o:     rts

; logic_resync - the logic clock restarts from now (after a stall that is not
; game time: the start, the LAB); the remainder is kept
logic_resync:
        move.l  a0,-(sp)
        move.w  d0,-(sp)
        bsr     get_tick
        move.w  d0,G_LTICK(a6)
        move.w  (sp)+,d0
        movea.l (sp)+,a0
        rts

; run_steps - G_STEPS logic steps on the marble block at a4 (6: unrolled)
run_steps:
        move.w  G_STEPS(a6),d0
        cmpi.w  #SUBSTEPS,d0
        beq.s   run_substeps
        move.w  G_PAD(a6),M_PAD(a4)
        move.w  G_PNEW(a6),M_PADNEW(a4)
        subq.w  #1,d0
.l:     move.w  d0,-(sp)
        bsr     lift_save
        bsr     marble_frame
        clr.w   M_PADNEW(a4)
        bsr     tk_poll
        move.w  (sp)+,d0
        dbra    d0,.l
        rts

; run_substeps - a4 = marble block: 6 logic steps (the LAB times this)
run_substeps:
        move.w  G_PAD(a6),M_PAD(a4)     ; the same input for all 6
        move.w  G_PNEW(a6),M_PADNEW(a4) ; "newly pressed" on the first only
        bsr     marble_frame
        clr.w   M_PADNEW(a4)
        bsr     tk_poll                 ; (takeover: the frame clock, every step)
        rept    SUBSTEPS-2
        bsr     marble_frame
        bsr     tk_poll
        endr
        bsr     lift_save
        bsr     marble_frame
        rts

; lift_save - (the player's block, a4) before a logic step: the lift the marble
; is drawn with that step (the fan lift M_F7EF, else the wave lift M_FB, else
; the ridge lift M_FD; the fan's and the waves' as the previous step left them,
; the race routine running after the drawing; the ridges' this step's, from
; the surface lookup, draw_marble). Also Beginner's bowl's drop (set by its
; race routine too: the previous step's). Uses d1.
lift_save:
        move.l  a4,d1
        sub.l   a6,d1
        cmpi.l  #G_MB,d1
        bne.s   .x
        move.w  G_WHD(a6),G_DRP(a6)
        move.w  M_F7EF(a4),d1
        bne.s   .s
        move.w  M_FB(a4),d1
.s:     move.w  d1,G_LFT(a6)
.x:     rts

; restart - the race-start state (Practice: the state at the first step of
; control)
restart:
        lea     G_MB(a6),a4
        clr.w   G_GOALT(a6)
        clr.w   G_LFT(a6)
        clr.w   G_WHD(a6)
        clr.w   G_DRP(a6)
; restart_a4 - the start state into the marble block at a4
restart_a4:
        tst.l   G_DAT(a6)
        beq     .old
        movea.l G_RBUF(a6),a0           ; mm_dat: the PLAY blob's start image
        move.l  PH_START(a0),d0
        adda.l  d0,a0
        ifeq    RELB
        move.l  G_TIMG(a6),d0           ; (a test loader's bench position instead)
        beq.s   .ti
        lea     G_MB(a6),a1
        cmpa.l  a1,a4
        bne.s   .ti
        movea.l d0,a0
        endc
.ti:    movea.l a4,a1
        moveq   #M_SIZE/2-1,d0
.cp:    move.w  (a0)+,(a1)+
        dbra    d0,.cp
        lea     G_MB(a6),a1             ; the real marble: the objects and the
        cmpa.l  a1,a4                   ; spawn walker too
        bne.s   .o
        lea     G_OBJ(a6),a1
        move.w  #(G_WEND-G_OBJ)/2-1,d0
.co:    move.w  (a0)+,(a1)+
        dbra    d0,.co
        move.w  #1,G_OBJON(a6)
.fsl:   lea     .fsl(pc),a0             ; slink_slots_off (no room for the slinkies'
        adda.l  #slink_slots_off-.fsl,a0 ; pictures): a PC-relative far call
        jsr     (a0)
        movem.l d0-d1/d7/a4,-(sp)       ; the objects there: their sprites
        lea     G_OBJ(a6),a4
        moveq   #5,d7
        clr.w   G_MOVM(a6)
        clr.l   G_DUE(a6)
.os:    FARCALL obj_mark                ; (src/mobj.asm: beyond a bsr's reach)
        tst.w   M_STATE(a4)
        beq.s   .on
.fos:   lea     .fos(pc),a0             ; obj_sprites (a PC-relative far call)
        adda.l  #obj_sprites-.fos,a0
        jsr     (a0)
.on:    lea     M_SIZE(a4),a4
        dbra    d7,.os
        movem.l (sp)+,d0-d1/d7/a4
.o:     rts
.old:   movea.l a4,a0
        moveq   #M_SIZE/2-1,d0
.c:     clr.w   (a0)+
        dbra    d0,.c
        move.l  #ST_X,M_X(a4)
        move.l  #ST_Y,M_Y(a4)
        move.l  #ST_Z,M_Z(a4)
        move.l  #ST_X,M_PX(a4)
        move.l  #ST_Y,M_PY(a4)
        move.w  #ST_VZ,M_VZ(a4)
        move.w  #ST_STATE,M_STATE(a4)
        move.w  #ST_GND,M_GND(a4)
        move.w  #ST_E2,M_E2(a4)
        move.w  #ST_RACING,M_RACING(a4)
        move.w  #ST_CODE,M_CODE(a4)
        move.w  #ST_SCROLL,M_SCROLL(a4)
        move.w  #ST_S,M_S(a4)
        move.w  #ST_DD,M_DD(a4)
        move.w  #ST_FID,M_FID(a4)
        move.w  #ST_BC,M_BC(a4)
        move.w  #ST_CF,M_CF(a4)
        move.w  #ST_TIME,M_TIME(a4)
        move.w  #ST_T43,M_T43(a4)
        move.w  #ST_T48,M_T48(a4)
        move.w  #ST_PRESENT,M_PRESENT(a4)
        move.w  #ST_F5CC,M_F5CC(a4)
        move.w  #ST_F5CD,M_F5CD(a4)
        move.w  #ST_E7,M_E7(a4)
        move.w  #ST_E4,M_E4(a4)
        move.w  #ST_F6,M_F6(a4)
        move.w  #ST_F8,M_F8(a4)
        move.w  #ST_F9B,M_F9B(a4)
        move.w  #ST_F5CE,M_F5CE(a4)
        move.w  #ST_RNG01,M_RNG(a4)
        move.w  #ST_RNG23,M_RNG+2(a4)
        move.w  #ST_RNG45,M_RNG+4(a4)
        rts

        ifeq    RELB
; ghosts_init - copy the marble into the 9 ghosts (entering mode 1)
ghosts_init:
        lea     G_GHOST(a6),a1
        moveq   #N_GHOST-1,d1
.g:     lea     G_MB(a6),a0
        moveq   #M_SIZE/2-1,d0
.w:     move.w  (a0)+,(a1)+
        dbra    d0,.w
        dbra    d1,.g
        rts
        endc

;=============================================================================
; The race flow (the race timer, time per race, bonus time)
; goto_race - race d0.w from its start (keys 1-6; GAME OVER -> 0): its own time
; (the start block's), a new game's freezes; the clock restarts after the load
; next_race - after the goal: race + 1 (Ultimate -> Practice, a new game): from
; Intermediate on, the time left is kept and the race's time added (at most 99),
; and the freezes left this game carry over
;=============================================================================
goto_race:
        movem.l d0-d7/a0-a5,-(sp)
        tst.w   G_TKON(a6)              ; the measuring loader (mmp_tbas, take='measure'):
        beq.s   .ld                     ; mm_dat's RESPR is the takeover's save buffer,
        move.l  G_SAVE(a6),d1           ; its first 32 KB QDOS's $28000-$2FFFF while the
        cmp.l   G_DAT(a6),d1            ; game runs: no race loads, the run ends instead
        bne.s   .ld                     ; (d1, not d0: d0 is the race to load)
        move.w  #1,G_QUIT(a6)
        bra.s   .o
.ld:
        ifne    MUS_ON
        bsr     mus_silence             ; (the tune is in the race area: its ticks
        endc                            ;  off, and the chip silent while it loads)
        bsr     load_race
        bsr     restart
        clr.l   G_MB+M_SCORE(a6)        ; (a new game's; next_race puts it back)
        ifeq    RELB
        bsr     ghosts_init
        endc
        ifne    MUS_ON
        bsr     mus_race                ; the new race's tune
        endc
        bsr     fmt_settings
        bsr     stats_reset
        bsr     top_now                 ; (the top band whole now: not in a game frame)
        bsr     logic_resync
        move.w  #1,G_INTRO(a6)          ; (its TIME TO FINISH box after this frame)
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts

next_race:
        movem.l d0-d7/a0-a5,-(sp)
        move.w  G_MB+M_TIME(a6),d6      ; the time left
        move.w  G_MB+M_F5CC(a6),d5      ; the freezes left this game
        move.w  G_RACE(a6),d0
        addq.w  #1,d0
        cmpi.w  #6,d0
        blo.s   .n
        FARCALL fe_ending               ; after Ultimate: the ending (the bonus),
        tst.w   G_QUIT(a6)              ; then the high scores, then a new game
        bne.s   .o
        moveq   #0,d0
        FARCALL fe_gameover
        tst.w   G_QUIT(a6)
        bne.s   .o
        moveq   #0,d0
        bsr     goto_race
        bra.s   .o
.n:     move.w  d0,d7
        move.l  G_MB+M_SCORE(a6),d4     ; the score carries on
        bsr     goto_race
        move.l  d4,G_MB+M_SCORE(a6)
        move.w  d5,G_MB+M_F5CC(a6)
        cmpi.w  #2,d7                   ; Beginner starts from 0, later races
        blo.s   .o                      ; carry the time left over
        movea.l G_RBUF(a6),a0
        add.w   PH_TIME(a0),d6
        cmpi.w  #99,d6
        bls.s   .t
        moveq   #99,d6
.t:     move.w  d6,G_MB+M_TIME(a6)
        bsr     top_now                 ; (the carried score and time: drawn now,
        bsr     logic_resync            ;  not in a game frame)
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts

; fmt_time - the race timer (or GAME OVER) in the top band's right quarter
; (line 0, columns 55-63), and the score (columns 48-53), when they changed
fmt_time:
        move.l  G_MB+M_SCORE(a6),d0
        cmp.l   G_SCSHOWN(a6),d0
        beq.s   .sc
        move.l  d0,G_SCSHOWN(a6)
        st      G_HCHG(a6)              ; (the HUD: hud_fmt this frame; no panel text)
        ifeq    RELB
        cmpi.w  #2,G_OVL(a6)
        beq.s   .sc
        move.w  #3,G_TDIRTY(a6)
        move.l  d0,d3
        lea     G_TEXT+TX_SCORE+6(a6),a1
        moveq   #3-1,d2
.sd:    moveq   #0,d0
        move.b  d3,d0
        moveq   #2-1,d1
        bsr     put_dec_a1
        lsr.l   #8,d3
        dbra    d2,.sd
        endc
.sc:
        move.w  G_MB+M_TIME(a6),d0
        move.w  G_HTOVR(a6),d1          ; (the TIME TO FINISH count's)
        bpl.s   .tv
        move.w  d1,d0
        andi.w  #$FF,d0
.tv:    tst.b   G_MB+M_PRESENT+1(a6)
        bne.s   .t
        move.w  #$FFFF,d0               ; GAME OVER
.t:     cmpi.w  #$FFFF,d0
        beq.s   .t2
        tst.w   G_TIMOFF(a6)
        beq.s   .t2
        move.w  #$FFFE,d0               ; TIMER OFF
.t2:    cmp.w   G_TSHOWN(a6),d0
        beq.s   .o
        move.w  d0,G_TSHOWN(a6)
        st      G_HCHG(a6)
        ifeq    RELB
        cmpi.w  #2,G_OVL(a6)
        beq.s   .o
        move.w  #3,G_TDIRTY(a6)
        lea     G_TEXT+TX_TIME(a6),a1
        lea     txt_time(pc),a0
        cmpi.w  #$FFFF,d0
        bne.s   .c0
        lea     txt_over(pc),a0
.c0:    cmpi.w  #$FFFE,d0
        bne.s   .c
        lea     txt_toff(pc),a0
.c:     moveq   #9-1,d1
.cp:    move.b  (a0)+,(a1)+
        dbra    d1,.cp
        cmpi.w  #$FFFE,d0
        bhs.s   .o
        andi.l  #$FF,d0
        lea     G_TEXT+TX_TIME+7(a6),a1
        moveq   #2-1,d1
        bsr     put_dec_a1
        endc
.o:     rts

;=============================================================================
; set_view - bitmap row at screen line 0 = scroll - VIEW_SCROLL, clamped
;=============================================================================
set_view:
        move.w  G_MB+M_SCROLL(a6),d0
        subi.w  #VIEW_SCROLL,d0
        bpl.s   .p
        moveq   #0,d0
.p:     move.w  G_LINL(a6),d1
        sub.w   G_LINES(a6),d1
        cmp.w   d1,d0
        ble.s   .s
        move.w  d1,d0
.s:     move.w  d0,G_VIEW(a6)
        rts

;=============================================================================
; draw_marble - the marble's frame (chosen from its state and position, once
; per QL frame) drawn PLAIN into G_DEST,
; pre-shifted, clipped to x 0..255 and y 0..LINES-1, no save/restore.
;
; Frame: dizzy -> $18 + (fc >> 3 & 3); state 1 -> the roll
; table at ((Y << 2 & $F0) | (X >> 2 & 15)) + (Z >> 2 & 15) * 17, 8-bit
; (+$13 if >= $18); state 7 -> $1C + t/2; state 8 ->
; $21 + t/4; states 9/B -> none. Position: x = X - Y + 120 (+ the frame's
; xoff), top line = S - $8000 + 1 + (scroll - VIEW_SCROLL - view).
;=============================================================================
SPN_ROWB        equ     6
OSPN_ROWB       equ     4               ; the objects' spans (spr_build): offset, pairs - 1

draw_marble:
.far:   lea     .far(pc),a0             ; mx_before (under it: held, fragments,
        adda.l  #mx_before-.far,a0      ; sparkle; src/mobj.asm): a PC-relative far
        jsr     (a0)                    ; call (past bsr reach)
        lea     G_MB(a6),a4
        move.w  #-1,G_SPF(a6)
        move.w  M_STATE(a4),d0
        cmpi.w  #ST_DEAD,d0
        beq     .none
        cmpi.w  #ST_WAIT,d0
        beq     .none
        cmpi.w  #ST_FUNNEL,d0           ; in a funnel / Ultimate's chutes: frame id 0,
        beq     .none                   ;  not drawn (dizzy or not)
        cmpi.w  #ST_FUNNEL2,d0
        beq     .none
        tst.b   M_DIZZY+1(a4)
        beq.s   .nd
        moveq   #0,d1
        move.b  M_FC+1(a4),d1
        lsr.w   #3,d1
        andi.w  #3,d1
        addi.w  #$18,d1
        bra     .have
.nd:    cmpi.w  #ST_ROLL,d0
        bne.s   .n1
        movea.l G_PGEO(a6),a0
        moveq   #0,d1
        move.b  M_Z+2(a4),d1
        lsr.w   #2,d1
        andi.w  #15,d1
        mulu.w  #17,d1
        moveq   #0,d2
        move.b  M_Y+2(a4),d2
        lsl.w   #2,d2
        andi.w  #$F0,d2
        moveq   #0,d3
        move.b  M_X+2(a4),d3
        lsr.w   #2,d3
        andi.w  #15,d3
        or.w    d3,d2
        add.w   d2,d1
        andi.w  #$FF,d1                 ; 8-bit index (the sum's carry is dropped)
        lea     GEO_ROLL(a0),a0
        move.b  0(a0,d1.w),d1
        andi.w  #$FF,d1
        cmpi.w  #$18,d1
        blo.s   .have
        addi.w  #$13,d1
        bra.s   .have
.n1:    moveq   #0,d1
        move.b  M_T400+1(a4),d1
        cmpi.w  #ST_BROKEN,d0
        bne.s   .n7
        lsr.w   #1,d1
        addi.w  #$1C,d1
        bra.s   .have
.n7:    cmpi.w  #ST_SINK,d0
        bne     .nac
        lsr.w   #2,d1
        addi.w  #$21,d1
        cmpi.w  #$27,d1
        bhi     .none
        bra.s   .have
.nac:   cmpi.w  #ST_INACID,d0           ; dissolving in a pool: its frame
        bne     .none
        move.w  M_FID(a4),d1
.have:  movea.l G_SPRB(a6),a5
        move.w  d1,G_SPF(a6)
        add.w   d1,d1
        add.w   d1,d1
        move.l  0(a5,d1.w),d1
        beq     .none
        adda.l  d1,a5                   ; the frame record
        ; screen position
        move.l  M_X(a4),d0
        sub.l   M_Y(a4),d0
        asr.l   #8,d0
        addi.w  #120,d0
        add.w   2(a5),d0                ; xoff (-4 for 24-px frames)
        move.w  M_S(a4),d1
        move.l  a4,d2                   ; the player: the fan's / the waves' lift
        sub.l   a6,d2                   ; (G_LFT, lift_save) first
        cmpi.l  #G_MB,d2
        bne.s   .fdo
        move.w  G_LFT(a6),d2
        bne.s   .lft
.fdo:   move.w  M_FD(a4),d2             ; Ultimate's ridges: in state 1
.lft:   tst.w   d2                      ; the marble is drawn the lift (ridges 0-3, waves
        beq.s   .drp                    ; to 23, the fan) px higher, and
        cmpi.w  #ST_ROLL,M_STATE(a4)    ; not at all when that borrows from the screen
        bne.s   .nfd                    ; y's low byte (the masks, chosen from the
        cmp.b   M_S+1(a4),d2            ; unlifted position by occ_build, move with it)
        bhi     .nofd
        sub.w   d2,d1
        bra.s   .nfd
.drp:   move.l  a4,d2                   ; no lift: Beginner's bowl (the player,
        sub.l   a6,d2                   ; state 1, M_F6 set): the whirl px lower (G_DRP:
        cmpi.l  #G_MB,d2                ; the previous step's, lift_save)
        bne.s   .nfd
        cmpi.w  #ST_ROLL,M_STATE(a4)
        bne.s   .nfd
        tst.w   M_F6(a4)
        beq.s   .nfd
        add.w   G_DRP(a6),d1
.nfd:   subi.w  #$8000-1,d1
        add.w   M_SCROLL(a4),d1
        subi.w  #VIEW_SCROLL,d1
        sub.w   G_VIEW(a6),d1
        move.w  d0,G_SPX(a6)
        move.w  d1,G_SPY(a6)
        movem.l d0-d1/a4-a5,-(sp)
        bsr     occ_build               ; G_HIDE / G_HMASK for this frame
        movem.l (sp)+,d0-d1/a4-a5
        ; setup (the frame's word count, shift, clip)
        moveq   #3,d2
        and.w   d0,d2                   ; shift
        asr.w   #2,d0
        move.w  d0,d7                   ; wx
        moveq   #0,d6
        tst.w   d7
        bpl.s   .wl
        move.w  d7,d6
        neg.w   d6                      ; wlo
.wl:    moveq   #64,d5
        sub.w   d7,d5
        cmp.w   (a5),d5
        ble.s   .wh
        move.w  (a5),d5                 ; whi = min(nw, 64 - wx)
.wh:    cmp.w   d5,d6
        bge     .none
        moveq   #0,d3
        tst.w   d1
        bpl.s   .r0
        move.w  d1,d3
        neg.w   d3                      ; r0
.r0:    move.w  G_LINES(a6),d4
        sub.w   d1,d4
        cmpi.w  #16,d4
        ble.s   .r1
        moveq   #16,d4
.r1:    sub.w   d3,d4
        ble     .none
        subq.w  #1,d4                   ; rows - 1
        add.w   d2,d2
        add.w   d2,d2
        movea.l a5,a3
        adda.w  4(a5,d2.w),a3           ; this shift's data
        movea.l a5,a2
        adda.w  6(a5,d2.w),a2           ; its spans
        move.w  d3,d0
        mulu.w  #SPN_ROWB,d0
        adda.w  d0,a2
        movea.l G_DEST(a6),a4
        move.w  G_PTOP(a6),d0           ; (y is relative to the playfield top)
        lsl.w   #7,d0
        adda.w  d0,a4
        move.w  d1,d0
        add.w   d3,d0
        lsl.w   #7,d0
        adda.w  d0,a4
        move.w  d7,d0
        add.w   d0,d0
        adda.w  d0,a4
        tst.w   G_HMASK(a6)
        bne     .masked
        tst.w   d6
        bne.s   .clip
        cmp.w   (a5),d5
        bne.s   .clip
; FAST: the whole row span is on screen
.rf:    movem.w (a2)+,d0-d1/d3
        tst.w   d3
        bmi.s   .nf
        lea     0(a4,d0.w),a1
        lea     0(a3,d1.w),a0
.wf:    move.w  (a1),d0
        and.w   (a0)+,d0
        or.w    (a0)+,d0
        move.w  d0,(a1)+
        dbra    d3,.wf
.nf:    lea     BPL(a4),a4
        dbra    d4,.rf
        rts
; CLIP: trim each row's span [f, f+n) to [wlo, whi)
.clip:  movem.w (a2)+,d0-d1/d3
        tst.w   d3
        bmi.s   .nc
        move.w  d0,d2
        lsr.w   #1,d2
        addq.w  #1,d3
        add.w   d2,d3
        cmp.w   d6,d2
        bge.s   .ca
        move.w  d6,d2
.ca:    cmp.w   d5,d3
        ble.s   .cb
        move.w  d5,d3
.cb:    sub.w   d2,d3
        ble.s   .nc
        subq.w  #1,d3
        sub.w   d0,d1
        sub.w   d0,d1
        add.w   d2,d2
        lea     0(a4,d2.w),a1
        add.w   d2,d1
        add.w   d2,d1
        lea     0(a3,d1.w),a0
.wc:    move.w  (a1),d0
        and.w   (a0)+,d0
        or.w    (a0)+,d0
        move.w  d0,(a1)+
        dbra    d3,.wc
.nc:    lea     BPL(a4),a4
        dbra    d4,.clip
        rts
; MASKED: as FAST / CLIP, with the hide words (d7 = this row's G_HIDE line)
.masked:
        lea     G_HIDE(a6),a0
        move.w  d3,d0
        mulu.w  #HIDE_ROWB,d0
        adda.w  d0,a0
        move.l  a0,d7
        move.w  G_HRM(a6),d0            ; the rows' flags from the first row drawn
        lsr.w   d3,d0
        move.w  d0,G_HRT(a6)
        tst.w   d6
        bne.s   .mclip
        cmp.w   (a5),d5
        bne.s   .mclip
        move.w  d0,d6                   ; (FAST: d6 is free, the flags there)
.mf:    movem.w (a2)+,d0-d1/d3
        lsr.w   #1,d6                   ; (this row's flag: C)
        bcs.s   .mfm
        tst.w   d3                      ; nothing hidden in this row: as FAST
        bmi.s   .mnf
        lea     0(a4,d0.w),a1
        lea     0(a3,d1.w),a0
.mwp:   move.w  (a1),d0
        and.w   (a0)+,d0
        or.w    (a0)+,d0
        move.w  d0,(a1)+
        dbra    d3,.mwp
        bra.s   .mnf
.mfm:   tst.w   d3
        bmi.s   .mnf
        lea     0(a4,d0.w),a1
        lea     0(a3,d1.w),a0
        movea.l d7,a5
        adda.w  d0,a5
.mwf:   move.w  (a5)+,d2                ; hide
        move.w  (a0)+,d1
        or.w    d2,d1                   ; keep: the sprite's clear pixels + hidden ones
        not.w   d2
        and.w   (a0)+,d2                ; colour where shown
        move.w  (a1),d0
        and.w   d1,d0
        or.w    d2,d0
        move.w  d0,(a1)+
        dbra    d3,.mwf
.mnf:   lea     BPL(a4),a4
        moveq   #HIDE_ROWB,d0
        add.l   d0,d7
        dbra    d4,.mf
        rts
.mclip: movem.w (a2)+,d0-d1/d3
        lsr.w   G_HRT(a6)               ; (this row's flag: C, then as CLIP)
        bcs.s   .mcm
        tst.w   d3
        bmi     .mnc
        move.w  d0,d2
        lsr.w   #1,d2
        addq.w  #1,d3
        add.w   d2,d3
        cmp.w   d6,d2
        bge.s   .pa
        move.w  d6,d2
.pa:    cmp.w   d5,d3
        ble.s   .pb
        move.w  d5,d3
.pb:    sub.w   d2,d3
        ble     .mnc
        subq.w  #1,d3
        sub.w   d0,d1
        sub.w   d0,d1
        add.w   d2,d2
        lea     0(a4,d2.w),a1
        add.w   d2,d1
        add.w   d2,d1
        lea     0(a3,d1.w),a0
.mwq:   move.w  (a1),d0
        and.w   (a0)+,d0
        or.w    (a0)+,d0
        move.w  d0,(a1)+
        dbra    d3,.mwq
        bra     .mnc
.mcm:   tst.w   d3
        bmi.s   .mnc
        move.w  d0,d2
        lsr.w   #1,d2
        addq.w  #1,d3
        add.w   d2,d3
        cmp.w   d6,d2
        bge.s   .ma
        move.w  d6,d2
.ma:    cmp.w   d5,d3
        ble.s   .mb
        move.w  d5,d3
.mb:    sub.w   d2,d3
        ble.s   .mnc
        subq.w  #1,d3
        sub.w   d0,d1
        sub.w   d0,d1
        add.w   d2,d2
        lea     0(a4,d2.w),a1
        add.w   d2,d1
        add.w   d2,d1
        lea     0(a3,d1.w),a0
        movea.l d7,a5
        adda.w  d2,a5
.mwc:   move.w  (a5)+,d2
        move.w  (a0)+,d1
        or.w    d2,d1
        not.w   d2
        and.w   (a0)+,d2
        move.w  (a1),d0
        and.w   d1,d0
        or.w    d2,d0
        move.w  d0,(a1)+
        dbra    d3,.mwc
.mnc:   lea     BPL(a4),a4
        moveq   #HIDE_ROWB,d0
        add.l   d0,d7
        dbra    d4,.mclip
        rts
.nofd:  move.w  #-1,G_SPF(a6)           ; (lifted off the top: not drawn this frame)
.none:  rts

;=============================================================================
; Frame counter: MT.LPOLL polled task (never use a3 in it)
;=============================================================================
poll_link:
        lea     G_PLINK(a6),a0
        lea     poll_handler(pc),a1
        clr.l   (a0)
        move.l  a1,4(a0)
        moveq   #MT_LPOLL,d0
        trap    #1
        rts

poll_handler:
        lea     globals(pc),a0
        addq.w  #1,G_PTICK(a0)
        ifne    MUS_ON
        tst.w   G_MON(a0)               ; the tune's tick (QDOS mode)
        beq.s   .o
        move.l  a6,-(sp)
        movea.l a0,a6
        bsr     mus_tick
        movea.l (sp)+,a6
.o:
        endc
        rts

        ifeq    RELB
; load_times - (test loader, G_TLAB = 2) the start's unpack + marble bank, then
; each race's load, timed in 50 Hz ticks into G_LDT (QDOS mode: the poll task
; counts while the load runs)
load_times:
        movem.l d0-d7/a0-a5,-(sp)
        bsr     get_tick
        move.w  d0,-(sp)
        bsr     boot_data
        bsr     get_tick
        sub.w   (sp)+,d0
        move.w  d0,G_LDT(a6)
        moveq   #0,d7
.r:     move.w  d7,-(sp)
        bsr     get_tick
        move.w  d0,-(sp)
        move.w  2(sp),d0
        bsr     load_race
        bsr     get_tick
        sub.w   (sp)+,d0
        move.w  (sp)+,d7
        move.w  d7,d1
        add.w   d1,d1
        lea     G_LDT+2(a6),a0
        move.w  d0,0(a0,d1.w)
        addq.w  #1,d7
        cmpi.w  #6,d7
        blo.s   .r
        movem.l (sp)+,d0-d7/a0-a5
        rts
        endc

get_tick:
        movea.l G_TICKP(a6),a0
        move.w  (a0),d0
        rts

get_tick_to_d2:
        movea.l G_TICKP(a6),a0
        move.w  (a0),d2
        rts

spin_to:
        movea.l G_TICKP(a6),a0
        moveq   #0,d5
spin_loop:                              ; (global: the emulator test hooks it)
        addq.l  #1,d5
        tst.b   G_TKON+1(a6)            ; takeover: the frame flag is our clock
        beq.s   .q
        btst    #3,PC_INTR
        beq.s   .q
        bsr     tk_ack
.q:     cmp.w   (a0),d1
        beq.s   .done
        cmp.l   d4,d5
        blo.s   spin_loop
        moveq   #-1,d0
        rts
.done:  moveq   #0,d0
        rts

clock_check:
        lea     G_PTICK(a6),a0
        move.l  a0,G_TICKP(a6)
        movea.l G_SYS(a6),a1
        lea     SV_RAND(a1),a1
        move.w  (a1),d2
        move.w  (a0),d1
        move.l  #CAL_CAP,d4
clock_loop:                             ; (global: the emulator test hooks it)
        cmp.w   (a0),d1
        bne.s   .alive
        move.w  (a1),d0
        sub.w   d2,d0
        cmpi.w  #POLL_CHECK,d0
        bhs.s   .dead
        subq.l  #1,d4
        bne.s   clock_loop
.dead:  move.l  a1,G_TICKP(a6)
        clr.w   G_POLLOK(a6)
        rts
.alive: move.w  #1,G_POLLOK(a6)
        rts

calibrate:
        clr.l   G_K(a6)
        bsr.s   get_tick
        move.w  d0,d1
        addq.w  #1,d1
        move.l  #CAL_CAP,d4
        bsr.s   spin_to
        tst.l   d0
        bne.s   .none
        addq.w  #4,d1
        bsr.s   spin_to
        tst.l   d0
        bne.s   .none
        lsr.l   #2,d5
        bne.s   .ok
        moveq   #1,d5
.ok:    move.l  d5,G_K(a6)
.none:  rts

;=============================================================================
; detect_dual / flip_to / apply_sync / sync_end: the screens and the frame sync
;=============================================================================
detect_dual:
        move.l  G_SYS(a6),d0
        cmpi.l  #SCREEN1+$8000,d0
        blo.s   .no
        cmpi.b  #'1',G_VER(a6)
        bne.s   .no
        moveq   #MT_DMODE,d0
        moveq   #$40,d1
        moveq   #-1,d2
        trap    #1
        tst.l   d0
        bne.s   .no
        andi.w  #$FF,d1
        move.w  d1,G_DMODE(a6)
        btst    #7,d1
        beq.s   .no
        move.w  #1,G_DUAL(a6)
.no:    rts

flip_to:
        tst.w   G_DUAL(a6)
        beq.s   .out
        move.w  d0,G_SHOWN(a6)
        move.b  G_MCSTA0+1(a6),d1
        andi.b  #$75,d1
        ori.b   #$08,d1
        tst.w   d0
        beq.s   .w
        ori.b   #$80,d1
.w:     move.b  d1,MC_STAT
        tst.w   G_TKON(a6)              ; takeover: the system variables may be
        bne.s   .out                    ; in screen 1 (saved; not written)
        movea.l G_SYS(a6),a0
        move.b  d1,SV_MCSTA(a0)
.out:   rts

apply_sync:
        move.w  G_SYNC(a6),d0
        cmpi.w  #2,d0
        bne.s   .set
        tst.w   G_DUAL(a6)
        bne.s   .set
        moveq   #0,d0
.set:   tst.l   G_K(a6)
        bne.s   .clk
        moveq   #0,d0
.clk:   move.w  d0,G_SEFF(a6)
        tst.w   G_SHOWN(a6)
        beq.s   .s0
        moveq   #0,d0
        bsr.s   flip_to
.s0:    move.l  #SCREEN,G_DEST(a6)
        cmpi.w  #2,G_SEFF(a6)
        bne.s   .d
        move.l  #SCREEN1,G_DEST(a6)
.d:     move.w  #N_MIN,G_NT(a6)         ; 10 fps, or 12.5 fixed (G_FPSM 2); adaptive
        cmpi.w  #2,G_FPSM(a6)           ; starts at 10 (sync_end steps it)
        bne.s   .d10
        move.w  #N_FAST,G_NT(a6)
.d10:   clr.w   G_SLACK(a6)
        clr.w   G_BOFF(a6)
        clr.w   G_RUN125(a6)
        move.w  #1,G_CLR0(a6)
        move.w  #1,G_CLR1(a6)
        bsr     get_tick
        move.w  d0,G_FT0(a6)
        rts

sync_end:
        moveq   #0,d5
        tst.w   G_SEFF(a6)
        beq     .out
        cmpi.w  #N_FAST,G_NT(a6)        ; the frame just made, by its rate
        bne.s   .c10
        addq.l  #1,G_F125(a6)
        bra.s   .c12
.c10:   addq.l  #1,G_F10(a6)
.c12:
        move.l  G_K(a6),d4
        add.l   d4,d4
        move.w  G_FT0(a6),d1
        add.w   G_NT(a6),d1
        bsr     get_tick
        sub.w   d1,d0
        bmi.s   .ontime
        bsr     get_tick
        move.w  d0,d1
        addq.w  #1,d1
        bsr     spin_to
        move.l  d0,d6
        ; LATE: the frame ran past its deadline. It is shown on the tick edge
        ; after it finished (the spin above) and the next frame's deadline is
        ; N whole ticks from that edge (G_FT0 = that edge, below): the display
        ; keeps a steady N-tick cadence from the late flip on, never two quick
        ; flips to catch up; the logic catches up from the clock. At 5 ticks N
        ; is not raised (the display holds 10 fps); late frames are counted.
        ; Adaptive at 4 ticks (12.5 fps): back to 5, held there for the back-off.
        addq.l  #1,G_LATE(a6)
        clr.w   G_SLACK(a6)
        cmpi.w  #N_FAST,G_NT(a6)
        bne     .edge
        tst.w   G_FPSM(a6)              ; (fixed 12.5 fps holds 4)
        bne     .edge
        bsr     fps_down
        bra     .edge
.ontime:
        move.w  d1,d0
        bsr     get_tick_to_d2
        sub.w   d2,d0
        bra.s   .capn
.capl:  add.l   G_K(a6),d4
.capn:  dbra    d0,.capl
        bsr     spin_to
        move.l  d0,d6
        ; ON TIME. Adaptive (G_FPSM 0; not the benchmark): at 5 ticks, a frame
        ; done with the wait >= 1.25 ticks (it would have made 4 ticks with 5 ms
        ; to spare) counts; UP_FRAMES in a row -> 4 ticks (12.5 fps). Not during
        ; the back-off after a failure at 4. At 4, a long clean run resets the
        ; back-off length.
        tst.w   G_FPSM(a6)
        bne     .edge
        ifeq    RELB
        tst.w   G_BENCH(a6)             ; (the benchmark holds 10 fps: its figures
        beq.s   .ad                     ; stay comparable)
        cmpi.w  #N_MIN,G_NT(a6)
        beq     .edge
        move.w  #N_MIN,G_NT(a6)
        bsr     fmt_settings
        bra     .edge
        endc
.ad:    cmpi.w  #N_MIN,G_NT(a6)
        beq.s   .at10
        addq.w  #1,G_RUN125(a6)
        cmpi.w  #BOFF_RESET,G_RUN125(a6)
        blo     .edge
        clr.w   G_RUN125(a6)
        move.w  #BOFF_BASE,G_BOFFL(a6)
        bra     .edge
.at10:  tst.w   G_BOFF(a6)
        beq.s   .try
        subq.w  #1,G_BOFF(a6)
        bra.s   .tight
.try:   move.l  G_K(a6),d2
        move.l  d2,d3
        lsr.l   #2,d3
        add.l   d3,d2
        cmp.l   d2,d5
        blo.s   .tight
        addq.w  #1,G_SLACK(a6)
        cmpi.w  #UP_FRAMES,G_SLACK(a6)
        blt.s   .edge
        clr.w   G_SLACK(a6)
        clr.w   G_RUN125(a6)
        move.w  #N_FAST,G_NT(a6)        ; 12.5 fps
        addq.w  #1,G_FSW(a6)
        bsr     fmt_settings
        bra.s   .edge
.tight: clr.w   G_SLACK(a6)
.edge:
        tst.l   d6
        beq.s   .on_edge
        bsr     get_tick
        move.w  d0,d1
.on_edge:
        ifeq    RELB
        move.l  G_TELP(a6),d0           ; telemetry: this frame's record (TELEMETRY
        beq     .ntl                    ; below; d0 / a0 free here, d1 / d5 kept)
        movea.l d0,a0
        move.b  G_RACE+1(a6),(a0)+
        move.b  G_NT+1(a6),(a0)+        ; (the next frame's rate: never 0)
        move.w  d5,(a0)+
        move.b  G_MB+M_X+1(a6),(a0)+    ; (bytes: the px word is odd in its long)
        move.b  G_MB+M_X+2(a6),(a0)+
        move.b  G_MB+M_Y+1(a6),(a0)+
        move.b  G_MB+M_Y+2(a6),(a0)+
        move.w  G_MB+M_S(a6),d0
        add.w   G_MB+M_SCROLL(a6),d0
        move.w  d0,(a0)+
        move.w  d1,d0
        sub.w   G_FT0(a6),d0
        move.b  d0,(a0)+
        move.b  G_MOVM+1(a6),(a0)+
        move.b  G_STEPS+1(a6),(a0)+
        move.b  G_TFLG+1(a6),d0         ; the flags: the frame's events, then the
        tst.w   G_PAUSE(a6)             ; states (1 paused, 2 muted, 4 demo input)
        beq.s   .tf1
        bset    #1,d0
.tf1:   tst.w   G_MUTE(a6)
        beq.s   .tf2
        bset    #2,d0
.tf2:   tst.w   G_DEMO(a6)
        beq.s   .tf4
        bset    #4,d0
.tf4:   move.b  d0,(a0)+
        clr.w   G_TFLG(a6)
        move.w  G_VIEW(a6),d0           ; the lines scrolled since the last record
        sub.w   G_TVIEW(a6),d0          ; (down +; -128 / 127 at most)
        add.w   d0,G_TVIEW(a6)
        cmpi.w  #127,d0
        ble.s   .tv1
        moveq   #127,d0
.tv1:   cmpi.w  #-128,d0
        bge.s   .tv2
        moveq   #-128,d0
.tv2:   move.b  d0,(a0)+
        move.w  G_TSPR(a6),d0           ; sprites drawn (255 at most)
        clr.w   G_TSPR(a6)
        cmpi.w  #255,d0
        bls.s   .ts
        move.w  #255,d0
.ts:    move.b  d0,(a0)+
        cmpa.l  G_TELE(a6),a0
        blo.s   .tw
        movea.l G_TELS(a6),a0
.tw:    move.l  a0,G_TELP(a6)
        endc
.ntl:   move.w  d1,G_FT0(a6)
        add.l   d5,G_WSPIN(a6)
        cmpi.w  #2,G_SEFF(a6)
        bne.s   .out
        moveq   #1,d0
        sub.w   G_SHOWN(a6),d0
        move.l  d5,-(sp)
        bsr     flip_to
        move.l  (sp)+,d5
        move.l  #SCREEN1,G_DEST(a6)
        tst.w   G_SHOWN(a6)
        beq.s   .out
        move.l  #SCREEN,G_DEST(a6)
.out:   rts

        ifeq    RELB
;=============================================================================
; TELEMETRY (mmt_bas: tel = the buffer's KB; G_TELB 0 otherwise, and then the
; frame pays one test). A ring of per-frame records in a RESPRed buffer, written
; at sync_end's edge (inline: about 110 bytes of 68008 bus a frame), SBYTEd by
; the loader after ESC (win1_mm_tel). Header, 32 B:
;   0 'MMTL'   4 version (3)   6 record size (16)
;   8 the next record's offset from the buffer (long; the LOADER pokes it from
;     G_TELP before the SBYTES: the frame does not keep it)
;   12 K: spins per tick (long)   16 capacity (records, long)
;   20 N_FAST, 22 N_MIN   24 the bitmap line offset ($8000-1+VIEW_SCROLL, word)
; then the records, cleared here (an unwritten one is all 0; byte 1 never is):
;   0  race (0-5)   1 the ticks a frame from now (G_NT, after this frame's
;      adaptive step: the rate THIS frame was made at is the previous record's)
;   2  the spins waited for the edge (low word: busy = span - spins / K ticks)
;   4  the marble's X, 6 its Y (map px)
;   8  M_S + M_SCROLL: minus the header's offset, the marble's bitmap line (its
;      sprite's top; the race map's row + LIN_TOP)
;   10 the span, edge to edge (ticks: late when over the rate it was made at)
;   11 the slots with logic (G_MOVM: bits 2-7)   12 logic steps run (G_STEPS)
;   13 flags: the frame's events (G_TFLG: 0 a BEEP / kill sent, 3 the typed keys
;      read, 5 the input skipped for a BEEP) and states (1 paused, 2 muted, 4 demo)
;   14 the lines scrolled since the last record (signed byte, down +; clamped)
;   15 the sprites drawn (G_TSPR: spr_put / spr_puts; the marble not counted; 255
;      at most)
; The K at 12 is the takeover's after tk_enter (tk_enter rewrites it; tel_init
; writes QDOS's, the spin loop then polls the hardware).
;=============================================================================
TEL_REC         equ     16
TEL_HDR         equ     32

tel_init:
        move.w  G_VIEW(a6),G_TVIEW(a6)  ; (the first record's scroll: from now)
        clr.w   G_TSPR(a6)
        clr.w   G_TFLG(a6)
        move.l  G_TELB(a6),d0
        beq.s   .o
        movea.l d0,a0
        move.l  G_TELN(a6),d0
        lsr.l   #1,d0
        subq.l  #1,d0
.c:     clr.w   (a0)+                   ; (the whole buffer: RESPR does not clear)
        subq.l  #1,d0
        bpl.s   .c
        movea.l G_TELB(a6),a0
        move.l  #'MMTL',(a0)
        move.w  #3,4(a0)
        move.w  #TEL_REC,6(a0)
        move.l  #TEL_HDR,8(a0)
        move.l  G_K(a6),12(a0)
        move.l  G_TELN(a6),d0
        subi.l  #TEL_HDR,d0
        divu.w  #TEL_REC,d0             ; (a buffer under 900 KB)
        andi.l  #$FFFF,d0
        beq.s   .o                      ; (no room for a record: not recording)
        move.l  d0,16(a0)
        move.w  #N_FAST,20(a0)
        move.w  #N_MIN,22(a0)
        move.w  #$8000-1+VIEW_SCROLL,24(a0)
        mulu.w  #TEL_REC,d0
        lea     TEL_HDR(a0),a0
        move.l  a0,G_TELS(a6)
        move.l  a0,G_TELP(a6)
        adda.l  d0,a0
        move.l  a0,G_TELE(a6)
.o:     rts
        endc

; fps_down - (sync_end) adaptive, late at 4 ticks: back to 5 ticks (10 fps), held
; for the back-off (G_BOFFL frames, then doubled up to BOFF_MAX). Uses d0.
fps_down:
        move.w  #N_MIN,G_NT(a6)
        addq.w  #1,G_FSW(a6)
        clr.w   G_SLACK(a6)
        clr.w   G_RUN125(a6)
        move.w  G_BOFFL(a6),d0
        move.w  d0,G_BOFF(a6)
        add.w   d0,d0
        cmpi.w  #BOFF_MAX,d0
        bls.s   .bo
        move.w  #BOFF_MAX,d0
.bo:    move.w  d0,G_BOFFL(a6)
        bra     fmt_settings

;=============================================================================
; draw_linear - LINES lines x 128 B from G_LIN + view*128 to G_DEST: both are
; flat (BPL = 128), so a 2 KB block (16 lines) is 39 x 52 B + 20 B through 13
; registers (a6 too: reloaded for the poll between blocks)
;=============================================================================
draw_linear:
        movem.l d0-d7/a0-a6,-(sp)
        movea.l G_LIN(a6),a0
        moveq   #0,d0
        move.w  G_VIEW(a6),d0
        lsl.l   #7,d0
        adda.l  d0,a0
        movea.l G_DEST(a6),a1
        move.w  G_PTOP(a6),d0           ; the playfield starts at line PTOP
        lsl.w   #7,d0
        adda.w  d0,a1
        move.w  G_LINES(a6),d0
        lsr.w   #4,d0                   ; blocks of 16 lines (LINES = 224/208/192)
        move.w  d0,-(sp)                ; (the count; the saved a6 at 2+56)
.blk:
DL_O    set     0
        rept    39
        movem.l (a0)+,d0-d7/a2-a6       ; 52
        movem.l d0-d7/a2-a6,DL_O(a1)
DL_O    set     DL_O+52
        endr
        movem.l (a0)+,d0-d4             ; 20
        movem.l d0-d4,DL_O(a1)
        lea     16*BPL(a1),a1
        movea.l 2+56(sp),a6
        tst.b   G_TKON+1(a6)            ; (tk_poll inline: the frame clock)
        beq.s   .np
        btst    #3,PC_INTR
        beq.s   .np
        bsr     tk_ack
.np:    subq.w  #1,(sp)
        bne     .blk
        addq.l  #2,sp
        movem.l (sp)+,d0-d7/a0-a6
        rts

;=============================================================================
; heights and the cleared tail; a tail clear also forgets
; what that buffer's panel shows
;=============================================================================
set_height:
        move.w  G_HGT(a6),d0
        add.w   d0,d0
        lea     hgt_tab(pc),a0
        move.w  0(a0,d0.w),G_LINES(a6)
        move.w  #SCR_LINES,d0           ; centred: (256 - LINES) / 2, even
        sub.w   G_LINES(a6),d0
        lsr.w   #1,d0
        andi.w  #$FFFE,d0
        move.w  d0,G_PTOP(a6)
        move.w  #1,G_CLR0(a6)
        move.w  #1,G_CLR1(a6)
        rts

hgt_tab:
        dc.w    224,208,192

clear_tail:
        lea     G_CLR0(a6),a0
        ifeq    RELB
        lea     G_SHAD0(a6),a1
        endc
        move.l  G_DEST(a6),d0
        cmpi.l  #SCREEN,d0
        beq.s   .s0
        lea     G_CLR1(a6),a0
        ifeq    RELB
        lea     G_SHAD1(a6),a1
        endc
.s0:    tst.w   (a0)
        beq.s   .out
        clr.w   (a0)
        ifeq    RELB
        move.w  #TEXT_LEN-1,d1
.sh:    move.b  #$FF,(a1)+
        dbra    d1,.sh
        endc
        move.l  d0,-(sp)                ; (this screen's HUD: every column queued)
        lea     G_HQN0(a6),a0
        cmpi.l  #SCREEN,d0
        beq.s   .h0
        lea     G_HQN1(a6),a0
.h0:    bsr     hud_qall
        move.l  (sp)+,d0
        ifeq    RELB
        move.w  #3,G_TDIRTY(a6)
        endc
        movea.l d0,a0                   ; the top band: lines 0 .. PTOP-1
        move.w  G_PTOP(a6),d2
        bsr.s   .clr
        move.w  G_LINES(a6),d2          ; (skip the playfield)
        lsl.w   #7,d2
        adda.w  d2,a0
        move.w  #SCR_LINES,d2           ; the bottom band: PTOP+LINES .. 255
        sub.w   G_PTOP(a6),d2
        sub.w   G_LINES(a6),d2
        bsr.s   .clr
        move.w  #-1,G_WFR(a6)
.out:   rts
.clr:   tst.w   d2                      ; d2 lines from a0 (a0 advances)
        beq.s   .z
        lsl.w   #5,d2
        subq.w  #1,d2
        moveq   #0,d1
.c:     move.l  d1,(a0)+
        dbra    d2,.c
.z:     rts

;=============================================================================
; read_input - typed keys from our con_ (settings), then KEYROW row 1 once:
; the input bits for this QL frame (Right 1, Left 2, Down 4, Up 8, speed-up $80).
;=============================================================================
read_input:
        ifne    MUS_ON
        tst.w   G_BSENT(a6)             ; a BEEP less than 2 ticks ago: no IPC now
        beq.s   .ok
        bsr     beep_quiet
        beq.s   .ok
        ifeq    RELB
        bset    #5,G_TFLG+1(a6)         ; (telemetry: the input skipped)
        endc
        rts
.ok:
        endc
        ifeq    RELB
        tst.w   G_REL(a6)               ; the release: no typed keys (ESC, ENTER and
        bne     .drained                ;  \ are KEYROW row 1's: row_keys)
        bset    #3,G_TFLG+1(a6)         ; (telemetry: the typed keys read)
        tst.w   G_TKON(a6)
        beq.s   .drain
        bsr     tk_keys                 ; takeover: the IPC's typed keys
.drain:
        tst.w   G_TKON(a6)
        beq.s   .qd
        bsr     tk_getkey
        tst.l   d0
        bne     .drained
        bra.s   .key
.qd:    move.l  G_CON(a6),d0
        beq     .drained
        movea.l d0,a0
        moveq   #IO_FBYTE,d0
        moveq   #0,d3
        trap    #3
        tst.l   d0
        bne     .drained
.key:   andi.w  #$FF,d1
        cmpi.b  #K_ESC,d1
        bne.s   .n_esc
        move.w  #1,G_QUIT(a6)
        rts
.n_esc: cmpi.b  #'1',d1                 ; 1-6: that race, now
        blo.s   .n_dig
        cmpi.b  #'6',d1
        bhi.s   .n_dig
        tst.l   G_DAT(a6)
        beq     .drain                  ; (the single-race mm1_* files)
        moveq   #0,d0
        move.b  d1,d0
        subi.w  #'1',d0
        bsr     goto_race
        bra     .changed
.n_dig: andi.b  #$DF,d1                 ; upper case
        cmpi.b  #'H',d1
        bne.s   .n_h
        move.w  G_HGT(a6),d0
        addq.w  #1,d0
        cmpi.w  #3,d0
        blo.s   .h_ok
        moveq   #0,d0
.h_ok:  move.w  d0,G_HGT(a6)
        bsr     set_height
        bra     .changed
.n_h:   cmpi.b  #'V',d1
        bne.s   .n_v
        move.w  G_SYNC(a6),d0
        addq.w  #1,d0
        cmpi.w  #3,d0
        blo.s   .v_ok
        moveq   #0,d0
.v_ok:  move.w  d0,G_SYNC(a6)
        bsr     apply_sync
        bra     .changed
.n_v:   cmpi.b  #'T',d1
        bne.s   .n_t
        clr.w   G_BENCH(a6)
        move.w  G_MODE(a6),d0
        addq.w  #1,d0
        cmpi.w  #N_TMODES,d0
        blo.s   .t_ok
        moveq   #0,d0
.t_ok:  bsr     set_mode
        bra     .changed
.n_t:   cmpi.b  #'B',d1
        bne.s   .n_b
        move.w  #1,G_BENCH(a6)
        move.w  #1,G_DEMO(a6)           ; the benchmark plays the demo: no keys needed,
        bsr     demo_start              ; every mode sees the same marble run
        moveq   #0,d0
        bsr     set_mode
        bsr     fmt_bench
        bra     .changed
.n_b:   cmpi.b  #'P',d1
        bne.s   .n_p
        eori.w  #1,G_PAUSE(a6)
        bra     .changed
.n_p:   cmpi.b  #'R',d1
        bne.s   .n_r
        bsr     restart
        bsr     ghosts_init
        bra     .drain
.n_r:   cmpi.b  #'L',d1
        bne.s   .n_l
        bsr     lab_run
        bsr     logic_resync            ; (the LAB's 8 s are not game time)
        bra     .changed
.n_l:   cmpi.b  #'D',d1
        bne.s   .n_d
        eori.w  #1,G_DEMO(a6)
        beq     .changed
        bsr     demo_start
        bra     .changed
.n_d:   cmpi.b  #'M',d1
        bne.s   .n_m
        eori.w  #1,G_OCCON(a6)
        bra     .changed
.n_m:   cmpi.b  #'O',d1
        bne.s   .n_o
        moveq   #1,d0                   ; the debug panel <-> the HUD
        cmp.w   G_OVL(a6),d0
        bne.s   .ovp
        moveq   #2,d0
.ovp:   move.w  d0,G_OVL(a6)
        move.l  #-1,G_SCSHOWN(a6)       ; (the panel's score and time: formatted
        move.w  #$FFFD,G_TSHOWN(a6)     ;  again)
        bsr     hud_reset               ; (both bands cleared, drawn again: now)
        bsr     top_now
        bra     .changed
.n_o:   cmpi.b  #'C',d1                 ; C: the race timer off / on (play-testing)
        bne     .n_c
        eori.w  #1,G_TIMOFF(a6)
        bsr     fmt_time
        bra     .changed
.n_c:   cmpi.b  #'F',d1                 ; F: the frame rate, adaptive -> fixed 10 fps
        bne     .drain                  ; -> fixed 12.5 fps -> adaptive
        move.w  G_FPSM(a6),d0
        addq.w  #1,d0
        cmpi.w  #3,d0
        blo.s   .f_ok
        moveq   #0,d0
.f_ok:  move.w  d0,G_FPSM(a6)
        bsr     apply_sync
        bra     .changed
.changed:
        bsr     fmt_settings
        cmpi.w  #2,G_OVL(a6)            ; (the HUD: a band cleared by a setting -
        bne.s   .chs                    ;  height, sync - drawn whole now)
        bsr     top_now
.chs:   bsr     stats_reset
        bra     .drain

.drained:
        tst.w   G_DEMO(a6)
        beq.s   .live
        cmpi.w  #4,G_MODE(a6)           ; demo input: KEYROW is still read (and
        beq     demo_pad                ; ignored) so INP measures it, except mode 4
        cmpi.w  #6,G_MODE(a6)           ; and 6, 7
        beq     demo_pad
        cmpi.w  #7,G_MODE(a6)
        beq     demo_pad
        bsr     read_arrow_row
        move.w  d0,G_KEYROW(a6)
        bra     demo_pad
        endc
.live:
        ifeq    RELB
        move.w  G_TPAD(a6),d0           ; test loader: a fixed input, no KEYROW
        beq.s   .kr
        subq.w  #1,d0
        move.w  d0,G_PAD(a6)
        rts
.kr:    cmpi.w  #4,G_MODE(a6)
        beq.s   .nkr
        cmpi.w  #6,G_MODE(a6)
        beq.s   .nkr
        cmpi.w  #7,G_MODE(a6)
        bne.s   .rd
.nkr:   clr.w   G_PAD(a6)               ; modes 4, 6, 7: no KEYROW read
        rts
        endc
.rd:    bsr     read_arrow_row          ; d0.b: Left 1 Up 2 Right 4 Space 6 Down 7
        move.w  d0,G_KEYROW(a6)
        bsr     row_keys                ; ENTER pause, \ mute (no extra IPC)
        tst.b   d0
        beq.s   .pad
        move.w  #1,G_KRALIVE(a6)
.pad:   moveq   #0,d1
        btst    #4,d0
        beq.s   .p1
        ori.b   #$01,d1                 ; Right
.p1:    btst    #1,d0
        beq.s   .p2
        ori.b   #$02,d1                 ; Left
.p2:    btst    #7,d0
        beq.s   .p3
        ori.b   #$04,d1                 ; Down
.p3:    btst    #2,d0
        beq.s   .p4
        ori.b   #$08,d1                 ; Up
.p4:    btst    #6,d0
        beq.s   .p5
        ori.b   #$80,d1                 ; speed-up = SPACE
.p5:    move.w  d1,G_PAD(a6)
        rts

; row_keys - d0.w = KEYROW row 1: its new presses (not held last frame; none
; after a frontend screen until released): ENTER (bit 0) pause / go on, as P;
; \ (bit 5) the sound muted / back (snd_mute); ENTER and \ down together: the
; race timer off / on (as C; the first key's own action undone). The release
; (G_REL): ESC (bit 3) quits here, no typed keys being read. Preserves all
; registers.
row_keys:
        movem.l d0-d7/a0-a5,-(sp)
        move.w  G_KRPREV(a6),d1         ; d1 = last frame's row
        move.w  d0,G_KRPREV(a6)
        ifeq    RELB
        tst.w   G_REL(a6)
        beq.s   .ne
        endc
        btst    #3,d0
        beq.s   .ne
        move.w  #1,G_QUIT(a6)
.ne:    move.w  d0,d2
        andi.w  #$21,d2                 ; d2 = ENTER / \ held now
        bne.s   .h
        clr.w   G_KRSOLO(a6)            ; (both up)
        bra.s   .o
.h:     cmpi.w  #$21,d2
        bne.s   .one
        move.w  d1,d3                   ; both down: newly?
        andi.w  #$21,d3
        cmpi.w  #$21,d3
        beq.s   .o
        move.w  G_KRSOLO(a6),d3         ; the first key's own action undone
        clr.w   G_KRSOLO(a6)
        btst    #0,d3
        beq.s   .u5
        bsr.s   .pause
.u5:    btst    #5,d3
        beq.s   .tm
        bsr.s   .mute
.tm:    eori.w  #1,G_TIMOFF(a6)         ; the race timer off / on
        bsr     fmt_time
        bsr     fmt_settings
        bra.s   .o
.one:   not.w   d1                      ; one of them: its new press
        and.w   d2,d1
        beq.s   .o
        move.w  d1,G_KRSOLO(a6)
        btst    #0,d1
        beq.s   .n0
        bsr.s   .pause
.n0:    btst    #5,d1
        beq.s   .o
        bsr.s   .mute
.o:     movem.l (sp)+,d0-d7/a0-a5
        rts
.pause: eori.w  #1,G_PAUSE(a6)
        bra     fmt_settings
.mute:
        ifne    MUS_ON
        bra     snd_mute
        endc
        ifeq    MUS_ON
        eori.w  #1,G_MUTE(a6)
        rts
        endc

        ifeq    RELB
; set_mode - d0 = measuring mode; mode 1 starts its ghosts from the marble
set_mode:
        cmpi.w  #6,d0                   ; (the benchmark's 7th: mode 8)
        bne.s   .s
        tst.w   G_BENCH(a6)
        beq.s   .s
        moveq   #8,d0
.s:     move.w  d0,G_MODE(a6)
        cmpi.w  #1,d0
        bne.s   .o
        bsr     ghosts_init
.o:     rts
        endc

read_arrow_row:
        tst.w   G_TKON(a6)
        beq.s   .qdos
        movem.l d1-d4,-(sp)             ; takeover: the IPC directly
        moveq   #1,d0
        bsr     tk_row
        andi.l  #$FF,d0
        movem.l (sp)+,d1-d4
        rts
.qdos:  movem.l d1-d3/a3/a6,-(sp)
        movea.l G_SYS(a6),a6
        lea     ipc_kbd_cmd(pc),a3
        moveq   #MT_IPCOM,d0
        moveq   #0,d3
        trap    #1
        moveq   #0,d0
        move.b  d1,d0
        movem.l (sp)+,d1-d3/a3/a6
        rts

ipc_kbd_cmd:
        dc.b    $09,$01,$00,$00,$00,$00,$01,$02
        even

open_console:
        lea     con_name(pc),a0
        moveq   #IO_OPEN,d0
        moveq   #-1,d1
        moveq   #0,d3
        trap    #2
        tst.l   d0
        bne.s   .fail
        move.l  a0,G_CON(a6)
        rts
.fail:  clr.l   G_CON(a6)
        rts

con_name:
        dc.w    4
        dc.b    'con_'
        even

;=============================================================================
; Stats + the benchmark sequencer
;=============================================================================
stats_reset:
        move.w  #-1,G_WFR(a6)
        clr.l   G_TFR(a6)
        clr.l   G_TB(a6)
        clr.l   G_TT(a6)
        rts

stats_frame:
        addq.l  #1,G_FRAMES(a6)
        ifeq    RELB
        tst.w   G_REL(a6)               ; the release: no panel figures (their once-a-
        bne     .rel                    ;  second sums and text: one frame's worth)
        addq.w  #1,G_WFR(a6)
        bne.s   .count
        bsr     get_tick
        move.w  d0,G_WT0(a6)
        clr.l   G_WSPIN(a6)
        rts
.count: bsr     get_tick
        sub.w   G_WT0(a6),d0
        cmpi.w  #STAT_TICKS,d0
        blo     .out
        add.w   d0,G_WT0(a6)
        moveq   #0,d7
        move.w  G_WFR(a6),d7
        clr.w   G_WFR(a6)
        andi.l  #$FFFF,d0
        move.l  d0,d6
        move.l  d7,d2
        mulu.w  #500,d2
        divu.w  d6,d2
        bvc.s   .f_ok
        move.w  #999,d2
.f_ok:  cmpi.w  #999,d2
        bls.s   .f_st
        move.w  #999,d2
.f_st:  move.w  d2,G_FPS10(a6)
        move.l  G_WSPIN(a6),d1
        clr.l   G_WSPIN(a6)
        move.l  G_K(a6),d2
        bsr     udiv32
        move.l  d1,d3
        bsr     mul2000
        move.l  d3,d4
        move.l  d2,d3
        bsr     mul2000
        move.l  d3,d1
        move.l  G_K(a6),d2
        bsr     udiv32
        add.l   d1,d4
        move.l  d6,d3
        bsr     mul2000
        sub.l   d4,d3
        bpl.s   .b_ok
        moveq   #0,d3
.b_ok:  move.l  d3,d5
        move.l  d5,d1
        move.l  d7,d2
        mulu.w  #10,d2
        bsr     udiv32
        cmpi.l  #$FFFF,d1
        bls.s   .w_st
        move.w  #$FFFF,d1
.w_st:  move.w  d1,G_MS10W(a6)
        add.l   d7,G_TFR(a6)
        add.l   d5,G_TB(a6)
        add.l   d6,G_TT(a6)
        cmpi.l  #ACC_MAX_TICKS,G_TT(a6)
        bls.s   .acc_ok
        move.l  d6,G_TT(a6)
        move.l  d7,G_TFR(a6)
        move.l  d5,G_TB(a6)
.acc_ok:
        move.l  G_TB(a6),d1
        move.l  G_TFR(a6),d2
        bsr     udiv32
        cmpi.l  #$FFFF,d1
        bls.s   .m_st
        move.w  #$FFFF,d1
.m_st:  move.w  d1,G_MS100(a6)
        bsr     fmt_stats
        bsr     fmt_marble
        bsr     bench_step
.out:
        endc
.rel:   rts

        ifeq    RELB
; bench_step - after each stats window: once a mode has BENCH_FRAMES of
; samples, record its mean and go to the next; after mode 4 show the result
bench_step:
        move.w  G_BENCH(a6),d0
        beq.s   .out
        cmpi.l  #BENCH_FRAMES,G_TFR(a6)
        blo.s   .out
        subq.w  #1,d0
        add.w   d0,d0
        lea     G_BRES(a6),a0
        move.w  G_MS100(a6),0(a0,d0.w)
        move.w  G_BENCH(a6),d0
        cmpi.w  #N_MODES,d0
        bhs.s   .done
        addq.w  #1,G_BENCH(a6)
        move.w  d0,-(sp)
        bsr     demo_start
        move.w  (sp)+,d0
        bsr     set_mode                ; d0 = the next mode (bench index)
        bsr     stats_reset
        bsr     fmt_settings
        bra     fmt_bench
.done:  clr.w   G_BENCH(a6)
        moveq   #0,d0
        bsr     set_mode
        bsr     stats_reset
        bsr     fmt_settings
        bra     fmt_bench
.out:   rts

udiv32:
        movem.l d3-d4,-(sp)
        moveq   #0,d3
        moveq   #31,d4
.l:     add.l   d1,d1
        addx.l  d3,d3
        cmp.l   d2,d3
        blo.s   .n
        sub.l   d2,d3
        addq.l  #1,d1
.n:     dbra    d4,.l
        move.l  d3,d2
        movem.l (sp)+,d3-d4
        rts

mul2000:
        move.l  d0,-(sp)
        move.l  d3,d0
        swap    d0
        mulu.w  #2000,d0
        swap    d0
        clr.w   d0
        mulu.w  #2000,d3
        add.l   d0,d3
        move.l  (sp)+,d0
        rts
        endc

;=============================================================================
; Panel text (glyph codes; a digit value is its glyph index)
;   line 0: "MS 000.00 FPS 00.0 D1 H224 M0 SUB6 P"
;   line 1: benchmark: "BENCH 1/5 ..." / "T0 00.00 CPY 00.00 LOG 0.00 ..."
;   line 2: "X 0000 Y 0000 Z 0000 SC 0000 ST 01 D 00 GOAL"
;=============================================================================
TX_MSI          equ 3
TX_MSD          equ 7
TX_FPSI         equ 14
TX_FPSD         equ 17
TX_SYNC         equ 19
TX_NT           equ 20
TX_H            equ 23
TX_MODE         equ 28
TX_SUB          equ 33
TX_PAUSE        equ 35
TX_OCC          equ 38                  ; OC1 / OC0: occlusion on / off
TX_RACE         equ 45                  ; R1-R6: the race
TX_SCORE        equ 48                  ; the score, 6 digits (line 0)
TX_TIME         equ 55                  ; "TIME nn" / "GAME OVER" (line 0, the right end)
L2              equ 2*TEXT_W
TX_X            equ L2+2
TX_Y            equ L2+9
TX_Z            equ L2+16
TX_SC           equ L2+25
TX_ST           equ L2+34
TX_D            equ L2+39
TX_GOAL         equ L2+42
TX_LATE         equ L2+50                  ; "LT 0000": late frames
TX_RATE         equ L2+55                  ; "10" / "12.5": the frame rate (G_NT)
TX_SW           equ L2+62                  ; "SW 00": rate switches (G_FSW)
L1              equ TEXT_W
L3              equ 3*TEXT_W

        ifeq    RELB
text_init:
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        lea     G_TEXT(a6),a1
        move.w  #TEXT_LEN-1,d0
.c:     move.b  #CH_SPC,(a1)+
        dbra    d0,.c
        lea     tpl0(pc),a0
        lea     G_TEXT(a6),a1
        bsr.s   .copy
        lea     tpl2(pc),a0
        lea     G_TEXT+L2(a6),a1
        bsr.s   .copy
        lea     G_SHAD0(a6),a0
        move.w  #TEXT_LEN*2-1,d0
.s:     move.b  #$FF,(a0)+
        dbra    d0,.s
        bra     fmt_bench
.copy:  move.b  (a0)+,d0
        bmi.s   .e
        move.b  d0,(a1)+
        bra.s   .copy
.e:     rts
        endc

        ifeq    RELB
fmt_settings:                           ; (preserves all registers: sync_end
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        movem.l d0-d2/a0-a1,-(sp)       ; calls it with live d1/d5/d6)
        lea     G_TEXT(a6),a0
        move.b  G_NT+1(a6),TX_NT(a0)
        move.w  G_SEFF(a6),d0
        beq.s   .free
        move.b  #CH_V,TX_SYNC(a0)
        subq.w  #1,d0
        beq.s   .s_out
        move.b  #CH_D,TX_SYNC(a0)
        bra.s   .s_out
.free:  move.b  #CH_DASH,TX_NT(a0)
        move.b  #CH_F,TX_SYNC(a0)
        cmpi.w  #2,G_SYNC(a6)
        bne.s   .s_out
        move.b  #CH_X,TX_SYNC(a0)
.s_out: moveq   #0,d0
        move.w  G_LINES(a6),d0
        lea     TX_H+3(a0),a1
        moveq   #3-1,d1
        bsr     put_dec_a1
        lea     G_TEXT(a6),a0
        move.b  G_MODE+1(a6),TX_MODE(a0)
        move.b  #CH_SPC,TX_PAUSE(a0)
        tst.w   G_PAUSE(a6)
        beq.s   .p
        move.b  #CH_P,TX_PAUSE(a0)
.p:     move.b  #CH_O,TX_OCC(a0)
        move.b  #CH_C,TX_OCC+1(a0)
        move.b  G_OCCON+1(a6),TX_OCC+2(a0)
        move.b  #CH_R,TX_RACE(a0)       ; the race number
        move.w  G_RACE(a6),d0
        addq.b  #1,d0
        move.b  d0,TX_RACE+1(a0)
        move.b  #CH_SPC,TX_OCC+4(a0)    ; TK = takeover mode
        move.b  #CH_SPC,TX_OCC+5(a0)
        tst.w   G_TKON(a6)
        beq.s   .ntk
        move.b  #CH_T,TX_OCC+4(a0)
        move.b  #CH_K,TX_OCC+5(a0)
.ntk:
        tst.w   G_POLLOK(a6)
        bne.s   .pk
        move.b  #CH_EXCL,TX_PAUSE+1(a0) ; timing on the SV_RAND fallback
.pk:    movem.l (sp)+,d0-d2/a0-a1
        rts
        else
fmt_settings:                           ; (the panel's text: none)
        rts
        endc

        ifeq    RELB
fmt_stats:
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        moveq   #0,d0
        move.w  G_MS100(a6),d0
        divu.w  #100,d0
        move.l  d0,d2
        swap    d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_MSD+2(a6),a1
        moveq   #2-1,d1
        bsr     put_dec_a1
        move.l  d2,d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_MSI+3(a6),a1
        moveq   #3-1,d1
        bsr     put_dec_a1
        moveq   #0,d0
        move.w  G_FPS10(a6),d0
        divu.w  #10,d0
        move.l  d0,d2
        swap    d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_FPSD+1(a6),a1
        moveq   #0,d1
        bsr     put_dec_a1
        move.l  d2,d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_FPSI+2(a6),a1
        moveq   #2-1,d1
        bra     put_dec_a1

fmt_marble:
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        lea     G_MB(a6),a4
        move.l  M_X(a4),d0
        lsr.l   #8,d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_X+4(a6),a1
        moveq   #4-1,d1
        bsr     put_dec_a1
        move.l  M_Y(a4),d0
        lsr.l   #8,d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_Y+4(a6),a1
        moveq   #4-1,d1
        bsr     put_dec_a1
        move.l  M_Z(a4),d0
        lsr.l   #8,d0
        subi.w  #$8000,d0
        andi.l  #$FFFF,d0
        lea     G_TEXT+TX_Z+4(a6),a1
        moveq   #4-1,d1
        bsr     put_dec_a1
        moveq   #0,d0
        move.w  M_SCROLL(a4),d0
        lea     G_TEXT+TX_SC+4(a6),a1
        moveq   #4-1,d1
        bsr     put_dec_a1
        moveq   #0,d0
        move.w  M_STATE(a4),d0
        lea     G_TEXT+TX_ST+2(a6),a1
        moveq   #2-1,d1
        bsr     put_dec_a1
        moveq   #0,d0
        move.w  M_DEATHS(a4),d0
        lea     G_TEXT+TX_D+2(a6),a1
        moveq   #2-1,d1
        bsr     put_dec_a1
        lea     G_TEXT+TX_GOAL(a6),a1
        lea     txt_goal(pc),a0
        tst.b   M_RACING+1(a4)
        beq.s   .g
        lea     txt_nogoal(pc),a0
.g:     moveq   #4-1,d0
.c:     move.b  (a0)+,(a1)+
        dbra    d0,.c
        move.l  G_LATE(a6),d0           ; late frames (overruns), at most 9999
        cmpi.l  #9999,d0
        bls.s   .lt
        move.l  #9999,d0
.lt:    lea     G_TEXT+TX_LATE+4(a6),a1
        moveq   #4-1,d1
        bsr     put_dec_a1
        lea     G_TEXT+TX_RATE(a6),a1   ; the frame rate: "10" or "12.5"
        move.b  #1,(a1)+
        cmpi.w  #N_FAST,G_NT(a6)
        bne.s   .r10
        move.b  #2,(a1)+
        move.b  #CH_DOT,(a1)+
        move.b  #5,(a1)
        bra.s   .rsw
.r10:   clr.b   (a1)+
        move.b  #CH_SPC,(a1)+
        move.b  #CH_SPC,(a1)
.rsw:   moveq   #0,d0                   ; the switches, at most 99
        move.w  G_FSW(a6),d0
        cmpi.w  #99,d0
        bls.s   .sw
        moveq   #99,d0
.sw:    lea     G_TEXT+TX_SW+2(a6),a1
        moveq   #2-1,d1
        bra     put_dec_a1

; fmt_bench - line 1: progress or the result
fmt_bench:
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        lea     G_TEXT+L1(a6),a1
        moveq   #TEXT_W-1,d0
.c:     move.b  #CH_SPC,(a1)+
        dbra    d0,.c
        move.w  G_BENCH(a6),d0
        beq.s   .res
        lea     tplb(pc),a0
        lea     G_TEXT+L1(a6),a1
.cp:    move.b  (a0)+,d1
        bmi.s   .n
        move.b  d1,(a1)+
        bra.s   .cp
.n:     lea     G_TEXT+L1(a6),a0
        move.b  d0,6(a0)                ; "BENCH n/5 M m"
        subq.w  #1,d0
        move.b  d0,12(a0)
        rts
.res:   tst.w   G_BRES(a6)              ; no result yet
        beq.s   .out
        ; "T0 xx.xx CPY xx.xx LOG x.xx SPR x.xx INP x.xx"
        lea     tplr(pc),a0
        lea     G_TEXT+L1(a6),a1
.cr:    move.b  (a0)+,d1
        bmi.s   .v
        move.b  d1,(a1)+
        bra.s   .cr
.v:     move.w  G_BRES(a6),d0           ; T0
        lea     G_TEXT+L1+3(a6),a1
        bsr.s   put_ms
        move.w  G_BRES(a6),d0           ; CPY = T0 - T2
        sub.w   G_BRES+4(a6),d0
        lea     G_TEXT+L1+14(a6),a1
        bsr.s   put_ms
        move.w  G_BRES+2(a6),d0         ; LOG = (T1 - T0) / 9
        sub.w   G_BRES(a6),d0
        bpl.s   .lp
        moveq   #0,d0
.lp:    andi.l  #$FFFF,d0
        divu.w  #N_GHOST,d0
        lea     G_TEXT+L1+24(a6),a1
        bsr.s   put_ms
        move.w  G_BRES(a6),d0           ; SPR = T0 - T3
        sub.w   G_BRES+6(a6),d0
        lea     G_TEXT+L1+34(a6),a1
        bsr.s   put_ms
        move.w  G_BRES(a6),d0           ; INP = T0 - T4
        sub.w   G_BRES+8(a6),d0
        lea     G_TEXT+L1+44(a6),a1
        bsr.s   put_ms
        move.w  G_BRES(a6),d0           ; OCC = T0 - T5
        sub.w   G_BRES+10(a6),d0
        lea     G_TEXT+L1+54(a6),a1
        bra.s   put_ms
.out:   rts

; put_ms - d0.w = 1/100 ms (negative -> shown as 00.00 with a dash): "dd.dd"
; written from a1
put_ms:
        tst.w   d0
        bpl.s   .p
        move.b  #CH_DASH,-1(a1)
        neg.w   d0
.p:     andi.l  #$FFFF,d0
        divu.w  #100,d0
        move.l  d0,-(sp)
        andi.l  #$FFFF,d0
        addq.l  #2,a1
        moveq   #2-1,d1
        bsr.s   put_dec_a1
        move.b  #CH_DOT,2(a1)
        move.l  (sp)+,d0
        swap    d0
        andi.l  #$FFFF,d0
        addq.l  #5,a1
        moveq   #2-1,d1
; put_dec_a1 - d0.l value, a1 one past the last digit, d1 digits-1
put_dec_a1:
.d:     divu.w  #10,d0
        swap    d0
        move.b  d0,-(a1)
        clr.w   d0
        swap    d0
        dbra    d1,.d
        rts

;=============================================================================
; draw_panel - the glyphs that differ from what G_DEST already shows
;=============================================================================
draw_panel:
        addq.l  #1,G_PANELS(a6)
        lea     G_TEXT(a6),a2
        lea     G_SHAD0(a6),a3
        moveq   #0,d1                   ; this buffer's dirty bit
        move.l  G_DEST(a6),d0
        cmpi.l  #SCREEN,d0
        beq.s   .s0
        lea     G_SHAD1(a6),a3
        moveq   #1,d1
.s0:    bclr    d1,G_TDIRTY+1(a6)       ; only when the text changed since this
        bne.s   .go                     ; buffer last drew it (comparing all 256
        rts                             ; glyphs every frame costs ~3.6 ms)
.go:    move.l  d0,d3                   ; this buffer's screen
        moveq   #0,d4                   ; text line 0-3 (x2)
        lea     font(pc),a4
        moveq   #TEXT_LINES-1,d2
.ln:    moveq   #TEXT_W-1,d1
        lea     pan_rows(pc),a5
        move.w  0(a5,d4.w),d0
        movea.l d3,a5
        adda.w  d0,a5                   ; its screen row (top or bottom band)
        addq.w  #2,d4
.ch:    move.b  (a2)+,d0
        cmp.b   (a3)+,d0
        beq.s   .same
        move.b  d0,-1(a3)
        addq.l  #1,G_GLYPHS(a6)         ; (diagnostics: glyphs drawn)
        andi.w  #$FF,d0
        lsl.w   #4,d0
        lea     0(a4,d0.w),a0
        move.w  (a0)+,(a5)
        move.w  (a0)+,BPL(a5)
        move.w  (a0)+,2*BPL(a5)
        move.w  (a0)+,3*BPL(a5)
        move.w  (a0)+,4*BPL(a5)
        move.w  (a0)+,5*BPL(a5)
        move.w  (a0)+,6*BPL(a5)
.same:  addq.l  #2,a5
        dbra    d1,.ch
        bsr     tk_poll
        dbra    d2,.ln
        rts
pan_rows:                               ; text lines L0-L3 -> screen line x BPL
        dc.w    PANEL_TOP*BPL,PANEL_BOT*BPL
        dc.w    (PANEL_TOP+PANEL_STEP)*BPL,(PANEL_BOT+PANEL_STEP)*BPL
        endc

;=============================================================================
; the HUD: one line of the small font in
; the top band, centred in it (line (PTOP - 7) / 2), when the panel is off:
;   cols 1-13  SCORE 012,340   (cyan label, white digits, a comma)
;   cols 27-34 TIME 59 / OFF   (cyan label, yellow; OFF: key C)
;   cols 50-62 the race's name (green, right-aligned)
; G_OVL: 0 nothing, 1 the debug panel, 2 the HUD (O swaps 1 / 2). hud_fmt
; (each frame, the HUD on) writes a field's text when its value changed; each
; column that changes is queued for both screens (hud_set); hud_draw draws, on
; the screen at G_DEST, at most HUD_BUD queued columns a game frame (all at a
; race's load: top_now): a coloured glyph = the white font word AND the
; column's mask. Nothing queued: out at once.
;=============================================================================
HUD_SC          equ 7                   ; the score's 7 columns (012,340)
HUD_TM          equ 32                  ; the time's 3 (59 / OFF)
HUD_RE          equ 63                  ; the race's name ends before it
HUD_BUD         equ 2                   ; glyphs a game frame draws at most (a screen):
                                        ; the rest the next (the worst frame's cost)

; HSET col,ea - column col shows the glyph at ea: hud_set, only when it differs
HSET    macro
        move.b  \2,d1
        cmp.b   G_HUDT+\1(a6),d1
        beq.s   .h\@
        move.b  d1,G_HUDT+\1(a6)
        moveq   #\1,d0
        bsr     hud_q
.h\@:
        endm

; hud_reset - the HUD unknown on both screens: the bands cleared (clear_tail),
; every column queued; its text: blank, the labels, the values written again
hud_reset:
        movem.l d0-d2/a0-a1,-(sp)
        move.w  #1,G_CLR0(a6)
        move.w  #1,G_CLR1(a6)
        move.l  #-1,G_HSCORE(a6)
        move.w  #-3,G_HTIME(a6)
        move.w  #-1,G_HRACE(a6)
        st      G_HCHG(a6)
        lea     G_HUDT(a6),a0
        moveq   #64-1,d0
.sp:    move.b  #CH_SPC,(a0)+
        dbra    d0,.sp
        lea     hud_lbl(pc),a0
.l:     moveq   #0,d0
        move.b  (a0)+,d0                ; column (0: the end)
        beq.s   .x
        lea     G_HUDT(a6),a1
        adda.w  d0,a1
        moveq   #0,d1
        move.b  (a0)+,d1                ; length
        subq.w  #1,d1
.c:     move.b  (a0)+,(a1)+
        dbra    d1,.c
        bra.s   .l
.x:     lea     G_HQN0(a6),a0
        bsr.s   hud_qall
        clr.w   G_HQN1(a6)              ; (screen 1: only when dual)
        tst.w   G_DUAL(a6)
        beq.s   .x1
        lea     G_HQN1(a6),a0
        bsr.s   hud_qall
.x1:    move.w  #HUD_BUD,G_HBUDS(a6)
        movem.l (sp)+,d0-d2/a0-a1
        rts
hud_lbl:
        dc.b    1,5,CH_S,CH_C,CH_O,CH_R,CH_E
        dc.b    10,1,CH_COMMA
        dc.b    27,4,CH_T,CH_I,CH_M,CH_E
        dc.b    0
        even

; hud_qall - a screen's queue (a0: its count) holds every column. Uses d0
hud_qall:
        move.w  #64,(a0)+
        moveq   #0,d0
.q:     move.b  d0,(a0)+
        addq.b  #1,d0
        cmpi.b  #64,d0
        blo.s   .q
        rts

; hud_set - column d0.w shows glyph d1.b: when that changes, it is queued for
; both screens (screen 1 only when dual: it is drawn only then); a queue near
; full holds every column instead. Uses d2 / a0
hud_qo: rts
hud_set:
        lea     G_HUDT(a6),a0
        cmp.b   0(a0,d0.w),d1
        beq.s   hud_qo
        move.b  d1,0(a0,d0.w)
; hud_q - column d0.w queued for both screens (as hud_set). Uses d2 / a0
hud_q:  st      G_HFMTW(a6)             ; (hud_draw draws nothing this frame)
        lea     G_HQN0(a6),a0
        bsr.s   .q
        tst.w   G_DUAL(a6)
        beq.s   .o
        lea     G_HQN1(a6),a0
.q:     move.w  (a0),d2
        cmpi.w  #62,d2
        bhs.s   .f
        addq.w  #1,(a0)
        move.b  d0,2(a0,d2.w)
.o:     rts
.f:     move.w  d0,-(sp)
        bsr.s   hud_qall
        move.w  (sp)+,d0
        rts

; hud_fmt - the HUD's fields from the game, each frame (the HUD on): the score
; (M_SCORE: 3 base-100 bytes) and the time (G_HTOVR when bit 15: the TIME TO
; FINISH count's; OFF with the timer off); a changed value is written, two
; digits a base-100 byte through hud_dig (no division), column by column
; (hud_set). hud_fmtr: also the race's name (a race's load: top_now)
hud_fmtr:
        move.w  G_RACE(a6),d0
        cmp.w   G_HRACE(a6),d0
        beq.s   hud_fmt
        move.w  d0,G_HRACE(a6)
        add.w   d0,d0
        lea     hud_names(pc),a1
        adda.w  0(a1,d0.w),a1
        moveq   #0,d3
        move.b  (a1)+,d3                ; its length
        moveq   #HUD_RE,d5
        sub.w   d3,d5                   ; its first column
        moveq   #HUD_RE-13,d4           ; (13 columns: blank before it)
.rc:    moveq   #CH_SPC,d1
        cmp.w   d5,d4
        blo.s   .rs
        move.b  (a1)+,d1
.rs:    move.w  d4,d0
        bsr     hud_set
        addq.w  #1,d4
        cmpi.w  #HUD_RE,d4
        blo.s   .rc
hud_fmt:
        move.l  G_MB+M_SCORE(a6),d0
        cmp.l   G_HSCORE(a6),d0
        bne.s   .sc
.t:     move.w  G_MB+M_TIME(a6),d0
        tst.w   G_HTOVR(a6)
        bmi.s   .ov
        tst.w   G_TIMOFF(a6)
        bne.s   .off
.t1:    cmp.w   G_HTIME(a6),d0
        bne     .tw
        rts
.ov:    moveq   #0,d0
        move.b  G_HTOVR+1(a6),d0
        bra.s   .t1
.off:   move.w  #$FFFE,d0               ; OFF
        bra.s   .t1
.sc:    move.l  d0,G_HSCORE(a6)         ; hh mm ll -> cols 0-1, 2 / 4, 5-6 (3: ,)
        move.l  d0,d3                   ; (the time waits a frame: one field a frame)
        lea     hud_dig(pc),a1
        moveq   #0,d4
        move.b  d3,d4                   ; ll
        add.w   d4,d4
        HSET    HUD_SC+5,0(a1,d4.w)
        HSET    HUD_SC+6,1(a1,d4.w)
        lsr.l   #8,d3
        moveq   #0,d4
        move.b  d3,d4                   ; mm
        add.w   d4,d4
        HSET    HUD_SC+2,0(a1,d4.w)
        HSET    HUD_SC+4,1(a1,d4.w)
        lsr.w   #8,d3
        moveq   #0,d4
        move.b  d3,d4                   ; hh
        add.w   d4,d4
        HSET    HUD_SC,0(a1,d4.w)
        HSET    HUD_SC+1,1(a1,d4.w)
        st      G_HCHG(a6)              ; (the time, if it changed: next frame)
        rts
.tw:    move.w  d0,G_HTIME(a6)
        move.w  d0,d3
        cmpi.w  #$FFFE,d3
        bne.s   .td
        moveq   #HUD_TM,d0
        moveq   #CH_O,d1
        bsr     hud_set
        moveq   #HUD_TM+1,d0
        moveq   #CH_F,d1
        bsr     hud_set
        moveq   #HUD_TM+2,d0
        moveq   #CH_F,d1
        bra     hud_set
.td:    lea     hud_dig(pc),a1
        andi.w  #$FF,d3
        add.w   d3,d3
        moveq   #HUD_TM,d0
        move.b  0(a1,d3.w),d1
        bsr     hud_set
        moveq   #HUD_TM+1,d0
        move.b  1(a1,d3.w),d1
        bsr     hud_set
        moveq   #HUD_TM+2,d0
        moveq   #CH_SPC,d1
        bra     hud_set
hud_dig:                                ; 0-99 (and up to 255): its two digits' glyphs
        dc.b    0,0,0,1,0,2,0,3,0,4,0,5,0,6,0,7,0,8,0,9,1,0,1,1,1,2,1,3,1,4,1,5
        dc.b    1,6,1,7,1,8,1,9,2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7,2,8,2,9,3,0,3,1
        dc.b    3,2,3,3,3,4,3,5,3,6,3,7,3,8,3,9,4,0,4,1,4,2,4,3,4,4,4,5,4,6,4,7
        dc.b    4,8,4,9,5,0,5,1,5,2,5,3,5,4,5,5,5,6,5,7,5,8,5,9,6,0,6,1,6,2,6,3
        dc.b    6,4,6,5,6,6,6,7,6,8,6,9,7,0,7,1,7,2,7,3,7,4,7,5,7,6,7,7,7,8,7,9
        dc.b    8,0,8,1,8,2,8,3,8,4,8,5,8,6,8,7,8,8,8,9,9,0,9,1,9,2,9,3,9,4,9,5
        dc.b    9,6,9,7,9,8,9,9,0,0,0,1,0,2,0,3,0,4,0,5,0,6,0,7,0,8,0,9,1,0,1,1
        dc.b    1,2,1,3,1,4,1,5,1,6,1,7,1,8,1,9,2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7
        dc.b    2,8,2,9,3,0,3,1,3,2,3,3,3,4,3,5,3,6,3,7,3,8,3,9,4,0,4,1,4,2,4,3
        dc.b    4,4,4,5,4,6,4,7,4,8,4,9,5,0,5,1,5,2,5,3,5,4,5,5,5,6,5,7,5,8,5,9
        dc.b    6,0,6,1,6,2,6,3,6,4,6,5,6,6,6,7,6,8,6,9,7,0,7,1,7,2,7,3,7,4,7,5
        dc.b    7,6,7,7,7,8,7,9,8,0,8,1,8,2,8,3,8,4,8,5,8,6,8,7,8,8,8,9,9,0,9,1
        dc.b    9,2,9,3,9,4,9,5,9,6,9,7,9,8,9,9,0,0,0,1,0,2,0,3,0,4,0,5,0,6,0,7
        dc.b    0,8,0,9,1,0,1,1,1,2,1,3,1,4,1,5,1,6,1,7,1,8,1,9,2,0,2,1,2,2,2,3
        dc.b    2,4,2,5,2,6,2,7,2,8,2,9,3,0,3,1,3,2,3,3,3,4,3,5,3,6,3,7,3,8,3,9
        dc.b    4,0,4,1,4,2,4,3,4,4,4,5,4,6,4,7,4,8,4,9,5,0,5,1,5,2,5,3,5,4,5,5
hud_names:
        dc.w    hud_n0-hud_names,hud_n1-hud_names,hud_n2-hud_names
        dc.w    hud_n3-hud_names,hud_n4-hud_names,hud_n5-hud_names
hud_n0:  dc.b    8,CH_P,CH_R,CH_A,CH_C,CH_T,CH_I,CH_C,CH_E
        even
hud_n1:  dc.b    8,CH_B,CH_E,CH_G,CH_I,CH_N,CH_N,CH_E,CH_R
        even
hud_n2:  dc.b    12,CH_I,CH_N,CH_T,CH_E,CH_R,CH_M,CH_E,CH_D,CH_I,CH_A,CH_T,CH_E
        even
hud_n3:  dc.b    6,CH_A,CH_E,CH_R,CH_I,CH_A,CH_L
        even
hud_n4:  dc.b    5,CH_S,CH_I,CH_L,CH_L,CH_Y
        even
hud_n5:  dc.b    8,CH_U,CH_L,CH_T,CH_I,CH_M,CH_A,CH_T,CH_E
        even
        even

; hud_draw - on the screen at G_DEST, its queued columns (the last first): at
; most G_HBUDS of them (HUD_BUD a game frame: the worst frame's cost), the rest
; the next time; the queue empty: out at once
hud_draw:
        move.w  G_HQN0(a6),d0           ; (nothing queued: out at once)
        or.w    G_HQN1(a6),d0
        bne.s   .q
        rts
.q:     tst.b   G_HFMTW(a6)             ; (hud_fmt queued columns this frame: they
        bne     hud_dw                  ;  are drawn from the next: the worst frame
        lea     G_HQN0(a6),a3           ;  formats or draws, not both)
        move.l  G_DEST(a6),d3
        cmpi.l  #SCREEN,d3
        beq.s   .s0
        lea     G_HQN1(a6),a3
.s0:    move.w  (a3),d2
        bne.s   .go
        rts
.go:    movea.l d3,a5
        move.w  G_PTOP(a6),d0
        subq.w  #7,d0
        asr.w   #1,d0
        lsl.w   #7,d0
        adda.w  d0,a5                   ; the HUD's line
        lea     hud_cols(pc),a4
        lea     G_HUDT(a6),a2
        move.w  G_HBUDS(a6),d6
.g:     subq.w  #1,d6
        bmi.s   .out
        subq.w  #1,d2
        moveq   #0,d5
        move.b  2(a3,d2.w),d5           ; a column
        ifeq    RELB
        addq.l  #1,G_GLYPHS(a6)         ; (diagnostics: glyphs drawn)
        endc
        moveq   #0,d0
        move.b  0(a2,d5.w),d0           ; its glyph
        add.w   d5,d5
        move.w  0(a4,d5.w),d1           ; the column's colour mask
        lea     0(a5,d5.w),a1
        lsl.w   #4,d0
        lea     font(pc),a0
        adda.w  d0,a0
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,BPL(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,2*BPL(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,3*BPL(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,4*BPL(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,5*BPL(a1)
        move.w  (a0)+,d0
        and.w   d1,d0
        move.w  d0,6*BPL(a1)
        tst.w   d2
        bne.s   .g
.out:   move.w  d2,(a3)
        bsr     tk_poll
        tst.w   d2
        beq.s   hud_drawn
        rts
hud_drawn:                              ; (global: the queue drawn: the emulator test
        rts                             ;  hooks it)
hud_dw: sf      G_HFMTW(a6)
        rts

hud_cols:                               ; per column: the colour mask
        dc.w    $AAFF,$AA55,$AA55,$AA55,$AA55,$AA55,$AAFF,$AAFF
        dc.w    $AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF
        dc.w    $AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF
        dc.w    $AAFF,$AAFF,$AAFF,$AA55,$AA55,$AA55,$AA55,$AAFF
        dc.w    $AAAA,$AAAA,$AAAA,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF
        dc.w    $AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF,$AAFF
        dc.w    $AAFF,$AAFF,$AA00,$AA00,$AA00,$AA00,$AA00,$AA00
        dc.w    $AA00,$AA00,$AA00,$AA00,$AA00,$AA00,$AA00,$AAFF

; top_now - the top band now, on both screens when dual (the race boxes: the
; logic idle, no main loop): the time / score as they are, the panel or the HUD
top_now:
        movem.l d0-d7/a0-a5,-(sp)
        move.l  G_DEST(a6),-(sp)
        move.l  #SCREEN,G_DEST(a6)
        bsr.s   .one
        tst.w   G_DUAL(a6)
        beq.s   .x
        move.l  #SCREEN1,G_DEST(a6)
        bsr.s   .one
.x:     move.l  (sp)+,G_DEST(a6)
        movem.l (sp)+,d0-d7/a0-a5
        rts
.one:   bsr     tk_poll                 ; (the takeover's frame flag: the gap)
        bsr     clear_tail              ; (a band cleared first, if due)
        bsr     tk_poll
        bsr     fmt_time
        ifeq    RELB
        move.w  G_OVL(a6),d0
        subq.w  #1,d0
        bmi.s   .n
        bne.s   .h
        bra     draw_panel
        endc
.h:     bsr     hud_fmtr
        bsr     hud_fmt                 ; (the time too: one field a call)
        sf      G_HFMTW(a6)
        move.w  #999,G_HBUDS(a6)        ; (all at once: the logic idle)
        bsr     hud_draw
        move.w  #HUD_BUD,G_HBUDS(a6)
.n:     rts

        ifeq    RELB
;=============================================================================
; DEMO input: the inputs of a recorded Practice race (demo_pads),
; one per QL frame, from the race start. D toggles it; B always uses it, so the
; benchmark needs no held key and every mode sees the same marble run.
;=============================================================================
demo_start:
        clr.w   G_DPOS(a6)
        clr.w   G_PPAD(a6)
        bsr     restart
        bra     ghosts_init

demo_pad:                               ; (jumped to from read_input)
        move.w  G_DPOS(a6),d0
        cmpi.w  #DEMO_LEN,d0
        blo.s   .ok
        bsr     demo_start              ; the end: from the start again
        moveq   #0,d0
.ok:    lea     demo_pads(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        tst.l   G_TIMG(a6)              ; (a bench position: no input, the marble
        beq.s   .p                      ; stays where the position put it)
        moveq   #0,d1
.p:     move.w  d1,G_PAD(a6)
        addq.w  #1,d0
        move.w  d0,G_DPOS(a6)
        rts

;=============================================================================
; LAB (key L) - where does the time go? Each item is timed with the frame
; counter + the calibrated spin loop (as the busy time is), over 0.1-1 s:
;   R   a register-only loop (4 x add.l + dbra) in the program's own memory
;   F   the same with 4 word READS from the globals (the program's memory)
;   S   ... reads from the displayed screen (line 255: display-contended RAM)
;   V   ... reads from the system variables (QL internal RAM)
;   K   ... reads from the stack (BASIC's stack: where the logic's bsr/rts go)
;   CS  the register loop COPIED to screen line 255 and run there
;   CK  the register loop copied to the stack and run there
;   E   an empty call (jsr + rts)
;   LOG one QL frame of the marble logic (6 sub-steps) on a scratch marble,
;       100 frames of the demo input from the race start
;   NK  the same without the behind-scenery kill check
;   FS  LOG with the stack moved into the program's memory
; R..CK in us per loop pass (5 instructions), E in us, LOG/NK/FS in ms per QL
; frame. Comparing R with F/S/V/K and CS/CK shows which memory is slow;
; LOG vs FS shows what the stack's position costs.
;=============================================================================
LAB_REGW        equ     (lab_reg_end-lab_reg)/2

lab_run:
        movem.l d0-d7/a0-a5,-(sp)
        tst.l   G_K(a6)
        beq     .none
        lea     -32(sp),sp              ; a code buffer on the caller's stack
        move.l  sp,G_LSKC(a6)
        lea     lab_reg(pc),a0
        movea.l sp,a1
        moveq   #LAB_REGW-1,d0
.c1:    move.w  (a0)+,(a1)+
        dbra    d0,.c1
        move.l  #SCREEN+255*BPL,d0      ; and on the displayed screen's line 255
        tst.w   G_SHOWN(a6)
        beq.s   .s0
        move.l  #SCREEN1+255*BPL,d0
.s0:    move.l  d0,G_LSCR(a6)
        movea.l d0,a1
        lea     lab_reg(pc),a0
        moveq   #LAB_REGW-1,d0
.c2:    move.w  (a0)+,(a1)+
        dbra    d0,.c2

        lea     lab_reg(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+0(a6)
        lea     lab_rdf(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+4(a6)
        lea     lab_rds(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+8(a6)
        lea     lab_rdv(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+12(a6)
        lea     lab_rdk(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+16(a6)
        lea     lab_csc(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+20(a6)
        lea     lab_csk(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+24(a6)
        lea     lab_emp(pc),a2
        move.w  #20000,d7
        bsr     lab_time
        move.l  d0,G_LAB+28(a6)
        bsr     lab_logstart
        lea     lab_log(pc),a2
        moveq   #100,d7
        bsr     lab_time
        move.l  d0,G_LAB+32(a6)
        bsr     lab_logstart
        move.w  #1,G_NOKILL(a6)
        lea     lab_log(pc),a2
        moveq   #100,d7
        bsr     lab_time
        move.l  d0,G_LAB+36(a6)
        clr.w   G_NOKILL(a6)
        bsr     lab_logstart
        lea     lab_logfs(pc),a2
        moveq   #100,d7
        bsr     lab_time
        move.l  d0,G_LAB+40(a6)
        bsr     lab_irqoff              ; R with the interrupts off
        move.l  d0,G_LAB+44(a6)
        lea     lab_drn(pc),a2
        move.w  #1000,d7
        bsr     lab_time
        move.l  d0,G_LAB+48(a6)
        lea     lab_kr(pc),a2
        moveq   #100,d7
        bsr     lab_time
        move.l  d0,G_LAB+52(a6)
        lea     lab_pan(pc),a2
        moveq   #50,d7
        bsr     lab_time
        move.l  d0,G_LAB+56(a6)
        lea     lab_pi(pc),a2
        moveq   #100,d7                 ; (keep each item under ~2 s: 32-bit sums)
        bsr     lab_time
        move.l  d0,G_LAB+60(a6)
        lea     draw_linear(pc),a2      ; the background copy (into the hidden
        moveq   #10,d7                  ; screen; LINES lines)
        bsr     lab_time
        move.l  d0,G_LAB+64(a6)
        lea     lab_spr(pc),a2          ; the marble drawn (at the race start)
        moveq   #100,d7
        bsr     lab_time
        move.l  d0,G_LAB+68(a6)

        movea.l G_LSCR(a6),a1           ; line 255 back to black
        moveq   #LAB_REGW-1,d0
.c3:    clr.w   (a1)+
        dbra    d0,.c3
        lea     32(sp),sp
        bsr     ghosts_init             ; (the scratch marble was ghost 0)
        move.w  #1,G_LABOK(a6)
        bsr     fmt_lab
.none:  movem.l (sp)+,d0-d7/a0-a5
        rts

; lab_time - time d7.w calls of (a2). Out: d0.l = 1/100 us per call.
lab_time:
        move.l  a2,G_LA2(a6)
        move.w  d7,G_LN(a6)
        move.w  d7,-(sp)
        bsr     get_tick
        move.w  d0,d1
        addq.w  #1,d1
        move.l  G_K(a6),d4
        add.l   d4,d4
        bsr     spin_to                 ; start on a tick edge
        move.w  d1,G_LT0(a6)
.l:     movea.l G_LA2(a6),a2
        jsr     (a2)
        bsr     tk_poll
        subq.w  #1,G_LN(a6)
        bne.s   .l
        bsr     get_tick
        move.w  d0,d1
        addq.w  #1,d1
        move.l  G_K(a6),d4
        add.l   d4,d4
        bsr     spin_to                 ; d5 = spins up to the next edge
        moveq   #0,d3
        move.w  d1,d3
        sub.w   G_LT0(a6),d3            ; whole ticks
        move.l  G_K(a6),d2
        mulu.w  d2,d3                   ; in spins (K < 65536)
        sub.l   d5,d3                   ; the time taken, in spins
        bsr     mul2000
        move.l  d3,d1
        add.l   d1,d1
        lsl.l   #3,d3
        add.l   d3,d1                   ; spins x 20000
        move.l  G_K(a6),d2
        bsr     udiv32                  ; us in all (one tick = 20000 us)
        move.l  d1,d0                   ; x 100 = x 64 + x 32 + x 4
        lsl.l   #2,d1
        move.l  d1,d2
        lsl.l   #3,d1
        add.l   d1,d2
        add.l   d1,d1
        add.l   d2,d1
        moveq   #0,d2
        move.w  (sp)+,d2
        bsr     udiv32
        move.l  d1,d0
        rts

lab_reg:
        moveq   #63,d3
.l:     add.l   d1,d2
        add.l   d1,d2
        add.l   d1,d2
        add.l   d1,d2
        dbra    d3,.l
        rts
lab_reg_end:

lab_rd:
        moveq   #63,d3
.l:     move.w  (a0),d0
        move.w  (a0),d0
        move.w  (a0),d0
        move.w  (a0),d0
        dbra    d3,.l
        rts
lab_rdf:
        lea     globals(pc),a0
        bra.s   lab_rd
lab_rds:
        movea.l G_LSCR(a6),a0
        bra.s   lab_rd
lab_rdv:
        movea.l G_SYS(a6),a0
        bra.s   lab_rd
lab_rdk:
        lea     4(sp),a0
        bra.s   lab_rd
lab_csc:
        movea.l G_LSCR(a6),a0
        jmp     (a0)
lab_csk:
        movea.l G_LSKC(a6),a0
        jmp     (a0)
lab_emp:
        rts

; lab_logstart - the scratch marble (ghost 0) at the race start, demo frame 0
lab_logstart:
        lea     G_GHOST(a6),a4
        bsr     restart_a4
        clr.w   G_LPP(a6)
        clr.w   G_LDP(a6)
        rts

; lab_log - one QL frame of the logic on the scratch marble, demo input
lab_log:
        move.w  G_LDP(a6),d0
        lea     demo_pads(pc),a0
        moveq   #0,d1
        move.b  0(a0,d0.w),d1
        addq.w  #1,G_LDP(a6)
        move.w  G_LPP(a6),d2
        not.w   d2
        and.w   d1,d2
        move.w  d2,G_PNEW(a6)
        move.w  d1,G_LPP(a6)
        move.w  d1,G_PAD(a6)
        lea     G_GHOST(a6),a4
        bra     run_substeps

lab_logfs:
        move.l  sp,G_LSAV(a6)
        lea     G_LSTK+LAB_STK(a6),sp
        bsr     lab_log
        movea.l G_LSAV(a6),sp
        rts

; fmt_lab - panel lines 1 (the results row, where B's line is) and 3
fmt_lab:
        move.w  #3,G_TDIRTY(a6)         ; (both buffers redraw the panel)
        lea     tpll2(pc),a0
        lea     G_TEXT+L1(a6),a1
        bsr     .copy
        lea     tpll3(pc),a0
        lea     G_TEXT+L3(a6),a1
        bsr     .copy
        lea     lab_pos(pc),a3
        moveq   #LAB_SHOWN-1,d7
.v:     move.w  (a3)+,d0                ; G_LAB index
        lea     G_LAB(a6),a2
        move.l  0(a2,d0.w),d0
        move.w  (a3)+,d1                ; text position
        move.w  (a3)+,d2                ; divisor (64: per loop pass, 1000: ms)
        lea     G_TEXT(a6),a1
        adda.w  d1,a1
        move.l  d0,d1
        andi.l  #$FFFF,d2
        bsr     udiv32
        cmpi.l  #9999,d1
        bls.s   .w
        move.l  #9999,d1
.w:     move.l  d1,d0
        bsr     put_ms
        dbra    d7,.v
        ; IQ: the interrupts' share of the CPU, (R - RI) / R in 1/100 %
        move.l  G_LAB+44(a6),d0
        beq.s   .iq
        move.l  G_LAB(a6),d2
        move.l  d2,d1
        sub.l   d0,d1
        bpl.s   .iqp
        moveq   #0,d1
.iqp:   move.l  d1,d3
        bsr     mul2000
        move.l  d3,d1
        add.l   d1,d1
        lsl.l   #2,d3
        add.l   d3,d1                   ; x 10000
        bsr     udiv32
        move.l  d1,d0
.iq:    lea     G_TEXT+L1+20(a6),a1
        bsr     put_ms
        move.l  G_SP0(a6),d0
        lea     G_TEXT+L3+48(a6),a1
        moveq   #6-1,d1
        bsr     put_hex
        lea     globals(pc),a0
        move.l  a0,d0
        lea     G_TEXT+L3+57(a6),a1
        moveq   #6-1,d1
        bra     put_hex
.copy:  moveq   #TEXT_W-1,d0
        movea.l a1,a4
.cl:    move.b  #CH_SPC,(a4)+
        dbra    d0,.cl
.cp:    move.b  (a0)+,d0
        bmi.s   .e
        move.b  d0,(a1)+
        bra.s   .cp
.e:     rts

; put_hex - d0.l, a1 one past the last digit, d1 digits-1
put_hex:
.h:     moveq   #$0F,d2
        and.w   d0,d2
        cmpi.w  #10,d2
        blo.s   .d
        addi.w  #CH_A-10,d2
.d:     move.b  d2,-(a1)
        lsr.l   #4,d0
        dbra    d1,.h
        rts

; (G_LAB byte index, text position, divisor) of each LAB result shown
lab_pos:
        dc.w    0,L1+2,64, 44,L1+11,64, 48,L1+30,1000, 52,L1+39,1000, 56,L1+49,1000
        dc.w    60,L1+58,1000, 32,L3+4,1000, 36,L3+13,1000, 64,L3+23,1000, 68,L3+33,1000
LAB_SHOWN       equ     10

tpll2:  ; "R 00.00 RI 00.00 IQ 00.00 DRN 00.00 KR 00.00 PAN 00.00 PI 00.00"
        dc.b    CH_R,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_R,CH_I,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_I,CH_Q,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_D,CH_R,CH_N,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_K,CH_R,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_P,CH_A,CH_N,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_P,CH_I,CH_SPC,0,0,CH_DOT,0,0,-1
        even
tpll3:  ; "LOG 00.00 NK 00.00 CPY 00.00 SPR 00.00 SP 000000 C 000000"
        dc.b    CH_L,CH_O,CH_G,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_N,CH_K,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_C,CH_P,CH_Y,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_S,CH_P,CH_R,CH_SPC,0,0,CH_DOT,0,0,CH_SPC
        dc.b    CH_S,CH_P,CH_SPC,0,0,0,0,0,0,CH_SPC
        dc.b    CH_C,CH_SPC,0,0,0,0,0,0,-1
        even
        endc

;=============================================================================
; OCCLUSION - the marble behind scenery. Once per QL frame, for
; the frame drawn now: the occluder lists of the marble's 3 (4 for the 24-px
; frames) screen columns are walked exactly as the kill check walks them
; (mlogic col_codes); each column gives 3 mask codes, one per 8-line course
; band; code c's 8 bytes at GEO_OPAT + 8c say, per line, which
; pixels of the column stay visible (bit 7 - (x & 7)); the game shifts its
; masks in 2-px steps (the marble's x rounded down to even). Codes with bit 7
; kill (the logic's kill check) and mask nothing here.
; The result is G_HIDE: 16 lines x 7 words, one per sprite data word of the
; current shift, in the Mode 8 layout (both bits of every hidden pixel set),
; drawn with  screen = (screen AND (mask OR hide)) OR (data AND NOT hide).
; G_HMASK = 0 when nothing hides the marble: the PLAIN kernels are used.
; (hide_lut2: data/proto_occ.inc, 256 longs: a visibility byte -> 2 hide words)
; A quick test first (GEO_OMAP: per course row, the columns where any entry
; could give a non-zero mask code) skips the walk almost everywhere.
; M toggles it (default on); measuring mode 5 runs without it.
;=============================================================================
HIDE_ROWB       equ     16              ; 8 words a line (7 used)

; occ_build's line: V = the band's 4 pattern bytes of line d6 (a0-a3), in d4
HPACK   macro
        move.b  0(a0,d6.w),d4
        lsl.w   #8,d4
        move.b  0(a1,d6.w),d4
        swap    d4
        move.b  0(a2,d6.w),d4
        lsl.w   #8,d4
        move.b  0(a3,d6.w),d4
        endm
; HLOOK o - V's top byte (rotated down) as two hide words at o(a4)
HLOOK   macro
        moveq   #0,d1
        rol.l   #8,d4
        move.b  d4,d1
        lsl.w   #2,d1
        move.l  0(a5,d1.w),\1(a4)
        endm
; HROW loop - the line's hide words from V (shifted; all ones: a zero line, its
; G_HRM bit cleared), words 0-5 (6-7 for 24-px frames: d5 bit 31), the next line
HROW    macro
        moveq   #-1,d1
        cmp.l   d1,d4
        beq.s   .z\@
        HLOOK   0
        HLOOK   4
        HLOOK   8
        tst.l   d5
        bpl.s   .n\@
        HLOOK   12
        bra.s   .n\@
.z\@:   clr.l   (a4)
        clr.l   4(a4)
        clr.l   8(a4)
        clr.l   12(a4)
        move.w  d7,d1
        addi.w  #16,d1
        bclr    d1,d7
.n\@:   lea     HIDE_ROWB(a4),a4
        addq.w  #1,d7
        addq.w  #1,d6
        dbra    d3,\1
        endm

occ_build:                              ; a4 = marble, a5 = frame record,
        clr.w   G_HMASK(a6)             ; G_SPX = the frame's left edge
        tst.w   G_OCCON(a6)
        beq     .out
        ifeq    RELB
        cmpi.w  #5,G_MODE(a6)
        beq     .out
        endc
        move.w  (a5),G_ONW(a6)          ; words a row (5 or 7)
        move.w  M_S(a4),d0              ; (X+Y)/2 + Z = S + scroll - $C0
        add.w   M_SCROLL(a4),d0
        subi.w  #$C0+$7F3F,d0
        moveq   #7,d6
        and.w   d0,d6                   ; the sprite top's line in its band
        move.w  d6,G_OF(a6)
        lsr.w   #3,d0
        andi.w  #$FF,d0
        move.w  d0,d5                   ; its band (row)
        move.w  G_SPX(a6),d4
        andi.w  #$FF,d4
        lsr.w   #3,d4                   ; first column
        move.w  d4,G_OC0(a6)
        moveq   #7,d3
        cmpi.w  #7,G_ONW(a6)
        bne.s   .n
        moveq   #15,d3
.n:     movea.l G_PGEO(a6),a0
        adda.l  #GEO_OMAP,a0
        move.w  d5,d0
        add.w   d0,d0
        add.w   d0,d0
        move.l  0(a0,d0.w),d0
        beq     .out
        ror.l   d4,d0
        and.l   d3,d0
        beq     .out
        ; the columns' codes (the kill check's walk)
        lea     -KC_SIZE(sp),sp
        move.w  d5,KC_ROW(sp)
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
        movea.l G_PGEO(a6),a5
        lea     GEO_OHGT(a5),a2
        lea     GEO_OSHP(a5),a3
        clr.w   G_OANY(a6)
        clr.l   G_OCP+12(a6)            ; (a 16-px frame needs 3 columns)
        moveq   #3,d0
        cmpi.w  #7,G_ONW(a6)
        bne.s   .n3
        moveq   #4,d0
.n3:    move.w  d0,G_ONC(a6)
        moveq   #0,d7
.col:   move.w  G_OC0(a6),d0
        add.w   d7,d0
        andi.w  #31,d0
        add.w   d0,d0
        lea     GEO_OCOL(a5),a0
        move.w  0(a0,d0.w),d0
        lea     0(a5,d0.w),a0
        bsr     col_codes               ; a1 = 3 codes, or 0
        move.w  d7,d0
        add.w   d0,d0
        add.w   d0,d0
        lea     G_OCP(a6),a0
        move.l  a1,0(a0,d0.w)
        move.l  a1,d0
        beq.s   .nx
        move.w  #1,G_OANY(a6)
.nx:    addq.w  #1,d7
        cmp.w   G_ONC(a6),d7
        blo.s   .col
        lea     KC_SIZE(sp),sp
        tst.w   G_OANY(a6)
        beq     .out
        ; per band (0-2) and column: the pattern row of its code (GEO_OPAT + 8 code);
        ; code 0's row (all visible) where there is no occluder or a kill code
        movea.l G_PGEO(a6),a3
        adda.l  #GEO_OPAT,a3            ; (past 32 KB: not a displacement)
        lea     G_OPB(a6),a1
        adda.w  G_OPBO(a6),a1           ; (this frame's buffer)
        moveq   #0,d6                   ; band
.pb:    lea     G_OCP(a6),a0
        moveq   #3,d3
.pk:    movea.l a3,a2                   ; all visible
        move.l  (a0)+,d1
        beq.s   .pp
        movea.l d1,a5
        moveq   #0,d1
        move.b  0(a5,d6.w),d1
        bmi.s   .pp                     ; a kill code: no mask
        lsl.w   #3,d1
        adda.w  d1,a2
.pp:    move.l  a2,(a1)+
        dbra    d3,.pk
        addq.w  #1,d6
        cmpi.w  #3,d6
        blo.s   .pb
        ; the hide words, line by line: V = the 4 columns' visibility bytes,
        ; shifted by c so that each byte of it covers two sprite words; a
        ; 256-entry table turns a byte into those two hide words
        move.w  G_SPX(a6),d0
        moveq   #4,d5
        and.w   d0,d5
        moveq   #1,d1
        and.w   d0,d1
        sub.w   d1,d5                   ; c = (x & 4) - (x & 1): mask offset of word 0
        ; the same pattern rows, line offset, shift and width as the last build (and
        ; the GEO blob unchanged: G_OCV bit 1): G_HIDE / G_HRM are still its result
        ; (the rows: this frame's buffer against the other, the last build's)
        move.w  G_OF(a6),d0
        swap    d0
        move.w  d5,d0
        move.w  G_ONW(a6),d1
        btst    #1,G_OCV+1(a6)
        beq.s   .bld
        cmp.l   G_HKX(a6),d0
        bne.s   .bld
        cmp.w   G_HKW(a6),d1
        bne.s   .bld
        lea     G_OPB(a6),a0
        lea     G_OPB2(a6),a1
        tst.w   G_OPBO(a6)
        beq.s   .ab
        exg     a0,a1
.ab:    moveq   #12-1,d2
.hk:    cmpm.l  (a0)+,(a1)+
        dbne    d2,.hk
        bne.s   .bld
        move.w  #1,G_HMASK(a6)
        rts
.bld:   move.l  d0,G_HKX(a6)
        move.w  d1,G_HKW(a6)
        bset    #1,G_OCV+1(a6)
        cmpi.w  #7,d1                   ; 24-px frames: d5 bit 31 (the shifts read its
        bne.s   .w5                     ; low 6 bits, the tests its low word)
        bset    #31,d5
.w5:    lea     hide_lut2(pc),a5
        lea     G_HIDE(a6),a4
        movea.l G_PGEO(a6),a0
        adda.l  #GEO_OPAT,a0
        move.l  a0,d2                   ; code 0's row: all visible
        move.l  #$FFFF0000,d7           ; sprite line (word); bits 16-31: G_HRM (a
                                        ; zero line clears its bit)
        move.w  G_OF(a6),d6             ; line in the band
        moveq   #0,d0                   ; band x 16
        ; band by band: its 4 pattern rows stay in a0-a3
.band:  move.w  d0,-(sp)
        moveq   #8,d3
        sub.w   d6,d3                   ; lines left in this band
        moveq   #16,d1
        sub.w   d7,d1
        cmp.w   d1,d3
        ble.s   .bn
        move.w  d1,d3                   ; (and in the sprite)
.bn:    subq.w  #1,d3                   ; (the line loop's count: d3)
        lea     G_OPB(a6),a1
        adda.w  G_OPBO(a6),a1
        movem.l 0(a1,d0.w),a0-a3        ; the band's 4 pattern rows
        cmp.l   a0,d2                   ; all four visible: zero lines
        bne.s   .lines
        cmp.l   a1,d2
        bne.s   .lines
        cmp.l   a2,d2
        bne.s   .lines
        cmp.l   a3,d2
        bne.s   .lines
.bz:    clr.l   (a4)+
        clr.l   (a4)+
        clr.l   (a4)+
        clr.l   (a4)+
        move.w  d7,d1
        addi.w  #16,d1
        bclr    d1,d7
        addq.w  #1,d7
        dbra    d3,.bz
        bra     .bnext
        ; the band's lines, by the sign of c (d0, free in a band: c >= 0's fill)
.lines: tst.w   d5
        bmi     .lm
        moveq   #1,d0
        lsl.w   d5,d0
        subq.w  #1,d0                   ; (the c pixels shifted in: visible)
.lp:    HPACK
        lsl.l   d5,d4                   ; line up the sprite's word 0
        or.w    d0,d4
        HROW    .lp
        bra     .bnext
.lm:    HPACK                           ; (c = -1)
        lsr.l   #1,d4
        bset    #31,d4
        HROW    .lm
.bnext: moveq   #0,d6                   ; the next band starts at its line 0
        move.w  (sp)+,d0
        addi.w  #16,d0
        cmpi.w  #16,d7
        blo     .band
        swap    d7
        move.w  d7,G_HRM(a6)
        eori.w  #G_OPB2-G_OPB,G_OPBO(a6) ; (these rows now the last build's)
        move.w  #1,G_HMASK(a6)
.out:   rts

; hide_lut[visible nibble] (bit 3 = the word's leftmost pixel) -> Mode 8 hide word
hide_lut:
        dc.w    $FFFF,$FCFC,$F3F3,$F0F0,$CFCF,$CCCC,$C3C3,$C0C0
        dc.w    $3F3F,$3C3C,$3333,$3030,$0F0F,$0C0C,$0303,$0000

; LAB: the interrupt-free register loop. Supervisor mode (QDOS trap #0),
; interrupts masked, the ZX8302's frame-interrupt flag polled (and cleared)
; directly: lab_reg calls over 25 frames. Out: d0.l = 1/100 us per call, 0
; if the flag never came. Compared with R it gives the share of the CPU the
; interrupts (QDOS's 50 Hz tasks, the poll, the keyboard) take.
PC_INTR         equ     $18021
SV_PCINT        equ     $35

        ifeq    RELB
lab_irqoff:
        tst.w   G_TKON(a6)              ; takeover: R already ran without interrupts
        beq.s   .q
        move.l  G_LAB(a6),d0
        rts
.q:     movem.l d1-d7/a0-a5,-(sp)
        movea.l G_SYS(a6),a0
        move.b  SV_PCINT(a0),d7
        ori.b   #8,d7                   ; enables + "clear the frame interrupt"
        trap    #0
        ori.w   #$0700,sr
        lea     PC_INTR,a0
        move.b  d7,(a0)
        move.l  #500000,d5
.w1:    btst    #3,(a0)
        bne.s   .go
        subq.l  #1,d5
        bne.s   .w1
        bra.s   .fail
.go:    move.b  d7,(a0)
        moveq   #25,d6
        moveq   #0,d4
.c:     bsr     lab_reg
        addq.l  #1,d4
        cmpi.l  #200000,d4
        bhs.s   .fail
        btst    #3,(a0)
        beq.s   .c
        move.b  d7,(a0)
        subq.w  #1,d6
        bne.s   .c
        andi.w  #$D8FF,sr               ; user mode, interrupts on
        move.l  #50000000,d1            ; 25 frames x 20000 us x 100
        move.l  d4,d2
        bsr     udiv32
        move.l  d1,d0
        movem.l (sp)+,d1-d7/a0-a5
        rts
.fail:  andi.w  #$D8FF,sr
        moveq   #0,d0
        movem.l (sp)+,d1-d7/a0-a5
        rts

lab_drn:                                ; one con_ poll (the frame's key drain)
        tst.w   G_TKON(a6)
        bne     tk_keys                 ; (takeover: the IPC status + typed keys)
        move.l  G_CON(a6),d0
        beq.s   .x
        movea.l d0,a0
        moveq   #IO_FBYTE,d0
        moveq   #0,d3
        trap    #3
.x:     rts
lab_kr:
        bra     read_arrow_row
lab_pan:                                ; the whole panel (shadows forgotten)
        lea     G_SHAD0(a6),a0
        cmpi.l  #SCREEN,G_DEST(a6)
        beq.s   .s
        lea     G_SHAD1(a6),a0
.s:     move.w  #TEXT_LEN-1,d0
.f:     st      (a0)+
        dbra    d0,.f
        move.w  #3,G_TDIRTY(a6)
        bra     draw_panel
lab_pi:
        bra     draw_panel
lab_spr:
        bsr     set_view
        bra     draw_marble
        endc

;=============================================================================
; TAKEOVER mode (loader mmt_bas, G_TAKE = 1): the game runs with the machine
; to itself, on any QL ROM (JS, Minerva, ...) and needs no dual-screen boot.
;
; Entry (tk_enter, after the QDOS set-up): QDOS trap #0 = supervisor mode,
; interrupts masked (SR $2700) for the whole game, our own supervisor stack
; inside the globals. No QDOS trap is used until tk_exit.
;  - Frame clock: the ZX8302's frame-interrupt bit (pc_intr $18021 bit 3) is
;    polled - in the spin loop, every 16 lines of the copy, per panel line,
;    per logic pass - and acknowledged by writing sv_pcint | 8 there (the
;    three mask bits kept as QDOS had them). Every gap between polls is well
;    under a frame (20 ms), so no frame is missed.
;  - Both screens on any QL: MC_STAT ($18063) bit 7 is written directly. The
;    32 KB at $28000 (screen 1: on JS and Minerva booted normally the system
;    variables live there; on Minerva dual mode it is the spare screen) is
;    copied to a RESPR buffer (G_SAVE) on entry and copied back on exit. The
;    code, its data and our stack must all lie outside $20000-$2FFFF (checked:
;    otherwise the takeover is refused and the game runs in QDOS mode).
;  - Keyboard: the IPC (8049) is talked to directly, as Minerva's ip_rdwr does
;    (M/ip/int_asm, M/inc/ipcmd): each bit is sent by writing %000011x0 to
;    pc_ipcwr ($18003), then pc_ipcrd ($18020) bit 6 is awaited to go to 0,
;    and bit 7 there is the IPC's bit; reading = sending ones (%1110); msb
;    first. Per frame: the status command (1) and, when the IPC has typed keys
;    buffered, read keyboard (8): count + keydefs (shift nibble, key byte);
;    then keyboard direct read (9) of row 1 (arrows, SPACE, ESC). After a
;    transfer the IPC's interface interrupt is cleared (sv_pcint | 2), as
;    every ROM routine does. Every wait is bounded (G_TKERR counts timeouts).
;    The beeper (src/music.asm) uses the same routine: initiate sound (10)
;    + 64 bits.
; Exit (tk_exit): the IPC's key buffer is drained, screen 0 shown again
; (MC_STAT as it was), $28000-$2FFFF copied back, the interrupt register
; written as QDOS keeps it, our stack dropped, user mode with interrupts on.
;=============================================================================
PC_IPCRD        equ     $18020
PC_IPCWR        equ     $18003
TK_WAIT         equ     4000            ; IPC handshake: polls before giving up

tk_enter:
        tst.l   G_SAVE(a6)              ; the loader's 32 KB buffer
        bne.s   .sb
        ; no buffer: allowed on Minerva dual (G_TAKE = 2), where $28000-$2FFFF is
        ; just the spare screen (the system variables are at $30000), and in the
        ; release (3): QDOS's $28000-$2FFFF is given up, ESC resets the machine
        cmpi.w  #3,G_TAKE(a6)
        beq.s   .sb
        cmpi.w  #2,G_TAKE(a6)
        bne     .no
        cmpi.l  #$30000,G_SYS(a6)
        beq.s   .sb
        addq.w  #1,G_TKERR(a6)          ; (not dual after all: refused)
        bra     .no
.sb:
        ; everything we use must lie outside $20000-$2FFFF (the screens)
        lea     globals(pc),a0
        move.l  a0,d0
        bsr     .chk
        move.l  G_LIN(a6),d0
        bsr     .chk
        move.l  G_PGEO(a6),d0
        bsr     .chk
        move.l  G_SPRB(a6),d0
        bsr     .chk
        move.l  G_SAVE(a6),d0
        bsr     .chk
        move.l  G_DAT(a6),d0            ; (mm_dat: read at the race loads)
        bsr     .chk
        move.l  G_CCH(a6),d0            ; the sprite cache: both ends
        beq.s   .nc
        bsr     .chk
        add.l   G_CSZ(a6),d0
        subq.l  #1,d0
        bsr     .chk
.nc:    tst.w   G_TKERR(a6)             ; (.chk sets it on a clash)
        bne     .no
        ifeq    RELB
        bsr     cache_fill              ; (test loader; before the takeover: no frame lost)
        endc
        movea.l G_SYS(a6),a0
        moveq   #0,d0
        move.b  SV_PCINT(a0),d0
        andi.b  #$E0,d0                 ; the mask bits QDOS keeps
        move.w  d0,G_PCINT(a6)
        movea.l (sp)+,a2                ; our return address: the stack changes
        trap    #0                      ; QDOS: supervisor mode
        ori.w   #$0700,sr               ; no interrupts from now on
        move.l  sp,G_SSP0(a6)
        lea     G_TSTK+TK_STK(a6),sp    ; our own stack (QDOS's may be in screen 1)
        move.l  a2,-(sp)
        move.l  G_SAVE(a6),d0           ; keep screen 1's 32 KB (none on Minerva dual)
        beq.s   .ns
        lea     $28000,a0
        movea.l d0,a1
        move.w  #$8000/4-1,d0
.sv:    move.l  (a0)+,(a1)+
        dbra    d0,.sv
.ns:    move.w  #1,G_TKON(a6)
        move.w  #1,G_DUAL(a6)           ; both screens, on any QL
        move.w  #1,G_POLLOK(a6)
        lea     G_PTICK(a6),a0
        move.l  a0,G_TICKP(a6)
        moveq   #PC_INTRF,d0            ; drop a pending frame interrupt
        or.b    G_PCINT+1(a6),d0
        move.b  d0,PC_INTR
        bsr     tk_keys                 ; empty the IPC's key buffer
        clr.w   G_TKQN(a6)
        bsr     calibrate               ; the spin loop now polls the hardware
        ifeq    RELB
        move.l  G_TELB(a6),d0           ; telemetry: the header's K = this one (tel_init
        beq.s   .no                     ;  wrote QDOS's: busy times overstated)
        movea.l d0,a0
        move.l  G_K(a6),12(a0)
        endc
.no:    rts
.chk:   cmpi.l  #$30000,d0              ; clash if $20000 <= d0 < $30000
        bhs.s   .ok
        cmpi.l  #$20000-$100,d0         ; (a block starting just below $20000
        blo.s   .ok                     ;  would also reach in: be strict)
        addq.w  #1,G_TKERR(a6)
.ok:    rts

tk_exit:
        tst.w   G_TKON(a6)
        beq.s   .o
        cmpi.w  #3,G_TAKE(a6)           ; the release: no way back to QDOS
        beq.s   tk_reset
        bsr     tk_keys                 ; leave the IPC with an empty key buffer
        move.b  G_MCSTA0+1(a6),MC_STAT  ; screen 0, the mode QDOS had
        clr.w   G_SHOWN(a6)
        move.l  G_SAVE(a6),d0           ; screen 1's / the system variables' 32 KB
        beq.s   .nr                     ; (Minerva dual: none kept, the spare screen)
        movea.l d0,a0
        lea     $28000,a1
        move.w  #$8000/4-1,d0
.rs:    move.l  (a0)+,(a1)+
        dbra    d0,.rs
.nr:    moveq   #PC_INTRI,d0            ; as QDOS keeps it; IPC interrupt cleared
        or.b    G_PCINT+1(a6),d0
        move.b  d0,PC_INTR
        clr.w   G_TKON(a6)
        movea.l (sp)+,a2                ; our return address
        movea.l G_SSP0(a6),sp           ; QDOS's supervisor stack
        andi.w  #$D8FF,sr               ; user mode (BASIC's stack), interrupts on
        jmp     (a2)
.o:     rts

; tk_reset - the release's exit (G_TAKE = 3: QDOS's $28000-$2FFFF were not kept):
; interrupts off (as all through the takeover), the AY silenced and the last BEEP
; waited for already (quit: mus_stop), the IPC's sound killed (command 11) and
; its interrupt cleared, screen 0 shown, then the ROM's reset: the supervisor
; stack and the start address from its vectors at 0 and 4, as at power-on.
tk_reset:
        ori.w   #$0700,sr
        moveq   #11,d4                  ; kill sound
        moveq   #4,d1
        bsr     ipc_send
        bsr     tk_clri
        move.b  G_MCSTA0+1(a6),MC_STAT
        movea.l $0.w,sp
        movea.l $4.w,a0
        jmp     (a0)

        ifeq    RELB
; cache_fill / cache_check - the test loader's check of the sprite cache (G_TCCHK):
; every long is set to its address ^ CC_KEY before the takeover and compared after
; the exit; G_CCHK = 1 + the longs changed (saturated), 0 = not run. Only below the
; part the game has used (G_CMAX at the top: the slinkies' pictures, written at
; race loads).
CC_KEY          equ     $5A3C96E1

cache_fill:
        tst.w   G_TCCHK(a6)
        beq.s   .o
        bsr     cache_free
        beq.s   .o
.f:     move.l  a0,d1
        eori.l  #CC_KEY,d1
        move.l  d1,(a0)+
        subq.l  #1,d0
        bne.s   .f
        move.w  #1,G_CCHK(a6)
.o:     rts

cache_check:
        tst.w   G_CCHK(a6)
        beq.s   .o
        bsr     cache_free
        moveq   #1,d2
        tst.l   d0
        beq.s   .z
.c:     move.l  a0,d1
        eori.l  #CC_KEY,d1
        cmp.l   (a0)+,d1
        beq.s   .n
        addq.w  #1,d2
        bne.s   .n
        subq.w  #1,d2                   ; (saturate at $FFFF)
.n:     subq.l  #1,d0
        bne.s   .c
.z:     move.w  d2,G_CCHK(a6)
.o:     rts
        endc

;-----------------------------------------------------------------------------
; anim_update - the animated cells (Beginner's bridge and its neighbour):
; each group's variant by the logic state at the last step with frame & 3 = 3
; (the step the patches change); when it is not
; the one in the bitmap, its pixels are copied there (from the race area's top:
; anim_build in expand_bitmap); only while the box is in the view (set_view's
; G_VIEW, G_LINES): out of it the bitmap is not read, and it is brought up to
; date on the first frame it is in view again. Selector 0:
; .a7cf[((M_F9B - ((fc + 1) & 3)) mod $30) >> 3]; 1: M_F9D >> 6 & 1.
;-----------------------------------------------------------------------------

anim_update:
        move.w  G_ANN(a6),d7
        beq     .x
        move.w  G_VIEW(a6),d0           ; the flags' / GOAL's line range in the view?
        cmp.w   G_ANL1(a6),d0
        bhs.s   .cells
        add.w   G_LINES(a6),d0
        cmp.w   G_ANL0(a6),d0
        bhi.s   .all
.cells: move.w  G_ANCN(a6),d7           ; no: only the cell groups (Beginner's bridge)
        beq     .x
.all:   subq.w  #1,d7
        lea     G_ANG(a6),a4
        lea     G_MB(a6),a3
.g:     move.w  AN_Y(a4),d0             ; in the view? [Y, Y + LINES) and
        move.w  G_VIEW(a6),d1           ; [VIEW, VIEW + G_LINES) overlap
        add.w   AN_LINES(a4),d0
        cmp.w   d1,d0
        bls     .n
        add.w   G_LINES(a6),d1
        cmp.w   AN_Y(a4),d1
        bls     .n
        move.w  AN_SEL(a4),d0
        beq.s   .s0
        subq.w  #2,d0
        bmi.s   .s1
        beq.s   .fc                     ; 2: a goal flag: (fc >> 3) & 3
        cmpi.w  #2,d0
        beq.s   .s4
        tst.b   G_WR95+1(a6)            ; 3: the GOAL text's palette: G_WR95 once
        bmi.s   .fc                     ; the goal line set it, from the frame
        move.b  M_FC+1(a3),d0           ; after (its handler runs before the marble's)
        cmp.b   G_FC95+1(a6),d0
        beq.s   .fc
        moveq   #3,d0
        and.b   G_WR95+1(a6),d0
        bra.s   .v
.fc:    move.b  M_FC+1(a3),d0           ; (fc >> 3) & 3
        lsr.b   #3,d0
        andi.w  #3,d0
        bra.s   .v
.s0:    moveq   #1,d1                   ; M_F9B at the last write: M_F9B - ((fc + 1) & 3)
        add.b   M_FC+1(a3),d1
        andi.w  #3,d1
        moveq   #0,d0
        move.b  M_F9B+1(a3),d0
        sub.w   d1,d0
        bpl.s   .p
        addi.w  #$30,d0
.p:     lsr.w   #3,d0
        lea     .a7cf(pc),a0            ; (past the pc-indexed reach)
        move.b  0(a0,d0.w),d0
        bra.s   .v
.s1:    moveq   #0,d0
        move.b  M_F9D+1(a3),d0
        lsr.b   #6,d0
        andi.w  #1,d0
        bra.s   .v
.s4:    moveq   #$1F,d0                 ; 4: Aerial's catapult: .c20[M_F9D >> 3] at
        and.b   M_F9D+1(a3),d0          ; the last even frame (M_F9D one step back on an
        btst    #0,M_FC+1(a3)           ; odd frame from 7 up)
        beq.s   .s4e
        cmpi.b  #7,d0
        blo.s   .s4e
        subq.b  #1,d0
.s4e:   lsr.b   #3,d0
        move.b  .c20(pc,d0.w),d0
.v:     cmp.w   AN_SHOWN(a4),d0
        beq.s   .n
        move.w  d0,AN_SHOWN(a4)
        mulu.w  AN_VB(a4),d0
        movea.l AN_STORE(a4),a0
        adda.l  d0,a0
        movea.l AN_LIN(a4),a1
        move.l  AN_CODE(a4),d0          ; a flag: its spans' own code
        beq.s   .cp
        movea.l d0,a2
        jsr     (a2)
        bra.s   .n
.cp:    move.w  AN_LINES(a4),d6
        subq.w  #1,d6
        move.w  AN_LB(a4),d5
        cmpi.w  #16,d5                  ; (the bridge's piece: 16 B lines, nearly
        beq.s   .c16                    ;  every frame; the bridge: 32 B)
        cmpi.w  #32,d5
        beq.s   .c32
        lsr.w   #2,d5
        subq.w  #1,d5
.l:     movea.l a1,a2
        move.w  d5,d4
.w:     move.l  (a0)+,(a2)+
        dbra    d4,.w
        lea     BPL(a1),a1
        dbra    d6,.l
.n:     lea     AN_SIZE(a4),a4
        dbra    d7,.g
.x:     rts
.a7cf:  dc.b    0,1,2,3,2,1             ; the bridge's variant by phase
.c20:   dc.b    0,1,2,1                 ; Aerial's catapult's variant by phase
        even
.c16:   movem.l (a0)+,d0-d3             ; (after the tables: their pc-indexed reach)
        movem.l d0-d3,(a1)
        lea     BPL(a1),a1
        dbra    d6,.c16
        bra.s   .n
.c32:   movem.l (a0)+,d0-d3
        movem.l d0-d3,(a1)
        movem.l (a0)+,d0-d3
        movem.l d0-d3,16(a1)
        lea     BPL(a1),a1
        dbra    d6,.c32
        bra.s   .n

;-----------------------------------------------------------------------------
; maze_update - Ultimate's goal maze: the patches of the maze state (M_F9B)
; are written every step the scroll is $0343, so the maze shown is the map with
; the patches of the states written so far, in order (the logic counts
; them: M_MZK, 0-23). Here the states written and not
; yet applied (G_MZPD) are applied in turn: a state's list (cell, picture) puts
; each picture whose cell does not show it already (G_MZCU) into the bitmap,
; polling the frame flag after each cell. At most MZ_CAP cells a frame (the
; start, all cells changing from the map's, would be one long frame): the rest,
; from where it stopped (G_MZEI), on the next frames. M_MZK = 0 after it was
; not (a restart): the map's pictures back, MZ_CAP cells a frame (G_MZRI). The
; cells under a goal flag's box have four pictures each, one per wave frame
; (the flag's spans leave them out): put with the flags' frame (fc >> 3) & 3,
; and all of them again when that changes (while their lines are in the view).
;-----------------------------------------------------------------------------
MZ_CAP          equ     30              ; cells a frame at most while catching up (68008
                                        ; ~2.6 ms): at the start and after a restart only

maze_update:
        tst.l   G_MZST(a6)
        beq     .x
        lea     G_MB(a6),a3
        move.w  G_MZVS(a6),d5           ; d5 = the flags' frame x 32 their cells show
        bpl.s   .vs                     ; (cells put now: the same; -1: the frame now)
        moveq   #0,d5
        move.b  M_FC+1(a3),d5
        lsr.w   #3,d5
        andi.w  #3,d5
        lsl.w   #5,d5
.vs:    moveq   #MZ_CAP,d6              ; d6 = the cells left this frame: MZ_CAP while
        tst.w   G_MZCT(a6)              ; catching up (the start, a restart), else all
        bne.s   .cap
        move.w  #$7FFF,d6
.cap:   tst.w   G_MZRI(a6)              ; a reset under way
        bpl.s   .rs
        move.w  M_MZK(a3),d3
        bne.s   .on
        tst.w   G_MZLS(a6)              ; k = 0: not started, or a restart
        bmi     .fv
        move.w  #-1,G_MZLS(a6)
        clr.w   G_MZPD(a6)
        clr.w   G_MZEI(a6)
        clr.w   G_MZRI(a6)
        move.w  #1,G_MZCT(a6)
        moveq   #MZ_CAP,d6
.rs:    bsr     maze_reset
        tst.w   G_MZRI(a6)
        bpl     .x                      ; (not done: on the next frame)
        bra     .fv
.on:    moveq   #0,d2
        move.b  M_F9B+1(a3),d2          ; s
        move.w  G_MZLS(a6),d0
        bpl.s   .ls
        move.w  d2,d0                   ; none applied yet: the k states from s - k + 1
        sub.w   d3,d0
        bpl.s   .f1
        addi.w  #MZ_NST,d0
.f1:    move.w  d0,G_MZLS(a6)
        move.w  d3,G_MZPD(a6)
        move.w  d2,G_MZSS(a6)
        clr.w   G_MZEI(a6)
        move.w  #1,G_MZCT(a6)           ; (the start: caught up over a few frames)
        moveq   #MZ_CAP,d6
        bra.s   .ap
.ls:    move.w  d2,d1                   ; + the states written since the last frame
        sub.w   G_MZSS(a6),d1
        bpl.s   .l1
        addi.w  #MZ_NST,d1
.l1:    add.w   d1,G_MZPD(a6)
        move.w  d2,G_MZSS(a6)
        cmpi.w  #2*MZ_NST,G_MZPD(a6)    ; (a whole lap more changes nothing)
        bls.s   .ap
        subi.w  #MZ_NST,G_MZPD(a6)
.ap:    tst.w   G_MZPD(a6)
        bne.s   .ap1
        clr.w   G_MZCT(a6)              ; caught up: from now on every state whole
        bra.s   .fv
.ap1:
        tst.w   d6
        ble.s   .x
        move.w  G_MZLS(a6),d0           ; the next state
        addq.w  #1,d0
        cmpi.w  #MZ_NST,d0
        blo.s   .s1
        moveq   #0,d0
.s1:    movem.w d0/d5,-(sp)
        bsr.s   maze_apply
        movem.w (sp)+,d0/d5
        tst.w   G_MZEI(a6)
        bne.s   .x                      ; (stopped in its list: the rest next frame)
        move.w  d0,G_MZLS(a6)
        subq.w  #1,G_MZPD(a6)
        bra.s   .ap
.fv:    moveq   #0,d5                   ; the flags' frame now: shown?
        move.b  G_MB+M_FC+1(a6),d5
        lsr.w   #3,d5
        andi.w  #3,d5
        lsl.w   #5,d5
        cmp.w   G_MZVS(a6),d5
        beq.s   .x
        cmpi.w  #12,d6                  ; (room for their cells this frame)
        blt.s   .x
        move.w  G_VIEW(a6),d0           ; their cells' lines in the view?
        cmp.w   G_MZY1(a6),d0
        bhs.s   .x
        add.w   G_LINES(a6),d0
        cmp.w   G_MZY0(a6),d0
        bls.s   .x
        bra     maze_flags
.x:     rts

; maze_apply - state d0's list into the bitmap from its entry G_MZEI (the cells
; not showing it already; d5 = the flags' frame x 32, d6 = the cells left this
; frame: out of them before the list's end, G_MZEI = where to go on)
maze_apply:
        movea.l G_MZLI(a6),a0
        add.w   d0,d0
        adda.w  0(a0,d0.w),a0
        move.w  (a0)+,d7                ; n x (cell x 4, picture x 32)
        move.w  G_MZEI(a6),d4
        sub.w   d4,d7
        move.w  d4,d0
        lsl.w   #2,d0
        adda.w  d0,a0
        subq.w  #1,d7
        bmi.s   .d
        movea.l G_MZST(a6),a1           ; the pictures
        movea.l G_MZOF(a6),a2           ; the cells' addresses
        movea.l G_MZCU(a6),a3           ; what each shows
.e:     move.w  (a0)+,d1
        move.w  (a0)+,d2
        move.w  d1,d3
        lsr.w   #1,d3
        cmp.w   0(a3,d3.w),d2
        beq.s   .n
        move.w  d2,0(a3,d3.w)
        bpl.s   .p                      ; (bit 15: under a flag: its frame's)
        andi.w  #$7FFF,d2
        add.w   d5,d2
.p:     movea.l 0(a2,d1.w),a4
        lea     0(a1,d2.w),a5
        move.l  (a5)+,(a4)
        move.l  (a5)+,BPL(a4)
        move.l  (a5)+,2*BPL(a4)
        move.l  (a5)+,3*BPL(a4)
        move.l  (a5)+,4*BPL(a4)
        move.l  (a5)+,5*BPL(a4)
        move.l  (a5)+,6*BPL(a4)
        move.l  (a5)+,7*BPL(a4)
        tst.b   G_TKON+1(a6)            ; (tk_poll: takeover only)
        beq.s   .q
        bsr     tk_poll
.q:     subq.w  #1,d6
        bgt.s   .n
        tst.w   d7                      ; out of cells: more of the list left?
        beq.s   .d
        addq.w  #1,d4
        move.w  d4,G_MZEI(a6)
        rts
.n:     addq.w  #1,d4
        dbra    d7,.e
.d:     clr.w   G_MZEI(a6)
        rts

; maze_reset - from cell G_MZRI on, the cells that differ back to the map's
; picture (a restart), d6 cells at most (d5 = the flags' frame x 32); G_MZRI =
; where to go on, -1 when done
maze_reset:
        move.w  G_MZRI(a6),d4
        move.w  G_MZN(a6),d7
        sub.w   d4,d7
        subq.w  #1,d7
        bmi.s   .d
        movea.l G_MZST(a6),a1
        movea.l G_MZOF(a6),a2
        movea.l G_MZBA(a6),a0
        movea.l G_MZCU(a6),a3
        move.w  d4,d0
        add.w   d0,d0
        adda.w  d0,a0
        adda.w  d0,a3
        add.w   d0,d0
        adda.w  d0,a2
.e:     move.w  (a0)+,d2
        cmp.w   (a3),d2
        beq.s   .n
        move.w  d2,(a3)
        bpl.s   .p
        andi.w  #$7FFF,d2
        add.w   d5,d2
.p:     movea.l (a2),a4
        lea     0(a1,d2.w),a5
        move.l  (a5)+,(a4)
        move.l  (a5)+,BPL(a4)
        move.l  (a5)+,2*BPL(a4)
        move.l  (a5)+,3*BPL(a4)
        move.l  (a5)+,4*BPL(a4)
        move.l  (a5)+,5*BPL(a4)
        move.l  (a5)+,6*BPL(a4)
        move.l  (a5)+,7*BPL(a4)
        tst.b   G_TKON+1(a6)
        beq.s   .q
        bsr     tk_poll
.q:     subq.w  #1,d6
        bgt.s   .n
        tst.w   d7
        beq.s   .d
        addq.w  #1,d4
        move.w  d4,G_MZRI(a6)
        rts
.n:     addq.l  #2,a3
        addq.l  #4,a2
        addq.w  #1,d4
        dbra    d7,.e
.d:     move.w  #-1,G_MZRI(a6)
        rts

; maze_flags - the cells under the flags with the frame d5 (x 32)
maze_flags:
        move.w  d5,G_MZVS(a6)
        movea.l G_MZFC(a6),a0           ; word n, n x cell x 4
        move.w  (a0)+,d7
        subq.w  #1,d7
        bmi.s   .x
        movea.l G_MZST(a6),a1
        movea.l G_MZOF(a6),a2
        movea.l G_MZCU(a6),a3
.e:     move.w  (a0)+,d1
        move.w  d1,d3
        lsr.w   #1,d3
        move.w  0(a3,d3.w),d2
        andi.w  #$7FFF,d2
        add.w   d5,d2
        movea.l 0(a2,d1.w),a4
        lea     0(a1,d2.w),a5
        move.l  (a5)+,(a4)
        move.l  (a5)+,BPL(a4)
        move.l  (a5)+,2*BPL(a4)
        move.l  (a5)+,3*BPL(a4)
        move.l  (a5)+,4*BPL(a4)
        move.l  (a5)+,5*BPL(a4)
        move.l  (a5)+,6*BPL(a4)
        move.l  (a5)+,7*BPL(a4)
        bsr     tk_poll
        dbra    d7,.e
.x:     rts

;-----------------------------------------------------------------------------
; flag_cover - the goal flags over the marble: the flags have priority over the
; marble, so wherever a flag pixel is not colour 0 the flag is shown, at
; any depth. After draw_marble: for each
; flag whose box overlaps the marble frame on the screen (its words from G_SPX,
; G_SPF's word count; 16 lines from G_SPY), the overlapping words get the
; flag's pixels where its frame in the bitmap (AN_SHOWN) is opaque (AN_HIDE: a
; long per box word, (its colours AND m, NOT m), made at the load). Nothing else
; is touched. A row of the overlap (1-4 words) is an unrolled run entered by a
; computed jump.
; Off with M (G_OCCON = 0) and in measuring mode 5, as occ_build.
;-----------------------------------------------------------------------------
flag_cover:
        ; quick, first: does the flags' line range [G_FLL0, G_FLL1) (0, 0: none) meet
        ; the marble's 16 lines? Then which flag's box (fy - SPY in (-24, 16))
        move.w  G_SPY(a6),d4
        add.w   G_VIEW(a6),d4           ; (bitmap lines)
        cmp.w   G_FLL1(a6),d4
        bge     .x
        moveq   #16,d1
        add.w   d4,d1
        cmp.w   G_FLL0(a6),d1
        ble     .x
        move.w  G_ANN(a6),d7
        beq     .x
        move.w  G_SPF(a6),d0
        bmi     .x
        tst.w   G_OCCON(a6)
        beq     .x
        ifeq    RELB
        cmpi.w  #5,G_MODE(a6)
        beq     .x
        endc
        move.w  d7,d1
        subq.w  #1,d1
        lea     G_ANG(a6),a4
.q:     cmpi.w  #2,AN_SEL(a4)
        bne.s   .qn
        move.w  AN_BOXL(a4),d2
        sub.w   d4,d2
        cmpi.w  #16,d2
        bge.s   .qn
        cmpi.w  #-FL_BOXH,d2
        bgt.s   .go
.qn:    lea     AN_SIZE(a4),a4
        dbra    d1,.q
        rts
.go:    movea.l G_SPRB(a6),a0
        add.w   d0,d0
        add.w   d0,d0
        move.l  0(a0,d0.w),d0
        beq     .x
        move.w  0(a0,d0.l),d6           ; the frame's words a row
        move.w  G_SPX(a6),d5
        asr.w   #2,d5                   ; its first screen word
        add.w   d5,d6                   ; past its last
        move.w  G_SPY(a6),d4            ; its top line (playfield)
        subq.w  #1,d7
        lea     G_ANG(a6),a4
.g:     cmpi.w  #2,AN_SEL(a4)
        bne     .n
        tst.w   AN_SHOWN(a4)
        bmi     .n
        ; lines [max(SPY, fy, 0), min(SPY + 16, fy + BOXH, LINES))
        move.w  AN_BOXL(a4),d2
        sub.w   G_VIEW(a6),d2           ; fy: the box's top line
        move.w  d4,d0
        cmp.w   d2,d0
        bge.s   .a
        move.w  d2,d0
.a:     tst.w   d0
        bpl.s   .b
        moveq   #0,d0
.b:     moveq   #16,d1
        add.w   d4,d1
        moveq   #FL_BOXH,d3
        add.w   d2,d3
        cmp.w   d3,d1
        ble.s   .c
        move.w  d3,d1
.c:     cmp.w   G_LINES(a6),d1
        ble.s   .d
        move.w  G_LINES(a6),d1
.d:     sub.w   d0,d1                   ; lines
        ble     .n
        ; words [max(wx, wc, 0), min(wend, wc + 4, 64))
        move.w  AN_WC(a4),d3
        cmp.w   d3,d6
        ble     .n                      ; (quick: the marble left of the box)
        movem.l d4-d7/a4,-(sp)
        move.w  d5,d7                   ; c0
        cmp.w   d3,d7
        bge.s   .e
        move.w  d3,d7
.e:     tst.w   d7
        bpl.s   .f
        moveq   #0,d7
.f:     move.w  d3,d4
        addq.w  #4,d4
        cmp.w   d4,d6
        ble.s   .h
        move.w  d4,d6
.h:     cmpi.w  #64,d6
        ble.s   .i
        moveq   #64,d6
.i:     sub.w   d7,d6                   ; words
        ble.s   .o
        ; a0 = the cover data at (line r0 - fy, word c0 - wc), a1 = the screen
        move.w  AN_SHOWN(a4),d4
        mulu.w  #FL_HIDEB,d4
        movea.l AN_HIDE(a4),a0
        adda.l  d4,a0
        move.w  d0,d4
        sub.w   d2,d4
        lsl.w   #4,d4                   ; x 16 B a box line
        adda.w  d4,a0
        move.w  d7,d4
        sub.w   d3,d4
        lsl.w   #2,d4
        adda.w  d4,a0
        add.w   d7,d7                   ; c0 x 2
        move.w  G_PTOP(a6),d4
        add.w   d0,d4
        lsl.w   #7,d4
        add.w   d7,d4
        movea.l G_DEST(a6),a1
        adda.w  d4,a1
        moveq   #4,d0                   ; the jump into the run: (4 - words) x 8 B
        sub.w   d6,d0
        lsl.w   #3,d0
        subq.w  #1,d1
.r:     movea.l a0,a3
        movea.l a1,a5
        jmp     .u(pc,d0.w)
.u:     rept    4
        move.l  (a3)+,d4                ; colours : keep
        and.w   d4,(a5)
        swap    d4
        or.w    d4,(a5)+
        endr
        lea     16(a0),a0
        lea     BPL(a1),a1
        dbra    d1,.r
.o:     movem.l (sp)+,d4-d7/a4
.n:     lea     AN_SIZE(a4),a4
        dbra    d7,.g
.x:     rts

; cache_free - a0 = the cache, d0 = its longs below the part in use at its top
; (G_CMAX, rounded up to a long) (Z set when none)
cache_free:
        move.l  G_CMAX(a6),d1           ; (the game's part: the top, slink_load)
        addq.l  #3,d1
        andi.l  #-4,d1
        movea.l G_CCH(a6),a0
        move.l  G_CSZ(a6),d0
        sub.l   d1,d0
        bhi.s   .p
        moveq   #0,d0
.p:     lsr.l   #2,d0
        rts

; tk_poll - the frame clock in takeover mode: count a pending frame interrupt.
; Preserves all registers (call it often: at least once every ~15 ms).
tk_poll:
        tst.b   G_TKON+1(a6)
        beq.s   .o
        btst    #3,PC_INTR
        bne.s   tk_ack
.o:     rts
tk_ack:
        move.l  d0,-(sp)
        moveq   #PC_INTRF,d0
        or.b    G_PCINT+1(a6),d0
        move.b  d0,PC_INTR
        addq.w  #1,G_PTICK(a6)
        move.l  (sp)+,d0
        ifne    MUS_ON
        bra     mus_tick                ; the tune's tick (takeover; all kept)
        endc
        rts

; ipc_bit - one bit each way. In: d2.b = the byte for pc_ipcwr (%11x0 or
; %1110). Out: d0.b bit 7 = the IPC's bit. Uses d0/d3.
ipc_bit:
        move.b  d2,PC_IPCWR
        move.w  #TK_WAIT,d3
.w:     btst    #6,PC_IPCRD
        beq.s   .ok
        dbra    d3,.w
        addq.w  #1,G_TKERR(a6)          ; no answer: give up this bit
        moveq   #0,d0
        rts
.ok:    move.b  PC_IPCRD,d0
        rts

; ipc_send - d1.w bits of d4 (msb first, from bit d1-1). Uses d0-d3.
ipc_send:
        subq.w  #1,d1
.b:     moveq   #%1100,d2
        btst    d1,d4
        beq.s   .z
        moveq   #%1110,d2
.z:     bsr     ipc_bit
        dbra    d1,.b
        rts

; ipc_recv - d1.w bits from the IPC into d4 (msb first). Uses d0-d3.
ipc_recv:
        moveq   #0,d4
        subq.w  #1,d1
.b:     moveq   #%1110,d2
        bsr     ipc_bit
        add.b   d0,d0                   ; the bit into X
        addx.l  d4,d4
        dbra    d1,.b
        rts

; tk_clri - clear the IPC interface interrupt our transfers raised
tk_clri:
        moveq   #PC_INTRI,d0
        or.b    G_PCINT+1(a6),d0
        move.b  d0,PC_INTR
        rts

; tk_row - keyboard direct read (command 9) of row d0.w. Out: d0.b. Uses d0-d4.
tk_row:
        moveq   #9,d4
        lsl.w   #4,d4
        or.w    d0,d4                   ; nibbles 9, row
        moveq   #8,d1
        bsr     ipc_send
        moveq   #8,d1
        bsr     ipc_recv
        bsr     tk_clri
        move.l  d4,d0
        rts

; tk_keys - typed keys: status (command 1); if the IPC holds keystrokes, read
; keyboard (command 8): a nibble (bit 3 = still held, bits 2-0 = count n),
; then n x (shift nibble, key byte). The keys we use go to G_TKQ (ASCII, via
; tk_keymap); the rest are dropped. Uses d0-d6/a0.
tk_keys:
        moveq   #1,d4
        moveq   #4,d1
        bsr     ipc_send
        moveq   #8,d1
        bsr     ipc_recv
        btst    #0,d4                   ; keyboard data waiting?
        beq.s   .x
        moveq   #8,d4
        moveq   #4,d1
        bsr     ipc_send
        moveq   #4,d1
        bsr     ipc_recv
        moveq   #7,d5
        and.w   d4,d5                   ; keydefs to follow
        bra.s   .n
.k:     moveq   #12,d1
        bsr     ipc_recv
        andi.w  #$3F,d4                 ; the key (6 bits)
        lea     tk_keymap(pc),a0
        move.b  0(a0,d4.w),d6
        beq.s   .n
        move.w  G_TKQN(a6),d0
        cmpi.w  #8,d0
        bhs.s   .n
        lea     G_TKQ(a6),a0
        move.b  d6,0(a0,d0.w)
        addq.w  #1,G_TKQN(a6)
.n:     dbra    d5,.k
.x:     bra     tk_clri

; tk_getkey - next queued key: d1.w = ASCII, d0 = 0; d0 = -1 if none
tk_getkey:
        move.w  G_TKQN(a6),d0
        beq.s   .none
        lea     G_TKQ(a6),a0
        moveq   #0,d1
        move.b  (a0),d1
        subq.w  #1,d0
        move.w  d0,G_TKQN(a6)
        beq.s   .ok
        subq.w  #1,d0
.sh:    move.b  1(a0),(a0)+
        dbra    d0,.sh
.ok:    moveq   #0,d0
        rts
.none:  moveq   #-1,d0
        rts

;=============================================================================
; constant data
;=============================================================================
tpl0:   dc.b    CH_M,CH_S,CH_SPC,0,0,0,CH_DOT,0,0,CH_SPC        ; MS 000.00
        dc.b    CH_F,CH_P,CH_S,CH_SPC,0,0,CH_DOT,0,CH_SPC       ; FPS 00.0
        dc.b    CH_F,1,CH_SPC                                   ; F1
        dc.b    CH_H,2,2,4,CH_SPC                               ; H224
        dc.b    CH_M,0,CH_SPC                                   ; M0
        dc.b    CH_S,CH_U,CH_B,6,CH_SPC,CH_SPC,CH_SPC,-1        ; SUB6
        even
tpl2:   dc.b    CH_X,CH_SPC,0,0,0,0,CH_SPC                      ; X 0000
        dc.b    CH_Y,CH_SPC,0,0,0,0,CH_SPC                      ; Y 0000
        dc.b    CH_Z,CH_SPC,0,0,0,0,CH_SPC,CH_SPC               ; Z 0000
        dc.b    CH_S,CH_C,CH_SPC,0,0,0,0,CH_SPC,CH_SPC          ; SC 0000
        dc.b    CH_S,CH_T,CH_SPC,0,0,CH_SPC                     ; ST 00
        dc.b    CH_D,CH_SPC,0,0,CH_SPC,CH_SPC,CH_SPC,CH_SPC,CH_SPC   ; D 00 GOAL
        dc.b    CH_SPC,CH_L,CH_T,CH_SPC,0,0,0,0                 ; LT 0000 (late frames)
        dc.b    CH_SPC,1,0,CH_SPC,CH_SPC,CH_SPC,CH_S,CH_W,0,0,-1 ; 10 / 12.5, SW 00
        even
tplb:   dc.b    CH_B,CH_E,CH_N,CH_C,CH_H,CH_SPC,0,CH_SLASH,N_MODES,CH_SPC,CH_M,CH_SPC,0,-1
        even
tplr:   dc.b    CH_T,0,CH_SPC,0,0,CH_DOT,0,0,CH_SPC,CH_SPC                  ; T0 00.00
        dc.b    CH_C,CH_P,CH_Y,CH_SPC,0,0,CH_DOT,0,0,CH_SPC                 ; CPY
        dc.b    CH_L,CH_O,CH_G,CH_SPC,0,0,CH_DOT,0,0,CH_SPC                 ; LOG
        dc.b    CH_S,CH_P,CH_R,CH_SPC,0,0,CH_DOT,0,0,CH_SPC                 ; SPR
        dc.b    CH_I,CH_N,CH_P,CH_SPC,0,0,CH_DOT,0,0,CH_SPC                 ; INP
        dc.b    CH_O,CH_C,CH_C,CH_SPC,0,0,CH_DOT,0,0,-1                     ; OCC
        even
txt_time:
        dc.b    CH_T,CH_I,CH_M,CH_E,CH_SPC,0,0,CH_SPC,CH_SPC,0   ; (9 used; even)
txt_over:
        dc.b    CH_G,CH_A,CH_M,CH_E,CH_SPC,CH_O,CH_V,CH_E,CH_R,0   ; (9 used; even)
txt_toff:
        dc.b    CH_T,CH_I,CH_M,CH_E,CH_R,CH_SPC,CH_O,CH_F,CH_F
        even
txt_goal:
        dc.b    CH_G,CH_O,CH_A,CH_L
        even
txt_nogoal:
        dc.b    CH_SPC,CH_SPC,CH_SPC,CH_SPC
        even

        include "music.asm"             ; (here: within bsr reach of the main code)
        include "mlogic.asm"
        include "proto_font.inc"
        ifeq    RELB
        include "proto_demo.inc"
        endc
        include "proto_occ.inc"
        include "proto_keys.inc"
        include "proto_load.asm"
        include "mobj.asm"
        include "unzx0_68000.s"
        ifne    MUS_ON
        even
        include "mus_tab.inc"           ; (generated: the ST's periods, envelopes,
        even                            ;  effect streams; read by src/music.asm)
        include "mus_beep.inc"          ; (generated: the beeper's BEEPs)
        even
        endc
        include "anim_afix.asm"         ; (load code: after the frame code and its tables)
        ifne    MAP_FIX
        include "map_fix.asm"           ; (load code, as anim_afix; only with map fixes)
        endc
        include "frontend.asm"          ; (game over, high scores: not in a frame)
