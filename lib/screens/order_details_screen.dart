import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../models/listing.dart';
import '../models/measurement_unit.dart';
import '../services/order_firestore_service.dart';
import '../services/seller_profile_service.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSellerView = currentUid.isNotEmpty && currentUid == order.sellerId;
    final isAccepted = order.orderStatus == 'AcceptedBySeller' ||
        order.orderStatus == 'Confirmed' ||
        order.orderStatus == 'Completed';

    // Get listing details
    final listingBox = Hive.box<Listing>('listingBox');
    Listing? listing;
    try {
      final listingKey = int.tryParse(order.listingId);
      if (listingKey != null) {
        listing = listingBox.get(listingKey);
      }
    } catch (e) {
      // Listing might not exist anymore
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Order Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor(order.orderStatus).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: _getStatusColor(order.orderStatus),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(order.orderStatus),
                    color: _getStatusColor(order.orderStatus),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderStatus,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(order.orderStatus),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${order.orderId.substring(order.orderId.length - 6)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Product Image
            if (listing != null && listing.imagePath != null)
              Builder(
                builder: (context) {
                  final imagePath = listing!.imagePath!;
                  return Container(
                    height: 250,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: _loadImageBytes(imagePath),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : File(imagePath).existsSync()
                              ? Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.fastfood, size: 64),
                                ),
                    ),
                  );
                },
              ),

            // Order Information
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name (already includes pack info if available)
                  Text(
                    order.foodName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (order.selectedPackQuantity != null && order.selectedPackLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pack Size: ${order.selectedPackLabel}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'by ${order.sellerName}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Order Date & Time
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Order Date',
                    _formatFullDateTime(order.purchasedAt),
                  ),
                  const SizedBox(height: 16),

                  // Quantity (Number of Packs)
                  _buildDetailRow(
                    Icons.shopping_cart,
                    order.selectedPackQuantity != null ? 'Number of Packs' : 'Quantity',
                    // Show pack size quantity if available
                    order.selectedPackQuantity != null && order.selectedPackLabel != null
                        ? '${order.quantity} pack${order.quantity > 1 ? 's' : ''} of ${order.selectedPackLabel}'
                        : order.selectedPackQuantity != null && listing?.measurementUnit != null
                            ? '${order.quantity} pack${order.quantity > 1 ? 's' : ''} of ${order.selectedPackQuantity} ${listing!.measurementUnit!.shortLabel}'
                            : '${order.quantity} item${order.quantity > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 16),

                  Text(
                    isSellerView ? 'Seller Details' : 'Seller Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPrivacyGatedDetails(context, isSellerView: isSellerView, isAccepted: isAccepted),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 16),

                  // Price Breakdown
                  const Text(
                    'Price Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    order.selectedPackPrice != null ? 'Price per Pack' : 'Unit Price',
                    order.selectedPackPrice != null
                        ? '₹${order.selectedPackPrice!.toStringAsFixed(0)}'
                        : '₹${order.discountedPrice.toStringAsFixed(0)}',
                  ),
                  _buildPriceRow(
                    order.selectedPackQuantity != null ? 'Number of Packs' : 'Quantity',
                    '${order.quantity}',
                  ),
                  if (order.originalPrice > order.discountedPrice)
                    _buildPriceRow(
                      'Original Price',
                      order.selectedPackPrice != null
                          ? '₹${(order.selectedPackPrice! * order.quantity).toStringAsFixed(0)}'
                          : '₹${(order.originalPrice * order.quantity).toStringAsFixed(0)}',
                      isStrikethrough: true,
                    ),
                  if (order.savedAmount > 0)
                    _buildPriceRow(
                      'Savings',
                      '₹${order.savedAmount.toStringAsFixed(0)}',
                      isHighlight: true,
                      color: Colors.green,
                    ),
                  const Divider(),
                  _buildPriceRow(
                    'Total Amount',
                    '₹${order.pricePaid.toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyGatedDetails(
    BuildContext context, {
    required bool isSellerView,
    required bool isAccepted,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: OrderFirestoreService.doc(order.orderId).snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.exists ?? false) ? snap.data!.data() : null;
        if (data == null) {
          return Text('Loading details…', style: TextStyle(color: Colors.grey.shade700));
        }

        // Check order status from Firestore (most up-to-date)
        final firestoreStatus = (data['orderStatus'] as String?) ?? order.orderStatus;
        final isAcceptedFirestore = firestoreStatus == 'AcceptedBySeller' ||
                                    firestoreStatus == 'Confirmed' ||
                                    firestoreStatus == 'Completed';
        final finalIsAccepted = isAccepted || isAcceptedFirestore;

        if (isSellerView) {
          // Seller view: Show seller's own details (phone and pickup location)
          // Try to get from Firestore first, then fallback to seller profile
          final sellerPhoneFromFirestore = (data['sellerPhone'] as String?) ?? '';
          final pickupFromFirestore = (data['sellerPickupLocation'] as String?) ?? '';
          
          // If Firestore doesn't have it, fetch from seller profile
          if (sellerPhoneFromFirestore.isEmpty || pickupFromFirestore.isEmpty) {
            return FutureBuilder(
              future: SellerProfileService.getProfile(order.sellerId),
              builder: (context, profileSnap) {
                final sellerPhone = sellerPhoneFromFirestore.isNotEmpty 
                    ? sellerPhoneFromFirestore 
                    : (profileSnap.data?.phoneNumber ?? '');
                final pickup = pickupFromFirestore.isNotEmpty 
                    ? pickupFromFirestore 
                    : (profileSnap.data?.pickupLocation ?? '');
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sellerPhone.isNotEmpty) _buildPhoneRowWithCallLink(sellerPhone),
                    if (pickup.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildLocationRowWithMapLink(pickup),
                    ],
                    if (sellerPhone.isEmpty && pickup.isEmpty)
                      Text('Seller details not available', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                );
              },
            );
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sellerPhoneFromFirestore.isNotEmpty) _buildPhoneRowWithCallLink(sellerPhoneFromFirestore),
              if (pickupFromFirestore.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildLocationRowWithMapLink(pickupFromFirestore),
              ],
            ],
          );
        } else {
          // Buyer view: Only show seller details after acceptance
          if (!finalIsAccepted) {
            return Text(
              'Seller phone & pickup location will be visible after the seller accepts.',
              style: TextStyle(color: Colors.grey.shade700),
            );
          }
          
          final sellerPhone = (data['sellerPhone'] as String?) ?? '';
          final pickup = (data['sellerPickupLocation'] as String?) ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sellerPhone.isNotEmpty) _buildPhoneRowWithCallLink(sellerPhone),
              if (pickup.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildLocationRowWithMapLink(pickup),
              ],
              if (sellerPhone.isEmpty && pickup.isEmpty)
                Text('Seller details not available', style: TextStyle(color: Colors.grey.shade700)),
            ],
          );
        }
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRowWithMapLink(String location) {
    // Check if location is coordinates (format: "lat, lng" or "lat,lng")
    final coordPattern = RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$');
    final isCoordinates = coordPattern.hasMatch(location.trim());
    
    String googleMapsUrl;
    if (isCoordinates) {
      // Parse coordinates and create Google Maps URL
      final parts = location.trim().split(',');
      if (parts.length == 2) {
        final lat = parts[0].trim();
        final lng = parts[1].trim();
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      } else {
        // Fallback: use location as search query
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
      }
    } else {
      // Use location as search query for addresses
      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
    }

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(googleMapsUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: try opening in browser
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        }
      },
      child: Row(
        children: [
          Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup Location',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_new,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to open in Google Maps',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRowWithCallLink(String phoneNumber) {
    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final telUrl = 'tel:$cleanPhone';

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(telUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Row(
        children: [
          Icon(Icons.phone, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller Phone',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.phone,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to call',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isStrikethrough = false,
    bool isHighlight = false,
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? (color ?? Colors.green) : Colors.black87,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? (color ?? Colors.green) : Colors.black87,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Completed':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<Uint8List> _loadImageBytes(String imagePath) async {
    if (kIsWeb) {
      final XFile file = XFile(imagePath);
      return await file.readAsBytes();
    } else {
      final File file = File(imagePath);
      return await file.readAsBytes();
    }
  }
}

