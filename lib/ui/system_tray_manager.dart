import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// システムトレイ管理クラス
class SystemTrayManager {
  static final Logger _logger = Logger();
  static final SystemTray _systemTray = SystemTray();
  static bool _isInitialized = false;
  static String? _iconPath;

  /// システムトレイを初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('システムトレイを初期化中...');

      // アイコンファイルを準備
      final iconPath = await _prepareIconFile();
      if (iconPath == null) {
        _logger.e('システムトレイアイコンの準備に失敗しました');
        return;
      }

      _logger.i('システムトレイアイコンパス: $iconPath');

      // システムトレイアイコンを設定
      await _systemTray.initSystemTray(title: "EYM Agent", iconPath: iconPath);

      // コンテキストメニューを設定
      await _setupContextMenu();

      _isInitialized = true;
      _logger.i('✅ システムトレイの初期化が完了しました');
    } catch (e) {
      _logger.e('システムトレイ初期化エラー', error: e);
      // 初期化に失敗してもアプリケーションは継続
    }
  }

  /// アイコンファイルを準備
  static Future<String?> _prepareIconFile() async {
    try {
      // キャッシュされたアイコンパスがあれば使用
      if (_iconPath != null && File(_iconPath!).existsSync()) {
        return _iconPath;
      }

      // 一時ディレクトリにアイコンファイルを作成
      final tempDir = await getTemporaryDirectory();
      final iconFile = File(path.join(tempDir.path, 'qrsc_pc_tray.ico'));

      // アイコンファイルが既に存在する場合は使用
      if (iconFile.existsSync()) {
        _iconPath = iconFile.path;
        return _iconPath;
      }

      // シンプルなICOファイルを生成
      final iconData = _generateSimpleIcon();
      await iconFile.writeAsBytes(iconData);

      _iconPath = iconFile.path;
      _logger.i('システムトレイアイコンを生成しました: ${_iconPath}');
      return _iconPath;
    } catch (e) {
      _logger.e('アイコンファイル準備エラー', error: e);

      // フォールバック: 実行ファイルのアイコンを使用
      try {
        return Platform.resolvedExecutable;
      } catch (e2) {
        _logger.e('フォールバックアイコン取得エラー', error: e2);
        return null;
      }
    }
  }

  /// シンプルなICOファイルを生成
  static Uint8List _generateSimpleIcon() {
    // 16x16の最小限のICOファイルを生成
    // ICOファイルヘッダー + 1つのアイコンエントリ + ビットマップデータ
    final List<int> iconData = [];

    // ICOファイルヘッダー (6バイト)
    iconData.addAll([0x00, 0x00]); // Reserved (0)
    iconData.addAll([0x01, 0x00]); // Type (1 = ICO)
    iconData.addAll([0x01, 0x00]); // Count (1 icon)

    // アイコンディレクトリエントリ (16バイト)
    iconData.add(0x10); // Width (16)
    iconData.add(0x10); // Height (16)
    iconData.add(0x00); // Color count (0 = 256 colors)
    iconData.add(0x00); // Reserved
    iconData.addAll([0x01, 0x00]); // Color planes (1)
    iconData.addAll([0x20, 0x00]); // Bits per pixel (32)
    iconData.addAll([
      0x00,
      0x04,
      0x00,
      0x00,
    ]); // Size of bitmap data (1024 bytes)
    iconData.addAll([0x16, 0x00, 0x00, 0x00]); // Offset to bitmap data (22)

    // ビットマップヘッダー (40バイト)
    iconData.addAll([0x28, 0x00, 0x00, 0x00]); // Header size (40)
    iconData.addAll([0x10, 0x00, 0x00, 0x00]); // Width (16)
    iconData.addAll([0x20, 0x00, 0x00, 0x00]); // Height (32 = 16*2 for ICO)
    iconData.addAll([0x01, 0x00]); // Planes (1)
    iconData.addAll([0x20, 0x00]); // Bits per pixel (32)
    iconData.addAll([0x00, 0x00, 0x00, 0x00]); // Compression (0)
    iconData.addAll([0x00, 0x04, 0x00, 0x00]); // Image size (1024)
    iconData.addAll([0x00, 0x00, 0x00, 0x00]); // X pixels per meter
    iconData.addAll([0x00, 0x00, 0x00, 0x00]); // Y pixels per meter
    iconData.addAll([0x00, 0x00, 0x00, 0x00]); // Colors used
    iconData.addAll([0x00, 0x00, 0x00, 0x00]); // Important colors

    // ピクセルデータ (16x16 = 256 pixels, 4 bytes each = 1024 bytes)
    // シンプルな青いアイコンを作成
    for (int y = 0; y < 16; y++) {
      for (int x = 0; x < 16; x++) {
        if ((x >= 2 && x <= 13) && (y >= 2 && y <= 13)) {
          // 内側: 青色 (BGRA format)
          iconData.addAll([0xFF, 0x80, 0x00, 0xFF]); // Blue
        } else {
          // 外側: 透明
          iconData.addAll([0x00, 0x00, 0x00, 0x00]); // Transparent
        }
      }
    }

    // ANDマスク (16x16 bits = 32 bytes)
    for (int i = 0; i < 32; i++) {
      iconData.add(0x00); // すべて表示
    }

    return Uint8List.fromList(iconData);
  }

  /// コンテキストメニューを設定
  static Future<void> _setupContextMenu() async {
    final Menu menu = Menu();

    // サーバー状態表示
    await menu.buildFrom([
      MenuItemLabel(label: 'EYM Agent', enabled: false),
      MenuSeparator(),
      MenuItemLabel(label: '🟢 サーバー実行中', enabled: false),
      MenuItemLabel(label: 'ポート: 8080', enabled: false),
      MenuSeparator(),
      MenuItemLabel(
        label: '📱 ウィンドウを表示',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuItemLabel(
        label: '📋 QRコードを表示',
        onClicked: (menuItem) => _showQRCode(),
      ),
      MenuItemLabel(label: '⚙️ 設定', onClicked: (menuItem) => _showSettings()),
      MenuSeparator(),
      MenuItemLabel(
        label: '🔄 サーバー再起動',
        onClicked: (menuItem) => _restartServer(),
      ),
      MenuItemLabel(label: '⏹️ サーバー停止', onClicked: (menuItem) => _stopServer()),
      MenuSeparator(),
      MenuItemLabel(label: '❌ 終了', onClicked: (menuItem) => _exitApplication()),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// サーバー状態に応じてメニューを更新
  static Future<void> updateServerStatus(bool isRunning, int port) async {
    if (!_isInitialized) return;

    try {
      final Menu menu = Menu();

      await menu.buildFrom([
        MenuItemLabel(label: 'EYM Agent', enabled: false),
        MenuSeparator(),
        MenuItemLabel(
          label: isRunning ? '🟢 サーバー実行中' : '🔴 サーバー停止中',
          enabled: false,
        ),
        MenuItemLabel(label: 'ポート: $port', enabled: false),
        MenuSeparator(),
        MenuItemLabel(
          label: '📱 ウィンドウを表示',
          onClicked: (menuItem) => _showWindow(),
        ),
        MenuItemLabel(
          label: '📋 QRコードを表示',
          onClicked: (menuItem) => _showQRCode(),
          enabled: isRunning,
        ),
        MenuItemLabel(label: '⚙️ 設定', onClicked: (menuItem) => _showSettings()),
        MenuSeparator(),
        MenuItemLabel(
          label: isRunning ? '🔄 サーバー再起動' : '▶️ サーバー開始',
          onClicked: (menuItem) =>
              isRunning ? _restartServer() : _startServer(),
        ),
        if (isRunning)
          MenuItemLabel(
            label: '⏹️ サーバー停止',
            onClicked: (menuItem) => _stopServer(),
          ),
        MenuSeparator(),
        MenuItemLabel(
          label: '❌ 終了',
          onClicked: (menuItem) => _exitApplication(),
        ),
      ]);

      await _systemTray.setContextMenu(menu);

      // トレイアイコンのツールチップを更新
      await _systemTray.setToolTip(
        isRunning ? 'EYM Agent - 実行中 (ポート: $port)' : 'EYM Agent - 停止中',
      );
    } catch (e) {
      _logger.e('システムトレイメニュー更新エラー', error: e);
    }
  }

  /// ウィンドウを表示
  static Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      _logger.i('ウィンドウを表示しました');
    } catch (e) {
      _logger.e('ウィンドウ表示エラー', error: e);
    }
  }

  /// QRコードダイアログを表示
  static Future<void> _showQRCode() async {
    try {
      await _showWindow();
      // QRコードダイアログの表示は、メインウィンドウで処理
      _logger.i('QRコード表示を要求しました');
    } catch (e) {
      _logger.e('QRコード表示エラー', error: e);
    }
  }

  /// 設定画面を表示
  static Future<void> _showSettings() async {
    try {
      await _showWindow();
      // 設定画面の表示は、メインウィンドウで処理
      _logger.i('設定画面表示を要求しました');
    } catch (e) {
      _logger.e('設定画面表示エラー', error: e);
    }
  }

  /// サーバーを開始
  static Future<void> _startServer() async {
    try {
      _logger.i('システムトレイからサーバー開始を要求');
      // サーバー開始処理は、メインアプリケーションで処理
    } catch (e) {
      _logger.e('サーバー開始エラー', error: e);
    }
  }

  /// サーバーを再起動
  static Future<void> _restartServer() async {
    try {
      _logger.i('システムトレイからサーバー再起動を要求');
      // サーバー再起動処理は、メインアプリケーションで処理
    } catch (e) {
      _logger.e('サーバー再起動エラー', error: e);
    }
  }

  /// サーバーを停止
  static Future<void> _stopServer() async {
    try {
      _logger.i('システムトレイからサーバー停止を要求');
      // サーバー停止処理は、メインアプリケーションで処理
    } catch (e) {
      _logger.e('サーバー停止エラー', error: e);
    }
  }

  /// アプリケーションを終了
  static Future<void> _exitApplication() async {
    try {
      _logger.i('システムトレイからアプリケーション終了を要求');
      await dispose();
      exit(0);
    } catch (e) {
      _logger.e('アプリケーション終了エラー', error: e);
    }
  }

  /// ウィンドウを最小化してトレイに隠す
  static Future<void> hideToTray() async {
    try {
      await windowManager.hide();
      _logger.i('ウィンドウをシステムトレイに最小化しました');
    } catch (e) {
      _logger.e('トレイ最小化エラー', error: e);
    }
  }

  /// 通知を表示
  static Future<void> showNotification(String title, String message) async {
    try {
      await _systemTray.popUpContextMenu();
      _logger.i('通知を表示: $title - $message');
    } catch (e) {
      _logger.e('通知表示エラー', error: e);
    }
  }

  /// システムトレイを破棄
  static Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _systemTray.destroy();
      _isInitialized = false;
      _logger.i('システムトレイを破棄しました');
    } catch (e) {
      _logger.e('システムトレイ破棄エラー', error: e);
    }
  }
}
