# How to View Integration Test Logs

## Quick Answer

**Test logs appear in the terminal/console where you run the test command.**

## Methods to View Logs

### Method 1: Run Test in Terminal (Recommended)

Run the test command in your terminal and watch the output in real-time:

```powershell
# Windows PowerShell
flutter test integration_test/test_complete_journey.dart -d emulator-5554 --reporter expanded
```

**What you'll see:**
- All `print()` statements from the test code
- Test execution progress
- Pass/fail status
- Error messages if any

### Method 2: Save Logs to File

Use the provided script to save logs to a file:

```powershell
.\scripts\run_test_with_logs.ps1
```

This will:
- Run the test
- Display output in terminal
- Save all output to `test_output_YYYYMMDD_HHMMSS.log`

Then view the log file:
```powershell
# View in terminal
Get-Content test_output_*.log

# Or open in Notepad
notepad test_output_*.log
```

### Method 3: Use VS Code Terminal

1. Open VS Code
2. Open the integrated terminal (`` Ctrl+` `` or `Terminal > New Terminal`)
3. Run the test command
4. All output will appear in the terminal panel

### Method 4: Redirect Output Manually

```powershell
# Save to file
flutter test integration_test/test_complete_journey.dart -d emulator-5554 --reporter expanded > test_log.txt 2>&1

# View the file
Get-Content test_log.txt
```

## What Logs Contain

The test logs include:

1. **Test Progress**: Step-by-step execution
   ```
   🚀 Starting Complete User Journey Test...
   📱 Step 1: Starting app...
   🔐 Step 2: Logging in...
   ```

2. **Debug Information**: From `print()` statements in test code
   ```
   📝 Filling login form with email: test@gmail.com
   Found 2 TextFormField(s)
   ✅ Email entered: test@gmail.com
   ```

3. **Test Results**: Pass/fail status
   ```
   00:01 +1: Complete Journey test passed
   All tests passed!
   ```

4. **Errors**: If tests fail
   ```
   Error: Could not find email field
   Stack trace: ...
   ```

## Understanding the Output

### Reporter Options

- `--reporter expanded`: Shows detailed output (recommended)
- `--reporter compact`: Shows minimal output
- `--reporter json`: Shows JSON format (for CI/CD)

### Log Levels

The test uses `print()` statements with emojis for easy identification:
- 🚀 = Test start
- 📱 = App/UI actions
- 🔐 = Authentication
- ✅ = Success
- ⚠️ = Warning
- ❌ = Error
- 📝 = Form filling
- 🔘 = Button clicks

## Troubleshooting

### If you don't see any output:

1. **Check terminal**: Make sure you're running in a terminal that supports output
2. **Check test is running**: Look for "Running Gradle task" messages
3. **Check emulator**: Ensure emulator is running and connected
4. **Add more logging**: Add `print()` statements in test code

### If output is cut off:

1. **Use log file**: Save to file using Method 2
2. **Scroll terminal**: Use terminal scroll to see all output
3. **Increase buffer**: Some terminals have scrollback limits

## Example Output

```
00:00 +0: loading C:/Users/.../integration_test/test_complete_journey.dart
Running Gradle task 'assembleDebug'...                             48.0s
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...           4.3s

🚀 Starting Complete User Journey Test...
📱 Step 1: Starting app...
⏳ Waiting for app to initialize...
🔔 Checking for notification permission dialog...
✅ Notification permission granted
🔐 Step 2: Logging in...
   📝 Filling login form with email: test@gmail.com
   Found 2 TextFormField(s)
   Filling email in first field...
   ✅ Email entered: test@gmail.com
   Filling password in second field...
   ✅ Password entered
   🔘 Looking for login button...
   Found Login button, tapping...
   ✅ Login button tapped
✅ Step 2: Login completed
...
```

## Tips

1. **Watch in real-time**: Keep terminal visible while test runs
2. **Use expanded reporter**: Always use `--reporter expanded` for detailed logs
3. **Save important runs**: Use log file for runs you want to review later
4. **Search logs**: Use `Select-String` to search logs:
   ```powershell
   Get-Content test_log.txt | Select-String "Error"
   ```

