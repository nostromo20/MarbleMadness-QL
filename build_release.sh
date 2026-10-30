#!/bin/bash
# Marble Madness for the Sinclair QL
# Copyright (C) 2026 J. McKay
# SPDX-License-Identifier: GPL-3.0-or-later
# build_release.sh - Marble Madness QL: the release from data/ alone
#
#   ./build_release.sh
#
# Builds the release (build_rel/mm, build_rel/release/mm.mdv and the files for a host
# folder in build_rel/release/win/) from the source and the generated data committed in
# data/: no original game data or Atari ST files needed. data/ holds the generated data
# of a full development build.
#
# Needs: vasmm68k_mot (VASM=...), Python 3 (PY=...), and Einar Saukas's zx0 compressor
# (ZX0=..., default tools/ext/zx0/src/zx0; on Windows a Linux build run through WSL).
# VASM and PY default to vasmm68k_mot and python3 (else python) from the PATH.
set -u
cd "$(dirname "$0")"
VASM=${VASM:-vasmm68k_mot}
if [ -z "${PY:-}" ]; then
    PY=python3
    python3 -c '' >/dev/null 2>&1 || PY=python    # (Windows: python3 may be the Store stub)
fi
export VASM
B=build_rel
rm -rf "$B"
mkdir -p "$B"
cp data/* "$B"/

echo "=== assembling the release build (-DRELB=1) -> $B/mmr ==="
LOG=$( cd "$B" && "$VASM" -Fbin -m68000 -DRELB=1 -I. -I../src -L proto_r.lst -o mmr ../src/proto.asm 2>&1 )
echo "$LOG" | grep -iE 'error|warning|bytes'
if echo "$LOG" | grep -qiE '(^|\s)(error|fatal|warning)'; then
    echo "*** release assembly FAILED (a warning counts)"; exit 1
fi
[ -f "$B/mmr" ] || { echo "*** no release binary"; exit 1; }

echo "=== the release job: $B/mm + $B/release/mm.mdv ==="
"$PY" tools/mk_release.py "$B" || exit 1
echo "release: $B/release/mm.mdv, $B/release/win/"
