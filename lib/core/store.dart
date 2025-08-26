import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'models.dart';

/// ショートカット設定の永続化を管理するクラス
class ShortcutStore {
  static const String _fileName = 'shortcuts.json';
  static final Logger _logger = Logger();
  
  /// 設定ファイルのパスを取得
  static Future<String> get _filePath async {
    try {
      final directory = await getApplicationSupportDirectory();
      final filePath = '${directory.path}${Platform.pathSeparator}$_fileName';
      _logger.i('設定ファイルパス: $filePath');
      return filePath;
    } catch (e) {
      _logger.e('ApplicationSupportDirectoryの取得に失敗、フォールバック使用', error: e);
      // フォールバック: 実行ファイルと同じディレクトリに保存
      final executablePath = Platform.resolvedExecutable;
      final executableDir = File(executablePath).parent.path;
      final fallbackPath = '$executableDir${Platform.pathSeparator}$_fileName';
      _logger.i('フォールバック設定ファイルパス: $fallbackPath');
      return fallbackPath;
    }
  }

  /// ショートカット設定を読み込み
  static Future<ShortcutConfig> load() async {
    try {
      final path = await _filePath;
      final file = File(path);
      
      if (!await file.exists()) {
        _logger.i('設定ファイルが存在しません。デフォルト設定を作成します: $path');
        final defaultConfig = ShortcutConfig.createDefault();
        await save(defaultConfig);
        return defaultConfig;
      }

      final jsonString = await file.readAsString();
      final config = ShortcutConfig.fromJsonString(jsonString);
      _logger.i('設定ファイルを読み込みました: $path');
      return config;
    } catch (e, stackTrace) {
      _logger.e('設定ファイルの読み込みに失敗しました', error: e, stackTrace: stackTrace);
      // エラーが発生した場合はデフォルト設定を返す
      return ShortcutConfig.createDefault();
    }
  }

  /// ショートカット設定を保存
  static Future<bool> save(ShortcutConfig config) async {
    try {
      final path = await _filePath;
      final file = File(path);
      
      // ディレクトリが存在しない場合は作成
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final jsonString = config.toJsonString();
      await file.writeAsString(jsonString);
      _logger.i('設定ファイルを保存しました: $path');
      return true;
    } catch (e, stackTrace) {
      _logger.e('設定ファイルの保存に失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 設定ファイルのバックアップを作成
  static Future<bool> backup() async {
    try {
      final path = await _filePath;
      final file = File(path);
      
      if (!await file.exists()) {
        _logger.w('バックアップ対象のファイルが存在しません: $path');
        return false;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${path}.backup.$timestamp';
      await file.copy(backupPath);
      _logger.i('設定ファイルのバックアップを作成しました: $backupPath');
      return true;
    } catch (e, stackTrace) {
      _logger.e('バックアップの作成に失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 設定ファイルが存在するかチェック
  static Future<bool> exists() async {
    try {
      final path = await _filePath;
      final file = File(path);
      return await file.exists();
    } catch (e) {
      _logger.e('設定ファイルの存在確認に失敗しました', error: e);
      return false;
    }
  }

  /// 設定ファイルを削除（リセット）
  static Future<bool> reset() async {
    try {
      final path = await _filePath;
      final file = File(path);
      
      if (await file.exists()) {
        await file.delete();
        _logger.i('設定ファイルを削除しました: $path');
      }
      return true;
    } catch (e, stackTrace) {
      _logger.e('設定ファイルの削除に失敗しました', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 設定ファイルのパスを取得（デバッグ用）
  static Future<String> getFilePath() async {
    return await _filePath;
  }
}

/// アプリケーション起動機能を提供するクラス
class AppLauncher {
  static final Logger _logger = Logger();

  /// アプリケーションを起動
  static Future<ResultMessage> launch(Shortcut shortcut) async {
    try {
      if (shortcut.path.isEmpty) {
        return ResultMessage(
          id: shortcut.buttonId,
          success: false,
          message: 'アプリケーションパスが設定されていません',
        );
      }

      _logger.i('アプリケーションを起動します: ${shortcut.name} (${shortcut.path})');

      Process process;
      
      if (Platform.isWindows) {
        // Windows: 直接実行またはcmdを使用
        if (shortcut.path.toLowerCase().endsWith('.exe') || 
            shortcut.path.toLowerCase().endsWith('.bat') ||
            shortcut.path.toLowerCase().endsWith('.cmd')) {
          process = await Process.start(
            shortcut.path,
            shortcut.args,
            mode: ProcessStartMode.detached,
          );
        } else {
          // URLやその他のファイルはcmdで開く
          process = await Process.start(
            'cmd',
            ['/c', 'start', '""', shortcut.path, ...shortcut.args],
            mode: ProcessStartMode.detached,
          );
        }
      } else if (Platform.isMacOS) {
        // macOS: openコマンドを使用
        process = await Process.start(
          'open',
          [shortcut.path, ...shortcut.args],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isLinux) {
        // Linux: xdg-openを使用
        process = await Process.start(
          'xdg-open',
          [shortcut.path, ...shortcut.args],
          mode: ProcessStartMode.detached,
        );
      } else {
        return ResultMessage(
          id: shortcut.buttonId,
          success: false,
          message: 'サポートされていないプラットフォームです',
        );
      }

      _logger.i('アプリケーションの起動に成功しました: ${shortcut.name} (PID: ${process.pid})');
      
      return ResultMessage(
        id: shortcut.buttonId,
        success: true,
        message: 'アプリケーションを起動しました',
      );
    } catch (e, stackTrace) {
      _logger.e('アプリケーションの起動に失敗しました: ${shortcut.name}', 
                error: e, stackTrace: stackTrace);
      
      return ResultMessage(
        id: shortcut.buttonId,
        success: false,
        message: 'アプリケーションの起動に失敗しました: ${e.toString()}',
      );
    }
  }

  /// パスが有効かチェック
  static Future<bool> isValidPath(String path) async {
    if (path.isEmpty) return false;

    try {
      // URLの場合
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return true;
      }

      // ファイルパスの場合
      final file = File(path);
      if (await file.exists()) {
        return true;
      }

      // ディレクトリの場合
      final directory = Directory(path);
      if (await directory.exists()) {
        return true;
      }

      // Windowsの場合、システムコマンドかチェック
      if (Platform.isWindows) {
        // 拡張子がない場合は.exeを追加してチェック
        if (!path.contains('.')) {
          final exePath = '$path.exe';
          final exeFile = File(exePath);
          if (await exeFile.exists()) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      _logger.w('パスの検証中にエラーが発生しました: $path', error: e);
      return false;
    }
  }

  /// ファイルの種類を判定
  static String getFileType(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return 'URL';
    }

    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'exe':
        return 'アプリケーション';
      case 'bat':
      case 'cmd':
        return 'バッチファイル';
      case 'lnk':
        return 'ショートカット';
      case 'app':
        return 'macOSアプリケーション';
      case 'dmg':
        return 'ディスクイメージ';
      case 'deb':
      case 'rpm':
      case 'appimage':
        return 'Linuxパッケージ';
      default:
        return 'ファイル';
    }
  }
}
