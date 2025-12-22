import 'package:flutter/material.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          foodCard('Veg Biryani', '₹120'),
          foodCard('Chicken Curry', '₹180'),
          foodCard('Paneer Butter Masala', '₹150'),
        ],
      ),
    );
  }

  Widget foodCard(String name, String price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(name),
        subtitle: Text(price),
        trailing: ElevatedButton(
          onPressed: () {},
          child: const Text('Order'),
        ),
      ),
    );
  }
}
