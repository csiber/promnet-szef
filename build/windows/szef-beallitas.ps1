# PromNET Széf — első beállítás (a telepítő futtatja, az ügyfél adataival).
# 1) ellenőrzi a Széf-azonosítót és -jelszót a szef.promnet.hu-n,
# 2) generál egy titkosítási jelszót, és létrehozza a tárolót,
# 3) megírja a beállítást (%APPDATA%\backrest\config.json): Dokumentumok, Asztal, Képek, naponta, 30 nap / 8 hét / 12 hónap,
# 4) elkészíti a kinyomtatható helyreállítási lapot az Asztalra.
# Kilépési kódok: 0 kész, 2 hibás azonosító/jelszó, 3 erről a gépről (ugyanezzel a gépnévvel) már van mentés, 4 nincs kapcsolat, 5 már be van állítva, 1 egyéb hiba.
param(
  [Parameter(Mandatory = $true)][string]$AdatFajl,   # ideiglenes JSON {azonosito, jelszo}; elolvasás után töröljük
  [Parameter(Mandatory = $true)][string]$Restic       # a restic.exe útvonala
)
$ErrorActionPreference = 'Stop'
$Szerver = 'szef.promnet.hu'

$adat = Get-Content -Raw -Encoding UTF8 $AdatFajl | ConvertFrom-Json
Remove-Item -Force $AdatFajl
$az = ($adat.azonosito).Trim().ToLower()
$pw = ($adat.jelszo).Trim()
if ($az -notmatch '^[a-z0-9][a-z0-9-]{2,40}$') { exit 2 }

$cfgDir = Join-Path $env:APPDATA 'backrest'
$cfgFile = Join-Path $cfgDir 'config.json'
if (Test-Path $cfgFile) { exit 5 }

# Titkosítási jelszó: 32 karakter, a nem összetéveszthető betűkből (kinyomtatva is jól olvasható).
$abc = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$buf = New-Object byte[] 32; $rng.GetBytes($buf)
$enc = -join ($buf | ForEach-Object { $abc[$_ % $abc.Length] })
$encSzep = ($enc -split '(.{4})' | Where-Object { $_ }) -join '-'

# Gépenként saját altároló (/<azonosító>/<gépnév>/): a Család és Iroda csomag több gépet enged.
$gep = ($env:COMPUTERNAME).ToLower() -replace '[^a-z0-9._-]', '-'
$repo = "rest:https://" + [uri]::EscapeDataString($az) + ":" + [uri]::EscapeDataString($pw) + "@$Szerver/$az/$gep/"

$env:RESTIC_REPOSITORY = $repo
$env:RESTIC_PASSWORD = $enc
# A restic a hibát a stderr-re írja; PowerShell 5.1-ben ez „Stop” mellett kivétel lenne, ezért itt Continue.
$ErrorActionPreference = 'Continue'
$ki = & $Restic init 2>&1 | Out-String
$kod = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item Env:RESTIC_PASSWORD, Env:RESTIC_REPOSITORY
if ($kod -ne 0) {
  if ($ki -match '401|Unauthorized') { exit 2 }
  if ($ki -match 'already (exists|initialized)|config file already') { exit 3 }
  if ($ki -match 'no such host|connection|timeout|dial tcp') { exit 4 }
  Set-Content -Encoding UTF8 (Join-Path $env:TEMP 'promnet-szef-hiba.txt') $ki
  exit 1
}

# A jelzés sablonja (Go-sablon; a Backrest tölti ki eseménykor).
$jelzes = '{"az":"AZ","pw":"PW","gep":"GEP","e":"{{ .EventName .Event }}","err":{{ .JsonMarshal .Error }},"d":"{{ .FormatDuration .Duration }}"}'
$jelzes = $jelzes.Replace('"AZ"', '"' + $az + '"').Replace('"PW"', '"' + $pw + '"').Replace('"GEP"', '"' + $gep + '"')

$utak = @([Environment]::GetFolderPath('MyDocuments'), [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyPictures')) |
  Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$cfg = [ordered]@{
  modno    = 1
  version  = 6
  instance = $gep
  auth     = @{ disabled = $true }   # csak ezen a gépen (127.0.0.1) érhető el
  repos    = @(@{
      id             = 'promnet-szef'
      uri            = $repo
      password       = $enc
      autoUnlock     = $true
      autoInitialize = $true
      prunePolicy    = @{ schedule = @{ maxFrequencyDays = 30; clock = 'CLOCK_LAST_RUN_TIME' }; maxUnusedPercent = 10 }
      # Havi ellenőrzés: a szerkezet mellett az adat 5%-át ténylegesen visszaolvassa és visszafejti (itt, a gépen, a kulccsal).
      checkPolicy    = @{ schedule = @{ maxFrequencyDays = 30; clock = 'CLOCK_LAST_RUN_TIME' }; readDataSubsetPercent = 5 }
      # Jelzés a promnet.hu-nak (Széf Plusz, 2026-10-10): a havi ellenőrzés eredménye és a sikertelen mentés.
      # Csak a Széf-BELÉPÉSI jelszót küldi azonosításra (a szerveren csak a lenyomata van) — a titkosítási jelszót SOHA.
      hooks          = @(@{
          conditions         = @('CONDITION_CHECK_SUCCESS', 'CONDITION_CHECK_ERROR', 'CONDITION_SNAPSHOT_ERROR')
          actionHealthchecks = @{ webhookUrl = 'https://promnet.hu/api/szef/esemeny'; template = $jelzes }
        })
    })
  plans    = @(@{
      id        = 'sajat-mappak'
      repo      = 'promnet-szef'
      paths     = @($utak)
      excludes  = @('*.tmp', '~$*', 'Thumbs.db', 'desktop.ini', '*.lnk')
      schedule  = @{ maxFrequencyHours = 24; clock = 'CLOCK_LAST_RUN_TIME' }
      retention = @{ policyTimeBucketed = @{ daily = 30; weekly = 8; monthly = 12 } }
    })
}
New-Item -ItemType Directory -Force $cfgDir | Out-Null
$json = $cfg | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($cfgFile, $json, (New-Object Text.UTF8Encoding $false))
# A beállítás tartalmazza a titkosítási jelszót: csak a felhasználó olvashassa.
icacls $cfgFile /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null

# Helyreállítási lap az Asztalra.
$datum = Get-Date -Format 'yyyy. MM. dd.'
$mappak = ($utak | ForEach-Object { "<li>$([Net.WebUtility]::HtmlEncode($_))</li>" }) -join ''
$lap = @"
<!doctype html><html lang="hu"><head><meta charset="utf-8"><title>PromNET Széf – helyreállítási lap</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;max-width:720px;margin:32px auto;color:#0a0e14;line-height:1.5}
h1{font-size:26px;margin:0 0 4px}.tri{color:#d97706}.box{border:2px solid #0a0e14;border-radius:8px;padding:16px 20px;margin:18px 0}
.k{font-family:Consolas,monospace;font-size:22px;letter-spacing:.04em;font-weight:700}.m{color:#5a6370;font-size:14px}
button{font-size:16px;padding:10px 16px;margin-top:8px}@media print{button{display:none}}</style></head><body>
<h1><span class="tri">&#9650;</span> PromNET Széf – helyreállítási lap</h1>
<p class="m">Készült: $datum · gép: $gep</p>
<div class="box"><p>Széf-azonosító</p><p class="k">$az</p>
<p>Titkosítási jelszó</p><p class="k">$encSzep</p>
<p class="m">A kötőjelek csak az olvashatóságot segítik, a jelszó részei nem.</p></div>
<p><b>Nyomtasd ki, és tedd el biztos helyre</b> (a géptől külön). Ha a géped tönkremegy vagy ellopják, ezzel a lappal egy új gépen vissza tudjuk hozni a mentéseidet. Nyomtatás után ezt a fájlt törölheted az Asztalról.</p>
<p><b>A titkosítási jelszót mi sem ismerjük.</b> A mentéseid titkosítva kerülnek hozzánk, így senki nem lát beléjük, mi sem. Ha ez a jelszó elveszik, a mentés nem állítható vissza.</p>
<p>Mentett mappák:</p><ul>$mappak</ul>
<p>Naponta egyszer ment; 30 napra, 8 hétre és 12 hónapra visszamenőleg tart meg változatokat.</p>
<p class="m">PromNET · Polyák Csaba e.v. · 06 20 549 4107 · info@promnet.hu · szef.promnet.hu</p>
<button onclick="window.print()">Nyomtatás</button></body></html>
"@
$lapFajl = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PromNET Széf - helyreállítási lap.html'
[IO.File]::WriteAllText($lapFajl, $lap, (New-Object Text.UTF8Encoding $false))
Start-Process $lapFajl
exit 0
