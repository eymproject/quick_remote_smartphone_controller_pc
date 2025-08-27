@echo off
echo ========================================
echo QRSC PC 完全削除ツール
echo ========================================
echo.
echo このツールは不完全にインストールされたQRSC PCを
echo 手動で完全削除します。
echo.

REM 管理者権限チェック
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] 管理者権限で実行中
) else (
    echo [警告] 管理者権限が推奨されます
    echo        一部の削除処理で権限が必要な場合があります
)
echo.

echo 削除を開始しますか？
set /p choice="続行する場合は 'y' を入力してください: "
if /i not "%choice%"=="y" (
    echo 削除を中止しました。
    pause
    exit /b 0
)

echo.
echo QRSC PC の完全削除を開始します...
echo.

REM 1. プロセス終了
echo 1. QRSC PC プロセスを終了中...
taskkill /f /im qrsc_pc.exe >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] qrsc_pc.exe を終了しました
) else (
    echo    [INFO] qrsc_pc.exe は実行されていません
)

REM 2. 自動起動設定削除
echo.
echo 2. 自動起動設定を削除中...
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] 自動起動設定を削除しました
) else (
    echo    [INFO] 自動起動設定は存在しませんでした
)

REM 3. インストールフォルダ削除
echo.
echo 3. インストールフォルダを削除中...

REM Program Files内のフォルダ
if exist "C:\Program Files\QRSC PC" (
    echo    Program Files内のフォルダを削除中...
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] C:\Program Files\QRSC PC を削除しました
    ) else (
        echo    [警告] C:\Program Files\QRSC PC の削除に失敗しました
    )
)

REM LocalAppData内のフォルダ
if exist "%LOCALAPPDATA%\QRSC PC" (
    echo    LocalAppData内のフォルダを削除中...
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] %LOCALAPPDATA%\QRSC PC を削除しました
    ) else (
        echo    [警告] %LOCALAPPDATA%\QRSC PC の削除に失敗しました
    )
)

REM AppData内の設定フォルダ
if exist "%APPDATA%\QRSC PC" (
    echo    AppData内のフォルダを削除中...
    rmdir /s /q "%APPDATA%\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] %APPDATA%\QRSC PC を削除しました
    ) else (
        echo    [INFO] %APPDATA%\QRSC PC は存在しませんでした
    )
)

REM 4. スタートメニューショートカット削除
echo.
echo 4. スタートメニューショートカットを削除中...
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" (
    rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] スタートメニューフォルダを削除しました
    ) else (
        echo    [警告] スタートメニューフォルダの削除に失敗しました
    )
) else (
    echo    [INFO] スタートメニューフォルダは存在しませんでした
)

REM 5. デスクトップショートカット削除
echo.
echo 5. デスクトップショートカットを削除中...
if exist "%USERPROFILE%\Desktop\QRSC PC.lnk" (
    del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] デスクトップショートカットを削除しました
    ) else (
        echo    [警告] デスクトップショートカットの削除に失敗しました
    )
) else (
    echo    [INFO] デスクトップショートカットは存在しませんでした
)

REM 6. レジストリエントリ削除
echo.
echo 6. レジストリエントリを削除中...
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
echo    [OK] レジストリエントリを削除しました

REM 7. 一時ファイル削除
echo.
echo 7. 一時ファイルを削除中...
del "%TEMP%\QRSC*.*" /q >nul 2>&1
del "%TEMP%\Setup Log*.txt" /q >nul 2>&1
echo    [OK] 一時ファイルを削除しました

echo.
echo ========================================
echo QRSC PC の完全削除が完了しました！
echo ========================================
echo.
echo 削除された項目:
echo ? アプリケーションファイル
echo ? 設定ファイル
echo ? スタートメニューショートカット
echo ? デスクトップショートカット
echo ? 自動起動設定
echo ? レジストリエントリ
echo ? 一時ファイル
echo.
echo 新しいインストーラでの再インストールが可能です。
echo.
pause
