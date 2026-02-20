# Fix APK Location Script
# This script copies the APK from Gradle output to Flutter's expected location
# Run this if Flutter test runner can't find the APK

$gradleApkPath = "android\app\build\outputs\apk\debug\app-debug.apk"
$flutterApkPath = "build\app\outputs\flutter-apk\app-debug.apk"

if (Test-Path $gradleApkPath) {
    Write-Host "✅ APK found at Gradle location: $gradleApkPath"
    
    # Create Flutter output directory if it doesn't exist
    $flutterApkDir = Split-Path $flutterApkPath -Parent
    if (-not (Test-Path $flutterApkDir)) {
        New-Item -ItemType Directory -Path $flutterApkDir -Force | Out-Null
        Write-Host "📁 Created Flutter APK directory: $flutterApkDir"
    }
    
    # Copy APK to Flutter location
    Copy-Item $gradleApkPath -Destination $flutterApkPath -Force
    Write-Host "✅ APK copied to Flutter location: $flutterApkPath"
    
    $apk = Get-Item $flutterApkPath
    Write-Host "📦 APK Size: $([math]::Round($apk.Length/1MB, 2)) MB"
    Write-Host "✅ Ready for Flutter test runner!"
} else {
    Write-Host "❌ APK not found at: $gradleApkPath"
    Write-Host "💡 Run 'flutter build apk --debug' or 'cd android; .\gradlew.bat :app:assembleDebug' first"
    exit 1
}

