#!/usr/bin/env python3
# Marble Madness for the Sinclair QL
# Copyright (C) 2026 J. McKay
# SPDX-License-Identifier: GPL-3.0-or-later
"""ZX0 compression of blobs with Einar Saukas's zx0 tool (optimal mode), cached by content.

The tool: $ZX0, else tools/ext/zx0/src/zx0 (README.txt, BUILDING FROM SOURCE). On Windows
it is a Linux build run through WSL; elsewhere it is run directly. Results are cached in out/mmdat_cache
by the SHA-1 of the input (each blob takes minutes for 70-90 KB).
"""
import hashlib
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'out' / 'mmdat_cache'


def _wsl(p):
    q = str(p).replace('\\', '/')
    return '/mnt/' + q[0].lower() + q[2:]


def zx0_many(blobs):
    """ZX0 (optimal) of each blob, all at once -> the packed bytes, in order"""
    CACHE.mkdir(parents=True, exist_ok=True)
    exe = Path(os.environ.get('ZX0', ROOT / 'tools' / 'ext' / 'zx0' / 'src' / 'zx0'))
    procs, outs = [], []
    for data in blobs:
        h = hashlib.sha1(data).hexdigest()
        out = CACHE / (h + '.zx0')
        outs.append(out)
        if out.exists() and out.stat().st_size:
            continue
        if not exe.exists():
            sys.exit('zx0pack: the zx0 tool is missing (%s; set ZX0; README.txt, BUILDING FROM SOURCE)' % exe)
        src = CACHE / (h + '.bin')
        src.write_bytes(data)
        if os.name == 'nt':
            cmd = ['wsl', '-e', _wsl(exe), '-f', _wsl(src), _wsl(out)]
        else:
            cmd = [str(exe), '-f', str(src), str(out)]
        procs.append((subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                       stdin=subprocess.DEVNULL), src, out))
    for pr, src, out in procs:
        _, err = pr.communicate()
        if pr.returncode or not out.exists():
            sys.exit('zx0pack: zx0 failed: %s' % err)
        src.unlink()
    return [o.read_bytes() for o in outs]
