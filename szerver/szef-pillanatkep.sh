#!/bin/bash
# PromNET Széf — napi pillanatkép hard linkekkel (a restic a fájlokat soha nem írja felül, csak újat ír vagy töröl).
# A /mnt/szef/pillanatkepek a CT134 számára láthatatlan, így egy fertőzött ügyfélgép sem tudja törölni. 30 napot tart meg.
set -euo pipefail
B=/mnt/szef; S=$B/pillanatkepek; KEEP=30
mountpoint -q $B || { echo "$(date -Is) HIBA: a blackbox-megosztás nincs felcsatolva" >&2; exit 1; }
mkdir -p $S; chmod 700 $S
D=$(date +%F); [ -e "$S/$D" ] && exit 0
cp -al $B/tarolo "$S/.$D.tmp" && mv "$S/.$D.tmp" "$S/$D"
ls -1d $S/20??-??-?? | head -n -$KEEP | xargs -r rm -rf
echo "$(date -Is) kész: $D ($(ls -1d $S/20??-??-?? | wc -l) pillanatkép)"
