# Windows ビルド環境セットアップ

## 問題
`flutter run -d windows` を実行すると以下のエラーが発生：
```
CMake Error at CMakeLists.txt:3 (project):
  No CMAKE_CXX_COMPILER could be found.
```

## 解決方法

### 1. Visual Studio Build Tools のインストール

以下のいずれかの方法でC++コンパイラをインストールしてください：

#### オプション A: Visual Studio Community 2022 (推奨)
1. [Visual Studio Community 2022](https://visualstudio.microsoft.com/ja/vs/community/) をダウンロード
2. インストーラーを実行
3. **「C++によるデスクトップ開発」** ワークロードを選択
4. インストールを完了

#### オプション B: Visual Studio Build Tools 2022
1. [Visual Studio Build Tools 2022](https://visualstudio.microsoft.com/ja/downloads/#build-tools-for-visual-studio-2022) をダウンロード
2. インストーラーを実行
3. **「C++ build tools」** を選択
4. 以下のコンポーネントが含まれていることを確認：
   - MSVC v143 - VS 2022 C++ x64/x86 build tools
   - Windows 10/11 SDK
   - CMake tools for Visual Studio

### 2. 環境変数の設定

インストール後、新しいコマンドプロンプトまたはPowerShellを開いて以下を確認：

```powershell
# C++コンパイラが利用可能か確認
where cl

# CMakeが利用可能か確認
where cmake
```

### 3. Flutter環境の確認

```bash
flutter doctor -v
```

Visual Studio関連の項目が✓になっていることを確認してください。

### 4. プロジェクトのビルド

```bash
flutter clean
flutter pub get
flutter run -d windows
```

## 代替案

Windowsでのビルドが困難な場合は、以下の代替案があります：

### Web版での動作確認
```bash
flutter run -d chrome
```

### テストクライアントでの動作確認
```bash
# Pythonテストクライアントを使用
pip install requests
python test_client.py
```

## トラブルシューティング

### エラー: "Visual Studio not found"
- Visual Studio Community 2022またはBuild Tools 2022がインストールされていることを確認
- インストール時に「C++によるデスクトップ開発」ワークロードが選択されていることを確認

### エラー: "CMake not found"
- Visual Studioインストール時にCMakeツールが含まれていることを確認
- または、[CMake公式サイト](https://cmake.org/download/)から個別にインストール

### エラー: "Windows SDK not found"
- Visual Studioインストール時にWindows SDKが含まれていることを確認
- 最新のWindows 10/11 SDKを選択

## 参考リンク

- [Flutter Windows デスクトップサポート](https://docs.flutter.dev/platform-integration/desktop)
- [Visual Studio Community](https://visualstudio.microsoft.com/ja/vs/community/)
- [Flutter Doctor](https://docs.flutter.dev/resources/bug-reports#provide-some-flutter-diagnostics)
