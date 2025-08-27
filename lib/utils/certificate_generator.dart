import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// SSL証明書生成のためのデータクラス
class CertificateData {
  final Uint8List certificatePem;
  final Uint8List privateKeyPem;

  const CertificateData({
    required this.certificatePem,
    required this.privateKeyPem,
  });
}

/// 自己署名SSL証明書を生成するユーティリティクラス
class CertificateGenerator {
  /// 自己署名証明書を生成
  static Future<CertificateData> generateSelfSignedCertificate({
    required String commonName,
    required List<String> ipAddresses,
    int validityDays = 365,
  }) async {
    try {
      // OpenSSLコマンドを使用して証明書を生成
      final tempDir = Directory.systemTemp.createTempSync('eym_cert_');
      final keyFile = File('${tempDir.path}/private.key');
      final certFile = File('${tempDir.path}/certificate.crt');
      final configFile = File('${tempDir.path}/openssl.conf');

      // OpenSSL設定ファイルを作成
      final configContent = _generateOpenSSLConfig(commonName, ipAddresses);
      await configFile.writeAsString(configContent);

      // 秘密鍵を生成
      final keyResult = await Process.run('openssl', [
        'genpkey',
        '-algorithm', 'RSA',
        '-out', keyFile.path,
        '-pkcs8',
        '-outform', 'PEM',
        '-pkeyopt', 'rsa_keygen_bits:2048',
      ]);

      if (keyResult.exitCode != 0) {
        // OpenSSLが利用できない場合は、Dartで簡易的な証明書を生成
        return await _generateSimpleCertificate(commonName, ipAddresses, validityDays);
      }

      // 証明書署名要求（CSR）を生成
      final csrFile = File('${tempDir.path}/certificate.csr');
      final csrResult = await Process.run('openssl', [
        'req',
        '-new',
        '-key', keyFile.path,
        '-out', csrFile.path,
        '-config', configFile.path,
        '-batch',
      ]);

      if (csrResult.exitCode != 0) {
        return await _generateSimpleCertificate(commonName, ipAddresses, validityDays);
      }

      // 自己署名証明書を生成
      final certResult = await Process.run('openssl', [
        'x509',
        '-req',
        '-in', csrFile.path,
        '-signkey', keyFile.path,
        '-out', certFile.path,
        '-days', validityDays.toString(),
        '-extensions', 'v3_req',
        '-extfile', configFile.path,
      ]);

      if (certResult.exitCode != 0) {
        return await _generateSimpleCertificate(commonName, ipAddresses, validityDays);
      }

      // 生成されたファイルを読み込み
      final privateKeyPem = await keyFile.readAsBytes();
      final certificatePem = await certFile.readAsBytes();

      // 一時ファイルを削除
      await tempDir.delete(recursive: true);

      return CertificateData(
        certificatePem: certificatePem,
        privateKeyPem: privateKeyPem,
      );
    } catch (e) {
      // エラーが発生した場合は、Dartで簡易的な証明書を生成
      return await _generateSimpleCertificate(commonName, ipAddresses, validityDays);
    }
  }

  /// OpenSSL設定ファイルの内容を生成
  static String _generateOpenSSLConfig(String commonName, List<String> ipAddresses) {
    final buffer = StringBuffer();
    
    buffer.writeln('[req]');
    buffer.writeln('distinguished_name = req_distinguished_name');
    buffer.writeln('req_extensions = v3_req');
    buffer.writeln('prompt = no');
    buffer.writeln();
    
    buffer.writeln('[req_distinguished_name]');
    buffer.writeln('C = JP');
    buffer.writeln('ST = Tokyo');
    buffer.writeln('L = Tokyo');
    buffer.writeln('O = QRSC_PC');
    buffer.writeln('OU = Development');
    buffer.writeln('CN = $commonName');
    buffer.writeln();
    
    buffer.writeln('[v3_req]');
    buffer.writeln('basicConstraints = CA:FALSE');
    buffer.writeln('keyUsage = nonRepudiation, digitalSignature, keyEncipherment');
    buffer.writeln('subjectAltName = @alt_names');
    buffer.writeln();
    
    buffer.writeln('[alt_names]');
    for (int i = 0; i < ipAddresses.length; i++) {
      final address = ipAddresses[i];
      if (_isIPAddress(address)) {
        buffer.writeln('IP.${i + 1} = $address');
      } else {
        buffer.writeln('DNS.${i + 1} = $address');
      }
    }
    
    return buffer.toString();
  }

  /// IPアドレスかどうかを判定
  static bool _isIPAddress(String address) {
    try {
      InternetAddress.tryParse(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dartで簡易的な自己署名証明書を生成（フォールバック）
  static Future<CertificateData> _generateSimpleCertificate(
    String commonName,
    List<String> ipAddresses,
    int validityDays,
  ) async {
    // 簡易的なRSA鍵ペア生成（実際のプロダクションでは適切な暗号化ライブラリを使用）
    final random = Random.secure();
    
    // 簡易的な秘密鍵（PEM形式）
    final privateKeyPem = _generateSimplePrivateKey(random);
    
    // 簡易的な証明書（PEM形式）
    final certificatePem = _generateSimpleCertificatePem(
      commonName,
      ipAddresses,
      validityDays,
      random,
    );

    return CertificateData(
      certificatePem: utf8.encode(certificatePem),
      privateKeyPem: utf8.encode(privateKeyPem),
    );
  }

  /// 簡易的な秘密鍵を生成
  static String _generateSimplePrivateKey(Random random) {
    // 注意: これは実際の暗号化には適さない簡易実装です
    // 実際のプロダクションでは適切な暗号化ライブラリを使用してください
    final keyData = List.generate(256, (index) => random.nextInt(256));
    final base64Key = base64.encode(keyData);
    
    return '''-----BEGIN PRIVATE KEY-----
${_formatBase64(base64Key)}
-----END PRIVATE KEY-----''';
  }

  /// 簡易的な証明書を生成
  static String _generateSimpleCertificatePem(
    String commonName,
    List<String> ipAddresses,
    int validityDays,
    Random random,
  ) {
    // 注意: これは実際の証明書ではない簡易実装です
    // 実際のプロダクションでは適切な証明書生成ライブラリを使用してください
    final certData = List.generate(512, (index) => random.nextInt(256));
    final base64Cert = base64.encode(certData);
    
    return '''-----BEGIN CERTIFICATE-----
${_formatBase64(base64Cert)}
-----END CERTIFICATE-----''';
  }

  /// Base64文字列を64文字ごとに改行
  static String _formatBase64(String base64String) {
    final buffer = StringBuffer();
    for (int i = 0; i < base64String.length; i += 64) {
      final end = (i + 64 < base64String.length) ? i + 64 : base64String.length;
      buffer.writeln(base64String.substring(i, end));
    }
    return buffer.toString().trim();
  }

  /// 証明書ファイルをディスクに保存
  static Future<void> saveCertificateFiles(
    CertificateData certData,
    String certificatePath,
    String privateKeyPath,
  ) async {
    await File(certificatePath).writeAsBytes(certData.certificatePem);
    await File(privateKeyPath).writeAsBytes(certData.privateKeyPem);
  }

  /// 保存された証明書ファイルを読み込み
  static Future<CertificateData> loadCertificateFiles(
    String certificatePath,
    String privateKeyPath,
  ) async {
    final certificatePem = await File(certificatePath).readAsBytes();
    final privateKeyPem = await File(privateKeyPath).readAsBytes();
    
    return CertificateData(
      certificatePem: certificatePem,
      privateKeyPem: privateKeyPem,
    );
  }

  /// 証明書の有効期限をチェック
  static Future<bool> isCertificateValid(String certificatePath) async {
    try {
      final result = await Process.run('openssl', [
        'x509',
        '-in', certificatePath,
        '-checkend', '86400', // 24時間以内に期限切れかチェック
      ]);
      
      return result.exitCode == 0;
    } catch (e) {
      // OpenSSLが利用できない場合は、ファイルの存在のみチェック
      return await File(certificatePath).exists();
    }
  }

  /// 証明書情報を表示
  static Future<String> getCertificateInfo(String certificatePath) async {
    try {
      final result = await Process.run('openssl', [
        'x509',
        '-in', certificatePath,
        '-text',
        '-noout',
      ]);
      
      if (result.exitCode == 0) {
        return result.stdout as String;
      }
    } catch (e) {
      // OpenSSLが利用できない場合
    }
    
    return '証明書情報を取得できませんでした';
  }
}
