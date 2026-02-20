@echo off
REM Flutter Integration Test Runner Script for Windows
REM This script runs integration tests on an emulator/device

echo 🚀 Starting Flutter Integration Tests...

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    exit /b 1
)

REM Get available devices
echo 📱 Checking available devices...
flutter devices

REM Install dependencies
echo 📦 Installing dependencies...
flutter pub get

REM Fix APK location if needed
echo 🔧 Checking APK location...
powershell -ExecutionPolicy Bypass -File "%~dp0fix_apk_location.ps1"

REM Run tests
echo 🧪 Running integration tests...
flutter test integration_test\ --reporter expanded

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo ✅ All tests passed!
    exit /b 0
) else (
    echo ❌ Tests failed!
    exit /b 1
)

