import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import '../core/models.dart';
import '../core/store.dart' hide AppLauncher;
import '../network/network_setup.dart';

/// HTTP/WebSocketサーバーを管理するクラス
class EYMServer {
  static const int defaultPort = 8080;
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,
  );

  HttpServer? _server;
  int _port = defaultPort;
  bool _isRunning = false;
  final Set<WebSocketChannel> _wsConnections = {};
  ShortcutConfig _currentConfig = ShortcutConfig.createDefault();
  String? _customIPAddress; // カスタムIPアドレス
  
  // ウィンドウ表示リクエスト用コールバック
  void Function()? _onShowWindowRequested;

  /// サーバーが実行中かどうか
  bool get isRunning => _isRunning;

  /// 現在のポート番号
  int get port => _port;

  /// 現在の設定
  ShortcutConfig get currentConfig => _currentConfig;

  /// サーバーを開始
  Future<bool> start({int? port}) async {
    if (_isRunning) {
      _logger.w('サーバーは既に実行中です');
      return false;
    }

    try {
      _port = port ?? defaultPort;

      // 設定を読み込み
      _currentConfig = await ShortcutStore.load();

      // ルーターを設定
      final router = _createRouter();

      // CORSヘッダーを追加
      final handler = Pipeline()
          .addMiddleware(corsHeaders())
          .addMiddleware(logRequests())
          .addHandler(router);

      // Wi-Fi接続とUSB接続の両方に対応するため、全てのIPアドレスでリッスン
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      _isRunning = true;

      final localIP = _getLocalIPAddress();
      _logger.i('EYM Agentサーバーを開始しました: http://$localIP:${_server!.port}');
      _logger.i('Wi-Fi接続: http://$localIP:${_server!.port}');
      _logger.i('USB接続: http://localhost:${_server!.port} (ADB reverse必要)');

      // UPnP自動設定を試行
      _setupUPnPAsync();

      return true;
    } catch (e, stackTrace) {
      _logger.e('サーバーの開始に失敗しました', error: e, stackTrace: stackTrace);
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
      // WebSocket接続を閉じる
      for (final connection in _wsConnections) {
        await connection.sink.close();
      }
      _wsConnections.clear();

      // ネットワーク設定をクリーンアップ
      _logger.i('ネットワーク設定をクリーンアップしています...');

      // HTTPサーバーを停止
      await _server?.close();
      _server = null;
      _isRunning = false;

      _logger.i('EYM Agentサーバーを停止しました');
    } catch (e, stackTrace) {
      _logger.e('サーバーの停止中にエラーが発生しました', error: e, stackTrace: stackTrace);
    }
  }

  /// 設定を更新
  Future<void> updateConfig(ShortcutConfig config) async {
    _currentConfig = config;
    await _broadcastShortcuts();
  }

  /// ルーターを作成
  Router _createRouter() {
    final router = Router();

    // ヘルスチェック
    router.get('/health', (Request request) {
      return Response.ok('ok');
    });

    // Ping エンドポイント（スマホ側の接続テスト用）
    router.get('/ping', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok', 'message': 'EYM Agent is running'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ショートカット一覧を取得
    router.get('/shortcuts', (Request request) {
      final message = ShortcutsMessage(
        protocolVersion: _currentConfig.protocolVersion,
        data: _currentConfig.shortcuts,
      );
      return Response.ok(
        jsonEncode(message.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // タブ情報を取得
    router.get('/tabs', (Request request) {
      final tabs = _currentConfig.tabs.map((tab) => {
        'index': tab.index,
        'name': tab.name,
      }).toList();
      
      return Response.ok(
        jsonEncode({'tabs': tabs}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ショートカット設定を保存
    router.post('/save', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        if (!json.containsKey('shortcuts')) {
          return Response.badRequest(
            body: jsonEncode({'error': 'shortcuts field is required'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final shortcuts = (json['shortcuts'] as List<dynamic>)
            .map((e) => Shortcut.fromJson(e as Map<String, dynamic>))
            .toList();

        final config = ShortcutConfig(shortcuts: shortcuts);
        final success = await ShortcutStore.save(config);

        if (success) {
          _currentConfig = config;
          await _broadcastShortcuts();

          return Response.ok(
            jsonEncode({'success': true, 'message': '設定を保存しました'}),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response.internalServerError(
            body: jsonEncode({'success': false, 'message': '設定の保存に失敗しました'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        _logger.e('設定保存中にエラーが発生しました', error: e);
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'リクエストの処理に失敗しました'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // アプリケーション起動（既存MVPとの互換性のため）
    router.post('/launch', (Request request) async {
      try {
        final body = await request.readAsString();
        _logger.i('受信したリクエスト: $body');
        final json = jsonDecode(body) as Map<String, dynamic>;

        final buttonId = json['button_id'] as int?;
        final tabIndex = json['tab_index'] as int?;
        _logger.i('ボタンID: $buttonId, タブインデックス: $tabIndex');
        
        if (buttonId == null) {
          return Response.badRequest(
            body: jsonEncode({
              'success': false,
              'message': 'button_id is required',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        _logger.i('アプリケーション起動開始: ボタンID $buttonId, タブ $tabIndex');
        final result = await _launchApplication(buttonId, tabIndex: tabIndex);
        _logger.i('起動結果: ${result.toJson()}');
        
        return Response.ok(
          jsonEncode(result.toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        _logger.e('アプリケーション起動中にエラーが発生しました', error: e);
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'リクエストの処理に失敗しました: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ウィンドウ表示エンドポイント（単一インスタンス制御用）
    router.post('/show_window', (Request request) async {
      try {
        _logger.i('ウィンドウ表示リクエストを受信しました');
        
        // ウィンドウ表示のシグナルを送信
        _onShowWindowRequested?.call();
        
        return Response.ok(
          jsonEncode({'success': true, 'message': 'ウィンドウ表示リクエストを処理しました'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        _logger.e('ウィンドウ表示リクエストの処理中にエラーが発生しました', error: e);
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': 'ウィンドウ表示に失敗しました'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // アイコンファイル配信エンドポイント
    router.get('/icon/<iconId>', (Request request, String iconId) async {
      try {
        _logger.i('アイコンリクエストを受信: $iconId');
        _logger.i('現在のショートカット数: ${_currentConfig.shortcuts.length}');
        
        // アイコンIDの形式: tab{tabIndex}_btn{buttonId}_{fileName} または {fileName}
        String? iconPath;
        
        // 新しい形式のアイコンIDかチェック
        if (iconId.contains('tab') && iconId.contains('_btn')) {
          // 新しい形式: tab{tabIndex}_btn{buttonId}_{fileName}
          final parts = iconId.split('_');
          if (parts.length >= 3) {
            final tabPart = parts[0]; // tab{tabIndex}
            final btnPart = parts[1]; // btn{buttonId}
            
            if (tabPart.startsWith('tab') && btnPart.startsWith('btn')) {
              final tabIndex = int.tryParse(tabPart.substring(3));
              final buttonId = int.tryParse(btnPart.substring(3));
              
              if (tabIndex != null && buttonId != null) {
                // 特定のタブとボタンIDでショートカットを検索
                for (final shortcut in _currentConfig.shortcuts) {
                  if (shortcut.tabIndex == tabIndex && shortcut.buttonId == buttonId) {
                    iconPath = shortcut.iconPath;
                    _logger.i('タブ$tabIndex ボタン$buttonId のアイコンパスが見つかりました: $iconPath');
                    break;
                  }
                }
              }
            }
          }
        } else {
          // 従来の形式: ファイル名のみ
          for (final shortcut in _currentConfig.shortcuts) {
            _logger.i('ショートカット確認: ${shortcut.name}, iconPath: ${shortcut.iconPath}');
            if (shortcut.iconPath != null && shortcut.iconPath!.isNotEmpty) {
              final fileName = shortcut.iconPath!.split(Platform.pathSeparator).last;
              _logger.i('ファイル名比較: $fileName vs $iconId');
              if (fileName == iconId || shortcut.iconPath!.endsWith(iconId)) {
                iconPath = shortcut.iconPath;
                _logger.i('アイコンパスが見つかりました: $iconPath');
                break;
              }
            }
          }
        }
        
        if (iconPath == null || iconPath.isEmpty) {
          _logger.w('アイコンが見つかりません: $iconId');
          _logger.w('利用可能なアイコン:');
          for (final shortcut in _currentConfig.shortcuts) {
            if (shortcut.iconPath != null && shortcut.iconPath!.isNotEmpty) {
              final fileName = shortcut.iconPath!.split(Platform.pathSeparator).last;
              _logger.w('  - ${shortcut.name}: $fileName');
            }
          }
          return Response.notFound('アイコンが見つかりません');
        }
        
        final iconFile = File(iconPath);
        if (!iconFile.existsSync()) {
          _logger.w('アイコンファイルが存在しません: $iconPath');
          return Response.notFound('アイコンファイルが存在しません');
        }
        
        // ファイルの拡張子からContent-Typeを決定
        String contentType = 'application/octet-stream';
        final extension = iconPath.toLowerCase().split('.').last;
        switch (extension) {
          case 'png':
            contentType = 'image/png';
            break;
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'ico':
            contentType = 'image/x-icon';
            break;
          case 'bmp':
            contentType = 'image/bmp';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
        }
        
        final bytes = await iconFile.readAsBytes();
        _logger.i('アイコンを配信: $iconPath (${bytes.length} bytes)');
        
        return Response.ok(
          bytes,
          headers: {
            'Content-Type': contentType,
            'Cache-Control': 'public, max-age=86400', // 24時間キャッシュ（高解像度アイコン用）
            'Accept-Ranges': 'bytes', // バイト範囲リクエストをサポート
            'Content-Length': bytes.length.toString(), // コンテンツ長を明示
            'Content-Encoding': 'identity', // 圧縮無効化（品質優先）
            'Vary': 'Accept-Encoding', // キャッシュ最適化
            'ETag': '"${bytes.length}-${iconPath.hashCode}"', // ETagでキャッシュ効率化
          },
        );
      } catch (e) {
        _logger.e('アイコン配信中にエラーが発生しました', error: e);
        return Response.internalServerError(
          body: 'アイコンの配信に失敗しました',
        );
      }
    });

    // WebSocket接続
    router.get('/ws', webSocketHandler(_handleWebSocket));

    return router;
  }

  /// WebSocket接続を処理
  void _handleWebSocket(WebSocketChannel webSocket) {
    _wsConnections.add(webSocket);
    _logger.i('WebSocket接続が確立されました (接続数: ${_wsConnections.length})');

    // 接続時にショートカット一覧を送信
    _sendShortcutsToConnection(webSocket);

    // メッセージを受信
    webSocket.stream.listen(
      (message) async {
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          await _handleWebSocketMessage(webSocket, json);
        } catch (e) {
          _logger.e('WebSocketメッセージの処理中にエラーが発生しました', error: e);
          _sendErrorToConnection(webSocket, 'メッセージの処理に失敗しました');
        }
      },
      onDone: () {
        _wsConnections.remove(webSocket);
        _logger.i('WebSocket接続が切断されました (接続数: ${_wsConnections.length})');
      },
      onError: (error) {
        _logger.e('WebSocket接続でエラーが発生しました', error: error);
        _wsConnections.remove(webSocket);
      },
    );
  }

  /// WebSocketメッセージを処理
  Future<void> _handleWebSocketMessage(
    WebSocketChannel webSocket,
    Map<String, dynamic> json,
  ) async {
    final type = json['type'] as String?;

    switch (type) {
      case 'launch':
        final id = json['id'] as int?;
        if (id != null) {
          final result = await _launchApplication(id);
          webSocket.sink.add(jsonEncode(result.toJson()));
        } else {
          _sendErrorToConnection(
            webSocket,
            'id field is required for launch message',
          );
        }
        break;

      case 'ping':
        webSocket.sink.add(jsonEncode(const PongMessage().toJson()));
        break;

      default:
        _logger.w('未知のメッセージタイプ: $type');
        _sendErrorToConnection(webSocket, '未知のメッセージタイプです');
    }
  }

  /// アプリケーションを起動
  Future<ResultMessage> _launchApplication(int buttonId, {int? tabIndex}) async {
    // タブインデックスが指定されている場合は、そのタブのショートカットを検索
    Shortcut? shortcut;
    if (tabIndex != null) {
      _logger.i('タブ$tabIndex のボタン$buttonId を検索中...');
      _logger.i('利用可能なショートカット:');
      for (final s in _currentConfig.shortcuts) {
        _logger.i('  - タブ${s.tabIndex} ボタン${s.buttonId}: ${s.name}');
      }
      
      try {
        shortcut = _currentConfig.shortcuts.firstWhere(
          (s) => s.buttonId == buttonId && s.tabIndex == tabIndex,
        );
        _logger.i('検索結果: ${shortcut.name}');
      } catch (e) {
        _logger.w('タブ$tabIndex のボタン$buttonId が見つかりませんでした');
        shortcut = null;
      }
    } else {
      // 従来の方法（タブ0のショートカットを検索）
      _logger.i('従来の方法でボタン$buttonId を検索中...');
      shortcut = _currentConfig.getShortcut(buttonId);
    }
    
    if (shortcut == null) {
      final message = tabIndex != null 
          ? 'タブ$tabIndex のボタンID $buttonId のショートカットが見つかりません'
          : 'ボタンID $buttonId のショートカットが見つかりません';
      _logger.w(message);
      return ResultMessage(
        id: buttonId,
        success: false,
        message: message,
      );
    }

    _logger.i('ショートカット実行: ${shortcut.name} (${shortcut.path})');
    return await AppLauncher.launch(shortcut);
  }

  /// 全WebSocket接続にショートカット一覧を送信
  Future<void> _broadcastShortcuts() async {
    final message = ShortcutsMessage(
      protocolVersion: _currentConfig.protocolVersion,
      data: _currentConfig.shortcuts,
    );

    final jsonString = jsonEncode(message.toJson());
    final deadConnections = <WebSocketChannel>[];

    for (final connection in _wsConnections) {
      try {
        connection.sink.add(jsonString);
      } catch (e) {
        _logger.w('WebSocket接続への送信に失敗しました', error: e);
        deadConnections.add(connection);
      }
    }

    // 無効な接続を削除
    for (final connection in deadConnections) {
      _wsConnections.remove(connection);
    }
  }

  /// 特定のWebSocket接続にショートカット一覧を送信
  void _sendShortcutsToConnection(WebSocketChannel webSocket) {
    try {
      final message = ShortcutsMessage(
        protocolVersion: _currentConfig.protocolVersion,
        data: _currentConfig.shortcuts,
      );
      webSocket.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      _logger.e('ショートカット一覧の送信に失敗しました', error: e);
    }
  }

  /// 特定のWebSocket接続にエラーメッセージを送信
  void _sendErrorToConnection(WebSocketChannel webSocket, String message) {
    try {
      final errorMessage = {'type': 'error', 'message': message};
      webSocket.sink.add(jsonEncode(errorMessage));
    } catch (e) {
      _logger.e('エラーメッセージの送信に失敗しました', error: e);
    }
  }

  /// サーバーの情報を取得
  Map<String, dynamic> getServerInfo() {
    final localIP = _getLocalIPAddress();
    return {
      'isRunning': _isRunning,
      'port': _port,
      'url': _isRunning ? 'http://$localIP:$_port' : null,
      'localUrl': _isRunning ? 'http://localhost:$_port' : null,
      'wifiUrl': _isRunning ? 'http://$localIP:$_port' : null,
      'adbCommand': 'adb reverse tcp:12345 tcp:$_port',
      'connectionType': 'Wi-Fi & USB',
      'wsConnections': _wsConnections.length,
      'shortcuts': _currentConfig.shortcuts.length,
    };
  }

  /// IPアドレスを更新
  Future<void> updateIPAddress(String ipAddress) async {
    _customIPAddress = ipAddress;
    _logger.i('IPアドレスを更新しました: $ipAddress');
  }

  /// ウィンドウ表示リクエストのコールバックを設定
  void setShowWindowCallback(void Function() callback) {
    _onShowWindowRequested = callback;
  }

  /// ローカルIPアドレスを取得（同期版）
  String _getLocalIPAddress() {
    // カスタムIPアドレスが設定されている場合はそれを使用
    if (_customIPAddress != null && _customIPAddress!.isNotEmpty) {
      _logger.i('カスタムIPアドレスを使用: $_customIPAddress');
      return _customIPAddress!;
    }

    try {
      // デフォルトIPアドレス（ipconfig結果に基づく）
      _logger.i('デフォルトIPアドレスを使用: 192.168.11.10');
      return '192.168.11.10';
      
    } catch (e) {
      _logger.w('IPアドレスの取得に失敗しました: $e');
    }
    
    // フォールバック: localhostを返す
    _logger.w('ローカルIPアドレスが見つかりません。localhostを使用します。');
    return 'localhost';
  }

  /// ネットワーク自動設定を非同期で実行
  void _setupUPnPAsync() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        _logger.i('ネットワーク自動設定を開始します...');
        final success = await NetworkSetup.setupNetwork(port: _port);
        
        if (success) {
          _logger.i('✅ ネットワーク自動設定が成功しました！');
        } else {
          _logger.w('⚠️ ネットワーク自動設定に失敗しました。手動でファイアウォール設定が必要です。');
        }
      } catch (e) {
        _logger.e('ネットワーク自動設定中にエラーが発生しました', error: e);
      }
    });
  }
}
