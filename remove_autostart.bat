@echo off
chcp 65001 >nul
title EYM Agent 自動起動削除

echo.
echo ========================================
echo   EYM Agent 自動起動削除
echo ========================================
echo.
echo このツールはEYM Agentの自動起動設定を削除します。
echo アンインストール時やトラブルシューティング時に使用してください。
echo.
echo 削除内容:
echo - Windows起動時の自動起動設定
echo - レジストリエントリ: "EYM Agent"
echo.

:: 管理者権限チェック
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 管理者権限が必要です。
    echo.
    echo 解決方法:
    echo 1. このファイルを右クリック
    echo 2. "管理者として実行" を選択
    echo 3. UAC（ユーザーアカウント制御）で「はい」をクリック
    echo.
    echo 何かキーを押して終了...
    pause >nul
    exit /b 1
)

echo ✓ 管理者権限を確認しました。
echo.

:: 確認メッセージ
echo ⚠️  本当にEYM Agentの自動起動設定を削除しますか？
echo.
echo 削除すると:
echo - Windows起動時にEYM Agentが自動起動しなくなります
echo - 手動でアプリケーションを起動する必要があります
echo - 再度自動起動したい場合は install_autostart.bat を実行してください
echo.
set /p confirm="削除を実行しますか？ (y/N): "

if /i not "%confirm%"=="y" (
    echo.
    echo キャンセルしました。設定は変更されていません。
    echo.
    echo 何かキーを押して終了...
    pause >nul
    exit /b 0
)

echo.
echo 自動起動設定を削除中...
echo.

:: レジストリから自動起動エントリを削除
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "EYM Agent" /f >nul 2>&1

if %errorlevel% == 0 (
    echo.
    echo ✅ 自動起動設定を削除しました！
    echo.
    echo 削除された設定:
    echo - 登録名: EYM Agent
    echo - 場所: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    echo.
    echo 📝 注意事項:
    echo - 次回のWindows起動時からEYM Agentは自動起動しません
    echo - qrsc_pc.exeを実行してください
    echo - 再度自動起動したい場合は install_autostart.bat を実行してください
    echo.
    echo 📝 現在実行中のEYM Agentについて:
    echo - 現在実行中のEYM Agentは継続して動作します
    echo - システムトレイから終了するか、PCを再起動してください
    echo.
) else (
    echo.
    echo ⚠️  自動起動設定の削除に失敗しました。
    echo.
    echo 考えられる原因:
    echo - 該当するレジストリエントリが存在しない
    echo - レジストリへの書き込み権限不足
    echo - セキュリティソフトによる干渉
    echo.
    echo 手動削除方法:
    echo 1. Win + R → "regedit" → Enter
    echo 2. HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run に移動
    echo 3. "EYM Agent" エントリを右クリック → 削除
    echo.
    echo または:
    echo 1. Win + R → "msconfig" → スタートアップタブ
    echo 2. "EYM Agent" を無効にする
    echo.
)

echo.
echo 設定確認方法:
echo 1. Win + R → "msconfig" → スタートアップタブ
echo 2. または タスクマネージャー → スタートアップタブ
echo 3. "EYM Agent" が表示されないことを確認
echo.
echo 何かキーを押して終了...
pause >nul
