@echo off
echo ========================================
echo QRSC PC 強制完全削除ツール
echo ========================================
echo.
echo このツールはアンインストール後に残った
echo レジストリエントリを強制削除します。
echo.

REM 管理者権限チェック
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [警告] 管理者権限が推奨されます
    echo        レジストリ削除には管理者権限が必要です
    echo.
    echo 右クリック → 管理者として実行 してください
    echo.
    pause
    exit /b 1
)

echo [OK] 管理者権限で実行中
echo.

echo レジストリから残存エントリを削除中...
echo.

REM 全ての可能なアンインストールエントリを削除
echo 1. メインアンインストールエントリを削除中...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] メインエントリを削除しました
) else (
    echo    [INFO] メインエントリは存在しませんでした
)

echo 2. 代替アンインストールエントリを削除中...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] 代替エントリを削除しました
) else (
    echo    [INFO] 代替エントリは存在しませんでした
)

echo 3. ユーザー固有エントリを削除中...
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] ユーザーエントリを削除しました
) else (
    echo    [INFO] ユーザーエントリは存在しませんでした
)

echo 4. 自動起動設定を削除中...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
echo    [OK] 自動起動設定を削除しました

echo 5. アプリケーション設定を削除中...
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\QRSC PC" /f >nul 2>&1
echo    [OK] アプリケーション設定を削除しました

echo 6. ファイアウォール設定を削除中...
netsh advfirewall firewall delete rule name="QRSC_PC" >nul 2>&1
if %errorLevel__ == 0 (
    echo    [OK] ファイアウォール設定を削除しました
) else (
    echo    [INFO] ファイアウォール設定は存在しませんでした
)

echo 7. 残存ファイルを削除中...
if exist "C:\Program Files\QRSC PC" (
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    echo    [OK] Program Files内のフォルダを削除しました
)

if exist "C:\Program Files (x86)\QRSC PC" (
    rmdir /s /q "C:\Program Files (x86)\QRSC PC" >nul 2>&1
    echo    [OK] Program Files (x86)内のフォルダを削除しました
)

if exist "%LOCALAPPDATA%\QRSC PC" (
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] LocalAppData内のフォルダを削除しました
)

echo 8. ショートカットを削除中...
del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
del "%PUBLIC%\Desktop\QRSC PC.lnk" >nul 2>&1
rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
echo    [OK] ショートカットを削除しました

echo.
echo ========================================
echo 強制完全削除が完了しました！
echo ========================================
echo.
echo 削除された項目:
echo • 全てのレジストリエントリ
echo • アンインストール情報
echo • 自動起動設定
echo • ファイアウォール設定
echo • 残存ファイル・フォルダ
echo • ショートカット
echo.
echo PCを再起動して、「インストールされているアプリ」から
echo QRSC PCが完全に消えていることを確認してください。
echo.
pause
