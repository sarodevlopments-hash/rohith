# How to Check Integration Test Status

## Quick Status Check

### Windows (PowerShell):
```powershell
.\scripts\check_test_status.ps1
```

### Linux/Mac (Bash):
```bash
./scripts/check_test_status.sh
```

## Manual Methods

### 1. Check Running Processes

**Windows:**
```powershell
# Check if Dart/Flutter processes are running
Get-Process -Name "dart","flutter" -ErrorAction SilentlyContinue

# Check specific process details
Get-Process -Name "dart" | Select-Object Id, CPU, StartTime
```

**Linux/Mac:**
```bash
# Check if Dart/Flutter processes are running
ps aux | grep -E "dart|flutter" | grep -v grep
```

### 2. Check Test Output

If you ran tests in a terminal, check that terminal for:
- ✅ `All tests passed!` - Tests completed successfully
- ❌ `Some tests failed.` - Tests completed with failures
- ⏳ `loading...` or `Running...` - Tests still running

### 3. Check Test Results Files

```bash
# Check for test reports
ls -lh test_reports/*.json

# View test results (if JSON reporter was used)
cat test_reports/test_results.json
```

### 4. Check Emulator Status

```bash
flutter devices
```

Should show your emulator (e.g., `emulator-5554`)

### 5. Check APK Status

**Windows:**
```powershell
Test-Path "build\app\outputs\flutter-apk\app-debug.apk"
```

**Linux/Mac:**
```bash
test -f "build/app/outputs/flutter-apk/app-debug.apk" && echo "APK exists" || echo "APK not found"
```

## Understanding Test Status

### Tests Running
- ✅ Dart/Flutter processes visible in task manager
- ✅ CPU usage on those processes
- ✅ Terminal shows "loading..." or "Running..."

### Tests Completed
- ✅ No Dart/Flutter test processes running
- ✅ Terminal shows final results (passed/failed)
- ✅ Test report files created (if configured)

### Tests Not Started
- ✅ No Dart/Flutter processes
- ✅ No test output in terminal
- ✅ No test report files

## Real-Time Monitoring

### Option 1: Watch Process List
```powershell
# Windows - Refresh every 2 seconds
while ($true) { Clear-Host; Get-Process -Name "dart","flutter" -ErrorAction SilentlyContinue | Format-Table; Start-Sleep -Seconds 2 }
```

```bash
# Linux/Mac - Refresh every 2 seconds
watch -n 2 'ps aux | grep -E "dart|flutter" | grep -v grep'
```

### Option 2: Monitor Test Output File
```bash
# Run tests with file output
flutter test integration_test/ -d emulator-5554 --reporter json > test_output.json

# In another terminal, watch the file
tail -f test_output.json
```

### Option 3: Use Flutter's Verbose Output
```bash
flutter test integration_test/ -d emulator-5554 --reporter expanded --verbose
```

This shows detailed progress and you'll see when tests complete.

## Expected Test Duration

- **Registration Test**: ~30-60 seconds
- **Login Test**: ~20-40 seconds
- **Product Listing Test**: ~30-60 seconds
- **Cart & Order Test**: ~60-120 seconds
- **Complete Journey Test**: ~3-5 minutes

**Total Expected Time**: 5-10 minutes for all tests

## Troubleshooting

### Tests Seem Stuck

1. **Check emulator**: Is it responsive?
   ```bash
   flutter devices
   ```

2. **Check APK**: Is it built?
   ```bash
   .\scripts\fix_apk_location.ps1  # Windows
   ./scripts/fix_apk_location.sh  # Linux/Mac
   ```

3. **Kill stuck processes**:
   ```powershell
   # Windows
   Stop-Process -Name "dart","flutter" -Force
   ```

   ```bash
   # Linux/Mac
   pkill -f "dart.*test"
   pkill -f "flutter.*test"
   ```

4. **Restart tests**:
   ```bash
   flutter clean
   flutter pub get
   flutter test integration_test/ -d emulator-5554
   ```

### Tests Completed But No Results

Check for:
- Test report files in `test_reports/`
- Console output in the terminal
- Exit code: `echo $?` (0 = success, non-zero = failure)

## Quick Reference

| Status | Indicator |
|--------|-----------|
| **Running** | Dart/Flutter processes active, CPU usage |
| **Completed** | No test processes, final output shown |
| **Failed** | Error messages, non-zero exit code |
| **Not Started** | No processes, no output |

---

**Tip**: Use the status check script for the quickest way to see test status:
```bash
.\scripts\check_test_status.ps1  # Windows
./scripts/check_test_status.sh   # Linux/Mac
```

