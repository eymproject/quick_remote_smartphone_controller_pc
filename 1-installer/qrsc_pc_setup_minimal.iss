; QRSC PC Minimal Installer - Troubleshooting Version
; Simple installer to identify issues

#define MyAppName "QRSC PC"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "EYM Project"
#define MyAppExeName "qrsc_pc.exe"

[Setup]
; Basic application info
AppId={{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

; Installation settings
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=QRSC_PC_Setup_Minimal
Compression=lzma
SolidCompression=yes

; System requirements
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; No admin privileges required
PrivilegesRequired=lowest

[Files]
; Main executable only
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Essential DLL files
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start menu shortcut only
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
; Launch application after install
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
