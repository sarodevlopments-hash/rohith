import 'dart:math';

/// Service for generating and managing OTPs for order pickup verification
class OtpService {
  /// Generates a 6-digit OTP
  static String generateOtp() {
    final random = Random();
    // Generate a 6-digit number (100000 to 999999)
    final otp = 100000 + random.nextInt(900000);
    return otp.toString().padLeft(6, '0');
  }

  /// Validates if the provided OTP matches the stored OTP
  static bool validateOtp(String providedOtp, String storedOtp) {
    // Remove any whitespace and compare
    return providedOtp.trim() == storedOtp.trim();
  }
}

