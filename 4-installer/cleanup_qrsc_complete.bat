@echo off
echo ========================================
echo QRSC PC 強制完全削除ツール
echo ========================================
echo.
echo このツールはQRSC PCを強制的に完全削除します。
echo 全ての可能な場所から削除を試行します。
echo.

REM 管理者権限チェック
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] 管理者権限で実行中
) else (
    echo [警告] 管理者権限が推奨されます
)
echo.

echo 強制削除を開始しますか？
set /p choice="続行する場合は 'y' を入力してください: "
if /i not "%choice%"=="y" (
    echo 削除を中止しました。
    pause
    exit /b 0
)

echo.
echo QRSC PC の強制完全削除を開始します...
echo.

REM 1. 全てのQRSC関連プロセス終了
echo 1. 全てのQRSC関連プロセスを終了中...
taskkill /f /im qrsc_pc.exe >nul 2>&1
taskkill /f /im "QRSC PC.exe" >nul 2>&1
taskkill /f /im flutter_windows.exe >nul 2>&1
echo    [OK] プロセス終了完了

REM 2. 全ての可能なインストールフォルダを削除
echo.
echo 2. 全てのインストールフォルダを削除中...

REM Program Files (x86)
if exist "C:\Program Files (x86)\QRSC PC" (
    echo    Program Files (x86) 内のフォルダを削除中...
    rmdir /s /q "C:\Program Files (x86)\QRSC PC" >nul 2>&1
    echo    [OK] C:\Program Files (x86)\QRSC PC を削除
)

REM Program Files
if exist "C:\Program Files\QRSC PC" (
    echo    Program Files内のフォルダを削除中...
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    echo    [OK] C:\Program Files\QRSC PC を削除
)

REM LocalAppData
if exist "%LOCALAPPDATA%\QRSC PC" (
    echo    LocalAppData内のフォルダを削除中...
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] %LOCALAPPDATA%\QRSC PC を削除
)

REM AppData\Roaming
if exist "%APPDATA%\QRSC PC" (
    echo    AppData\Roaming内のフォルダを削除中...
    rmdir /s /q "%APPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] %APPDATA%\QRSC PC を削除
)

REM AppData\Local\Programs
if exist "%LOCALAPPDATA%\Programs\QRSC PC" (
    echo    LocalAppData\Programs内のフォルダを削除中...
    rmdir /s /q "%LOCALAPPDATA%\Programs\QRSC PC" >nul 2>&1
    echo    [OK] %LOCALAPPDATA%\Programs\QRSC PC を削除
)

REM 3. 全てのレジストリエントリを削除
echo.
echo 3. 全てのレジストリエントリを削除中...

REM 自動起動設定
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1

REM アンインストール情報（複数のパターンを試行）
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1

REM アプリケーション設定
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\QRSC PC" /f >nul 2>&1

REM Windows Installer関連
for /f "tokens=1" %%i in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /k /f "QRSC" 2^>nul ^| findstr /i "HKEY"') do (
    echo    レジストリキー %%i を削除中...
    reg delete "%%i" /f >nul 2>&1
)

echo    [OK] レジストリエントリ削除完了

REM 4. 全てのショートカットを削除
echo.
echo 4. 全てのショートカットを削除中...

REM デスクトップ
del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
del "%PUBLIC%\Desktop\QRSC PC.lnk" >nul 2>&1

REM スタートメニュー
rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC.lnk" >nul 2>&1
del "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC.lnk" >nul 2>&1

echo    [OK] ショートカット削除完了

REM 5. 一時ファイルとキャッシュを削除
echo.
echo 5. 一時ファイルとキャッシュを削除中...
del "%TEMP%\QRSC*.*" /q >nul 2>&1
del "%TEMP%\Setup Log*.txt" /q >nul 2>&1
del "%TEMP%\is-*.tmp" /q >nul 2>&1
rmdir /s /q "%TEMP%\QRSC PC" >nul 2>&1
echo    [OK] 一時ファイル削除完了

REM 6. Windows Installerキャッシュをクリア
echo.
echo 6. Windows Installerキャッシュをクリア中...
for /d %%i in ("%WINDIR%\Installer\{*}") do (
    if exist "%%i\QRSC*" (
        rmdir /s /q "%%i" >nul 2>&1
    )
)
echo    [OK] Installerキャッシュクリア完了

echo.
echo ========================================
echo QRSC PC の強制完全削除が完了しました！
echo ========================================
echo.
echo 削除処理を実行した項目:
echo • 全てのプロセス終了
echo • 全ての可能なインストールフォルダ
echo • 全てのレジストリエントリ
echo • 全てのショートカット
echo • 一時ファイルとキャッシュ
echo • Windows Installerキャッシュ
echo.
echo システムを再起動することを推奨します。
echo 再起動後、新しいインストーラでの再インストールが可能です。
echo.
pause
