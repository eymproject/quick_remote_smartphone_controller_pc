@echo off
chcp 65001 >nul
title QRSC_PC ファイアウォール設定削除

echo.
echo ========================================
echo   QRSC_PC ファイアウォール設定削除
echo ========================================
echo.
echo このツールはQRSC_PCのために追加した
echo Windows Defenderファイアウォールの設定を削除します。
echo.
echo 削除対象:
echo - ルール名: "QRSC_PC"
echo - ポート8080（TCP）の受信許可
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
echo ⚠️ 本当にQRSC_PCのファイアウォール設定を削除しますか？
echo.
echo 削除すると:
echo - スマホからPCへの接続ができなくなります
echo - 再度使用する場合は setup_firewall.bat を実行してください
echo.
set /p confirm="削除を実行しますか？ (y/N): "

if /i not "%confirm%"=="y" (
    echo.
    echo キャンセルしました。設定は変更されていません。
    echo.
    pause
    exit /b 0
)

echo.
echo ファイアウォール設定を削除中...
echo.

:: ルール削除（ルール名ベース）
netsh advfirewall firewall delete rule name="QRSC_PC" >nul 2>&1

:: 念のためポート指定でも削除（ルール名が変わっている場合に対応）
netsh advfirewall firewall delete rule protocol=TCP localport=8080 >nul 2>&1

if %errorlevel% == 0 (
    echo.
    echo ✅ ファイアウォール設定を削除しました！
    echo.
    echo 削除された内容:
    echo - ルール名: QRSC_PC
    echo - ポート: 8080 (TCP)
    echo.
    echo 📝 注意事項:
    echo - QRSC_PCは正常に動作しなくなります
    echo - 再度使用する場合は setup_firewall.bat を実行してください
    echo.
) else (
    echo.
    echo ⚠️ ファイアウォール設定の削除に失敗しました。
    echo.
    echo 考えられる原因:
    echo - 該当するルールが存在しない
    echo - Windows Defenderファイアウォールが無効
    echo - グループポリシーによる制限
    echo.
    echo 手動削除方法:
    echo 1. Windows設定 → Windows セキュリティ
    echo 2. ファイアウォールとネットワーク保護 → 詳細設定
    echo 3. 受信の規則 → "QRSC_PC" を右クリック → 削除
    echo.
)

echo.
echo 何かキーを押して終了...
pause >nul
