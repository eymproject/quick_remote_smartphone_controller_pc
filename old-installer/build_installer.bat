@echo off
chcp 65001 >nul
echo ========================================
echo QRSC PC インストーラビルドスクリプト
echo ========================================
echo.

REM 管理者権限チェック
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] 管理者権限で実行中
) else (
    echo [警告] 管理者権限が必要な場合があります
    echo        ファイアウォール設定を含む場合は管理者として実行してください
)
echo.

REM Inno Setup Compilerのパスを確認
set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)
if not exist "%ISCC_PATH%" (
    echo [エラー] Inno Setup Compilerが見つかりません
    echo.
    echo 以下のいずれかの場所にISCC.exeが必要です:
    echo - C:\Program Files (x86)\Inno Setup 6\ISCC.exe
    echo - C:\Program Files\Inno Setup 6\ISCC.exe
    echo.
    echo Inno Setupをダウンロードしてインストールしてください:
    echo https://jrsoftware.org/isinfo.php
    echo.
    pause
    exit /b 1
)

echo [OK] Inno Setup Compiler: %ISCC_PATH%
echo.

REM ビルド前チェック
echo 1. ビルド前チェック中...

REM Flutter アプリがビルド済みかチェック
if not exist "..\build\windows\x64\runner\Release\qrsc_pc.exe" (
    echo [エラー] qrsc_pc.exe が見つかりません
    echo.
    echo 先にFlutterアプリをビルドしてください:
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo [OK] qrsc_pc.exe が存在します
echo.

REM 必要なファイルの存在確認
echo 2. 必要ファイルの確認中...

if not exist "LICENSE.txt" (
    echo [警告] LICENSE.txt が見つかりません。作成します...
    echo MIT License > LICENSE.txt
    echo. >> LICENSE.txt
    echo Copyright (c) 2025 EYM Project >> LICENSE.txt
    echo. >> LICENSE.txt
    echo Permission is hereby granted, free of charge, to any person obtaining a copy >> LICENSE.txt
    echo of this software and associated documentation files (the "Software"), to deal >> LICENSE.txt
    echo in the Software without restriction, including without limitation the rights >> LICENSE.txt
    echo to use, copy, modify, merge, publish, distribute, sublicense, and/or sell >> LICENSE.txt
    echo copies of the Software, and to permit persons to whom the Software is >> LICENSE.txt
    echo furnished to do so, subject to the following conditions: >> LICENSE.txt
    echo. >> LICENSE.txt
    echo The above copyright notice and this permission notice shall be included in all >> LICENSE.txt
    echo copies or substantial portions of the Software. >> LICENSE.txt
    echo. >> LICENSE.txt
    echo THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR >> LICENSE.txt
    echo IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, >> LICENSE.txt
    echo FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE >> LICENSE.txt
    echo AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER >> LICENSE.txt
    echo LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, >> LICENSE.txt
    echo OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE >> LICENSE.txt
    echo SOFTWARE. >> LICENSE.txt
)

if not exist "README_INSTALLER.md" (
    echo [警告] README_INSTALLER.md が見つかりません。作成します...
    echo # QRSC PC インストーラ > README_INSTALLER.md
    echo. >> README_INSTALLER.md
    echo このインストーラは QRSC PC (Quick Remote Smartphone Controller PC) をインストールします。 >> README_INSTALLER.md
    echo. >> README_INSTALLER.md
    echo ## インストール内容 >> README_INSTALLER.md
    echo - QRSC PC アプリケーション >> README_INSTALLER.md
    echo - 必要なDLLファイル >> README_INSTALLER.md
    echo - 設定用バッチファイル >> README_INSTALLER.md
    echo - ドキュメントファイル >> README_INSTALLER.md
    echo. >> README_INSTALLER.md
    echo ## システム要件 >> README_INSTALLER.md
    echo - Windows 10/11 (64bit) >> README_INSTALLER.md
    echo - 管理者権限 (ファイアウォール設定のため) >> README_INSTALLER.md
    echo. >> README_INSTALLER.md
    echo ## 使用方法 >> README_INSTALLER.md
    echo 1. インストール完了後、QRSC PC を起動 >> README_INSTALLER.md
    echo 2. スマートフォンのEYMアプリから接続 >> README_INSTALLER.md
    echo 3. QRコードまたは手動でIPアドレスを入力して接続 >> README_INSTALLER.md
)

echo [OK] 必要ファイルの準備完了
echo.

REM 出力ディレクトリ作成
if not exist "Output" mkdir Output

REM インストーラビルド実行
echo 3. インストーラをビルド中...
echo    これには数分かかる場合があります...
echo.

"%ISCC_PATH%" qrsc_pc_setup.iss

if %errorLevel% == 0 (
    echo.
    echo ========================================
    echo [成功] インストーラビルド完了！
    echo ========================================
    echo.
    
    if exist "Output\QRSC_PC_Setup.exe" (
        for %%I in ("Output\QRSC_PC_Setup.exe") do (
            echo インストーラファイル: %%~fI
            echo ファイルサイズ: %%~zI bytes
        )
        echo.
        echo 次のステップ:
        echo 1. Output\QRSC_PC_Setup.exe をテスト実行
        echo 2. 他のPCでインストールテスト
        echo 3. 配布用にファイルを準備
        echo.
        
        REM インストーラを開くかの選択
        set /p choice="インストーラフォルダを開きますか？ (y/N): "
        if /i "%choice%"=="y" (
            explorer Output
        )
    ) else (
        echo [エラー] インストーラファイルが生成されませんでした
    )
) else (
    echo.
    echo ========================================
    echo [エラー] インストーラビルド失敗
    echo ========================================
    echo.
    echo トラブルシューティング:
    echo 1. qrsc_pc_setup.iss の構文エラーを確認
    echo 2. 参照ファイルのパスが正しいか確認
    echo 3. Inno Setup のバージョンを確認
    echo.
)

echo.
pause
