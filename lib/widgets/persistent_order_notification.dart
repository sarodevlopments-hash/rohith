import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../screens/order_details_screen.dart';

class PersistentOrderNotification extends StatefulWidget {
  final Order order;
  final String? sellerPhone;
  final String? pickupLocation;
  final VoidCallback onDismiss;

  const PersistentOrderNotification({
    super.key,
    required this.order,
    this.sellerPhone,
    this.pickupLocation,
    required this.onDismiss,
  });

  @override
  State<PersistentOrderNotification> createState() => _PersistentOrderNotificationState();
}

class _PersistentOrderNotificationState extends State<PersistentOrderNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openMap() async {
    if (widget.pickupLocation == null || widget.pickupLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup location not available')),
      );
      return;
    }

    final encodedLocation = Uri.encodeComponent(widget.pickupLocation!);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map')),
        );
      }
    }
  }

  Future<void> _callSeller() async {
    if (widget.sellerPhone == null || widget.sellerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller phone number not available')),
      );
      return;
    }

    final url = Uri.parse('tel:${widget.sellerPhone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make phone call')),
        );
      }
    }
  }

  void _viewOrder() {
    // Animate out first, then navigate and dismiss
    _animationController.reverse().then((_) {
      widget.onDismiss();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: widget.order),
          ),
        );
      }
    });
  }
  
  void _dismiss() {
    // Animate out, then dismiss
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  String _getLiveKitchenStatusText() {
    switch (widget.order.orderStatus) {
      case 'Preparing':
        return '🔥 Order Being Prepared';
      case 'ReadyForPickup':
        return '✅ Ready for Pickup!';
      case 'ReadyForDelivery':
        return '✅ Ready for Delivery!';
      default:
        return '✅ Order Accepted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortOrderId = widget.order.orderId.length > 6
        ? widget.order.orderId.substring(widget.order.orderId.length - 6)
        : widget.order.orderId;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.order.isLiveKitchenOrder ?? false
                            ? _getLiveKitchenStatusText()
                            : '✅ Order Accepted',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _dismiss,
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Order Info
                Text(
                  widget.order.foodName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order ID: $shortOrderId • ${widget.order.sellerName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                
                // Action Buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    // View on Map
                    if (widget.pickupLocation != null && widget.pickupLocation!.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openMap,
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (widget.pickupLocation != null && widget.pickupLocation!.isNotEmpty)
                      const SizedBox(width: 8),
                    
                    // Call Seller
                    if (widget.sellerPhone != null && widget.sellerPhone!.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callSeller,
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (widget.sellerPhone != null && widget.sellerPhone!.isNotEmpty)
                      const SizedBox(width: 8),
                    
                    // View Order
                    Expanded(
                      flex: widget.pickupLocation != null && widget.pickupLocation!.isNotEmpty ? 1 : 2,
                      child: ElevatedButton.icon(
                        onPressed: _viewOrder,
                        icon: const Icon(Icons.shopping_bag, size: 18),
                        label: const Text('View Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

