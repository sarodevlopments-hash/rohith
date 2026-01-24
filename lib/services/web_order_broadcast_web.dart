import 'dart:async';
import 'dart:html' as html;

class OrderStatusMessage {
  final String orderId;
  final String status;

  const OrderStatusMessage({required this.orderId, required this.status});
}

class WebOrderBroadcast {
  static final html.BroadcastChannel _ch = html.BroadcastChannel('order_status_channel');
  static final StreamController<OrderStatusMessage> _controller =
      StreamController<OrderStatusMessage>.broadcast();
  static bool _initialized = false;

  static void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _ch.onMessage.listen((event) {
      final data = event.data;
      if (data is Map) {
        final orderId = data['orderId']?.toString();
        final status = data['status']?.toString();
        if (orderId != null && status != null) {
          _controller.add(OrderStatusMessage(orderId: orderId, status: status));
        }
      }
    });
  }

  static Stream<OrderStatusMessage> get stream {
    _ensureInit();
    return _controller.stream;
  }

  static void postStatus({required String orderId, required String status}) {
    _ensureInit();
    _ch.postMessage({'orderId': orderId, 'status': status});
  }
}


