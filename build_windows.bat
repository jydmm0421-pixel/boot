@echo off

echo ===========================================
echo   CyberEx - Build Script
echo ===========================================
echo.

set "FLUTTER_BIN=C:\flutter\bin\flutter.bat"

if not exist "%FLUTTER_BIN%" (
    echo [ERROR] Flutter not found at %FLUTTER_BIN%
    echo Please check the path and modify this script.
    pause
    exit /b 1
)

echo [1/2] Running flutter pub get...
call "%FLUTTER_BIN%" pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] pub get failed
    pause
    exit /b 1
)

echo.
echo [2/2] Building Windows release...
call "%FLUTTER_BIN%" build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [NOTE] Windows build failed.
    echo Please enable Developer Mode:
    echo   start ms-settings:developers
    echo.
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   BUILD SUCCESS!
echo   Output: build\windows\x64\runner\Release\
echo ===========================================
pause
