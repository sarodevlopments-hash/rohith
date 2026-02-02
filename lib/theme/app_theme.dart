import 'package:flutter/material.dart';

class AppTheme {
  // Beautiful, Warm Color Palette - More Pleasant and Easy on the Eyes
  static const Color primaryColor = Color(0xFF4A90E2); // Soft Blue
  static const Color secondaryColor = Color(0xFF7B68EE); // Soft Purple
  static const Color accentColor = Color(0xFFFF6B9D); // Soft Pink
  static const Color successColor = Color(0xFF50C878); // Fresh Green
  static const Color warningColor = Color(0xFFFFB347); // Warm Orange
  static const Color errorColor = Color(0xFFFF6B6B); // Soft Red
  static const Color infoColor = Color(0xFF5DADE2); // Sky Blue

  // Neutral Colors - Softer and More Pleasant
  static const Color darkText = Color(0xFF2C3E50);
  static const Color lightText = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color borderColor = Color(0xFFE8ECEF);
  static const Color surfaceColor = Color(0xFFFFFBF8); // Warm white

  // Beautiful Gradients - Softer and More Elegant
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF50C878), Color(0xFF48BB78)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFF8C94)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFB347), Color(0xFFFFA07A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Food Category Colors (Softer)
  static Color getVegColor() => const Color(0xFF50C878);
  static Color getEggColor() => const Color(0xFFFFB347);
  static Color getNonVegColor() => const Color(0xFFFF6B6B);

  // Card Styles - More Elegant with Better Shadows
  static BoxDecoration getCardDecoration({bool elevated = true, Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ]
          : null,
      border: Border.all(
        color: borderColor,
        width: 1,
      ),
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

  // Badge Styles - Softer and More Elegant
  static BoxDecoration getBadgeDecoration(Color color, {bool withShadow = true}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ]
          : null,
    );
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

  // Chip Styles - Softer and More Elegant
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
      color: isSelected ? null : chipColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected
            ? chipColor
            : chipColor.withOpacity(0.25),
        width: isSelected ? 2 : 1.5,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: chipColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ]
          : null,
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
              Expanded(
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
