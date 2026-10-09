# Kódaláírási szabályzat / Code signing policy

**Magyarul.** A PromNET Széf Windows-telepítőjét a GitHub Actions építi automatikusan, közvetlenül ebből a tárolóból
(`.github/workflows/szef-kiadas.yml`, `szef` ág, `szef-v*` címkék). Aláírást csak az így készült, nyilvánosan kiadott
fájlok kapnak. Ingyenes kódaláírás: [SignPath.io](https://about.signpath.io), tanúsítvány: [SignPath Foundation](https://signpath.org).

- Karbantartó és jóváhagyó: Polyák Csaba (PromNET, info@promnet.hu) — minden kiadást ő hagy jóvá.
- A program a felhasználó gépéről csak a kiválasztott mappák **titkosított** mentését küldi a felhasználó által megadott
  szerverre (alapból szef.promnet.hu); más adatot nem gyűjt és nem küld. Adatkezelés: https://promnet.hu/adatkezeles

**English.** Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).
Windows installers are built automatically by GitHub Actions from this repository (`.github/workflows/szef-kiadas.yml`,
branch `szef`, tags `szef-v*`); only those released builds are signed. Maintainer and approver: Csaba Polyák (PromNET).
The program only sends encrypted backups of user-selected folders to the user-configured server (default: szef.promnet.hu);
it collects no other data. Privacy policy: https://promnet.hu/adatkezeles
