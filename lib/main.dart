import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/app_state.dart';
import 'ui/main_screen.dart';
import 'ui/system_tray_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 単一インスタンス制御
  if (!await _checkSingleInstance()) {
    print('EYM Agent は既に実行中です。既存のインスタンスを表示します。');
    exit(0);
  }

  // ウィンドウマネージャーを初期化
  await windowManager.ensureInitialized();

  // ウィンドウ設定
  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 640),
    minimumSize: Size(900, 640), // 最小サイズを設定
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // ウィンドウを閉じる時にシステムトレイに最小化
    await windowManager.setPreventClose(true);
  });

  runApp(const QrscPCApp());
}

/// 単一インスタンス制御
Future<bool> _checkSingleInstance() async {
  try {
    // ポート8080でサーバーが既に起動しているかチェック
    final socket = await Socket.connect('localhost', 8080);
    await socket.close();

    // 既に起動している場合は、既存のウィンドウを表示するシグナルを送信
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://localhost:8080/show_window'),
      );
      request.headers.set('content-type', 'application/json');
      request.write('{"action": "show_window"}');
      await request.close();
      client.close();
    } catch (e) {
      print('既存インスタンスへのシグナル送信に失敗: $e');
    }

    return false; // 既に起動中
  } catch (e) {
    return true; // まだ起動していない
  }
}

class QrscPCApp extends StatelessWidget {
  const QrscPCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'EYM Agent',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
