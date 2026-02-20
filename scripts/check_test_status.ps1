# Check Integration Test Status Script
Write-Host "Checking Integration Test Status..." -ForegroundColor Cyan
Write-Host ""

# Check if Flutter/Dart processes are running
$dartProcesses = Get-Process -Name "dart" -ErrorAction SilentlyContinue
$flutterProcesses = Get-Process -Name "flutter" -ErrorAction SilentlyContinue

if ($dartProcesses -ne $null -or $flutterProcesses -ne $null) {
    Write-Host "Tests are RUNNING..." -ForegroundColor Yellow
    Write-Host ""
    
    if ($dartProcesses -ne $null) {
        Write-Host "Dart processes found:" -ForegroundColor Cyan
        $dartProcesses | ForEach-Object {
            $runtime = (Get-Date) - $_.StartTime
            Write-Host "  - PID: $($_.Id) | Running for: $([math]::Round($runtime.TotalMinutes, 1)) minutes"
        }
    }
    
    if ($flutterProcesses -ne $null) {
        Write-Host "Flutter processes found:" -ForegroundColor Cyan
        $flutterProcesses | ForEach-Object {
            $runtime = (Get-Date) - $_.StartTime
            Write-Host "  - PID: $($_.Id) | Running for: $([math]::Round($runtime.TotalMinutes, 1)) minutes"
        }
    }
    
    Write-Host ""
    Write-Host "To see live test output, check the terminal where you ran the tests" -ForegroundColor Gray
} else {
    Write-Host "No test processes running - Tests are COMPLETED or NOT STARTED" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run tests: flutter test integration_test/ -d emulator-5554" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Checking emulator status..." -ForegroundColor Cyan
$devicesOutput = flutter devices 2>&1 | Out-String
if ($devicesOutput -match "emulator") {
    Write-Host "Emulator is running" -ForegroundColor Green
} else {
    Write-Host "No emulator detected" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking APK status..." -ForegroundColor Cyan
if (Test-Path "build\app\outputs\flutter-apk\app-debug.apk") {
    $apk = Get-Item "build\app\outputs\flutter-apk\app-debug.apk"
    Write-Host "APK ready: $([math]::Round($apk.Length/1MB, 2)) MB" -ForegroundColor Green
} else {
    Write-Host "APK not found. Run: .\scripts\fix_apk_location.ps1" -ForegroundColor Yellow
}
