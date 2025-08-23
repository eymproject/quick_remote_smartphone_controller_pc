import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'app_state.dart';
import 'qr_code_dialog.dart';
import 'system_tray_manager.dart';
import '../utils/firewall_manager.dart';
import '../core/models.dart';
import '../utils/icon_extractor.dart';
import '../utils/image_processor.dart';

/// メイン画面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WindowListener, TickerProviderStateMixin {
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _pathControllers = [];
  final List<TextEditingController> _iconControllers = []; // アイコンパス管理用
  bool _isDragging = false;

  // タブ管理用の変数
  late TabController _tabController;
  int _totalTabs = 1; // 初期は2つのタブ
  List<TabInfo> _tabInfos = []; // タブ情報リスト

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeSystemTray();
    _initializeControllers();
    _initializeTabController();

    // アプリ起動時にアイコンキャッシュをクリアして強制的にリフレッシュ
    _clearIconCacheOnStartup();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tabController.dispose();
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    for (final controller in _pathControllers) {
      controller.dispose();
    }
    for (final controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    final appState = context.read<AppState>();

    // 全てのショートカットを取得（タブ別に整理）
    final allShortcuts = appState.config.shortcuts;
    final maxTabIndex = allShortcuts.isEmpty
        ? 0
        : allShortcuts.map((s) => s.tabIndex).reduce((a, b) => a > b ? a : b);
    _totalTabs = maxTabIndex;

    // 最小2つのタブを保証
    if (_totalTabs < 1) {
      _totalTabs = 1;
    }

    print('🚀 アプリ初期化開始: ${allShortcuts.length}個のショートカットを読み込み');
    print('🚀 読み込まれたショートカット一覧:');
    for (final s in allShortcuts) {
      print(
        '  - タブ${s.tabIndex}, ボタン${s.buttonId}: ${s.name}, パス: ${s.path}, アイコン: ${s.iconPath}',
      );
    }

    // タブ情報を初期化
    _tabInfos = List.generate(_totalTabs, (index) {
      final tabInfo = appState.config.getTabInfo(index);
      return tabInfo ?? TabInfo(index: index, name: 'タブ ${index + 1}');
    });

    print('🚀 タブ情報初期化: $_totalTabs個のタブ');
    for (int i = 0; i < _tabInfos.length; i++) {
      print('  - タブ$i: ${_tabInfos[i].name}');
    }

    // 各タブの6つのボタン分のコントローラーを作成
    for (int tabIndex = 0; tabIndex < _totalTabs; tabIndex++) {
      for (int buttonIndex = 0; buttonIndex < 6; buttonIndex++) {
        final buttonId = (tabIndex * 6) + buttonIndex + 1;
        final relativeButtonId = buttonIndex + 1;

        final shortcut = allShortcuts.firstWhere(
          (s) => s.tabIndex == tabIndex && s.buttonId == relativeButtonId,
          orElse: () {
            print('🚀 デフォルトショートカット作成: タブ$tabIndex, ボタン$relativeButtonId');
            return Shortcut(
              buttonId: relativeButtonId,
              name: '$relativeButtonId',
              path: '',
              tabIndex: tabIndex,
            );
          },
        );

        final nameController = TextEditingController(text: shortcut.name);
        final pathController = TextEditingController(text: shortcut.path);
        final iconController = TextEditingController(
          text: shortcut.iconPath ?? '',
        ); // アイコンパス用

        // テキスト変更時の自動保存リスナーを追加
        nameController.addListener(() => _autoSave());
        pathController.addListener(() => _autoSaveAndExtractIcon(buttonId));

        _nameControllers.add(nameController);
        _pathControllers.add(pathController);
        _iconControllers.add(iconController); // アイコンコントローラーを追加
      }
    }
  }

  /// TabControllerを初期化
  void _initializeTabController() {
    _tabController = TabController(length: _totalTabs, vsync: this);
  }

  /// 自動保存（デバウンス付き）
  void _autoSave() {
    // 短時間での連続保存を防ぐため、少し遅延させる
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _saveSettingsQuietly();
      }
    });
  }

  /// 自動保存（デバウンス付き）
  void _autoSaveAndExtractIcon(int buttonId) {
    // 短時間での連続保存を防ぐため、少し遅延させる
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _saveSettingsQuietly();
        // パスが設定されている場合はアイコンを自動抽出
        final index = buttonId - 1;
        if (index < _pathControllers.length) {
          final path = _pathControllers[index].text.trim();
          if (path.isNotEmpty &&
              !path.startsWith('http') &&
              path.toLowerCase().endsWith('.exe')) {
            _extractIconForShortcut(buttonId, path);
          }
        }
      }
    });
  }

  /// 静かに設定を保存（SnackBarを表示しない）
  Future<void> _saveSettingsQuietly() async {
    final appState = context.read<AppState>();
    final shortcuts = <Shortcut>[];

    // 全タブの全ショートカットを保存
    for (int tabIndex = 0; tabIndex < _totalTabs; tabIndex++) {
      for (int buttonIndex = 0; buttonIndex < 6; buttonIndex++) {
        final controllerIndex = (tabIndex * 6) + buttonIndex;
        if (controllerIndex < _nameControllers.length) {
          final name = _nameControllers[controllerIndex].text.trim();
          final path = _pathControllers[controllerIndex].text.trim();
          final buttonId = buttonIndex + 1; // 各タブ内での相対的なボタンID (1-6)

          // 既存のショートカットからアイコンパスを取得
          final existingShortcut = appState.config.shortcuts.firstWhere(
            (s) => s.tabIndex == tabIndex && s.buttonId == buttonId,
            orElse: () => Shortcut(
              buttonId: buttonId,
              name: '',
              path: '',
              tabIndex: tabIndex,
            ),
          );

          shortcuts.add(
            Shortcut(
              buttonId: buttonId,
              name: name.isEmpty ? '$buttonId' : name,
              path: path,
              args: [], // 引数は空のリストに固定
              tabIndex: tabIndex,
              iconPath: existingShortcut.iconPath,
              iconSource: existingShortcut.iconSource, // 既存のiconSourceを保持
            ),
          );
        }
      }
    }

    // タブ情報も含めて設定を保存
    final config = ShortcutConfig(shortcuts: shortcuts, tabs: _tabInfos);
    await appState.updateConfig(config);
  }

  /// タブ情報のみを保存（ショートカット設定は変更しない）
  Future<void> _saveTabInfoOnly() async {
    final appState = context.read<AppState>();

    // 既存のショートカット設定を保持したまま、タブ情報のみを更新
    final updatedConfig = appState.config.copyWith(tabs: _tabInfos);
    await appState.updateConfig(updatedConfig);
  }

  /// システムトレイを初期化
  Future<void> _initializeSystemTray() async {
    try {
      print('システムトレイ初期化を開始...');
      await SystemTrayManager.initialize();
      print('システムトレイ初期化完了');

      // ウィンドウを閉じる時にシステムトレイに隠すように設定
      await windowManager.setPreventClose(true);
      print('ウィンドウクローズ防止を設定');

      // ウィンドウ表示コールバックを設定
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setShowWindowCallback(_showWindowFromTray);
      print('ウィンドウ表示コールバックを設定');
    } catch (e) {
      print('システムトレイ初期化エラー: $e');
      // エラーが発生してもアプリケーションは継続
    }
  }

  /// システムトレイからのウィンドウ表示要求を処理
  Future<void> _showWindowFromTray() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      print('システムトレイからウィンドウを表示しました');
    } catch (e) {
      print('ウィンドウ表示エラー: $e');
    }
  }

  /// ウィンドウを閉じる時の処理
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // ウィンドウを閉じる代わりにシステムトレイに最小化
      await SystemTrayManager.hideToTray();
    }
  }

  /// ウィンドウ最小化時の処理
  @override
  void onWindowMinimize() async {
    // 最小化時もシステムトレイに隠す
    await SystemTrayManager.hideToTray();
  }

  /// アイコンファイルの整合性を検証して修復
  Future<void> _validateAndFixIconFiles(List<Shortcut> shortcuts) async {
    print('🔧 アイコンファイル整合性チェック開始: ${shortcuts.length}個のショートカット');

    int fixedCount = 0;
    final updatedShortcuts = <Shortcut>[];

    for (final shortcut in shortcuts) {
      if (shortcut.iconPath != null && shortcut.iconPath!.isNotEmpty) {
        final iconFile = File(shortcut.iconPath!);

        if (!iconFile.existsSync()) {
          print('⚠️ アイコンファイルが見つかりません: ${shortcut.iconPath}');
          print(
            '   ショートカット: ${shortcut.name} (タブ${shortcut.tabIndex}, ボタン${shortcut.buttonId})',
          );

          // アイコンファイルが存在しない場合、パスから再抽出を試行
          if (shortcut.path.isNotEmpty &&
              !shortcut.path.startsWith('http') &&
              shortcut.path.toLowerCase().endsWith('.exe')) {
            try {
              final iconCacheDir = IconExtractor.getIconCacheDir();
              final newIconPath = await IconExtractor.extractIcon(
                shortcut.path,
                iconCacheDir,
              );

              if (newIconPath != null) {
                print('✅ アイコンを再抽出しました: $newIconPath');
                updatedShortcuts.add(shortcut.copyWith(iconPath: newIconPath));
                fixedCount++;
              } else {
                print('❌ アイコン再抽出に失敗、アイコンパスをクリア');
                updatedShortcuts.add(shortcut.copyWith(iconPath: ''));
                fixedCount++;
              }
            } catch (e) {
              print('❌ アイコン再抽出エラー: $e');
              updatedShortcuts.add(shortcut.copyWith(iconPath: ''));
              fixedCount++;
            }
          } else {
            print('❌ 実行ファイルではないため、アイコンパスをクリア');
            updatedShortcuts.add(shortcut.copyWith(iconPath: ''));
            fixedCount++;
          }
        } else {
          // アイコンファイルが存在する場合はそのまま保持
          updatedShortcuts.add(shortcut);
        }
      } else {
        // アイコンパスが設定されていない場合はそのまま保持
        updatedShortcuts.add(shortcut);
      }
    }

    if (fixedCount > 0) {
      print('🔧 アイコンファイル整合性チェック完了: ${fixedCount}個のアイコンを修復');

      // 修復されたショートカットを保存
      final appState = context.read<AppState>();
      final updatedConfig = appState.config.copyWith(
        shortcuts: updatedShortcuts,
      );
      await appState.updateConfig(updatedConfig);
    } else {
      print('✅ アイコンファイル整合性チェック完了: 修復の必要なし');
    }
  }

  /// IPアドレス設定ダイアログを表示
  void _showIPAddressDialog(BuildContext context, AppState appState) {
    final TextEditingController controller = TextEditingController();

    // 現在のIPアドレスを取得
    final serverInfo = appState.server.getServerInfo();
    final currentUrl = serverInfo['url'] as String?;
    if (currentUrl != null) {
      final uri = Uri.parse(currentUrl);
      controller.text = uri.host;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.network_check, color: Colors.blue),
            SizedBox(width: 8),
            Text('IPアドレス設定'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('自分PCのIPアドレスを入力してください'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'IPアドレス',
                hintText: '192.168.xxx.xxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'IPアドレスの確認方法',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. コマンドプロンプトを開く\n'
                    '2. "ipconfig" を実行\n'
                    '3. IPv4アドレスを確認',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ipAddress = controller.text.trim();
              if (ipAddress.isNotEmpty) {
                Navigator.of(context).pop();
                await _updateIPAddress(context, appState, ipAddress);
              }
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );
  }

  /// IPアドレスを更新
  Future<void> _updateIPAddress(
    BuildContext context,
    AppState appState,
    String ipAddress,
  ) async {
    try {
      // サーバーを一時停止
      if (appState.isServerRunning) {
        await appState.stopServer();
      }

      // IPアドレスを更新（サーバー内部で設定）
      await appState.server.updateIPAddress(ipAddress);

      // サーバーを再起動
      await appState.startServer();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('IPアドレスを $ipAddress に設定しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('IPアドレスの設定に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ファイアウォール設定ダイアログを表示
  void _showFirewallSetupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('ファイアウォール設定'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EYM Agentが正常に動作するために、Windowsファイアウォールの設定を行います。'),
            SizedBox(height: 12),
            Text('設定内容:'),
            Text('• ポート8080（TCP）の受信を許可'),
            Text('• プログラム名: "EYM Agent"'),
            SizedBox(height: 12),
            Text(
              '※ 管理者権限が必要です',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupFirewall(context);
            },
            child: const Text('設定実行'),
          ),
        ],
      ),
    );
  }

  /// ファイアウォール削除確認ダイアログを表示
  void _showFirewallRemoveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('ファイアウォール設定削除'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EYM Agentのファイアウォール設定を削除します。'),
            SizedBox(height: 12),
            Text('削除すると:'),
            Text('• スマホからPCへの接続ができなくなります'),
            Text('• 再度使用する場合は設定が必要です'),
            SizedBox(height: 12),
            Text(
              '本当に削除しますか？',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _removeFirewall(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除実行'),
          ),
        ],
      ),
    );
  }

  /// ファイアウォール設定を実行
  Future<void> _setupFirewall(BuildContext context) async {
    try {
      final result = await FirewallManager.setupFirewall();

      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          if (result.needsAdmin) {
            _showAdminRequiredDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ファイアウォール設定中にエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ファイアウォール設定を削除
  Future<void> _removeFirewall(BuildContext context) async {
    try {
      final result = await FirewallManager.removeFirewall();

      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          if (result.needsAdmin) {
            _showAdminRequiredDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ファイアウォール設定削除中にエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// アイコンキャッシュクリアダイアログを表示
  void _showIconCacheClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.purple),
            SizedBox(width: 8),
            Text('アイコン更新'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('アイコンキャッシュをクリアして、高解像度アイコンを再生成します。'),
            SizedBox(height: 12),
            Text('実行内容:'),
            Text('• 既存のアイコンキャッシュを削除'),
            Text('• 512x512の超高解像度でアイコンを再抽出'),
            Text('• スマホ側でより鮮明なアイコンが表示されます'),
            SizedBox(height: 12),
            Text(
              '※ 処理には少し時間がかかる場合があります',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearIconCacheAndRegenerate(context);
            },
            child: const Text('実行'),
          ),
        ],
      ),
    );
  }

  /// アプリ起動時にアイコンキャッシュをクリア
  Future<void> _clearIconCacheOnStartup() async {
    try {
      print('アプリ起動時: アイコンキャッシュクリアを開始');
      // 起動時は静かにキャッシュをクリアするだけ
      await IconExtractor.clearIconCache();
      print('アプリ起動時: アイコンキャッシュクリア完了');
    } catch (e) {
      print('アプリ起動時: アイコンキャッシュクリアエラー: $e');
      // エラーが発生してもアプリケーションは継続
    }
  }

  /// アイコン表示を強制的に更新
  void _forceIconRefresh() {
    print('アイコン強制更新を実行');

    // UIを即座に更新
    if (mounted) {
      setState(() {});

      // 少し遅延してもう一度更新（アイコンキャッシュの更新を確実にするため）
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {});
        }
      });

      // さらに遅延してもう一度更新（完全にアイコンが更新されるまで）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  /// アイコンキャッシュをクリアして再生成
  Future<void> _clearIconCacheAndRegenerate(BuildContext context) async {
    try {
      // 処理中ダイアログを表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('アイコンキャッシュを更新中...'),
            ],
          ),
        ),
      );

      // アイコンキャッシュをクリア
      await IconExtractor.clearIconCache();

      // 現在のショートカットからアイコンを再抽出
      final appState = context.read<AppState>();
      final shortcuts = List<Shortcut>.from(appState.config.shortcuts);
      int regeneratedCount = 0;

      for (int i = 0; i < shortcuts.length; i++) {
        final shortcut = shortcuts[i];
        if (shortcut.path.isNotEmpty && !shortcut.path.startsWith('http')) {
          final iconCacheDir = IconExtractor.getIconCacheDir();
          final iconPath = await IconExtractor.extractIcon(
            shortcut.path,
            iconCacheDir,
          );

          if (iconPath != null) {
            // ショートカットのアイコンパスを更新
            shortcuts[i] = shortcuts[i].copyWith(iconPath: iconPath);
            regeneratedCount++;
          }
        }
      }

      // 設定を保存
      if (regeneratedCount > 0) {
        final updatedConfig = appState.config.copyWith(shortcuts: shortcuts);
        await appState.updateConfig(updatedConfig);

        // UIを更新
        if (mounted) {
          setState(() {});
        }
      }

      // 処理中ダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アイコンキャッシュを更新しました（$regeneratedCount個のアイコンを再生成）'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // 処理中ダイアログが表示されている場合は閉じる
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('アイコンキャッシュクリアエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アイコンキャッシュの更新に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 管理者権限が必要な場合のダイアログを表示
  void _showAdminRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.orange),
            SizedBox(width: 8),
            Text('ファイアウォール設定について'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '✅ 通常権限でもファイアウォール設定が可能です',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '🔒 自動UAC昇格機能',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ファイアウォール設定時に自動的にUAC（ユーザーアカウント制御）ダイアログが表示されます。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '手順:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. 「ファイアウォール設定」ボタンをクリック\n'
                '2. UACダイアログが表示されたら「はい」をクリック\n'
                '3. 自動的にファイアウォール設定が完了',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '管理者として実行する必要はありません',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('理解しました'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Column(
            children: [
              // サーバー状態表示（固定）
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildServerStatus(context, appState),
              ),
              // 設定画面
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: _buildSettingsSection(context, appState),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// サーバー状態表示
  Widget _buildServerStatus(BuildContext context, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      appState.isServerRunning
                          ? Icons.check_circle
                          : Icons.error,
                      color: appState.isServerRunning
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appState.isServerRunning ? 'サーバー稼働中' : 'サーバー停止中',
                      style: TextStyle(
                        color: appState.isServerRunning
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // サーバー開始/停止ボタン
                    IconButton(
                      icon: Icon(
                        appState.isServerRunning
                            ? Icons.stop
                            : Icons.play_arrow,
                        color: appState.isServerRunning
                            ? Colors.red
                            : Colors.green,
                      ),
                      onPressed: appState.isLoading
                          ? null
                          : () async {
                              if (appState.isServerRunning) {
                                await appState.stopServer();
                              } else {
                                await appState.startServer();
                              }
                            },
                      tooltip: appState.isServerRunning ? 'サーバーを停止' : 'サーバーを開始',
                    ),
                  ],
                ),
                if (appState.serverUrl != null) ...[
                  const SizedBox(height: 8),
                  // IP設定案内メッセージ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '最初にIP設定からIPアドレスを設定してください',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 全ボタンを横一列に配置
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _showIPAddressDialog(context, appState);
                        },
                        icon: const Icon(Icons.network_check, size: 20),
                        label: const Text('IP設定'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                QRCodeDialog(serverUrl: appState.serverUrl!),
                          );
                        },
                        icon: const Icon(Icons.qr_code, size: 20),
                        label: const Text('QRコード表示'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 設定セクション
  Widget _buildSettingsSection(BuildContext context, AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 2, child: _buildSettingsTable(context, appState)),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDropArea(context)),
            ],
          ),
        ),
      ],
    );
  }

  /// 設定テーブル
  Widget _buildSettingsTable(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分
            Row(
              children: [
                Text(
                  'ショートカット一覧',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'ドラッグして並び替え',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // タブ管理部分
            _buildTabControls(context),
            const SizedBox(height: 16),

            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(_totalTabs, (tabIndex) {
                  return _buildTabContent(context, appState, tabIndex);
                }),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: appState.isLoading ? null : _resetSettings,
                  child: const Text('リセット'),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// タブ管理コントロール
  Widget _buildTabControls(BuildContext context) {
    return Row(
      children: [
        // ドラッグ可能なタブバー
        Expanded(
          child: _totalTabs > 1
              ? SizedBox(
                  height: 48, // 高さを明示的に指定
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalTabs,
                    onReorder: (oldIndex, newIndex) =>
                        _reorderTabs(oldIndex, newIndex),
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final tabName = index < _tabInfos.length
                          ? _tabInfos[index].name
                          : 'タブ ${index + 1}';
                      final isSelected = _tabController.index == index;

                      return Container(
                        key: ValueKey('tab_$index'),
                        margin: const EdgeInsets.only(right: 4),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: GestureDetector(
                            onTap: () {
                              print(
                                'タブ$indexをクリック: 現在のインデックス=${_tabController.index}',
                              );
                              if (_tabController.index != index) {
                                _tabController.animateTo(index);
                                // UIを強制的に更新してフォーカス状態を反映
                                setState(() {});
                              }
                            },
                            onDoubleTap: () => _showTabRenameDialog(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1)
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_handle,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.folder, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    tabName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : null,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: List.generate(_totalTabs, (index) {
                    final tabName = index < _tabInfos.length
                        ? _tabInfos[index].name
                        : 'タブ ${index + 1}';
                    return Tab(
                      child: GestureDetector(
                        onDoubleTap: () => _showTabRenameDialog(index),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder, size: 16),
                            const SizedBox(width: 4),
                            Text(tabName),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(width: 8),

        // タブ追加ボタン
        IconButton(
          onPressed: _addTab,
          icon: const Icon(Icons.add, size: 20),
          tooltip: 'タブを追加',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 4),

        // タブ削除ボタン（タブが1つの場合はリセット機能）
        IconButton(
          onPressed: _removeTab,
          icon: const Icon(Icons.remove, size: 20),
          tooltip: _totalTabs > 1 ? 'タブを削除' : 'タブをリセット',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  /// タブコンテンツ
  Widget _buildTabContent(
    BuildContext context,
    AppState appState,
    int tabIndex,
  ) {
    return ReorderableListView.builder(
      itemCount: 6,
      buildDefaultDragHandles: false, // 右側の自動ドラッグハンドルを無効化
      onReorder: (oldIndex, newIndex) =>
          _reorderShortcutsInTab(tabIndex, oldIndex, newIndex),
      itemBuilder: (context, index) {
        // 相対的なボタンID（1-6）を渡す
        final relativeButtonId = index + 1;
        return _buildShortcutCard(
          context,
          appState,
          relativeButtonId,
          tabIndex,
        );
      },
    );
  }

  /// タブを追加
  void _addTab() async {
    // まず現在のコントローラーの内容を保存してからタブを追加
    await _saveSettingsQuietly();

    setState(() {
      _totalTabs++;

      // _tabInfosリストを_totalTabsに合わせて拡張
      while (_tabInfos.length < _totalTabs) {
        _tabInfos.add(
          TabInfo(index: _tabInfos.length, name: 'タブ ${_tabInfos.length + 1}'),
        );
      }

      // 新しいタブ用のコントローラーを追加
      for (int i = 0; i < 6; i++) {
        final nameController = TextEditingController(text: '');
        final pathController = TextEditingController(text: '');
        final iconController = TextEditingController(text: '');

        nameController.addListener(() => _autoSave());
        pathController.addListener(
          () => _autoSaveAndExtractIcon((_totalTabs - 1) * 6 + i + 1),
        );

        _nameControllers.add(nameController);
        _pathControllers.add(pathController);
        _iconControllers.add(iconController);
      }

      // TabControllerを再作成
      _tabController.dispose();
      _tabController = TabController(length: _totalTabs, vsync: this);
      _tabController.animateTo(_totalTabs - 1); // 新しいタブに移動
    });

    // タブ情報を含めて設定を更新
    final appState = context.read<AppState>();
    final updatedConfig = appState.config.copyWith(tabs: _tabInfos);
    await appState.updateConfig(updatedConfig);
  }

  /// タブを削除
  void _removeTab() {
    if (_totalTabs <= 1) {
      // タブが2つ以下の場合は削除せず、現在のタブをリセット
      final currentIndex = _tabController.index;
      setState(() {
        // 現在のタブの内容をリセット（安全チェック付き）
        final startIndex = currentIndex * 6;
        for (int i = 0; i < 6; i++) {
          final index = startIndex + i;
          if (index < _nameControllers.length &&
              index < _pathControllers.length) {
            _nameControllers[index].text = '';
            _pathControllers[index].text = '';
          }
        }

        // タブ名もリセット（安全チェック付き）
        if (currentIndex < _tabInfos.length) {
          _tabInfos[currentIndex] = _tabInfos[currentIndex].copyWith(
            name: 'タブ ${currentIndex + 1}',
          );
        }
      });

      // 設定を保存
      _saveSettingsQuietly();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「タブ ${currentIndex + 1}」の内容をリセットしました'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    final currentIndex = _tabController.index;
    final tabToRemove = currentIndex;

    setState(() {
      // 削除するタブのコントローラーを削除（逆順で削除してインデックスのずれを防ぐ）
      final startIndex = tabToRemove * 6;
      for (int i = 5; i >= 0; i--) {
        final index = startIndex + i;
        if (index < _nameControllers.length &&
            index < _pathControllers.length &&
            index < _iconControllers.length) {
          _nameControllers[index].dispose();
          _pathControllers[index].dispose();
          _iconControllers[index].dispose();
          _nameControllers.removeAt(index);
          _pathControllers.removeAt(index);
          _iconControllers.removeAt(index);
        }
      }

      // _tabInfosからも削除（安全チェック付き）
      if (tabToRemove < _tabInfos.length) {
        _tabInfos.removeAt(tabToRemove);
      }

      // 残りのタブのindexを更新
      for (int i = 0; i < _tabInfos.length; i++) {
        _tabInfos[i] = _tabInfos[i].copyWith(index: i);
      }

      _totalTabs--;

      // TabControllerを再作成
      _tabController.dispose();
      _tabController = TabController(length: _totalTabs, vsync: this);

      // 削除後のタブインデックスを調整（安全チェック付き）
      final newIndex = tabToRemove >= _totalTabs ? _totalTabs - 1 : tabToRemove;
      if (newIndex >= 0 && newIndex < _totalTabs) {
        _tabController.animateTo(newIndex);
      }
    });

    // 設定を保存
    _saveSettingsQuietly();
  }

  /// タブの並び替え（ドラッグ&ドロップ）
  // void _reorderTabs(int oldIndex, int newIndex) {
  //   if (oldIndex < newIndex) {
  //     newIndex -= 1;
  //   }

  //   print('🔄 タブドラッグ&ドロップ並び替え: $oldIndex -> $newIndex');

  //   // 現在のタブ情報をコピー
  //   final reorderedTabs = List<TabInfo>.from(_tabInfos);

  //   // タブ情報を並び替え（名前のみ移動、ショートカット設定は元の位置に残す）
  //   final movedTabName = reorderedTabs[oldIndex].name;
  //   final targetTabName = reorderedTabs[newIndex].name;

  //   // タブ名のみを交換
  //   reorderedTabs[oldIndex] = reorderedTabs[oldIndex].copyWith(
  //     name: targetTabName,
  //   );
  //   reorderedTabs[newIndex] = reorderedTabs[newIndex].copyWith(
  //     name: movedTabName,
  //   );

  //   setState(() {
  //     _tabInfos = reorderedTabs;

  //     // TabControllerを再作成
  //     final currentIndex = _tabController.index;
  //     _tabController.dispose();
  //     _tabController = TabController(length: _totalTabs, vsync: this);

  //     // 現在選択されているタブのインデックスを調整
  //     int newCurrentIndex = currentIndex;
  //     if (currentIndex == oldIndex) {
  //       // 移動されたタブが選択されていた場合
  //       newCurrentIndex = newIndex;
  //     } else if (currentIndex > oldIndex && currentIndex <= newIndex) {
  //       // 選択されたタブが左にシフトされる場合
  //       newCurrentIndex = currentIndex - 1;
  //     } else if (currentIndex < oldIndex && currentIndex >= newIndex) {
  //       // 選択されたタブが右にシフトされる場合
  //       newCurrentIndex = currentIndex + 1;
  //     }

  //     _tabController.animateTo(newCurrentIndex);
  //   });

  //   // タブ情報のみを保存（ショートカット設定は変更しない）
  //   _saveTabInfoOnly();

  //   // UIを強制的に更新
  //   if (mounted) {
  //     setState(() {});

  //     Future.delayed(const Duration(milliseconds: 100), () {
  //       if (mounted) {
  //         setState(() {});
  //       }
  //     });
  //   }
  // }
  void _reorderTabs(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    // 並び順（TabInfo）を更新
    final reordered = List<TabInfo>.from(_tabInfos);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() {
      _tabInfos = reordered;
    });

    // ★中身（コントローラとショートカットデータ）も新しい順に再配置
    await _reorderControllersBasedOnTabs(_tabInfos);

    // TabController を再構築し、選択タブを補正
    final currentIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(length: _totalTabs, vsync: this);

    int newCurrentIndex = currentIndex;
    if (currentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (currentIndex > oldIndex && currentIndex <= newIndex) {
      newCurrentIndex = currentIndex - 1;
    } else if (currentIndex < oldIndex && currentIndex >= newIndex) {
      newCurrentIndex = currentIndex + 1;
    }
    _tabController.animateTo(newCurrentIndex);

    // タブ情報のみ保存（ショートカットは再配置内で保存済み）
    await _saveTabInfoOnly();

    if (mounted) setState(() {});
  }

  /// タブ内でのショートカット並び替え
  void _reorderShortcutsInTab(int tabIndex, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final startIndex = tabIndex * 6;
    final oldControllerIndex = startIndex + oldIndex;
    final newControllerIndex = startIndex + newIndex;

    // コントローラーの並び替え
    final nameController = _nameControllers.removeAt(oldControllerIndex);
    final pathController = _pathControllers.removeAt(oldControllerIndex);

    _nameControllers.insert(newControllerIndex, nameController);
    _pathControllers.insert(newControllerIndex, pathController);

    // AppStateのショートカットデータも並び替える
    final appState = context.read<AppState>();
    final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

    // 該当するタブのショートカットを取得
    final tabShortcuts = currentShortcuts
        .where((s) => s.tabIndex == tabIndex)
        .toList();
    tabShortcuts.sort((a, b) => a.buttonId.compareTo(b.buttonId));

    // 並び替え対象のショートカットを移動
    if (oldIndex < tabShortcuts.length && newIndex < tabShortcuts.length) {
      final movingShortcut = tabShortcuts.removeAt(oldIndex);
      tabShortcuts.insert(newIndex, movingShortcut);

      // 他のタブのショートカットを保持
      final otherTabShortcuts = currentShortcuts
          .where((s) => s.tabIndex != tabIndex)
          .toList();

      // 新しいショートカットリストを作成（アイコンパスを保持）
      final newShortcuts = <Shortcut>[];
      newShortcuts.addAll(otherTabShortcuts);

      // 並び替えられたタブのショートカットを追加（buttonIdを更新）
      for (int i = 0; i < tabShortcuts.length; i++) {
        final shortcut = tabShortcuts[i];
        newShortcuts.add(
          shortcut.copyWith(
            buttonId: i + 1, // 新しい位置のbuttonId
            name: _nameControllers[startIndex + i].text.trim().isEmpty
                ? ''
                : _nameControllers[startIndex + i].text.trim(),
            path: _pathControllers[startIndex + i].text.trim(),
          ),
        );
      }

      // 設定を更新
      final updatedConfig = appState.config.copyWith(shortcuts: newShortcuts);
      appState.updateConfig(updatedConfig);
    }

    setState(() {});
  }

  /// ショートカットカードを構築（タブ対応版）
  Widget _buildShortcutCard(
    BuildContext context,
    AppState appState,
    int buttonId, [
    int? tabIndex,
  ]) {
    final currentTabIndex = tabIndex ?? _tabController.index;
    final relativeButtonId = buttonId;
    final controllerIndex = (currentTabIndex * 6) + (relativeButtonId - 1);

    final shortcut = appState.config.shortcuts.firstWhere(
      (s) => s.tabIndex == currentTabIndex && s.buttonId == relativeButtonId,
      orElse: () => Shortcut(
        buttonId: relativeButtonId,
        name: '$relativeButtonId',
        path: '',
        tabIndex: currentTabIndex,
      ),
    );

    // デバッグ: 全ショートカットの状態を確認
    print('全ショートカット一覧:');
    for (final s in appState.config.shortcuts) {
      print(
        '  - タブ${s.tabIndex}, ボタン${s.buttonId}: ${s.name}, アイコン: ${s.iconPath}',
      );
    }

    return Card(
      key: ValueKey('${currentTabIndex}_$relativeButtonId'),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // ドラッグハンドル（左側のみ）
            ReorderableDragStartListener(
              index: relativeButtonId - 1, // タブ内での相対インデックス
              child: Container(
                width: 24,
                height: 40,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // アイコン
            _buildShortcutIcon(shortcut),

            const SizedBox(width: 12),

            // 名前とパスの入力フィールド
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名前
                  TextField(
                    controller: controllerIndex < _nameControllers.length
                        ? _nameControllers[controllerIndex]
                        : TextEditingController(
                            text: '$relativeButtonId',
                          ),
                    decoration: const InputDecoration(
                      labelText: '名前',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  // パス
                  TextField(
                    controller: controllerIndex < _pathControllers.length
                        ? _pathControllers[controllerIndex]
                        : TextEditingController(text: ''),
                    decoration: const InputDecoration(
                      labelText: 'パス',
                      hintText: 'アプリケーションパスまたはURL',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 操作ボタン
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  onPressed: shortcut.path.isNotEmpty
                      ? () => _testShortcut(buttonId)
                      : null,
                  tooltip: 'テスト実行',
                ),
                IconButton(
                  icon: const Icon(Icons.image, size: 20),
                  onPressed: shortcut.path.isNotEmpty
                      ? () => _showIconChangeDialog(buttonId)
                      : null,
                  tooltip: shortcut.path.isNotEmpty
                      ? 'アイコン変更'
                      : 'ショートカットを設定してください',
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _clearShortcut(controllerIndex),
                  tooltip: 'クリア',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ショートカットのアイコンを構築（高解像度対応）
  Widget _buildShortcutIcon(Shortcut shortcut) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final currentTabIndex = _tabController.index;

    print('[$currentTime] 🔍 アイコン表示チェック:');
    print('  - ショートカット名: ${shortcut.name}');
    print('  - アイコンパス: ${shortcut.iconPath}');
    print('  - タブインデックス: ${shortcut.tabIndex}');
    print('  - ボタンID: ${shortcut.buttonId}');
    print('  - 現在のタブ: $currentTabIndex');

    if (shortcut.iconPath != null && shortcut.iconPath!.isNotEmpty) {
      final iconFile = File(shortcut.iconPath!);
      final fileExists = iconFile.existsSync();
      print('  - ファイル存在: $fileExists (${iconFile.path})');

      if (fileExists) {
        print('  - ✅ アイコンファイルを表示');
        // より強力なキー生成（タブ並び替えを確実に反映）
        final uniqueKey =
            'icon_tab${shortcut.tabIndex}_btn${shortcut.buttonId}_${shortcut.iconPath.hashCode}_$currentTime';
        return Container(
          key: ValueKey(uniqueKey),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              iconFile,
              key: ValueKey('image_$uniqueKey'),
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              cacheWidth: null, // キャッシュを無効化
              cacheHeight: null, // キャッシュを無効化
              errorBuilder: (context, error, stackTrace) {
                print('  - ❌ アイコン表示エラー: $error');
                return _buildDefaultIcon(shortcut);
              },
            ),
          ),
        );
      } else {
        print('  - ❌ アイコンファイルが存在しません');
      }
    } else {
      print('  - ⚠️ アイコンパスが設定されていません');
    }

    return _buildDefaultIcon(shortcut);
  }

  /// デフォルトアイコンを構築
  Widget _buildDefaultIcon(Shortcut shortcut) {
    IconData iconData;
    Color iconColor = Colors.grey.shade600;

    if (shortcut.path.startsWith('http://') ||
        shortcut.path.startsWith('https://')) {
      iconData = Icons.language;
      iconColor = Colors.blue.shade600;
    } else if (shortcut.path.toLowerCase().endsWith('.exe')) {
      iconData = Icons.desktop_windows;
      iconColor = Colors.green.shade600;
    } else if (shortcut.path.isEmpty) {
      iconData = Icons.add_circle_outline;
      iconColor = Colors.grey.shade400;
    } else {
      iconData = Icons.launch;
      iconColor = Colors.orange.shade600;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Icon(iconData, size: 20, color: iconColor),
    );
  }

  /// ドラッグ&ドロップエリア
  Widget _buildDropArea(BuildContext context) {
    return Card(
      child: DropTarget(
        onDragDone: (detail) {
          print('ドラッグ&ドロップ検出: ${detail.files.length}個のファイル');
          if (detail.files.isNotEmpty) {
            _handleDroppedFiles(detail.files);
          }
        },
        onDragEntered: (detail) {
          print('ドラッグ開始検出');
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (detail) {
          print('ドラッグ終了検出');
          setState(() {
            _isDragging = false;
          });
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _isDragging
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_upload,
                size: 64,
                color: _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'ファイルをドラッグ&ドロップ',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '空いているスロットに自動で追加されます',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // ファイル選択ボタン（ドラッグ&ドロップの代替手段）
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.folder_open, size: 20),
                label: const Text('ファイルを選択'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ドラッグ&ドロップが動作しない場合はこちら',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ドロップされたファイルを処理
  Future<void> _handleDroppedFiles(List<XFile> files) async {
    for (final file in files) {
      final emptyIndex = _findEmptySlot();
      if (emptyIndex != -1) {
        final fileName = file.name;
        final nameWithoutExtension = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;

        _nameControllers[emptyIndex].text = nameWithoutExtension;
        _pathControllers[emptyIndex].text = file.path;

        // 自動保存
        await _saveSettingsQuietly();

        // .exeファイルの場合はアイコンを自動抽出
        if (file.path.toLowerCase().endsWith('.exe')) {
          // emptyIndexは0ベースなので、buttonIdは1ベースに変換
          final tabIndex = emptyIndex ~/ 6;
          final relativeButtonIndex = emptyIndex % 6;
          final buttonId = (tabIndex * 6) + relativeButtonIndex + 1;

          print(
            'アイコン抽出開始: emptyIndex=$emptyIndex, tabIndex=$tabIndex, buttonId=$buttonId, path=${file.path}',
          );
          await _extractIconForShortcut(buttonId, file.path);

          // アイコン抽出後にUIを更新
          if (mounted) {
            setState(() {});
          }
        }

        // どのタブに追加されたかを計算
        final tabIndex = emptyIndex ~/ 6;
        final tabName = tabIndex < _tabInfos.length
            ? _tabInfos[tabIndex].name
            : 'タブ ${tabIndex + 1}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$tabName」に「$nameWithoutExtension」を追加・保存しました'),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('空いているスロットがありません')));
        break;
      }
    }

    setState(() {
      _isDragging = false;
    });
  }

  /// 空いているスロットを見つける（現在のタブから開始、右側のタブを確認してから新しいタブを作成）
  int _findEmptySlot() {
    final currentTabIndex = _tabController.index;
    final startIndex = currentTabIndex * 6;

    // まず現在のタブ内で空きスロットを探す
    for (
      int i = startIndex;
      i < startIndex + 6 && i < _pathControllers.length;
      i++
    ) {
      if (_pathControllers[i].text.isEmpty) {
        return i;
      }
    }

    // 現在のタブが満杯の場合、右側（現在のタブより後ろ）のタブで空きスロットを探す
    for (
      int tabIndex = currentTabIndex + 1;
      tabIndex < _totalTabs;
      tabIndex++
    ) {
      final tabStartIndex = tabIndex * 6;
      for (
        int i = tabStartIndex;
        i < tabStartIndex + 6 && i < _pathControllers.length;
        i++
      ) {
        if (_pathControllers[i].text.isEmpty) {
          return i;
        }
      }
    }

    // 右側のタブにも空きがない場合、新しいタブを作成
    _addTab();

    // 新しく作成されたタブの最初のスロットを返す
    final newTabIndex = _totalTabs - 1;
    final newTabStartIndex = newTabIndex * 6;
    return newTabStartIndex;
  }

  /// ファイル選択ダイアログを表示
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        dialogTitle: 'ショートカットに追加するファイルを選択',
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((file) => file.path != null)
            .map((file) => XFile(file.path!))
            .toList();

        if (files.isNotEmpty) {
          await _handleDroppedFiles(files);
        }
      }
    } catch (e) {
      print('ファイル選択エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ファイル選択中にエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ショートカットをクリア
  void _clearShortcut(int index) async {
    _nameControllers[index].text = '';
    _pathControllers[index].text = '';

    // アイコンパスもクリア
    final appState = context.read<AppState>();
    final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

    // indexからタブインデックスと相対ボタンIDを計算
    final tabIndex = index ~/ 6;
    final relativeButtonId = (index % 6) + 1;

    // 該当するショートカットのアイコンパスをクリア
    final shortcutIndex = currentShortcuts.indexWhere(
      (s) => s.tabIndex == tabIndex && s.buttonId == relativeButtonId,
    );

    if (shortcutIndex != -1) {
      currentShortcuts[shortcutIndex] = currentShortcuts[shortcutIndex]
          .copyWith(
            name: '$relativeButtonId',
            path: '',
            iconPath: '', // アイコンパスをクリア
          );

      final updatedConfig = appState.config.copyWith(
        shortcuts: currentShortcuts,
      );
      await appState.updateConfig(updatedConfig);
    }

    // クリア後に自動保存とUI更新
    await _saveSettingsQuietly();
    if (mounted) {
      setState(() {});
    }
  }

  /// ショートカットをテスト
  void _testShortcut(int buttonId) {
    final appState = context.read<AppState>();
    appState.launchApplication(buttonId);
  }

  /// ショートカットのアイコンを抽出
  Future<void> _extractIconForShortcut(int buttonId, String path) async {
    try {
      print('アイコン抽出開始: buttonId=$buttonId, path=$path');

      final iconCacheDir = IconExtractor.getIconCacheDir();
      print('アイコンキャッシュディレクトリ: $iconCacheDir');

      final iconPath = await IconExtractor.extractIcon(path, iconCacheDir);
      print('アイコン抽出結果: $iconPath');

      if (iconPath != null) {
        final appState = context.read<AppState>();
        final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

        // buttonIdからタブインデックスと相対ボタンIDを計算
        final tabIndex = (buttonId - 1) ~/ 6;
        final relativeButtonId = ((buttonId - 1) % 6) + 1;

        print('計算結果: tabIndex=$tabIndex, relativeButtonId=$relativeButtonId');

        // 該当するショートカットを更新（タブインデックスと相対ボタンIDで検索）
        final shortcutIndex = currentShortcuts.indexWhere(
          (s) => s.tabIndex == tabIndex && s.buttonId == relativeButtonId,
        );

        print('ショートカット検索結果: shortcutIndex=$shortcutIndex');

        if (shortcutIndex != -1) {
          print('既存ショートカットを更新');
          currentShortcuts[shortcutIndex] = currentShortcuts[shortcutIndex]
              .copyWith(
                iconPath: iconPath,
                iconSource: "drag_drop", // ドラッグ&ドロップで設定
              );

          final updatedConfig = appState.config.copyWith(
            shortcuts: currentShortcuts,
          );
          await appState.updateConfig(updatedConfig);

          print('アイコン抽出成功: $iconPath (タブ: $tabIndex, ボタン: $relativeButtonId)');
        } else {
          print('新規ショートカットを作成');
          // ショートカットが存在しない場合は新規作成
          final index = buttonId - 1;
          final name = index < _nameControllers.length
              ? _nameControllers[index].text.trim()
              : '$relativeButtonId';
          final shortcutPath = index < _pathControllers.length
              ? _pathControllers[index].text.trim()
              : path;

          currentShortcuts.add(
            Shortcut(
              buttonId: relativeButtonId,
              name: name.isEmpty ? '$relativeButtonId' : name,
              path: shortcutPath,
              args: [],
              tabIndex: tabIndex,
              iconPath: iconPath,
              iconSource: "drag_drop", // ドラッグ&ドロップで設定
            ),
          );

          final updatedConfig = appState.config.copyWith(
            shortcuts: currentShortcuts,
          );
          await appState.updateConfig(updatedConfig);

          print(
            '新規ショートカット作成とアイコン抽出成功: $iconPath (タブ: $tabIndex, ボタン: $relativeButtonId)',
          );
        }

        // UIを強制的に更新
        if (mounted) {
          print('UIを更新中...');
          setState(() {});

          // 少し遅延してもう一度更新を試行
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              print('遅延UI更新を実行');
              setState(() {});
            }
          });
        }
      } else {
        print('アイコン抽出に失敗しました');
      }
    } catch (e) {
      print('アイコン抽出エラー: $e');
    }
  }

  /// アイコン変更ダイアログを表示
  Future<void> _showIconChangeDialog(int buttonId) async {
    final appState = context.read<AppState>();

    // 現在のタブインデックスと相対ボタンIDを取得
    final currentTabIndex = _tabController.index;
    final relativeButtonId = buttonId; // 既に相対的なボタンID（1-6）

    final shortcut = appState.config.shortcuts.firstWhere(
      (s) => s.tabIndex == currentTabIndex && s.buttonId == relativeButtonId,
      orElse: () => Shortcut(
        buttonId: relativeButtonId,
        name: '$relativeButtonId',
        path: '',
        tabIndex: currentTabIndex,
      ),
    );

    print(
      'アイコン変更ダイアログ: currentTabIndex=$currentTabIndex, relativeButtonId=$relativeButtonId, shortcut.name=${shortcut.name}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.image, color: Colors.blue),
            SizedBox(width: 8),
            Text('アイコン変更'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('「${shortcut.name}」のアイコンを変更します'),
              const SizedBox(height: 16),

              // 現在のアイコン表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('現在のアイコン: '),
                    const SizedBox(width: 8),
                    _buildShortcutIcon(shortcut),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 説明テキスト
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'サポートされる画像形式',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PNG, JPG, JPEG, BMP, GIF, ICO, WEBP\n'
                      '※ 自動的に512x512ピクセルの超高解像度にリサイズされます',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _selectAndProcessIcon(buttonId);
            },
            icon: const Icon(Icons.folder_open, size: 20),
            label: const Text('画像を選択'),
          ),
          if (shortcut.iconPath != null && shortcut.iconPath!.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetToDefaultIcon(buttonId);
              },
              child: const Text('デフォルトに戻す'),
            ),
        ],
      ),
    );
  }

  /// 画像を選択してアイコンとして処理
  Future<void> _selectAndProcessIcon(int buttonId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'アイコン用の画像を選択',
      );

      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;

        // 画像形式をチェック
        if (!ImageProcessor.isSupportedImageFormat(imagePath)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('サポートされていない画像形式です'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 処理中ダイアログを表示
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('画像を処理中...'),
                ],
              ),
            ),
          );
        }

        // アイコンキャッシュディレクトリを取得
        final iconCacheDir = IconExtractor.getIconCacheDir();

        // カスタムアイコンファイル名を生成
        final shortcutName = buttonId.toString(); // ボタンIDをショートカット名として使用
        final customIconFileName = ImageProcessor.generateCustomIconFileName(
          shortcutName,
          imagePath,
        );
        final outputPath = '$iconCacheDir/$customIconFileName';

        // 画像をリサイズしてアイコンとして保存（品質最適化）
        print('手動アイコン選択: 品質最適化リサイズを開始');
        final success = await ImageProcessor.resizeIconWithQualityOptimization(
          imagePath,
          outputPath,
          forceSize: 512, // 512x512で統一
        );

        // 処理中ダイアログを閉じる
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (success) {
          // ファイルサイズ検証
          final validation = await ImageProcessor.validateIconFileSize(
            outputPath,
          );
          print('手動アイコン選択: ${validation['message']}');

          // ショートカットのアイコンパスを更新
          await _updateShortcutIcon(buttonId, outputPath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('アイコンを変更しました'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('画像の処理に失敗しました'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // 処理中ダイアログが表示されている場合は閉じる
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('アイコン選択エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アイコン変更中にエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ショートカットのアイコンパスを更新
  Future<void> _updateShortcutIcon(int buttonId, String iconPath) async {
    final appState = context.read<AppState>();
    final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

    // 現在のタブインデックスと相対ボタンIDを取得
    final currentTabIndex = _tabController.index;
    final relativeButtonId = buttonId; // 既に相対的なボタンID（1-6）

    print(
      'アイコン更新: currentTabIndex=$currentTabIndex, relativeButtonId=$relativeButtonId, iconPath=$iconPath',
    );

    // 該当するショートカットを更新（現在のタブインデックスと相対ボタンIDで検索）
    final shortcutIndex = currentShortcuts.indexWhere(
      (s) => s.tabIndex == currentTabIndex && s.buttonId == relativeButtonId,
    );

    if (shortcutIndex != -1) {
      print('既存ショートカットのアイコンを更新: shortcutIndex=$shortcutIndex');
      currentShortcuts[shortcutIndex] = currentShortcuts[shortcutIndex]
          .copyWith(
            iconPath: iconPath,
            iconSource: "manual", // 手動でアイコン変更
          );
    } else {
      print('新規ショートカットを作成してアイコンを設定');
      // ショートカットが存在しない場合は新規作成
      final controllerIndex = (currentTabIndex * 6) + (relativeButtonId - 1);
      final name = controllerIndex < _nameControllers.length
          ? _nameControllers[controllerIndex].text.trim()
          : '$relativeButtonId';
      final path = controllerIndex < _pathControllers.length
          ? _pathControllers[controllerIndex].text.trim()
          : '';

      currentShortcuts.add(
        Shortcut(
          buttonId: relativeButtonId,
          name: name.isEmpty ? '$relativeButtonId' : name,
          path: path,
          args: [],
          tabIndex: currentTabIndex,
          iconPath: iconPath,
          iconSource: "manual", // 手動でアイコン変更
        ),
      );
    }

    final updatedConfig = appState.config.copyWith(shortcuts: currentShortcuts);
    await appState.updateConfig(updatedConfig);

    // UIを更新
    setState(() {});
  }

  /// デフォルトアイコンに戻す
  // Future<void> _resetToDefaultIcon(int buttonId) async {
  //   final appState = context.read<AppState>();
  //   final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

  //   // buttonIdからタブインデックスと相対ボタンIDを計算
  //   final tabIndex = (buttonId - 1) ~/ 6;
  //   final relativeButtonId = ((buttonId - 1) % 6) + 1;

  //   // 該当するショートカットのアイコンパスをクリア（タブインデックスと相対ボタンIDで検索）
  //   final shortcutIndex = currentShortcuts.indexWhere(
  //     (s) => s.tabIndex == tabIndex && s.buttonId == relativeButtonId,
  //   );

  //   if (shortcutIndex != -1) {
  //     currentShortcuts[shortcutIndex] = currentShortcuts[shortcutIndex]
  //         .copyWith(iconPath: '');

  //     final updatedConfig = appState.config.copyWith(
  //       shortcuts: currentShortcuts,
  //     );
  //     await appState.updateConfig(updatedConfig);

  //     // UIを更新
  //     setState(() {});

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('デフォルトアイコンに戻しました'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _resetToDefaultIcon(int buttonId) async {
    final appState = context.read<AppState>();
    final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

    // 現在タブ + 相対ID(1..6) として扱う
    final tIndex = _tabController.index;
    final relativeButtonId = buttonId;

    final idx = currentShortcuts.indexWhere(
      (s) => s.tabIndex == tIndex && s.buttonId == relativeButtonId,
    );

    if (idx != -1) {
      currentShortcuts[idx] = currentShortcuts[idx].copyWith(iconPath: '');
      final updatedConfig = appState.config.copyWith(
        shortcuts: currentShortcuts,
      );
      await appState.updateConfig(updatedConfig);

      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('デフォルトアイコンに戻しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// タブ名変更ダイアログを表示
  Future<void> _showTabRenameDialog(int tabIndex) async {
    final currentName = tabIndex < _tabInfos.length
        ? _tabInfos[tabIndex].name
        : 'タブ ${tabIndex + 1}';
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('タブ名を変更'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('タブ ${tabIndex + 1} の名前を変更してください'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'タブ名',
                hintText: 'タブ 1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              autofocus: true,
              maxLength: 20,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (newName != null && newName != currentName) {
      setState(() {
        // _tabInfosリストを更新
        if (tabIndex < _tabInfos.length) {
          _tabInfos[tabIndex] = _tabInfos[tabIndex].copyWith(name: newName);
        } else {
          // 新しいTabInfoを追加
          while (_tabInfos.length <= tabIndex) {
            _tabInfos.add(
              TabInfo(
                index: _tabInfos.length,
                name: 'タブ ${_tabInfos.length + 1}',
              ),
            );
          }
          _tabInfos[tabIndex] = _tabInfos[tabIndex].copyWith(name: newName);
        }
      });

      // まず現在のコントローラーの内容を保存してからタブ情報を更新
      await _saveSettingsQuietly();

      // タブ情報を含めて設定を更新
      final appState = context.read<AppState>();
      final updatedConfig = appState.config.copyWith(tabs: _tabInfos);
      await appState.updateConfig(updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('タブ名を「$newName」に変更しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// タブの順序に基づいてコントローラーを並び替える
  Future<void> _reorderControllersBasedOnTabs(List<TabInfo> newTabOrder) async {
    final appState = context.read<AppState>();
    final currentShortcuts = List<Shortcut>.from(appState.config.shortcuts);

    final newNameControllers = <TextEditingController>[];
    final newPathControllers = <TextEditingController>[];
    final newIconControllers = <TextEditingController>[];
    final newShortcuts = <Shortcut>[];

    print('🔄 タブ並び替え開始: ${newTabOrder.length}個のタブを並び替え');

    // 新しい順序でコントローラーとショートカットデータを並び替え
    for (int newIndex = 0; newIndex < newTabOrder.length; newIndex++) {
      final oldIndex = newTabOrder[newIndex].index;
      final startOldIndex = oldIndex * 6;

      print('🔄 タブ並び替え: oldIndex=$oldIndex -> newIndex=$newIndex');

      // 6つのボタン分のコントローラーとショートカットデータを移動
      for (int i = 0; i < 6; i++) {
        final relativeButtonId = i + 1;
        final controllerIndex = startOldIndex + i;

        if (controllerIndex < _nameControllers.length &&
            controllerIndex < _pathControllers.length) {
          // 既存のコントローラーを移動
          newNameControllers.add(_nameControllers[controllerIndex]);
          newPathControllers.add(_pathControllers[controllerIndex]);
          if (controllerIndex < _iconControllers.length) {
            newIconControllers.add(_iconControllers[controllerIndex]);
          } else {
            newIconControllers.add(TextEditingController(text: ''));
          }

          // 元のタブ位置でショートカットを直接検索（シンプルで確実）
          final existingShortcut = currentShortcuts.firstWhere(
            (s) => s.tabIndex == oldIndex && s.buttonId == relativeButtonId,
            orElse: () => Shortcut(
              buttonId: relativeButtonId,
              name: _nameControllers[controllerIndex].text.trim().isEmpty
                  ? '$relativeButtonId'
                  : _nameControllers[controllerIndex].text.trim(),
              path: _pathControllers[controllerIndex].text.trim(),
              tabIndex: newIndex,
              args: [],
              iconPath: '',
              iconSource: '',
            ),
          );

          // 新しいタブインデックスでショートカットを作成（アイコンパスを確実に保持）
          final newShortcut = existingShortcut.copyWith(
            tabIndex: newIndex,
            name: _nameControllers[controllerIndex].text.trim().isEmpty
                ? '$relativeButtonId'
                : _nameControllers[controllerIndex].text.trim(),
            path: _pathControllers[controllerIndex].text.trim(),
          );

          newShortcuts.add(newShortcut);
          print(
            '✅ ショートカット移動完了: タブ$oldIndex->$newIndex, ボタン$relativeButtonId, アイコン=${newShortcut.iconPath}',
          );
        } else {
          // 新しいコントローラーを作成
          final nameController = TextEditingController(
            text: '$relativeButtonId',
          );
          final pathController = TextEditingController(text: '');
          final iconController = TextEditingController(text: '');
          nameController.addListener(() => _autoSave());
          pathController.addListener(
            () => _autoSaveAndExtractIcon(newIndex * 6 + relativeButtonId),
          );
          newNameControllers.add(nameController);
          newPathControllers.add(pathController);
          newIconControllers.add(iconController);

          // 新しいショートカットを作成
          newShortcuts.add(
            Shortcut(
              buttonId: relativeButtonId,
              name: '$relativeButtonId',
              path: '',
              tabIndex: newIndex,
              args: [],
              iconPath: '',
              iconSource: '',
            ),
          );

          print('🆕 新規ショートカット作成: タブ$newIndex, ボタン$relativeButtonId');
        }
      }
    }

    // 古いコントローラーを破棄
    for (final controller in _nameControllers) {
      if (!newNameControllers.contains(controller)) {
        controller.dispose();
      }
    }
    for (final controller in _pathControllers) {
      if (!newPathControllers.contains(controller)) {
        controller.dispose();
      }
    }
    for (final controller in _iconControllers) {
      if (!newIconControllers.contains(controller)) {
        controller.dispose();
      }
    }

    // 新しいコントローラーリストを設定
    _nameControllers.clear();
    _pathControllers.clear();
    _iconControllers.clear();
    _nameControllers.addAll(newNameControllers);
    _pathControllers.addAll(newPathControllers);
    _iconControllers.addAll(newIconControllers);

    // TabInfoのindexを更新
    for (int i = 0; i < _tabInfos.length; i++) {
      _tabInfos[i] = _tabInfos[i].copyWith(index: i);
    }

    print('🔄 タブ並び替え完了: ${newShortcuts.length}個のショートカットを更新');

    // 並び替えられたショートカットデータを保存
    final updatedConfig = appState.config.copyWith(
      shortcuts: newShortcuts,
      tabs: _tabInfos,
    );
    await appState.updateConfig(updatedConfig);

    // UIを強制的に更新
    _forceIconRefresh();
  }

  /// 設定をリセット
  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定をリセット'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('すべての設定をリセットしますか？この操作は元に戻せません。'),
            const SizedBox(height: 12),
            if (_totalTabs > 1) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'リセット内容',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 「タブ 1」のみ残して他のタブを削除\n'
                      '• 全てのショートカットをクリア\n'
                      '• カスタムアイコンもクリア',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'リセット内容',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 全てのショートカットをクリア\n'
                      '• カスタムアイコンもクリア\n'
                      '• タブ名を「タブ 1」にリセット',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        // 複数タブがある場合は、タブ1以外を削除
        if (_totalTabs > 1) {
          // タブ1以外のコントローラーを削除（逆順で削除してインデックスのずれを防ぐ）
          for (int tabIndex = _totalTabs - 1; tabIndex >= 1; tabIndex--) {
            final startIndex = tabIndex * 6;
            for (int i = 5; i >= 0; i--) {
              final index = startIndex + i;
              if (index < _nameControllers.length) {
                _nameControllers[index].dispose();
                _pathControllers[index].dispose();
                _nameControllers.removeAt(index);
                _pathControllers.removeAt(index);
              }
            }
          }

          // タブ情報をリセット（タブ1のみ残す）
          _tabInfos.clear();
          _tabInfos.add(TabInfo(index: 0, name: 'タブ 1'));
          _totalTabs = 1;

          // TabControllerを再作成
          _tabController.dispose();
          _tabController = TabController(length: 1, vsync: this);
        } else {
          // タブが1つの場合は名前をリセット
          _tabInfos.clear();
          _tabInfos.add(TabInfo(index: 0, name: 'タブ 1'));
        }

        // タブ1のコントローラーをリセット
        for (int i = 0; i < 6 && i < _nameControllers.length; i++) {
          _nameControllers[i].text = '';
          _pathControllers[i].text = '';
        }
      });

      // AppStateの設定もリセット
      final appState = context.read<AppState>();
      await appState.resetConfig();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _totalTabs > 1 ? '設定をリセットし、「タブ 1」のみ残しました' : '設定をリセットしました',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
