; QRSC PC Minimal Test Installer
; Test version for troubleshooting

#define MyAppName "QRSC PC"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "EYM Project"
#define MyAppURL "https://github.com/eymproject/quick_remote_smartphone_controller_pc"
#define MyAppExeName "qrsc_pc.exe"
#define MyAppDescription "Quick Remote Smartphone Controller for PC"

[Setup]
; アプリケーション基本情報
AppId={{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright=Copyright (C) 2025 {#MyAppPublisher}

; インストール設定
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=QRSC_PC_Setup_Test
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; アイコン設定
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; システム要件
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 管理者権限でインストール（ファイアウォール設定のため）
PrivilegesRequired=admin

; 言語設定
ShowLanguageDialog=no

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成(&D)"; GroupDescription: "追加のアイコン:"
Name: "autostart"; Description: "Windows起動時に自動起動する(&A)"; GroupDescription: "追加設定:"; Flags: unchecked

[Files]
; メイン実行ファイル
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLファイル
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; データファイル
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; スタートメニューショートカット（作業ディレクトリを明示的に指定）
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppDescription}"

; デスクトップショートカット（作業ディレクトリを明示的に指定）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; ファイアウォール設定（管理者権限で自動実行）
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""QRSC_PC"""; Flags: runhidden waituntilterminated; StatusMsg: "既存のファイアウォール設定をクリーンアップ中..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""QRSC_PC"" dir=in action=allow protocol=TCP localport=8080 profile=any"; Flags: runhidden waituntilterminated; StatusMsg: "ファイアウォール設定を追加中..."

; 自動起動設定（オプション）
Filename: "reg"; Parameters: "add ""HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"" /v ""QRSC PC"" /t REG_SZ /d ""\""{app}\{#MyAppExeName}\"""" /f"; Flags: runhidden waituntilterminated; Tasks: autostart; StatusMsg: "自動起動設定を追加中..."

[Code]
// 管理者権限の厳格なチェック
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // 管理者権限の厳格なチェック（最優先）
  if not IsAdminLoggedOn then
  begin
    MsgBox('⚠️ 管理者権限が必要です' + #13#10 + #13#10 +
           'このインストーラーは管理者権限で実行する必要があります。' + #13#10 + #13#10 +
           '解決方法:' + #13#10 +
           '1. インストーラーを右クリック' + #13#10 +
           '2. 「管理者として実行」を選択' + #13#10 +
           '3. UAC（ユーザーアカウント制御）で「はい」をクリック' + #13#10 + #13#10 +
           '管理者権限が必要な理由:' + #13#10 +
           '• ファイアウォール設定の自動構成' + #13#10 +
           '• Program Filesへのインストール' + #13#10 +
           '• システム設定の変更', 
           mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Windows 10以降かチェック
  if not IsWin64 then
  begin
    MsgBox('このアプリケーションはWindows 10/11 (64bit) が必要です。', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // 管理者権限確認完了メッセージ
  Log('管理者権限での実行を確認しました。');
end;

[Messages]
; カスタムメッセージ（日本語）
japanese.BeveledLabel=QRSC PC - スマートフォンでPCを簡単操作
japanese.SetupAppTitle=QRSC PC セットアップ
japanese.SetupWindowTitle=QRSC PC セットアップ
japanese.UninstallAppFullTitle=QRSC PC アンインストール
