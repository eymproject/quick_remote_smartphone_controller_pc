import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

/// アイコン品質レベル
enum IconQuality {
  veryLow,  // 64x64未満
  low,      // 64x64以上128x128未満
  medium,   // 128x128以上256x256未満
  high,     // 256x256以上
}

/// 画像処理ユーティリティクラス
class ImageProcessor {
  /// 画像ファイルを512x512ピクセルの超高解像度アイコンサイズにリサイズしてPNGとして保存
  /// 
  /// [imagePath] 元画像ファイルのパス
  /// [outputPath] 出力先ファイルのパス
  /// 
  /// 戻り値: 成功時はtrue、失敗時はfalse
  static Future<bool> resizeImageToIcon(String imagePath, String outputPath) async {
    try {
      // 画像ファイルを読み込み
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print('ImageProcessor: 画像ファイルが存在しません: $imagePath');
        return false;
      }

      final imageBytes = await imageFile.readAsBytes();
      
      // 画像をデコード
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ImageProcessor: 画像のデコードに失敗しました: $imagePath');
        return false;
      }

      // 512x512にリサイズ（縦横比を保持してフィット）
      img.Image resizedImage = img.copyResize(
        image,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.cubic,
      );

      // PNG形式で最高品質エンコード（圧縮レベル0=無圧縮、品質優先）
      final pngBytes = img.encodePng(resizedImage, level: 0);

      // 出力ディレクトリを作成
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // ファイルに保存
      await outputFile.writeAsBytes(pngBytes);

      print('ImageProcessor: 超高解像度画像リサイズ成功: $outputPath (512x512)');
      return true;
    } catch (e) {
      print('ImageProcessor: 画像リサイズエラー: $e');
      return false;
    }
  }

  /// 画像ファイルを512x512ピクセルの超高解像度アイコンサイズにリサイズ（透明背景対応）
  /// 
  /// [imagePath] 元画像ファイルのパス
  /// [outputPath] 出力先ファイルのパス
  /// [backgroundColor] 背景色（透明の場合はnull）
  /// 
  /// 戻り値: 成功時はtrue、失敗時はfalse
  static Future<bool> resizeImageToIconWithBackground(
    String imagePath, 
    String outputPath, {
    img.ColorRgba8? backgroundColor,
  }) async {
    try {
      // 画像ファイルを読み込み
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print('ImageProcessor: 画像ファイルが存在しません: $imagePath');
        return false;
      }

      final imageBytes = await imageFile.readAsBytes();
      
      // 画像をデコード
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ImageProcessor: 画像のデコードに失敗しました: $imagePath');
        return false;
      }

      // 512x512の背景画像を作成
      img.Image background = img.Image(width: 512, height: 512);
      
      if (backgroundColor != null) {
        // 指定された背景色で塗りつぶし
        img.fill(background, color: backgroundColor);
      } else {
        // 透明背景
        img.fill(background, color: img.ColorRgba8(0, 0, 0, 0));
      }

      // 元画像を縦横比を保持してリサイズ
      final aspectRatio = image.width / image.height;
      int newWidth, newHeight;
      
      if (aspectRatio > 1) {
        // 横長の画像
        newWidth = 512;
        newHeight = (512 / aspectRatio).round();
      } else {
        // 縦長または正方形の画像
        newHeight = 512;
        newWidth = (512 * aspectRatio).round();
      }

      img.Image resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );

      // 中央に配置
      final offsetX = (512 - newWidth) ~/ 2;
      final offsetY = (512 - newHeight) ~/ 2;

      img.compositeImage(
        background,
        resizedImage,
        dstX: offsetX,
        dstY: offsetY,
      );

      // PNG形式で最高品質エンコード（圧縮レベル0=無圧縮、品質優先）
      final pngBytes = img.encodePng(background, level: 0);

      // 出力ディレクトリを作成
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // ファイルに保存
      await outputFile.writeAsBytes(pngBytes);

      print('ImageProcessor: 超高解像度画像リサイズ成功（背景付き）: $outputPath (512x512)');
      return true;
    } catch (e) {
      print('ImageProcessor: 画像リサイズエラー（背景付き）: $e');
      return false;
    }
  }

  /// サポートされている画像形式かどうかを判定
  /// 
  /// [filePath] ファイルパス
  /// 
  /// 戻り値: サポートされている場合はtrue
  static bool isSupportedImageFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const supportedFormats = ['.png', '.jpg', '.jpeg', '.bmp', '.gif', '.ico', '.webp'];
    return supportedFormats.contains(extension);
  }

  /// カスタムアイコンファイル名を生成
  /// 
  /// [shortcutName] ショートカット名
  /// [originalImagePath] 元画像のパス
  /// 
  /// 戻り値: カスタムアイコンファイル名
  static String generateCustomIconFileName(String shortcutName, String originalImagePath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalExtension = path.extension(originalImagePath);
    final safeName = shortcutName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    return '${safeName}_custom_${timestamp}.png';
  }

  /// 画像ファイルの基本情報を取得
  /// 
  /// [imagePath] 画像ファイルのパス
  /// 
  /// 戻り値: 画像情報のマップ（width, height, format）
  static Future<Map<String, dynamic>?> getImageInfo(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return null;
      }

      return {
        'width': image.width,
        'height': image.height,
        'format': path.extension(imagePath).toLowerCase(),
        'fileSize': imageBytes.length,
      };
    } catch (e) {
      print('ImageProcessor: 画像情報取得エラー: $e');
      return null;
    }
  }


  /// 元画像サイズに基づいて最適なターゲットサイズを決定
  /// 
  /// [originalWidth] 元画像の幅
  /// [originalHeight] 元画像の高さ
  /// 
  /// 戻り値: 最適なターゲットサイズ
  static int determineOptimalSize(int originalWidth, int originalHeight) {
    final maxDimension = math.max(originalWidth, originalHeight);
    
    if (maxDimension >= 256) return 512;  // 高解像度 → 512x512
    if (maxDimension >= 128) return 256;  // 中解像度 → 256x256
    if (maxDimension >= 64) return 128;   // 低解像度 → 128x128
    return 64;                            // 極小 → 64x64（品質優先）
  }

  /// アイコンの品質レベルを評価
  /// 
  /// [width] 画像の幅
  /// [height] 画像の高さ
  /// 
  /// 戻り値: 品質レベル
  static IconQuality assessIconQuality(int width, int height) {
    final pixels = width * height;
    if (pixels >= 65536) return IconQuality.high;    // 256x256以上
    if (pixels >= 16384) return IconQuality.medium;  // 128x128以上
    if (pixels >= 4096) return IconQuality.low;      // 64x64以上
    return IconQuality.veryLow;                      // 64x64未満
  }

  /// 高品質アイコンリサイズ（元サイズに基づく最適化）
  /// 
  /// [imagePath] 元画像ファイルのパス
  /// [outputPath] 出力先ファイルのパス
  /// [forceSize] 強制的に指定サイズにする場合のサイズ（nullの場合は自動決定）
  /// 
  /// 戻り値: 成功時はtrue、失敗時はfalse
  static Future<bool> resizeIconWithQualityOptimization(
    String imagePath, 
    String outputPath, {
    int? forceSize,
  }) async {
    try {
      // 画像ファイルを読み込み
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print('ImageProcessor: 画像ファイルが存在しません: $imagePath');
        return false;
      }

      final imageBytes = await imageFile.readAsBytes();
      final originalFileSize = imageBytes.length;
      
      // 画像をデコード
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ImageProcessor: 画像のデコードに失敗しました: $imagePath');
        return false;
      }

      final originalWidth = image.width;
      final originalHeight = image.height;
      final quality = assessIconQuality(originalWidth, originalHeight);
      
      // ターゲットサイズを決定（512x512で統一）
      final targetSize = forceSize ?? 512;
      
      print('ImageProcessor: 品質最適化リサイズ開始');
      print('  - 元サイズ: ${originalWidth}x${originalHeight}');
      print('  - 元ファイルサイズ: ${(originalFileSize / 1024).toStringAsFixed(1)}KB');
      print('  - 品質レベル: $quality');
      print('  - ターゲットサイズ: ${targetSize}x$targetSize');

      // 品質レベルに基づいて最適な補間方法を選択（HighQualityBicubic相当に統一）
      img.Image resizedImage;
      
      switch (quality) {
        case IconQuality.high:
          // 高品質画像: Cubic補間で最高品質
          resizedImage = img.copyResize(
            image,
            width: targetSize,
            height: targetSize,
            interpolation: img.Interpolation.cubic,
          );
          print('  - 補間方法: HighQualityCubic（高品質画像）');
          break;
          
        case IconQuality.medium:
          // 中品質画像: Cubic補間
          resizedImage = img.copyResize(
            image,
            width: targetSize,
            height: targetSize,
            interpolation: img.Interpolation.cubic,
          );
          print('  - 補間方法: HighQualityCubic（中品質画像）');
          break;
          
        case IconQuality.low:
          // 低品質画像: Cubic補間 + シャープネス調整
          resizedImage = img.copyResize(
            image,
            width: targetSize,
            height: targetSize,
            interpolation: img.Interpolation.cubic,
          );
          // 軽いシャープネス適用
          resizedImage = img.convolution(resizedImage, filter: [
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0
          ], div: 1);
          print('  - 補間方法: HighQualityCubic + シャープネス（低品質画像）');
          break;
          
        case IconQuality.veryLow:
          // 極低品質画像: 段階的リサイズで品質保持
          final conservativeSize = math.min(targetSize, originalWidth * 2);
          resizedImage = img.copyResize(
            image,
            width: conservativeSize,
            height: conservativeSize,
            interpolation: img.Interpolation.nearest,
          );
          
          // 必要に応じて最終サイズに調整
          if (conservativeSize < targetSize) {
            resizedImage = img.copyResize(
              resizedImage,
              width: targetSize,
              height: targetSize,
              interpolation: img.Interpolation.cubic,
            );
          }
          print('  - 補間方法: Nearest → HighQualityCubic（極低品質画像）');
          break;
      }

      // 品質向上のための後処理
      if (quality == IconQuality.low || quality == IconQuality.veryLow) {
        // コントラスト微調整
        resizedImage = img.adjustColor(resizedImage, contrast: 1.05);
        print('  - 後処理: コントラスト調整適用');
      }

      // PNG形式で最高品質エンコード（無圧縮）
      final pngBytes = img.encodePng(resizedImage, level: 0);
      final finalFileSize = pngBytes.length;

      // 出力ディレクトリを作成
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // ファイルに保存
      await outputFile.writeAsBytes(pngBytes);

      // 詳細ログ出力
      print('ImageProcessor: 品質最適化リサイズ成功');
      print('  - 出力パス: $outputPath');
      print('  - 最終サイズ: ${targetSize}x$targetSize');
      print('  - 最終ファイルサイズ: ${(finalFileSize / 1024).toStringAsFixed(1)}KB');
      print('  - 品質設定: PNG無圧縮（level: 0）');
      
      // ファイルサイズ検証
      if (finalFileSize >= 50 * 1024) {
        print('  - ✅ 高品質アイコン生成成功（50KB以上）');
      } else {
        print('  - ⚠️ ファイルサイズが50KB未満（${(finalFileSize / 1024).toStringAsFixed(1)}KB）');
      }
      
      return true;
    } catch (e) {
      print('ImageProcessor: 品質最適化リサイズエラー: $e');
      return false;
    }
  }

  /// ファイルサイズ検証機能
  /// 
  /// [filePath] 検証するファイルのパス
  /// [minSizeKB] 最小ファイルサイズ（KB）
  /// 
  /// 戻り値: 検証結果の詳細情報
  static Future<Map<String, dynamic>> validateIconFileSize(String filePath, {int minSizeKB = 50}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'ファイルが存在しません',
          'fileSizeKB': 0,
          'meetsRequirement': false,
        };
      }

      final fileSize = await file.length();
      final fileSizeKB = fileSize / 1024;
      final meetsRequirement = fileSizeKB >= minSizeKB;

      return {
        'success': true,
        'fileSizeKB': fileSizeKB,
        'fileSizeBytes': fileSize,
        'minSizeKB': minSizeKB,
        'meetsRequirement': meetsRequirement,
        'message': meetsRequirement 
          ? '✅ 高品質アイコン（${fileSizeKB.toStringAsFixed(1)}KB）'
          : '⚠️ ファイルサイズ不足（${fileSizeKB.toStringAsFixed(1)}KB < ${minSizeKB}KB）',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'ファイルサイズ検証エラー: $e',
        'fileSizeKB': 0,
        'meetsRequirement': false,
      };
    }
  }
}
