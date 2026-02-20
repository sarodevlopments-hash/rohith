# E2E Testing Setup Guide

This document provides a comprehensive guide for setting up and running end-to-end (E2E) integration tests for the Food App.

## 📋 Overview

The E2E testing framework uses Flutter's `integration_test` package to automate user flows including:
- User registration
- Login
- Product listing and filtering
- Adding products
- Cart management
- Order placement

## 🚀 Quick Start

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Start Emulator/Simulator

**⚠️ IMPORTANT**: Integration tests require Android emulator or iOS simulator. Web/Desktop devices are NOT supported.

**Android (Windows/Mac/Linux):**
```bash
# List available emulators
flutter emulators

# If no emulators exist, create one:
# 1. Open Android Studio
# 2. Go to Tools > Device Manager
# 3. Click "Create Device"
# 4. Select a device (e.g., Pixel 5)
# 5. Select a system image (e.g., API 33)
# 6. Finish setup

# Launch an emulator
flutter emulators --launch <emulator_id>

# Or launch from Android Studio: Tools > Device Manager > Click Play button
```

**iOS (Mac only):**
```bash
# List available simulators
xcrun simctl list devices

# Launch a simulator
open -a Simulator

# Or use Xcode: Xcode > Open Developer Tool > Simulator
```

**Windows Users - Setup Android Emulator:**
1. Install Android Studio: https://developer.android.com/studio
2. Open Android Studio
3. Go to **Tools > Device Manager**
4. Click **Create Device**
5. Select **Pixel 5** (or any device)
6. Download a system image (e.g., **API 33 - Android 13**)
7. Click **Finish**
8. Click the **Play** button to start the emulator
9. Wait for emulator to fully boot
10. Run: `flutter devices` to verify emulator is detected

### 3. Verify Emulator is Running

**Check available devices:**
```bash
flutter devices
```

You should see something like:
```
sdk gphone64 arm64 • emulator-5554 • android-arm64  • Android 13 (API 33)
```

**If emulator is not listed:**
- Make sure emulator is fully booted (wait 1-2 minutes)
- Check Android Studio Device Manager shows emulator as running
- Restart Flutter: `flutter doctor`

### 4. Run Tests

**Run all tests:**
```bash
# Tests will automatically use the first available Android/iOS device
flutter test integration_test/

# Or specify device explicitly
flutter test integration_test/ -d <device_id>
```

**Run specific test:**
```bash
flutter test integration_test/test_login.dart
```

**Run with verbose output:**
```bash
flutter test integration_test/ --reporter expanded
```

**List available devices:**
```bash
flutter devices
```

## 📁 Project Structure

```
├── integration_test/
│   ├── app_test.dart              # Complete user journey test
│   ├── test_registration.dart     # Registration flow
│   ├── test_login.dart            # Login flow
│   ├── test_product_listing.dart  # Product browsing & filtering
│   ├── test_cart_and_order.dart  # Cart & order placement
│   ├── helpers/
│   │   ├── test_helpers.dart     # Utility functions
│   │   └── page_objects.dart     # Page Object Models
│   └── README.md                 # Detailed documentation
├── scripts/
│   ├── run_integration_tests.sh  # Linux/Mac test runner
│   └── run_integration_tests.bat # Windows test runner
└── .github/workflows/
    └── integration_tests.yml     # CI/CD configuration
```

## 🧪 Test Files

### 1. `app_test.dart`
Complete end-to-end user journey covering all major flows.

### 2. `test_registration.dart`
Tests user registration flow:
- Navigate to registration
- Fill registration form
- Submit and verify success

### 3. `test_login.dart`
Tests user login flow:
- Navigate to login
- Enter credentials
- Verify successful login

### 4. `test_product_listing.dart`
Tests product browsing:
- Navigate to categories
- View product listings
- Apply distance filters

### 5. `test_cart_and_order.dart`
Tests shopping flow:
- Add products to cart
- View cart
- Checkout and place order

## 🔧 Configuration

### Test Data

Tests use dynamically generated test data:
- **Email**: `test_<timestamp>@test.com`
- **Password**: `Test123456!`
- **Name**: `Test User`

Test data is automatically cleaned up after tests complete.

### Timeouts

Default timeout is 5 seconds for most operations. Adjust in test files if needed:

```dart
await tester.pumpAndSettle(const Duration(seconds: 10));
```

## 🏃 Running Tests

### Using Scripts

**Windows:**
```bash
scripts\run_integration_tests.bat
```

**Linux/Mac:**
```bash
./scripts/run_integration_tests.sh
```

### Manual Execution

```bash
# List available devices
flutter devices

# Run on specific device
flutter test integration_test/ -d <device_id>

# Run with JSON reporter (for CI)
flutter test integration_test/ --reporter json > test_results.json
```

## 🔄 CI/CD Integration

Tests automatically run on:
- Push to `main`, `autotest`, or `develop` branches
- Pull requests to these branches
- Manual workflow dispatch

### GitHub Actions Workflow

The CI pipeline (`.github/workflows/integration_tests.yml`):
1. Sets up Flutter environment
2. Creates Android emulator
3. Runs all integration tests
4. Generates test reports
5. Uploads artifacts

### Viewing CI Results

1. Go to GitHub Actions tab
2. Select the workflow run
3. View test results and logs
4. Download test reports from artifacts

## 📊 Test Reports

### Local Reports

```bash
# Generate JSON report
flutter test integration_test/ --reporter json > test_reports/results.json

# Generate HTML report (requires additional tooling)
# See: https://pub.dev/packages/test_report_generator
```

### CI Reports

Test reports are automatically generated and uploaded as artifacts in GitHub Actions.

## 🐛 Troubleshooting

### Common Issues

**1. "No devices found"**
```bash
# Start an emulator first
flutter emulators --launch <emulator_id>
# Or connect a physical device
```

**2. "Widget not found"**
- Check if UI has changed
- Update selectors in `page_objects.dart`
- Use `flutter test --verbose` for detailed errors

**3. "Timeout errors"**
- Increase timeout values in test files
- Check network connectivity
- Ensure emulator is responsive

**4. "Firebase authentication errors"**
- Verify Firebase configuration
- Check test credentials
- Ensure Firebase project is set up correctly

### Debug Mode

Run tests with verbose output:
```bash
flutter test integration_test/ --reporter expanded --verbose
```

## 📝 Best Practices

1. **Page Object Model**: Always use Page Objects for UI interactions
2. **Test Isolation**: Each test should be independent
3. **Cleanup**: Always clean up test data
4. **Wait Times**: Use appropriate wait times for async operations
5. **Error Handling**: Handle edge cases gracefully

## 🔐 Test Credentials

For testing, use:
- Test Firebase project (separate from production)
- Test user accounts (automatically created/cleaned)
- Mock data where possible

## 📚 Additional Resources

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Page Object Model Pattern](https://martinfowler.com/bliki/PageObject.html)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)

## 🤝 Contributing

When adding new tests:
1. Follow existing test structure
2. Use Page Objects for UI interactions
3. Add cleanup for test data
4. Update documentation
5. Ensure tests pass in CI

## 📞 Support

For issues or questions:
1. Check troubleshooting section
2. Review test logs
3. Check CI/CD pipeline status
4. Open an issue with detailed error logs

