; QRSC PC Safe Installer - No batch execution during install
; Safe version without automatic batch file execution

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
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=QRSC_PC_Setup_Safe
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; システム要件
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 一般ユーザー権限でインストール
PrivilegesRequired=lowest

; 言語設定
ShowLanguageDialog=no

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成(&D)"; GroupDescription: "追加のアイコン:"

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
; スタートメニューショートカット
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\使用方法"; Filename: "{app}\README.txt"; Comment: "使用方法とトラブルシューティング"
Name: "{group}\ファイアウォール設定"; Filename: "{app}\setup_firewall.bat"; Comment: "Windowsファイアウォールを設定 (管理者として実行)"
Name: "{group}\自動起動設定"; Filename: "{app}\install_autostart.bat"; Comment: "Windows起動時の自動起動を設定"
Name: "{group}\自動起動解除"; Filename: "{app}\remove_autostart.bat"; Comment: "自動起動設定を解除"
Name: "{group}\{#MyAppName} アンインストール"; Filename: "{uninstallexe}"; Comment: "{#MyAppName} をアンインストールします"

; デスクトップショートカット
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; インストール完了後にアプリケーションを起動するかの選択のみ
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; アンインストール時に自動起動設定を削除
Filename: "{app}\remove_autostart.bat"; Parameters: ""; WorkingDir: "{app}"; Flags: runhidden waituntilterminated

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
end;

// インストール完了時のメッセージ
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // インストール完了メッセージ
    MsgBox('QRSC PCのインストールが完了しました！' + #13#10 + #13#10 +
           '🚀 次の手順でセットアップを完了してください:' + #13#10 + #13#10 +
           '1️⃣ ファイアウォール設定 (重要!)' + #13#10 +
           '   スタートメニュー → QRSC PC → 「ファイアウォール設定」' + #13#10 +
           '   ※右クリック → 管理者として実行' + #13#10 + #13#10 +
           '2️⃣ 自動起動設定 (オプション)' + #13#10 +
           '   スタートメニュー → QRSC PC → 「自動起動設定」' + #13#10 + #13#10 +
           '3️⃣ アプリケーション起動' + #13#10 +
           '   QRSC PCを起動してサーバーを開始' + #13#10 + #13#10 +
           '4️⃣ スマートフォンから接続' + #13#10 +
           '   QRコードまたは手動でIPアドレスを入力' + #13#10 + #13#10 +
           '📖 詳細な使用方法は「使用方法」ショートカットをご確認ください。', 
           mbInformation, MB_OK);
  end;
end;

// アンインストール前の確認
function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('QRSC PCをアンインストールしますか？' + #13#10 + 
            '自動起動設定も削除されます。', 
            mbConfirmation, MB_YESNO) = IDNO then
    Result := False;
end;

[Messages]
; カスタムメッセージ（日本語）
japanese.BeveledLabel=QRSC PC - スマートフォンでPCを簡単操作
japanese.SetupAppTitle=QRSC PC セットアップ
japanese.SetupWindowTitle=QRSC PC セットアップ
japanese.UninstallAppFullTitle=QRSC PC アンインストール
japanese.SelectDirLabel3=セットアップは [name] を次のフォルダにインストールします。
japanese.SelectDirBrowseLabel=続行するには [次へ] をクリックしてください。別のフォルダを選択する場合は [参照] をクリックしてください。
japanese.DiskSpaceGBLabel=少なくとも [gb] GB の空きディスク領域が必要です。
japanese.ToUninst=アンインストールするには %1 を実行してください。
japanese.ExitSetupMessage=セットアップは完了していません。今すぐ終了しますか？%n%nセットアップを完了するには、後でセットアップを再実行してください。
japanese.AboutSetupNote=
japanese.ClickNext=続行するには [次へ] をクリックしてください。セットアップを終了するには [キャンセル] をクリックしてください。
japanese.WelcomeLabel1=[name] セットアップウィザードへようこそ
japanese.WelcomeLabel2=このプログラムはお使いのコンピュータに [name/ver] をインストールします。%n%n続行する前に、他のすべてのアプリケーションを終了することをお勧めします。
