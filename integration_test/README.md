# Integration Tests Documentation

This directory contains end-to-end (E2E) integration tests for the Food App using Flutter's `integration_test` package.

## Structure

```
integration_test/
├── app_test.dart              # Main test file with complete user journey
├── test_registration.dart     # Registration flow test
├── test_login.dart            # Login flow test
├── test_product_listing.dart  # Product listing and filtering test
├── test_cart_and_order.dart  # Cart and order placement test
├── helpers/
│   ├── test_helpers.dart     # Test utility functions
│   └── page_objects.dart     # Page Object Model classes
└── README.md                 # This file
```

## Prerequisites

1. **Flutter SDK**: Version 3.0.0 or higher
2. **Android Emulator** or **iOS Simulator** (or physical device)
   - ⚠️ **IMPORTANT**: Web and Desktop devices are NOT supported for integration tests
   - See `SETUP_ANDROID_EMULATOR.md` for detailed setup instructions
3. **Firebase Setup**: Ensure Firebase is configured with test credentials
4. **Dependencies**: Run `flutter pub get` to install all dependencies

## Running Tests

### Option 1: Run All Tests

```bash
flutter test integration_test/
```

### Option 2: Run Specific Test File

```bash
flutter test integration_test/test_login.dart
```

### Option 3: Run on Specific Device

```bash
flutter test integration_test/ -d <device_id>
```

### Option 4: Using Test Scripts

**Windows:**
```bash
scripts\run_integration_tests.bat
```

**Linux/Mac:**
```bash
chmod +x scripts/run_integration_tests.sh
./scripts/run_integration_tests.sh
```

## Test Coverage

### 1. User Registration (`test_registration.dart`)
- ✅ Navigate to registration screen
- ✅ Fill registration form
- ✅ Submit registration
- ✅ Verify successful registration

### 2. User Login (`test_login.dart`)
- ✅ Navigate to login screen
- ✅ Fill login form with credentials
- ✅ Submit login
- ✅ Verify successful login and dashboard access

### 3. Product Listing (`test_product_listing.dart`)
- ✅ Browse products by category
- ✅ Verify products are displayed
- ✅ Apply distance filter
- ✅ Verify filtered results

### 4. Add Product (`app_test.dart`)
- ✅ Navigate to "Start Selling"
- ✅ Select category
- ✅ Fill product form
- ✅ Submit product listing

### 5. Cart and Order (`test_cart_and_order.dart`)
- ✅ Add product to cart
- ✅ View cart
- ✅ Proceed to checkout
- ✅ Place order
- ✅ Verify order confirmation

## Test Data

Tests use dynamically generated test data:
- **Email**: `test_<timestamp>@test.com`
- **Password**: `Test123456!`
- **Name**: `Test User`

Test data is automatically cleaned up after tests complete.

## CI/CD Integration

Tests are automatically run on:
- Push to `main`, `autotest`, or `develop` branches
- Pull requests to these branches
- Manual workflow dispatch

See `.github/workflows/integration_tests.yml` for CI configuration.

## Troubleshooting

### Tests Fail with "No devices found"
- ⚠️ **Web/Desktop devices are NOT supported** - You must use Android emulator or iOS simulator
- Start an emulator/simulator before running tests
- List available devices: `flutter devices`
- Run tests on specific device: `flutter test integration_test/ -d <device_id>`
- See `SETUP_ANDROID_EMULATOR.md` for detailed emulator setup guide

### "Web devices are not supported for integration tests yet"
- This error means you're trying to run tests on Chrome/Edge/Desktop
- **Solution**: You MUST use an Android emulator or iOS simulator
- Follow the setup guide in `SETUP_ANDROID_EMULATOR.md`

### Firebase Authentication Errors
- Ensure Firebase is properly configured
- Check that test credentials are valid
- Verify Firebase project settings

### Timeout Errors
- Increase timeout in test files: `await tester.pumpAndSettle(Duration(seconds: 10))`
- Check network connectivity
- Ensure emulator/simulator is responsive

### Widget Not Found Errors
- Verify widget keys/IDs match actual implementation
- Check if UI has changed and update selectors accordingly
- Use `flutter test --verbose` for detailed error messages

## Best Practices

1. **Page Object Model**: Use Page Objects to abstract UI interactions
2. **Test Helpers**: Use helper functions for common operations
3. **Cleanup**: Always clean up test data after tests
4. **Isolation**: Each test should be independent
5. **Wait Times**: Use appropriate wait times for async operations

## Generating Test Reports

Test reports are automatically generated in CI/CD. For local reports:

```bash
flutter test integration_test/ --reporter json > test_reports/test_results.json
```

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Use Page Objects for UI interactions
3. Add cleanup for test data
4. Update this README with new test coverage

