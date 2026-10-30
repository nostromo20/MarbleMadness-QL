; Marble Madness for the Sinclair QL
; Copyright (C) 2026 J. McKay
; SPDX-License-Identifier: GPL-3.0-or-later
;
; mlogic.inc - the marble block layout and constants (src/mlogic.asm).
; Included at the top of src/proto.asm; the code is included at its end.

;-----------------------------------------------------------------------------
; marble block (a4-relative)
;-----------------------------------------------------------------------------
                rsreset
M_X             rs.l    1               ; X, $00HHLLFF (high, low, fraction)
M_Y             rs.l    1               ; Y, the same
M_Z             rs.l    1               ; Z, the same ($8000 = 0)
M_PX            rs.l    1               ; X before this step's move
M_PY            rs.l    1               ; Y before
M_VX            rs.w    1               ; |vx| 8.8
M_VY            rs.w    1               ; |vy| 8.8
M_VZ            rs.w    1               ; |vz| 8.8 (down)
M_VXS           rs.w    1               ; vx < 0; wait timer in state B
M_VYS           rs.w    1               ; vy < 0; second timer in state B
M_VZS           rs.w    1               ; vz up
M_STATE         rs.w    1               ; 1 roll 7 broken 8 sink 9 dead B wait
M_T400          rs.w    1               ; state timer
M_GND           rs.w    1               ; 0 airborne, 1 on the ground (9 killed)
M_AIR           rs.w    1               ; steps airborne (saturates at 255)
M_DIZZY         rs.w    1               ; dizzy counter (no steering >= $50)
M_E2            rs.w    1               ; the cell shape's steer byte (steering, caps)
M_RACING        rs.w    1               ; 1 until the goal line
M_CKPT          rs.w    1               ; respawn point (cell link)
M_CODE          rs.w    1               ; the cell code landed on ($FF none)
M_SCROLL        rs.w    1               ; course scroll
M_S             rs.w    1               ; screen y + $8000
M_DEATHS        rs.w    1               ; lives lost
M_EC            rs.w    1               ; landing-pad flag
M_FC            rs.w    1               ; logic step counter (low byte)
M_DD            rs.w    1               ; ground-snap window ($F8 / $FD)
M_F7ED          rs.w    1               ; special jumps (stays 0 here)
M_F7EF          rs.w    1               ; (stays 0 here)
M_FB            rs.w    1               ; speed-cap mode (stays 0 here)
M_CF            rs.w    1               ; the Aerial piston under the marble ($FF none)
M_FID           rs.w    1               ; frame id (1 roll, 8 dizzy, $30 wait)
M_BC            rs.w    1               ; 0 where a routine clears it (occluders)
M_T6CF          rs.w    1               ; per-object counter (the player's copy)
M_DRAWN         rs.w    1               ; the object was put on the draw list
M_PAD           rs.w    1               ; input bits this step (held)
M_PADNEW        rs.w    1               ; newly pressed: first sub-step only
M_RNG           rs.w    3               ; random generator bytes
M_EVENTS        rs.w    1               ; event bits since cleared (EV_*)
M_PUSH          rs.w    1               ; scratch: slope code of the landed cell
M_E7            rs.w    1               ; 3 = the race start's drop-in
M_F0            rs.w    1               ; state $1E steps off the screen
M_F2            rs.w    1               ; state $1E screen y (low) saved
M_F4            rs.w    1               ; state $1E checkpoint saved ($FF none)
M_F5CB          rs.w    1               ; the freeze event's counter (0 = none)
M_F5CC          rs.w    1               ; freezes left this game
M_F5CD          rs.w    1               ; freezes left this race
M_TIME          rs.w    1               ; race timer, seconds
M_T43           rs.w    1               ; logic steps towards the next second
M_T48           rs.w    1               ; bit 7 = the timer runs
M_T51           rs.w    1               ; intro counter (timer stopped)
M_PRESENT       rs.w    1               ; the player is in the game
M_E0            rs.w    1               ; the funnel record (GEO_FUNNEL index)
M_DE            rs.w    1               ; steps to the funnel's exit
M_F6            rs.w    1               ; 0 after a code $11 / $12 cell (geo_cell)
M_F8            rs.w    1               ; the previous lookup's M_F6
M_F9B           rs.w    1               ; race machinery counter
M_F9D           rs.w    1               ; race machinery state (dynamic cells)
M_F7F1          rs.w    1               ; Ultimate's maze phase (occluders)
M_E4            rs.w    1               ; 0 = riding Aerial's piston
M_F5CE          rs.w    1               ; 0 = a closed maze floor
M_KD1           rs.w    1               ; scratch: the looked-up cell's GEO_KD1 byte
M_SLOT          rs.w    1               ; 0 the player; 2-7 an object (src/mobj.asm)
M_O6CF          rs.w    1               ; objects: home index / counter
M_O5C1          rs.w    1               ; objects: steps since a hit
M_O5B9          rs.w    1               ; objects: its spawn entry
M_ATTR          rs.w    1               ; objects: sprite attribute
M_HX            rs.w    1               ; objects: home X (acid / slinky)
M_HY            rs.w    1               ; home Y
M_PATH0         rs.w    1               ; the path's start
M_POOLX         rs.w    1               ; the player: the pool that has it (X)
M_POOLY         rs.w    1               ;  (Y)
M_GCKEY         rs.w    1               ; geo_cell's cache: (ty << 8 | tx) + 1, 0 none
M_GCBASE        rs.w    1               ;  base depth
M_GCKD1         rs.w    1               ;  GEO_KD1 byte
M_GCALT         rs.w    1               ;  the other shape
M_GCSH          rs.w    1               ;  shape x 2
M_GCLINK        rs.w    1               ;  link
M_GCCODE        rs.w    1               ;  cell code
M_GCPIST        rs.w    1               ;  Aerial piston number ($FF none)
M_GCSHP         rs.w    1               ;  shape x 128 (GEO_SHAPES), -1: a dynamic code
M_GCE6          rs.w    1               ;  steer byte (static codes)
M_NOE9          rs.w    1               ; geo_cell: 1 = a depth-only lookup
M_SB            rs.w    1               ; objects: the screen y's base (X + Y) / 2 + Z
M_SX            rs.w    1               ; the screen x, (X - Y) + $80 (low byte;
                                        ;  marble_sx, made by mx_before at the draw)
M_FRON          rs.w    1               ; non-zero: the fragments are drawn
M_FRAX          rs.w    1               ; the fragment drawer's inputs on its
M_FRAY          rs.w    1               ;  last step: anchor M_SX / M_S, the angle
M_FRT           rs.w    1               ;  (M_T400 after its - 3), M_VXS, M_VYS
M_FRM           rs.w    1
M_FRR           rs.w    1
M_FBB           rs.w    1               ; Intermediate's second wave (22: running)
M_ZCD           rs.w    1               ; the zone-2 load's steps left (its last one starts
                                        ;  the waves; 0 none)
M_MZK           rs.w    1               ; Ultimate's goal maze: the states written since it
                                        ;  started (0-23; machinery, maze_update)
M_SCORE         rs.l    1               ; the score, 3 base-100 bytes (+1 the
                                        ;  high one .. +3 the low one; +0 unused)
M_C5            rs.w    1               ; the speed points' accumulator (speed_pts)
M_C2            rs.w    1               ; the goal's time bonus wait, 16-step units
M_CA            rs.w    1               ; set (50) when the time bonus is given
M_FD            rs.w    1               ; Ultimate's ridges, the drawn marble's lift (0-3)
M_SIZE          rs.b    0

EV_TAKEOFF      equ     0
EV_LAND         equ     1
EV_WALL         equ     2
EV_SIDE         equ     3
EV_KILL         equ     4
EV_BREAK        equ     5
EV_RESPAWN      equ     6
EV_GOAL         equ     7
EV_OFF          equ     8
EV_OFFTOP       equ     9               ; above the screen top: state $1E
EV_FREEZE       equ     10              ; the random freeze started
EV_TIMEOUT      equ     11              ; the timer ran out: the player is out
EV_DROP         equ     12              ; drop-in landing (dizzy, set speeds)
EV_SPECIAL      equ     13              ; a special jump (the speed-up key held at a take-off point)
EV_FUNNEL       equ     14              ; into a funnel (state $1B)

ST_ROLL         equ     1
ST_BROKEN       equ     7
ST_SINK         equ     8
ST_DEAD         equ     9
ST_WAIT         equ     $0B
ST_OFFTOP       equ     $1E
ST_FUNNEL       equ     $1B             ; into the funnel (st_funnel)
ST_FUNNEL2      equ     $1C             ; in the funnel, to its exit

