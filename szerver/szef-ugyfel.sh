#!/bin/bash
# szef-ugyfel <azonosito>   — új PromNET Széf ügyfél (vagy jelszócsere); a jelszót a stdin-ről olvassa
# szef-ugyfel --torol <azonosito> — hozzáférés megszüntetése (az adatok maradnak, kézzel törlendők)
set -euo pipefail
F=/etc/szef/htpasswd
if [ "${1:-}" = --torol ]; then htpasswd -D "$F" "$2"; else
  [[ "${1:-}" =~ ^[a-z0-9][a-z0-9-]{2,40}$ ]] || { echo "azonosito: kisbetu, szam, kotojel" >&2; exit 2; }
  read -r PW; [ ${#PW} -ge 16 ] || { echo "a jelszo legalabb 16 karakter" >&2; exit 2; }
  htpasswd -iB "$F" "$1" <<< "$PW" 2>/dev/null
fi
systemctl kill -s HUP promnet-szef
echo kesz
