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

class AddListingScreen extends StatefulWidget {
  final ValueNotifier<int>? promptCounter;
  const AddListingScreen({super.key, this.promptCounter});

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
  MeasurementUnit? selectedMeasurementUnit;
  DateTime? preparedAt;
  DateTime? expiryDate;
  PlatformFile? fssaiLicenseFile;
  File? productImage;
  String? productImagePath;
  Uint8List? productImageBytes; // For web storage

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
      if (selectedType == SellType.vegetables || selectedType == SellType.medicine || selectedType == SellType.groceries) {
        if (selectedType != SellType.groceries) {
          selectedCategory = FoodCategory.veg;
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

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Choose item type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...SellType.values.map((t) {
                    String? subtitle;
                    if (t == SellType.cookedFood) {
                      subtitle = 'FSSAI mandatory for cooked food';
                    } else if (t == SellType.liveKitchen) {
                      subtitle = 'Cook on demand - real-time orders';
                    }
                    return RadioListTile<SellType>(
                      value: t,
                      groupValue: tempType,
                      title: Text(t == SellType.liveKitchen 
                          ? '🔥 Live Kitchen' 
                          : t.displayName),
                      subtitle: subtitle != null ? Text(subtitle) : null,
                      onChanged: (val) {
                        if (val == null) return;
                        setStateDialog(() => tempType = val);
                      },
                    );
                  }),
                  if (tempType == SellType.cookedFood)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'FSSAI number will be required.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (tempType == SellType.liveKitchen)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: const [
                          Icon(Icons.restaurant, color: Colors.deepOrange, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cook food on demand. Buyers order, you prepare fresh.',
                              style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Continue'),
                ),
              ],
              actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          },
        );
      },
    );

    _applySelectedType(tempType);
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

    // Validate product image
    if (productImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a product image')),
      );
      return;
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
        imagePath: productImagePath,
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

  Widget _buildSectionTitle(String title, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child, {Color? backgroundColor}) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Start Selling",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        actions: [
          if (sellerProfile != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              tooltip: "Edit Profile",
              onPressed: () {
                setState(() {
                  showSellerProfileForm = true;
                });
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
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
                ElevatedButton.icon(
                  onPressed: _showPreviousListingsDialog,
                  icon: const Icon(Icons.repeat, size: 22),
                  label: const Text(
                    "Select from Previous Items",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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

            // Product Image (Mandatory)
            _buildSectionTitle("Product Image", icon: Icons.image, iconColor: Colors.pink),
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

            // Time (Not for vegetables, groceries, or live kitchen)
            if (selectedType != SellType.vegetables && selectedType != SellType.groceries && selectedType != SellType.liveKitchen) ...[
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
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
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
                          const Icon(Icons.check_circle, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            isMultiItemMode ? "Add to List" : "Post Listing",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Post All Listings Button (when in multi-item mode with pending items)
            if (isMultiItemMode && pendingItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSubmitting ? null : _postAllListings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
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
                          const Icon(Icons.check_circle, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            "Post All Listings (${pendingItems.length})",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
