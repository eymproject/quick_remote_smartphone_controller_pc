@echo off
echo ========================================
echo QRSC PC �������S�폜�c�[��
echo ========================================
echo.
echo ���̃c�[���̓A���C���X�g�[����Ɏc����
echo ���W�X�g���G���g���������폜���܂��B
echo.

REM �Ǘ��Ҍ����`�F�b�N
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [�x��] �Ǘ��Ҍ�������������܂�
    echo        ���W�X�g���폜�ɂ͊Ǘ��Ҍ������K�v�ł�
    echo.
    echo �E�N���b�N �� �Ǘ��҂Ƃ��Ď��s ���Ă�������
    echo.
    pause
    exit /b 1
)

echo [OK] �Ǘ��Ҍ����Ŏ��s��
echo.

echo ���W�X�g������c���G���g�����폜��...
echo.

REM �S�Ẳ\�ȃA���C���X�g�[���G���g�����폜
echo 1. ���C���A���C���X�g�[���G���g�����폜��...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8B5F4A2C-9D3E-4F1A-8C7B-2E9F6A1D5C8E}_is1" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] ���C���G���g�����폜���܂���
) else (
    echo    [INFO] ���C���G���g���͑��݂��܂���ł���
)

echo 2. ��փA���C���X�g�[���G���g�����폜��...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] ��փG���g�����폜���܂���
) else (
    echo    [INFO] ��փG���g���͑��݂��܂���ł���
)

echo 3. ���[�U�[�ŗL�G���g�����폜��...
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\QRSC PC" /f >nul 2>&1
if %errorLevel% == 0 (
    echo    [OK] ���[�U�[�G���g�����폜���܂���
) else (
    echo    [INFO] ���[�U�[�G���g���͑��݂��܂���ł���
)

echo 4. �����N���ݒ���폜��...
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "QRSC PC" /f >nul 2>&1
echo    [OK] �����N���ݒ���폜���܂���

echo 5. �A�v���P�[�V�����ݒ���폜��...
reg delete "HKEY_CURRENT_USER\Software\QRSC PC" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\QRSC PC" /f >nul 2>&1
echo    [OK] �A�v���P�[�V�����ݒ���폜���܂���

echo 6. �t�@�C�A�E�H�[���ݒ���폜��...
netsh advfirewall firewall delete rule name="QRSC_PC" >nul 2>&1
if %errorLevel__ == 0 (
    echo    [OK] �t�@�C�A�E�H�[���ݒ���폜���܂���
) else (
    echo    [INFO] �t�@�C�A�E�H�[���ݒ�͑��݂��܂���ł���
)

echo 7. �c���t�@�C�����폜��...
if exist "C:\Program Files\QRSC PC" (
    rmdir /s /q "C:\Program Files\QRSC PC" >nul 2>&1
    echo    [OK] Program Files���̃t�H���_���폜���܂���
)

if exist "C:\Program Files (x86)\QRSC PC" (
    rmdir /s /q "C:\Program Files (x86)\QRSC PC" >nul 2>&1
    echo    [OK] Program Files (x86)���̃t�H���_���폜���܂���
)

if exist "%LOCALAPPDATA%\QRSC PC" (
    rmdir /s /q "%LOCALAPPDATA%\QRSC PC" >nul 2>&1
    echo    [OK] LocalAppData���̃t�H���_���폜���܂���
)

echo 8. �V���[�g�J�b�g���폜��...
del "%USERPROFILE%\Desktop\QRSC PC.lnk" >nul 2>&1
del "%PUBLIC%\Desktop\QRSC PC.lnk" >nul 2>&1
rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\QRSC PC" >nul 2>&1
echo    [OK] �V���[�g�J�b�g���폜���܂���

echo.
echo ========================================
echo �������S�폜���������܂����I
echo ========================================
echo.
echo �폜���ꂽ����:
echo ? �S�Ẵ��W�X�g���G���g��
echo ? �A���C���X�g�[�����
echo ? �����N���ݒ�
echo ? �t�@�C�A�E�H�[���ݒ�
echo ? �c���t�@�C���E�t�H���_
echo ? �V���[�g�J�b�g
echo.
echo PC���ċN�����āA�u�C���X�g�[������Ă���A�v���v����
echo QRSC PC�����S�ɏ����Ă��邱�Ƃ��m�F���Ă��������B
echo.
pause
