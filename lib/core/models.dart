import 'dart:convert';
import 'dart:io';

/// アプリケーション起動を担当するクラス
class AppLauncher {
  /// ショートカットを実行してResultMessageを返す
  static Future<ResultMessage> launch(Shortcut shortcut) async {
    print('AppLauncher.launch開始: ${shortcut.name} (${shortcut.path})');
    
    try {
      if (shortcut.path.isEmpty) {
        print('エラー: パスが空です');
        return ResultMessage(
          id: shortcut.buttonId,
          success: false,
          message: 'パスが設定されていません',
        );
      }

      print('コマンド実行: cmd /c start "" "${shortcut.path}"');
      
      // Windowsの場合、cmdを使用してアプリケーションを起動
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '', shortcut.path],
        runInShell: true,
      );

      print('実行結果: exitCode=${result.exitCode}');
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');

      if (result.exitCode == 0) {
        print('起動成功: ${shortcut.name}');
        return ResultMessage(
          id: shortcut.buttonId,
          success: true,
          message: '${shortcut.name} を起動しました',
        );
      } else {
        print('起動失敗: exitCode=${result.exitCode}, stderr=${result.stderr}');
        return ResultMessage(
          id: shortcut.buttonId,
          success: false,
          message: '起動に失敗しました: exitCode=${result.exitCode}, stderr=${result.stderr}',
        );
      }
    } catch (e) {
      print('例外発生: $e');
      return ResultMessage(
        id: shortcut.buttonId,
        success: false,
        message: '起動に失敗しました: $e',
      );
    }
  }
}

/// ショートカット情報を表すモデル
class Shortcut {
  final int buttonId;
  final String name;
  final String path;
  final List<String> args;
  final String? iconPath;
  final int tabIndex; // タブインデックス（0から開始）
  final String iconSource; // "drag_drop" または "manual"

  const Shortcut({
    required this.buttonId,
    required this.name,
    required this.path,
    this.args = const [],
    this.iconPath,
    this.tabIndex = 0, // デフォルトは0（最初のタブ）
    this.iconSource = "manual", // デフォルトは手動設定
  });

  /// JSONからShortcutオブジェクトを作成
  factory Shortcut.fromJson(Map<String, dynamic> json) {
    return Shortcut(
      buttonId: json['buttonId'] as int,
      name: json['name'] as String,
      path: json['path'] as String,
      args: (json['args'] as List<dynamic>?)?.cast<String>() ?? [],
      iconPath: json['iconPath'] as String?,
      tabIndex: json['tabIndex'] as int? ?? 0, // 後方互換性のためデフォルト0
      iconSource: json['iconSource'] as String? ?? "manual", // 既存データのデフォルト値
    );
  }

  /// ShortcutオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'buttonId': buttonId,
      'name': name,
      'path': path,
      'args': args,
      if (iconPath != null) 'iconPath': iconPath,
      'tabIndex': tabIndex,
      'iconSource': iconSource,
    };
  }

  /// コピーを作成（一部のフィールドを変更可能）
  Shortcut copyWith({
    int? buttonId,
    String? name,
    String? path,
    List<String>? args,
    String? iconPath,
    int? tabIndex,
    String? iconSource,
  }) {
    return Shortcut(
      buttonId: buttonId ?? this.buttonId,
      name: name ?? this.name,
      path: path ?? this.path,
      args: args ?? this.args,
      iconPath: iconPath ?? this.iconPath,
      tabIndex: tabIndex ?? this.tabIndex,
      iconSource: iconSource ?? this.iconSource,
    );
  }

  @override
  String toString() {
    return 'Shortcut(buttonId: $buttonId, name: $name, path: $path, args: $args, iconPath: $iconPath, tabIndex: $tabIndex, iconSource: $iconSource)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Shortcut &&
        other.buttonId == buttonId &&
        other.name == name &&
        other.path == path &&
        _listEquals(other.args, args) &&
        other.iconPath == iconPath &&
        other.tabIndex == tabIndex &&
        other.iconSource == iconSource;
  }

  @override
  int get hashCode {
    return Object.hash(buttonId, name, path, args, iconPath, tabIndex, iconSource);
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// タブ情報を表すモデル
class TabInfo {
  final int index;
  final String name;

  const TabInfo({
    required this.index,
    required this.name,
  });

  /// JSONからTabInfoオブジェクトを作成
  factory TabInfo.fromJson(Map<String, dynamic> json) {
    return TabInfo(
      index: json['index'] as int,
      name: json['name'] as String,
    );
  }

  /// TabInfoオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
    };
  }

  /// コピーを作成
  TabInfo copyWith({
    int? index,
    String? name,
  }) {
    return TabInfo(
      index: index ?? this.index,
      name: name ?? this.name,
    );
  }

  @override
  String toString() {
    return 'TabInfo(index: $index, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TabInfo &&
        other.index == index &&
        other.name == name;
  }

  @override
  int get hashCode {
    return Object.hash(index, name);
  }
}

/// ショートカット設定全体を表すモデル
class ShortcutConfig {
  final int protocolVersion;
  final List<Shortcut> shortcuts;
  final List<TabInfo> tabs;

  const ShortcutConfig({
    this.protocolVersion = 1,
    required this.shortcuts,
    this.tabs = const [],
  });

  /// JSONからShortcutConfigオブジェクトを作成
  factory ShortcutConfig.fromJson(Map<String, dynamic> json) {
    return ShortcutConfig(
      protocolVersion: json['protocolVersion'] as int? ?? 1,
      shortcuts: (json['shortcuts'] as List<dynamic>)
          .map((e) => Shortcut.fromJson(e as Map<String, dynamic>))
          .toList(),
      tabs: (json['tabs'] as List<dynamic>?)
          ?.map((e) => TabInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// ShortcutConfigオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'protocolVersion': protocolVersion,
      'shortcuts': shortcuts.map((e) => e.toJson()).toList(),
      'tabs': tabs.map((e) => e.toJson()).toList(),
    };
  }

  /// JSON文字列に変換
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// JSON文字列から作成
  factory ShortcutConfig.fromJsonString(String jsonString) {
    return ShortcutConfig.fromJson(jsonDecode(jsonString));
  }

  /// コピーを作成
  ShortcutConfig copyWith({
    int? protocolVersion,
    List<Shortcut>? shortcuts,
    List<TabInfo>? tabs,
  }) {
    return ShortcutConfig(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      shortcuts: shortcuts ?? this.shortcuts,
      tabs: tabs ?? this.tabs,
    );
  }

  /// 指定されたbuttonIdのショートカットを取得
  /// buttonIdはグローバルID（1から開始）で、タブインデックスと相対buttonIdに変換して検索
  Shortcut? getShortcut(int buttonId) {
    try {
      // グローバルbuttonIdからタブインデックスと相対buttonIdを計算
      final tabIndex = (buttonId - 1) ~/ 6;
      final relativeButtonId = ((buttonId - 1) % 6) + 1;
      
      return shortcuts.firstWhere(
        (s) => s.tabIndex == tabIndex && s.buttonId == relativeButtonId,
      );
    } catch (e) {
      return null;
    }
  }

  /// 指定されたインデックスのタブ情報を取得
  TabInfo? getTabInfo(int index) {
    try {
      return tabs.firstWhere((t) => t.index == index);
    } catch (e) {
      return null;
    }
  }

  /// タブ名を取得（存在しない場合はデフォルト名を返す）
  String getTabName(int index) {
    final tabInfo = getTabInfo(index);
    return tabInfo?.name ?? 'タブ ${index + 1}';
  }

  /// デフォルト設定を作成（1-9のボタン、空の状態）
  factory ShortcutConfig.createDefault() {
    return ShortcutConfig(
      shortcuts: List.generate(5, (index) => Shortcut(
        buttonId: index + 1,
        name: '',
        path: '',
      )),
      tabs: [const TabInfo(index: 0, name: 'タブ 1')],
    );
  }
}

/// プロトコルメッセージの基底クラス
abstract class ProtocolMessage {
  final String type;
  
  const ProtocolMessage({required this.type});
  
  Map<String, dynamic> toJson();
  
  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'shortcuts':
        return ShortcutsMessage.fromJson(json);
      case 'launch':
        return LaunchMessage.fromJson(json);
      case 'result':
        return ResultMessage.fromJson(json);
      case 'ping':
        return PingMessage.fromJson(json);
      case 'pong':
        return PongMessage.fromJson(json);
      default:
        throw ArgumentError('Unknown message type: $type');
    }
  }
}

/// ショートカット一覧を送信するメッセージ
class ShortcutsMessage extends ProtocolMessage {
  final int protocolVersion;
  final List<Shortcut> data;

  const ShortcutsMessage({
    this.protocolVersion = 1,
    required this.data,
  }) : super(type: 'shortcuts');

  factory ShortcutsMessage.fromJson(Map<String, dynamic> json) {
    return ShortcutsMessage(
      protocolVersion: json['protocolVersion'] as int? ?? 1,
      data: (json['data'] as List<dynamic>)
          .map((e) => Shortcut.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'protocolVersion': protocolVersion,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }
}

/// アプリケーション起動要求メッセージ
class LaunchMessage extends ProtocolMessage {
  final int id;

  const LaunchMessage({required this.id}) : super(type: 'launch');

  factory LaunchMessage.fromJson(Map<String, dynamic> json) {
    return LaunchMessage(id: json['id'] as int);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
    };
  }
}

/// 実行結果メッセージ
class ResultMessage extends ProtocolMessage {
  final int id;
  final bool success;
  final String message;

  const ResultMessage({
    required this.id,
    required this.success,
    this.message = '',
  }) : super(type: 'result');

  factory ResultMessage.fromJson(Map<String, dynamic> json) {
    return ResultMessage(
      id: json['id'] as int,
      success: json['success'] as bool,
      message: json['message'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'success': success,
      'message': message,
    };
  }
}

/// Pingメッセージ
class PingMessage extends ProtocolMessage {
  const PingMessage() : super(type: 'ping');

  factory PingMessage.fromJson(Map<String, dynamic> json) {
    return const PingMessage();
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}

/// Pongメッセージ
class PongMessage extends ProtocolMessage {
  const PongMessage() : super(type: 'pong');

  factory PongMessage.fromJson(Map<String, dynamic> json) {
    return const PongMessage();
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}
