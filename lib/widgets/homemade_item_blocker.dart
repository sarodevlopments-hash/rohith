import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomemadeItemBlocker extends StatelessWidget {
  final VoidCallback? onGoToCookedFood;
  final VoidCallback? onGoToLiveFood;

  const HomemadeItemBlocker({
    super.key,
    this.onGoToCookedFood,
    this.onGoToLiveFood,
  });

  static Future<void> show(BuildContext context, {
    VoidCallback? onGoToCookedFood,
    VoidCallback? onGoToLiveFood,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HomemadeItemBlocker(
        onGoToCookedFood: onGoToCookedFood,
        onGoToLiveFood: onGoToLiveFood,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                color: AppTheme.errorColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Homemade Edible Items Not Allowed',
              style: AppTheme.heading3.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              'Homemade edible items cannot be sold under Groceries.\n\n'
              'For safety and compliance, homemade edible products must be sold as Cooked Food or Live Food only.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.lightText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onGoToCookedFood?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Go to Cooked Food',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onGoToLiveFood?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppTheme.primaryColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Go to Live Food',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

