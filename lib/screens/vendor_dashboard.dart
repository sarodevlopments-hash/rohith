import 'package:flutter/material.dart';
import 'add_listing_screen.dart';
import '../models/sell_type.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  SellType _selectedType = SellType.cookedFood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// 🔽 SELL TYPE DROPDOWN
          DropdownButtonFormField<SellType>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: "What are you selling?",
              border: OutlineInputBorder(),
            ),
            items: SellType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          /// 🍛 COOKED FOOD
          if (_selectedType == SellType.cookedFood) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: "FSSAI License",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: "Discount %",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],

          /// 📦 PACKED FOOD
          if (_selectedType == SellType.groceries) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: "MRP",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: "Expiry Date",
                border: OutlineInputBorder(),
              ),
            ),
          ],

          /// 💊 MEDICINE
          if (_selectedType == SellType.medicine) ...[
            CheckboxListTile(
              value: true,
              onChanged: (_) {},
              title: const Text("OTC Medicine"),
            ),
          ],

          /// 🥦 VEGETABLES
          if (_selectedType == SellType.vegetables) ...[
            const Text(
              "Price must be less than market price",
              style: TextStyle(color: Colors.green),
            ),
          ],
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddListingScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget vendorCard(String item, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(item),
        subtitle: Text(status),
        trailing: Icon(
          status == 'Available' ? Icons.check_circle : Icons.cancel,
          color: status == 'Available' ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
