# IPアドレス確認方法

## 🎯 正しいIPアドレスの見つけ方

### PowerShellで確認
```powershell
ipconfig
```

### 出力例
```
   接続固有の DNS サフィックス . . . . .:
   IPv6 アドレス . . . . . . . . . . . .: 2404:7a85:e060:1200:8273:2e98:7f08:ef02
   一時 IPv6 アドレス. . . . . . . . . .: 2404:7a85:e060:1200:135:59f3:1e1e:6266
   リンクローカル IPv6 アドレス. . . . .: fe80::70e3:2707:7b7d:82fd%8
   IPv4 アドレス . . . . . . . . . . . .: xxx.xxx.xxx.xxx  ← これを使用！
   サブネット マスク . . . . . . . . . .: 255.255.255.0
   デフォルト ゲートウェイ . . . . . . .: fe80::22b:f5ff:fe76:ee60%8
                                          192.168.11.1
```

## ✅ 使用するIPアドレス

**IPv4 アドレス**: `192.168.xxx.xxx`

## 📱 スマホアプリでの設定

### 正しい設定
```dart
final String serverUrl = 'http://192.168.xxx.xxx:8080';
```

### 接続テスト用URL
```
http://192.168.xxx.xxx:8080/health
```

## 🔍 IPアドレスの種類と使い分け

### ✅ 使用するもの
- **IPv4 アドレス**: `192.168.xxx.xxx`
  - スマホから接続可能
  - 一般的なローカルネットワークアドレス

### ❌ 使用しないもの
- **IPv6 アドレス**: `2404:7a85:e060:1200:...`
  - 長すぎて複雑
  - 一般的なスマホアプリでは対応が複雑
- **リンクローカル IPv6**: `fe80::...`
  - ローカルリンクのみ
  - 通常のアプリでは使用しない
- **デフォルト ゲートウェイ**: `192.168.11.1`
  - ルーターのアドレス
  - PCのアドレスではない

## 🚀 実際の使用手順

### Step 1: IPアドレス確認
```powershell
ipconfig
```
→ `IPv4 アドレス . . . . . . . . . . . .: 192.168.xxx.xxx`

### Step 2: スマホアプリで設定
```dart
// あなたの場合の正しい設定
final String serverUrl = 'http://192.168.xxx.xxx:8080';

// ボタン押下時の処理
Future<void> sendButtonPress(int buttonId) async {
  final response = await http.post(
    Uri.parse('http://192.168.xxx.xxx:8080/launch'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'button_id': buttonId}),
  );
}
```

### Step 3: 接続テスト
1. **PCブラウザ**: `http://192.168.xxx.xxx:8080/health`
2. **スマホブラウザ**: 同じURL
3. 両方で "ok" が表示されれば成功！

## 💡 よくある間違い

### ❌ 間違った例
```dart
// localhost（スマホからアクセス不可）
final String serverUrl = 'http://localhost:8080';

// IPv6アドレス（複雑すぎる）
final String serverUrl = 'http://[2404:7a85:e060:1200:8273:2e98:7f08:ef02]:8080';

// ゲートウェイアドレス（ルーターのアドレス）
final String serverUrl = 'http://192.168.11.1:8080';
```

### ✅ 正しい例
```dart
// IPv4アドレス（シンプルで確実）
final String serverUrl = 'http://192.168.xxx.xxx:8080';
```

## 🔧 トラブルシューティング

### 問題1: IPアドレスが表示されない
**解決**: 
```powershell
ipconfig /all
```
より詳細な情報を表示

### 問題2: 複数のIPアドレスが表示される
**解決**: 
- Wi-Fi接続の場合：「ワイヤレス LAN アダプター Wi-Fi」の下のIPv4アドレス
- 有線接続の場合：「イーサネット アダプター イーサネット」の下のIPv4アドレス

### 問題3: IPアドレスが変わる
**解決**: 
- ルーターの設定で固定IPアドレスを割り当て
- または、毎回 `ipconfig` で確認

## 📋 チェックリスト

- [ ] `ipconfig` を実行
- [ ] **IPv4 アドレス** を確認（例：192.168.xxx.xxx）
- [ ] スマホアプリで `http://[IPv4アドレス]:8080` を設定
- [ ] PCブラウザで接続テスト
- [ ] スマホブラウザで接続テスト
- [ ] スマホアプリからボタンテスト

あなたの場合は **`http://192.168.xxx.xxx:8080`** がスマホから接続するURLです！
