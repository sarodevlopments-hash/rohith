import 'package:flutter/material.dart';

class AppTheme {
  // Premium Color System - Soft Pastel Gradient-Based Design
  // Primary Brand Gradient: Teal → Aqua → Soft Green
  static const Color teal = Color(0xFF5EC6C6); // #5EC6C6
  static const Color aqua = Color(0xFF6FD3C8); // #6FD3C8
  static const Color softGreen = Color(0xFFA7E3B3); // #A7E3B3
  
  // Primary Colors
  static const Color primaryColor = teal; // Use teal as primary
  static const Color secondaryColor = aqua;
  static const Color accentColor = softGreen;
  
  // Badge Colors
  static const Color badgeRecommended = Color(0xFF6FA8FF); // Soft blue
  static const Color badgeDiscount = Color(0xFFFF6B6B); // Coral red
  static const Color badgeOffer = Color(0xFFFFB703); // Peach/orange
  
  // Status Colors (Softer versions)
  static const Color successColor = softGreen;
  static const Color warningColor = badgeOffer;
  static const Color errorColor = badgeDiscount;
  static const Color infoColor = badgeRecommended;

  // Background Colors - Very Light Pastel
  static const Color backgroundColor = Color(0xFFF7F5FB); // Light pastel lavender/pearl white
  static const Color backgroundColorAlt = Color(0xFFFAFAFE); // Alternative pearl white
  static const Color cardColor = Colors.white;
  static const Color surfaceColor = Colors.white;

  // Text Colors
  static const Color darkText = Color(0xFF2E3440); // Deep slate / charcoal
  static const Color lightText = Color(0xFF6B7280); // Muted grey-blue
  static const Color disabledText = Color(0xFFB0B7C3); // Disabled text/icons
  static const Color borderColor = Color(0xFFE8ECEF);

  // Premium Brand Gradient - Teal → Aqua → Soft Green
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [teal, aqua, softGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Savings/Wallet Gradient (Blue → Green)
  static const LinearGradient savingsGradient = LinearGradient(
    colors: [Color(0xFF6FA8FF), Color(0xFF5EC6C6), Color(0xFFA7E3B3)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Success Gradient
  static const LinearGradient successGradient = LinearGradient(
    colors: [aqua, softGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accent Gradient (for highlights)
  static const LinearGradient accentGradient = LinearGradient(
    colors: [teal, aqua],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warm Gradient (for offers)
  static const LinearGradient warmGradient = LinearGradient(
    colors: [badgeOffer, Color(0xFFFFD54F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Food Category Colors (Softer)
  static Color getVegColor() => const Color(0xFF50C878);
  static Color getEggColor() => const Color(0xFFFFB347);
  static Color getNonVegColor() => const Color(0xFFFF6B6B);

  // Card Styles - Premium with Soft Gradient Glow
  static BoxDecoration getCardDecoration({bool elevated = true, Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? cardColor,
      borderRadius: BorderRadius.circular(18), // 18-22px rounded corners
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ]
          : null,
      border: Border.all(
        color: borderColor.withOpacity(0.5),
        width: 0.5,
      ),
    );
  }

  // Category Card Decoration with Dark Overlay Gradient
  static BoxDecoration getCategoryCardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20), // 18-22px rounded corners
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Button Styles - Cleaner and More Elegant
  static BoxDecoration getPrimaryButtonDecoration({bool isPressed = false}) {
    return BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(14),
      boxShadow: isPressed
          ? []
          : [
              BoxShadow(
                color: primaryColor.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
    );
  }

  static BoxDecoration getSuccessButtonDecoration({bool isPressed = false}) {
    return BoxDecoration(
      gradient: successGradient,
      borderRadius: BorderRadius.circular(14),
      boxShadow: isPressed
          ? []
          : [
              BoxShadow(
                color: successColor.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
    );
  }

  static BoxDecoration getAccentButtonDecoration({bool isPressed = false}) {
    return BoxDecoration(
      gradient: accentGradient,
      borderRadius: BorderRadius.circular(14),
      boxShadow: isPressed
          ? []
          : [
              BoxShadow(
                color: accentColor.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
    );
  }

  // Badge Styles - Premium Pill-Shaped with Soft Shadows
  static BoxDecoration getBadgeDecoration(Color color, {bool withShadow = true}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20), // Pill-shaped
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  // Badge Decorations for Specific Types
  static BoxDecoration getRecommendedBadgeDecoration() {
    return getBadgeDecoration(badgeRecommended);
  }

  static BoxDecoration getDiscountBadgeDecoration() {
    return getBadgeDecoration(badgeDiscount);
  }

  static BoxDecoration getOfferBadgeDecoration() {
    return getBadgeDecoration(badgeOffer);
  }

  // Input Field Styles - Cleaner and More Spacious
  static InputDecoration getInputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hint,
    Color? fillColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: primaryColor, size: 22)
          : null,
      filled: true,
      fillColor: fillColor ?? backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: TextStyle(
        color: lightText,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: lightText.withOpacity(0.6),
        fontSize: 15,
      ),
    );
  }

  // Text Styles - Better Typography
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: darkText,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: darkText,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: darkText,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: darkText,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: darkText,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: darkText,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: lightText,
    height: 1.4,
  );

  // Chip Styles - Premium Pill-Shaped with Soft Shadows
  static BoxDecoration getChipDecoration({
    required bool isSelected,
    Color? color,
    bool isFreeSize = false,
  }) {
    final chipColor = color ?? (isFreeSize ? secondaryColor : primaryColor);
    return BoxDecoration(
      gradient: isSelected
          ? LinearGradient(
              colors: [
                chipColor,
                chipColor.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isSelected ? null : chipColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20), // Pill-shaped
      border: Border.all(
        color: isSelected
            ? chipColor
            : chipColor.withOpacity(0.2),
        width: isSelected ? 2 : 1,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: chipColor.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
                spreadRadius: 0,
              ),
            ],
    );
  }

  // Price Badge Style
  static BoxDecoration getPriceBadgeDecoration() {
    return BoxDecoration(
      gradient: successGradient,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: successColor.withOpacity(0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Section Header Style
  static Widget buildSectionHeader({
    required String title,
    IconData? icon,
    Color? iconColor,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (iconColor ?? primaryColor).withOpacity(0.15),
                        (iconColor ?? primaryColor).withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (iconColor ?? primaryColor).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Flexible(
                child: Text(
                  title,
                  style: heading3.copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: bodySmall.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
