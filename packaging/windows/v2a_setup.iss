; Inno Setup Script for V2A — Video to Audio Studio v1.2.3
#define MyAppName "V2A"
#define MyAppVersion "1.2.3"
#define MyAppPublisher "margacis2"
#define MyAppURL "https://github.com/margacis2/v2a"
#define MyAppExeName "v2a.exe"
#define MyAppAssocName MyAppName + " Audio File"
#define MyAppAssocExt ".v2a"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; Basic Application Info
AppId={{5D014E4F-F8A2-4D39-953B-3A25C7BE7240}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\..\LICENSE
OutputDir=..\..\dist
OutputBaseFilename=V2A-Setup-1.2.3-x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Flutter Desktop Release Binaries
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Companion bundled FFmpeg binaries (Optional Complete Edition)
; Source: "..\..\bin\ffmpeg.exe"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
; Source: "..\..\bin\ffprobe.exe"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

