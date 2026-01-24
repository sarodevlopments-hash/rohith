class OrderStatusMessage {
  final String orderId;
  final String status;

  const OrderStatusMessage({required this.orderId, required this.status});
}

class WebOrderBroadcast {
  static Stream<OrderStatusMessage> get stream => const Stream.empty();

  static void postStatus({required String orderId, required String status}) {
    // no-op (non-web)
  }
}


