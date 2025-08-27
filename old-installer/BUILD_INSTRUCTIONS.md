# QRSC PC インストーラ ビルド手順

このドキュメントでは、QRSC PCのInno Setupインストーラをビルドする手順を説明します。

## 📋 前提条件

### 1. 必要なソフトウェア
- **Inno Setup 6.x** (https://jrsoftware.org/isinfo.php)
- **Flutter SDK** (アプリのビルド用)
- **Visual Studio 2022** (C++ワークロード)

### 2. プロジェクト状態
- Flutterアプリが正常にビルドされていること
- `build/windows/x64/runner/Release/` にqrsc_pc.exeが存在すること

## 🚀 ビルド手順

### ステップ1: Inno Setupのインストール

1. **Inno Setup公式サイト**からダウンロード
   ```
   https://jrsoftware.org/isinfo.php
   ```

2. **インストール実行**
   - `innosetup-6.x.x.exe` を実行
   - デフォルト設定でインストール
   - 日本語言語パックも含まれます

3. **インストール確認**
   ```batch
   # 以下のパスにISCC.exeが存在することを確認
   C:\Program Files (x86)\Inno Setup 6\ISCC.exe
   # または
   C:\Program Files\Inno Setup 6\ISCC.exe
   ```

### ステップ2: Flutterアプリのビルド

1. **プロジェクトルートで実行**
   ```batch
   # 既存のビルドをクリーンアップ
   flutter clean
   
   # 依存関係を取得
   flutter pub get
   
   # リリースビルド実行
   flutter build windows --release
   ```

2. **ビルド確認**
   ```batch
   # 以下のファイルが存在することを確認
   build\windows\x64\runner\Release\qrsc_pc.exe
   build\windows\x64\runner\Release\*.dll
   build\windows\x64\runner\Release\data\
   ```

### ステップ3: インストーラビルド

#### 方法1: バッチファイル使用（推奨）

1. **installerフォルダに移動**
   ```batch
   cd installer
   ```

2. **ビルドスクリプト実行**
   ```batch
   # 管理者権限で実行（推奨）
   build_installer.bat
   ```

3. **ビルド結果確認**
   - `installer/Output/QRSC_PC_Setup.exe` が生成される
   - ファイルサイズは約15-20MB

#### 方法2: 手動ビルド

1. **Inno Setup Compilerで実行**
   ```batch
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" qrsc_pc_setup.iss
   ```

2. **VSCodeから実行**
   ```batch
   # 統合ターミナルで実行
   cd installer
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" qrsc_pc_setup.iss
   ```

## 🧪 テスト手順

### 1. インストーラテスト

#### 基本テスト
1. **管理者権限で実行**
   ```batch
   # 右クリック → 管理者として実行
   Output\QRSC_PC_Setup.exe
   ```

2. **インストール確認項目**
   - [ ] ライセンス画面が表示される
   - [ ] インストール先選択が可能
   - [ ] ファイアウォール設定オプションが表示される
   - [ ] インストール進行状況が表示される
   - [ ] 完了メッセージが表示される

3. **インストール後確認**
   - [ ] `C:\Program Files\QRSC PC\` にファイルが配置される
   - [ ] スタートメニューにショートカットが作成される
   - [ ] デスクトップショートカット（選択時）
   - [ ] QRSC PCが正常に起動する

#### 機能テスト
1. **アプリケーション起動**
   - [ ] qrsc_pc.exe が正常に起動
   - [ ] サーバーがポート8080で起動
   - [ ] QRコード表示機能が動作

2. **ファイアウォール設定**
   - [ ] Windows Defenderファイアウォールでポート8080が許可される
   - [ ] 外部からの接続が可能

3. **スマートフォン接続**
   - [ ] QRコード接続が成功
   - [ ] 手動IP入力接続が成功
   - [ ] リモート操作が正常に動作

### 2. アンインストールテスト

1. **アンインストール実行**
   ```
   コントロールパネル → プログラムと機能 → QRSC PC → アンインストール
   ```

2. **削除確認項目**
   - [ ] アプリケーションファイルが削除される
   - [ ] ショートカットが削除される
   - [ ] ファイアウォール設定が削除される
   - [ ] レジストリエントリが削除される

## 🔧 トラブルシューティング

### ビルドエラー

#### エラー1: ISCC.exeが見つからない
```
解決方法:
1. Inno Setupが正しくインストールされているか確認
2. build_installer.bat のパス設定を確認
3. 環境変数PATHにInno Setupを追加
```

#### エラー2: qrsc_pc.exeが見つからない
```
解決方法:
1. flutter build windows --release を実行
2. build/windows/x64/runner/Release/ にファイルが存在するか確認
3. ビルドエラーがないか確認
```

#### エラー3: ファイルアクセスエラー
```
解決方法:
1. 管理者権限でコマンドプロンプトを実行
2. ウイルス対策ソフトの除外設定を確認
3. ファイルが他のプロセスで使用されていないか確認
```

### インストールエラー

#### エラー1: 管理者権限エラー
```
解決方法:
1. インストーラを右クリック → 管理者として実行
2. UACで「はい」をクリック
3. 管理者アカウントでログイン
```

#### エラー2: ファイアウォール設定失敗
```
解決方法:
1. Windows Defenderファイアウォールが有効か確認
2. 手動でsetup_firewall.batを管理者として実行
3. ファイアウォール設定を手動で追加
```

## 📦 配布準備

### 1. ファイル構成
```
配布用フォルダ/
├── QRSC_PC_Setup.exe          # インストーラ
├── README.txt                 # 使用方法
├── CHANGELOG.txt              # 変更履歴
└── screenshots/               # スクリーンショット
    ├── install_step1.png
    ├── install_step2.png
    └── app_screenshot.png
```

### 2. チェックリスト
- [ ] インストーラが正常にビルドされる
- [ ] 複数のWindows環境でテスト済み
- [ ] ウイルススキャンでクリーン
- [ ] デジタル署名（オプション）
- [ ] 配布用ドキュメント準備完了

### 3. バージョン管理
```
リリース時の更新項目:
1. pubspec.yaml のバージョン番号
2. qrsc_pc_setup.iss の MyAppVersion
3. README_INSTALLER.md のバージョン情報
4. CHANGELOG.txt の更新履歴
```

## 📝 メンテナンス

### 定期的な更新
- Inno Setupの最新版確認
- Flutterフレームワークの更新
- セキュリティパッチの適用
- 依存関係の更新

### ログ確認
```
インストールログの場所:
%TEMP%\Setup Log YYYY-MM-DD #XXX.txt
```

---

**作成者**: EYM Project  
**最終更新**: 2025/08/27  
**バージョン**: 1.0.0
