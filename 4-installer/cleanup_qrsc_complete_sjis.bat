@echo off
echo ========================================
echo QRSC PC �������S�폜�c�[��
echo ========================================
echo.
echo ���̃c�[����QRSC PC�������I�Ɋ��S�폜���܂��B
echo �S�Ẳ\�ȏꏊ����폜�����s���܂��B
echo.

REM �Ǘ��Ҍ����`�F�b�N
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] �Ǘ��Ҍ����Ŏ��s��
) else (
    echo [�x��] �Ǘ��Ҍ�������������܂�
)
echo.

echo �����폜���J�n���܂����H
set /p choice="���s����ꍇ�� 'y' ����͂��Ă�������: "
if /i not "%choice%"=="y" (
    echo �폜�𒆎~���܂����B
    pause
    exit /b 0
)

echo.
echo QRSC PC �̋������S�폜���J�n���܂�...
echo.

REM 1. �S�Ă�QRSC�֘A�v���Z�X�I��
echo 1. �S�Ă�QRSC�֘A�v���Z�X���I����...
taskkill /f /im qrsc_pc.exe >nul 2>&1
taskkill /f /im "QRSC PC.exe" >nul 2>&1
taskkill /f /im flutter_windows.exe >nul 2>&1
echo    [OK] �v���Z�X�I������

REM 2. �S�Ẳ\�ȃC���X�g�[���t�H���_���폜
echo.
echo 2. �S�ẴC���X�g�[���t�H���_���폜��...

REM Program Files (x86)
if exist "C:\Program Files (x86)\QRSC PC" (
    echo    Program Files (x86) ���̃t�H���_���폜��...
    rmdir /s /q "C:\Program Files (x86)\QRSC PC" >nul 2>&1
    echo    [OK] C:\Program Files (x86)\QRSC PC ���폜
)

REM Program Files
if exist "C:\Program Files\QRSC PC" (
    echo    Program Files���̃t�H���_���폜��...
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    echo    [OK] C:\Program Files\QRSC PC ���폜
)

REM LocalAppData
if exist "%LOCALAPPDATA%\QRSC PC" (
    echo    LocalAppData���̃t�H���_���폜��...
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] %LOCALAPPDATA%\QRSC PC ���폜
)

REM AppData\Roaming
if exist "%APPDATA%\QRSC PC" (
    echo    AppData\Roaming���̃t�H���_���폜��...
    rmdir /s /q "%APPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] %APPDATA%\QRSC PC ���폜
)

REM AppData\Local\Programs
if exist "%LOCALAPPDATA%\Programs\QRSC PC" (
    echo    LocalAppData\Programs���̃t�H���_���폜��...
    rmdir /s /q "%LOCALAPPDATA%\Programs\QRSC PC" >nul 2>&1
    echo    [OK] %LOCALAPPDATA%\Programs\QRSC PC ���폜
)

REM 3. �S�Ẵ��W�X�g���G���g�����폜
echo.
echo 3. �S�Ẵ��W�X�g���G���g�����폜��...

REM �����N���ݒ�
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1

REM �A���C���X�g�[�����i�����̃p�^�[�������s�j
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1

REM �A�v���P�[�V�����ݒ�
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\QRSC PC" /f >nul 2>&1

REM Windows Installer�֘A
for /f "tokens=1" %%i in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /k /f "QRSC" 2^>nul ^| findstr /i "HKEY"') do (
    echo    ���W�X�g���L�[ %%i ���폜��...
    reg delete "%%i" /f >nul 2>&1
)

echo    [OK] ���W�X�g���G���g���폜����

REM 4. �S�ẴV���[�g�J�b�g���폜
echo.
echo 4. �S�ẴV���[�g�J�b�g���폜��...

REM �f�X�N�g�b�v
del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
del "%PUBLIC%\Desktop\QRSC PC.lnk" >nul 2>&1

REM �X�^�[�g���j���[
rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC.lnk" >nul 2>&1
del "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC.lnk" >nul 2>&1

echo    [OK] �V���[�g�J�b�g�폜����

REM 5. �ꎞ�t�@�C���ƃL���b�V�����폜
echo.
echo 5. �ꎞ�t�@�C���ƃL���b�V�����폜��...
del "%TEMP%\QRSC*.*" /q >nul 2>&1
del "%TEMP%\Setup Log*.txt" /q >nul 2>&1
del "%TEMP%\is-*.tmp" /q >nul 2>&1
rmdir /s /q "%TEMP%\QRSC PC" >nul 2>&1
echo    [OK] �ꎞ�t�@�C���폜����

REM 6. Windows Installer�L���b�V�����N���A
echo.
echo 6. Windows Installer�L���b�V�����N���A��...
for /d %%i in ("%WINDIR%\Installer\{*}") do (
    if exist "%%i\QRSC*" (
        rmdir /s /q "%%i" >nul 2>&1
    )
)
echo    [OK] Installer�L���b�V���N���A����

echo.
echo ========================================
echo QRSC PC �̋������S�폜���������܂����I
echo ========================================
echo.
echo �폜���������s��������:
echo ? �S�Ẵv���Z�X�I��
echo ? �S�Ẳ\�ȃC���X�g�[���t�H���_
echo ? �S�Ẵ��W�X�g���G���g��
echo ? �S�ẴV���[�g�J�b�g
echo ? �ꎞ�t�@�C���ƃL���b�V��
echo ? Windows Installer�L���b�V��
echo.
echo �V�X�e�����ċN�����邱�Ƃ𐄏����܂��B
echo �ċN����A�V�����C���X�g�[���ł̍ăC���X�g�[�����\�ł��B
echo.
pause
