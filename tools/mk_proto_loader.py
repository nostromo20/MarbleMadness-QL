#!/usr/bin/env python3
# Marble Madness for the Sinclair QL
# Copyright (C) 2026 J. McKay
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate the SuperBASIC loaders for the playable prototype (src/proto.asm).

    python tools/mk_proto_loader.py [build_dir]

In the build folder (the test build, mmp, and the release build, mmr):
  mmp_bas          the play loader: LRUN win1_mmp_bas (waits for a key, then prints the
                   results after ESC)
  mmt_bas          the same in TAKEOVER mode (any ROM: JS, Minerva, ...; no dual-screen
                   boot needed): RESPRs a 32 KB buffer for $28000-$2FFFF and pokes
                   G_TAKE = 1; the game then runs in supervisor mode, interrupts off,
                   talking to the hardware directly, and gives the machine back on ESC
  mmp_tbas         test loader for runs under sQLux: no key wait, pokes a frame
                   budget and start settings (sync, measuring mode, fixed input bits), then
                   SBYTES the globals block to win1_mmp_res and screen 0 to win1_mmp_scr
                   and ends sQLux with KILL_UQLX (an sQLux keyword).

Sizes are baked in from the files on disk (stock SuperBASIC has no FLEN), each RESPR is
rounded up to EVEN, the files are written LF-only, and the globals offsets come from the
vasm listing (proto.lst) so they cannot drift from the source.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
G = 4
FILES = ('mmp', 'mm_dat')     # the code and the data of all six races
TEST_FRAMES = 150
TK_SAVE = 32768                 # takeover: the copy of $28000-$2FFFF
CC_SPARE = 2048                 # takeover: free memory left to QDOS beside the sprite cache
                                # (each KB here is a KB less cache: on a 640 KB QL with win1_,
                                # 8 KB would bound the cache to 39 KB, under the slinkies' 41,628 B)


def equates(lst):
    eq = {}
    for line in lst.read_text(encoding='latin-1').splitlines():
        m = re.match(r'^(\w+)\s+E:([0-9A-F]{8})\s*$', line)
        if m:
            eq[m.group(1)] = int(m.group(2), 16)
    return eq


def even(n):
    return n + (n & 1)


def buffers(b):
    """the load path's buffers (mm_dat.json, written with mm_dat)"""
    import json
    j = json.loads((b / 'mm_dat.json').read_text())
    mb = b / 'mmdat_ref' / 'marble_bank'
    spr = mb.stat().st_size if mb.exists() else j['spr']     # (data/: the size recorded)
    return {'area': even(j['area']), 'lin': even(j['lin']), 'spr': even(spr)}


def head(b, eq, take=False, title=False, tel_kb=0):
    """take: False (QDOS mode), True (takeover, mmt_bas: the save buffer, the clean exit
    back to BASIC) or 'release' (mmr_bas: takeover with no save buffer on any ROM, the
    32 KB going to the sprite cache; ESC resets the machine) or 'measure' (test loaders
    only: the release's memory layout and sprite cache, but a clean exit back to BASIC
    for the results: mm_dat's RESPR is the save buffer, so no race loads once the game
    has the machine - goto_race ends the run instead). title: the loading screen
    (mmr draws it: G_TLOGO, src/frontend.asm fe_loadlogo) as soon as the code is in,
    before mm_dat loads (the play loaders; the test loaders do without)"""
    meas = take == 'measure'
    rel = take == 'release' or meas
    sz = {f: even((b / f).stat().st_size) for f in FILES}
    # (the release loads mmr: the release build, no measuring code; its size
    # stands in for mmp's)
    code = 'mmr' if take == 'release' else 'mmp'
    sz['mmp'] = even((b / code).stat().st_size)
    assert not meas or sz['mm_dat'] >= TK_SAVE, 'measure: mm_dat smaller than the save buffer'
    bu = buffers(b)
    total = sum(sz.values()) + sum(bu.values()) + (TK_SAVE if take and not rel else 0)
    # takeover: the sprite cache = the QDOS free memory left after the save buffer, at
    # $30000 or above (screen 1 is $28000-$2FFFF), CC_SPARE kept for BASIC and the heap
    # after the return; RESPRed before the save buffer, so it gets what fast RAM is left.
    # System variables at $28000 (ident byte $D2) or $30000 (Minerva dual).
    # SV_FREE $0C, SV_BASIC $10, SV_RESPR $1C.
    # mmt_bas (and its test loaders): tel = the telemetry buffer in KB (0: none, the
    # program's G_TELB 0), RESPRed below the sprite cache (its sums take it off)
    # (mmm_bas, the measure loader: telemetry too, 16 KB by default; its buffer is
    # mm_dat's RESPR past the save buffer - mm_dat is read only at the race loads, done
    # before tel_init - so the sprite cache is the release's)
    tel_ok = take and take != 'release'
    tl = ' - tsz' if tel_ok and not meas else ''
    tk = ([
        # (mmm_bas: at most what mm_dat has past the save buffer; the IF's rest of the
        # line, the REMark too, is its THEN)
        '209 tel = %d : tsz = tel * 1024 : ' % tel_kb + (
            'IF tsz > dsz - %d THEN tsz = INT((dsz - %d) / 1024) * 1024 : ' % (TK_SAVE, TK_SAVE) if meas else '') +
        'REMark telemetry: KB of frame records, 0 off (16: about 2 minutes), saved to mm_tel at ESC',
    ] if tel_ok else []) + [
        ('211 sv = 163840 : s = 0 : IF PEEK(sv) <> 210 THEN sv = 196608' if rel else
         '211 sv = 163840 : s = %d : IF PEEK(sv) <> 210 THEN sv = 196608 : s = 0' % TK_SAVE),
        '212 n = PEEK_L(sv+28) - s - dsz%s - 196608' % tl,
        '213 f = PEEK_L(sv+16) - PEEK_L(sv+12) - s - dsz%s - %d : IF f < n THEN n = f' % (tl, CC_SPARE),
        '214 n = INT(n / 1024) * 1024 : IF n < 4096 THEN n = 0',
        '215 cch = 0 : IF n > 0 THEN cch = RESPR(n)',
        '216 POKE_L adr+%d, cch : POKE_L adr+%d, n' % (G + eq['G_CCH'], G + eq['G_CSZ']) + (
            ' : tbf = 0 : IF tel THEN tbf = RESPR(tsz) : POKE_L adr+%d, tbf : POKE_L adr+%d, tsz' % (
                G + eq['G_TELB'], G + eq['G_TELN']) if tl else ' : tbf = 0' if meas and tel_ok else ''),
        '217 sav = 0 : IF s > 0 THEN sav = RESPR(s)',
        ('218 PRINT "MEASURE: the release layout, mm_dat = the save buffer; sprite cache "; cch; ", "; n'
         if meas else
         '218 POKE_L adr+%d, 0 : POKE_W adr+%d, 3 : PRINT "RELEASE: ESC resets the machine; sprite cache "; cch; ", "; n' % (
            G + eq['G_SAVE'], G + eq['G_TAKE']) if rel else
         '218 POKE_L adr+%d, sav : POKE_W adr+%d, 1 + (s = 0) : PRINT "TAKEOVER: save "; sav; " sprite cache "; cch; ", "; n' % (
            G + eq['G_SAVE'], G + eq['G_TAKE'])),
    ] if take else []
    return total, sz, [
        '100 REMark Marble Madness QL - playable prototype (all six races)',
        '110 REMark GENERATED by tools/mk_proto_loader.py - do not edit.',
        '120 REMark Stock SuperBASIC only (no Toolkit II).',
        '130 dev$ = "win1_"',
        '140 csz = %d : dsz = %d : aud = 0 : fps = 2' % (sz['mmp'], sz['mm_dat']),
        '150 MODE 8 : CLS',
        '160 PRINT "MM prototype: RESPR "; %d; " bytes"' % total,
        '170 adr = RESPR(csz) : LBYTES dev$ & "%s", adr' % code + (
            ' : POKE_W adr+%d, 1 : CALL adr' % (G + eq['G_TLOGO']) if title else ''),
        '190 rbf = RESPR(%d)' % bu['area'],
        '200 lin = RESPR(%d) : spr = RESPR(%d)' % (bu['lin'], bu['spr']),
        '205 POKE_L adr+%d, rbf' % (G + eq['G_RBUF']),
        '210 POKE_L adr+%d, lin : POKE_L adr+%d, spr' % (G + eq['G_LIN'], G + eq['G_SPRB']),
    ] + tk + [
        '207 POKE_W adr+%d, aud : REMark sound: 0 = find the AY board (none: beeper), 1 = none, 5 = beeper' % (
            G + eq['G_TAUD']),
        '208 POKE_W adr+%d, fps : REMark frame rate: 2 = 12.5 fps (the default), 1 = 10 fps, 0 = adaptive 10 / 12.5 fps' % (
            G + eq['G_TFPS']),
        # mm_dat last, the lowest: it is read only at the race loads, so the slower
        # motherboard RAM is for it, the fast RAM above $40000 for the sprite cache
        '219 dat = RESPR(dsz) : LBYTES dev$ & "mm_dat", dat : POKE_L adr+%d, dat' % (G + eq['G_DAT']) + (
            ' : POKE_L adr+%d, dat : POKE_W adr+%d, 1' % (G + eq['G_SAVE'], G + eq['G_TAKE']) if meas else '') + (
            ' : IF tel THEN tbf = dat + %d : POKE_L adr+%d, tbf : POKE_L adr+%d, tsz' % (
                TK_SAVE, G + eq['G_TELB'], G + eq['G_TELN']) if meas and tel_ok else ''),
        '220 PRINT "code "; adr; " data "; dat; " level "; lin',
        '230 PRINT "race area "; rbf; " sprites "; spr',
        '240 low = adr : REMark (the frame memory; mm_dat: read at the loads only)',
        '250 IF lin < low THEN low = lin',
        '260 IF spr < low THEN low = spr',
        '262 IF rbf < low THEN low = rbf',
    ] + (['264 IF cch > 0 AND cch < low THEN low = cch : REMark (the sprite cache)'] if take else []) + [
        '270 IF low < 262144 THEN PRINT "* BELOW 262144: motherboard RAM, slower *"',
        '280 IF low >= 262144 THEN PRINT "All in fast RAM, margin "; low - 262144',
    ]


def report(eq):
    g = 'adr+%d' % G
    mb = G + eq['G_MB']
    return [
        '370 g = %s : m = adr+%d' % (g, mb),
        '380 CLS',
        '390 PRINT "Marble Madness QL prototype - results"',
        '400 s = PEEK_W(g+%d) : s$ = "FREE"' % eq['G_SEFF'],
        '402 IF s = 1 THEN s$ = "VSYNC"',
        '404 IF s = 2 THEN s$ = "DOUBLE"',
        '406 PRINT "sync "; s$; ", "; PEEK_W(g+%d); " ticks/frame, "; PEEK_W(g+%d); " lines"' % (
            eq['G_NT'], eq['G_LINES']),
        '410 PRINT "mode "; PEEK_W(g+%d); "  mean BUSY ms/frame "; PEEK_W(g+%d) / 100' % (
            eq['G_MODE'], eq['G_MS100']),
        '420 PRINT "last 1s: busy ms "; PEEK_W(g+%d) / 10; " fps "; PEEK_W(g+%d) / 10' % (
            eq['G_MS10W'], eq['G_FPS10']),
        '430 t0 = PEEK_W(g+%d) : IF t0 = 0 THEN GO TO 470' % eq['G_BRES'],
        '440 PRINT "BENCH (ms): total "; t0 / 100; " copy "; (t0 - PEEK_W(g+%d)) / 100' % (
            eq['G_BRES'] + 4),
        '450 PRINT "  logic(6 steps) "; (PEEK_W(g+%d) - t0) / 900; " sprite "; (t0 - PEEK_W(g+%d)) / 100' % (
            eq['G_BRES'] + 2, eq['G_BRES'] + 6),
        '460 PRINT "  input "; (t0 - PEEK_W(g+%d)) / 100; " occlusion "; (t0 - PEEK_W(g+%d)) / 100; " objects "; (t0 - PEEK_W(g+%d)) / 100' % (
            eq['G_BRES'] + 8, eq['G_BRES'] + 10, eq['G_BRES'] + 12),
        '470 PRINT "frames "; PEEK_L(g+%d); "  sysvars at "; PEEK_L(g+%d); ", spins/tick "; PEEK_L(g+%d)' % (
            eq['G_FRAMES'], eq['G_SYS'], eq['G_K']),
        '480 d$ = "not detected" : IF PEEK_W(g+%d) THEN d$ = "DETECTED"' % eq['G_DUAL'],
        '490 PRINT "Dual screen (Minerva F3/F4): "; d$',
        '500 c$ = "frame poll task" : IF PEEK_W(g+%d) = 0 THEN c$ = "SV_RAND fallback (! on panel)"' % eq['G_POLLOK'],
        '510 PRINT "timing: "; c$',
        '512 PRINT "sprite cache at "; PEEK_L(g+%d); ", "; PEEK_L(g+%d); " bytes"' % (
            eq['G_CCH'], eq['G_CSZ']),
        '514 IF PEEK_W(g+%d) THEN PRINT "cache check: "; PEEK_W(g+%d) - 1; " longs changed"' % (
            eq['G_CCHK'], eq['G_CCHK']),
        '516 PRINT "sprite cache used (most) "; PEEK_L(g+%d); " bytes; slinkies off (no room) "; PEEK_W(g+%d)' % (
            eq['G_CMAX'], eq['G_SLOFF']),
        # (bytes, not PEEK_W: X/Y's integer word sits at an ODD offset in its long)
        '520 PRINT "marble X "; PEEK(m+%d)*256+PEEK(m+%d); " Y "; PEEK(m+%d)*256+PEEK(m+%d); " state "; PEEK_W(m+%d); " deaths "; PEEK_W(m+%d)' % (
            eq['M_X'] + 1, eq['M_X'] + 2, eq['M_Y'] + 1, eq['M_Y'] + 2, eq['M_STATE'], eq['M_DEATHS']),
        '522 IF PEEK_W(g+%d) = 0 THEN GO TO 530' % eq['G_LABOK'],
        '524 l = g+%d : PRINT "LAB us/pass: R ";PEEK_L(l)/6400;" RI (no interrupts) ";PEEK_L(l+44)/6400' % eq['G_LAB'],
        '525 PRINT "LAB ms: LOG ";PEEK_L(l+32)/100000;" NK ";PEEK_L(l+36)/100000;" CPY ";PEEK_L(l+64)/100000;" SPR ";PEEK_L(l+68)/100000',
        '526 PRINT "  DRN ";PEEK_L(l+48)/100000;" KR ";PEEK_L(l+52)/100000;" PAN ";PEEK_L(l+56)/100000;" PI ";PEEK_L(l+60)/100000',
        '527 PRINT "stack at ";PEEK_L(g+%d);" code at ";adr' % eq['G_SP0'],
        '528 IF PEEK_W(g+%d) THEN PRINT "TAKEOVER refused / IPC timeouts: ";PEEK_W(g+%d)' % (
            eq['G_TKERR'], eq['G_TKERR']),
        '531 PRINT "late frames (shown a tick or more late): ";PEEK_L(g+%d)' % eq['G_LATE'],
        '517 a = PEEK_W(g+%d) : PRINT "sound: ";a;" (0 none, 1 QSound, 2 QIMSI Gold, 3 PiStorm, 4 QLion/Next, 5 dummy, 6 beeper)"' % eq['G_AUD'],
        '518 IF a = 6 THEN PRINT "beeper: effects only, ";PEEK_L(g+%d);" BEEPs sent"' % eq['G_BCNT'],
        '519 f = PEEK_W(g+%d) : n = PEEK_W(g+%d) : m$ = "adapt fix10 fix12" : r$ = "12.5 10  " : PRINT "frame rate: ";m$(f*6+1 TO f*6+5);", now ";r$((n=5)*5+1 TO (n=5)*5+4);" fps; switches ";PEEK_W(g+%d);"; frames at 10 fps ";PEEK_L(g+%d);", at 12.5 ";PEEK_L(g+%d)' % (
            eq['G_FPSM'], eq['G_NT'], eq['G_FSW'], eq['G_F10'], eq['G_F125']),
        '529 PRINT "logic: ";PEEK_L(g+%d);" logic steps in ";PEEK_L(g+%d);" ticks, capped frames ";PEEK_W(g+%d)' % (
            eq['G_STOT'], eq['G_TTOT'], eq['G_SCAP']),
    ]


def quiet(L):
    """the release loader prints nothing over the loading screen: its PRINTs dropped"""
    import re
    out = []
    for ln in L:
        num, st = ln.split(' ', 1)
        if st.startswith('PRINT') or st.startswith('IF ') and 'THEN PRINT' in st:
            continue
        st = re.sub(r'\s*:\s*PRINT .*$', '', st)
        out.append(num + ' ' + st)
    return out


def write_user_loader(b, eq, take=False):
    meas = take == 'measure'
    # mme_bas: mmt_bas that goes straight to the ending after Ultimate (its seconds left,
    # deaths and score on line 146), then the high scores and a new game as after a real
    # Ultimate goal
    end = take == 'ending'
    if end:
        take = True
    total, sz, L = head(b, eq, take, title=True, tel_kb=16 if meas else 0)
    if meas:
        # mmm_bas: one race in the release's memory (mm_dat lent to the save buffer, so
        # the sprite cache is the release's: the slinkies on), telemetry on; the run ends
        # at the race's end (a race change would need mm_dat)
        L += [
            '145 race = 2 : REMark the one race: 1 Practice 2 Beginner 3 Intermediate 4 Aerial 5 Silly 6 Ultimate',
            '206 POKE_W adr+%d, race' % (G + eq['G_TRACE']),
        ]
    if take == 'release':
        # the release: no text over the loading screen and no key wait; the game starts
        # when it is loaded (its keys: README.txt)
        # (back to BASIC only when the takeover was refused: the release build has
        # none of the test build's figures to report)
        L = quiet(L) + [
            '360 CALL adr',
            '528 IF PEEK_W(adr+%d) THEN PRINT "TAKEOVER refused / IPC timeouts: ";PEEK_W(adr+%d)' % (
                G + eq['G_TKERR'], G + eq['G_TKERR']),
            '530 PRINT "RESPR is not freed until reset."']
        write(b / 'mmr_bas', L)
        return total, sz
    if not meas:
        # the start screen (the logo, the keys, PRESS SPACE TO START: src/frontend.asm
        # fe_start), as the release has it always; the one-race loader goes straight in
        L += ['223 POKE_W adr+%d, 1 : REMark the start screen (0 = straight into Practice)'
              % (G + eq['G_TSTART'])]
    if end:
        L += [
            '146 secs = 59 : deaths = 5 : score = 6900 : REMark at Ultimate\'s goal (secs 0-99, deaths 0-20)',
            '206 POKE_W adr+%d, secs + 1 : POKE_W adr+%d, deaths' % (G + eq['G_TEND'], G + eq['G_TENDD']),
            '221 POKE adr+%d, INT(score / 10000) : POKE adr+%d, INT(score / 100) MOD 100 : POKE adr+%d, score MOD 100' % (
                G + eq['G_TENDS'] + 1, G + eq['G_TENDS'] + 2, G + eq['G_TENDS'] + 3),
            '285 PRINT "THE ENDING TEST (line 146): "; secs; " s left, "; deaths; " deaths, score "; score',
        ]
    L += [
        '290 PRINT "ARROWS steer (diagonals too)  SPACE speed-up"',
        ('295 PRINT "ONE RACE (line 145): the run ends at its end, ESC or a key 1-6"' if meas else
         '295 PRINT "1-6 race: Practice Beginner Intermediate Aerial Silly Ultimate"'),
        '300 PRINT "T measuring mode 0-7  B benchmark (no keys)"',
        '305 PRINT "L LAB timings (10 s)  D demo input on/off"',
        '310 PRINT "H height 224/208/192  V sync FREE/VSYNC/DOUBLE  F 10/12.5 fps"',
        '320 PRINT "ENTER or P pause  \\ sound mute  R restart  O panel / HUD  ESC quit"',
        '325 PRINT "M marble behind scenery on/off  C race timer off/on"',
        ('330 PRINT "Takes the machine over: any ROM, DOUBLE always"' if take else
         '330 PRINT "DOUBLE needs Minerva booted with F3/F4 (or mmt_bas)"'),
    ] + (['335 PRINT "RELEASE: ESC ends with a reset of the machine"'] if take == 'release' else []) + (
        ['337 PRINT "The release memory layout (sprite cache as mmr_bas); telemetry "; tel; " KB"'] if meas else []) + [
        '345 PRINT "Press a key to start"',
        '350 k$ = INKEY$(-1)',
        '360 CALL adr',
    ] + ([
        # (telemetry: takeover has no file I/O, so the loader saves the buffer)
        '365 IF tel THEN POKE_L tbf+8, PEEK_L(adr+%d) - tbf : DELETE dev$ & "mm_tel" : SBYTES dev$ & "mm_tel", tbf, tsz' % (
            G + eq['G_TELP']),
    ] if take else []) + report(eq) + ([
        '532 IF tel THEN PRINT "telemetry: ";tsz;" bytes saved to ";dev$;"mm_tel"',
    ] if take else []) + ['530 PRINT "RESPR is not freed until reset."']
    write(b / ('mmr_bas' if take == 'release' else 'mmm_bas' if meas else 'mme_bas' if end else
               'mmt_bas' if take else 'mmp_bas'), L)
    return total, sz


def write_test_loader(b, path, sync=None, mode=None, pad=None, frames=TEST_FRAMES, eq=None,
                      lab=False, demo=False, sqlux=True, take=False, race=None, img=None,
                      cchk=False, aud=0, tbeep=0, floff=0, nocall=False, panel=1):
    """sync 0/1/2, mode 0-4, pad = fixed input bits (None = read KEYROW); None = default.
    lab: run the LAB at start and quit; demo: demo input from the start; sqlux: end with
    KILL_UQLX (sQLux only; Q-emuLator is stopped from outside). img: (file name,
    size) of a start image G_MB..G_WEND (a bench position) the program starts from.
    panel: the top band, 1 the debug panel (default: the measuring figures), 0 the HUD
    (the game's loaders poke nothing: the HUD), 2 nothing."""
    eq = eq or equates(b / 'proto.lst')
    total, sz, L = head(b, eq, take)
    v = [0 if c is None else c + 1 for c in (sync, mode, pad)]
    L += [
        '290 POKE_W adr+%d, %d : POKE_W adr+%d, %d' % (G + eq['G_TFRAMES'], frames,
                                                    G + eq['G_TSYNC'], v[0]),
        '300 POKE_W adr+%d, %d : POKE_W adr+%d, %d' % (G + eq['G_TMODE'], v[1],
                                                    G + eq['G_TPAD'], v[2]),
        '310 POKE_W adr+%d, %d : POKE_W adr+%d, %d' % (G + eq['G_TLAB'], int(lab),
                                                    G + eq['G_TDEMO'], int(demo)),   # demo 2 = benchmark
        '320 POKE_W adr+%d, %d : POKE_W adr+%d, 1' % (G + eq['G_TRACE'], 0 if race is None else race + 1,
                                                    G + eq['G_TNOBOX']),   # (no race boxes)
        '322 POKE_W adr+%d, %d : POKE_W adr+%d, %d' % (G + eq['G_TAUD'], aud,
                                                    G + eq['G_TBEEPN'], tbeep & 0xFFFF),
        '323 POKE_W adr+%d, %d' % (G + eq['G_TPANEL'], panel),   # (0 HUD, 1 panel, 2 none)
    ] + (['325 POKE_W adr+%d, 1' % (G + eq['G_TCCHK'])] if cchk else []) + (
        ['326 POKE_W adr+%d, %d' % (G + eq['G_TFLOFF'], floff)] if floff else []) + ([
        '330 img = RESPR(%d) : LBYTES dev$ & "%s", img : POKE_L adr+%d, img' % (
            img[1], img[0], G + eq['G_TIMG']),
    ] if img else []) + ([
        '360 CALL adr',
    ] if not nocall else []) + report(eq) + ([
        # (load-time loaders only: a 521 IF ... THEN PRINT of these in every loader hangs
        # Minerva after a takeover run in sQLux)
        '532 PRINT "load (ticks): start ";PEEK_W(g+%d)' % eq['G_LDT'],
        '533 PRINT "races ";' + ';" ";'.join('PEEK_W(g+%d)' % (eq['G_LDT'] + 2 * i)
                                           for i in range(1, 7)),
    ] if lab == 2 else []) + [
        '540 SBYTES dev$ & "mmp_scr", 131072, 32768',
        '550 SBYTES dev$ & "mmp_res", adr+%d, %d' % (G, eq['G_END']),
    ] + (['560 KILL_UQLX'] if sqlux else [])
    write(path, L)


def write(path, L):
    text = '\n'.join(L) + '\n'
    assert '\r' not in text
    path.write_bytes(text.encode('ascii'))


def main():
    b = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build'
    eq = equates(b / 'proto.lst')
    need = ['G_LIN', 'G_PGEO', 'G_SPRB', 'G_DAT', 'G_RBUF', 'G_TFRAMES', 'G_TSYNC', 'G_TMODE', 'G_TPAD', 'G_END',
            'G_SEFF', 'G_NT', 'G_LINES', 'G_MODE', 'G_MS100', 'G_MS10W', 'G_FPS10', 'G_BRES',
            'G_FRAMES', 'G_SYS', 'G_K', 'G_DUAL', 'G_POLLOK', 'G_MB', 'M_X', 'M_Y', 'M_STATE',
            'M_DEATHS', 'G_TLAB', 'G_TDEMO', 'G_LABOK', 'G_LAB', 'G_SP0', 'G_TAKE', 'G_SAVE',
            'G_TKERR', 'G_STOT', 'G_TTOT', 'G_SCAP', 'G_LATE', 'G_TELB', 'G_TELN', 'G_TELP',
            'G_TEND', 'G_TENDD', 'G_TENDS', 'G_TSTART']
    missing = [n for n in need if n not in eq]
    if missing:
        sys.exit('mk_proto_loader: listing lacks %s' % missing)
    total, sz = write_user_loader(b, eq)
    write_user_loader(b, eq, take=True)
    write_user_loader(b, equates(b / 'proto_r.lst'), take='release')
    write_user_loader(b, eq, take='measure')
    write_user_loader(b, eq, take='ending')
    write_test_loader(b, b / 'mmp_tbas', eq=eq)
    bu = buffers(b)
    print('mmp_bas: RESPR %d B total (code %d + data %d + race area %d + '
          'bitmap %d + marble %d), all even; mmt_bas + %d save buffer'
          % (total, sz['mmp'], sz['mm_dat'], bu['area'], bu['lin'],
             bu['spr'], TK_SAVE))


if __name__ == '__main__':
    main()
