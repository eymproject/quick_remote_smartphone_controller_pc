import 'dart:io';
import 'package:logger/logger.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// ネットワーク自動設定クラス
class NetworkSetup {
  static final Logger _logger = Logger();
  static const String _serviceName = 'QRSC_PC';
  static const int _defaultPort = 8080;

  /// 自動ネットワーク設定を実行
  static Future<bool> setupNetwork({int port = _defaultPort}) async {
    try {
      _logger.i('ネットワーク自動設定を開始します...');

      // 実際のIPアドレスを取得
      final ipAddress = await getLocalIPAddress();
      if (ipAddress == null) {
        _logger.w('ローカルIPアドレスの取得に失敗しました');
        return false;
      }

      _logger.i('検出されたIPアドレス: $ipAddress');

      // ポート使用可能性をチェック
      final isPortAvailable = await checkPortAvailability(port);
      if (!isPortAvailable) {
        _logger.w('ポート$portは既に使用されています');
        return false;
      }

      _logger.i('✅ ネットワーク設定が完了しました: $ipAddress:$port');
      return true;
    } catch (e) {
      _logger.e('ネットワーク自動設定中にエラーが発生しました', error: e);
      return false;
    }
  }

  /// ローカルIPアドレスを取得
  static Future<String?> getLocalIPAddress() async {
    try {
      final info = NetworkInfo();
      
      // Wi-Fi IPアドレスを取得
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '127.0.0.1') {
        _logger.i('Wi-Fi IPアドレスを検出: $wifiIP');
        return wifiIP;
      }

      // ネットワークインターフェースから取得
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // ローカルネットワークのIPアドレスを検索
          if (!addr.isLoopback && 
              (addr.address.startsWith('192.168.') || 
               addr.address.startsWith('10.') || 
               addr.address.startsWith('172.'))) {
            _logger.i('ネットワークインターフェースからIPアドレスを検出: ${addr.address}');
            return addr.address;
          }
        }
      }
      
      _logger.w('ローカルIPアドレスが見つかりませんでした');
      return null;
    } catch (e) {
      _logger.e('ローカルIPアドレス取得エラー', error: e);
      return null;
    }
  }

  /// ポートの使用可能性をチェック
  static Future<bool> checkPortAvailability(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      _logger.i('ポート$portは使用可能です');
      return true;
    } catch (e) {
      _logger.w('ポート$portは使用できません: $e');
      return false;
    }
  }

  /// ネットワーク接続状況を診断
  static Future<Map<String, dynamic>> diagnoseNetwork() async {
    final result = <String, dynamic>{};
    
    try {
      // IPアドレス取得
      final ipAddress = await getLocalIPAddress();
      result['ipAddress'] = ipAddress;
      result['hasValidIP'] = ipAddress != null;

      // ネットワーク情報取得
      final info = NetworkInfo();
      result['wifiName'] = await info.getWifiName();
      result['wifiBSSID'] = await info.getWifiBSSID();
      result['wifiIP'] = await info.getWifiIP();

      // ポート使用可能性
      result['portAvailable'] = await checkPortAvailability(_defaultPort);

      // 接続性テスト
      result['internetConnectivity'] = await testInternetConnectivity();

      _logger.i('ネットワーク診断完了: $result');
    } catch (e) {
      _logger.e('ネットワーク診断エラー', error: e);
      result['error'] = e.toString();
    }
    
    return result;
  }

  /// インターネット接続性をテスト
  static Future<bool> testInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      _logger.w('インターネット接続テスト失敗: $e');
      return false;
    }
  }

  /// ファイアウォール状況を確認
  static Future<Map<String, dynamic>> checkFirewallStatus(int port) async {
    final result = <String, dynamic>{};
    
    try {
      // ローカル接続テスト
      final localTest = await testLocalConnection(port);
      result['localConnection'] = localTest;

      // 外部接続テスト（同一ネットワーク内）
      final externalTest = await testExternalConnection(port);
      result['externalConnection'] = externalTest;

      // ファイアウォール推定
      result['firewallBlocked'] = localTest && !externalTest;
      
      if (result['firewallBlocked'] == true) {
        result['recommendation'] = 'Windows Defenderファイアウォールでポート${port}が ブロックされている可能性があります';
      } else if (!localTest) {
        result['recommendation'] = 'サーバーが起動していない可能性があります';
      } else {
        result['recommendation'] = '接続に問題はありません';
      }

      _logger.i('ファイアウォール診断完了: $result');
    } catch (e) {
      _logger.e('ファイアウォール診断エラー', error: e);
      result['error'] = e.toString();
    }
    
    return result;
  }

  /// ローカル接続をテスト
  static Future<bool> testLocalConnection(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 外部接続をテスト
  static Future<bool> testExternalConnection(int port) async {
    try {
      final ipAddress = await getLocalIPAddress();
      if (ipAddress == null) return false;

      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 推奨設定を取得
  static Future<Map<String, dynamic>> getRecommendedSettings() async {
    final settings = <String, dynamic>{};
    
    try {
      // 最適なIPアドレス
      settings['recommendedIP'] = await getLocalIPAddress();
      
      // 利用可能なポート
      final availablePorts = <int>[];
      for (int port = 8080; port <= 8090; port++) {
        if (await checkPortAvailability(port)) {
          availablePorts.add(port);
        }
      }
      settings['availablePorts'] = availablePorts;
      settings['recommendedPort'] = availablePorts.isNotEmpty ? availablePorts.first : 8080;

      // ネットワーク情報
      final networkDiagnosis = await diagnoseNetwork();
      settings['networkInfo'] = networkDiagnosis;

      _logger.i('推奨設定: $settings');
    } catch (e) {
      _logger.e('推奨設定取得エラー', error: e);
      settings['error'] = e.toString();
    }
    
    return settings;
  }
}
