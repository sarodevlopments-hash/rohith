import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/clothing_category.dart';
import '../models/size_color_combination.dart';
import '../models/cooked_food_source.dart';
import '../models/measurement_unit.dart';
import '../models/pack_size.dart';
import '../models/pending_listing_item.dart';
import '../models/schedule_type.dart';
import '../models/scheduled_listing.dart';
import '../services/scheduled_listing_service.dart';
import '../services/product_suggestion_service.dart';
import '../models/seller_profile.dart';
import 'seller_item_management_screen.dart';
import '../services/listing_validator.dart';
import '../services/seller_profile_service.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AddListingScreen extends StatefulWidget {
  final ValueNotifier<int>? promptCounter;
  final VoidCallback? onBackToDashboard;
  const AddListingScreen({super.key, this.promptCounter, this.onBackToDashboard});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final originalPriceController = TextEditingController();
  final quantityController = TextEditingController(); // Stock quantity (number of items/packs)
  final packSizeWeightController = TextEditingController(); // Pack size weight for groceries without multiple packs
  final fssaiController = TextEditingController();
  final descriptionController = TextEditingController(); // Product description
  final placeSearchController = TextEditingController();
  final List<String> _placeSearchResults = [];
  Timer? _placeSearchDebounce;

  // Product name autocomplete
  final FocusNode _productNameFocusNode = FocusNode();
  List<String> _productNameSuggestions = [];
  bool _showProductSuggestions = false;
  Timer? _productNameDebounce;
  final LayerLink _productNameLayerLink = LayerLink();
  OverlayEntry? _productSuggestionOverlay;

  // Seller Profile Controllers (for one-time entry)
  final sellerNameController = TextEditingController();
  final sellerFssaiController = TextEditingController();
  final sellerPhoneController = TextEditingController();
  final sellerPickupLocationController = TextEditingController();

  // State variables
  SellType selectedType = SellType.cookedFood;
  CookedFoodSource? selectedCookedFoodSource;
  FoodCategory selectedCategory = FoodCategory.veg;
  ClothingCategory? selectedClothingCategory;
  MeasurementUnit? selectedMeasurementUnit;
  DateTime? preparedAt;
  DateTime? expiryDate;
  List<String> availableSizes = []; // Available sizes for clothing (deprecated, use sizeColorCombinations)
  List<String> availableColors = []; // Available colors for clothing (deprecated, use sizeColorCombinations)
  final sizeTextController = TextEditingController(); // For adding new size
  final colorTextController = TextEditingController(); // For adding new color
  List<SizeColorCombination> sizeColorCombinations = []; // Size-color combinations
  String? editingSize; // Currently editing size for color selection
  final Map<int, TextEditingController> colorControllers = {}; // Controllers for each size's color input
  PlatformFile? fssaiLicenseFile;
  File? productImage;
  String? productImagePath;
  Uint8List? productImageBytes; // For web storage
  // Color-specific images: Map of color name to image path/bytes
  final Map<String, String> colorImagePaths = {}; // Color name -> image path
  final Map<String, File?> colorImageFiles = {}; // Color name -> File (for mobile)
  final Map<String, Uint8List?> colorImageBytes = {}; // Color name -> bytes (for web)
  String? defaultColorImage; // Color name that is set as default product image

  bool isSubmitting = false;
  bool isFetchingLocation = false;
  bool isSearchingPlace = false;
  bool showSellerProfileForm = false;
  bool isFirstTimeSeller = false;
  bool _hasShownTypePrompt = false;
  SellerProfile? sellerProfile;
  Listing? selectedPreviousListing;
  
  // Pack sizes for groceries
  List<PackSize> packSizes = [];
  bool useMultiplePackSizes = false; // Toggle for groceries

  // Bulk food listing support
  bool isBulkFood = false;
  final servesCountController = TextEditingController();
  final portionDescriptionController = TextEditingController();

  // Live Kitchen support
  bool isKitchenOpen = false;
  final preparationTimeController = TextEditingController();
  final maxCapacityController = TextEditingController();

  // Multi-item listing support
  bool isMultiItemMode = false;
  List<PendingListingItem> pendingItems = [];
  
  // Scheduling support
  bool enableScheduling = false;
  ScheduleType? selectedScheduleType;
  DateTime? scheduleStartDate;
  DateTime? scheduleEndDate;
  TimeOfDay? scheduleTime; // Open/Post time
  TimeOfDay? scheduleCloseTime; // Close/Expiry time
  int? selectedDayOfWeek; // For weekly schedules

  String? get sellerId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadSellerProfile();
    widget.promptCounter?.addListener(_onPromptRequested);
    _productNameFocusNode.addListener(_onProductNameFocusChange);
  }

  void _onProductNameFocusChange() {
    if (!_productNameFocusNode.hasFocus) {
      // Delay removal to allow tap events on suggestions to be processed first
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_productNameFocusNode.hasFocus) {
          _removeProductSuggestionOverlay();
        }
      });
    }
  }

  @override
  void dispose() {
    _placeSearchDebounce?.cancel();
    _productNameDebounce?.cancel();
    _removeProductSuggestionOverlay();
    _productNameFocusNode.dispose();
    placeSearchController.dispose();
    nameController.dispose();
    priceController.dispose();
    originalPriceController.dispose();
    quantityController.dispose();
    fssaiController.dispose();
    sellerNameController.dispose();
    sellerFssaiController.dispose();
    sellerPhoneController.dispose();
    sellerPickupLocationController.dispose();
    servesCountController.dispose();
    portionDescriptionController.dispose();
    preparationTimeController.dispose();
    maxCapacityController.dispose();
    _scrollController.dispose();
    widget.promptCounter?.removeListener(_onPromptRequested);
    _productNameFocusNode.removeListener(_onProductNameFocusChange);
    super.dispose();
  }

  // Product name autocomplete methods
  void _onProductNameChanged(String value) {
    _productNameDebounce?.cancel();
    
    if (value.length < 2) {
      _removeProductSuggestionOverlay();
      setState(() {
        _productNameSuggestions = [];
        _showProductSuggestions = false;
      });
      return;
    }

    _productNameDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      
      final category = ProductSuggestionService.getCategoryFromSellType(selectedType);
      final suggestions = ProductSuggestionService.getSuggestions(
        value,
        sellerId: sellerId,
        category: category,
      );
      
      setState(() {
        _productNameSuggestions = suggestions;
        _showProductSuggestions = suggestions.isNotEmpty;
      });
      
      if (suggestions.isNotEmpty) {
        _showProductSuggestionOverlay();
      } else {
        _removeProductSuggestionOverlay();
      }
    });
  }

  void _showProductSuggestionOverlay() {
    _removeProductSuggestionOverlay();
    
    if (_productNameSuggestions.isEmpty || !mounted) return;

    final overlay = Overlay.of(context);
    
    _productSuggestionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 72, // Account for padding
        child: CompositedTransformFollower(
          link: _productNameLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60), // Position below the text field
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _productNameSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _productNameSuggestions[index];
                    final query = nameController.text.toLowerCase();
                    
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _selectProductSuggestion(suggestion);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: index < _productNameSuggestions.length - 1
                              ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildHighlightedText(suggestion, query),
                            ),
                            Icon(
                              Icons.north_west,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_productSuggestionOverlay!);
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 15),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: const TextStyle(fontSize: 15),
      );
    }

    final endIndex = startIndex + query.length;
    
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
        children: [
          if (startIndex > 0)
            TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          if (endIndex < text.length)
            TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  void _selectProductSuggestion(String suggestion) {
    // Immediately remove overlay first
    _removeProductSuggestionOverlay();
    
    // Update the text field
    nameController.text = suggestion;
    nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    
    // Clear suggestions state
    setState(() {
      _productNameSuggestions = [];
      _showProductSuggestions = false;
    });
    
    // Unfocus to dismiss keyboard and confirm selection
    _productNameFocusNode.unfocus();
  }

  void _removeProductSuggestionOverlay() {
    _productSuggestionOverlay?.remove();
    _productSuggestionOverlay = null;
  }

  Future<void> _loadSellerProfile() async {
    final currentSellerId = sellerId;
    if (currentSellerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue')),
        );
      }
      return;
    }
    final hasProfile = await SellerProfileService.hasProfile(currentSellerId);
    if (!hasProfile) {
      setState(() {
        isFirstTimeSeller = true;
        showSellerProfileForm = true;
      });
    } else {
      final profile = await SellerProfileService.getProfile(currentSellerId);
      setState(() {
        sellerProfile = profile;
        if (profile != null) {
          sellerNameController.text = profile.sellerName;
          sellerPhoneController.text = profile.phoneNumber;
          sellerPickupLocationController.text = profile.pickupLocation;
          // Only load FSSAI if it was for cooked food
          if (profile.defaultFoodType == SellType.cookedFood) {
            sellerFssaiController.text = profile.fssaiLicense;
          }
          selectedCookedFoodSource = profile.cookedFoodSource;
          if (profile.defaultFoodType != null) {
            selectedType = profile.defaultFoodType!;
          }
        }
      });
    }
  }

  void _applySelectedType(SellType v) {
    setState(() {
      selectedType = v;
      if (selectedType != SellType.cookedFood && selectedType != SellType.liveKitchen) {
        selectedCookedFoodSource = null;
        sellerFssaiController.clear();
        fssaiLicenseFile = null;
      }
      if (selectedType == SellType.vegetables || selectedType == SellType.clothingAndApparel || selectedType == SellType.groceries) {
        if (selectedType != SellType.groceries) {
          selectedCategory = FoodCategory.veg;
        }
        if (selectedType == SellType.clothingAndApparel) {
          selectedClothingCategory ??= ClothingCategory.unisex; // Default to unisex
        } else {
          selectedClothingCategory = null;
          availableSizes.clear();
          availableColors.clear();
          sizeColorCombinations.clear();
        }
        preparedAt = null;
        expiryDate = null;
      }
      if (selectedType == SellType.vegetables || selectedType == SellType.groceries) {
        selectedMeasurementUnit ??= MeasurementUnit.kilograms;
      }
      // Live Kitchen doesn't need dates but needs prep time and capacity
      if (selectedType == SellType.liveKitchen) {
        preparedAt = null;
        expiryDate = null;
        // Clear bulk food settings when switching to live kitchen
        isBulkFood = false;
        servesCountController.clear();
        portionDescriptionController.clear();
      } else {
        // Clear live kitchen settings when switching away
        isKitchenOpen = false;
        preparationTimeController.clear();
        maxCapacityController.clear();
      }
    });
  }

  void _onPromptRequested() {
    _promptItemType(force: true);
  }

  Future<void> promptItemType() async {
    await _promptItemType(force: true);
  }

  Future<void> _promptItemType({required bool force}) async {
    if (!mounted) return;
    if (!force && _hasShownTypePrompt) return;
    if (!force) _hasShownTypePrompt = true;
    SellType tempType = selectedType;

    final pickedType = await showDialog<SellType>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            String _typeTitle(SellType t) =>
                t == SellType.liveKitchen ? 'Live Kitchen' : t.displayName;

            String _typeHint(SellType t) {
              switch (t) {
                case SellType.cookedFood:
                  return 'Ready-made food items';
                case SellType.liveKitchen:
                  return 'Cook after order — real-time prep';
                case SellType.groceries:
                  return 'Packed daily essentials';
                case SellType.vegetables:
                  return 'Fresh produce';
                case SellType.clothingAndApparel:
                  return 'Apparel & accessories';
              }
            }

            IconData _typeIcon(SellType t) {
              switch (t) {
                case SellType.cookedFood:
                  return Icons.restaurant_rounded;
                case SellType.groceries:
                  return Icons.shopping_basket_rounded;
                case SellType.vegetables:
                  return Icons.eco_rounded;
                case SellType.clothingAndApparel:
                  return Icons.checkroom_rounded;
                case SellType.liveKitchen:
                  return Icons.local_fire_department_rounded;
              }
            }

            String? _typeImagePath(SellType t) {
              switch (t) {
                case SellType.cookedFood:
                  return 'assets/images/categories/cookedfood.png';
                case SellType.groceries:
                  return 'assets/images/categories/gro.png';
                case SellType.vegetables:
                  return 'assets/images/categories/vegs and fruitrs.png';
                case SellType.clothingAndApparel:
                  return 'assets/images/categories/clothesand app.png';
                case SellType.liveKitchen:
                  return 'assets/images/categories/live kitchen.png';
              }
            }

            Color _typeColor(SellType t) {
              switch (t) {
                case SellType.cookedFood:
                  return Colors.deepOrange;
                case SellType.groceries:
                  return Colors.blue;
                case SellType.vegetables:
                  return Colors.green;
                case SellType.clothingAndApparel:
                  return Colors.purple;
                case SellType.liveKitchen:
                  return Colors.red;
              }
            }

            LinearGradient? _typeGradient(SellType t) {
              if (t != SellType.liveKitchen) return null;
              return const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
              );
            }

            Widget _typeCard(SellType t) {
              final isSelected = tempType == t;
              final base = _typeColor(t);
              final gradient = _typeGradient(t);

              return GestureDetector(
                onTap: () => setStateDialog(() => tempType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: gradient == null
                        ? base.withOpacity(isSelected ? 0.16 : 0.10)
                        : null,
                    gradient: gradient != null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSelected
                                ? [
                                    gradient.colors[0].withOpacity(0.22),
                                    gradient.colors[1].withOpacity(0.22),
                                  ]
                                : [
                                    gradient.colors[0].withOpacity(0.12),
                                    gradient.colors[1].withOpacity(0.12),
                                  ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? base.withOpacity(0.9)
                          : base.withOpacity(0.18),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: base.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      if (isSelected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: base.withOpacity(0.95),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _typeImagePath(t) != null
                                    ? Image.asset(
                                        _typeImagePath(t)!,
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44,
                                        errorBuilder: (context, error, stackTrace) {
                                          // Fallback to icon if image fails
                                          return Icon(
                                            _typeIcon(t),
                                            size: 24,
                                            color: base,
                                          );
                                        },
                                      )
                                    : Icon(
                                        _typeIcon(t),
                                        size: 24,
                                        color: base,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _typeTitle(t),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _typeHint(t),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            final requiresFssai =
                tempType == SellType.cookedFood || tempType == SellType.liveKitchen;

            final buttonLabel = tempType == SellType.liveKitchen
                ? 'Continue with Live Kitchen'
                : 'Continue with ${tempType.displayName}';

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'What are you selling today?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You can change this later',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // Allow closing without changing the current selection.
                            // Use the root navigator to guarantee the dialog is dismissed.
                            Navigator.of(context, rootNavigator: true).pop(null);
                          },
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.black26,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(ctx).size.width;
                        final useTwoColumns = screenWidth >= 360;
                        final crossAxisCount = useTwoColumns ? 2 : 1;
                        // Fixed card height to avoid overflow; slightly taller on wider screens
                        final cardHeight = useTwoColumns ? 150.0 : 140.0;
                        final types = [
                          SellType.cookedFood,
                          SellType.groceries,
                          SellType.vegetables,
                          SellType.clothingAndApparel,
                          SellType.liveKitchen,
                        ];

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: types.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: cardHeight,
                          ),
                          itemBuilder: (context, index) => _typeCard(types[index]),
                        );
                      },
                    ),
                    if (requiresFssai) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tempType == SellType.liveKitchen
                                    ? 'FSSAI license required for Live Kitchen items.'
                                    : 'FSSAI license required for cooked food items.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(tempType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedType != null) {
      _applySelectedType(pickedType);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => isFetchingLocation = true);
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      // Always fall back to coordinates first; override with reverse-geocoded address if available
      sellerPickupLocationController.text = '${position.latitude}, ${position.longitude}';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressParts = [
            place.name,
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
          ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty);

          final resolvedAddress = addressParts.join(', ');
          if (resolvedAddress.isNotEmpty) {
            sellerPickupLocationController.text = resolvedAddress;
          }
        }
      } catch (_) {
        // Ignore reverse-geocoding failures; coordinates are already set
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup location set to current location')),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location timeout. Please try again.')),
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location services to autofill.')),
        );
      }
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow location permission to autofill.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isFetchingLocation = false);
      }
    }
  }

  Future<void> _openNearbyPlaces() async {
    placeSearchController.clear();
    _placeSearchResults.clear();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> search(String query) async {
              _placeSearchDebounce?.cancel();
              _placeSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
                final trimmed = query.trim();
                if (trimmed.isEmpty) return;
                setStateDialog(() {
                  isSearchingPlace = true;
                  _placeSearchResults.clear();
                });
                try {
                  final locations = await locationFromAddress(trimmed);
                  final List<String> addresses = [];
                  for (final loc in locations.take(5)) {
                    try {
                      final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
                      if (placemarks.isNotEmpty) {
                        final formatted = _formatPlacemark(placemarks.first);
                        if (formatted.isNotEmpty) {
                          addresses.add(formatted);
                        }
                      } else {
                        addresses.add('${loc.latitude}, ${loc.longitude}');
                      }
                    } catch (_) {
                      addresses.add('${loc.latitude}, ${loc.longitude}');
                    }
                  }
                  if (ctx.mounted) {
                    setStateDialog(() {
                      _placeSearchResults
                        ..clear()
                        ..addAll(addresses.toSet());
                    });
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    setStateDialog(() => _placeSearchResults.clear());
                  }
                } finally {
                  if (ctx.mounted) {
                    setStateDialog(() => isSearchingPlace = false);
                  }
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('Use current location'),
                    subtitle: const Text('Detect and fill automatically'),
                    trailing: isFetchingLocation
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _fillCurrentLocation();
                    },
                  ),
                  const Divider(),
                  TextField(
                    controller: placeSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search nearby places',
                      hintText: 'Metro, school, landmark...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: search,
                    onSubmitted: search,
                  ),
                  const SizedBox(height: 12),
                  if (isSearchingPlace)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_placeSearchResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Type to find nearby places'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _placeSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final address = _placeSearchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(address),
                            onTap: () {
                              sellerPickupLocationController.text = address;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pickup location updated')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatPlacemark(Placemark place) {
    final addressParts = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
    ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty);
    return addressParts.join(', ');
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Use current location'),
              subtitle: const Text('Auto-fill from GPS'),
              trailing: isFetchingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                _fillCurrentLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Search nearby places'),
              subtitle: const Text('Type a nearby landmark or address'),
              onTap: () {
                Navigator.of(context).pop();
                _openNearbyPlaces();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt),
              title: const Text('Enter address manually'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProductImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web: Read bytes and store path
          final Uint8List bytes = await image.readAsBytes();
          setState(() {
            productImagePath = image.path; // Web path
            productImageBytes = bytes;
          });
        } else {
          // For mobile: Save image to app directory
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String fileName = path.basename(image.path);
          final String savedPath = path.join(appDir.path, 'product_images', fileName);
          
          // Create directory if it doesn't exist
          final Directory imageDir = Directory(path.dirname(savedPath));
          if (!await imageDir.exists()) {
            await imageDir.create(recursive: true);
          }

          // Copy file
          final File savedFile = await File(image.path).copy(savedPath);
          
          setState(() {
            productImage = savedFile;
            productImagePath = savedPath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickColorImage(String colorName) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web: Read bytes and store path
          final Uint8List bytes = await image.readAsBytes();
          setState(() {
            colorImagePaths[colorName] = image.path; // Web path
            colorImageBytes[colorName] = bytes;
            // Auto-set as default if no default is set yet
            if (defaultColorImage == null) {
              defaultColorImage = colorName;
              productImagePath = image.path;
              productImageBytes = bytes;
            }
          });
        } else {
          // For mobile: Save image to app directory
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String fileName = '${colorName}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
          final String savedPath = path.join(appDir.path, 'product_images', 'colors', fileName);
          
          // Create directory if it doesn't exist
          final Directory imageDir = Directory(path.dirname(savedPath));
          if (!await imageDir.exists()) {
            await imageDir.create(recursive: true);
          }

          // Copy file
          final File savedFile = await File(image.path).copy(savedPath);
          
          setState(() {
            colorImageFiles[colorName] = savedFile;
            colorImagePaths[colorName] = savedPath;
            // Auto-set as default if no default is set yet
            if (defaultColorImage == null) {
              defaultColorImage = colorName;
              productImagePath = savedPath;
              productImage = savedFile;
            }
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image added for $colorName${defaultColorImage == colorName ? ' (set as default)' : ''}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickFssaiLicense() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          fssaiLicenseFile = result.files.single;
          fssaiController.text = fssaiLicenseFile!.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _pickDateTime({required bool isPrepared}) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      initialDate: DateTime.now(),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isPrepared) {
        preparedAt = result;
      } else {
        expiryDate = result;
      }
    });
  }

  Future<void> _saveSellerProfile() async {
    final currentSellerId = sellerId;
    if (currentSellerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue')),
        );
      }
      return;
    }

    if (sellerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill seller name')),
      );
      return;
    }

    // Validate phone number
    if (sellerPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter contact number')),
      );
      return;
    }

    // Validate pickup location
    if (sellerPickupLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter pickup location')),
      );
      return;
    }

    // FSSAI is only required for cooked food
    if (selectedType == SellType.cookedFood && sellerFssaiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FSSAI license is required for cooked food')),
      );
      return;
    }

    final profile = SellerProfile(
      sellerName: sellerNameController.text.trim(),
      fssaiLicense: selectedType == SellType.cookedFood 
          ? sellerFssaiController.text.trim()
          : (sellerProfile?.fssaiLicense ?? ''), // Keep existing FSSAI if not cooked food
      cookedFoodSource: selectedCookedFoodSource,
      defaultFoodType: selectedType,
      sellerId: currentSellerId,
      phoneNumber: sellerPhoneController.text.trim(),
      pickupLocation: sellerPickupLocationController.text.trim(),
    );

    await SellerProfileService.saveProfile(profile);
    
    setState(() {
      sellerProfile = profile;
      showSellerProfileForm = false;
      isFirstTimeSeller = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller profile saved successfully')),
      );
    }
  }

  Future<void> _selectPreviousListing(Listing listing) async {
    selectedPreviousListing = listing;
    nameController.text = listing.name;
    priceController.text = listing.price.toString();
    originalPriceController.text = listing.originalPrice?.toString() ?? '';
    quantityController.text = listing.quantity.toString();
    selectedType = listing.type;
    selectedCategory = listing.category;
    selectedClothingCategory = listing.clothingCategory;
    descriptionController.text = listing.description ?? '';
    availableSizes = listing.availableSizes ?? [];
    availableColors = listing.availableColors ?? [];
    sizeColorCombinations = listing.sizeColorCombinations ?? [];
    // Load color images
    if (listing.colorImages != null) {
      colorImagePaths.clear();
      colorImageFiles.clear();
      colorImageBytes.clear();
      for (final entry in listing.colorImages!.entries) {
        colorImagePaths[entry.key] = entry.value;
        if (kIsWeb) {
          // For web, try to load bytes
          try {
            final XFile file = XFile(entry.value);
            final bytes = await file.readAsBytes();
            colorImageBytes[entry.key] = bytes;
          } catch (e) {
            // If loading fails, keep the path
          }
        } else {
          // For mobile, check if file exists
          final file = File(entry.value);
          if (file.existsSync()) {
            colorImageFiles[entry.key] = file;
          }
        }
      }
    }
    selectedCookedFoodSource = listing.cookedFoodSource;
    selectedMeasurementUnit = listing.measurementUnit;
    // Don't auto-fill dates - seller needs to set them manually
    preparedAt = null;
    expiryDate = null;
    
    // Load image properly for both web and mobile
    if (listing.imagePath != null && listing.imagePath!.isNotEmpty) {
      productImagePath = listing.imagePath;
      if (kIsWeb) {
        // For web, try to load the image bytes
        try {
          final XFile file = XFile(listing.imagePath!);
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              productImageBytes = bytes;
              productImagePath = listing.imagePath;
            });
          }
        } catch (e) {
          // If loading fails, keep the path but mark for re-upload
          if (mounted) {
            setState(() {
              productImagePath = listing.imagePath;
              productImageBytes = null;
            });
          }
        }
      } else {
        // For mobile, check if file exists
        final file = File(listing.imagePath!);
        if (file.existsSync()) {
          if (mounted) {
            setState(() {
              productImage = file;
              productImagePath = listing.imagePath;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              productImagePath = null;
              productImage = null;
            });
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          productImagePath = null;
          productImage = null;
          productImageBytes = null;
        });
      }
    }
  }

  Future<void> _showPreviousListingsDialog() async {
    final currentSellerId = sellerId;
    if (currentSellerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view previous listings')),
        );
      }
      return;
    }
    final box = Hive.box<Listing>('listingBox');
    final previousListings = box.values
        .where((l) => l.sellerId == currentSellerId)
        .toSet()
        .toList();

    if (previousListings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous listings found')),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Previous Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: previousListings.length,
            itemBuilder: (context, index) {
              final listing = previousListings[index];
              return ListTile(
                leading: listing.imagePath != null
                    ? (kIsWeb
                        ? const Icon(Icons.fastfood) // On web, show icon (image loading is complex)
                        : File(listing.imagePath!).existsSync()
                            ? Image.file(File(listing.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.fastfood))
                    : const Icon(Icons.fastfood),
                title: Text(listing.name),
                subtitle: Text('₹${listing.price} - ${listing.type.name}'),
                onTap: () async {
                  await _selectPreviousListing(listing);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate product image (for clothing, allow default color image instead)
    if (productImagePath == null) {
      if (selectedType == SellType.clothingAndApparel && defaultColorImage != null && colorImagePaths.containsKey(defaultColorImage)) {
        // Use default color image as product image
        productImagePath = colorImagePaths[defaultColorImage];
        if (kIsWeb) {
          productImageBytes = colorImageBytes[defaultColorImage];
        } else {
          productImage = colorImageFiles[defaultColorImage];
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a product image or set a default color image')),
        );
        return;
      }
    }

    // Validate seller profile for first-time sellers
    if (isFirstTimeSeller && showSellerProfileForm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete seller profile first')),
      );
      return;
    }

    final currentSellerId = sellerId;
    if (currentSellerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to post listings')),
        );
      }
      return;
    }

    try {
      // For groceries with multiple pack sizes, validate pack sizes
      if (selectedType == SellType.groceries && useMultiplePackSizes) {
        if (packSizes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please add at least one pack size')),
            );
          }
          return;
        }
        // Validate all pack sizes have valid quantity and price
        for (var packSize in packSizes) {
          if (packSize.quantity <= 0 || packSize.price <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All pack sizes must have quantity > 0 and price > 0')),
              );
            }
            return;
          }
        }
      }
      
      // For groceries without multiple pack sizes, create a single pack size from packSizeWeightController
      List<PackSize>? finalPackSizes;
      if (selectedType == SellType.groceries && !useMultiplePackSizes && packSizeWeightController.text.isNotEmpty) {
        final packWeight = double.tryParse(packSizeWeightController.text) ?? 0.0;
        if (packWeight > 0) {
          finalPackSizes = [
            PackSize(
              quantity: packWeight,
              price: double.parse(priceController.text),
            )
          ];
        }
      } else if (selectedType == SellType.groceries && useMultiplePackSizes && packSizes.isNotEmpty) {
        finalPackSizes = packSizes;
      }
      
      final listing = Listing(
        name: nameController.text.trim(),
        sellerName: sellerProfile?.sellerName ?? sellerNameController.text.trim(),
        price: (selectedType == SellType.groceries && useMultiplePackSizes && packSizes.isNotEmpty)
            ? packSizes.first.price // Use first pack size price for backward compatibility
            : double.parse(priceController.text),
        originalPrice: originalPriceController.text.isEmpty
            ? null
            : double.parse(originalPriceController.text),
        quantity: int.parse(quantityController.text), // Always use quantityController for stock count
        initialQuantity: int.parse(quantityController.text), // Stock count
        sellerId: currentSellerId,
        type: selectedType,
        fssaiLicense: (selectedType == SellType.cookedFood || selectedType == SellType.liveKitchen)
            ? (sellerProfile?.fssaiLicense ?? fssaiController.text)
            : null,
        preparedAt: (selectedType == SellType.vegetables || selectedType == SellType.groceries || selectedType == SellType.liveKitchen) ? null : preparedAt,
        expiryDate: (selectedType == SellType.vegetables || selectedType == SellType.groceries || selectedType == SellType.liveKitchen) ? null : expiryDate,
        category: selectedCategory,
        cookedFoodSource: selectedCookedFoodSource,
        imagePath: productImagePath ?? (selectedType == SellType.clothingAndApparel && defaultColorImage != null 
            ? colorImagePaths[defaultColorImage] 
            : null),
        measurementUnit: (selectedType == SellType.vegetables || 
                          selectedType == SellType.groceries)
            ? selectedMeasurementUnit
            : null,
        packSizes: finalPackSizes,
        isBulkFood: selectedType == SellType.cookedFood && isBulkFood,
        servesCount: (selectedType == SellType.cookedFood && isBulkFood && servesCountController.text.isNotEmpty)
            ? int.tryParse(servesCountController.text)
            : null,
        portionDescription: (selectedType == SellType.cookedFood && isBulkFood && portionDescriptionController.text.isNotEmpty)
            ? portionDescriptionController.text.trim()
            : null,
        // Live Kitchen fields
        isKitchenOpen: selectedType == SellType.liveKitchen ? isKitchenOpen : false,
        preparationTimeMinutes: (selectedType == SellType.liveKitchen && preparationTimeController.text.isNotEmpty)
            ? int.tryParse(preparationTimeController.text)
            : null,
        maxCapacity: (selectedType == SellType.liveKitchen && maxCapacityController.text.isNotEmpty)
            ? int.tryParse(maxCapacityController.text)
            : null,
        clothingCategory: selectedType == SellType.clothingAndApparel ? selectedClothingCategory : null,
        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
        availableSizes: selectedType == SellType.clothingAndApparel && availableSizes.isNotEmpty ? availableSizes : null,
        availableColors: selectedType == SellType.clothingAndApparel && availableColors.isNotEmpty ? availableColors : null,
        sizeColorCombinations: selectedType == SellType.clothingAndApparel && sizeColorCombinations.isNotEmpty ? sizeColorCombinations : null,
        colorImages: selectedType == SellType.clothingAndApparel && colorImagePaths.isNotEmpty ? colorImagePaths : null,
      );

      final error = ListingValidator.validate(listing);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
        return;
      }

      // If in multi-item mode, add to pending items list instead of posting immediately
      if (isMultiItemMode) {
        final pendingItem = PendingListingItem(
          tempId: DateTime.now().millisecondsSinceEpoch.toString(),
          name: listing.name,
          price: listing.price,
          originalPrice: listing.originalPrice,
          quantity: listing.quantity,
          type: listing.type,
          category: listing.category,
          cookedFoodSource: listing.cookedFoodSource,
          preparedAt: listing.preparedAt,
          expiryDate: listing.expiryDate,
          fssaiLicense: listing.fssaiLicense,
          imagePath: listing.imagePath,
          measurementUnit: listing.measurementUnit,
          packSizes: listing.packSizes,
          packSizeWeight: (selectedType == SellType.groceries && !useMultiplePackSizes && packSizeWeightController.text.isNotEmpty)
              ? packSizeWeightController.text
              : null,
          isBulkFood: listing.isBulkFood,
          servesCount: listing.servesCount,
          portionDescription: listing.portionDescription,
          // Live Kitchen fields
          isKitchenOpen: listing.isKitchenOpen,
          preparationTimeMinutes: listing.preparationTimeMinutes,
          maxCapacity: listing.maxCapacity,
        );

        setState(() {
          pendingItems.add(pendingItem);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Item added to list! (${pendingItems.length} items)"),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Clear the form for next item
          _clearForm();
          
          // Scroll to top to show the pending items list
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
        return;
      }

      // Single item mode
      setState(() => isSubmitting = true);

      try {
        // Validate scheduling if enabled
        if (enableScheduling) {
          if (selectedScheduleType == null) {
            setState(() => isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a schedule type')),
              );
            }
            return;
          }
          if (scheduleStartDate == null) {
            setState(() => isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a start date')),
              );
            }
            return;
          }
          if (scheduleTime == null) {
            setState(() => isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a posting time')),
              );
            }
            return;
          }
          if (selectedScheduleType == ScheduleType.weekly && selectedDayOfWeek == null) {
            setState(() => isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a day of week for weekly schedule')),
              );
            }
            return;
          }
        }

        final box = Hive.box<Listing>('listingBox');
        final bool wasScheduling = enableScheduling;
        final currentSellerId = sellerId;

        if (wasScheduling && currentSellerId != null) {
          // Create a scheduled listing for this single item
          final scheduledListing = ScheduledListing(
            scheduledId: DateTime.now().millisecondsSinceEpoch.toString(),
            listingData: listing,
            scheduleType: selectedScheduleType!,
            scheduleStartDate: scheduleStartDate!,
            scheduleEndDate: scheduleEndDate,
            scheduleTime: scheduleTime!,
            scheduleCloseTime: scheduleCloseTime,
            dayOfWeek: selectedScheduleType == ScheduleType.weekly ? selectedDayOfWeek : null,
            sellerId: currentSellerId,
            createdAt: DateTime.now(),
          );

          await ScheduledListingService.addScheduledListing(scheduledListing);
        } else {
          // Post immediately
          await box.add(listing);
        }

        setState(() {
          isSubmitting = false;
          if (wasScheduling) {
            enableScheduling = false;
            selectedScheduleType = null;
            scheduleStartDate = null;
            scheduleEndDate = null;
            scheduleTime = null;
            scheduleCloseTime = null;
            selectedDayOfWeek = null;
          }
        });

        if (mounted) {
          final currentSellerId = sellerId;
          if (currentSellerId != null) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  wasScheduling
                      ? "Listing scheduled successfully!"
                      : "Listing posted successfully!",
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              )
            );
            
            // Navigate to manage items page after a short delay
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerItemManagementScreen(sellerId: currentSellerId),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Listing saved successfully!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error posting listing: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Color? iconColor, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (iconColor ?? AppTheme.primaryColor).withOpacity(0.15),
                    (iconColor ?? AppTheme.primaryColor).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child, {Color? backgroundColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
        ],
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    String? helperText,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool enabled = true,
    Color? iconColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      enabled: enabled,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: iconColor ?? AppTheme.primaryColor, size: 22)
            : null,
        suffixIcon: suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: -0.2,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
        ),
        helperStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isPrimary = true,
    bool isFullWidth = true,
    Color? backgroundColor,
    Gradient? gradient,
  }) {
    final buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );

    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 54,
      decoration: BoxDecoration(
        gradient: gradient ??
            (isPrimary
                ? LinearGradient(
                    colors: [AppTheme.warningColor, AppTheme.warningColor.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null),
        color: backgroundColor ?? (isPrimary ? null : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: AppTheme.warningColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: buttonContent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          ),
          onPressed: () {
            if (widget.onBackToDashboard != null) {
              widget.onBackToDashboard!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Start Selling",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "List your products",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (sellerProfile != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.warningColor.withOpacity(0.15), AppTheme.warningColor.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppTheme.warningColor, size: 20),
                ),
                tooltip: "Edit Profile",
                onPressed: () {
                  setState(() {
                    showSellerProfileForm = true;
                  });
                },
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.grey.shade200, Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Multi-Item Mode Toggle
            _buildCard(
              SwitchListTile(
                title: const Text(
                  'Multiple Items Mode',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  isMultiItemMode 
                      ? 'Add multiple items before posting'
                      : 'Post one item at a time',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                value: isMultiItemMode,
                onChanged: (value) {
                  setState(() {
                    isMultiItemMode = value;
                    if (!value) {
                      // Clear pending items when switching back to single mode
                      pendingItems.clear();
                    }
                  });
                },
                secondary: Icon(
                  isMultiItemMode ? Icons.list : Icons.add_circle_outline,
                  color: isMultiItemMode ? Colors.orange : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pending Items List (when in multi-item mode)
            if (isMultiItemMode && pendingItems.isNotEmpty) ...[
              _buildSectionTitle(
                "Items to Post (${pendingItems.length})",
                icon: Icons.shopping_bag,
                iconColor: Colors.green,
              ),
              ...pendingItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildCard(
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '₹${item.price.toStringAsFixed(0)} • Qty: ${item.quantity} • ${item.type.name}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          pendingItems.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Previous Items Selection
            if (sellerProfile != null) ...[
              _buildSectionTitle("Quick Post", icon: Icons.history, iconColor: Colors.blue),
              _buildCard(
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.infoColor.withOpacity(0.1), AppTheme.infoColor.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _showPreviousListingsDialog,
                    icon: Icon(Icons.repeat, size: 22, color: AppTheme.infoColor),
                    label: Text(
                      "Select from Previous Items",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.infoColor),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Seller Profile Form (One-time entry)
            if (showSellerProfileForm) ...[
              _buildSectionTitle(
                isFirstTimeSeller ? "Seller Information" : "Update Seller Information",
                icon: Icons.person,
                iconColor: Colors.purple,
              ),
              _buildCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: sellerNameController,
                      decoration: InputDecoration(
                        labelText: "Seller Name *",
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    if (selectedType == SellType.cookedFood) ...[
                      DropdownButtonFormField<CookedFoodSource>(
                        value: selectedCookedFoodSource,
                        decoration: InputDecoration(
                          labelText: "Food Source *",
                          prefixIcon: const Icon(Icons.store),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: CookedFoodSource.values.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => selectedCookedFoodSource = v),
                        validator: selectedType == SellType.cookedFood
                            ? (v) => v == null ? "Required" : null
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // FSSAI License - Only required for cooked food
                    if (selectedType == SellType.cookedFood) ...[
                      TextFormField(
                        controller: sellerFssaiController,
                        decoration: InputDecoration(
                          labelText: "FSSAI License Number *",
                          prefixIcon: const Icon(Icons.verified),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "Enter FSSAI license number",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: _pickFssaiLicense,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file, color: Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fssaiLicenseFile == null
                                            ? "Attach FSSAI License Document"
                                            : "Document: ${fssaiLicenseFile!.name}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: fssaiLicenseFile == null
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                          color: fssaiLicenseFile == null
                                              ? Colors.grey.shade600
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      if (fssaiLicenseFile != null)
                                        Text(
                                          "${(fssaiLicenseFile!.size / 1024).toStringAsFixed(2)} KB",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (fssaiLicenseFile != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        fssaiLicenseFile = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Phone Number
                    TextFormField(
                      controller: sellerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Contact Number *",
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        hintText: "9876543210",
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Required";
                        }
                        final phone = v.trim().replaceAll(RegExp(r'[^\d+]'), '');
                        if (phone.length < 10) {
                          return "Please enter a valid phone number";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Pickup Location
                    TextFormField(
                      controller: sellerPickupLocationController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Pickup / Collection Location *",
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: isFetchingLocation
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.my_location),
                                  tooltip: "Use current or nearby location",
                                  onPressed: _showLocationPicker,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        hintText: "Tap locator to use current or nearby location",
                      ),
                      validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                showSellerProfileForm = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveSellerProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bulk Food Option (only for cooked food) - BEFORE Item Details
            if (selectedType == SellType.cookedFood) ...[
              _buildSectionTitle("Bulk/Catering Option", icon: Icons.groups, iconColor: Colors.purple),
              _buildCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Bulk/Group Food Item',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isBulkFood 
                            ? 'This item serves multiple people (e.g., Biryani for 25)'
                            : 'Enable for catering-style food items',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      value: isBulkFood,
                      onChanged: (value) {
                        setState(() {
                          isBulkFood = value;
                          if (!value) {
                            servesCountController.clear();
                            portionDescriptionController.clear();
                          }
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isBulkFood ? Colors.purple.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isBulkFood ? Icons.groups : Icons.person,
                          color: isBulkFood ? Colors.purple : Colors.grey,
                        ),
                      ),
                    ),
                    if (isBulkFood) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bulk items are sold as complete units. Buyers purchase the entire pack.',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: servesCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Number of People Served *",
                          prefixIcon: const Icon(Icons.people),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "e.g., 25, 50, 100",
                          helperText: "How many people can this item serve?",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: isBulkFood 
                            ? (v) {
                                if (v?.isEmpty ?? true) return "Required for bulk items";
                                final count = int.tryParse(v!);
                                if (count == null || count <= 1) return "Must serve more than 1 person";
                                return null;
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: portionDescriptionController,
                        decoration: InputDecoration(
                          labelText: "Portion Description (Optional)",
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "e.g., Full Handi, Large Vessel, Catering Pack",
                          helperText: "Describe the portion size or container",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Preview of how it will appear to buyers
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade100, Colors.purple.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.visibility, size: 16, color: Colors.purple.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Buyer Preview',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.groups, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    servesCountController.text.isNotEmpty 
                                        ? 'Serves ${servesCountController.text} people'
                                        : 'Serves __ people',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (portionDescriptionController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                portionDescriptionController.text,
                                style: TextStyle(
                                  color: Colors.purple.shade800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Live Kitchen Option (only for Live Kitchen type)
            if (selectedType == SellType.liveKitchen) ...[
              _buildSectionTitle("🔥 Live Kitchen Settings", icon: Icons.restaurant, iconColor: Colors.deepOrange),
              _buildCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kitchen Status Toggle
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isKitchenOpen 
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isKitchenOpen ? 'Kitchen Open' : 'Kitchen Closed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  isKitchenOpen 
                                      ? 'Accepting orders now'
                                      : 'Toggle to start accepting orders',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isKitchenOpen,
                            onChanged: (value) {
                              setState(() => isKitchenOpen = value);
                            },
                            activeColor: Colors.white,
                            activeTrackColor: Colors.green.shade300,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live Kitchen: Cook fresh food on demand. Buyers order, you prepare and deliver fresh.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Preparation Time
                    TextFormField(
                      controller: preparationTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Preparation Time (minutes) *",
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: "e.g., 15, 30, 45",
                        helperText: "Average time to prepare one order",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return "Preparation time is required";
                        final time = int.tryParse(v!);
                        if (time == null || time <= 0) return "Enter a valid time in minutes";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Maximum Capacity
                    TextFormField(
                      controller: maxCapacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Maximum Orders (Capacity) *",
                        prefixIcon: const Icon(Icons.shopping_basket),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: "e.g., 10, 20, 50",
                        helperText: "Maximum orders you can handle at once",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return "Maximum capacity is required";
                        final cap = int.tryParse(v!);
                        if (cap == null || cap <= 0) return "Enter a valid capacity";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Preview section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepOrange.shade100, Colors.orange.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.visibility, size: 16, color: Colors.deepOrange.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Buyer Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isKitchenOpen ? Colors.green : Colors.grey,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isKitchenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isKitchenOpen ? 'Kitchen Open' : 'Kitchen Closed',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      preparationTimeController.text.isNotEmpty 
                                          ? '${preparationTimeController.text} mins'
                                          : '__ mins',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            maxCapacityController.text.isNotEmpty 
                                ? '${maxCapacityController.text} order slots available'
                                : '__ order slots available',
                            style: TextStyle(
                              color: Colors.deepOrange.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Item Details
            _buildSectionTitle("Item Details", icon: Icons.info, iconColor: Colors.orange),
            _buildCard(
              Column(
                children: [
                  // Product Name with Autocomplete
                  CompositedTransformTarget(
                    link: _productNameLayerLink,
                    child: TextFormField(
                      controller: nameController,
                      focusNode: _productNameFocusNode,
                      onChanged: _onProductNameChanged,
                      decoration: InputDecoration(
                        labelText: "Product Name *",
                        prefixIcon: const Icon(Icons.label),
                        suffixIcon: nameController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  nameController.clear();
                                  _removeProductSuggestionOverlay();
                                  setState(() {
                                    _productNameSuggestions = [];
                                    _showProductSuggestions = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        hintText: "Start typing for suggestions...",
                      ),
                      validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: originalPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Original Price (MRP) *",
                            prefixIcon: const Icon(Icons.currency_rupee),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Selling Price *",
                            prefixIcon: const Icon(Icons.sell),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Measurement Unit for groceries/vegetables
                  if (selectedType == SellType.vegetables ||
                      selectedType == SellType.groceries) ...[
                    DropdownButtonFormField<MeasurementUnit>(
                      value: selectedMeasurementUnit,
                      decoration: InputDecoration(
                        labelText: "Measurement Unit *",
                        prefixIcon: const Icon(Icons.straighten),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: [
                        MeasurementUnit.kilograms,
                        MeasurementUnit.grams,
                        MeasurementUnit.liters,
                      ].map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedMeasurementUnit = v),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    // Multiple pack sizes option for groceries
                    if (selectedType == SellType.groceries) ...[
                      SwitchListTile(
                        title: const Text('Multiple Pack Sizes'),
                        subtitle: const Text('Sell in different pack sizes (e.g., 5kg, 250gm)'),
                        value: useMultiplePackSizes,
                        onChanged: (value) {
                          setState(() {
                            useMultiplePackSizes = value;
                            if (value && packSizes.isEmpty) {
                              // Add a default pack size
                              packSizes.add(PackSize(quantity: 1.0, price: 0.0));
                            } else if (!value) {
                              packSizes.clear();
                            }
                          });
                        },
                      ),
                      if (useMultiplePackSizes) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Add different pack sizes with different prices:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...packSizes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final packSize = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: packSize.quantity.toString(),
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Quantity',
                                        hintText: 'e.g., 5.0',
                                        suffixText: selectedMeasurementUnit?.shortLabel ?? '',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final qty = double.tryParse(value) ?? 0.0;
                                        setState(() {
                                          packSizes[index] = PackSize(
                                            quantity: qty,
                                            price: packSizes[index].price,
                                            label: packSizes[index].label,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: packSize.price.toString(),
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Price (₹)',
                                        hintText: 'e.g., 100',
                                        prefixText: '₹',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final price = double.tryParse(value) ?? 0.0;
                                        setState(() {
                                          packSizes[index] = PackSize(
                                            quantity: packSizes[index].quantity,
                                            price: price,
                                            label: packSizes[index].label,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: packSize.label ?? '',
                                      decoration: InputDecoration(
                                        labelText: 'Label (Optional)',
                                        hintText: 'e.g., 5kg Pack',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          packSizes[index] = PackSize(
                                            quantity: packSizes[index].quantity,
                                            price: packSizes[index].price,
                                            label: value.isEmpty ? null : value,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        packSizes.removeAt(index);
                                        if (packSizes.isEmpty) {
                                          useMultiplePackSizes = false;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              packSizes.add(PackSize(quantity: 1.0, price: 0.0));
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Pack Size'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Pack size weight (for single pack size groceries)
                        if (selectedType == SellType.groceries) ...[
                          TextFormField(
                            controller: packSizeWeightController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: selectedMeasurementUnit != null
                                  ? "Pack Size Weight (${selectedMeasurementUnit!.shortLabel}) *"
                                  : "Pack Size Weight *",
                              prefixIcon: const Icon(Icons.scale),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: selectedMeasurementUnit != null
                                  ? "e.g., 250 for 250gm pack"
                                  : "Enter pack size weight",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Stock quantity (number of packs/items available)
                        TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: selectedType == SellType.groceries && !useMultiplePackSizes
                                ? "Stock Quantity (Number of Packs) *"
                                : selectedMeasurementUnit != null
                                    ? "Stock Quantity (${selectedMeasurementUnit!.shortLabel}) *"
                                    : "Stock Quantity *",
                            prefixIcon: const Icon(Icons.inventory_2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: selectedType == SellType.groceries && !useMultiplePackSizes
                                ? "e.g., 250 (number of packs available)"
                                : selectedMeasurementUnit != null
                                    ? "Enter stock quantity in ${selectedMeasurementUnit!.shortLabel}"
                                    : "Enter stock quantity",
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                        ),
                      ],
                    ] else ...[
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: selectedMeasurementUnit != null
                              ? "Quantity (${selectedMeasurementUnit!.shortLabel}) *"
                              : "Quantity *",
                          prefixIcon: const Icon(Icons.scale),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: selectedMeasurementUnit != null
                              ? "Enter quantity in ${selectedMeasurementUnit!.shortLabel}"
                              : "Enter quantity",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                      ),
                    ],
                  ] else ...[
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isBulkFood 
                            ? "Number of Bulk Packs Available *"
                            : "Quantity *",
                        prefixIcon: Icon(isBulkFood ? Icons.inventory_2 : Icons.scale),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: isBulkFood 
                            ? "e.g., 1 (how many bulk packs you have)"
                            : "Enter quantity",
                        helperText: isBulkFood 
                            ? "Each bulk pack serves ${servesCountController.text.isNotEmpty ? servesCountController.text : '__'} people"
                            : null,
                        filled: true,
                        fillColor: isBulkFood ? Colors.purple.shade50 : Colors.grey.shade50,
                      ),
                      validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                    ),
                  ],
                ],
              ),
            ),

            // Food Category
            if (selectedType == SellType.cookedFood ||
                selectedType == SellType.groceries) ...[
              _buildSectionTitle("Food Category", icon: Icons.restaurant, iconColor: Colors.green),
              _buildCard(
                DropdownButtonFormField<FoodCategory>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Veg / Egg / Non-Veg",
                    prefixIcon: const Icon(Icons.fastfood),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: FoodCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedCategory = v!),
                ),
              ),
            ],

            // Clothing Category
            if (selectedType == SellType.clothingAndApparel) ...[
              _buildSectionTitle("Clothing Category", icon: Icons.checkroom, iconColor: Colors.purple),
              _buildCard(
                DropdownButtonFormField<ClothingCategory>(
                  value: selectedClothingCategory,
                  decoration: InputDecoration(
                    labelText: "Select Category",
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: ClothingCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Text(c.icon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Text(c.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedClothingCategory = v),
                ),
              ),
            ],

            // Size-Color Combinations (for clothing and apparel)
            if (selectedType == SellType.clothingAndApparel) ...[
              _buildSectionTitle("Size & Color Combinations", icon: Icons.style, iconColor: Colors.teal),
              _buildCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Configure which colors are available for each size",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Add Size Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sizeTextController,
                                decoration: InputDecoration(
                                  labelText: "Add Size",
                                  hintText: "e.g., S, M, L, XL, Free Size",
                                  prefixIcon: const Icon(Icons.straighten),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    final size = value.trim();
                                    // Check if size already exists
                                    if (!sizeColorCombinations.any((combo) => combo.size == size)) {
                                      setState(() {
                                        sizeColorCombinations.add(SizeColorCombination(
                                          size: size,
                                          availableColors: [],
                                        ));
                                        sizeTextController.clear();
                                      });
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Colors.teal,
                              onPressed: () {
                                final size = sizeTextController.text.trim();
                                if (size.isNotEmpty) {
                                  if (!sizeColorCombinations.any((combo) => combo.size == size)) {
                                    setState(() {
                                      sizeColorCombinations.add(SizeColorCombination(
                                        size: size,
                                        availableColors: [],
                                      ));
                                      sizeTextController.clear();
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick add "Free Size" button
                        if (!sizeColorCombinations.any((combo) => combo.size.toLowerCase() == 'free size'))
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.secondaryColor.withOpacity(0.1), AppTheme.secondaryColor.withOpacity(0.05)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  sizeColorCombinations.add(SizeColorCombination(
                                    size: 'Free Size',
                                    availableColors: [],
                                  ));
                                });
                              },
                              icon: Icon(Icons.all_inclusive, size: 18, color: AppTheme.secondaryColor),
                              label: Text('Add Free Size', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Size-Color Combinations List
                    if (sizeColorCombinations.isNotEmpty) ...[
                      ...sizeColorCombinations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final combo = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.backgroundColor, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: combo.size.toLowerCase() == 'free size'
                                          ? LinearGradient(
                                              colors: [AppTheme.secondaryColor, AppTheme.secondaryColor.withOpacity(0.8)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : LinearGradient(
                                              colors: [AppTheme.infoColor, AppTheme.infoColor.withOpacity(0.8)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (combo.size.toLowerCase() == 'free size' ? AppTheme.secondaryColor : AppTheme.infoColor).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (combo.size.toLowerCase() == 'free size')
                                          const Icon(Icons.all_inclusive, color: Colors.white, size: 16),
                                        if (combo.size.toLowerCase() == 'free size')
                                          const SizedBox(width: 6),
                                        Text(
                                          combo.size,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        sizeColorCombinations.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Available Colors for ${combo.size}:",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...combo.availableColors.map((color) {
                                    final hasImage = colorImagePaths.containsKey(color) && 
                                                    (kIsWeb ? colorImageBytes[color] != null : 
                                                     colorImageFiles[color] != null && 
                                                     colorImageFiles[color]!.existsSync());
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: hasImage
                                            ? LinearGradient(
                                                colors: [AppTheme.successColor.withOpacity(0.15), AppTheme.successColor.withOpacity(0.05)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: hasImage ? null : AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: hasImage ? AppTheme.successColor.withOpacity(0.4) : AppTheme.borderColor,
                                          width: hasImage ? 2 : 1.5,
                                        ),
                                        boxShadow: hasImage
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.successColor.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Image upload button
                                          IconButton(
                                            icon: Icon(
                                              hasImage ? Icons.check_circle : Icons.add_photo_alternate,
                                              size: 18,
                                              color: hasImage ? Colors.green.shade700 : Colors.grey.shade600,
                                            ),
                                            onPressed: () => _pickColorImage(color),
                                            tooltip: hasImage ? 'Change image' : 'Add image for $color',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          // Color name
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              color,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: hasImage ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          // Set as default button (only show if image exists)
                                          if (hasImage)
                                            IconButton(
                                              icon: Icon(
                                                defaultColorImage == color ? Icons.star : Icons.star_border,
                                                size: 18,
                                                color: defaultColorImage == color ? Colors.amber.shade700 : Colors.grey.shade600,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  defaultColorImage = defaultColorImage == color ? null : color;
                                                  // Update productImagePath to use default color image
                                                  if (defaultColorImage != null && colorImagePaths.containsKey(defaultColorImage)) {
                                                    productImagePath = colorImagePaths[defaultColorImage];
                                                    if (kIsWeb) {
                                                      productImageBytes = colorImageBytes[defaultColorImage];
                                                    } else {
                                                      productImage = colorImageFiles[defaultColorImage];
                                                    }
                                                  }
                                                });
                                              },
                                              tooltip: defaultColorImage == color ? 'Default image (tap to remove)' : 'Set as default product image',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          // Delete button
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18),
                                            onPressed: () {
                                              setState(() {
                                                final updatedColors = List<String>.from(combo.availableColors);
                                                updatedColors.remove(color);
                                                sizeColorCombinations[index] = SizeColorCombination(
                                                  size: combo.size,
                                                  availableColors: updatedColors,
                                                );
                                                // Remove color image when color is removed
                                                colorImagePaths.remove(color);
                                                colorImageFiles.remove(color);
                                                colorImageBytes.remove(color);
                                                // If this was the default, clear it
                                                if (defaultColorImage == color) {
                                                  defaultColorImage = null;
                                                  productImagePath = null;
                                                  productImage = null;
                                                  productImageBytes = null;
                                                }
                                              });
                                            },
                                            tooltip: 'Remove color',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  Builder(
                                    builder: (context) {
                                      // Get or create controller for this size
                                      if (!colorControllers.containsKey(index)) {
                                        colorControllers[index] = TextEditingController();
                                      }
                                      return SizedBox(
                                        width: 120,
                                        child: TextField(
                                          controller: colorControllers[index],
                                          decoration: InputDecoration(
                                            hintText: "Add color",
                                            hintStyle: TextStyle(fontSize: 11),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          style: const TextStyle(fontSize: 11),
                                          onSubmitted: (value) {
                                            if (value.trim().isNotEmpty && !combo.availableColors.contains(value.trim())) {
                                              setState(() {
                                                final updatedColors = List<String>.from(combo.availableColors);
                                                updatedColors.add(value.trim());
                                                sizeColorCombinations[index] = SizeColorCombination(
                                                  size: combo.size,
                                                  availableColors: updatedColors,
                                                );
                                                colorControllers[index]?.clear();
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            "Add sizes and configure available colors for each size",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Product Description (for all items, especially useful for clothing)
            _buildSectionTitle("Product Description", icon: Icons.description, iconColor: Colors.blue),
            _buildCard(
              TextFormField(
                controller: descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: "Describe your product (Brand, Material, Size, Features, etc.)",
                  hintText: "E.g., Premium cotton sweatshirt from XYZ brand. Available in sizes S, M, L, XL. Soft fabric, perfect for casual wear...",
                  prefixIcon: const Icon(Icons.edit_note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            // Product Image (Mandatory for non-clothing, optional for clothing if default color image is set)
            if (selectedType != SellType.clothingAndApparel || defaultColorImage == null) ...[
              _buildSectionTitle(
                "Product Image", 
                icon: Icons.image, 
                iconColor: Colors.pink,
                subtitle: selectedType == SellType.clothingAndApparel 
                    ? "Or set a default image from color images above" 
                    : null,
              ),
              _buildCard(
              Column(
                children: [
                  GestureDetector(
                    onTap: _pickProductImage,
                    child: Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: productImagePath == null
                              ? Colors.red.shade300
                              : Colors.green.shade300,
                          width: 3,
                        ),
                      ),
                      child: productImagePath != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: kIsWeb
                                      ? (productImageBytes != null
                                          ? Image.memory(
                                              productImageBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(),
                                            ))
                                      : productImage != null
                                          ? Image.file(
                                              productImage!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 18,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          productImage = null;
                                          productImagePath = null;
                                          productImageBytes = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          "Image Uploaded",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate,
                                    size: 64,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Tap to upload product image",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (selectedType != SellType.clothingAndApparel || defaultColorImage == null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "* Required",
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            ],

            // Time (Not for vegetables, groceries, clothing and apparel, or live kitchen)
            if (selectedType != SellType.vegetables && selectedType != SellType.groceries && selectedType != SellType.clothingAndApparel && selectedType != SellType.liveKitchen) ...[
              _buildSectionTitle("Time Information", icon: Icons.access_time, iconColor: Colors.indigo),
              _buildCard(
                Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        preparedAt == null
                            ? "Select Prepared Date & Time"
                            : "Prepared: ${_formatDateTime(preparedAt!)}",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _pickDateTime(isPrepared: true),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.timer_off),
                      label: Text(
                        expiryDate == null
                            ? "Select Expiry Date & Time"
                            : "Expires: ${_formatDateTime(expiryDate!)}",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _pickDateTime(isPrepared: false),
                    ),
                  ],
                ),
              ),
            ],

            // Scheduling section - available for both single and multi-item modes
            const SizedBox(height: 24),
            _buildCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Options (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Scheduling'),
                    subtitle: const Text('Automatically post at scheduled times'),
                    value: enableScheduling,
                    onChanged: (value) {
                      setState(() {
                        enableScheduling = value;
                        if (!value) {
                          selectedScheduleType = null;
                          scheduleStartDate = null;
                          scheduleEndDate = null;
                          scheduleTime = null;
                          scheduleCloseTime = null;
                          selectedDayOfWeek = null;
                        }
                      });
                    },
                  ),
                  if (enableScheduling) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ScheduleType>(
                      decoration: const InputDecoration(
                        labelText: 'Schedule Type',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedScheduleType,
                      items: ScheduleType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedScheduleType = value;
                          if (value != ScheduleType.weekly) {
                            selectedDayOfWeek = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        scheduleStartDate == null
                            ? 'Select Start Date'
                            : 'Start: ${_formatDate(scheduleStartDate!)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            scheduleStartDate = date;
                          });
                        }
                      },
                    ),
                    if (selectedScheduleType == ScheduleType.daily ||
                        selectedScheduleType == ScheduleType.weekly) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.event_busy),
                        label: Text(
                          scheduleEndDate == null
                              ? 'Select End Date (Optional)'
                              : 'End: ${_formatDate(scheduleEndDate!)}',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: scheduleStartDate ?? DateTime.now(),
                            firstDate: scheduleStartDate ?? DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              scheduleEndDate = date;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        scheduleTime == null
                            ? 'Select Open/Post Time'
                            : 'Opens at: ${_formatTime(scheduleTime!)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade700,
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: scheduleTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            scheduleTime = time;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        scheduleCloseTime == null
                            ? 'Select Close/Expiry Time (Optional)'
                            : 'Closes at: ${_formatTime(scheduleCloseTime!)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: scheduleCloseTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            scheduleCloseTime = time;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Display summary of schedule
                    if (scheduleStartDate != null && scheduleTime != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule Summary:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Start: ${_formatDate(scheduleStartDate!)} at ${_formatTime(scheduleTime!)}',
                                    style: TextStyle(color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                            if (scheduleEndDate != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.event_busy, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'End Date: ${_formatDate(scheduleEndDate!)}',
                                      style: TextStyle(color: Colors.blue.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (scheduleCloseTime != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Closes daily at: ${_formatTime(scheduleCloseTime!)}',
                                      style: TextStyle(color: Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (selectedScheduleType != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.repeat, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Frequency: ${selectedScheduleType!.name.toUpperCase()}',
                                      style: TextStyle(color: Colors.blue.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (selectedScheduleType == ScheduleType.weekly) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Day of Week',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedDayOfWeek,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Monday')),
                          DropdownMenuItem(value: 2, child: Text('Tuesday')),
                          DropdownMenuItem(value: 3, child: Text('Wednesday')),
                          DropdownMenuItem(value: 4, child: Text('Thursday')),
                          DropdownMenuItem(value: 5, child: Text('Friday')),
                          DropdownMenuItem(value: 6, child: Text('Saturday')),
                          DropdownMenuItem(value: 7, child: Text('Sunday')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedDayOfWeek = value;
                          });
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button - PREMIUM STYLE
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSubmitting ? null : _submit,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isMultiItemMode ? Icons.add_circle_outline : Icons.upload_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isMultiItemMode ? "Add to List" : "Post Listing",
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            // Post All Listings Button (when in multi-item mode with pending items)
            if (isMultiItemMode && pendingItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.successColor, AppTheme.successColor.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: AppTheme.successColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isSubmitting ? null : _postAllListings,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_rounded, size: 22, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  "Post All Listings (${pendingItems.length})",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _postAllListings() async {
    if (pendingItems.isEmpty) return;

    final currentSellerId = sellerId;
    if (currentSellerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to post listings')),
        );
      }
      return;
    }

    // Store count before clearing
    final itemsCount = pendingItems.length;

    // Validate scheduling if enabled
    if (enableScheduling) {
      if (selectedScheduleType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a schedule type')),
        );
        return;
      }
      if (scheduleStartDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a start date')),
        );
        return;
      }
      if (scheduleTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a posting time')),
        );
        return;
      }
      if (selectedScheduleType == ScheduleType.weekly && selectedDayOfWeek == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a day of week for weekly schedule')),
        );
        return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      final sellerName = sellerProfile?.sellerName ?? sellerNameController.text.trim();
      final box = Hive.box<Listing>('listingBox');

      if (enableScheduling) {
        // Create scheduled listings
        for (final pendingItem in pendingItems) {
          final listing = pendingItem.toListing(
            sellerId: currentSellerId,
            sellerName: sellerName,
          );

          final scheduledListing = ScheduledListing(
            scheduledId: '${DateTime.now().millisecondsSinceEpoch}_${pendingItem.tempId}',
            listingData: listing,
            scheduleType: selectedScheduleType!,
            scheduleStartDate: scheduleStartDate!,
            scheduleEndDate: scheduleEndDate,
            scheduleTime: scheduleTime!,
            scheduleCloseTime: scheduleCloseTime,
            dayOfWeek: selectedScheduleType == ScheduleType.weekly ? selectedDayOfWeek : null,
            sellerId: currentSellerId,
            createdAt: DateTime.now(),
          );

          await ScheduledListingService.addScheduledListing(scheduledListing);
        }
      } else {
        // Post immediately
        for (final pendingItem in pendingItems) {
          final listing = pendingItem.toListing(
            sellerId: currentSellerId,
            sellerName: sellerName,
          );
          await box.add(listing);
        }

        // Success message will be shown after navigation delay
      }

      setState(() {
        pendingItems.clear();
        enableScheduling = false;
        selectedScheduleType = null;
        scheduleStartDate = null;
        scheduleEndDate = null;
        scheduleTime = null;
        scheduleCloseTime = null;
        selectedDayOfWeek = null;
        isSubmitting = false;
      });

      // Clear form
      _clearForm();

      // Navigate to manage items page
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enableScheduling 
                ? "$itemsCount items scheduled successfully!"
                : "$itemsCount listings posted successfully!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Navigate after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerItemManagementScreen(sellerId: currentSellerId),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error posting listings: $e")),
        );
      }
    }
  }

  void _clearForm() {
    // Clear all text controllers
    nameController.clear();
    priceController.clear();
    originalPriceController.clear();
    quantityController.clear();
    fssaiController.clear();
    servesCountController.clear();
    portionDescriptionController.clear();
    preparationTimeController.clear();
    maxCapacityController.clear();
    
    // Reset form state
    _formKey.currentState?.reset();
    
    // Reset state variables
    setState(() {
      selectedType = SellType.cookedFood;
      selectedCookedFoodSource = null;
      selectedCategory = FoodCategory.veg;
      selectedMeasurementUnit = null;
      preparedAt = null;
      expiryDate = null;
      fssaiLicenseFile = null;
      productImage = null;
      productImagePath = null;
      productImageBytes = null;
      selectedPreviousListing = null;
      isSubmitting = false;
      isBulkFood = false;
      isKitchenOpen = false;
    });
    
    // Scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

}
