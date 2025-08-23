import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../core/models.dart' hide AppLauncher;
import '../core/store.dart';
import '../server/http_server.dart';
import '../server/web_server.dart';

/// アプリケーション全体の状態を管理するクラス
class AppState extends ChangeNotifier {
  static final Logger _logger = Logger();

  // プラットフォームに応じてサーバーを選択
  late final dynamic _server;
  ShortcutConfig _config = ShortcutConfig.createDefault();
  final List<String> _logs = [];
  bool _isLoading = false;

  /// 現在のサーバー
  dynamic get server => _server;

  /// 現在の設定
  ShortcutConfig get config => _config;

  /// ログ一覧
  List<String> get logs => List.unmodifiable(_logs);

  /// ローディング状態
  bool get isLoading => _isLoading;

  /// サーバーが実行中かどうか
  bool get isServerRunning => _server.isRunning;

  /// サーバーのURL
  String? get serverUrl {
    if (!_server.isRunning) return null;
    final serverInfo = _server.getServerInfo();
    return serverInfo['url'] as String?;
  }

  AppState() {
    // プラットフォームに応じてサーバーを初期化
    if (kIsWeb) {
      _server = WebEYMServer();
    } else {
      _server = EYMServer();
    }
    _initialize();
  }

  /// ウィンドウ表示コールバックを設定
  void setShowWindowCallback(void Function() callback) {
    if (!kIsWeb && _server is EYMServer) {
      (_server as EYMServer).setShowWindowCallback(callback);
    }
  }

  /// 初期化
  Future<void> _initialize() async {
    _setLoading(true);
    try {
      // 設定を読み込み（プラットフォーム別）
      if (kIsWeb) {
        _config = await _loadWebConfig();
      } else {
        _config = await ShortcutStore.load();
      }
      _addLog('設定を読み込みました');

      // サーバーを開始
      final success = await _server.start();
      if (success) {
        _addLog('サーバーを開始しました: ${serverUrl}');
      } else {
        _addLog('サーバーの開始に失敗しました');
      }
    } catch (e) {
      _logger.e('初期化中にエラーが発生しました', error: e);
      _addLog('初期化中にエラーが発生しました: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 設定を更新
  Future<void> updateConfig(ShortcutConfig newConfig) async {
    _setLoading(true);
    try {
      bool success;
      if (kIsWeb) {
        success = await _saveWebConfig(newConfig);
      } else {
        success = await ShortcutStore.save(newConfig);
      }

      if (success) {
        _config = newConfig;
        _server.updateConfig(newConfig);
        _addLog('設定を更新しました');
        notifyListeners();
      } else {
        _addLog('設定の保存に失敗しました');
      }
    } catch (e) {
      _logger.e('設定更新中にエラーが発生しました', error: e);
      _addLog('設定更新中にエラーが発生しました: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// ショートカットを更新
  Future<void> updateShortcut(Shortcut shortcut) async {
    final shortcuts = _config.shortcuts.map((s) {
      return s.buttonId == shortcut.buttonId ? shortcut : s;
    }).toList();

    final newConfig = _config.copyWith(shortcuts: shortcuts);
    await updateConfig(newConfig);
  }

  /// サーバーを開始
  Future<void> startServer() async {
    if (_server.isRunning) {
      _addLog('サーバーは既に実行中です');
      return;
    }

    _setLoading(true);
    try {
      final success = await _server.start();
      if (success) {
        _addLog('サーバーを開始しました: ${serverUrl}');
      } else {
        _addLog('サーバーの開始に失敗しました');
      }
    } catch (e) {
      _logger.e('サーバー開始中にエラーが発生しました', error: e);
      _addLog('サーバー開始中にエラーが発生しました: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// サーバーを停止
  Future<void> stopServer() async {
    if (!_server.isRunning) {
      _addLog('サーバーは実行されていません');
      return;
    }

    _setLoading(true);
    try {
      await _server.stop();
      _addLog('サーバーを停止しました');
    } catch (e) {
      _logger.e('サーバー停止中にエラーが発生しました', error: e);
      _addLog('サーバー停止中にエラーが発生しました: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// アプリケーションを起動（テスト用）
  Future<void> launchApplication(int buttonId) async {
    final shortcut = _config.getShortcut(buttonId);
    if (shortcut == null) {
      _addLog('ボタンID $buttonId のショートカットが見つかりません');
      return;
    }

    _addLog('アプリケーションを起動中: ${shortcut.name}');

    try {
      ResultMessage result;
      if (kIsWeb) {
        // Web版では専用のメソッドを使用
        result = await (_server as WebEYMServer).launchApplication(buttonId);
      } else {
        // ネイティブ版では従来通り
        result = await AppLauncher.launch(shortcut);
      }

      if (result.success) {
        _addLog('アプリケーションを起動しました: ${shortcut.name}');
      } else {
        _addLog('アプリケーションの起動に失敗しました: ${result.message}');
      }
    } catch (e) {
      _logger.e('アプリケーション起動中にエラーが発生しました', error: e);
      _addLog('アプリケーション起動中にエラーが発生しました: $e');
    }
  }

  /// 設定をリセット
  Future<void> resetConfig() async {
    _setLoading(true);
    try {
      if (kIsWeb) {
        await _resetWebConfig();
        _config = ShortcutConfig.createDefault();
        await _saveWebConfig(_config);
      } else {
        await ShortcutStore.reset();
        _config = ShortcutConfig.createDefault();
        await ShortcutStore.save(_config);
      }

      _server.updateConfig(_config);
      _addLog('設定をリセットしました');
      notifyListeners();
    } catch (e) {
      _logger.e('設定リセット中にエラーが発生しました', error: e);
      _addLog('設定リセット中にエラーが発生しました: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// ログをクリア
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// サーバー情報を取得
  Map<String, dynamic> getServerInfo() {
    return _server.getServerInfo();
  }

  /// ローディング状態を設定
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// ログを追加
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');

    // ログが多すぎる場合は古いものを削除
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }

    _logger.i(message);
    notifyListeners();
  }

  /// Web版の設定読み込み（LocalStorage使用）
  Future<ShortcutConfig> _loadWebConfig() async {
    try {
      // Web版では設定をメモリに保持（簡易実装）
      return ShortcutConfig.createDefault();
    } catch (e) {
      _logger.e('Web版設定の読み込みに失敗しました', error: e);
      return ShortcutConfig.createDefault();
    }
  }

  /// Web版の設定保存（LocalStorage使用）
  Future<bool> _saveWebConfig(ShortcutConfig config) async {
    try {
      // Web版では設定をメモリに保持（簡易実装）
      _logger.i('Web版設定を保存しました（メモリ内）');
      return true;
    } catch (e) {
      _logger.e('Web版設定の保存に失敗しました', error: e);
      return false;
    }
  }

  /// Web版の設定リセット
  Future<bool> _resetWebConfig() async {
    try {
      // Web版では設定をメモリに保持（簡易実装）
      _logger.i('Web版設定をリセットしました（メモリ内）');
      return true;
    } catch (e) {
      _logger.e('Web版設定のリセットに失敗しました', error: e);
      return false;
    }
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
