
          __  __    _    ____  ____  _     _____
         |  \/  |  / \  |  _ \| __ )| |   | ____|
         | |\/| | / _ \ | |_) |  _ \| |   |  _|
         | |  | |/ ___ \|  _ <| |_) | |___| |___
         |_|  |_/_/   \_\_| \_\____/|_____|_____|

          __  __    _    ____  _   _ _____ ____ ____
         |  \/  |  / \  |  _ \| \ | | ____/ ___/ ___|
         | |\/| | / _ \ | | | |  \| |  _| \___ \___ \
         | |  | |/ ___ \| |_| | |\  | |___ ___) |__) |
         |_|  |_/_/   \_\____/|_| \_|_____|____/____/

              ============================================
                       SINCLAIR QL CONVERSION
              ============================================

                         - RELEASE 2026 -

            An unofficial conversion of the arcade classic
                    for the Sinclair QL computer


 ============================================================================
                              BACKGROUND
 ============================================================================

 Marble Madness was released to the arcades by Atari Games in 1984.
 Designed by Mark Cerny, it put the player in charge of a marble rolling
 down six isometric courses of ramps, chutes and narrow ledges, steered
 with a trackball against the clock.  Its pre-rendered look, stereo
 soundtrack and simple idea made it one of the most recognisable games
 of its time, and it was converted to most home computers and consoles
 of the following years.

 This QL conversion recreates the courses, the marble physics, the
 enemies and the rules of the game.  The race tunes come from the Atari
 ST version.

 Guide the marble from the start to the goal line of each race before the
 timer runs out, avoiding the edges, the drops and everything that lives
 on the course: steelies, slinkies, acid pools, birds, vacuums, hammers,
 mini marbles and more.


 ============================================================================
                           ORIGINAL CREDITS
 ============================================================================

              ARCADE GAME DESIGN ............. Mark Cerny
              ARCADE PROGRAMMING ............. Mark Cerny
                                               Bob Flanagan
              ARCADE MUSIC ................... Brad Fuller
                                               Hal Canon

                          (c) 1984 Atari Games


 ============================================================================
                         SINCLAIR QL VERSION
 ============================================================================

              QL CONVERSION .................. Jim McKay

 This conversion is a ground-up rewrite in 68000 assembler for a
 standard QL with a memory expansion.  Features:

   * All six races: Practice, Beginner, Intermediate, Aerial, Silly
     and Ultimate
   * The marble physics and race logic run at a steady 60 steps a
     second, whatever the frame rate
   * Every enemy and moving part of the courses: steelies, slinkies,
     acid pools, birds, vacuums, hammers, mini marbles, Aerial's pistons
     and catapult, Intermediate's waves, Beginner's bridge and
     Ultimate's goal maze
   * Full colour Mode 8 courses with smooth scrolling and the marble
     passing behind the scenery
   * 12.5 frames a second (10 fps and an adaptive mode also available)
   * Scoring, time bonuses, race boxes and the HIGH ROLLERS table
   * The Atari ST race tunes and sound effects on an AY sound board
     (QLion, ZX Spectrum Next QL core, QL PiStorm, QSound),
     or the sound effects on the QL's own beeper


 ============================================================================
                               FILES
 ============================================================================

   BOOT     runs the game (EXEC_W mdv1_mm)
   mm       the game: a QDOS executable (about 32 KB, the code packed)
   mm_dat   the six races' data (about 84 KB, packed)

 The release also comes as a Microdrive cartridge image, mm.mdv
 (236 sectors).


 ============================================================================
                               LOADING
 ============================================================================

 From a Microdrive: put the cartridge in mdv1_ and reset, or

   EXEC_W mdv1_mm

 From another device, copy mm and mm_dat to it and EXEC_W from there,
 e.g.

   EXEC_W win1_mm

 The game finds mm_dat by itself.  It looks in Toolkit II's default
 directory (if Toolkit II is present), then on mdv1_, win1_, win2_, flp1_
 and mdv2_, in that order.  No toolkit is needed.

 The loading screen stays up while mm_dat loads and the first race is
 prepared.  Each race is then built from mm_dat in a few seconds.

 The game takes over the whole machine while it runs.  ESC quits by
 resetting the QL, as switching it off and on again would.


 ============================================================================
                              CONTROLS
 ============================================================================

      STEER:              CURSOR KEYS (8 directions; DOWN rolls down
                          the screen)

      SPEED UP:           SPACE

      PAUSE / CONTINUE:   ENTER

      SOUND ON / OFF:     \

      QUIT (RESET):       ESC


 ============================================================================
                             HOW TO PLAY
 ============================================================================

 Each race is against the clock.  Roll the marble down the course to the
 goal line before the timer reaches zero.  Every second left at the goal
 is worth a time bonus, and from Intermediate on the time left over is
 added to the next race's time.  Points are also scored for speed, for
 reaching the goal and for some special landings.

 Drop too far, slide into an acid pool or get caught by an enemy and the
 marble is lost: after a short wait a new one is placed back on the
 course at the last checkpoint, and the clock keeps running.  When the
 time runs out the game is over, and a good score earns a place in the
 HIGH ROLLERS table.

 The courses get steeper, narrower and busier as you go.  Use SPACE for
 extra speed, but every slope and every ledge has to be taken under
 control.


 ============================================================================
                               RACES
 ============================================================================

   1  PRACTICE       a gentle course to learn the controls
   2  BEGINNER       the steelie, slinkies and the bridge
   3  INTERMEDIATE   slinkies, acid pools and the waves
   4  AERIAL         vacuums, hammers, pistons and the catapult
   5  SILLY          birds and mini marbles
   6  ULTIMATE       the steelie, acid pools, the ridges, the chute
                     and the goal maze


 ============================================================================
                          SUPPORTED HARDWARE
 ============================================================================

 * A Sinclair QL with at least 640 KB of memory (128 KB internal plus a
   512 KB expansion) and a 50 Hz display
 * JS, Minerva or compatible ROM; Toolkit II is optional
 * Tested on a real QL (JS ROM, 640 KB), Q-emuLator (JS and Minerva) and
   sQLux

 SOUND
 -----
 The game looks for an AY-3-8910 sound chip at start-up, in this order,
 and plays the race tunes and the sound effects on the first one found:

 QLION / ZX SPECTRUM NEXT (QL core)
   The QLion card and the Spectrum Next's QL core share one AY
   interface (2.5 MHz), detected by their signature at $80001E.

 QL PISTORM
   The PiStorm's AY emulation (0.75 MHz), detected by its "QLPS"
   signature.

 QSOUND
   The QSound board (0.75 MHz), detected through its ROM's system
   variable.  It is not used on a QL whose memory reaches the board's
   addresses (896 KB and over).

 Each note's pitch is converted to the board's own clock, so the tunes
 play in tune on every board.  Without any of them, the sound effects
 play on the QL's IPC beeper (no music).  \ turns all sound off and on.


 ============================================================================
                          TECHNICAL HIGHLIGHTS
 ============================================================================

 Running the game at its full logic speed on a 7.5 MHz 68008 took some
 careful engineering.

 RENDERING
 ---------
 * Each course is built at load time into one linear Mode 8 bitmap, and
   every frame copies the visible part of it into the hidden screen with
   unrolled MOVEM loops, then the two screens are swapped.
 * The QL has no hardware scrolling, so the game turns the QL's second
   screen (the 32 KB at $28000 that QDOS normally uses for its own system
   area) into a back buffer: each frame is composited directly in screen
   memory - the scrolled course, the enemies and the marble - on the
   screen not being shown, and the display is then switched to it on the
   frame boundary.
   The result behaves like hardware scrolling: the whole view moves in
   one clean step, with no tearing and no extra off-screen copy.
 * The marble is drawn from frames pre-shifted at all four pixel
   positions, and hidden behind scenery by per-course occluder data.
 * Enemies are pre-shifted at load time; the large slinky picture sets go
   into a sprite cache in the memory left over.

 SIMULATION
 ----------
 * The marble's physics, the course surfaces and the race logic run in
   fixed 60 Hz steps: 6 steps for every 5 ticks of the 50 Hz clock, so
   the game keeps the same speed at 10 or 12.5 frames a second.
 * The enemies run at 30 Hz, every other step.

 DATA
 ----
 * All six races fit in one 84 KB file: compact level data,
   ZX0-compressed, expanded into the QL's formats at load time.
 * The program itself is ZX0-packed inside a small QDOS job that unpacks
   it, shows the loading screen and loads the data.

 PLATFORM
 --------
 * The game takes the whole machine: interrupts off, the keyboard read
   straight from the IPC, the frame timing from the hardware's frame
   interrupt flag.  QDOS's 32 KB system area becomes the second screen,
   which is why ESC resets the machine rather than returning to BASIC.
 * The adaptive mode moves between 10 and 12.5 frames a second as the
   course allows.


 ============================================================================
                          SETTINGS (ADVANCED)
 ============================================================================

 A few settings live in the mm file itself and can be changed with any
 file or hex editor (offsets from the start of the QDOS file):

   +20  sound:       0 = find an AY board, else the beeper (default)
                     1 = no sound      5 = always the beeper
   +21  frame rate:  2 = 12.5 fps (default)   1 = 10 fps   0 = adaptive
   +22  mm_dat's device, as a QDOS string: a word length then up to 10
        characters (e.g. 5, "win2_").  Length 0 (default): search as
        described under LOADING
   +34  1 = show the sprite cache size before the game (default 0)


 ============================================================================
                        BUILDING FROM SOURCE
 ============================================================================

 The source release holds the game's 68000 source (src/), the game data
 it is built with (data/) and the build tools.  You need:

   * vasm, the 68000 assembler in Motorola syntax (vasmm68k_mot)
   * Python 3
   * Einar Saukas's ZX0 compressor (zx0), at tools/ext/zx0/src/zx0 or
     named by the environment variable ZX0 (on Windows, a Linux build
     run through WSL)
   * a bash shell

 Then:

   ./build_release.sh

 builds build_rel/release/mm.mdv (the cartridge image) and the files for
 a QL folder in build_rel/release/win/ (BOOT, mm, mm_dat; mm carries a
 Q-emuLator file header).  VASM, PY and ZX0 can name the tools.


 ============================================================================
                          SOURCE CODE AND LICENCE
 ============================================================================

 The QL source code (68000 assembler and the Python build tools) is
 released under the GNU General Public License, version 3 or later: see
 the file COPYING.

 The ZX0 decompressor (src/unzx0_68000.s) is by Emmanuel Marty, under
 the zlib licence; the ZX0 format and compressor are by Einar Saukas.

 Marble Madness is a trademark of its owners.  This is an unofficial,
 non-commercial fan conversion; the game's graphics, courses and music
 remain the property of their respective owners.


 ============================================================================
                             THANKS TO
 ============================================================================

 * Mark Cerny and the Atari Games team for the original game
 * Einar Saukas and Emmanuel Marty for ZX0 and its 68000 decoder
 * The QL community for keeping the platform alive


 ============================================================================

                            ROLL ON!

                              J. McKay
                                2026

 ============================================================================
