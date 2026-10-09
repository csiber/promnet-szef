#!/bin/bash
# PromNET Széf — a 30 napja lemondott ügyfelek adatainak végleges törlése (a CT134 írja a listát: /mnt/szef/tarolo/.torlendo).
# A konténer nem tud törölni a megosztásról (a tárolók a szef felhasználóé, a CT-root nem fér hozzájuk), ezért a hoszt teszi.
set -euo pipefail
T=/mnt/szef/tarolo; L=$T/.torlendo
mountpoint -q /mnt/szef || { echo "$(date -Is) HIBA: a megosztás nincs felcsatolva" >&2; exit 1; }
[ -s "$L" ] || exit 0
while read -r az; do
  [[ "$az" =~ ^sz-[a-z0-9]{6}$ ]] || { echo "$(date -Is) kihagyva (hibás név): $az" >&2; continue; }
  [ -d "$T/$az" ] || ls -d /mnt/szef/pillanatkepek/20??-??-??/$az >/dev/null 2>&1 || continue
  rm -rf -- "${T:?}/$az" && echo "$(date -Is) törölve: $az"
  # a napi pillanatképekből is (különben még 30 napig ott maradna)
  for s in /mnt/szef/pillanatkepek/20??-??-??; do if [ -d "$s/$az" ]; then rm -rf -- "${s:?}/$az"; fi; done
done < "$L"
