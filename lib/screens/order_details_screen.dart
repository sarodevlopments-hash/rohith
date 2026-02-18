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
import '../services/product_review_service.dart';
import '../services/seller_review_service.dart';
import '../widgets/seller_name_widget.dart';
import '../theme/app_theme.dart';
import 'write_product_review_screen.dart';
import 'write_seller_review_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Order get order => widget.order;

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
                          order.statusDisplayText,
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
                    decoration: AppTheme.getCardDecoration(elevated: true),
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
                    style: AppTheme.heading2,
                  ),
                  // Show size and color prominently if available
                  if ((order.selectedSize != null && order.selectedSize!.isNotEmpty) ||
                      (order.selectedColor != null && order.selectedColor!.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: AppTheme.getChipDecoration(
                              isSelected: true,
                              color: order.selectedSize == 'Free Size' ? AppTheme.secondaryColor : AppTheme.infoColor,
                              isFreeSize: order.selectedSize == 'Free Size',
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  order.selectedSize == 'Free Size' ? Icons.all_inclusive : Icons.straighten,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Size: ${order.selectedSize}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: AppTheme.getChipDecoration(
                              isSelected: true,
                              color: AppTheme.accentColor,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.palette, size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Color: ${order.selectedColor}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (order.selectedPackQuantity != null && order.selectedPackLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pack Size: ${order.selectedPackLabel}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Show seller name (blurred before confirmation, clear after) for groceries/vegetables
                  // Always show clear for other types
                  SellerNameWidget(
                    sellerName: order.sellerName,
                    shouldHideSellerIdentity: order.shouldHideSellerIdentity(),
                    isOrderAccepted: isAccepted,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Product Details Section
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Size (for clothing items)
                  if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                    _buildDetailRow(
                      Icons.straighten,
                      'Size',
                      order.selectedSize!,
                    ),
                  if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  // Color (for clothing items)
                  if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                    _buildDetailRow(
                      Icons.palette,
                      'Color',
                      order.selectedColor!,
                    ),
                  if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  // Payment Method
                  if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
                    _buildDetailRow(
                      Icons.payment,
                      'Payment Mode',
                      order.paymentMethod!,
                    ),
                  if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
                    const SizedBox(height: 16),
                  
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

                  // Review Section (for buyer view only)
                  if (!isSellerView) ...[
                    if (order.orderStatus == 'Completed') ...[
                      _buildReviewSection(context, listing),
                      const Divider(),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Show helpful message for non-completed orders
                      Card(
                        color: Colors.amber.shade50,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Reviews Available After Completion',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Current status: ${order.orderStatus}. Reviews will appear here once the seller marks the order as "Completed".',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                  ],

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
                                    firestoreStatus == 'ReadyForPickup' ||
                                    firestoreStatus == 'Completed';
        final finalIsAccepted = isAccepted || isAcceptedFirestore;
        
        // Get OTP information
        // OTP should remain visible until order status is 'Completed'
        final pickupOtp = (data['pickupOtp'] as String?) ?? '';
        // Show OTP if status is ReadyForPickup and order is not yet Completed
        final shouldShowOtp = firestoreStatus == 'ReadyForPickup' && 
                              pickupOtp.isNotEmpty;

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
            // For groceries/vegetables, also mention seller name will be visible
            final shouldHideSeller = order.shouldHideSellerIdentity();
            return Text(
              shouldHideSeller
                  ? 'Seller name, phone & pickup location will be visible after the seller accepts.'
                  : 'Seller phone & pickup location will be visible after the seller accepts.',
              style: TextStyle(color: Colors.grey.shade700),
            );
          }
          
          final sellerPhone = (data['sellerPhone'] as String?) ?? '';
          final pickup = (data['sellerPickupLocation'] as String?) ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show OTP if order is ready for pickup (until completed)
              if (shouldShowOtp && !isSellerView) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.teal.withOpacity(0.1), AppTheme.teal.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.teal.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code, color: AppTheme.teal, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Pickup OTP',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Show this OTP to the seller to collect your order:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.teal, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            pickupOtp,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: AppTheme.teal,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Show seller name for groceries/vegetables after acceptance
              if (order.shouldHideSellerIdentity()) ...[
                _buildDetailRow(
                  Icons.person,
                  'Seller Name',
                  order.sellerName,
                ),
                const SizedBox(height: 12),
              ],
              if (sellerPhone.isNotEmpty) _buildPhoneRowWithCallLink(sellerPhone),
              if (pickup.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildLocationRowWithMapLink(pickup),
              ],
              if (sellerPhone.isEmpty && pickup.isEmpty && !order.shouldHideSellerIdentity())
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

  Widget _buildReviewSection(BuildContext context, Listing? listing) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    if (listing == null) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Review Unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Product listing not found. Reviews are only available for active products.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, bool>>(
      future: Future.wait([
        ProductReviewService.canReviewProduct(
          buyerId: currentUser.uid,
          productId: order.listingId,
          orderId: order.orderId,
        ),
        SellerReviewService.canReviewSeller(
          buyerId: currentUser.uid,
          sellerId: order.sellerId,
          orderId: order.orderId,
        ),
      ]).then((results) => {
        'canReviewProduct': results[0],
        'canReviewSeller': results[1],
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final canReviewProduct = snapshot.data?['canReviewProduct'] ?? false;
        final canReviewSeller = snapshot.data?['canReviewSeller'] ?? false;

        // Show message if can't review
        if (!canReviewProduct && !canReviewSeller) {
          return Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have already reviewed this order, or the order is not eligible for review.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Write a Review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share your experience to help other buyers',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (canReviewProduct) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WriteProductReviewScreen(
                        order: order,
                        listing: listing,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    // Refresh the screen to update review status
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.star_outline),
                label: const Text('Review Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (canReviewSeller)
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WriteSellerReviewScreen(
                        order: order,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    // Refresh the screen to update review status
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.store_outlined),
                label: const Text('Review Seller'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        );
      },
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

