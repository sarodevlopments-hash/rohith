# Run Integration Test with Full Logging
# This script runs the test and saves output to a log file

param(
    [string]$TestFile = "integration_test/test_complete_journey.dart",
    [string]$DeviceId = "emulator-5554"
)

$logFile = "test_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logPath = Join-Path $PSScriptRoot ".." $logFile

Write-Host "Starting Integration Test..." -ForegroundColor Cyan
Write-Host "Test File: $TestFile" -ForegroundColor Yellow
Write-Host "Device: $DeviceId" -ForegroundColor Yellow
Write-Host "Log File: $logFile" -ForegroundColor Yellow
Write-Host ""

# Check emulator
Write-Host "Checking emulator..." -ForegroundColor Yellow
$devices = flutter devices 2>&1 | Out-String
if ($devices -notmatch "emulator") {
    Write-Host "ERROR: No emulator detected!" -ForegroundColor Red
    Write-Host "Start emulator first: flutter emulators --launch [emulator_id]" -ForegroundColor Yellow
    exit 1
}

$emulatorLine = flutter devices 2>&1 | Select-String "emulator-"
if ($emulatorLine) {
    $emulatorId = ($emulatorLine.ToString() -split '\s+') | Where-Object { $_ -like "emulator-*" } | Select-Object -First 1
    Write-Host "Using emulator: $emulatorId" -ForegroundColor Green
} else {
    Write-Host "ERROR: Could not find emulator ID" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Fix APK location if needed
Write-Host "Checking APK..." -ForegroundColor Yellow
if (-not (Test-Path "build\app\outputs\flutter-apk\app-debug.apk")) {
    Write-Host "Fixing APK location..." -ForegroundColor Yellow
    .\scripts\fix_apk_location.ps1
}

# Run tests with full output and save to log file
Write-Host "Running tests (output will be saved to $logFile)..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run test and capture all output
flutter test $TestFile -d $emulatorId --reporter expanded --ignore-timeouts 2>&1 | Tee-Object -FilePath $logPath

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test completed!" -ForegroundColor Green
Write-Host "Full log saved to: $logFile" -ForegroundColor Green
Write-Host ""
Write-Host "To view the log file:" -ForegroundColor Yellow
Write-Host "  Get-Content $logFile" -ForegroundColor White
Write-Host "  or" -ForegroundColor Yellow
Write-Host "  notepad $logFile" -ForegroundColor White

