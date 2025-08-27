#!/bin/bash

# QRSC_PC macOS自動起動設定スクリプト

echo "========================================"
echo "  QRSC_PC macOS自動起動設定"
echo "========================================"
echo ""
echo "このスクリプトはQRSC_PCをmacOS起動時に"
echo "自動で起動するように設定します。"
echo ""
echo "設定内容:"
echo "- macOS起動時にQRSC_PCを自動起動"
echo "- メニューバーに常駐"
echo "- バックグラウンドで動作"
echo ""

# 現在のディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/qrsc_pc.app"

# アプリケーションファイルの存在確認
if [ ! -d "$APP_PATH" ]; then
    echo "❌ QRSC_PCのアプリケーションが見つかりません。"
    echo ""
    echo "確認してください:"
    echo "- qrsc_pc.app が同じフォルダにあるか"
    echo "- ファイル名が正しいか"
    echo ""
    echo "検索パス: $APP_PATH"
    echo ""
    echo "何かキーを押して終了..."
    read -n 1
    exit 1
fi

echo "✓ QRSC_PCアプリケーションを確認しました。"
echo "パス: $APP_PATH"
echo ""

# LaunchAgentsディレクトリを作成
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# plistファイルのパス
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.qrsc.pc.plist"

# plistファイルを作成
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.qrsc.pc</string>
    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>-a</string>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>LaunchOnlyOnce</key>
    <true/>
</dict>
</plist>
EOF

if [ $? -eq 0 ]; then
    echo "✅ 自動起動設定が完了しました！"
    echo ""
    echo "設定内容:"
    echo "- 登録名: com.qrsc.pc"
    echo "- アプリケーション: $APP_PATH"
    echo "- 起動方法: メニューバーに常駐"
    echo ""
    echo "🎉 次回のmacOS起動時から自動で起動します！"
    echo ""
    echo "動作確認:"
    echo "1. Macを再起動"
    echo "2. メニューバー（画面上部）にQRSC_PCアイコンが表示される"
    echo "3. アイコンをクリックでメニュー表示"
    echo "4. スマホから接続テスト"
    echo ""
    echo "📝 メニューバーの使い方:"
    echo "- クリック: メニュー表示"
    echo "- \"ウィンドウを表示\": メイン画面を開く"
    echo "- \"QRコードを表示\": 接続用QRコード表示"
    echo "- \"終了\": アプリケーション終了"
    echo ""
    echo "📝 注意事項:"
    echo "- 自動起動を無効にしたい場合は remove_autostart_mac.sh を実行"
    echo "- macOSファイアウォール設定は通常不要です"
    echo ""
    
    # LaunchAgentを即座に読み込み
    launchctl load "$PLIST_FILE" 2>/dev/null
    
else
    echo "❌ 自動起動設定に失敗しました。"
    echo ""
    echo "考えられる原因:"
    echo "- ディスク容量不足"
    echo "- 権限不足"
    echo "- システム制限"
    echo ""
    echo "手動設定方法:"
    echo "1. システム環境設定 → ユーザとグループ"
    echo "2. ログイン項目タブ"
    echo "3. + ボタンでQRSC_PCを追加"
    echo "4. \"隠す\" にチェック"
    echo ""
fi

echo ""
echo "設定確認方法:"
echo "1. システム環境設定 → ユーザとグループ → ログイン項目"
echo "2. または Activity Monitor で \"QRSC_PC\" を検索"
echo ""
echo "何かキーを押して終了..."
read -n 1
