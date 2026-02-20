# Run Integration Tests with Visible Output
# This script runs tests and shows real-time output

Write-Host "Starting Integration Tests..." -ForegroundColor Cyan
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

# Fix APK location
Write-Host "Checking APK..." -ForegroundColor Yellow
if (-not (Test-Path "build\app\outputs\flutter-apk\app-debug.apk")) {
    Write-Host "Fixing APK location..." -ForegroundColor Yellow
    .\scripts\fix_apk_location.ps1
}

# Run tests with visible output
Write-Host "Running tests..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

flutter test integration_test/app_test.dart -d $emulatorId --reporter expanded --ignore-timeouts

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests completed!" -ForegroundColor Green

