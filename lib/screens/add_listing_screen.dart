import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/sell_type.dart';
import '../services/api_service.dart';
import '../services/listing_validator.dart';
import '../models/food_category.dart';
import '../models/cooked_food_source.dart';
import 'package:hive/hive.dart';


Widget sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget cardWrap(Widget child) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );
}


class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final sellerController = TextEditingController();
  final priceController = TextEditingController();
  final originalPriceController = TextEditingController();
  final quantityController = TextEditingController();
  final fssaiController = TextEditingController();

  SellType selectedType = SellType.cookedFood;
CookedFoodSource? selectedCookedFoodSource;

  DateTime? preparedAt;
  DateTime? expiryDate;

  bool isSubmitting = false;
FoodCategory selectedCategory = FoodCategory.veg;



  Future<void> _pickDateTime({
    required bool isPrepared,
  }) async {
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

//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;

//     final listing = Listing(
//       name: nameController.text.trim(),
//       cookedFoodSource: selectedCookedFoodSource,
//       sellerName: sellerController.text.trim(),
//       price: double.parse(priceController.text),
//       originalPrice: originalPriceController.text.isEmpty
//           ? null
//           : double.parse(originalPriceController.text),
//       quantity: int.parse(quantityController.text),
//       type: selectedType,
//       fssaiLicense:
//           selectedType == SellType.cookedFood ? fssaiController.text : null,
//       preparedAt: preparedAt,
//       expiryDate: expiryDate,
//       category: selectedCategory,
      

//     );

//     final error = ListingValidator.validate(listing);
//     if (error != null) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text(error)));
//       return;
//     }

//     setState(() => isSubmitting = true);

   
// if (!Hive.isBoxOpen('listingBox')) {
//   await Hive.openBox<Listing>('listingBox');
// }
// final box = Hive.box<Listing>('listingBox');
// await box.add(listing);

// setState(() => isSubmitting = false);

// ScaffoldMessenger.of(context).showSnackBar(
//   const SnackBar(content: Text("Listing posted successfully")),
// );

// Navigator.pop(context);

//   }
Future<void> _submit() async {
  try {
    if (!_formKey.currentState!.validate()) return;

    final listing = Listing(
      name: nameController.text.trim(),
      cookedFoodSource: selectedCookedFoodSource,
      sellerName: sellerController.text.trim(),
      price: double.parse(priceController.text),
      originalPrice: originalPriceController.text.isEmpty
          ? null
          : double.parse(originalPriceController.text),
      quantity: int.parse(quantityController.text),
      type: selectedType,
      fssaiLicense:
          selectedType == SellType.cookedFood ? fssaiController.text : null,
      preparedAt: preparedAt,
      expiryDate: expiryDate,
      category: selectedCategory,
    );

    final error = ListingValidator.validate(listing);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => isSubmitting = true);

    print("👉 Opening Hive box");
    final box = Hive.box<Listing>('listingBox');

    print("👉 Adding listing");
    await box.add(listing);

    print("✅ Listing added");

    setState(() => isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Listing posted successfully")),
    );

    Navigator.pop(context);
  } catch (e, s) {
    print("❌ SUBMIT ERROR: $e");
    print(s);

    setState(() => isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Listing")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

  // 🔹 SELL TYPE
  sectionTitle("Item Type"),
  cardWrap(
    DropdownButtonFormField<SellType>(
      value: selectedType,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.category),
        labelText: "What are you selling?",
        border: OutlineInputBorder(),
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
            fssaiController.clear();
            preparedAt = null;
          }
          if (selectedType == SellType.vegetables ||
              selectedType == SellType.medicine) {
            selectedCategory = FoodCategory.veg;
          }
        });
      },
    ),
  ),

  // 🔹 COOKED FOOD SOURCE
  if (selectedType == SellType.cookedFood) ...[
    sectionTitle("Cooked Food Details"),
    cardWrap(
      Column(
        children: [
          DropdownButtonFormField<CookedFoodSource>(
            value: selectedCookedFoodSource,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.store),
              labelText: "Cooked food source",
              border: OutlineInputBorder(),
            ),
            items: CookedFoodSource.values.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Text(c.label),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedCookedFoodSource = v),
            validator: (v) =>
                v == null ? "Please select cooked food source" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: fssaiController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.verified),
              labelText: "FSSAI License",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  ],

  // 🔹 FOOD CATEGORY
  if (selectedType == SellType.cookedFood ||
      selectedType == SellType.groceries) ...[
    sectionTitle("Food Category"),
    cardWrap(
      DropdownButtonFormField<FoodCategory>(
        value: selectedCategory,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.restaurant),
          labelText: "Veg / Egg / Non-Veg",
          border: OutlineInputBorder(),
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

  // 🔹 ITEM DETAILS
  sectionTitle("Item Details"),
  cardWrap(
    Column(
      children: [
        TextFormField(
          controller: sellerController,
          validator: (v) => v == null || v.isEmpty ? "Seller required" : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person),
            labelText: "Seller name",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          validator: (v) => v == null || v.isEmpty ? "Item name required" : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.fastfood),
            labelText: "Item name",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: originalPriceController,
          keyboardType: TextInputType.number,
          validator: (v) =>
      v == null || v.isEmpty ? "Price required" : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.currency_rupee),
            labelText: "Original price (MRP)",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: priceController,
          keyboardType: TextInputType.number,
          validator: (v) =>
      v == null || v.isEmpty ? "Price required" : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.discount),
            labelText: "Selling price",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          validator: (v) =>
      v == null || v.isEmpty ? "Quantity required" : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.scale),
            labelText: "Quantity",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
  ),

  // 🔹 TIME
  sectionTitle("Time"),
  cardWrap(
    Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.access_time),
          label: Text(preparedAt == null
              ? "Select prepared date & time"
              : preparedAt.toString()),
          onPressed: () => _pickDateTime(isPrepared: true),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.timer_off),
          label: Text(expiryDate == null
              ? "Select expiry date & time"
              : expiryDate.toString()),
          onPressed: () => _pickDateTime(isPrepared: false),
        ),
      ],
    ),
  ),

  const SizedBox(height: 20),

  // 🔹 SUBMIT
  ElevatedButton(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    onPressed: isSubmitting ? null : _submit,
    child: const Text(
      "Post Listing",
      style: TextStyle(fontSize: 16),
    ),
  ),
],

          ),
        ),
      ),
    );
  }
}
