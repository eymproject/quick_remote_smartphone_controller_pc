import 'dart:convert';
import 'package:logger/logger.dart';
import '../core/models.dart';

/// Web版用のサーバー代替クラス
class WebEYMServer {
  static final Logger _logger = Logger();
  
  bool _isRunning = false;
  ShortcutConfig _currentConfig = ShortcutConfig.createDefault();

  /// サーバーが実行中かどうか（Web版では常にfalse）
  bool get isRunning => _isRunning;
  
  /// 現在のポート番号（Web版では固定）
  int get port => 8080;
  
  /// 現在の設定
  ShortcutConfig get currentConfig => _currentConfig;

  /// サーバーを開始（Web版では設定読み込みのみ）
  Future<bool> start({int? port}) async {
    if (_isRunning) {
      _logger.w('サーバーは既に実行中です');
      return false;
    }

    try {
      // Web版では設定をデフォルトで初期化
      _currentConfig = ShortcutConfig.createDefault();
      _isRunning = true;
      
      _logger.i('Web版EYM Agent: 設定を読み込みました（HTTPサーバーはWeb版では利用できません）');
      _logger.i('注意: Web版ではHTTP/WebSocketサーバー機能は制限されます');
      _logger.i('完全な機能を使用するには、Windows ネイティブ版をご利用ください');
      
      return true;
    } catch (e, stackTrace) {
      _logger.e('設定の読み込みに失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// サーバーを停止
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.w('サーバーは実行されていません');
      return;
    }

    try {
      _isRunning = false;
      _logger.i('Web版EYM Agent: 停止しました');
    } catch (e, stackTrace) {
      _logger.e('停止中にエラーが発生しました', error: e, stackTrace: stackTrace);
    }
  }

  /// 設定を更新
  Future<void> updateConfig(ShortcutConfig config) async {
    _currentConfig = config;
    _logger.i('設定を更新しました');
  }

  /// アプリケーションを起動（Web版では制限あり）
  Future<ResultMessage> launchApplication(int buttonId) async {
    final shortcut = _currentConfig.getShortcut(buttonId);
    if (shortcut == null) {
      return ResultMessage(
        id: buttonId,
        success: false,
        message: 'ボタンID $buttonId のショートカットが見つかりません',
      );
    }

    // Web版では制限された起動処理
    if (shortcut.path.startsWith('http://') || shortcut.path.startsWith('https://')) {
      try {
        _logger.i('URL起動を試行: ${shortcut.path}');
        // Web版ではwindow.openが使えないため、ログのみ
        return ResultMessage(
          id: buttonId,
          success: true,
          message: 'URL起動を試行しました（Web版では制限があります）',
        );
      } catch (e) {
        return ResultMessage(
          id: buttonId,
          success: false,
          message: 'URL起動に失敗しました: $e',
        );
      }
    } else {
      return ResultMessage(
        id: buttonId,
        success: false,
        message: 'Web版ではローカルアプリケーションの起動はサポートされていません',
      );
    }
  }

  /// サーバーの情報を取得
  Map<String, dynamic> getServerInfo() {
    return {
      'isRunning': _isRunning,
      'port': port,
      'url': 'Web版では外部HTTPサーバーは利用できません',
      'wsConnections': 0,
      'shortcuts': _currentConfig.shortcuts.length,
      'platform': 'web',
      'limitations': [
        'HTTPサーバー機能は利用できません',
        'WebSocket機能は利用できません', 
        'ローカルアプリケーションの起動は制限されます',
        'URL起動のみ部分的にサポート',
      ],
    };
  }
}
