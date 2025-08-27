import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:libserialport/libserialport.dart';
import 'package:logger/logger.dart';
import '../core/models.dart';
import '../core/store.dart' hide AppLauncher;

// libserialportが利用可能かどうかをチェック
const bool _isLibSerialPortAvailable = true; // USB接続対応のため有効化

/// USBシリアル通信サーバー（条件付きコンパイル対応）
class UsbSerialServer {
  static final Logger _logger = Logger();
  
  SerialPort? _port;
  bool _isRunning = false;
  ShortcutConfig _currentConfig = ShortcutConfig.createDefault();
  
  /// サーバーが実行中かどうか
  bool get isRunning => _isRunning;
  
  /// 現在の設定
  ShortcutConfig get currentConfig => _currentConfig;

  /// USBシリアルサーバーを開始
  Future<bool> start() async {
    if (!_isLibSerialPortAvailable) {
      _logger.w('USBシリアル機能は現在無効化されています（libserialportパッケージが利用できません）');
      return false;
    }

    if (_isRunning) {
      _logger.w('USBシリアルサーバーは既に実行中です');
      return false;
    }

    try {
      // 設定を読み込み
      _currentConfig = await ShortcutStore.load();

      // 利用可能なシリアルポートを検索
      final availablePorts = SerialPort.availablePorts;
      _logger.i('利用可能なシリアルポート: $availablePorts');

      if (availablePorts.isEmpty) {
        _logger.e('利用可能なシリアルポートがありません');
        return false;
      }

      // Android ADB接続を探す（通常はCOMポートとして認識される）
      String? targetPort;
      for (final portName in availablePorts) {
        final port = SerialPort(portName);
        final description = port.description ?? '';
        
        // Android ADB Interfaceまたは類似のデバイスを探す
        if (description.toLowerCase().contains('android') ||
            description.toLowerCase().contains('adb') ||
            description.toLowerCase().contains('composite')) {
          targetPort = portName;
          _logger.i('Android デバイスを発見: $portName ($description)');
          break;
        }
      }

      // 見つからない場合は最初のポートを使用
      targetPort ??= availablePorts.first;
      
      _port = SerialPort(targetPort);
      
      // シリアルポート設定
      final config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);
      
      _port!.config = config;
      
      // ポートを開く
      if (!_port!.openReadWrite()) {
        _logger.e('シリアルポートを開けませんでした: ${SerialPort.lastError}');
        return false;
      }

      _isRunning = true;
      _logger.i('USBシリアルサーバーを開始しました: $targetPort');
      
      // データ受信を開始
      _startListening();
      
      // 接続確認メッセージを送信
      _sendMessage({
        'type': 'connected',
        'message': 'QRSC_PC USB接続が確立されました',
        'shortcuts': _currentConfig.shortcuts.length,
      });

      return true;
    } catch (e, stackTrace) {
      _logger.e('USBシリアルサーバーの開始に失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// サーバーを停止
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.w('USBシリアルサーバーは実行されていません');
      return;
    }

    try {
      _port?.close();
      _port = null;
      _isRunning = false;
      _logger.i('USBシリアルサーバーを停止しました');
    } catch (e, stackTrace) {
      _logger.e('USBシリアルサーバーの停止中にエラーが発生しました', error: e, stackTrace: stackTrace);
    }
  }

  /// データ受信を開始
  void _startListening() {
    if (!_isLibSerialPortAvailable || _port == null) return;

    // ポーリングでデータ受信（libserialport 0.3.0+1のAPI）
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRunning || _port == null) {
        timer.cancel();
        return;
      }

      try {
        final data = _port!.read(1024);
        
        if (data.isNotEmpty) {
          final message = utf8.decode(data);
          _handleMessage(message);
        }
      } catch (e) {
        _logger.e('シリアルポート読み取りエラー', error: e);
        timer.cancel();
        _isRunning = false;
      }
    });
  }

  /// メッセージを処理
  Future<void> _handleMessage(String message) async {
    if (!_isLibSerialPortAvailable) return;
    
    try {
      final json = jsonDecode(message.trim()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      _logger.i('受信メッセージ: $type');

      switch (type) {
        case 'ping':
          _sendMessage({
            'type': 'pong',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          break;

        case 'get_shortcuts':
          _sendShortcuts();
          break;

        case 'launch':
          final buttonId = json['button_id'] as int?;
          if (buttonId != null) {
            final result = await _launchApplication(buttonId);
            _sendMessage(result.toJson());
          } else {
            _sendError('button_id is required for launch command');
          }
          break;

        default:
          _logger.w('未知のメッセージタイプ: $type');
          _sendError('Unknown message type: $type');
      }
    } catch (e) {
      _logger.e('メッセージ解析エラー', error: e);
      _sendError('Failed to parse message: $e');
    }
  }

  /// ショートカット一覧を送信
  void _sendShortcuts() {
    if (!_isLibSerialPortAvailable) return;
    
    final message = ShortcutsMessage(
      protocolVersion: _currentConfig.protocolVersion,
      data: _currentConfig.shortcuts,
    );
    _sendMessage(message.toJson());
  }

  /// アプリケーションを起動
  Future<ResultMessage> _launchApplication(int buttonId) async {
    final shortcut = _currentConfig.getShortcut(buttonId);
    if (shortcut == null) {
      return ResultMessage(
        id: buttonId,
        success: false,
        message: 'ボタンID $buttonId のショートカットが見つかりません',
      );
    }

    _logger.i('アプリケーション起動: ${shortcut.name}');
    return await AppLauncher.launch(shortcut);
  }

  /// メッセージを送信
  void _sendMessage(Map<String, dynamic> message) {
    if (!_isLibSerialPortAvailable || _port == null || !_isRunning) return;

    try {
      final jsonString = jsonEncode(message);
      final data = utf8.encode('$jsonString\n'); // 改行文字で区切り
      
      final bytesWritten = _port!.write(Uint8List.fromList(data));
      _logger.d('送信完了: $bytesWritten bytes');
    } catch (e) {
      _logger.e('メッセージ送信エラー', error: e);
    }
  }

  /// エラーメッセージを送信
  void _sendError(String errorMessage) {
    _sendMessage({
      'type': 'error',
      'message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 設定を更新
  Future<void> updateConfig(ShortcutConfig config) async {
    _currentConfig = config;
    if (_isLibSerialPortAvailable) {
      _sendShortcuts(); // 更新されたショートカット一覧を送信
    }
  }

  /// サーバーの情報を取得
  Map<String, dynamic> getServerInfo() {
    return {
      'isRunning': _isRunning,
      'portName': _isLibSerialPortAvailable ? (_port?.toString() ?? 'None') : 'Disabled',
      'connectionType': 'USB Serial',
      'shortcuts': _currentConfig.shortcuts.length,
      'baudRate': 0,
      'status': _isLibSerialPortAvailable ? 'Available' : 'Disabled (libserialport not available)',
    };
  }

  /// 利用可能なシリアルポート一覧を取得
  static List<Map<String, String>> getAvailablePorts() {
    if (!_isLibSerialPortAvailable) {
      return [
        {
          'name': 'N/A',
          'description': 'libserialportパッケージが無効化されています',
          'manufacturer': 'N/A',
        }
      ];
    }
    
    final ports = <Map<String, String>>[];
    
    try {
      for (final portName in SerialPort.availablePorts) {
        final port = SerialPort(portName);
        ports.add({
          'name': portName,
          'description': port.description ?? 'Unknown',
          'manufacturer': port.manufacturer ?? 'Unknown',
        });
      }
    } catch (e) {
      _logger.e('シリアルポート一覧取得エラー', error: e);
    }
    
    return ports;
  }
}
