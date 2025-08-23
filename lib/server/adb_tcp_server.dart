import 'dart:convert';
import 'dart:io';
import 'package:eym_agent/core/models.dart';
import 'package:logger/logger.dart';
import '../core/models.dart' as models;
import '../core/store.dart' as store;

/// ADB経由のTCP通信サーバー
class AdbTcpServer {
  static final Logger _logger = Logger();
  
  ServerSocket? _server;
  bool _isRunning = false;
  models.ShortcutConfig _currentConfig = models.ShortcutConfig.createDefault();
  final int _port = 12345;
  
  /// サーバーが実行中かどうか
  bool get isRunning => _isRunning;
  
  /// 現在の設定
  ShortcutConfig get currentConfig => _currentConfig;

  /// ADB TCPサーバーを開始
  Future<bool> start() async {
    if (_isRunning) {
      _logger.w('ADB TCPサーバーは既に実行中です');
      return false;
    }

    try {
      // 設定を読み込み
      _currentConfig = await store.ShortcutStore.load();

      // TCPサーバーを開始（localhost:12345）
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);
      _isRunning = true;

      _logger.i('ADB TCPサーバーを開始しました: localhost:$_port');
      _logger.i('ADBリバースポートフォワーディング: adb reverse tcp:12345 tcp:12345');

      // クライアント接続を待機
      _server!.listen(_handleClient);

      return true;
    } catch (e, stackTrace) {
      _logger.e('ADB TCPサーバーの開始に失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// サーバーを停止
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.w('ADB TCPサーバーは実行されていません');
      return;
    }

    try {
      await _server?.close();
      _server = null;
      _isRunning = false;
      _logger.i('ADB TCPサーバーを停止しました');
    } catch (e, stackTrace) {
      _logger.e('ADB TCPサーバーの停止中にエラーが発生しました', error: e, stackTrace: stackTrace);
    }
  }

  /// クライアント接続を処理
  void _handleClient(Socket client) {
    _logger.i('ADB接続が確立されました: ${client.remoteAddress}');

    client.listen(
      (data) async {
        try {
          final message = utf8.decode(data).trim();
          await _handleMessage(client, message);
        } catch (e) {
          _logger.e('メッセージ処理エラー', error: e);
          _sendError(client, 'メッセージの処理に失敗しました');
        }
      },
      onDone: () {
        _logger.i('ADB接続が切断されました');
        client.close();
      },
      onError: (error) {
        _logger.e('ADB接続エラー', error: error);
        client.close();
      },
    );
  }

  /// メッセージを処理
  Future<void> _handleMessage(Socket client, String message) async {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      _logger.i('受信メッセージ: $type');

      switch (type) {
        case 'ping':
          _sendMessage(client, {
            'type': 'pong',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          break;

        case 'get_shortcuts':
          _sendShortcuts(client);
          break;

        case 'launch':
          final buttonId = json['button_id'] as int?;
          if (buttonId != null) {
            final result = await _launchApplication(buttonId);
            _sendMessage(client, result.toJson());
          } else {
            _sendError(client, 'button_id is required for launch command');
          }
          break;

        default:
          _logger.w('未知のメッセージタイプ: $type');
          _sendError(client, 'Unknown message type: $type');
      }
    } catch (e) {
      _logger.e('メッセージ解析エラー', error: e);
      _sendError(client, 'Failed to parse message: $e');
    }
  }

  /// ショートカット一覧を送信
  void _sendShortcuts(Socket client) {
    final message = models.ShortcutsMessage(
      protocolVersion: _currentConfig.protocolVersion,
      data: _currentConfig.shortcuts,
    );
    _sendMessage(client, message.toJson());
  }

  /// アプリケーションを起動
  Future<models.ResultMessage> _launchApplication(int buttonId) async {
    final shortcut = _currentConfig.getShortcut(buttonId);
    if (shortcut == null) {
      return models.ResultMessage(
        id: buttonId,
        success: false,
        message: 'ボタンID $buttonId のショートカットが見つかりません',
      );
    }

    _logger.i('アプリケーション起動: ${shortcut.name}');
    return await models.AppLauncher.launch(shortcut);
  }

  /// メッセージを送信
  void _sendMessage(Socket client, Map<String, dynamic> message) {
    try {
      final jsonString = jsonEncode(message);
      client.write('$jsonString\n');
      _logger.d('送信完了: $jsonString');
    } catch (e) {
      _logger.e('メッセージ送信エラー', error: e);
    }
  }

  /// エラーメッセージを送信
  void _sendError(Socket client, String errorMessage) {
    _sendMessage(client, {
      'type': 'error',
      'message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 設定を更新
  Future<void> updateConfig(models.ShortcutConfig config) async {
    _currentConfig = config;
  }

  /// サーバーの情報を取得
  Map<String, dynamic> getServerInfo() {
    return {
      'isRunning': _isRunning,
      'port': _port,
      'connectionType': 'ADB TCP',
      'shortcuts': _currentConfig.shortcuts.length,
    };
  }
}
