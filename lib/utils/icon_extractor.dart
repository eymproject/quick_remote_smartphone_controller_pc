import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'image_processor.dart';

/// アプリケーションアイコンを抽出するユーティリティクラス
class IconExtractor {
  /// 実行可能ファイルからアイコンを抽出してPNGファイルとして保存
  /// 
  /// [executablePath] 実行可能ファイルのパス
  /// [outputDir] アイコンファイルを保存するディレクトリ
  /// 
  /// 戻り値: 保存されたアイコンファイルのパス（失敗時はnull）
  static Future<String?> extractIcon(String executablePath, String outputDir) async {
    // アイコン取得処理を無効化
    print('IconExtractor: アイコン取得処理は無効化されています: $executablePath');
    return null;
  }

  /// PowerShellを使用してアイコンを抽出
  static Future<bool> _extractIconWithPowerShell(String executablePath, String iconPath) async {
    try {
      print('PowerShellでアイコン抽出開始: $executablePath -> $iconPath');
      
      // パスをエスケープ
      final escapedExePath = executablePath.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final escapedIconPath = iconPath.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      
      // 一時的なPowerShellファイルを作成する方法に変更
      final tempDir = Directory.systemTemp;
      final tempScriptFile = File('${tempDir.path}/extract_icon_${DateTime.now().millisecondsSinceEpoch}.ps1');
      
      final scriptContent = '''Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Win32 API for multiple icon sizes and high-quality extraction
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

public class Win32Icon {
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern uint ExtractIconEx(string lpszFile, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, uint nIcons);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
    
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SHGetFileInfo(string pszPath, uint dwFileAttributes, ref SHFILEINFO psfi, uint cbSizeFileInfo, uint uFlags);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct SHFILEINFO {
        public IntPtr hIcon;
        public IntPtr iIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szDisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
        public string szTypeName;
        public uint dwAttributes;
    }
    
    public const uint SHGFI_ICON = 0x100;
    public const uint SHGFI_LARGEICON = 0x0;
    public const uint SHGFI_SMALLICON = 0x1;
    public const uint SHGFI_SHELLICONSIZE = 0x4;
}
"@

try {
    Write-Output "Starting high-quality multi-size icon extraction"
    
    if (-not (Test-Path "$escapedExePath")) {
        Write-Output "FAILED: File not found"
        exit 1
    }
    
    \$bestIcon = \$null
    \$bestSize = 0
    \$originalSize = 0
    \$extractedIcons = @()
    
    # 複数サイズ試行による最高品質抽出（256x256、128x128、64x64の順）
    Write-Output "Phase 1: Multiple size extraction attempt"
    
    # Method 1: Try ExtractIconEx for multiple sizes (最優先)
    try {
        Write-Output "Attempting ExtractIconEx method..."
        \$largeIcons = New-Object IntPtr[] 1
        \$smallIcons = New-Object IntPtr[] 1
        \$count = [Win32Icon]::ExtractIconEx("$escapedExePath", 0, \$largeIcons, \$smallIcons, 1)
        
        if (\$count -gt 0) {
            # Large icon (通常256x256または128x128)
            if (\$largeIcons[0] -ne [IntPtr]::Zero) {
                \$icon = [System.Drawing.Icon]::FromHandle(\$largeIcons[0])
                \$extractedIcons += @{Icon = \$icon; Size = \$icon.Width; Method = "ExtractIconEx-Large"}
                Write-Output "Large icon extracted: \$(\$icon.Width)x\$(\$icon.Height)"
            }
            
            # Small icon (通常64x64または32x32)
            if (\$smallIcons[0] -ne [IntPtr]::Zero) {
                \$icon = [System.Drawing.Icon]::FromHandle(\$smallIcons[0])
                \$extractedIcons += @{Icon = \$icon; Size = \$icon.Width; Method = "ExtractIconEx-Small"}
                Write-Output "Small icon extracted: \$(\$icon.Width)x\$(\$icon.Height)"
            }
        }
    } catch {
        Write-Output "ExtractIconEx failed: \$(\$_.Exception.Message)"
    }
    
    # Method 2: Try SHGetFileInfo for system shell icons
    try {
        Write-Output "Attempting SHGetFileInfo method..."
        \$shinfo = New-Object Win32Icon+SHFILEINFO
        
        # Large shell icon
        \$hImgSmall = [Win32Icon]::SHGetFileInfo("$escapedExePath", 0, [ref]\$shinfo, [System.Runtime.InteropServices.Marshal]::SizeOf(\$shinfo), [Win32Icon]::SHGFI_ICON -bor [Win32Icon]::SHGFI_LARGEICON)
        if (\$hImgSmall -ne [IntPtr]::Zero -and \$shinfo.hIcon -ne [IntPtr]::Zero) {
            \$icon = [System.Drawing.Icon]::FromHandle(\$shinfo.hIcon)
            \$extractedIcons += @{Icon = \$icon; Size = \$icon.Width; Method = "SHGetFileInfo-Large"}
            Write-Output "Shell large icon extracted: \$(\$icon.Width)x\$(\$icon.Height)"
        }
        
        # Small shell icon
        \$shinfo = New-Object Win32Icon+SHFILEINFO
        \$hImgSmall = [Win32Icon]::SHGetFileInfo("$escapedExePath", 0, [ref]\$shinfo, [System.Runtime.InteropServices.Marshal]::SizeOf(\$shinfo), [Win32Icon]::SHGFI_ICON -bor [Win32Icon]::SHGFI_SMALLICON)
        if (\$hImgSmall -ne [IntPtr]::Zero -and \$shinfo.hIcon -ne [IntPtr]::Zero) {
            \$icon = [System.Drawing.Icon]::FromHandle(\$shinfo.hIcon)
            \$extractedIcons += @{Icon = \$icon; Size = \$icon.Width; Method = "SHGetFileInfo-Small"}
            Write-Output "Shell small icon extracted: \$(\$icon.Width)x\$(\$icon.Height)"
        }
    } catch {
        Write-Output "SHGetFileInfo failed: \$(\$_.Exception.Message)"
    }
    
    # Method 3: Fallback to ExtractAssociatedIcon
    if (\$extractedIcons.Count -eq 0) {
        try {
            Write-Output "Attempting ExtractAssociatedIcon fallback..."
            \$icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$escapedExePath")
            if (\$icon -ne \$null) {
                \$extractedIcons += @{Icon = \$icon; Size = \$icon.Width; Method = "ExtractAssociatedIcon"}
                Write-Output "Associated icon extracted: \$(\$icon.Width)x\$(\$icon.Height)"
            }
        } catch {
            Write-Output "ExtractAssociatedIcon failed: \$(\$_.Exception.Message)"
        }
    }
    
    # 適応的サイズ選択（256x256 > 128x128 > 64x64の優先順位）
    Write-Output "Phase 2: Adaptive size selection"
    Write-Output "Total icons extracted: \$(\$extractedIcons.Count)"
    
    if (\$extractedIcons.Count -gt 0) {
        # サイズ別に分類して最適なアイコンを選択
        \$iconsBySize = \$extractedIcons | Group-Object Size | Sort-Object Name -Descending
        
        foreach (\$sizeGroup in \$iconsBySize) {
            \$size = [int]\$sizeGroup.Name
            Write-Output "Available size: \$size x \$size (\$(\$sizeGroup.Count) icons)"
        }
        
        # 優先順位: 256x256 → 128x128 → 64x64 → その他（最大サイズ）
        \$preferredSizes = @(256, 128, 64)
        \$selectedIcon = \$null
        
        foreach (\$preferredSize in \$preferredSizes) {
            \$matchingIcons = \$extractedIcons | Where-Object { \$_.Size -eq \$preferredSize }
            if (\$matchingIcons.Count -gt 0) {
                \$selectedIcon = \$matchingIcons[0]
                Write-Output "Selected preferred size: \$preferredSize x \$preferredSize (\$(\$selectedIcon.Method))"
                break
            }
        }
        
        # 優先サイズが見つからない場合は最大サイズを選択
        if (\$selectedIcon -eq \$null) {
            \$selectedIcon = (\$extractedIcons | Sort-Object Size -Descending)[0]
            Write-Output "Selected maximum available size: \$(\$selectedIcon.Size) x \$(\$selectedIcon.Size) (\$(\$selectedIcon.Method))"
        }
        
        \$bestIcon = \$selectedIcon.Icon
        \$bestSize = \$selectedIcon.Size
        \$originalSize = \$bestSize
        
        Write-Output "Final selection: \$(\$bestIcon.Width)x\$(\$bestIcon.Height) via \$(\$selectedIcon.Method)"
        
        # 高品質保存処理
        Write-Output "Phase 3: High-quality saving with HighQualityBicubic settings"
        
        \$bitmap = \$bestIcon.ToBitmap()
        Write-Output "Converted to bitmap for high-quality processing"
        
        # 適応的サイズ処理（元サイズが小さい場合は拡大しない、最大256x256に制限）
        \$targetSize = \$originalSize
        if (\$originalSize -gt 256) {
            \$targetSize = 256
            Write-Output "Limiting oversized icon to 256x256 (original: \$originalSize x \$originalSize)"
        } elseif (\$originalSize -lt 64) {
            # 64x64未満の場合は拡大しない（品質保持）
            Write-Output "Preserving small icon size to avoid quality loss (original: \$originalSize x \$originalSize)"
        }
        
        # 高品質補間設定でリサイズ（必要な場合のみ）
        if (\$targetSize -ne \$originalSize) {
            Write-Output "Applying HighQualityBicubic interpolation for resize: \$originalSize → \$targetSize"
            \$resizedBitmap = New-Object System.Drawing.Bitmap(\$targetSize, \$targetSize)
            \$graphics = [System.Drawing.Graphics]::FromImage(\$resizedBitmap)
            
            # HighQuality + HighQualityBicubic設定
            \$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            \$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            \$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            \$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            
            \$graphics.DrawImage(\$bitmap, 0, 0, \$targetSize, \$targetSize)
            \$graphics.Dispose()
            \$bitmap.Dispose()
            \$bitmap = \$resizedBitmap
            
            Write-Output "High-quality resize completed: \$targetSize x \$targetSize"
        } else {
            Write-Output "No resize needed, preserving original quality"
        }
        
        # PNG形式で最高品質保存
        Write-Output "Saving as high-quality PNG format"
        \$bitmap.Save("$escapedIconPath", [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "High-quality PNG saved successfully"
        
        # メタデータ出力
        Write-Output "METADATA:ORIGINAL_SIZE:\$originalSize"
        Write-Output "METADATA:ORIGINAL_WIDTH:\$(\$bestIcon.Width)"
        Write-Output "METADATA:ORIGINAL_HEIGHT:\$(\$bestIcon.Height)"
        Write-Output "METADATA:TARGET_SIZE:\$targetSize"
        Write-Output "METADATA:METHOD:\$(\$selectedIcon.Method)"
        
        \$bitmap.Dispose()
        \$bestIcon.Dispose()
        
        Write-Output "SUCCESS: High-quality multi-size extraction completed"
    } else {
        Write-Output "FAILED: Could not extract any icon with any method"
    }
} catch {
    Write-Output "FAILED: \$(\$_.Exception.Message)"
}''';

      // スクリプトファイルに書き込み
      await tempScriptFile.writeAsString(scriptContent);
      
      print('PowerShellスクリプトファイル作成: ${tempScriptFile.path}');
      
      // PowerShellファイルを実行
      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', tempScriptFile.path],
        runInShell: true,
      );

      // 一時ファイルを削除
      try {
        await tempScriptFile.delete();
      } catch (e) {
        print('一時ファイル削除エラー: $e');
      }

      print('PowerShell終了コード: ${result.exitCode}');
      print('PowerShell stdout: ${result.stdout}');
      if (result.stderr.isNotEmpty) {
        print('PowerShell stderr: ${result.stderr}');
      }

      final success = result.exitCode == 0 && result.stdout.toString().contains('SUCCESS');
      print('アイコン抽出結果: $success');
      
      return success;
    } catch (e) {
      print('PowerShell実行エラー: $e');
      return false;
    }
  }

  /// デフォルトブラウザのアイコンを取得
  static Future<String?> _getDefaultBrowserIcon(String outputDir) async {
    try {
      // 出力ディレクトリを作成
      final outputDirectory = Directory(outputDir);
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }

      final iconPath = path.join(outputDir, 'browser_icon.png');

      // 既にアイコンファイルが存在する場合はそれを返す
      if (await File(iconPath).exists()) {
        return iconPath;
      }

      // デフォルトブラウザのパスを取得
      final result = await Process.run(
        'reg',
        ['query', 'HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\http\\UserChoice', '/v', 'ProgId'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('ProgId')) {
            final parts = line.split('REG_SZ');
            if (parts.length > 1) {
              final progId = parts[1].trim();
              
              // ProgIdからブラウザの実行ファイルパスを取得
              final browserPath = await _getBrowserPathFromProgId(progId);
              if (browserPath != null) {
                final tempIconPath = '${iconPath}_temp.png';
                final success = await _extractIconWithPowerShell(browserPath, tempIconPath);
                if (success) {
                  // 品質最適化リサイズを適用（256x256に統一）
                  final optimized = await ImageProcessor.resizeIconWithQualityOptimization(
                    tempIconPath, 
                    iconPath,
                    forceSize: 256,
                  );
                  
                  // 一時ファイルを削除
                  try {
                    await File(tempIconPath).delete();
                  } catch (e) {
                    print('一時ファイル削除エラー: $e');
                  }
                  
                  return optimized ? iconPath : null;
                }
              }
            }
          }
        }
      }

      // フォールバック: 一般的なブラウザを試す
      final commonBrowsers = [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files\\Mozilla Firefox\\firefox.exe',
        'C:\\Program Files (x86)\\Mozilla Firefox\\firefox.exe',
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
      ];

      for (final browserPath in commonBrowsers) {
        if (await File(browserPath).exists()) {
          final tempIconPath = '${iconPath}_temp.png';
          final success = await _extractIconWithPowerShell(browserPath, tempIconPath);
          if (success) {
            // 品質最適化リサイズを適用（256x256に統一）
            final optimized = await ImageProcessor.resizeIconWithQualityOptimization(
              tempIconPath, 
              iconPath,
              forceSize: 256,
            );
            
            // 一時ファイルを削除
            try {
              await File(tempIconPath).delete();
            } catch (e) {
              print('一時ファイル削除エラー: $e');
            }
            
            if (optimized) {
              return iconPath;
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('デフォルトブラウザアイコン取得エラー: $e');
      return null;
    }
  }

  /// ProgIdからブラウザの実行ファイルパスを取得
  static Future<String?> _getBrowserPathFromProgId(String progId) async {
    try {
      final result = await Process.run(
        'reg',
        ['query', 'HKEY_CLASSES_ROOT\\$progId\\shell\\open\\command'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('REG_SZ')) {
            final parts = line.split('REG_SZ');
            if (parts.length > 1) {
              var command = parts[1].trim();
              
              // コマンドから実行ファイルパスを抽出
              if (command.startsWith('"')) {
                final endQuote = command.indexOf('"', 1);
                if (endQuote > 0) {
                  command = command.substring(1, endQuote);
                }
              } else {
                final spaceIndex = command.indexOf(' ');
                if (spaceIndex > 0) {
                  command = command.substring(0, spaceIndex);
                }
              }
              
              if (await File(command).exists()) {
                return command;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('ProgIdからブラウザパス取得エラー: $e');
      return null;
    }
  }

  /// アイコンキャッシュディレクトリを取得
  static String getIconCacheDir() {
    final appDataDir = Platform.environment['APPDATA'] ?? '';
    return path.join(appDataDir, 'QRSC_Pc', 'icons');
  }

  /// 指定されたアイコンファイルを削除
  static Future<void> deleteIcon(String? iconPath) async {
    if (iconPath != null && iconPath.isNotEmpty) {
      try {
        final file = File(iconPath);
        if (await file.exists()) {
          await file.delete();
          print('IconExtractor: アイコンファイルを削除しました: $iconPath');
        }
      } catch (e) {
        print('IconExtractor: アイコンファイル削除エラー: $e');
      }
    }
  }

  /// アイコンキャッシュをクリア
  static Future<void> clearIconCache() async {
    try {
      final cacheDir = Directory(getIconCacheDir());
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('IconExtractor: アイコンキャッシュをクリアしました');
      }
    } catch (e) {
      print('IconExtractor: アイコンキャッシュクリアエラー: $e');
    }
  }
}
