; The Tether Windows installer, built by tools/release/build-windows.ps1 with
; Inno Setup (ISCC /DAppVersion=0.18.0 deploy\windows\tether.iss).
;
; It installs for the current user, into the same folder install-app.ps1
; used, so installing it over an existing copy upgrades that copy in place.
; The updater in the app (WinSparkle) downloads this file from the GitHub
; release, checks its signature and runs it with /SILENT, which closes the
; running app, replaces the files and starts the app again.

#ifndef AppVersion
  #error Pass /DAppVersion=X.Y.Z
#endif

[Setup]
AppId={{B7C4F0A2-6E1D-4B7B-9C1A-5D2E8F3A7C10}
AppName=Tether
AppVersion={#AppVersion}
AppPublisher=dev.tether
DefaultDirName={localappdata}\Programs\Tether
DefaultGroupName=Tether
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\..\dist\{#AppVersion}
OutputBaseFilename=Tether-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\tether.exe
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "A shortcut on the desktop"

[Files]
Source: "..\..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Tether"; Filename: "{app}\tether.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Tether"; Filename: "{app}\tether.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Not skipped when silent: an update restarts the app.
Filename: "{app}\tether.exe"; Description: "Start Tether"; Flags: nowait postinstall
