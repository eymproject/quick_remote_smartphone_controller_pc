@echo off
chcp 65001 >nul
title EYM Agent ファイアウォール設定

echo.
echo ========================================
echo   EYM Agent ファイアウォール設定
echo ========================================
echo.
echo このツールはEYM Agentが正常に動作するために
echo Windows Defenderファイアウォールの設定を行います。
echo.
echo 設定内容:
echo - ポート8080（TCP）の受信を許可
echo - プログラム名: "EYM Agent"
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
echo ファイアウォール設定を開始します...
echo.

:: 既存のルールを削除（重複防止）
echo 既存の設定をクリーンアップ中...
netsh advfirewall firewall delete rule name="EYM Agent" >nul 2>&1

:: 新しいルールを追加
echo ポート8080の受信許可ルールを追加中...
netsh advfirewall firewall add rule name="EYM Agent" dir=in action=allow protocol=TCP localport=8080 profile=any

if %errorlevel% == 0 (
    echo.
    echo ✅ ファイアウォール設定が完了しました！
    echo.
    echo 設定内容:
    echo - ルール名: EYM Agent
    echo - 方向: 受信
    echo - プロトコル: TCP
    echo - ポート: 8080
    echo - 動作: 許可
    echo - プロファイル: すべて（パブリック、プライベート、ドメイン）
    echo.
    echo 🎉 EYM Agentが正常に動作するようになりました！
    echo.
    echo 次の手順:
    echo 1. EYM Agentを起動
    echo 2. スマホでQRコードをスキャン
    echo 3. 接続完了！
    echo.
) else (
    echo.
    echo ❌ ファイアウォール設定に失敗しました。
    echo.
    echo 考えられる原因:
    echo - Windows Defenderファイアウォールが無効
    echo - グループポリシーによる制限
    echo - セキュリティソフトによる干渉
    echo.
    echo 手動設定方法:
    echo 1. Windows設定 → 更新とセキュリティ
    echo 2. Windows セキュリティ → ファイアウォールとネットワーク保護
    echo 3. 詳細設定 → 受信の規則 → 新しい規則
    echo 4. ポート → TCP → 特定のローカルポート: 8080
    echo 5. 接続を許可する → すべてのプロファイル
    echo 6. 名前: "EYM Agent" → 完了
    echo.
)

echo.
echo 設定確認方法:
echo Windows設定 → Windows セキュリティ → ファイアウォールとネットワーク保護
echo → 詳細設定 → 受信の規則 → "EYM Agent" を確認
echo.
echo 何かキーを押して終了...
pause >nul
