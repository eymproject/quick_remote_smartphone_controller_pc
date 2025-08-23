# EYM Agent リリースビルドスクリプト
# PowerShell実行ポリシーの設定が必要な場合があります：
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EYM Agent リリースビルドを開始します..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 環境確認
Write-Host "`n1. 環境確認中..." -ForegroundColor Yellow

# Flutter環境確認
$flutterVersion = flutter --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: Flutterが見つかりません。Flutterをインストールしてください。" -ForegroundColor Red
    exit 1
}

Write-Host "Flutter環境: OK" -ForegroundColor Green

# Visual Studio確認
$clPath = where.exe cl 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "警告: Visual Studio C++コンパイラが見つかりません。" -ForegroundColor Yellow
    Write-Host "Visual Studio Community 2022の「C++によるデスクトップ開発」ワークロードをインストールしてください。" -ForegroundColor Yellow
    
    $continue = Read-Host "続行しますか？ (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "ビルドを中止しました。" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Visual Studio C++: OK" -ForegroundColor Green
}

# プロジェクトクリーンアップ
Write-Host "`n2. プロジェクトをクリーンアップ中..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: flutter clean に失敗しました。" -ForegroundColor Red
    exit 1
}

# 依存関係取得
Write-Host "`n3. 依存関係を取得中..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: flutter pub get に失敗しました。" -ForegroundColor Red
    exit 1
}

# リリースビルド実行
Write-Host "`n4. リリースビルドを実行中..." -ForegroundColor Yellow
Write-Host "これには数分かかる場合があります..." -ForegroundColor Gray

$buildStartTime = Get-Date
flutter build windows --release --verbose
$buildEndTime = Get-Date
$buildDuration = $buildEndTime - $buildStartTime

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "ビルド成功！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    $exePath = "build\windows\x64\runner\Release\qrsc_pc.exe"
    if (Test-Path $exePath) {
        $fileInfo = Get-Item $exePath
        Write-Host "実行ファイル: $exePath" -ForegroundColor Green
        Write-Host "ファイルサイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
        Write-Host "作成日時: $($fileInfo.CreationTime)" -ForegroundColor Green
    }
    
    Write-Host "ビルド時間: $($buildDuration.Minutes)分$($buildDuration.Seconds)秒" -ForegroundColor Green
    
    # 配布用フォルダ作成の提案
    Write-Host "`n配布用パッケージを作成しますか？ (y/N): " -ForegroundColor Yellow -NoNewline
    $createPackage = Read-Host
    
    if ($createPackage -eq "y" -or $createPackage -eq "Y") {
        Write-Host "`n5. 配布用パッケージを作成中..." -ForegroundColor Yellow
        
        $packageDir = "QRSC_Pc_Windows_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
        
        # 実行ファイルとDLLをコピー
        Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination $packageDir -Recurse -Force
        
        # ドキュメントをコピー
        if (Test-Path "README.md") { Copy-Item "README.md" $packageDir }
        if (Test-Path "アプリ起動方法.md") { Copy-Item "アプリ起動方法.md" $packageDir }
        if (Test-Path "ネイティブ版ビルド手順.md") { Copy-Item "ネイティブ版ビルド手順.md" $packageDir }
        if (Test-Path "test_client.py") { Copy-Item "test_client.py" $packageDir }
        
        Write-Host "配布用パッケージを作成しました: $packageDir" -ForegroundColor Green
        
        # 実行テストの提案
        Write-Host "`nビルドしたアプリケーションをテスト実行しますか？ (y/N): " -ForegroundColor Yellow -NoNewline
        $testRun = Read-Host
        
        if ($testRun -eq "y" -or $testRun -eq "Y") {
            Write-Host "`nアプリケーションを起動しています..." -ForegroundColor Yellow
            Start-Process -FilePath $exePath
            Write-Host "アプリケーションが起動しました。動作を確認してください。" -ForegroundColor Green
        }
    }
    
    Write-Host "`n次のステップ:" -ForegroundColor Cyan
    Write-Host "1. $exePath を実行してアプリケーションをテスト" -ForegroundColor White
    Write-Host "2. http://localhost:8765 でAPIサーバーが起動することを確認" -ForegroundColor White
    Write-Host "3. 設定画面でショートカットを設定" -ForegroundColor White
    Write-Host "4. スマホアプリから接続テスト" -ForegroundColor White
    
} else {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "ビルド失敗" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    
    Write-Host "`nトラブルシューティング:" -ForegroundColor Yellow
    Write-Host "1. Visual Studio Community 2022がインストールされているか確認" -ForegroundColor White
    Write-Host "2. 「C++によるデスクトップ開発」ワークロードが選択されているか確認" -ForegroundColor White
    Write-Host "3. 新しいPowerShellを開いて再実行" -ForegroundColor White
    Write-Host "4. 詳細は 'ネイティブ版ビルド手順.md' を参照" -ForegroundColor White
    
    exit 1
}

Write-Host "`nビルドスクリプトが完了しました。" -ForegroundColor Cyan
