import 'package:flutter/material.dart';
import 'food_admin_screen.dart';
import 'restaurant_admin_screen.dart';
import 'tourist_place_admin_screen.dart';
import 'phrase_admin_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminMenu(
            icon: Icons.restaurant_menu,
            title: 'Foods',
            subtitle: 'Manage food',
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodAdminScreen(),
                ),
              );
            },
          ),
          _AdminMenu(
            icon: Icons.restaurant,
            title: 'Restaurants',
            subtitle: 'Manage restaurants',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RestaurantAdminScreen(),
                ),
              );
            },
          ),
          _AdminMenu(
            icon: Icons.location_city,
            title: 'Tourist Places',
            subtitle: 'Manage tourist places',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TouristPlaceAdminScreen(),
                ),
              );
            },
          ),
          _AdminMenu(
            icon: Icons.translate,
            title: 'Phrases',
            subtitle: 'Manage Vietnamese phrases',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PhraseAdminScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminMenu extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withAlpha(35),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}