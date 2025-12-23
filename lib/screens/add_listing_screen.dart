import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../models/food_category.dart';
import '../models/cooked_food_source.dart';
import '../models/measurement_unit.dart';
import '../models/seller_profile.dart';
import '../services/listing_validator.dart';
import '../services/seller_profile_service.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

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
  final quantityController = TextEditingController();
  final fssaiController = TextEditingController();

  // Seller Profile Controllers (for one-time entry)
  final sellerNameController = TextEditingController();
  final sellerFssaiController = TextEditingController();

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
  bool showSellerProfileForm = false;
  bool isFirstTimeSeller = false;
  SellerProfile? sellerProfile;
  Listing? selectedPreviousListing;

  final String sellerId = '101'; // TODO: Get from auth

  @override
  void initState() {
    super.initState();
    _loadSellerProfile();
  }

  Future<void> _loadSellerProfile() async {
    final hasProfile = await SellerProfileService.hasProfile(sellerId);
    if (!hasProfile) {
      setState(() {
        isFirstTimeSeller = true;
        showSellerProfileForm = true;
      });
    } else {
      final profile = await SellerProfileService.getProfile(sellerId);
      setState(() {
        sellerProfile = profile;
        if (profile != null) {
          sellerNameController.text = profile.sellerName;
          sellerFssaiController.text = profile.fssaiLicense;
          selectedCookedFoodSource = profile.cookedFoodSource;
          if (profile.defaultFoodType != null) {
            selectedType = profile.defaultFoodType!;
          }
        }
      });
    }
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
    if (sellerNameController.text.isEmpty || sellerFssaiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all seller profile fields')),
      );
      return;
    }

    final profile = SellerProfile(
      sellerName: sellerNameController.text.trim(),
      fssaiLicense: sellerFssaiController.text.trim(),
      cookedFoodSource: selectedCookedFoodSource,
      defaultFoodType: selectedType,
      sellerId: sellerId,
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

  void _selectPreviousListing(Listing listing) {
    setState(() {
      selectedPreviousListing = listing;
      nameController.text = listing.name;
      priceController.text = listing.price.toString();
      originalPriceController.text = listing.originalPrice?.toString() ?? '';
      quantityController.text = listing.quantity.toString();
      selectedType = listing.type;
      selectedCategory = listing.category;
      selectedCookedFoodSource = listing.cookedFoodSource;
      selectedMeasurementUnit = listing.measurementUnit;
      preparedAt = listing.preparedAt;
      expiryDate = listing.expiryDate;
      if (listing.imagePath != null) {
        productImagePath = listing.imagePath;
        productImage = File(listing.imagePath!);
      }
    });
  }

  Future<void> _showPreviousListingsDialog() async {
    final box = Hive.box<Listing>('listingBox');
    final previousListings = box.values
        .where((l) => l.sellerId == sellerId)
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
                leading: listing.imagePath != null && File(listing.imagePath!).existsSync()
                    ? Image.file(File(listing.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.fastfood),
                title: Text(listing.name),
                subtitle: Text('₹${listing.price} - ${listing.type.name}'),
                onTap: () {
                  _selectPreviousListing(listing);
                  Navigator.pop(context);
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

    try {
      final listing = Listing(
        name: nameController.text.trim(),
        sellerName: sellerProfile?.sellerName ?? sellerNameController.text.trim(),
        price: double.parse(priceController.text),
        originalPrice: originalPriceController.text.isEmpty
            ? null
            : double.parse(originalPriceController.text),
        quantity: int.parse(quantityController.text),
        initialQuantity: int.parse(quantityController.text),
        sellerId: sellerId,
        type: selectedType,
        fssaiLicense: selectedType == SellType.cookedFood
            ? (sellerProfile?.fssaiLicense ?? fssaiController.text)
            : null,
        preparedAt: selectedType == SellType.vegetables ? null : preparedAt,
        expiryDate: selectedType == SellType.vegetables ? null : expiryDate,
        category: selectedCategory,
        cookedFoodSource: selectedCookedFoodSource,
        imagePath: productImagePath,
        measurementUnit: (selectedType == SellType.vegetables || 
                          selectedType == SellType.groceries)
            ? selectedMeasurementUnit
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

      setState(() => isSubmitting = true);

      final box = Hive.box<Listing>('listingBox');
      await box.add(listing);

      setState(() => isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Listing posted successfully!")),
        );
        Navigator.pop(context);
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
          "Sell Food",
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

            // Product Image (Mandatory) - PROMINENT
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

            // Item Type
            _buildSectionTitle("Item Type", icon: Icons.category, iconColor: Colors.blue),
            _buildCard(
              DropdownButtonFormField<SellType>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: "What are you selling?",
                  prefixIcon: const Icon(Icons.shopping_bag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: SellType.values.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e.name),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    selectedType = v!;
                    if (selectedType != SellType.cookedFood) {
                      selectedCookedFoodSource = null;
                    }
                    if (selectedType == SellType.vegetables ||
                        selectedType == SellType.medicine) {
                      selectedCategory = FoodCategory.veg;
                      preparedAt = null;
                      expiryDate = null;
                    }
                    // Set default measurement unit
                    if (selectedType == SellType.vegetables ||
                        selectedType == SellType.groceries) {
                      selectedMeasurementUnit ??= MeasurementUnit.kilograms;
                    }
                  });
                },
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

            // Item Details
            _buildSectionTitle("Item Details", icon: Icons.info, iconColor: Colors.orange),
            _buildCard(
              Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Product Name *",
                      prefixIcon: const Icon(Icons.label),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) => v?.isEmpty ?? true ? "Required" : null,
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
                  ],
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
              ),
            ),

            // Time (Not for vegetables)
            if (selectedType != SellType.vegetables) ...[
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 24),
                          SizedBox(width: 12),
                          Text(
                            "Post Listing",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    originalPriceController.dispose();
    quantityController.dispose();
    fssaiController.dispose();
    sellerNameController.dispose();
    sellerFssaiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
