# PromNET Széf — szerveroldal

A szef.promnet.hu mentőszerver üzemeltetése (Proxmox CT134 + hoszt). A titkok (alagútkulcs, promnet-kulcs) NINCSENEK itt.

- **CT134 `promnet-szef`** (192.168.6.54, VLAN6, helyi háló tiltva): restic rest-server 0.14 `--private-repos`
  (`promnet-szef.service`), Cloudflare-alagút (`szef-tunnel.service`, kulcs: /etc/cloudflared/token).
- **`szef-szinkron.py`** (CT134 /usr/local/sbin/szef-szinkron): `lista` percenként (a promnet.hu-ról → htpasswd + HUP,
  törlendők → /srv/szef/.torlendo), `jelentes` naponta 04:23 (foglalt hely, gépek, utolsó mentés → promnet.hu).
  Kulcs: /etc/szef/promnet-kulcs (a promnet.hu-n csak a SHA-256 lenyomata: service_keys, scope `szef-szerver`).
- **Belső fiókok** (saját, nem fizetős): `/etc/szef/htpasswd.belso`, csak `belso-…` nevek. A szinkron mindig hozzáfűzi őket
  a htpasswd-hez; a jelentés és a törlés nem nyúl hozzájuk. Jelenleg: `belso-aika` — az Aika-infrastruktúra napi mentése
  (Proxmox-hoszt `/usr/local/sbin/aika-szef-mentes`, cron 02:40; titkok `/root/.config/aika-szef/`, másolatuk a Vaultban).
- **`szef-ugyfel.sh`**: kézi felvétel (tesztre) — a percenkénti szinkron felülírja!
- **Hoszt:** `szef-pillanatkep.sh` 03:30 (hard linkes napi pillanatkép, 30 nap, a CT nem látja), `szef-torles.sh` 03:10
  (a 30 napja lemondott ügyfelek adata a tárolóból és a pillanatképekből).
- **Tárhely:** blackbox Synology `/volume1/PromNET_Szef` (NFS) → hoszt /mnt/szef (fstab, az üres mappa chattr +i) → CT /srv/szef.
- Rendszerfájlok pillanatképe: `rendszer-beallitasok.txt`.
