# Complete User Journey E2E Test

This test covers the complete user journey from login to order completion and reviews.

## Test Flow

1. **Login** - Login with `test@gmail.com` / `123456`
2. **Seller Dashboard** - Navigate to seller dashboard
3. **Start Selling** - Click "Start Selling" tab
4. **Select Live Kitchen** - Choose "Live Kitchen Food" option
5. **Fill Details** - Enter all mandatory fields:
   - Product name
   - Price
   - Description
   - FSSAI number
   - Preparation time
   - Max capacity
6. **Verification** - Complete seller verification with bank details and documentation
7. **Post Item** - Submit the listing
8. **Manage Items** - Verify item appears in "Manage Items"
9. **Verify Modification** - Check that edit functionality is available
10. **Switch to Buyer** - Navigate to buyer/home tab
11. **View Item** - Verify the posted item is visible
12. **Place Order** - Add item to cart/order with cash on delivery payment
13. **Seller Notification** - Verify seller receives notification
14. **Complete Order** - Seller marks order as completed
15. **Buyer Orders** - Verify completed order in buyer orders tab
16. **Product Review** - Submit product review
17. **Seller Review** - Submit seller review
18. **Verify Reviews** - Check reviews appear in seller dashboard
19. **Verify Rating** - Check rating displays in buyer dashboard (e.g., 4.2 (3 people))

## Running the Test

```bash
# On Windows
flutter test integration_test/test_complete_journey.dart -d emulator-5554 --reporter expanded

# On Linux/Mac
flutter test integration_test/test_complete_journey.dart -d emulator-5554 --reporter expanded
```

## Prerequisites

1. Android emulator must be running
2. User account `test@gmail.com` with password `123456` must exist
3. App must be built and installed on emulator

## Notes

- The test uses timeout-based waits instead of `pumpAndSettle` to avoid hanging
- Image uploads are skipped in the test (would require file picker mocking)
- Some UI elements may need adjustment based on actual app structure
- The test is designed to be resilient to minor UI changes

