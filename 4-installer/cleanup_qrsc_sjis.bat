@echo off
echo ========================================
echo QRSC PC ���S�폜�c�[��
echo ========================================
echo.
echo ���̃c�[���͕s���S�ɃC���X�g�[�����ꂽQRSC PC��
echo �蓮�Ŋ��S�폜���܂��B
echo.

REM �Ǘ��Ҍ����`�F�b�N
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] �Ǘ��Ҍ����Ŏ��s��
) else (
    echo [�x��] �Ǘ��Ҍ�������������܂�
    echo        �ꕔ�̍폜�����Ō������K�v�ȏꍇ������܂�
)
echo.

echo �폜���J�n���܂����H
set /p choice="���s����ꍇ�� 'y' ����͂��Ă�������: "
if /i not "%choice%"=="y" (
    echo �폜�𒆎~���܂����B
    pause
    exit /b 0
)

echo.
echo QRSC PC �̊��S�폜���J�n���܂�...
echo.

REM 1. �v���Z�X�I��
echo 1. QRSC PC �v���Z�X���I����...
taskkill /f /im qrsc_pc.exe >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] qrsc_pc.exe ���I�����܂���
) else (
    echo    [INFO] qrsc_pc.exe �͎��s����Ă��܂���
)

REM 2. �����N���ݒ�폜
echo.
echo 2. �����N���ݒ���폜��...
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] �����N���ݒ���폜���܂���
) else (
    echo    [INFO] �����N���ݒ�͑��݂��܂���ł���
)

REM 3. �C���X�g�[���t�H���_�폜
echo.
echo 3. �C���X�g�[���t�H���_���폜��...

REM Program Files���̃t�H���_
if exist "C:\Program Files\QRSC PC" (
    echo    Program Files���̃t�H���_���폜��...
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] C:\Program Files\QRSC PC ���폜���܂���
    ) else (
        echo    [�x��] C:\Program Files\QRSC PC �̍폜�Ɏ��s���܂���
    )
)

REM LocalAppData���̃t�H���_
if exist "%LOCALAPPDATA%\QRSC PC" (
    echo    LocalAppData���̃t�H���_���폜��...
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] %LOCALAPPDATA%\QRSC PC ���폜���܂���
    ) else (
        echo    [�x��] %LOCALAPPDATA%\QRSC PC �̍폜�Ɏ��s���܂���
    )
)

REM AppData���̐ݒ�t�H���_
if exist "%APPDATA%\QRSC PC" (
    echo    AppData���̃t�H���_���폜��...
    rmdir /s /q "%APPDATA%\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] %APPDATA%\QRSC PC ���폜���܂���
    ) else (
        echo    [INFO] %APPDATA%\QRSC PC �͑��݂��܂���ł���
    )
)

REM 4. �X�^�[�g���j���[�V���[�g�J�b�g�폜
echo.
echo 4. �X�^�[�g���j���[�V���[�g�J�b�g���폜��...
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" (
    rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] �X�^�[�g���j���[�t�H���_���폜���܂���
    ) else (
        echo    [�x��] �X�^�[�g���j���[�t�H���_�̍폜�Ɏ��s���܂���
    )
) else (
    echo    [INFO] �X�^�[�g���j���[�t�H���_�͑��݂��܂���ł���
)

REM 5. �f�X�N�g�b�v�V���[�g�J�b�g�폜
echo.
echo 5. �f�X�N�g�b�v�V���[�g�J�b�g���폜��...
if exist "%USERPROFILE%\Desktop\QRSC PC.lnk" (
    del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
    if %errorLevel% == 0 (
        echo    [OK] �f�X�N�g�b�v�V���[�g�J�b�g���폜���܂���
    ) else (
        echo    [�x��] �f�X�N�g�b�v�V���[�g�J�b�g�̍폜�Ɏ��s���܂���
    )
) else (
    echo    [INFO] �f�X�N�g�b�v�V���[�g�J�b�g�͑��݂��܂���ł���
)

REM 6. ���W�X�g���G���g���폜
echo.
echo 6. ���W�X�g���G���g�����폜��...
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
echo    [OK] ���W�X�g���G���g�����폜���܂���

REM 7. �ꎞ�t�@�C���폜
echo.
echo 7. �ꎞ�t�@�C�����폜��...
del "%TEMP%\QRSC*.*" /q >nul 2>&1
del "%TEMP%\Setup Log*.txt" /q >nul 2>&1
echo    [OK] �ꎞ�t�@�C�����폜���܂���

echo.
echo ========================================
echo QRSC PC �̊��S�폜���������܂����I
echo ========================================
echo.
echo �폜���ꂽ����:
echo ? �A�v���P�[�V�����t�@�C��
echo ? �ݒ�t�@�C��
echo ? �X�^�[�g���j���[�V���[�g�J�b�g
echo ? �f�X�N�g�b�v�V���[�g�J�b�g
echo ? �����N���ݒ�
echo ? ���W�X�g���G���g��
echo ? �ꎞ�t�@�C��
echo.
echo �V�����C���X�g�[���ł̍ăC���X�g�[�����\�ł��B
echo.
pause
