; QRSC PC (Quick Remote Smartphone Controller PC) Inno Setup Script
; QRSC - スマートフォンからPCを遠隔操作するアプリケーション

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
LicenseFile=LICENSE.txt
InfoBeforeFile=README_INSTALLER.md
OutputDir=Output
OutputBaseFilename=QRSC_PC_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; システム要件
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 権限設定（ファイアウォール設定のため管理者権限が必要）
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; 言語設定
ShowLanguageDialog=no

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成(&D)"; GroupDescription: "追加のアイコン:"
Name: "firewall"; Description: "Windowsファイアウォールを自動設定 (推奨)"; GroupDescription: "システム設定:"

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

; ライセンスファイル
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; スタートメニューショートカット
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\{#MyAppName} アンインストール"; Filename: "{uninstallexe}"; Comment: "{#MyAppName} をアンインストールします"
Name: "{group}\使用方法"; Filename: "{app}\README.txt"; Comment: "使用方法とトラブルシューティング"

; デスクトップショートカット
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; インストール完了後にアプリケーションを起動するかの選択
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; アンインストール時にファイアウォール設定を削除
Filename: "{app}\remove_firewall.bat"; Parameters: ""; WorkingDir: "{app}"; Flags: runhidden waituntilterminated

[UninstallDelete]
; アンインストール時に設定ファイルも削除
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"

[Code]
// カスタムメッセージとエラーハンドリング
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Windows 10以降かチェック
  if not IsWin64 then
  begin
    MsgBox('このアプリケーションはWindows 10/11 (64bit) が必要です。', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // .NET Framework 4.8以降の確認（必要に応じて）
  // if not IsDotNetInstalled(net48, 0) then
  // begin
  //   MsgBox('.NET Framework 4.8以降が必要です。', mbError, MB_OK);
  //   Result := False;
  //   Exit;
  // end;
end;

// インストール完了時のメッセージ
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // インストール完了メッセージ
    MsgBox('QRSC PCのインストールが完了しました。' + #13#10 + #13#10 +
           '使用方法:' + #13#10 +
           '1. QRSC PCを起動してください' + #13#10 +
           '2. スマートフォンのQRSCアプリから接続してください' + #13#10 +
           '3. 詳細な使用方法は「使用方法」ショートカットをご確認ください', 
           mbInformation, MB_OK);
  end;
end;

// アンインストール前の確認
function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('QRSC PCをアンインストールしますか？' + #13#10 + 
            'ファイアウォール設定も削除されます。', 
            mbConfirmation, MB_YESNO) = IDNO then
    Result := False;
end;

[Messages]
; カスタムメッセージ（日本語）
japanese.BeveledLabel=QRSC PC - スマートフォンでPCを簡単操作
japanese.SetupAppTitle=QRSC PC セットアップ
japanese.SetupWindowTitle=QRSC PC セットアップ
japanese.UninstallAppFullTitle=QRSC PC アンインストール
