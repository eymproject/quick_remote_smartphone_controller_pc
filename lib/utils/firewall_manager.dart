import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

/// Windowsファイアウォール管理クラス
class FirewallManager {
  static const String ruleName = 'QRSC_PC';
  static const int port = 8080;

  /// 管理者権限をチェック
  static Future<bool> isRunningAsAdmin() async {
    try {
      // net sessionコマンドで管理者権限をチェック
      final result = await Process.run(
        'net',
        ['session'],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 管理者権限で外部プロセスを実行
  static Future<FirewallResult> _runAsAdmin(List<String> command) async {
    try {
      // 一時的なPowerShellスクリプトファイルを作成
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}/eym_firewall_setup.ps1');
      
      // PowerShellスクリプトの内容を作成
      final scriptContent = '''
# QRSC_PC Firewall Setup Script
try {
    \$process = Start-Process -FilePath "${command[0]}" -ArgumentList "${command.skip(1).join('", "')}" -Verb RunAs -Wait -PassThru
    if (\$process.ExitCode -eq 0) {
        Write-Host "SUCCESS: Command executed successfully"
        exit 0
    } else {
        Write-Host "ERROR: Command failed with exit code \$(\$process.ExitCode)"
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to execute command: \$(\$_.Exception.Message)"
    exit 1
}
''';

      // スクリプトファイルに書き込み
      await scriptFile.writeAsString(scriptContent, encoding: utf8);

      // PowerShellスクリプトを実行
      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
        runInShell: true,
      );

      // 一時ファイルを削除
      try {
        await scriptFile.delete();
      } catch (e) {
        print('一時ファイルの削除に失敗: $e');
      }

      return FirewallResult(
        success: result.exitCode == 0,
        message: result.exitCode == 0 
          ? 'ファイアウォール設定が正常に完了しました。'
          : 'ファイアウォール設定に失敗しました。UAC（ユーザーアカウント制御）で「はい」をクリックしてください。',
      );
    } catch (e) {
      return FirewallResult(
        success: false,
        message: '管理者権限での実行に失敗しました: $e\n\nUAC（ユーザーアカウント制御）ダイアログで「はい」をクリックしてください。',
      );
    }
  }

  /// ファイアウォールルールを追加
  static Future<FirewallResult> setupFirewall() async {
    try {
      final isAdmin = await isRunningAsAdmin();
      
      if (isAdmin) {
        // 管理者権限で実行中の場合、直接実行
        // 既存のルールを削除（重複防止）
        await Process.run(
          'netsh',
          [
            'advfirewall',
            'firewall',
            'delete',
            'rule',
            'name=$ruleName',
          ],
          runInShell: true,
        );

        // 新しいルールを追加
        final result = await Process.run(
          'netsh',
          [
            'advfirewall',
            'firewall',
            'add',
            'rule',
            'name=$ruleName',
            'dir=in',
            'action=allow',
            'protocol=TCP',
            'localport=$port',
            'profile=any',
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          return FirewallResult(
            success: true,
            message: 'ファイアウォール設定が完了しました！\n'
                'ポート$portの受信が許可されました。',
          );
        } else {
          return FirewallResult(
            success: false,
            message: 'ファイアウォール設定に失敗しました。\n'
                'エラー: ${result.stderr}',
          );
        }
      } else {
        // 管理者権限がない場合、UAC昇格を試行
        final deleteCommand = [
          'netsh',
          'advfirewall',
          'firewall',
          'delete',
          'rule',
          'name=$ruleName'
        ];
        
        final addCommand = [
          'netsh',
          'advfirewall',
          'firewall',
          'add',
          'rule',
          'name=$ruleName',
          'dir=in',
          'action=allow',
          'protocol=TCP',
          'localport=$port',
          'profile=any'
        ];

        // 既存ルール削除（エラーは無視）
        await _runAsAdmin(deleteCommand);
        
        // 新しいルール追加
        final result = await _runAsAdmin(addCommand);
        
        if (result.success) {
          // 設定後に実際にルールが追加されたか確認
          await Future.delayed(const Duration(milliseconds: 500)); // 少し待つ
          final ruleExists = await isFirewallRuleExists();
          if (ruleExists) {
            return FirewallResult(
              success: true,
              message: 'ファイアウォール設定が完了しました！\n'
                  'ポート$portの受信が許可されました。',
            );
          } else {
            return FirewallResult(
              success: false,
              message: 'ファイアウォール設定に失敗しました。\n'
                  'ルールが正常に追加されませんでした。',
            );
          }
        } else {
          return FirewallResult(
            success: false,
            message: 'ファイアウォール設定に失敗しました。\n'
                'UAC（ユーザーアカウント制御）で「はい」をクリックしてください。',
            needsAdmin: true,
          );
        }
      }
    } catch (e) {
      return FirewallResult(
        success: false,
        message: 'ファイアウォール設定中にエラーが発生しました: $e',
      );
    }
  }

  /// ファイアウォールルールを削除
  static Future<FirewallResult> removeFirewall() async {
    try {
      // まずルールが存在するかチェック
      final ruleExists = await isFirewallRuleExists();
      if (!ruleExists) {
        return FirewallResult(
          success: false,
          message: 'QRSC_PCのファイアウォールルールが見つかりません。\n'
              '既に削除されているか、設定されていない可能性があります。',
        );
      }

      final isAdmin = await isRunningAsAdmin();
      
      if (isAdmin) {
        // 管理者権限で実行中の場合、直接実行
        final result = await Process.run(
          'netsh',
          [
            'advfirewall',
            'firewall',
            'delete',
            'rule',
            'name=$ruleName',
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          return FirewallResult(
            success: true,
            message: 'ファイアウォール設定を削除しました。\n'
                'QRSC_PCのルールが削除されました。',
          );
        } else {
          return FirewallResult(
            success: false,
            message: 'ファイアウォール設定の削除に失敗しました。\n'
                'エラー: ${result.stderr}',
          );
        }
      } else {
        // 管理者権限がない場合、UAC昇格を試行
        final deleteCommand = [
          'netsh',
          'advfirewall',
          'firewall',
          'delete',
          'rule',
          'name=$ruleName'
        ];

        final result = await _runAsAdmin(deleteCommand);
        
        if (result.success) {
          // 削除後に再度確認
          final stillExists = await isFirewallRuleExists();
          if (!stillExists) {
            return FirewallResult(
              success: true,
              message: 'ファイアウォール設定を削除しました。\n'
                  'QRSC_PCのルールが削除されました。',
            );
          } else {
            return FirewallResult(
              success: false,
              message: 'ファイアウォール設定の削除に失敗しました。\n'
                  'ルールが残っています。',
            );
          }
        } else {
          return FirewallResult(
            success: false,
            message: 'ファイアウォール設定の削除に失敗しました。\n'
                'UAC（ユーザーアカウント制御）で「はい」をクリックしてください。',
            needsAdmin: true,
          );
        }
      }
    } catch (e) {
      return FirewallResult(
        success: false,
        message: 'ファイアウォール設定削除中にエラーが発生しました: $e',
      );
    }
  }

  /// ファイアウォールルールの存在確認
  static Future<bool> isFirewallRuleExists() async {
    try {
      final result = await Process.run(
        'netsh',
        [
          'advfirewall',
          'firewall',
          'show',
          'rule',
          'name=$ruleName',
        ],
        runInShell: true,
      );

      // ルールが存在する場合、出力にルール名が含まれる
      return result.stdout.toString().contains(ruleName);
    } catch (e) {
      return false;
    }
  }

  /// 管理者として再起動を促すダイアログ用のメッセージ
  static String getAdminRequiredMessage() {
    return 'ファイアウォール設定には管理者権限が必要です。\n\n'
        '手順:\n'
        '1. QRSC_PCを終了\n'
        '2. QRSC_PCを右クリック\n'
        '3. "管理者として実行" を選択\n'
        '4. UACで「はい」をクリック\n\n'
        'または、手動でファイアウォール設定を行ってください:\n'
        '- Windows設定 → Windows セキュリティ\n'
        '- ファイアウォールとネットワーク保護\n'
        '- 詳細設定 → 受信の規則 → 新しい規則\n'
        '- ポート → TCP → $port → 許可';
  }

  /// アプリを管理者権限で再起動
  static Future<bool> restartAsAdmin() async {
    try {
      // 現在の実行ファイルのパスを取得
      final executablePath = Platform.resolvedExecutable;
      
      // PowerShellを使用して管理者権限で再起動
      await Process.start(
        'powershell',
        [
          '-Command',
          'Start-Process -FilePath "$executablePath" -Verb RunAs'
        ],
        runInShell: true,
      );
      
      // 現在のアプリを強制終了
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
      
      return true;
    } catch (e) {
      print('管理者権限での再起動に失敗: $e');
      return false;
    }
  }

  /// アプリを通常権限で再起動
  static Future<bool> restartAsNormal() async {
    try {
      // 現在の実行ファイルのパスを取得
      final executablePath = Platform.resolvedExecutable;
      
      // 通常権限で新しいプロセスを開始
      await Process.start(
        executablePath,
        [],
        runInShell: false,
      );
      
      // 現在のアプリを強制終了
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
      
      return true;
    } catch (e) {
      print('通常権限での再起動に失敗: $e');
      return false;
    }
  }
}

/// ファイアウォール操作の結果
class FirewallResult {
  final bool success;
  final String message;
  final bool needsAdmin;

  FirewallResult({
    required this.success,
    required this.message,
    this.needsAdmin = false,
  });
}
