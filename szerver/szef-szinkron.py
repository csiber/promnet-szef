#!/usr/bin/env python3
"""PromNET Széf — szinkron a promnet.hu-val (CT134).
  szef-szinkron lista     (percenként) a promnet.hu-ról lekéri az aktív fiókokat → /etc/szef/htpasswd (atomikusan, csak ha változott) + HUP;
                          a véglegesen törlendő azonosítókat a /srv/szef/.torlendo fájlba írja (a Proxmox-hoszt törli az adatukat).
  szef-szinkron jelentes  (naponta) azonosítónként foglalt hely, gépek (altárolók) száma, utolsó írás → promnet.hu; a már törölteket is jelenti.
A kulcs: /etc/szef/promnet-kulcs (a promnet.hu-n csak a SHA-256 lenyomata van, service_keys / szef-szerver)."""
import json, os, re, subprocess, sys, time, urllib.request

API = 'https://promnet.hu/api/internal/szef-szerver'
HTPASSWD = '/etc/szef/htpasswd'
ROOT = '/srv/szef'
AZ_RE = re.compile(r'^sz-[a-z0-9]{6}$')

def kulcs():
    with open('/etc/szef/promnet-kulcs') as f: return f.read().strip()

def hivas(method, body=None):
    req = urllib.request.Request(API, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + kulcs(), 'Content-Type': 'application/json', 'User-Agent': 'promnet-szef-ct134'})
    with urllib.request.urlopen(req, timeout=30) as r: return json.loads(r.read())

def lista():
    d = hivas('GET')
    if not d.get('ok'): raise SystemExit('a promnet.hu hibát adott: %s' % d)
    sorok = sorted(a['htpasswd'] for a in d['accounts'] if AZ_RE.match(a['azonosito']) and a['htpasswd'].startswith(a['azonosito'] + ':{SHA}'))
    uj = '\n'.join(sorok) + ('\n' if sorok else '')
    regi = open(HTPASSWD).read() if os.path.exists(HTPASSWD) else ''
    # Biztonsági fék: ha egy csapásra eltűnne minden belépés, inkább nem írjuk felül (valószínűleg hiba a túloldalon).
    if not sorok and regi.count('\n') >= 3:
        print('FIGYELEM: üres lista jött, a meglévő %d belépést megtartom' % regi.count('\n'), file=sys.stderr)
    elif uj != regi:
        tmp = HTPASSWD + '.uj'
        with open(tmp, 'w') as f: f.write(uj)
        os.chmod(tmp, 0o640); subprocess.run(['chown', 'root:szef', tmp], check=True)
        os.replace(tmp, HTPASSWD)
        subprocess.run(['systemctl', 'kill', '-s', 'HUP', 'promnet-szef'], check=False)
        print('htpasswd frissítve: %d belépés' % len(sorok))
    torl = sorted(a for a in d.get('torlendo', []) if AZ_RE.match(a))
    t = '\n'.join(torl) + ('\n' if torl else '')
    p = os.path.join(ROOT, '.torlendo')
    # a /srv/szef a szef felhasználóé (a CT-root nem lát bele), ezért az olvasás is az ő nevében megy
    regi_t = subprocess.run(['runuser', '-u', 'szef', '--', 'sh', '-c', 'cat %s 2>/dev/null || true' % p], capture_output=True, text=True).stdout
    if regi_t != t:
        subprocess.run(['runuser', '-u', 'szef', '--', 'sh', '-c', 'cat > %s' % p], input=t.encode(), check=True)

def jelentes():
    usage, torolve = [], []
    torlendo = set(open(os.path.join(ROOT, '.torlendo')).read().split()) if os.path.exists(os.path.join(ROOT, '.torlendo')) else set()
    for az in sorted(os.listdir(ROOT)):
        p = os.path.join(ROOT, az)
        if not AZ_RE.match(az) or not os.path.isdir(p): continue
        osszes, utolso, gepek = 0, None, 0
        for gyoker, mappak, fajlok in os.walk(p):
            if 'config' in fajlok and 'keys' in mappak: gepek += 1
            for f in fajlok:
                try:
                    st = os.lstat(os.path.join(gyoker, f)); osszes += st.st_blocks * 512
                    if os.path.basename(gyoker) == 'snapshots' and (utolso is None or st.st_mtime > utolso): utolso = st.st_mtime
                except OSError: pass
        usage.append({'azonosito': az, 'bytes': osszes, 'machines': gepek, 'last_write': int(utolso) if utolso else None})
    for az in torlendo:
        if AZ_RE.match(az) and not os.path.exists(os.path.join(ROOT, az)): torolve.append(az)
    print(json.dumps(hivas('POST', {'usage': usage, 'torolve': torolve})))

if __name__ == '__main__':
    {'lista': lista, 'jelentes': jelentes}[sys.argv[1] if len(sys.argv) > 1 else 'lista']()
