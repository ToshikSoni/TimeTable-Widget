; Inno Setup 6 script for Cadence.
;
; Build from the repository root after `flutter build windows --release`:
;
;   iscc /DAppVersion=1.2.0 ^
;        /DSourceDir=%CD%\build\windows\x64\runner\Release ^
;        /DOutputBaseFilename=Cadence-1.2.0-windows-x64-setup ^
;        /O%CD%\dist ^
;        packaging\windows\cadence.iss

#define AppName "Cadence"
#define AppExeName "cadence.exe"
#define AppPublisher "Toshik Soni"
#define AppURL "https://github.com/ToshikSoni/TimeTable-Widget"
#define RepoRoot AddBackslash(SourcePath) + "..\.."

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir RepoRoot + "\build\windows\x64\runner\Release"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "Cadence-" + AppVersion + "-windows-x64-setup"
#endif

; VersionInfoVersion only accepts numbers, so drop any pre-release suffix.
#if Pos("-", AppVersion) > 0
  #define NumericVersion Copy(AppVersion, 1, Pos("-", AppVersion) - 1)
#else
  #define NumericVersion AppVersion
#endif

; The app writes the same value when "Start on sign-in" is toggled in Settings.
#define RunKey "Software\Microsoft\Windows\CurrentVersion\Run"
#define RunValueName "Cadence"

[Setup]
; Never change this GUID: it ties upgrades and uninstalls to existing installs.
AppId={{63411D22-614A-4F97-B902-85788E0674C3}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
VersionInfoVersion={#NumericVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#RepoRoot}\LICENSE
SetupIconFile={#RepoRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
OutputBaseFilename={#OutputBaseFilename}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Start Cadence when I sign in"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "{#RunKey}"; ValueType: string; ValueName: "{#RunValueName}"; ValueData: """{app}\{#AppExeName}"" --hidden"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  { The app can add this value itself, so remove it even if setup didn't. }
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKEY_CURRENT_USER, '{#RunKey}', '{#RunValueName}');
end;
