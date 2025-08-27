; QRSC PC Phase 2 Installer - Enhanced Version
; Adding firewall setup shortcut and Japanese documents

#define MyAppName "QRSC PC"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "EYM Project"
#define MyAppExeName "qrsc_pc.exe"
#define MyAppDescription "Quick Remote Smartphone Controller for PC"

[Setup]
; Basic application info
AppId={{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2025 {#MyAppPublisher}

; Installation settings
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=QRSC_PC_Setup_Phase2
Compression=lzma
SolidCompression=yes

; System requirements
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; No admin privileges required
PrivilegesRequired=lowest

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; Main executable
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All DLL files
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Batch files for manual execution
Source: "..\build\windows\x64\runner\Release\*.bat"; DestDir: "{app}"; Flags: ignoreversion

; Japanese documentation files
Source: "..\README.md"; DestDir: "{app}"; DestName: "README.txt"; Flags: ignoreversion
Source: "..\アプリ起動方法.md"; DestDir: "{app}"; DestName: "アプリ起動方法.txt"; Flags: ignoreversion
Source: "..\簡単接続手順.md"; DestDir: "{app}"; DestName: "簡単接続手順.txt"; Flags: ignoreversion
Source: "..\スマホ連携設定.md"; DestDir: "{app}"; DestName: "スマホ連携設定.txt"; Flags: ignoreversion

[Icons]
; Start menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\使用方法"; Filename: "{app}\README.txt"; Comment: "使用方法とトラブルシューティング"
Name: "{group}\ファイアウォール設定"; Filename: "{app}\setup_firewall.bat"; Comment: "Windowsファイアウォールを設定 (管理者として実行してください)"
Name: "{group}\{#MyAppName} アンインストール"; Filename: "{uninstallexe}"; Comment: "{#MyAppName} をアンインストールします"

; Desktop shortcut (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; Launch application after install
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// Installation completion message
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('QRSC PCのインストールが完了しました。' + #13#10 + #13#10 +
           '重要: アプリを使用する前に以下を実行してください:' + #13#10 +
           '1. スタートメニューから「ファイアウォール設定」を管理者として実行' + #13#10 +
           '2. QRSC PCを起動してサーバーを開始' + #13#10 +
           '3. スマートフォンから接続テスト' + #13#10 + #13#10 +
           '詳細な使用方法は「使用方法」ショートカットをご確認ください。', 
           mbInformation, MB_OK);
  end;
end;
