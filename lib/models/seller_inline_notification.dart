import '../models/order.dart';

/// Simple data model for Cart's inline seller notification.
class SellerInlineNotification {
  final Order order;
  final int pendingCount;

  const SellerInlineNotification({
    required this.order,
    required this.pendingCount,
  });
}


