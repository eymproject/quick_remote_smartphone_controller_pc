; QRSC PC Complete Installer with App Icon
; Final version with integrated batch processing and app icon

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
OutputBaseFilename=QRSC_PC_Setup
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

; 設定用バッチファイル
Source: "..\build\windows\x64\runner\Release\*.bat"; DestDir: "{app}"; Flags: ignoreversion

; ドキュメントファイル
Source: "..\README.md"; DestDir: "{app}"; DestName: "README.txt"; Flags: ignoreversion
Source: "..\アプリ起動方法.md"; DestDir: "{app}"; DestName: "アプリ起動方法.txt"; Flags: ignoreversion
Source: "..\簡単接続手順.md"; DestDir: "{app}"; DestName: "簡単接続手順.txt"; Flags: ignoreversion
Source: "..\スマホ連携設定.md"; DestDir: "{app}"; DestName: "スマホ連携設定.txt"; Flags: ignoreversion

[Icons]
; スタートメニューショートカット（作業ディレクトリを明示的に指定）
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppDescription}"
Name: "{group}\使用方法"; Filename: "{app}\README.txt"; Comment: "使用方法とトラブルシューティング"
Name: "{group}\ファイアウォール設定"; Filename: "{app}\setup_firewall.bat"; WorkingDir: "{app}"; Comment: "Windowsファイアウォールを設定 (管理者として実行)"
Name: "{group}\自動起動設定"; Filename: "{app}\install_autostart.bat"; WorkingDir: "{app}"; Comment: "Windows起動時の自動起動を設定"
Name: "{group}\自動起動解除"; Filename: "{app}\remove_autostart.bat"; WorkingDir: "{app}"; Comment: "自動起動設定を解除"
Name: "{group}\{#MyAppName} アンインストール"; Filename: "{uninstallexe}"; Comment: "{#MyAppName} をアンインストールします"

; デスクトップショートカット（作業ディレクトリを明示的に指定）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; ファイアウォール設定（管理者権限で自動実行）
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""QRSC_PC"""; Flags: runhidden waituntilterminated; StatusMsg: "既存のファイアウォール設定をクリーンアップ中..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""QRSC_PC"" dir=in action=allow protocol=TCP localport=8080 profile=any"; Flags: runhidden waituntilterminated; StatusMsg: "ファイアウォール設定を追加中..."

; 自動起動設定（オプション）
Filename: "reg"; Parameters: "add ""HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"" /v ""QRSC PC"" /t REG_SZ /d ""\""{app}\{#MyAppExeName}\"""" /f"; Flags: runhidden waituntilterminated; Tasks: autostart; StatusMsg: "自動起動設定を追加中..."

; インストール完了後にアプリケーションを起動するかの選択（作業ディレクトリを指定）
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent unchecked

[UninstallRun]
; アンインストール時にファイアウォール設定を削除
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""QRSC_PC"""; Flags: runhidden waituntilterminated skipifdoesntexist
; アンインストール時に自動起動設定を削除
Filename: "reg"; Parameters: "delete ""HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"" /v ""QRSC PC"" /f"; Flags: runhidden waituntilterminated skipifdoesntexist

[UninstallDelete]
; アンインストール時に設定ファイルも削除
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: files; Name: "{app}\*.log"
Type: files; Name: "{app}\*.tmp"

[Code]
// カスタムメッセージとエラーハンドリング
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

// インストール完了時のメッセージ
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // インストール完了メッセージ
    MsgBox('QRSC PCのインストールが完了しました！' + #13#10 + #13#10 +
           '✅ 自動設定完了:' + #13#10 +
           '• ファイアウォール設定（ポート8080許可）' + #13#10 +
           '• 自動起動設定（選択した場合）' + #13#10 + #13#10 +
           '🚀 すぐに使用開始できます:' + #13#10 + #13#10 +
           '1️⃣ アプリケーション起動' + #13#10 +
           '   QRSC PCを起動してサーバーを開始' + #13#10 + #13#10 +
           '2️⃣ スマートフォンから接続' + #13#10 +
           '   QRコードをスキャンまたは手動でIPアドレスを入力' + #13#10 + #13#10 +
           '📱 接続手順:' + #13#10 +
           '• PCでQRSC PCを起動' + #13#10 +
           '• スマホでQRコードをスキャン' + #13#10 +
           '• 接続完了！PCをスマホで操作可能' + #13#10 + #13#10 +
           '📖 詳細な使用方法は「使用方法」ショートカットをご確認ください。', 
           mbInformation, MB_OK);
  end;
end;

// アンインストール前の確認
function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('QRSC PCをアンインストールしますか？' + #13#10 + #13#10 +
            '以下の項目が削除されます:' + #13#10 +
            '• アプリケーションファイル' + #13#10 +
            '• スタートメニューのショートカット' + #13#10 +
            '• デスクトップショートカット' + #13#10 +
            '• 自動起動設定' + #13#10 +
            '• ファイアウォール設定' + #13#10 +
            '• 設定ファイル', 
            mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDNO then
    Result := False;
end;

// アンインストール完了時のメッセージ
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    MsgBox('QRSC PCのアンインストールが完了しました。' + #13#10 + #13#10 +
           'ご利用いただき、ありがとうございました。', 
           mbInformation, MB_OK);
  end;
end;

[Messages]
; カスタムメッセージ（日本語）
japanese.BeveledLabel=QRSC PC - スマートフォンでPCを簡単操作
japanese.SetupAppTitle=QRSC PC セットアップ
japanese.SetupWindowTitle=QRSC PC セットアップ
japanese.UninstallAppFullTitle=QRSC PC アンインストール
