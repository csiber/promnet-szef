; PromNET Széf — Windows-telepítő (Inno Setup 6). Csak a felhasználó saját fiókjába telepít, rendszergazdai jog nélkül.
; Fordítás:  ISCC.exe /DSzefVer=1.14.1-szef1 szef.iss   (a mappában: promnet-szef.exe, restic.exe, icon.ico, LICENSE, szef-beallitas.ps1)
; A Backrest (GPL-3.0, Gareth George) alapján — a módosított forrás: https://github.com/csiber/promnet-szef
#define N "PromNET Széf"
#define Exe "promnet-szef.exe"
#ifndef SzefVer
  #define SzefVer "0.0.0-dev"
#endif

[Setup]
AppId={{D2C120E0-F0C1-493A-8D2E-EE1DD8B8351C}
AppName={#N}
AppVersion={#SzefVer}
AppVerName={#N} {#SzefVer}
AppPublisher=Polyák Csaba e.v. (PromNET)
AppPublisherURL=https://szef.promnet.hu
AppSupportURL=https://szef.promnet.hu
AppContact=info@promnet.hu
DefaultDirName={localappdata}\Programs\PromNET Szef
DefaultGroupName={#N}
DisableProgramGroupPage=yes
DisableDirPage=yes
UninstallDisplayIcon={app}\icon.ico
UninstallDisplayName={#N}
SetupIconFile=icon.ico
OutputBaseFilename=PromNET-Szef-telepito
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
CloseApplications=no
RestartApplications=no
WizardStyle=modern
SetupLogging=yes

[Languages]
Name: "hu"; MessagesFile: "compiler:Languages\Hungarian.isl"

[Files]
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion; BeforeInstall: SzefLeallitasa
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Exe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "restic.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "szef-beallitas.ps1"; Flags: dontcopy

[Icons]
Name: "{userstartup}\{#N}"; Filename: "{app}\{#Exe}"; Parameters: "--windows-tray"; IconFilename: "{app}\icon.ico"
Name: "{group}\{#N}"; Filename: "{app}\{#Exe}"; Parameters: "--windows-tray"; IconFilename: "{app}\icon.ico"
Name: "{group}\{#N} – mentések áttekintése"; Filename: "http://localhost:9898/"; IconFilename: "{app}\icon.ico"

[Run]
Filename: "{app}\{#Exe}"; Parameters: "--windows-tray"; Description: "A PromNET Széf indítása (a tálcán fut)"; Flags: postinstall nowait

[UninstallDelete]
Type: files; Name: "{app}\restic*.exe"
Type: files; Name: "{app}\install.lock"
Type: dirifempty; Name: "{app}"

[Code]
var
  AdatOldal: TInputQueryWizardPage;
  MarBeallitva: Boolean;

procedure SzefLeallitasa();
var Kod: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C taskkill /FI "USERNAME eq %USERNAME%" /IM "{#Exe}" /F', '', SW_HIDE, ewWaitUntilTerminated, Kod);
end;

procedure InitializeWizard();
begin
  MarBeallitva := FileExists(ExpandConstant('{userappdata}\backrest\config.json'));
  AdatOldal := CreateInputQueryPage(wpWelcome,
    'A Széfed adatai',
    'Ezeket a PromNET-fiókodban, a Széf oldalán találod (vagy a szerviztől kaptad).',
    'A telepítő ellenőrzi őket, létrehozza a titkosított tárolódat, és a végén ad egy kinyomtatható helyreállítási lapot.');
  AdatOldal.Add('Széf-azonosító:', False);
  AdatOldal.Add('Széf-jelszó:', True);
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  // Frissítésnél / újratelepítésnél a meglévő beállítás marad, nem kérünk újra adatot.
  Result := (PageID = AdatOldal.ID) and MarBeallitva;
end;

// Csendes telepítés (szervizben): PromNET-Szef-telepito.exe /VERYSILENT /AZONOSITO=xyz /JELSZO=...
// Ha nincs megadva és még nincs beállítás, csak a program kerül fel; a Széfet ilyenkor kézzel kell beállítani.
function CsendesAdatok(): Boolean;
begin
  Result := (ExpandConstant('{param:AZONOSITO|}') <> '') and (ExpandConstant('{param:JELSZO|}') <> '');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Adat, Ps1, Restic, Uzenet: String;
  Kod: Integer;
begin
  Result := True;
  if CurPageID <> AdatOldal.ID then exit;
  if WizardSilent then
  begin
    if MarBeallitva or not CsendesAdatok() then exit;
    AdatOldal.Values[0] := ExpandConstant('{param:AZONOSITO|}');
    AdatOldal.Values[1] := ExpandConstant('{param:JELSZO|}');
  end;
  if (Trim(AdatOldal.Values[0]) = '') or (Trim(AdatOldal.Values[1]) = '') then
  begin
    MsgBox('Add meg a Széf-azonosítót és a Széf-jelszót.', mbError, MB_OK);
    Result := False; exit;
  end;
  ExtractTemporaryFile('szef-beallitas.ps1');
  ExtractTemporaryFile('restic.exe');
  Ps1 := ExpandConstant('{tmp}\szef-beallitas.ps1');
  Restic := ExpandConstant('{tmp}\restic.exe');
  Adat := ExpandConstant('{tmp}\szef-adat.json');
  // Az adat ideiglenes fájlban megy át (nem parancssorban), a szkript elolvasás után törli.
  SaveStringToFile(Adat, '{"azonosito":"' + Trim(AdatOldal.Values[0]) + '","jelszo":"' + Trim(AdatOldal.Values[1]) + '"}', False);
  WizardForm.NextButton.Enabled := False;
  try
    Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -File "' + Ps1 + '" -AdatFajl "' + Adat + '" -Restic "' + Restic + '"',
      '', SW_HIDE, ewWaitUntilTerminated, Kod);
  finally
    WizardForm.NextButton.Enabled := True;
    DeleteFile(Adat);
  end;
  case Kod of
    0: exit;
    5: begin MarBeallitva := True; exit; end;
    2: Uzenet := 'A Széf-azonosító vagy a Széf-jelszó nem jó. Ellenőrizd, és próbáld újra.';
    3: Uzenet := 'Erről a gépről már van mentés a Széfben (egy korábbi telepítésből). A folytatáshoz a régi helyreállítási lapon lévő titkosítási jelszó kell — hívj, és segítünk: 06 20 549 4107.';
    4: Uzenet := 'Nem sikerült elérni a szef.promnet.hu-t. Nézd meg, van-e internet, és próbáld újra.';
  else
    Uzenet := 'Váratlan hiba történt a beállításnál. A részletek: %TEMP%\promnet-szef-hiba.txt. Hívj, és segítünk: 06 20 549 4107.';
  end;
  MsgBox(Uzenet, mbError, MB_OK);
  if WizardSilent then Abort;
  Result := False;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Beall: String;
begin
  Beall := ExpandConstant('{userappdata}\backrest');
  case CurUninstallStep of
    usUninstall: SzefLeallitasa();
    usDone:
      if MsgBox('Töröljem a PromNET Széf beállításait is erről a gépről?' + #13#10 + Beall + #13#10#13#10 +
        'A mentéseid a Széfben megmaradnak. A visszaállításhoz a helyreállítási lapra lesz szükség.',
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
        DelTree(Beall, True, True, True);
  end;
end;
