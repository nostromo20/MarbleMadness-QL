; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
; mm_dat.inc - the layout of data/mm_dat (the data builder reads these values from
; this file: one definition).
;
; File: "MMD2", word blob count, word 0, then per blob: long offset, long packed size,
; long unpacked size; the blobs are ZX0 v2 streams (src/unzx0_68000.s), even-aligned.
; Blob 0 = SHARED; race r (0-5): blob 1+2r = BUILD (the bitmap's sources, header XH_),
; blob 2+2r = PLAY (GEO2 + the start block, header PH_). All of them go through ONE
; buffer, the race area (G_RBUF): at a race start BUILD, then SHARED after it, then
; the work area (tile states + cell cache) after that; once the bitmap is built, PLAY
; is unpacked over all of it and stays. At start SHARED is unpacked there alone for
; the marble bank.
DAT_MAGIC       equ     $4D4D4432      ; "MMD2"
DAT_NBLOB       equ     14
DAT_GEOFIX      equ     13              ; the GEO2 tables that are the same in every race
DAT_DIR         equ     8               ; first directory entry
DAT_DIRSZ       equ     12

; SHARED blob
SH_BG0          equ     0               ; 4096 B: the BG tile set after the set-up's
                                        ; clear + its first entry (255 tiles at $0010)
SH_MARB         equ     4096            ; 53 marble frames x 96 B (6 tiles of 16 B;
                                        ; the narrow ones use 4: 64 B)
SH_WIDE         equ     4096+53*96      ; 53 bytes: 1 = 24 px wide frame
SH_SPRS         equ     SH_WIDE+54      ; SPR_MAX x 16 B: every race's sprite tiles (each
                                        ; race's XH_SPRTAB indexes them)
SPR_MAX         equ     384
SH_SIZE         equ     SH_SPRS+SPR_MAX*16

; GEOFIX blob (DAT_GEOFIX): GEO2's race-independent tables, copied into each race's
; GEO2 at the load (the PLAY blob ships them zeroed)
GF_ROLL         equ     0               ; 256 B -> GEO_ROLL
GF_OPAT         equ     256             ; 1024 B -> GEO_OPAT
GF_FUNNEL       equ     256+1024        ; 72 B -> GEO_FUNNEL (its +72, the race's byte,
GF_SIZE         equ     256+1024+72     ;  stays in the PLAY blob)

; BUILD blob: a header of longs (offsets from the blob start), then the bitmap's sources
XH_MFIX         equ     0               ; long: the map's colour fixes
                                        ; (src/map_fix.asm), 0 none: word
                                        ; n, n x (word bitmap line, byte byte in the line,
                                        ; byte words, the Mode 8 words): over the bitmap
                                        ; after flag_build
XH_MAP          equ     4               ; rows x 32 tile numbers (the map's rows)
XH_ATTR         equ     8               ; rows x 32 palette numbers (0-3)
XH_RSTATE       equ     12              ; rows bytes: tile state (zones in force)
XH_OVR          equ     16              ; word n, n x (word row, byte col, byte state)
XH_PATCH        equ     20              ; word n, n x (byte tile, 16 B): BG tiles over SH_BG0
XH_SPRTAB       equ     24              ; 256 words: the sprite tile set, as tiles of SH_SPRS
XH_PAL          equ     28              ; 32 B: BG + sprite palettes (source colours, 0-$3F)
XH_ZONES        equ     32              ; per state 1..n-1: word n, n x (word addr, word
                                        ; len, len bytes, even): what it adds to the last
XH_SPRITES      equ     36              ; word n, n x (byte state, byte attr, byte tile,
                                        ; byte tag, word x, word y): priority order, first wins;
                                        ; tag 0 = painted with the map, 1 + 4k + v = goal
                                        ; flag k's wave frame v (flag_build only)
XH_COLMAP       equ     40              ; 256 B: source colour x 4 + (y&1)*2 + (x&1) -> QL
XH_GSCHEME      equ     44              ; long: the GOAL text's colours,
                                        ; 0 none: 64 B, (palette x 4 + value) x 4 + (y&1)*2
                                        ; + (x&1) -> QL colour; flag_build paints it with them
XH_ROWS         equ     48              ; word: map rows
XH_NSTATE       equ     50              ; word: tile states
XH_LINES        equ     54              ; word: bitmap lines (16 + rows x 8)
XH_ANIM         equ     56              ; long: the animated cells, 0
                                        ; none: word n, n x (word row, col, rows, cols, nvar,
                                        ; selector, long the variants' offset in the race
                                        ; area), then per group nvar x rows x cols tiles (even)
XH_FLAGS        equ     60              ; long: the goal flags,
                                        ; 0 none: word n, n x FL_SIZE, then per
                                        ; flag its spans: nspan x (word disp from the box's
                                        ; first byte, word words); then per flag its opaque
                                        ; pixels: FL_NVAR x FL_BOXH words (bit 15 = the
                                        ; box's leftmost pixel; flag_cover)
XH_MAZE         equ     64              ; long: Ultimate's goal maze, 0
                                        ; none: the MZ_ header, K x (state, tile, palette,
                                        ; 0) pictures, KL x 4 x 32 B literal pictures, N x
                                        ; long the cells' bitmap offsets, N x word the map's
                                        ; picture (x 32), MZ_FB bytes of flags, then MZ_LB
                                        ; bytes: 23 word offsets (from their first) to the
                                        ; states' lists: word n, n x (cell x 4, picture x 32)
XH_WAVE         equ     68              ; long: Intermediate's water,
                                        ; 0 none: the WV_ header, K x (state,
                                        ; tile, palette, 0), L x 32 bytes literal pictures
                                        ; (the cells under scenery sprites: pictures K to
                                        ; K + L - 1), N x word (row x 32 + col), N
                                        ; bytes the map's picture (even), 46 x word list
                                        ; offsets (from the first) and the lists, each
                                        ; step's whole patch (merged):
                                        ; byte n, byte d, byte r0, byte r1 (its rows), n x
                                        ; (cell, picture), the d differing from step - 1's
                                        ; first;
                                        ; then 46 x WV_CMPB bytes: patch p's bit q (byte
                                        ; q >> 3, bit q & 7) = p again after q is a no-op;
                                        ; then N bytes the cells' rows (even), NR + 1 bytes
                                        ; each row's first cell (even)
XH_AFIX         equ     72              ; long: an animated group's own pixels in their
                                        ; own colours (Aerial's catapult),
                                        ; 0 none: word n (=
                                        ; XH_ANIM's), per group word nvar (0: none), word
                                        ; the variant the bitmap starts with (-1 none), per
                                        ; variant word k, k x (byte line, byte byte in the
                                        ; line, word the Mode 8 word): over the variant's
                                        ; store at the load, and over the bitmap's box for
                                        ; that first variant
XH_SIZE         equ     76
WV_N            equ     0               ; word: the cells
WV_K            equ     2               ; word: the pictures
WV_STORE        equ     4               ; long: the store (bit 31: the bitmap's tail)
WV_LB           equ     8               ; word: the lists' bytes (with their 46 offsets)
WV_Y0           equ     10              ; word: the cells' first bitmap line
WV_Y1           equ     12              ; word: and past their last
WV_L            equ     14              ; word: the literal pictures
WV_R0           equ     16              ; word: the cells' first map row
WV_NR           equ     18              ; word: their rows
WV_HSIZE        equ     20
WV_WINDOW       equ     28              ; the patch builder's rows: [W, W + $1C), W = $92
WV_CMPB         equ     6               ; the compatibility rows' bytes (46 bits)
MZ_N            equ     0               ; word: the maze cells
MZ_K            equ     2               ; word: their pictures
MZ_STORE        equ     4               ; long: the store (bit 31: in the bitmap tail, else the race area)
MZ_LB           equ     8               ; word: the lists' bytes (with their 23 offsets)
MZ_KL           equ     10              ; word: the cells under a flag's box (x 4 pictures)
MZ_FB           equ     12              ; word: the flag bytes (N, even) + the flag cells'
                                        ;  list (word n, n x cell x 4)
MZ_FL0          equ     14              ; word: the flag cells' first bitmap line
MZ_FL1          equ     16              ; word: and past their last
MZ_FINIT        equ     18              ; word: the flags' frame the map is built with x 32
MZ_HSIZE        equ     20
MZ_NST          equ     23              ; the maze's states (M_F9B 0-$16)
; a goal flag (XH_FLAGS): the part of its 16 x 24 box that changes between its 4 wave
; frames (frame id 4 + (fc >> 3 & 3)), as spans of whole Mode 8 words
FL_LINE         equ     0               ; word: the box's first changing bitmap line
FL_XB           equ     2               ; word: the box's first byte in a line (x / 2)
FL_LINES        equ     4               ; word: lines from the first to the last changing one
FL_VB           equ     6               ; word: bytes a variant (2 x the spans' words)
FL_INIT         equ     8               ; word: the variant the map was built with
FL_NSPAN        equ     10              ; word: spans
FL_STORE        equ     12              ; long: the store: the generated put code (FL_CODE B),
                                        ; then FL_NVAR + 1 variants (the last: scratch);
                                        ; bit 31 set = an offset in the bitmap (the tail
                                        ; past the race's lines), else in the race area
FL_CODE         equ     16              ; word: the put code's bytes (even)
FL_BOXL         equ     18              ; word: the whole box's first bitmap line
FL_KIND         equ     20              ; word: 0 a goal flag (the cover data, the opaque
                                        ; bits), 1 the GOAL text (palette cycling, no cover)
FL_SIZE         equ     22
FL_NVAR         equ     4
FL_BOXH         equ     24              ; the box: 24 lines x 4 Mode 8 words (16 px)
FL_HIDEB        equ     FL_BOXH*16      ; a frame's cover data in the store (after the
                                        ; scratch variant): a long a box word, (the flag's
                                        ; colours AND m, NOT m), m = its opaque pixels
; PLAY blob: what the race needs while it is played
PH_GEO          equ     0               ; long: GEO2 (G_PGEO)
PH_START        equ     4               ; long: the start image (G_MB..G_WEND: the
                                        ; marble, the object slots, the walker)
PH_TIME         equ     8               ; word: the race's time (s)
PH_SPAWN        equ     12              ; long: the spawn list (word n, n x 8 B: type,
                                        ; first row, last row, X/8, Y/8, Z/4, extra x 2)
PH_OFRM         equ     16              ; long: the objects' pictures (src/mobj.asm)
PH_RFRM         equ     20              ; long: the race-wide pictures (word n, n x (byte
                                        ; frame id, byte attribute, word w, h, xoff, yoff,
                                        ; w x h colour bytes, even)): pre-shifted at load
PH_RSPR         equ     24              ; long: their pre-shifted size (G_RSPR area)
PH_SFRM         equ     28              ; long: the slinkies' pictures (as PH_RFRM; the
                                        ; attribute byte = the variant): the sprite cache
PH_SSPR         equ     32              ; long: their pre-shifted size in the cache (0 none)
PH_MUS          equ     36              ; long: the race's tune (the
                                        ; QL tune format; src/music.inc), 0 = none (built
                                        ; without the Atari ST files)
PH_MXFRM        equ     40              ; long: the held / carried / waiting / frozen marble's
                                        ; tile pictures (as PH_RFRM: frame id = tile,
                                        ; attribute = flips >> 6)
PH_MXAT         equ     44              ; long: their pre-shifted store: bit 31 set = an offset
                                        ; in the bitmap (its tail), else in the race area
PH_MXVAC        equ     48              ; long: the vacuum's lists (Aerial), 0 none: 96 word
                                        ; offsets by M_T400 x 16 + M_VXS (side $02; $42: the
                                        ; same mirrored), then lists: byte n, n x (tile, flips
                                        ; >> 6, dx, dy), each sprite once
PH_MXSPK        equ     52              ; long: the freeze's sparkle lists, 0 none: 32 word
                                        ; offsets by M_F5CB >> 2, lists as PH_MXVAC
PH_MXTAB        equ     56              ; long: 64 B sine, the fragments'
                                        ; pattern: 8 x (tile, flips >> 6)
                                        ; (XH_MAZE's MP_ part, after its pictures: the MP_
                                        ; header, N x long the cells' bitmap offsets, N x
                                        ; word the map's picture, MP_FB bytes of flags, MP_LB
                                        ; of lists)
MP_N            equ     0
MP_FB           equ     2
MP_LB           equ     4
MP_FL0          equ     6
MP_FL1          equ     8
MP_FINIT        equ     10
MP_PICB         equ     12              ; the pictures' bytes in the store (K + 4 KL) x 32
MP_HSIZE        equ     14
PH_PIST         equ     60              ; long: Aerial's piston field,
                                        ; 0 none: the PP_ layout
PH_PPAT         equ     64              ; long: its store (bit 31: in the bitmap's tail, else
                                        ; the race area): the strips' and entries' backgrounds
PH_SIZE         equ     68
PP_ENT          equ     0               ; 108 x long: the entries' bitmap offsets (8 x 8 px)
PP_STRIP        equ     432             ; 3 x long: each column's strip (its entries 0 and 1 of
                                        ; each row: 12 or 16 px x PP_STRIPL)
PP_PAR          equ     444             ; 3 bytes: each column's line parity (bit 0) + its
                                        ; strip's words x 2 (+ 1 byte)
PP_TAB          equ     448             ; the piston's lookup tables, in order: 3, 3, 36,
PPT_AC4D        equ     0               ; 16, 16, 16, then 256 and 256 bytes (the
PPT_AE95        equ     3               ; last two indexed with any byte)
PPT_AFF3        equ     6
PPT_B034        equ     42
PPT_B025        equ     58
PPT_B016        equ     74
PPT_AEB3        equ     90
PPT_B122        equ     346
PP_PIC          equ     1050             ; 2 parities x 12 tiles ($20-$2B) x 8 x (mask, data)
PP_STRIPL       equ     52
PP_STORE        equ     3*8*52+108*32   ; the store: the strips' (8 B a line), the entries'
LIN_TOP         equ     16              ; blank lines above map row 0 in the bitmap
VIEW_SCROLL_X   equ     240             ; bitmap line of screen line 0 = scroll - this
; the race loader's work area (G_WORK, after SHARED): per tile state ST_BYTES, then the cell cache's
; index (2 KB a state) and cells (32 B each, at most CELL_SLOTS)
ST_BYTES        equ     8192+32         ; a tile state: BG + sprite tables, palettes
CELL_SLOTS      equ     1024
