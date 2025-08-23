@echo off
chcp 65001 >nul
title EYM Agent 自動起動設定

echo.
echo ========================================
echo   EYM Agent 自動起動設定
echo ========================================
echo.
echo このツールはEYM AgentをWindows起動時に
echo システムトレイで自動起動するように設定します。
echo.
echo 設定内容:
echo - Windows起動時にEYM Agentを自動起動
echo - システムトレイに最小化して起動
echo - バックグラウンドで動作
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

:: 現在のディレクトリを取得
set "CURRENT_DIR=%~dp0"
set "EXE_PATH=%CURRENT_DIR%eym_agent.exe"

:: EXEファイルの存在確認
if not exist "%EXE_PATH%" (
    echo ❌ EYM Agentの実行ファイルが見つかりません。
    echo.
    echo 確認してください:
    echo - eym_agent.exe が同じフォルダにあるか
    echo - ファイル名が正しいか
    echo.
    echo 検索パス: %EXE_PATH%
    echo.
    echo 何かキーを押して終了...
    pause >nul
    exit /b 1
)

echo ✓ EYM Agent実行ファイルを確認しました。
echo パス: %EXE_PATH%
echo.

:: レジストリに自動起動を登録
echo Windows起動時の自動起動を設定中...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "EYM Agent" /t REG_SZ /d "\"%EXE_PATH%\"" /f >nul 2>&1

if %errorlevel% == 0 (
    echo.
    echo ✅ 自動起動設定が完了しました！
    echo.
    echo 設定内容:
    echo - 登録名: EYM Agent
    echo - 実行ファイル: %EXE_PATH%
    echo - 起動方法: システムトレイに最小化
    echo.
    echo 🎉 次回のWindows起動時から自動で起動します！
    echo.
    echo 動作確認:
    echo 1. PCを再起動
    echo 2. システムトレイ（画面右下）にEYM Agentアイコンが表示される
    echo 3. アイコンを右クリックでメニュー表示
    echo 4. スマホから接続テスト
    echo.
    echo 📝 システムトレイの使い方:
    echo - 右クリック: メニュー表示
    echo - "ウィンドウを表示": メイン画面を開く
    echo - "QRコードを表示": 接続用QRコード表示
    echo - "終了": アプリケーション終了
    echo.
    echo 📝 注意事項:
    echo - 自動起動を無効にしたい場合は remove_autostart.bat を実行
    echo - ファイアウォール設定も必要です（setup_firewall.bat）
    echo.
) else (
    echo.
    echo ❌ 自動起動設定に失敗しました。
    echo.
    echo 考えられる原因:
    echo - レジストリへの書き込み権限不足
    echo - セキュリティソフトによる干渉
    echo - システムポリシーによる制限
    echo.
    echo 手動設定方法:
    echo 1. Win + R キーを押す
    echo 2. "shell:startup" と入力してEnter
    echo 3. 開いたフォルダにEYM Agentのショートカットを作成
    echo 4. ショートカットのプロパティで実行時の大きさを「最小化」に設定
    echo.
)

echo.
echo 設定確認方法:
echo 1. Win + R → "msconfig" → スタートアップタブ
echo 2. または タスクマネージャー → スタートアップタブ
echo 3. "EYM Agent" が有効になっているか確認
echo.
echo 何かキーを押して終了...
pause >nul
